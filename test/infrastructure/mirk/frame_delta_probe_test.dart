// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/infrastructure/mirk/frame_delta_probe_test.dart — FOG-08 / PERF-07
// (+ verbose-gating cases specific to MirkFall, CLAUDE.md §Logging).

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';

/// FrameDeltaProbe rollup correctness, dual-clock discipline and verbose gating.
///
/// The POC cases drive synthetic samples via the `debugRecordRawDelta(micros)`
/// `@visibleForTesting` seam (deterministic; the production path adds
/// real-clock jitter). The gating cases use `fake_async` so a whole rollup
/// window elapses without waiting.
void main() {
  const String loggerName = 'infrastructure.mirk.frame_delta';
  const Duration testInterval = Duration(milliseconds: 100);
  late Level previousLevel;

  setUp(() {
    previousLevel = Logger.root.level;
    // Verbose: the probe is gated on `isLoggable(Level.FINE)` (CLAUDE.md §Logging).
    Logger.root.level = Level.ALL;
  });
  tearDown(() => Logger.root.level = previousLevel);

  group('FrameDeltaProbe (FOG-08)', () {
    test('emitRollup computes correct median/p95/max from injected deltas', () async {
      final probe = FrameDeltaProbe(rollupInterval: testInterval);
      addTearDown(() async => probe.dispose());
      for (var i = 1; i <= 10; i++) {
        probe.debugRecordRawDelta(i * 1000); // 1ms, 2ms, ..., 10ms
      }
      probe.start();
      final rollup = await probe.rollups.first.timeout(const Duration(seconds: 1));
      expect(rollup.sampleCount, 10);
      // sorted indices: [1000, 2000, ..., 10000]; sorted[10 ~/ 2] = sorted[5] = 6000.
      expect(rollup.medianMicros, 6000);
      // sorted[(10*0.95).floor()] = sorted[9] = 10000.
      expect(rollup.p95Micros, 10000);
      expect(rollup.maxMicros, 10000);
    });

    test('idle window emits nothing (empty buffer skips rollup)', () async {
      final probe = FrameDeltaProbe(rollupInterval: testInterval);
      addTearDown(() async => probe.dispose());
      var emissionCount = 0;
      final subscription = probe.rollups.listen((_) => emissionCount++);
      addTearDown(subscription.cancel);
      probe.start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(emissionCount, 0);
    });

    test('non-monotonic input clamps at 0 (production path, no throw)', () async {
      final probe = FrameDeltaProbe(rollupInterval: testInterval);
      addTearDown(() async => probe.dispose());
      probe.start();
      // A snapshotMicros far in the future MUST clamp the delta at 0, not throw.
      expect(() => probe.recordFogUniformPopulation(_farFutureMicros), returnsNormally);
      probe.debugRecordRawDelta(5000);
      final rollup = await probe.rollups.first.timeout(const Duration(seconds: 1));
      // Sorted buffer is [0, 5000]; median = sorted[2 ~/ 2] = sorted[1] = 5000.
      expect(rollup.sampleCount, 2);
      expect(rollup.medianMicros, greaterThanOrEqualTo(0));
      expect(rollup.maxMicros, 5000);
    });

    test('JSONL line via Logger contains all 8 keys', () async {
      final captured = <String>[];
      final logSubscription = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen((r) => captured.add(r.message));
      addTearDown(logSubscription.cancel);

      final probe = FrameDeltaProbe(rollupInterval: testInterval);
      addTearDown(() async => probe.dispose());
      probe.debugRecordRawDelta(1000);
      probe.debugRecordRawDelta(2000);
      probe.start();
      await probe.rollups.first.timeout(const Duration(seconds: 1));

      expect(captured, isNotEmpty);
      final decoded = json.decode(captured.first) as Map<String, Object?>;
      expect(decoded.keys, containsAll(<String>['epochSecond', 'sampleCount', 'medianMicros', 'p95Micros', 'maxMicros', 'medianMs', 'p95Ms', 'maxMs']));
      expect(decoded['sampleCount'], 2);
    });

    test('buffer caps at kMirkFogDiagFrameDeltaBufferMaxSamples (240) — oldest dropped FIFO', () async {
      final probe = FrameDeltaProbe(rollupInterval: testInterval);
      addTearDown(() async => probe.dispose());
      for (var i = 0; i < 300; i++) {
        probe.debugRecordRawDelta(1000 + i);
      }
      probe.start();
      final rollup = await probe.rollups.first.timeout(const Duration(seconds: 1));
      expect(rollup.sampleCount, kMirkFogDiagFrameDeltaBufferMaxSamples);
      // Oldest 60 (1000..1059) were dropped — max is 1299 (= 1000 + 299).
      expect(rollup.maxMicros, 1299);
    });

    test('dispose() closes the stream and is idempotent', () async {
      final probe = FrameDeltaProbe(rollupInterval: testInterval);
      final streamFuture = expectLater(probe.rollups, emitsDone);
      await probe.dispose();
      await streamFuture;
      await expectLater(probe.dispose(), completes);
    });

    test('wall-clock epochSecond ≈ DateTime.now() (dual-clock invariant)', () async {
      final probe = FrameDeltaProbe(rollupInterval: testInterval);
      addTearDown(() async => probe.dispose());
      probe.debugRecordRawDelta(5000);
      probe.start();
      final rollup = await probe.rollups.first.timeout(const Duration(seconds: 1));
      final wallClockNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect((wallClockNow - rollup.epochSecond).abs(), lessThanOrEqualTo(1));
      // A Stopwatch-derived tag would be tiny (seconds since construction), not ~1.7e9.
      expect(rollup.epochSecond, greaterThan(1_700_000_000));
    });
  });

  group('FrameDeltaProbe verbose gating (CLAUDE.md §Logging)', () {
    test('non-verbose (root INFO): start + records + elapsed rollup windows emit NO LogRecord and NO stream rollup', () {
      Logger.root.level = Level.INFO;
      fakeAsync((FakeAsync async) {
        final captured = <LogRecord>[];
        final logSubscription = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
        final probe = FrameDeltaProbe(rollupInterval: testInterval);
        var emissionCount = 0;
        final rollupSubscription = probe.rollups.listen((_) => emissionCount++);
        probe.start();
        final snapshot = probe.recordCameraSnapshot();
        for (var i = 0; i < 5; i++) {
          probe.recordFogUniformPopulation(snapshot);
        }
        probe.debugRecordRawDelta(5000);
        async.elapse(testInterval * 3);
        async.flushMicrotasks();
        expect(captured, isEmpty, reason: 'production must not pay for the diagnostic (no INFO rollup line)');
        expect(emissionCount, 0, reason: 'the rollup stream stays silent when not verbose');
        probe.stop();
        logSubscription.cancel();
        rollupSubscription.cancel();
      });
    });

    test('verbose (root ALL): one JSONL record per rollup window', () {
      fakeAsync((FakeAsync async) {
        final captured = <LogRecord>[];
        final logSubscription = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
        final probe = FrameDeltaProbe(rollupInterval: testInterval);
        probe.start();
        probe.recordFogUniformPopulation(probe.recordCameraSnapshot());
        async.elapse(testInterval);
        async.flushMicrotasks();
        expect(captured, hasLength(1));
        probe.recordFogUniformPopulation(probe.recordCameraSnapshot());
        async.elapse(testInterval);
        async.flushMicrotasks();
        expect(captured, hasLength(2));
        expect((json.decode(captured.last.message) as Map<String, Object?>)['sampleCount'], 1);
        probe.stop();
        logSubscription.cancel();
      });
    });

    test('recordFogUniformPopulation before start() is a no-op', () {
      fakeAsync((FakeAsync async) {
        final captured = <LogRecord>[];
        final logSubscription = Logger.root.onRecord.where((r) => r.loggerName == loggerName).listen(captured.add);
        final probe = FrameDeltaProbe(rollupInterval: testInterval);
        probe.recordFogUniformPopulation(probe.recordCameraSnapshot());
        probe.start();
        async.elapse(testInterval * 2);
        async.flushMicrotasks();
        expect(captured, isEmpty, reason: 'samples recorded before start() are dropped');
        probe.stop();
        logSubscription.cancel();
      });
    });

    test('stop() is idempotent and start() after stop() re-arms the timer', () {
      fakeAsync((FakeAsync async) {
        final probe = FrameDeltaProbe(rollupInterval: testInterval);
        expect(probe.isRunning, isFalse);
        probe.stop();
        probe.stop();
        expect(probe.isRunning, isFalse);
        probe.start();
        probe.start();
        expect(probe.isRunning, isTrue);
        probe.stop();
        probe.stop();
        expect(probe.isRunning, isFalse);
        expect(async.periodicTimerCount, 0);
      });
    });
  });
}

/// A microsecond reading far enough in the future that a real
/// Stopwatch.elapsedMicroseconds can never exceed it during the test run —
/// exercises the monotonic guard in `recordFogUniformPopulation`.
const int _farFutureMicros = 1 << 50;
