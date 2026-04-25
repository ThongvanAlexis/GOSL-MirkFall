// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/providers/revealed_tile_store_provider.dart';
import 'package:mirkfall/application/providers/visible_mirk_tiles_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/revealed_tile_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/revealed_tile.dart';
import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';

/// In-memory fake [RevealedTileStore] — only `findByParent` is exercised
/// by `visibleMirkTilesProvider`.
class _FakeRevealedTileStore implements RevealedTileStore {
  _FakeRevealedTileStore({Map<String, Uint8List>? rows}) : _rowByKey = rows ?? <String, Uint8List>{};

  final Map<String, Uint8List> _rowByKey;

  String _key(SessionId sessionId, int x, int y) => '${sessionId.value}|$x|$y';

  @override
  Future<RevealedTile?> findByParent({required SessionId sessionId, required int parentX, required int parentY}) async {
    final bitmap = _rowByKey[_key(sessionId, parentX, parentY)];
    if (bitmap == null) return null;
    final setBitCount = bitmap.fold<int>(0, (acc, b) => acc + _popcount8(b));
    return RevealedTile(
      id: RevealedTileId('rvt_test_${parentX}_$parentY'),
      sessionId: sessionId,
      parentX: parentX,
      parentY: parentY,
      bitmap: bitmap,
      setBitCount: setBitCount,
      updatedAtUtc: DateTime.utc(2026, 4, 25),
    );
  }

  static int _popcount8(int b) {
    var v = b;
    v = v - ((v >> 1) & 0x55);
    v = (v & 0x33) + ((v >> 2) & 0x33);
    return (v + (v >> 4)) & 0x0F;
  }

  @override
  Future<List<RevealedTile>> listBySession(SessionId sessionId) async => <RevealedTile>[];

  @override
  Future<void> mergeMask({required SessionId sessionId, required int parentX, required int parentY, required Uint8List mask}) async {
    _rowByKey[_key(sessionId, parentX, parentY)] = Uint8List.fromList(mask);
  }
}

class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._initial);
  final ActiveSessionState _initial;

  @override
  ActiveSessionState build() => _initial;
}

class _SeededMapViewport extends MapViewport {
  _SeededMapViewport(this._initial);
  final MirkViewportBbox? _initial;

  @override
  MirkViewportBbox? build() => _initial;
}

ProviderContainer _buildContainer({required ActiveSessionState sessionState, required RevealedTileStore store, MirkViewportBbox? viewport}) {
  return ProviderContainer(
    overrides: [
      activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(sessionState)),
      revealedTileStoreProvider.overrideWith((ref) async => store),
      mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visibleMirkTilesProvider', () {
    test('returns empty list when no session is active', () async {
      // Idle session ⇒ short-circuit BEFORE viewport check, so seed
      // any non-null bbox (here: 43.0/44.0/5.0/6.0 around Marseille).
      final container = _buildContainer(
        sessionState: const Idle(),
        store: _FakeRevealedTileStore(),
        viewport: MirkViewportBbox(south: 43.0, west: 5.5, north: 44.5, east: 6.0),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(visibleMirkTilesProvider.future);
      expect(tiles, isEmpty);
    });

    test('returns empty list when viewport is null', () async {
      final container = _buildContainer(
        sessionState: Tracking(sessionId: const SessionId('sess_no_viewport'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
        store: _FakeRevealedTileStore(),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(visibleMirkTilesProvider.future);
      expect(tiles, isEmpty);
    });

    test('returns parent tiles intersecting viewport — '
        'tile with no DB row gets all-zero bitmap', () async {
      // Pick a tiny bbox that lands inside one parent tile at z14 around
      // Marseille. The provider returns at least 1 tile (the parent
      // covering the centre); since the store has no row, the bitmap is
      // all zeros.
      final container = _buildContainer(
        sessionState: Tracking(sessionId: const SessionId('sess_marseille'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
        store: _FakeRevealedTileStore(),
        viewport: MirkViewportBbox(south: 43.295, west: 5.385, north: 43.300, east: 5.395),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(visibleMirkTilesProvider.future);
      expect(tiles, isNotEmpty);
      // Every tile gets a 512-byte bitmap (all-zero when missing).
      for (final tile in tiles) {
        expect(tile.bitmap, hasLength(kRevealedTileBitmapBytes));
        expect(tile.bitmap.every((b) => b == 0), isTrue);
      }
    });

    test('uses the bitmap from store when a row exists for the tile', () async {
      // Pre-seed a known bitmap for one tile, then assert the provider
      // returns it verbatim. Use the store to pre-write a non-empty
      // bitmap at a known parent position.
      final store = _FakeRevealedTileStore();
      final knownBitmap = Uint8List(kRevealedTileBitmapBytes);
      knownBitmap[0] = 0xFF;
      knownBitmap[1] = 0xAA;
      const sessionId = SessionId('sess_seeded');

      // Compute the parent tile at z14 for Marseille centre.
      final container = _buildContainer(
        sessionState: Tracking(sessionId: sessionId, startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
        store: store,
        viewport: MirkViewportBbox(south: 43.295, west: 5.385, north: 43.300, east: 5.395),
      );
      addTearDown(container.dispose);

      // Prime via the same store (use mergeMask which accepts the mask
      // verbatim in the in-memory fake).
      // Manually compute the parent tile coordinates for the bbox centre.
      // (The provider does the same math internally — we mirror it here
      // for the test to know which tile to seed.)
      final firstFetch = await container.read(visibleMirkTilesProvider.future);
      final aTile = firstFetch.first;
      await store.mergeMask(sessionId: sessionId, parentX: aTile.parentX, parentY: aTile.parentY, mask: knownBitmap);

      // Invalidate to force a re-read.
      container.invalidate(visibleMirkTilesProvider);
      final tiles = await container.read(visibleMirkTilesProvider.future);
      final seeded = tiles.firstWhere((t) => t.parentX == aTile.parentX && t.parentY == aTile.parentY);
      expect(seeded.bitmap[0], 0xFF);
      expect(seeded.bitmap[1], 0xAA);
    });
  });
}
