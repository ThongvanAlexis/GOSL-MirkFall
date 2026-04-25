// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/logging/file_logger_lifecycle_observer.dart';

/// Structural tests for [FileLoggerLifecycleObserver] — verify the
/// observer fans `AppLifecycleState` transitions out of `resumed` to
/// the injected flush callback. We do NOT exercise the real
/// [FileLogger.flush] here (covered by file_logger_test.dart); the goal
/// is to lock in the lifecycle → flush wiring against future regressions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileLoggerLifecycleObserver', () {
    test('flushes on AppLifecycleState.paused (screen lock / app switcher)', () async {
      var flushCount = 0;
      final observer = FileLoggerLifecycleObserver.withFlush(() async {
        flushCount++;
      });

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      // The observer fires the flush as a fire-and-forget Future; pump a
      // microtask so the awaited body of our test callback runs before the
      // assertion.
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, equals(1), reason: 'paused must trigger exactly one flush');
    });

    test('flushes on AppLifecycleState.inactive (transient transition)', () async {
      var flushCount = 0;
      final observer = FileLoggerLifecycleObserver.withFlush(() async {
        flushCount++;
      });

      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, equals(1));
    });

    test('flushes on AppLifecycleState.detached (process dying — best effort)', () async {
      var flushCount = 0;
      final observer = FileLoggerLifecycleObserver.withFlush(() async {
        flushCount++;
      });

      observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, equals(1));
    });

    test('flushes on AppLifecycleState.hidden (Flutter 3.13+ hidden state)', () async {
      var flushCount = 0;
      final observer = FileLoggerLifecycleObserver.withFlush(() async {
        flushCount++;
      });

      observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, equals(1));
    });

    test('does NOT flush on AppLifecycleState.resumed (buffer was already drained)', () async {
      var flushCount = 0;
      final observer = FileLoggerLifecycleObserver.withFlush(() async {
        flushCount++;
      });

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, equals(0), reason: 'resumed must be a no-op — flushing here would be a wasted syscall');
    });

    test('a paused → resumed → paused cycle fires exactly two flushes', () async {
      var flushCount = 0;
      final observer = FileLoggerLifecycleObserver.withFlush(() async {
        flushCount++;
      });

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, equals(2));
    });
  });
}
