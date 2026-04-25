// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Observable fake for the Phase 09 `RevealStreamingController` (plan
/// 09-06). Lets widget + integration suites assert how many times
/// `onFix`, `revealInitial`, `flush`, and `dispose` were invoked
/// without driving a real `RevealedTileStore` or computing actual
/// reveal masks.
///
/// Wave 0 keeps the surface dependency-free — does NOT
/// `implements RevealStreamingController` because that class lands in
/// plan 09-06. Wave 5 (when 09-06 ships) extends this fake to
/// `implements RevealStreamingController` so the type system enforces
/// surface conformance.
///
/// The recorded shapes use plain Dart records (e.g.
/// `({double lat, double lon, double accuracy})`) instead of Phase
/// types so this file can compile in Wave 0 before
/// `lib/application/controllers/reveal_streaming_controller.dart` is
/// frozen.
class FakeRevealStreamingController {
  /// Every fix passed to [onFix], in call order.
  final List<({double lat, double lon, double accuracyMeters, DateTime timestampUtc})> onFixCalls =
      <({double lat, double lon, double accuracyMeters, DateTime timestampUtc})>[];

  /// Every starter-reveal trigger passed to [revealInitial], in call order.
  final List<({double lat, double lon, double radiusMeters})> revealInitialCalls = <({double lat, double lon, double radiusMeters})>[];

  /// Number of times [flush] has been called.
  int flushCallCount = 0;

  /// Number of times [dispose] has been called.
  int disposeCallCount = 0;

  /// When `true`, the next call to any method throws [StateError].
  /// Used by error-path tests to validate the SUT's surfacing
  /// behaviour without changing the controller's surface.
  bool throwOnNextCall = false;

  /// Resets all counters + recorded shapes. Helpful between sub-cases
  /// in a single test that wants to share the fake instance.
  void reset() {
    onFixCalls.clear();
    revealInitialCalls.clear();
    flushCallCount = 0;
    disposeCallCount = 0;
    throwOnNextCall = false;
  }

  /// Records a GPS fix. Wave 5 wires this to the real surface signature
  /// — until then the record shape gives tests deterministic data
  /// without coupling to `lib/domain/fixes/fix.dart`.
  void onFix({required double lat, required double lon, required double accuracyMeters, required DateTime timestampUtc}) {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeRevealStreamingController.onFix forced throw');
    }
    onFixCalls.add((lat: lat, lon: lon, accuracyMeters: accuracyMeters, timestampUtc: timestampUtc));
  }

  /// Records a session-start initial-reveal trigger.
  void revealInitial({required double lat, required double lon, required double radiusMeters}) {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeRevealStreamingController.revealInitial forced throw');
    }
    revealInitialCalls.add((lat: lat, lon: lon, radiusMeters: radiusMeters));
  }

  /// Records a manual flush call.
  Future<void> flush() async {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeRevealStreamingController.flush forced throw');
    }
    flushCallCount++;
  }

  /// Records a dispose call.
  Future<void> dispose() async {
    if (throwOnNextCall) {
      throwOnNextCall = false;
      throw StateError('FakeRevealStreamingController.dispose forced throw');
    }
    disposeCallCount++;
  }
}
