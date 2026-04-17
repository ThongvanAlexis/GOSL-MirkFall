// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';

/// JSON-Lines file sink for the project logger.
///
/// One file per app launch under `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt`.
/// At bootstrap, oldest files are pruned until directory size < [kMaxLogsDirBytes].
/// Root log level is set from `--dart-define=DEBUG` or SharedPreferences flag.
class FileLogger {
  static IOSink? _sink;
  static String? _activeFilename;
  static StreamSubscription<LogRecord>? _subscription;

  /// Shared-prefs key for the verbose-logging toggle. Value lives across
  /// launches; `--dart-define=DEBUG=true` overrides to verbose regardless.
  static const String kDebugLoggingPrefsKey = 'debug_logging_enabled';

  /// Active log file absolute path, or null before [bootstrap] (or after [clearAll]).
  static String? get activeFilename => _activeFilename;

  /// Initialises the logger: opens today's file, prunes oldest files, sets
  /// [Logger.root] level, subscribes to the `LogRecord` stream.
  ///
  /// MUST be awaited before [runApp]. Idempotent: calling twice closes the
  /// previous sink and re-opens cleanly (covers dev hot-reload and tests that
  /// re-bootstrap between cases).
  static Future<void> bootstrap() async {
    // 1) Decide level — DEBUG define or SharedPreferences flag switches to ALL.
    const debugDefine = bool.fromEnvironment('DEBUG');
    final prefs = await SharedPreferences.getInstance();
    final verboseFromPrefs = prefs.getBool(kDebugLoggingPrefsKey) ?? false;
    Logger.root.level = (debugDefine || verboseFromPrefs) ? Level.ALL : Level.INFO;

    // 2) Resolve logs dir under <app_docs>/logs.
    final docsDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(p.join(docsDir.path, 'logs'));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    // 3) Prune oldest files until directory size < kMaxLogsDirBytes.
    await _pruneToSizeLimit(logsDir);

    // 4) Compute today's filename and open it in append mode.
    final now = DateTime.now();
    final timestamp = _formatFilenameTimestamp(now);
    _activeFilename = p.join(logsDir.path, '${timestamp}_logs.txt');
    final file = File(_activeFilename!);

    // Idempotency: close previous sink + unsubscribe if bootstrap was called
    // twice (hot-reload / tests). Order: flush → close → cancel.
    await _sink?.flush();
    await _sink?.close();
    await _subscription?.cancel();

    _sink = file.openWrite(mode: FileMode.append);
    _subscription = Logger.root.onRecord.listen(_onRecord);
  }

  /// Toggles the SharedPreferences flag that controls logging verbosity when
  /// `--dart-define=DEBUG` is not set. Takes effect immediately for the
  /// current run (mutates [Logger.root.level]) and persists for next launch.
  /// Returns the new flag value.
  static Future<bool> toggleVerbosePref() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !(prefs.getBool(kDebugLoggingPrefsKey) ?? false);
    await prefs.setBool(kDebugLoggingPrefsKey, next);
    return next;
  }

  /// Reads the current value of the verbose logging preference.
  static Future<bool> readVerbosePref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kDebugLoggingPrefsKey) ?? false;
  }

  /// Lists all `*_logs.txt` files in the logs directory, sorted newest-first
  /// by filename (which embeds the timestamp, so alphabetical == chronological).
  static Future<List<File>> listLogFiles() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(p.join(docsDir.path, 'logs'));
    if (!await logsDir.exists()) return <File>[];
    final files = <File>[];
    await for (final entity in logsDir.list()) {
      if (entity is File && entity.path.endsWith('_logs.txt')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.path.compareTo(a.path)); // newest first
    return files;
  }

  /// Deletes every log file, closes the active sink, and clears the active
  /// filename. Subsequent logs are no-ops until the next [bootstrap] call.
  static Future<void> clearAll() async {
    await _sink?.flush();
    await _sink?.close();
    await _subscription?.cancel();
    _sink = null;
    _subscription = null;

    final files = await listLogFiles();
    for (final f in files) {
      try {
        await f.delete();
      } on FileSystemException {
        // Periphery error per CLAUDE.md §Error handling: a single file that
        // can't be unlinked (e.g. Windows lock) is not fatal. Keep going.
      }
    }
    _activeFilename = null;
  }

  static Future<void> _onRecord(LogRecord rec) async {
    final entry = <String, Object?>{
      'ts': rec.time.toIso8601String(),
      'level': rec.level.name,
      'logger': rec.loggerName,
      'msg': rec.message,
      if (rec.error != null) 'error': rec.error.toString(),
      if (rec.stackTrace != null) 'stack': rec.stackTrace.toString(),
    };
    final sink = _sink;
    if (sink == null) return;
    sink.writeln(jsonEncode(entry));
    await sink.flush();
  }

  static Future<void> _pruneToSizeLimit(Directory logsDir) async {
    final files = <File>[];
    await for (final entity in logsDir.list()) {
      if (entity is File && entity.path.endsWith('_logs.txt')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path)); // oldest first

    int totalBytes = 0;
    final sizes = <int>[];
    for (final f in files) {
      final s = await f.length();
      sizes.add(s);
      totalBytes += s;
    }

    var i = 0;
    while (totalBytes > kMaxLogsDirBytes && i < files.length) {
      try {
        await files[i].delete();
        totalBytes -= sizes[i];
      } on FileSystemException {
        // Skip unlinkable file, keep going. Rare edge case (Windows lock).
      }
      i++;
    }
  }

  static String _formatFilenameTimestamp(DateTime dt) {
    String pad(int n, int w) => n.toString().padLeft(w, '0');
    return '${pad(dt.year, 4)}${pad(dt.month, 2)}${pad(dt.day, 2)}'
        '_${pad(dt.hour, 2)}${pad(dt.minute, 2)}.${pad(dt.second, 2)}';
  }
}
