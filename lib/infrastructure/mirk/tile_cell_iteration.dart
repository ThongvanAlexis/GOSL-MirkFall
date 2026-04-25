// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Path, Rect, Size;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

import 'mirk_projection.dart';

/// Iterates the unrevealed cells of a [VisibleMirkTile] and accumulates
/// their screen-space rectangles into a single [Path].
///
/// Reused by all 4 concrete renderers (`AtmosphericMirkRenderer`,
/// `SolidFillMirkRenderer`, `CandlelightMirkRenderer`,
/// `HeavenlyCloudsMirkRenderer`) — drawing one combined Path per tile
/// is far cheaper than `drawRect` per cell when 50–100 % of the 4096
/// cells are unrevealed.
///
/// ## Bit-unpack semantics
///
/// `tile.bitmap` is 512 bytes = 4096 bits. Bit `(j * 64 + i)` represents
/// cell `(i, j)` where `i` is the column index (0 = west, 63 = east)
/// and `j` is the row index (0 = north, 63 = south). Bit value `1` =
/// REVEALED (skip — let the basemap show through). Bit value `0` =
/// UN-revealed (include in the fog Path).
///
/// ## Coordinate system
///
/// Lat/lon spans for cell `(i, j)` are computed by linear interpolation
/// over the tile's lat/lon extents (`tile.tileNorthLat`,
/// `tile.tileWestLon`, `tile.tileSouthLat`, `tile.tileEastLon`). The
/// resulting cell rectangle is then projected to screen space via
/// [MirkProjection.latLonToScreen].
Path buildUnrevealedCellsPath({required VisibleMirkTile tile, required MirkViewportBbox viewport, required Size canvasSize}) {
  final path = Path();
  final cellLatSpan = (tile.tileNorthLat - tile.tileSouthLat) / kRevealedTileSubgridSize;
  final cellLonSpan = (tile.tileEastLon - tile.tileWestLon) / kRevealedTileSubgridSize;
  for (var j = 0; j < kRevealedTileSubgridSize; j++) {
    final cellNorthLat = tile.tileNorthLat - j * cellLatSpan;
    final cellSouthLat = tile.tileNorthLat - (j + 1) * cellLatSpan;
    for (var i = 0; i < kRevealedTileSubgridSize; i++) {
      final bitIndex = j * kRevealedTileSubgridSize + i;
      final byteIndex = bitIndex >> 3;
      final bitOffset = bitIndex & 7;
      final bit = (tile.bitmap[byteIndex] >> bitOffset) & 1;
      if (bit == 1) continue; // revealed — skip
      final cellWestLon = tile.tileWestLon + i * cellLonSpan;
      final cellEastLon = tile.tileWestLon + (i + 1) * cellLonSpan;
      final nw = MirkProjection.latLonToScreen(lat: cellNorthLat, lon: cellWestLon, viewport: viewport, size: canvasSize);
      final se = MirkProjection.latLonToScreen(lat: cellSouthLat, lon: cellEastLon, viewport: viewport, size: canvasSize);
      path.addRect(Rect.fromPoints(nw, se));
    }
  }
  return path;
}
