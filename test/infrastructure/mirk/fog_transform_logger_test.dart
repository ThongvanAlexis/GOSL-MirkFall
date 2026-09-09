// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/infrastructure/mirk/fog_transform_logger_test.dart — FOG-10
// (+ verbose-gating cases specific to MirkFall, CLAUDE.md §Logging).

import 'dart:convert';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';

/// FogTransformLogger rollup of per-paint Canvas-transform vs camera-pixelOrigin
/// vs applied-pixelOrigin diagnostics, JSONL contract and verbose gating.
void main() {
  const String loggerName = 'infrastructure.mirk.fog_transform';
  const Duration testInterval = Duration(milliseconds: 100);
  const GeoPoint melun = (latitude: 48.5397, longitude: 2.6553);
  late Level previousLevel;

  setUp(() {
    previousLevel = Logger.root.level;
    // Verbose: the logger is gated on `isLoggable(Level.FINE)` (CLAUDE.md §Logging).
    Logger.root.level = Level.ALL;
  });
  tearDown(() => Logger.root.level = previousLevel);

  group('FogTransformLogger (FOG-10)', () {
    test('recordPaint buffers samples; emits one JSONL rollup per active window with min/median/max for the 15 diagnostic fields', () async {
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        final logger = FogTransformLogger(rollupInterval: testInterval);
        logger.start();
        // pixelOriginX 100/200/300 → min 100, median sorted[1] = 200, max 300.
        for (final double pixelOriginX in <double>[100.0, 200.0, 300.0]) {
          logger.recordPaint(
            canvasTransform: _matrixWithTranslation(tx: 0.0, ty: 0.0),
            cameraPixelOrigin: Point<double>(pixelOriginX, 50.0),
            cameraCenter: melun,
            appliedPixelOrigin: (x: pixelOriginX, y: 50.0),
            uResolutionX: 1080.0,
            uResolutionY: 1920.0,
            zoom: 13.0,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
        logger.stop();
        expect(captured, hasLength(greaterThanOrEqualTo(1)));
        final decoded = json.decode(captured.first.message) as Map<String, Object?>;
        expect(decoded.keys, containsAll(_kExpectedJsonKeys));
        expect(decoded.keys, hasLength(_kExpectedJsonKeys.length), reason: '47 keys: epochSecond + sampleCount + 15 fields × (Min, Median, Max)');
        expect(decoded['sampleCount'], 3);
        expect(decoded['pixelOriginXMin'], '100.000000');
        expect(decoded['pixelOriginXMedian'], '200.000000');
        expect(decoded['pixelOriginXMax'], '300.000000');
        expect(decoded['uOffsetXMax'], '300.000000', reason: 'uOffset* keys carry the applied pixelOrigin (POC key kept for the grep tooling)');
        expect(decoded['canvasSxMedian'], '1.000000', reason: 'scale / shear are read from the matrix by the logger');
        expect(decoded['canvasShearYXMedian'], '0.000000');
        expect(decoded['centerLatMedian'], '48.539700');
      } finally {
        await sub.cancel();
      }
    });

    test('idle windows emit no log line', () async {
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        final logger = FogTransformLogger(rollupInterval: testInterval);
        logger.start();
        await Future<void>.delayed(const Duration(milliseconds: 350));
        logger.stop();
        expect(captured, isEmpty);
      } finally {
        await sub.cancel();
      }
    });

    test('buffer caps at kMirkFogDiagFogTransformBufferMaxSamples (240) — oldest dropped FIFO', () async {
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        final logger = FogTransformLogger(rollupInterval: testInterval);
        logger.start();
        for (var i = 0; i < 300; i++) {
          logger.recordPaint(
            canvasTransform: _matrixWithTranslation(tx: 0.0, ty: 0.0),
            cameraPixelOrigin: Point<double>(i.toDouble(), i.toDouble()),
            cameraCenter: melun,
            appliedPixelOrigin: (x: i.toDouble(), y: i.toDouble()),
            uResolutionX: 1080.0,
            uResolutionY: 1920.0,
            zoom: 13.0,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
        logger.stop();
        expect(captured, isNotEmpty);
        final decoded = json.decode(captured.first.message) as Map<String, Object?>;
        expect(decoded['sampleCount'], kMirkFogDiagFogTransformBufferMaxSamples);
        // Oldest 60 (i = 0..59) dropped; remaining samples 60..299.
        expect(decoded['pixelOriginXMin'], '60.000000');
        expect(decoded['pixelOriginXMax'], '299.000000');
      } finally {
        await sub.cancel();
      }
    });

    test('stop flushes pending samples even before a timer tick', () async {
      final captured = <LogRecord>[];
      final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
      try {
        // Long interval: the timer never fires — proves stop() flushes synchronously.
        final logger = FogTransformLogger(rollupInterval: const Duration(seconds: 10));
        logger.start();
        logger.recordPaint(
          canvasTransform: _matrixWithTranslation(tx: 12.5, ty: 7.25),
          cameraPixelOrigin: const Point<double>(1024.0, 768.0),
          cameraCenter: melun,
          appliedPixelOrigin: (x: 1024.0, y: -768.0),
          uResolutionX: 1080.0,
          uResolutionY: 1920.0,
          zoom: 13.0,
        );
        logger.stop();
        await Future<void>.delayed(Duration.zero);
        expect(captured, hasLength(1));
        final decoded = json.decode(captured.first.message) as Map<String, Object?>;
        expect(decoded['sampleCount'], 1);
        expect(decoded['pixelOriginXMedian'], '1024.000000');
        expect(decoded['canvasTxMedian'], '12.500000');
        expect(decoded['canvasTyMedian'], '7.250000');
        expect(decoded['uOffsetYMedian'], '-768.000000', reason: 'the Android FOG-23 sign flip is observable in the applied value');
      } finally {
        await sub.cancel();
      }
    });

    test('computeStats returns (first, middle, last) of a sorted list', () {
      expect(FogTransformLogger.computeStats(<double>[1.0, 2.0, 3.0, 4.0]), equals((1.0, 3.0, 4.0)));
      expect(FogTransformLogger.computeStats(<double>[7.5]), equals((7.5, 7.5, 7.5)));
    });
  });

  group('FogTransformLogger verbose gating (CLAUDE.md §Logging)', () {
    test('non-verbose (root INFO): start + N recordPaint + elapsed windows + stop emit NO LogRecord', () {
      Logger.root.level = Level.INFO;
      fakeAsync((FakeAsync async) {
        final captured = <LogRecord>[];
        final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
        final logger = FogTransformLogger(rollupInterval: testInterval);
        logger.start();
        for (var i = 0; i < 5; i++) {
          _recordSyntheticPaint(logger, pixelOriginX: i.toDouble());
        }
        async.elapse(testInterval * 3);
        async.flushMicrotasks();
        logger.stop();
        async.flushMicrotasks();
        expect(captured, isEmpty, reason: 'production must not pay for the diagnostic (no INFO rollup line, not even on stop())');
        sub.cancel();
      });
    });

    test('verbose (root ALL): one JSONL record per rollup window', () {
      fakeAsync((FakeAsync async) {
        final captured = <LogRecord>[];
        final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
        final logger = FogTransformLogger(rollupInterval: testInterval);
        logger.start();
        _recordSyntheticPaint(logger, pixelOriginX: 1.0);
        async.elapse(testInterval);
        async.flushMicrotasks();
        expect(captured, hasLength(1));
        _recordSyntheticPaint(logger, pixelOriginX: 2.0);
        _recordSyntheticPaint(logger, pixelOriginX: 3.0);
        async.elapse(testInterval);
        async.flushMicrotasks();
        expect(captured, hasLength(2));
        expect((json.decode(captured.last.message) as Map<String, Object?>)['sampleCount'], 2);
        logger.stop();
        sub.cancel();
      });
    });

    test('recordPaint before start() is a no-op', () {
      fakeAsync((FakeAsync async) {
        final captured = <LogRecord>[];
        final sub = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
        final logger = FogTransformLogger(rollupInterval: testInterval);
        _recordSyntheticPaint(logger, pixelOriginX: 1.0);
        logger.start();
        async.elapse(testInterval * 2);
        async.flushMicrotasks();
        logger.stop();
        async.flushMicrotasks();
        expect(captured, isEmpty);
        sub.cancel();
      });
    });

    test('stop() is idempotent', () {
      fakeAsync((FakeAsync async) {
        final logger = FogTransformLogger(rollupInterval: testInterval);
        logger.stop();
        expect(logger.isRunning, isFalse);
        logger.start();
        expect(logger.isRunning, isTrue);
        logger.stop();
        logger.stop();
        expect(logger.isRunning, isFalse);
        expect(async.periodicTimerCount, 0);
      });
    });
  });
}

/// One synthetic paint observation at identity transform.
void _recordSyntheticPaint(FogTransformLogger logger, {required double pixelOriginX}) {
  logger.recordPaint(
    canvasTransform: _matrixWithTranslation(tx: 0.0, ty: 0.0),
    cameraPixelOrigin: Point<double>(pixelOriginX, 0.0),
    cameraCenter: (latitude: 48.5397, longitude: 2.6553),
    appliedPixelOrigin: (x: pixelOriginX, y: 0.0),
    uResolutionX: 400.0,
    uResolutionY: 800.0,
    zoom: 13.0,
  );
}

/// 4×4 column-major identity matrix — synthetic stand-in for `Canvas.getTransform()`.
Float64List _identityMatrix() => Float64List(16)
  ..[0] = 1.0
  ..[5] = 1.0
  ..[10] = 1.0
  ..[15] = 1.0;

/// Identity matrix with translation `(tx, ty)` in the column-major slots `[12]` / `[13]`.
Float64List _matrixWithTranslation({required double tx, required double ty}) {
  final m = _identityMatrix();
  m[kCanvasTransformTxIndex] = tx;
  m[kCanvasTransformTyIndex] = ty;
  return m;
}

/// The 47 JSONL keys of one rollup line.
const List<String> _kExpectedJsonKeys = <String>[
  'epochSecond',
  'sampleCount',
  'canvasTxMin',
  'canvasTxMedian',
  'canvasTxMax',
  'canvasTyMin',
  'canvasTyMedian',
  'canvasTyMax',
  'pixelOriginXMin',
  'pixelOriginXMedian',
  'pixelOriginXMax',
  'pixelOriginYMin',
  'pixelOriginYMedian',
  'pixelOriginYMax',
  'centerLatMin',
  'centerLatMedian',
  'centerLatMax',
  'centerLonMin',
  'centerLonMedian',
  'centerLonMax',
  'uOffsetXMin',
  'uOffsetXMedian',
  'uOffsetXMax',
  'uOffsetYMin',
  'uOffsetYMedian',
  'uOffsetYMax',
  'canvasSxMin',
  'canvasSxMedian',
  'canvasSxMax',
  'canvasSyMin',
  'canvasSyMedian',
  'canvasSyMax',
  'canvasShearYXMin',
  'canvasShearYXMedian',
  'canvasShearYXMax',
  'canvasShearXYMin',
  'canvasShearXYMedian',
  'canvasShearXYMax',
  'uResolutionXMin',
  'uResolutionXMedian',
  'uResolutionXMax',
  'uResolutionYMin',
  'uResolutionYMedian',
  'uResolutionYMax',
  'zoomMin',
  'zoomMedian',
  'zoomMax',
];
