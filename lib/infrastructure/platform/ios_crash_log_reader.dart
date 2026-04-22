// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Basename of the crash log written by the native-side [CrashReporter]
/// (`ios/Runner/CrashReporter.swift`). Triple-source truth: Swift
/// `CrashReporter.crashLogURL` + Dart constant here + any debug-menu
/// consumer must agree.
const String kIosCrashLogBasename = 'ios_crash.log';

/// Basename of the drained crash log — after [IosCrashLogReader.drainIfAny]
/// reads the active file and SHOUTs it into the FileLogger JSONL, the
/// file is renamed with this suffix so the debug menu's "Voir dernier
/// crash" can still display it on later launches.
///
/// Why rename instead of delete: the user wants to inspect the last
/// native crash directly from the debug menu even after the bootstrap
/// drain has already written it to today's log — scrolling the JSONL is
/// not as convenient as a dedicated "show me the most recent crash"
/// affordance.
const String kIosCrashLogDrainedBasename = 'ios_crash.log.drained';

/// Reads (and optionally drains) the native iOS crash log file produced
/// by the Swift-side [CrashReporter].
///
/// ## Purpose
///
/// Sideloaded iOS builds (SideStore / AltStore) are excluded from the
/// system ReportCrash pipeline, so native crashes (SIGABRT, EXC_BAD_ACCESS,
/// uncaught NSException) used to leave zero trace once the Dart VM was
/// torn down with the process. The Swift CrashReporter installed in
/// AppDelegate captures those crashes and appends a raw dump to
/// `<AppSupport>/ios_crash.log`. On the next cold launch, this reader
/// picks up the file, logs its contents at SHOUT, then renames it to
/// `ios_crash.log.drained` — so every subsequent native crash shows up
/// in today's FileLogger JSONL AND remains readable from the debug menu.
///
/// ## Lifecycle
///
/// - Swift crash → writes `ios_crash.log`.
/// - Dart bootstrap → [drainIfAny] SHOUTs contents + renames to
///   `ios_crash.log.drained` (overwriting any previous drained file).
/// - Debug menu [readIfAny] → returns `ios_crash.log` if present (a new
///   crash captured after last drain), else `ios_crash.log.drained`
///   (the crash already drained into the JSONL).
/// - User explicitly hits "Supprimer" → [clear] deletes both.
///
/// ## Non-iOS platforms
///
/// All operations are no-ops on Android / desktop — the Swift CrashReporter
/// doesn't run there, and the crash log file never exists. The class is
/// still safe to call from cross-platform bootstrap code.
///
/// ## GOSL compliance
///
/// Local-file-only. No network, no third-party service, no telemetry.
class IosCrashLogReader {
  IosCrashLogReader();

  static final Logger _log = Logger('infrastructure.platform.ios_crash_log_reader');

  /// Resolves the absolute path of the active crash log on disk (the
  /// one Swift writes to). Matches the Swift side's
  /// `FileManager.default.urls(for: .applicationSupportDirectory, ...)`
  /// lookup by going through `path_provider.getApplicationSupportDirectory()`,
  /// which resolves to the same NSApplicationSupportDirectory URL on iOS.
  ///
  /// Returns null on non-iOS platforms.
  Future<String?> resolveCrashLogFilename() async {
    if (!_isIos) return null;
    final Directory supportDir = await getApplicationSupportDirectory();
    return p.join(supportDir.path, kIosCrashLogBasename);
  }

  /// Resolves the path of the drained (post-bootstrap) crash log.
  /// Returns null on non-iOS platforms.
  Future<String?> resolveDrainedCrashLogFilename() async {
    if (!_isIos) return null;
    final Directory supportDir = await getApplicationSupportDirectory();
    return p.join(supportDir.path, kIosCrashLogDrainedBasename);
  }

