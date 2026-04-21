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
/// picks up the file, logs its contents at SHOUT, then deletes it — so
/// every subsequent native crash shows up in the FileLogger JSONL that the
/// debug menu already exposes via "Partager les logs".
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

  /// Resolves the absolute path of the crash log on disk.
  ///
  /// Matches the Swift side's
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

  /// Returns the raw crash-log contents if the file exists, otherwise
  /// null. Does NOT delete the file — callers that want idempotent drain
  /// semantics should use [drainIfAny] instead.
  ///
  /// Used by the debug menu's "Voir dernier crash" entry to surface the
  /// last crash even after it has been drained into today's JSONL — as
  /// long as the file is still on disk.
  Future<String?> readIfAny() async {
    final String? filename = await resolveCrashLogFilename();
    if (filename == null) return null;
    final File file = File(filename);
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } on FileSystemException catch (e, st) {
      _log.warning('readIfAny: failed to read $filename', e, st);
      return null;
    }
  }

  /// Drains the crash log: if a file exists, reads its contents, emits
  /// them at SHOUT through [Logger], then deletes the file. Returns the
  /// raw contents (or null if no crash was pending).
  ///
  /// Intended to be called exactly once during bootstrap, AFTER
  /// `FileLogger.bootstrap()` so the SHOUT is captured by today's JSONL.
  /// Swallows all IO / platform errors best-effort: a crash-log read
  /// failure must never prevent the app from starting.
  Future<String?> drainIfAny() async {
    if (!_isIos) return null;
    try {
      final String? filename = await resolveCrashLogFilename();
      if (filename == null) return null;
      final File file = File(filename);
      if (!await file.exists()) return null;

      final String contents = await file.readAsString();
      // SHOUT so the Dart-side log captures the native crash trail at the
      // highest severity. The payload is raw (signal number, si_addr,
      // backtrace addresses, NSException reason+stack). Keep it intact —
      // the whole point of this channel is that we do NOT want to try
      // to parse / sanitise it on a platform where we couldn't even trust
      // ourselves to run more code.
      _log.shout('=== iOS native crash recovered from previous run ===\n$contents');

      // Best-effort delete. If the delete fails (shouldn't on AppSupport),
      // the NEXT launch will re-drain the same contents, which is idempotent
      // from the user's perspective but will produce duplicate log entries.
      // Better duplicates than losing the report.
      try {
        await file.delete();
      } on FileSystemException catch (e, st) {
        _log.warning('drainIfAny: delete failed; next launch will re-log', e, st);
      }
      return contents;
    } on Object catch (e, st) {
      _log.warning('drainIfAny: unexpected error (non-fatal, continuing bootstrap)', e, st);
      return null;
    }
  }

  /// Deletes the crash log file if present. Used by the debug menu after
  /// the user has confirmed they've shared / read the report.
  Future<void> clear() async {
    if (!_isIos) return;
    try {
      final String? filename = await resolveCrashLogFilename();
      if (filename == null) return;
      final File file = File(filename);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (e, st) {
      _log.warning('clear: failed', e, st);
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
