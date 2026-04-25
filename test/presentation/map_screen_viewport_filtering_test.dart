// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/providers/revealed_tile_store_provider.dart';
import 'package:mirkfall/application/providers/visible_mirk_tiles_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

import '../fakes/fake_revealed_tile_store.dart';

/// Plan 09-08 Task 2 — viewport filtering regression guard (SC#5).
///
/// With 1000 tiles in the in-memory store and a viewport covering ≈ 4
/// parent tiles, the [`visibleMirkTilesProvider`] must call
/// `findByParent` only for the viewport's tile rectangle — NOT for every
/// row in the store. Bounded by `≤ 20` calls per provider build (a
/// Paris-sized bbox at z=14 spans ~3-4 parent tiles + a small slack).
///
/// The second test exercises the panning path: a `mapViewportProvider`
/// override that swaps bbox between Paris and Berlin invalidates the
/// filtered set, yielding a different tile selection.
class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._initial);

  final ActiveSessionState _initial;

  @override
  ActiveSessionState build() => _initial;
}

class _SwappableMapViewport extends MapViewport {
  _SwappableMapViewport(this._initial);

  final MirkViewportBbox? _initial;

  @override
  MirkViewportBbox? build() => _initial;

  /// Test-only setter so the panning test can swap the published bbox
  /// without re-mounting the provider scope.
  // ignore: use_setters_to_change_properties — exposed as a method so
  // it shows up explicitly in test code; setters disappear into ordinary
  // assignment which is harder to grep when triaging a flake.
  void publish(MirkViewportBbox? next) {
    state = next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Paris bbox at z=14 — picked to ensure ~3-4 parent tiles intersect.
  // 1° lat / 1° lon at z=14 = many parent tiles (each parent tile is
  // ~0.022° at z=14), so the bbox is sized smaller than 1° in both
  // directions to keep call count manageable.
  final MirkViewportBbox parisBbox = MirkViewportBbox(south: 48.84, west: 2.32, north: 48.88, east: 2.36);
  final MirkViewportBbox berlinBbox = MirkViewportBbox(south: 52.50, west: 13.39, north: 52.54, east: 13.43);

  group('09-08 — visibleMirkTilesProvider viewport filtering (SC#5)', () {
    test('1000 tiles in DB, viewport over ~4 parent tiles → ≤ 20 findByParent calls', () async {
      const sessionId = SessionId('sess_viewport_filter');
      final fakeStore = FakeRevealedTileStore()..seed1000TilesEurope(sessionId: sessionId);
      expect(fakeStore.rowCount, 1000, reason: 'seeder must populate exactly 1000 deterministic tiles');

      final container = ProviderContainer(
        overrides: [
          revealedTileStoreProvider.overrideWith((ref) async => fakeStore),
          activeSessionControllerProvider.overrideWith(
            () => _FakeActiveSessionController(Tracking(sessionId: sessionId, startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5)),
          ),
          mapViewportProvider.overrideWith(() => _SwappableMapViewport(parisBbox)),
        ],
      );
      addTearDown(container.dispose);

      // Pre-resolve the store provider so the visibleMirkTiles
      // provider sees a synchronously-available value (mirrors the
      // pattern used in active_session_controller_initial_reveal_test
      // — Plan 09-06 deviation #4).
      await container.read(revealedTileStoreProvider.future);
      // Reset the counter AFTER any seeding/setup queries the store
      // might run; only the provider's own findByParent calls count.
      fakeStore.findByParentCallCount = 0;

      final List<VisibleMirkTile> visible = await container.read(visibleMirkTilesProvider.future);

      expect(
        fakeStore.findByParentCallCount,
        lessThanOrEqualTo(20),
        reason: 'Paris bbox at z=14 should iterate ≤ 20 parent tiles; got ${fakeStore.findByParentCallCount}',
      );
      // Sanity: the visible list size matches the call count exactly
      // (each iterated parent tile produces one VisibleMirkTile).
      expect(visible.length, fakeStore.findByParentCallCount);
    });

    test('panning the viewport produces a different visible-tile set', () async {
      const sessionId = SessionId('sess_viewport_pan');
      final fakeStore = FakeRevealedTileStore()..seed1000TilesEurope(sessionId: sessionId);

      final swappable = _SwappableMapViewport(parisBbox);
      final container = ProviderContainer(
        overrides: [
          revealedTileStoreProvider.overrideWith((ref) async => fakeStore),
          activeSessionControllerProvider.overrideWith(
            () => _FakeActiveSessionController(Tracking(sessionId: sessionId, startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5)),
          ),
          mapViewportProvider.overrideWith(() => swappable),
        ],
      );
      addTearDown(container.dispose);

      await container.read(revealedTileStoreProvider.future);
      // Trigger the build on the override notifier so we have a live
      // reference to mutate. The mapViewportProvider.notifier static
      // type is the abstract MapViewport class (not our override
      // subclass) which hides the publish() method, so we go through
      // the captured `swappable` reference directly.
      container.read(mapViewportProvider);
      final List<VisibleMirkTile> setParis = await container.read(visibleMirkTilesProvider.future);

      // Swap viewport — provider rebuilds because mapViewportProvider's
      // state changed (visibleMirkTilesProvider watches it).
      swappable.publish(berlinBbox);

      final List<VisibleMirkTile> setBerlin = await container.read(visibleMirkTilesProvider.future);

      // Tile keys differ between Paris and Berlin viewports.
      Set<({int x, int y})> keysOf(List<VisibleMirkTile> tiles) {
        return tiles.map((t) => (x: t.parentX, y: t.parentY)).toSet();
      }

      final Set<({int x, int y})> parisKeys = keysOf(setParis);
      final Set<({int x, int y})> berlinKeys = keysOf(setBerlin);
      expect(parisKeys, isNotEmpty);
      expect(berlinKeys, isNotEmpty);
      expect(parisKeys.intersection(berlinKeys), isEmpty, reason: 'Paris and Berlin parent tiles must not overlap');
    });
  });
}