  /// Returns the most recent crash-log contents — prioritising the
  /// active file (a fresh crash since last drain) over the drained file
  /// (already logged into today's JSONL). Returns null if neither
  /// exists.
  ///
  /// Does NOT delete or rename anything — callers that want idempotent
  /// drain semantics should use [drainIfAny] instead.
  ///
  /// Used by the debug menu's "Voir dernier crash" entry so the user
  /// can see the last native crash regardless of whether it has already
  /// been drained at bootstrap.
  Future<String?> readIfAny() async {
    final String? activeFilename = await resolveCrashLogFilename();
    if (activeFilename != null) {
      final File active = File(activeFilename);
      if (await active.exists()) {
        try {
          return await active.readAsString();
        } on FileSystemException catch (e, st) {
          _log.warning('readIfAny: failed to read active $activeFilename', e, st);
        }
      }
    }
    final String? drainedFilename = await resolveDrainedCrashLogFilename();
    if (drainedFilename != null) {
      final File drained = File(drainedFilename);
      if (await drained.exists()) {
        try {
          return await drained.readAsString();
        } on FileSystemException catch (e, st) {
          _log.warning('readIfAny: failed to read drained $drainedFilename', e, st);
        }
      }
    }
    return null;
  }

  /// Returns the filename that [readIfAny] would currently read, or null
  /// if neither the active nor the drained file exists. Lets the debug
  /// menu pass the right File to the share sheet.
  Future<String?> resolveReadableFilename() async {
    final String? activeFilename = await resolveCrashLogFilename();
    if (activeFilename != null && await File(activeFilename).exists()) {
      return activeFilename;
    }
    final String? drainedFilename = await resolveDrainedCrashLogFilename();
    if (drainedFilename != null && await File(drainedFilename).exists()) {
      return drainedFilename;
    }
    return null;
  }

  /// Drains the active crash log: reads it, emits at SHOUT, then renames
  /// to the `.drained` variant so the debug menu can still display it.
  /// Returns the raw contents (or null if no fresh crash was pending).
  ///
  /// Intended to be called exactly once during bootstrap, AFTER
  /// `FileLogger.bootstrap()` so the SHOUT is captured by today's JSONL.
  /// Swallows all IO / platform errors best-effort: a crash-log read
  /// failure must never prevent the app from starting.
  Future<String?> drainIfAny() async {
    if (!_isIos) return null;
    try {
      final String? activeFilename = await resolveCrashLogFilename();
      if (activeFilename == null) return null;
      final File active = File(activeFilename);
      if (!await active.exists()) return null;

      final String contents = await active.readAsString();
      // SHOUT so the Dart-side log captures the native crash trail at the
      // highest severity. The payload is raw (signal number, si_addr,
      // backtrace addresses, NSException reason+stack). Keep it intact —
      // the whole point of this channel is that we do NOT want to try
      // to parse / sanitise it on a platform where we couldn't even trust
      // ourselves to run more code.
      _log.shout('=== iOS native crash recovered from previous run ===\n$contents');

      // Move active → drained. `rename(2)` is atomic on the same
      // filesystem so there is no window where both files could be
      // partially written. If a previous drained file exists (crash
      // happened, was drained, then a NEW crash occurred after), the
      // rename replaces it — the active file is always the most recent.
      try {
        final String? drainedFilename = await resolveDrainedCrashLogFilename();
        if (drainedFilename != null) {
          // Delete any stale drained file first — `File.rename` on iOS
          // fails if the destination already exists.
          final File drained = File(drainedFilename);
          if (await drained.exists()) {
            await drained.delete();
          }
          await active.rename(drainedFilename);
        } else {
          // No drained-path available (shouldn't happen on iOS) — fall
          // back to delete so we don't re-drain on next launch.
          await active.delete();
        }
      } on FileSystemException catch (e, st) {
        _log.warning('drainIfAny: post-drain rename failed; next launch may re-log', e, st);
      }
      return contents;
    } on Object catch (e, st) {
      _log.warning('drainIfAny: unexpected error (non-fatal, continuing bootstrap)', e, st);
      return null;
    }
  }

  /// Deletes BOTH the active and drained crash log files if present.
  /// Used by the debug menu after the user has confirmed they've
  /// shared / read the report.
  Future<void> clear() async {
    if (!_isIos) return;
    for (final Future<String?> futureFilename in <Future<String?>>[resolveCrashLogFilename(), resolveDrainedCrashLogFilename()]) {
      try {
        final String? filename = await futureFilename;
        if (filename == null) continue;
        final File file = File(filename);
        if (await file.exists()) {
          await file.delete();
        }
      } on FileSystemException catch (e, st) {
        _log.warning('clear: delete failed', e, st);
      }
    }
  }

  /// Platform guard — the native hook only runs on iOS. `defaultTargetPlatform`
  /// would also work but would evaluate to iOS under flutter test on desktop
  /// if overridden; the explicit `Platform.isIOS` check keeps this tied to
  /// the actual runtime OS.
  bool get _isIos {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }
}
