// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';

import '../../fakes/fake_map_view.dart';

/// Test seam helpers.
ProviderContainer _makeContainer({MapView? initialView}) {
  return ProviderContainer(overrides: [mapViewProvider.overrideWith(() => _SeededMapViewHolder(initialView))]);
}

/// Notifier override that returns a pre-seeded [MapView] reference at
/// build-time so the subscription-establishing code path in
/// [mapViewportProvider] runs immediately without a separate `set()` call
/// being scheduled by the widget layer.
class _SeededMapViewHolder extends MapViewHolder {
  _SeededMapViewHolder(this._initial);
  final MapView? _initial;

  @override
  MapView? build() => _initial;
}

MirkViewportBbox _bbox({double s = -1.0, double w = -2.0, double n = 1.0, double e = 2.0}) {
  return MirkViewportBbox(south: s, west: w, north: n, east: e);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mapViewportProvider', () {
    test('returns null while MapView is not yet attached', () async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      // No view → provider stays null.
      expect(container.read(mapViewportProvider), isNull);
    });

    test('seeds the bbox from queryViewportBounds on first build', () async {
      final fake = FakeMapView();
      fake.viewportBoundsToReturn = _bbox(s: 10.0, w: 20.0, n: 11.0, e: 21.0);
      final container = _makeContainer(initialView: fake);
      addTearDown(container.dispose);

      // Provider read kicks off the build + the unawaited seed call.
      expect(container.read(mapViewportProvider), isNull);

      // Drain the microtask + the awaited queryViewportBounds.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapViewportProvider);
      expect(state, isNotNull);
      expect(state!.south, 10.0);
      expect(state.north, 11.0);
      expect(state.west, 20.0);
      expect(state.east, 21.0);
      // Seed counts as one call.
      expect(fake.queryViewportBoundsCallCount, 1);
    });

    test('viewport emission triggers a leading-edge refresh (no debounce wait)', () async {
      // BUG-005 (2026-04-25) — switched from 50 ms debounce to leading-
      // edge throttle. The first emission of a burst fires
      // queryViewportBounds IMMEDIATELY so the fog tracks pan / pinch /
      // zoom in realtime instead of snapping to the new bbox at gesture
      // release.
      final fake = FakeMapView();
      fake.viewportBoundsToReturn = _bbox(s: 0.0, w: 0.0);
      final container = _makeContainer(initialView: fake);
      addTearDown(container.dispose);

      // Build + drain the seed.
      container.read(mapViewportProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(fake.queryViewportBoundsCallCount, 1);

      // Push a new viewport and switch the bbox the fake will return.
      fake.viewportBoundsToReturn = _bbox(s: 5.0, w: 6.0, n: 7.0, e: 8.0);
      fake.pushViewport(latitude: 6.0, longitude: 7.0, zoom: 12.0);

      // Leading edge — refresh fired synchronously. Drain the
      // queryViewportBounds future + the `state =` assignment.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(fake.queryViewportBoundsCallCount, 2, reason: 'leading-edge throttle fires queryViewportBounds immediately on the first emission of a burst');
      final state = container.read(mapViewportProvider);
      expect(state, isNotNull);
      expect(state!.south, 5.0);
    });

    test('rapid-fire emissions inside one window: 1 leading + 1 trailing refresh', () async {
      // Continuous-gesture pattern. Three emissions arrive within the
      // 50 ms throttle window. Expectation:
      //  - First emission → leading-edge refresh fires immediately.
      //  - 2nd + 3rd emissions → coalesced into the trailing slot.
      //  - At window expiry → one more (trailing) refresh.
      // Total refreshes on top of the seed: 2 (leading + trailing), not 3.
      final fake = FakeMapView();
      fake.viewportBoundsToReturn = _bbox();
      final container = _makeContainer(initialView: fake);
      addTearDown(container.dispose);

      container.read(mapViewportProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final seedCalls = fake.queryViewportBoundsCallCount;

      fake.pushViewport(latitude: 1.0, longitude: 1.0, zoom: 12.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      fake.pushViewport(latitude: 2.0, longitude: 2.0, zoom: 12.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      fake.pushViewport(latitude: 3.0, longitude: 3.0, zoom: 12.0);
      // Wait past the throttle window so the trailing refresh fires.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // Drain the trailing async queryViewportBounds + state assignment.
      await Future<void>.delayed(Duration.zero);

      expect(
        fake.queryViewportBoundsCallCount,
        seedCalls + 2,
        reason: 'expected leading-edge refresh + trailing refresh = 2 calls on top of the seed (got ${fake.queryViewportBoundsCallCount - seedCalls})',
      );
    });

    test('continuous emissions across multiple windows refresh at throttle cadence (BUG-005 realtime tracking)', () async {
      // The user-visible scenario. Sustained pan generates one emission
      // per frame (~16 ms), spanning many throttle windows. The provider
      // must publish updated bboxes at the throttle cadence (1 per
      // window), NOT wait for the gesture to end before publishing.
      //
      // 200 ms of continuous emissions @ 10 ms cadence = 20 emissions.
      // With a 50 ms window, expect roughly 4-5 refreshes on top of the
      // seed (one per window: leading, then trailing-chained). The exact
      // count depends on timer alignment so we assert a range.
      final fake = FakeMapView();
      fake.viewportBoundsToReturn = _bbox(s: 0.0);
      final container = _makeContainer(initialView: fake);
      addTearDown(container.dispose);

      container.read(mapViewportProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final seedCalls = fake.queryViewportBoundsCallCount;

      // 20 emissions @ 10 ms intervals = ~200 ms of "continuous gesture".
      // Each iteration's bbox shifts south by 1° while keeping a 1° span
      // (south < north invariant must hold — see MirkViewportBbox assert).
      for (var i = 0; i < 20; i++) {
        final s = i.toDouble();
        fake.viewportBoundsToReturn = _bbox(s: s, n: s + 1.0, w: 0.0, e: 1.0);
        fake.pushViewport(latitude: s, longitude: s, zoom: 12.0);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // Drain the trailing-window timer + the final async queryViewportBounds.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await Future<void>.delayed(Duration.zero);

      final extraCalls = fake.queryViewportBoundsCallCount - seedCalls;
      // 200 ms of activity through 50 ms windows ≈ 4-5 windows fired.
      // Lower bound 3 is the safety net for timer-alignment jitter; the
      // important assertion is "more than 1" — pre-fix would have fired
      // exactly 1 at the very end of the gesture.
      expect(
        extraCalls,
        greaterThanOrEqualTo(3),
        reason:
            'BUG-005: continuous emissions must produce multiple refreshes (>=3) across the gesture, '
            'not a single one at the end. Got $extraCalls. Pre-fix debounce would have fired exactly 1.',
      );
      // Final state is the LAST pushed bbox (trailing refresh captures it).
      final state = container.read(mapViewportProvider);
      expect(state, isNotNull);
      expect(state!.south, 19.0, reason: 'trailing refresh must capture the final viewport at gesture end');
    });

    test('queryViewportBounds error is silently dropped — provider stays null', () async {
      final fake = FakeMapView();
      // viewportBoundsToReturn left null → fake throws on call.
      final container = _makeContainer(initialView: fake);
      addTearDown(container.dispose);

      container.read(mapViewportProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Provider state stays null (seed threw, was caught).
      expect(container.read(mapViewportProvider), isNull);
      // The next successful emission recovers.
      fake.viewportBoundsToReturn = _bbox(s: 4.0, w: 5.0, n: 6.0, e: 7.0);
      fake.pushViewport(latitude: 5.0, longitude: 6.0, zoom: 10.0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(container.read(mapViewportProvider), isNotNull);
    });
  });
}
