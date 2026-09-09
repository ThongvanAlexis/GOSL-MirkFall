// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-05 Task 1 — `SdfRebuildLogger` 1 Hz JSONL rollup (POC FOG-03 port)
// + the verbose gate every Phase 09.1 diagnostic logger carries (CLAUDE.md §Logging: silent
// unless `Logger('infrastructure.mirk.sdf').isLoggable(Level.FINE)`).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/infrastructure/mirk/sdf_rebuild_logger.dart';

const String _loggerName = 'infrastructure.mirk.sdf';

void main() {
  // INFO-level rollup lines only surface through `Logger.root.onRecord` when the root level
  // admits them; the verbose gate additionally requires FINE to be loggable.
  setUpAll(() {
    Logger.root.level = Level.ALL;
  });

  group('09.1-05 — SdfRebuildLogger (FOG-03)', () {
    test('recordRebuild buffers samples; one JSONL rollup per active second with count / p50 / p95 / max', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      try {
        final SdfRebuildLogger logger = SdfRebuildLogger(rollupInterval: const Duration(milliseconds: 100));
        logger.start();
        logger.recordRebuild(elapsedMs: 1.2, discCount: 5, intersectingDiscCount: 2);
        logger.recordRebuild(elapsedMs: 0.8, discCount: 5, intersectingDiscCount: 2);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        logger.stop();
        expect(captured, hasLength(greaterThanOrEqualTo(1)));
        final Map<String, Object?> decoded = json.decode(captured.first.message) as Map<String, Object?>;
        expect(decoded['rebuildCount'], 2);
        expect(decoded['discCount'], 5);
        expect(decoded['intersectingDiscCount'], 2);
        expect(decoded['medianMs'], 1.2, reason: 'sorted [0.8, 1.2] → index 1');
        expect(decoded['p95Ms'], 1.2);
        expect(decoded['maxMs'], 1.2);
        // Invariant 6 — wall-clock epoch second so post-walk grep can join the four diag streams.
        final int epochSecond = decoded['epochSecond']! as int;
        final int nowSecond = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect((nowSecond - epochSecond).abs(), lessThanOrEqualTo(1));
      } finally {
        await sub.cancel();
      }
    });

    test('idle seconds emit no log line', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      try {
        final SdfRebuildLogger logger = SdfRebuildLogger(rollupInterval: const Duration(milliseconds: 100));
        logger.start();
        await Future<void>.delayed(const Duration(milliseconds: 350));
        logger.stop();
        expect(captured, isEmpty);
      } finally {
        await sub.cancel();
      }
    });

    test('stop() flushes pending samples before a timer tick and is idempotent', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      try {
        final SdfRebuildLogger logger = SdfRebuildLogger(rollupInterval: const Duration(seconds: 10));
        logger.start();
        logger.recordRebuild(elapsedMs: 2.5, discCount: 3, intersectingDiscCount: 1);
        logger.stop();
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(1));
        expect(captured.first.message, contains('"rebuildCount":1'));
        expect(captured.first.message, contains('"discCount":3'));
      } finally {
        await sub.cancel();
      }
    });

    test('verbose gate — nothing is recorded nor emitted while FINE is not loggable', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      Logger.root.level = Level.INFO;
      try {
        final SdfRebuildLogger logger = SdfRebuildLogger(rollupInterval: const Duration(milliseconds: 50));
        logger.start();
        logger.recordRebuild(elapsedMs: 1.0, discCount: 1, intersectingDiscCount: 1);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured, isEmpty, reason: 'production level (INFO) must keep the diagnostic silent');
      } finally {
        Logger.root.level = Level.ALL;
        await sub.cancel();
      }
    });

    test('verbose gate — toggling FINE on at runtime activates the rollup without a restart', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      Logger.root.level = Level.INFO;
      try {
        final SdfRebuildLogger logger = SdfRebuildLogger(rollupInterval: const Duration(seconds: 10));
        logger.start();
        logger.recordRebuild(elapsedMs: 1.0, discCount: 1, intersectingDiscCount: 1);
        Logger.root.level = Level.ALL;
        logger.recordRebuild(elapsedMs: 3.0, discCount: 4, intersectingDiscCount: 2);
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(1));
        final Map<String, Object?> decoded = json.decode(captured.single.message) as Map<String, Object?>;
        expect(decoded['rebuildCount'], 1, reason: 'the sample recorded while gated is dropped, the one after the toggle is kept');
        expect(decoded['discCount'], 4);
      } finally {
        Logger.root.level = Level.ALL;
        await sub.cancel();
      }
    });
  });
}
