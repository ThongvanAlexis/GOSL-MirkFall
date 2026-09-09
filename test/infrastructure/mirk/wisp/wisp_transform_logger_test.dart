// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-05 — `WispTransformLogger` 1 Hz JSONL rollup (POC WISP-05 port) + the
// verbose gate every Phase 09.1 diagnostic logger carries (silent unless
// `Logger('infrastructure.mirk.wisp').isLoggable(Level.FINE)`).
//
// Determinism: the meanAge fixture is 8 distinct doubles whose sorted median (index 4) is the
// 5th element exactly; `epochSecond` is compared to the wall clock ±1 s (invariant 6).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_transform_logger.dart';

const String _loggerName = 'infrastructure.mirk.wisp';

void _recordConstant(WispTransformLogger logger, {required int activeCount, required double meanAge, double spawnRate = 5.0}) {
  logger.recordPaint(
    activeCount: activeCount,
    meanAge: meanAge,
    latBounds: (48.5390, 48.5410),
    lonBounds: (2.6550, 2.6570),
    screenXBounds: (100.0, 200.0),
    screenYBounds: (300.0, 400.0),
    spawnRatePerSecond: spawnRate,
  );
}

void main() {
  setUpAll(() {
    Logger.root.level = Level.ALL;
  });

  group('09.1-05 — WispTransformLogger (WISP-05)', () {
    test('recordPaint buffers; one JSONL rollup per active second with activeCount / meanAge / bounds / spawnRate stats', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      try {
        final WispTransformLogger logger = WispTransformLogger(rollupInterval: const Duration(milliseconds: 100));
        logger.start();
        for (int i = 0; i < 8; i++) {
          _recordConstant(logger, activeCount: 10 + i, meanAge: 0.1 + i * 0.1);
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
        logger.stop();

        expect(captured, hasLength(greaterThanOrEqualTo(1)));
        final Map<String, Object?> decoded = json.decode(captured.first.message) as Map<String, Object?>;
        expect(
          decoded.keys,
          containsAll(<String>[
            'epochSecond',
            'sampleCount',
            'activeCountMax',
            'activeCountMean',
            'meanAgeMin',
            'meanAgeMedian',
            'meanAgeMax',
            'latMinMin',
            'latMinMedian',
            'latMinMax',
            'latMaxMin',
            'latMaxMedian',
            'latMaxMax',
            'lonMinMin',
            'lonMinMedian',
            'lonMinMax',
            'lonMaxMin',
            'lonMaxMedian',
            'lonMaxMax',
            'screenXMinMin',
            'screenXMinMedian',
            'screenXMinMax',
            'screenXMaxMin',
            'screenXMaxMedian',
            'screenXMaxMax',
            'screenYMinMin',
            'screenYMinMedian',
            'screenYMinMax',
            'screenYMaxMin',
            'screenYMaxMedian',
            'screenYMaxMax',
            'spawnRatePerSecondMin',
            'spawnRatePerSecondMedian',
            'spawnRatePerSecondMax',
          ]),
        );
        expect(decoded['sampleCount'], 8);
        expect(decoded['activeCountMax'], 17);
        expect(decoded['activeCountMean'], '13.500000');
        expect(decoded['meanAgeMin'], '0.100000');
        expect(decoded['meanAgeMedian'], '0.500000');
        expect(decoded['meanAgeMax'], '0.800000');
        expect(decoded['latMinMedian'], '48.539000');
        expect(decoded['latMaxMedian'], '48.541000');
        expect(decoded['lonMinMedian'], '2.655000');
        expect(decoded['lonMaxMedian'], '2.657000');
        expect(decoded['screenXMinMedian'], '100.000000');
        expect(decoded['screenXMaxMedian'], '200.000000');
        expect(decoded['screenYMinMedian'], '300.000000');
        expect(decoded['screenYMaxMedian'], '400.000000');
        expect(decoded['spawnRatePerSecondMedian'], '5.000000');
        // Invariant 6 — `epochSecond` = millisecondsSinceEpoch ~/ 1000 of the wall clock.
        final int epochSecond = decoded['epochSecond']! as int;
        expect((DateTime.now().millisecondsSinceEpoch ~/ 1000 - epochSecond).abs(), lessThanOrEqualTo(1));

        // Buffer cleared after emit: one more paint + stop() → a second rollup with sampleCount 1.
        final int before = captured.length;
        logger.start();
        _recordConstant(logger, activeCount: 99, meanAge: 0.9, spawnRate: 0.0);
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured.length, before + 1);
        final Map<String, Object?> second = json.decode(captured.last.message) as Map<String, Object?>;
        expect(second['sampleCount'], 1);
        expect(second['activeCountMax'], 99);
      } finally {
        await sub.cancel();
      }
    });

    test('idle seconds emit no log line — WISP-05', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      try {
        final WispTransformLogger logger = WispTransformLogger(rollupInterval: const Duration(milliseconds: 100));
        logger.start();
        await Future<void>.delayed(const Duration(milliseconds: 350));
        logger.stop();
        expect(captured, isEmpty);
      } finally {
        await sub.cancel();
      }
    });

    test('buffer caps at kMirkFogDiagWispTransformBufferMaxSamples — oldest dropped FIFO — WISP-05', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      try {
        final WispTransformLogger logger = WispTransformLogger(rollupInterval: const Duration(seconds: 60));
        logger.start();
        final int overflow = kMirkFogDiagWispTransformBufferMaxSamples + 5;
        for (int i = 0; i < overflow; i++) {
          _recordConstant(logger, activeCount: i, meanAge: i * 0.001, spawnRate: 0.0);
        }
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(1));
        final Map<String, Object?> decoded = json.decode(captured.first.message) as Map<String, Object?>;
        expect(decoded['sampleCount'], kMirkFogDiagWispTransformBufferMaxSamples);
        expect(decoded['activeCountMax'], overflow - 1);
      } finally {
        await sub.cancel();
      }
    });

    test('stop() flushes pending samples before a timer tick and is idempotent — WISP-05', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      try {
        final WispTransformLogger logger = WispTransformLogger(rollupInterval: const Duration(seconds: 10));
        logger.start();
        _recordConstant(logger, activeCount: 42, meanAge: 0.5, spawnRate: 7.5);
        _recordConstant(logger, activeCount: 43, meanAge: 0.6, spawnRate: 7.5);
        _recordConstant(logger, activeCount: 44, meanAge: 0.7, spawnRate: 7.5);
        logger.stop();
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(1));
        final Map<String, Object?> decoded = json.decode(captured.first.message) as Map<String, Object?>;
        expect(decoded['sampleCount'], 3);
        expect(decoded['activeCountMax'], 44);
        expect(decoded['spawnRatePerSecondMedian'], '7.500000');
      } finally {
        await sub.cancel();
      }
    });

    test('computeStats returns (first, middle, last) on a non-empty sorted list — WISP-05', () {
      final (double, double, double) stats = WispTransformLogger.computeStats(<double>[1.0, 2.0, 3.0, 4.0, 5.0]);
      expect(stats.$1, 1.0);
      expect(stats.$2, 3.0);
      expect(stats.$3, 5.0);
    });

    test('verbose gate — nothing is recorded nor emitted while FINE is not loggable', () async {
      final List<LogRecord> captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((LogRecord r) => r.loggerName == _loggerName).listen(captured.add);
      Logger.root.level = Level.INFO;
      try {
        final WispTransformLogger logger = WispTransformLogger(rollupInterval: const Duration(milliseconds: 50));
        logger.start();
        _recordConstant(logger, activeCount: 1, meanAge: 0.5);
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
        final WispTransformLogger logger = WispTransformLogger(rollupInterval: const Duration(seconds: 10));
        logger.start();
        _recordConstant(logger, activeCount: 1, meanAge: 0.5);
        Logger.root.level = Level.ALL;
        _recordConstant(logger, activeCount: 7, meanAge: 0.5);
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(1));
        final Map<String, Object?> decoded = json.decode(captured.single.message) as Map<String, Object?>;
        expect(decoded['sampleCount'], 1, reason: 'the sample recorded while gated is dropped, the one after the toggle is kept');
        expect(decoded['activeCountMax'], 7);
      } finally {
        Logger.root.level = Level.ALL;
        await sub.cancel();
      }
    });
  });
}
