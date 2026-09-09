// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Controllable [Stopwatch] for the wisp warm-up gate (`WispParticleSystem(wallClock:)`) and any
/// other elapsed-time seam — avoids `Future.delayed(Duration(seconds: 5))` in suites that must
/// prove the BUG-015 5 s warm-up. Shared by `test/infrastructure/mirk/wisp/*`, the renderer
/// suites and the 09.1-07 `fog_layer_wisp_render_test`.
///
/// Only the `elapsed*` getters and [advance] are implemented; any other `Stopwatch` member throws
/// through [noSuchMethod] so a production call the fake does not model fails loudly instead of
/// silently returning a bogus value.
class FakeStopwatch implements Stopwatch {
  FakeStopwatch({int initialMs = 0}) : _elapsedMs = initialMs;

  int _elapsedMs;

  /// Advances the fake clock forward by [milliseconds].
  void advance(int milliseconds) => _elapsedMs += milliseconds;

  @override
  int get elapsedMilliseconds => _elapsedMs;

  @override
  int get elapsedMicroseconds => _elapsedMs * Duration.microsecondsPerMillisecond;

  @override
  Duration get elapsed => Duration(milliseconds: _elapsedMs);

  // `dynamic` is imposed by the `Object.noSuchMethod` signature — the only place the project
  // tolerates it. Every unmodelled member is a test-fake bug, hence the throw.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeStopwatch: ${invocation.memberName} is not modelled (production code should not call it)');
}
