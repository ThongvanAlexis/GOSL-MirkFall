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
  return ProviderContainer(
    overrides: [
      mapViewProvider.overrideWith(() => _SeededMapViewHolder(initialView)),
    ],
  );
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

MirkViewportBbox _bbox({
  double s = -1.0,
  double w = -2.0,
  double n = 1.0,
  double e = 2.0,
}) {
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

    test('viewport emission triggers a debounced refresh (~50 ms)', () async {
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

      // Right after the emission no refresh should have fired (debounced).
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        fake.queryViewportBoundsCallCount,
        1,
        reason: 'still within debounce window',
      );

      // After the debounce window elapses the refresh fires.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(fake.queryViewportBoundsCallCount, 2);
      final state = container.read(mapViewportProvider);
      expect(state, isNotNull);
      expect(state!.south, 5.0);
    });

    test('rapid-fire emissions coalesce via debounce', () async {
      final fake = FakeMapView();
      fake.viewportBoundsToReturn = _bbox();
      final container = _makeContainer(initialView: fake);
      addTearDown(container.dispose);

      container.read(mapViewportProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final seedCalls = fake.queryViewportBoundsCallCount;

      // Three emissions inside one debounce window → exactly ONE refresh.
      fake.pushViewport(latitude: 1.0, longitude: 1.0, zoom: 12.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      fake.pushViewport(latitude: 2.0, longitude: 2.0, zoom: 12.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      fake.pushViewport(latitude: 3.0, longitude: 3.0, zoom: 12.0);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Only one extra refresh on top of the seed.
      expect(fake.queryViewportBoundsCallCount, seedCalls + 1);
    });

    test(
      'queryViewportBounds error is silently dropped — provider stays null',
      () async {
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
      },
    );
  });
}
