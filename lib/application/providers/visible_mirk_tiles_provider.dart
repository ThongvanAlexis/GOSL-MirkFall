// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/providers/revealed_tile_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/domain/revealed/tile_math.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'visible_mirk_tiles_provider.g.dart';

/// Async provider returning the parent tiles intersecting the current
/// viewport, hydrated with their bitmap from [`RevealedTileStore`] and
/// pre-projected lat/lon extents.
///
/// Empty list is returned when:
/// * The session is not in `Tracking` state (no fog to paint).
/// * The viewport is not yet known ([`mapViewportProvider`] is null).
///
/// A parent tile with no row in the store yields a [VisibleMirkTile]
/// with an all-zero bitmap — the renderer paints the entire tile as
/// fog (which is the correct semantic for "this area has not been
/// revealed yet").
///
/// Phase 09 plan 09-07 Task 2 — viewport filtering (SC#5) seam.
@riverpod
Future<List<VisibleMirkTile>> visibleMirkTiles(Ref ref) async {
  final sessionAsync = ref.watch(activeSessionControllerProvider);
  final sessionState = sessionAsync.value;
  final SessionId? sessionId = switch (sessionState) {
    Tracking(:final sessionId) => sessionId,
    Idle() || Starting() || null => null,
  };
  if (sessionId == null) return const <VisibleMirkTile>[];

  final MirkViewportBbox? viewport = ref.watch(mapViewportProvider);
  if (viewport == null) return const <VisibleMirkTile>[];

  // The viewport bbox can wrap the antimeridian (east < west). Phase 09
  // research deferred antimeridian rendering (out of MVP scope); we
  // short-circuit to an empty list rather than producing garbage tile
  // ranges. The next non-wrapping camera move recovers.
  if (viewport.east < viewport.west) return const <VisibleMirkTile>[];

  final store = await ref.watch(revealedTileStoreProvider.future);

  // Tile-coordinate north corresponds to MIN y (slippy-map convention).
  // Compute the four bbox corners' tile indices and produce the
  // inclusive (xMin..xMax, yMin..yMax) rectangle.
  final TilePosition nwTile = TileMath.latLonToTile(
    lat: viewport.north,
    lon: viewport.west,
    zoom: kRevealedTileParentZoom,
  );
  final TilePosition seTile = TileMath.latLonToTile(
    lat: viewport.south,
    lon: viewport.east,
    zoom: kRevealedTileParentZoom,
  );
  final int xMin = nwTile.x < seTile.x ? nwTile.x : seTile.x;
  final int xMax = nwTile.x > seTile.x ? nwTile.x : seTile.x;
  final int yMin = nwTile.y < seTile.y ? nwTile.y : seTile.y;
  final int yMax = nwTile.y > seTile.y ? nwTile.y : seTile.y;

  final result = <VisibleMirkTile>[];
  for (var y = yMin; y <= yMax; y++) {
    for (var x = xMin; x <= xMax; x++) {
      final row = await store.findByParent(
        sessionId: sessionId,
        parentX: x,
        parentY: y,
      );
      // Null bitmap = no bits revealed yet for this tile. Still include
      // the tile — all-zero bitmap means the entire tile renders as fog.
      final bitmap = row?.bitmap ?? Uint8List(kRevealedTileBitmapBytes);
      final ({double lat, double lon}) nw = TileMath.tileToLatLon(
        x: x,
        y: y,
        zoom: kRevealedTileParentZoom,
      );
      final ({double lat, double lon}) se = TileMath.tileToLatLon(
        x: x + 1,
        y: y + 1,
        zoom: kRevealedTileParentZoom,
      );
      result.add(
        VisibleMirkTile(
          parentX: x,
          parentY: y,
          bitmap: bitmap,
          tileNorthLat: nw.lat,
          tileWestLon: nw.lon,
          tileSouthLat: se.lat,
          tileEastLon: se.lon,
        ),
      );
    }
  }
  return result;
}
