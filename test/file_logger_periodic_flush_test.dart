// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/logging/file_logger.dart';

/// Structural test for the FileLogger periodic-flush backstop.
///
/// We do NOT exercise the real sink here — `file_logger_test.dart` covers
/// end-to-end JSONL write semantics. The goal is to lock in the
/// `Timer.periodic(kFileLoggerFlushPeriodSeconds)` cadence: a future
/// regression that swaps the timer for a one-shot or accidentally
/// disables it would slip past the existing tests but breaks the bug-fix
/// motivating contract.
void main() {
  test('startPeriodicFlushTimer fires the flush callback every kFileLoggerFlushPeriodSeconds seconds', () {
    fakeAsync((async) {
      var flushCount = 0;
      final timer = FileLogger.startPeriodicFlushTimer(() async {
        flushCount++;
      });

      // Tick 1 — exactly one period elapsed.
      async.elapse(const Duration(seconds: kFileLoggerFlushPeriodSeconds));
      expect(flushCount, equals(1), reason: 'one flush after one period');

      // Tick 2 — second period elapsed.
      async.elapse(const Duration(seconds: kFileLoggerFlushPeriodSeconds));
      expect(flushCount, equals(2), reason: 'two flushes after two periods');

      // Tick 3 — third period elapsed.
      async.elapse(const Duration(seconds: kFileLoggerFlushPeriodSeconds));
      expect(flushCount, equals(3), reason: 'three flushes after three periods');

      timer.cancel();

      // Cancellation halts further ticks even as fake time advances.
      async.elapse(const Duration(seconds: kFileLoggerFlushPeriodSeconds * 5));
      expect(flushCount, equals(3), reason: 'cancelled timer must not fire again');
    });
  });

  test('a flush callback throwing does NOT prevent subsequent ticks', () {
    var flushCount = 0;
    final swallowedErrors = <Object>[];
    // Run inside a guarded zone — the deliberate `throw` inside the
    // fire-and-forget callback would otherwise propagate to the test
    // runner as an unhandled async error and fail the test even though
    // the timer behaviour is correct.
    runZonedGuarded(
      () {
        fakeAsync((async) {
          final timer = FileLogger.startPeriodicFlushTimer(() async {
            flushCount++;
            // Simulate a sink-write failure on every tick — fire-and-forget
            // semantics in `Timer.periodic` swallow the error and the timer
            // continues. The real `flush()` already swallows
            // FileSystemException internally; this test just confirms the
            // wrapper does not break that contract.
            throw const FormatException('simulated transient flush failure');
          });

          async.elapse(const Duration(seconds: kFileLoggerFlushPeriodSeconds * 3));
          // Drain the microtasks so the unhandled-error reports are
          // delivered to the guarded zone before the assertions run.
          async.flushMicrotasks();
          timer.cancel();
        });
      },
      (error, stack) {
        swallowedErrors.add(error);
      },
    );

    expect(flushCount, equals(3), reason: 'timer must keep ticking after flush errors');
    // Three thrown errors should have surfaced via the zone error handler
    // (one per tick), confirming we are NOT silently swallowing them.
    expect(swallowedErrors.length, equals(3), reason: 'every tick error must be observable via zone error handler');
  });
}
