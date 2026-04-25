// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  // Counter for the hybrid flush policy (flush-every-N) to amortize the
  // per-record flush cost at high log rates.
  static int _unflushedRecordCount = 0;
  // Backstop periodic flush timer — guarantees `<= kFileLoggerFlushPeriodSeconds`
  // data-loss window even when activity is too sparse to trip the
  // record-count threshold. Cancelled in [clearAll] / re-armed in [bootstrap].
  static Timer? _periodicFlushTimer;

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
    _periodicFlushTimer?.cancel();

    _sink = file.openWrite(mode: FileMode.append);
    _subscription = Logger.root.onRecord.listen(_onRecord);
    _unflushedRecordCount = 0;
    // Backstop timer — bounds the worst-case loss window at
    // kFileLoggerFlushPeriodSeconds even when no record-count threshold
    // and no lifecycle transition fires. Started AFTER the sink so the
    // first tick has a sink to flush against.
    _periodicFlushTimer = startPeriodicFlushTimer(flush);
  }

  /// Creates the backstop [Timer.periodic] that drives a periodic flush
  /// every [kFileLoggerFlushPeriodSeconds] seconds. Extracted from
  /// [bootstrap] so the timer wiring can be exercised under `fakeAsync`
  /// without standing up the real I/O sink — tests inject a counting
  /// callback and advance fake time to assert the cadence.
  ///
  /// The callback is fire-and-forget: `Timer.periodic` does not observe
  /// the returned `Future`, but [IOSink] serialises its own
  /// write-after-flush ordering internally, so a still-pending flush at
  /// the next tick is benign.
  @visibleForTesting
  static Timer startPeriodicFlushTimer(Future<void> Function() flushCallback) {
    return Timer.periodic(const Duration(seconds: kFileLoggerFlushPeriodSeconds), (_) => unawaited(flushCallback()));
  }

  /// Toggles the SharedPreferences flag that controls logging verbosity when
  /// `--dart-define=DEBUG` is not set. Takes effect immediately for the
  /// current run (mutates [Logger.root.level]) and persists for next launch.
  /// Returns the new flag value. Prefer [writeVerbosePref] when the caller
  /// already knows the desired value — this XOR path is only kept for
  /// call-sites that want read-modify-write semantics.
  static Future<bool> toggleVerbosePref() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !(prefs.getBool(kDebugLoggingPrefsKey) ?? false);
    await prefs.setBool(kDebugLoggingPrefsKey, next);
    return next;
  }

  /// Writes an explicit verbose-logging preference value. Preferred over
  /// [toggleVerbosePref] when the UI already knows the desired value (e.g.
  /// a SwitchListTile's onChanged callback), so the persisted value stays
  /// monotonically aligned with the widget state instead of racing through
  /// a read-modify-write XOR.
  static Future<void> writeVerbosePref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDebugLoggingPrefsKey, value);
  }

  /// Reads the current value of the verbose logging preference.
  static Future<bool> readVerbosePref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kDebugLoggingPrefsKey) ?? false;
  }

  /// Forces the active sink's internal buffer to disk. No-op when no sink is
  /// open. Must be awaited before handing the file path to another process
  /// (share-sheet, external editor) so the shared copy isn't missing the most
  /// recent records. Resets the hybrid-flush counter so the next flush policy
  /// check starts from zero.
  static Future<void> flush() async {
    await _sink?.flush();
    _unflushedRecordCount = 0;
  }

  /// Lists all `*_logs.txt` files in the logs directory, sorted newest-first
  /// by filesystem modification time.
  ///
  /// Phase 01 relied on the yyyymmdd_hhmm.ss filename embedding + alphabetical
  /// sort to produce chronological order. That invariant is fragile: a future
  /// change to [_formatFilenameTimestamp] would silently break ordering
  /// without any compile-time signal. Use [FileStat.modified] directly so the
  /// sort stays correct regardless of the filename format.
  static Future<List<File>> listLogFiles() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(p.join(docsDir.path, 'logs'));
    if (!await logsDir.exists()) return <File>[];
    final entries = <(File, DateTime)>[];
    await for (final entity in logsDir.list()) {
      if (entity is File && entity.path.endsWith('_logs.txt')) {
        final stat = await entity.stat();
        entries.add((entity, stat.modified));
      }
    }
    entries.sort((a, b) => b.$2.compareTo(a.$2)); // newest first
    return entries.map((e) => e.$1).toList();
  }

  /// Deletes every log file, closes the active sink, and clears the active
  /// filename. When [rearm] is true (default), immediately re-bootstraps so
  /// subsequent logs are persisted to a fresh file — this matches the
  /// intuitive user mental model ("clear the logs and keep recording").
  /// Pass [rearm] = false for test tear-downs or shutdown code that explicitly
  /// wants the logger to stay closed after clearing.
  static Future<void> clearAll({bool rearm = true}) async {
    await _sink?.flush();
    await _sink?.close();
    await _subscription?.cancel();
    _periodicFlushTimer?.cancel();
    _sink = null;
    _subscription = null;
    _periodicFlushTimer = null;

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

    if (rearm) {
      // Re-arm: open a fresh sink so subsequent LogRecords are persisted
      // instead of silently dropped. The new file sits inside an empty dir,
      // so the bootstrap prune step is a no-op.
      await bootstrap();
    }
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
    // Guard against write failures (disk full, sink closed mid-write, etc.)
    // If the sink throws, clear the reference so subsequent records are
    // silently dropped instead of re-entering the zone error handler —
    // which would itself call Logger.shout → _onRecord → infinite loop.
    try {
      sink.writeln(jsonEncode(entry));
      // Hybrid flush: force fsync every N records OR on any SHOUT-level
      // record (errors must be durable immediately). Amortizes per-record
      // syscall cost at high-frequency log rates while keeping error
      // durability tight. Acceptable loss window is kFileLoggerFlushEveryNRecords
      // INFO/WARNING records on abrupt process termination.
      _unflushedRecordCount++;
      if (rec.level >= Level.SHOUT || _unflushedRecordCount >= kFileLoggerFlushEveryNRecords) {
        await sink.flush();
        _unflushedRecordCount = 0;
      }
    } on FileSystemException {
      _sink = null;
    } on StateError {
      // IOSink throws StateError when addStream/write is called after close.
      _sink = null;
    }
  }

  /// Prunes oldest log files until the directory total stays under
  /// [kMaxLogsDirBytes].
  ///
  /// INVARIANT: assumes a single app instance is writing to the logs
  /// directory. Two concurrent bootstraps (e.g. two Flutter desktop windows
  /// open simultaneously) could mis-count bytes and over-delete. This is
  /// acceptable because MirkFall is a single-window mobile/desktop app by
  /// design — not a service. If V1.x ever ships a headless/background variant
  /// that can run alongside the UI, this function needs a file-lock guard.
  static Future<void> _pruneToSizeLimit(Directory logsDir) async {
    final files = <File>[];
    await for (final entity in logsDir.list()) {
      if (entity is File && entity.path.endsWith('_logs.txt')) {
        files.add(entity);
      }
    }
    // Sort oldest-first by mtime so we prune the right files regardless of the
    // filename format (symmetric with listLogFiles using FileStat.modified).
    final byMtime = <(File, int)>[];
    for (final f in files) {
      final s = await f.stat();
      byMtime.add((f, s.modified.millisecondsSinceEpoch));
    }
    byMtime.sort((a, b) => a.$2.compareTo(b.$2));

    int totalBytes = 0;
    final sizes = <int>[];
    for (final entry in byMtime) {
      final s = await entry.$1.length();
      sizes.add(s);
      totalBytes += s;
    }

    var i = 0;
    while (totalBytes > kMaxLogsDirBytes && i < byMtime.length) {
      try {
        await byMtime[i].$1.delete();
        totalBytes -= sizes[i];
      } on FileSystemException {
        // Skip unlinkable file, keep going. Rare edge case (Windows lock).
      }
      i++;
    }
  }

  // ISO-8601 calendar-component widths used by the yyyymmdd_hhmm.ss filename
  // format. The numbers 4 and 2 are universally understood for year vs
  // month/day/hour/minute/second widths — extracted here anyway so every
  // caller references a named constant per CLAUDE.md §Magic numbers.
  static const int _yearWidth = 4;
  static const int _calendarComponentWidth = 2;

  static String _formatFilenameTimestamp(DateTime dt) {
    String pad(int n, int w) => n.toString().padLeft(w, '0');
    return '${pad(dt.year, _yearWidth)}${pad(dt.month, _calendarComponentWidth)}${pad(dt.day, _calendarComponentWidth)}'
        '_${pad(dt.hour, _calendarComponentWidth)}${pad(dt.minute, _calendarComponentWidth)}.${pad(dt.second, _calendarComponentWidth)}';
  }
}
