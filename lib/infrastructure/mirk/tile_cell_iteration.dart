// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Path, PathOperation, Rect, Size;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

import 'mirk_projection.dart';

/// Builds the screen-space fog Path for a single [VisibleMirkTile] using
/// "tile-rect MINUS revealed cells" semantics — the canonical strategy
/// for all 4 builtin renderers since BUG-003 (2026-04-25).
///
/// Reused by all 4 concrete renderers (`AtmosphericMirkRenderer`,
/// `SolidFillMirkRenderer`, `CandlelightMirkRenderer`,
/// `HeavenlyCloudsMirkRenderer`).
///
/// ## Why "rect minus revealed", not "union of unrevealed cells"
///
/// The pre-BUG-003 helper composed a path by adding 4096 individual
/// `Rect.fromPoints(...)` per tile (one per unrevealed cell). When the 3
/// noise-animated renderers applied `MaskFilter.blur(BlurStyle.inner,
/// sigma)` to that path, Skia eroded alpha along EVERY edge of the path,
/// including the 8000+ internal edges between adjacent unrevealed cells.
/// At the macro scale this produced the visible "damier" pattern of
/// bright bands at parent-tile boundaries (cumulative erosion from
/// adjacent tiles each running their own feather pass on top of each
/// other). See `docs/phase09-bug-tracking/BUG-003-mirk-tile-gaps-and-frozen-gestures.md`.
///
/// The current strategy returns a SINGLE path whose only edges are:
///   (a) the tile's outer screen rect, and
///   (b) holes for revealed cells (run-length-encoded per row to merge
///       horizontally adjacent revealed cells into one rect — keeps the
///       hole boundary count low when large quadrants are revealed).
///
/// `Path.combine(PathOperation.difference, ...)` produces exactly that.
/// The `BlurStyle.inner` mask filter then erodes alpha only at those
/// intentional boundaries — no internal cell-grid artifacts remain.
///
/// ## Bit-unpack semantics (unchanged from the pre-BUG-003 helper)
///
/// `tile.bitmap` is 512 bytes = 4096 bits. Bit `(j * 64 + i)` represents
/// cell `(i, j)` where `i` is the column index (0 = west, 63 = east)
/// and `j` is the row index (0 = north, 63 = south). Bit value `1` =
/// REVEALED (carve out — let the basemap show through). Bit value `0` =
/// UN-revealed (keep covered by fog).
///
/// ## Coordinate system
///
/// Lat/lon spans for cell `(i, j)` are computed by linear interpolation
/// over the tile's lat/lon extents (`tile.tileNorthLat`,
/// `tile.tileWestLon`, `tile.tileSouthLat`, `tile.tileEastLon`). Cell
/// rectangles are then projected to screen space via
/// [MirkProjection.latLonToScreen].
///
/// The outer tile rect is computed once from the four corners (NW, SE)
/// rather than as the union of all 4096 cell rects — same geometry,
/// fewer floating-point ops.
Path buildFogClipPath({required VisibleMirkTile tile, required MirkViewportBbox viewport, required Size canvasSize}) {
  // Outer tile rect in screen space — the full fog area before holes.
  final tileNw = MirkProjection.latLonToScreen(lat: tile.tileNorthLat, lon: tile.tileWestLon, viewport: viewport, size: canvasSize);
  final tileSe = MirkProjection.latLonToScreen(lat: tile.tileSouthLat, lon: tile.tileEastLon, viewport: viewport, size: canvasSize);
  final tileRectPath = Path()..addRect(Rect.fromPoints(tileNw, tileSe));

  // Build the revealed-cells "holes" path with row-wise run-length
  // encoding: contiguous revealed cells in the same row collapse to a
  // single rect. Reduces hole count from up to 4096 small rects to a
  // handful of wider rects when large patches are revealed (the common
  // case after a few session minutes of walking).
  final cellLatSpan = (tile.tileNorthLat - tile.tileSouthLat) / kRevealedTileSubgridSize;
  final cellLonSpan = (tile.tileEastLon - tile.tileWestLon) / kRevealedTileSubgridSize;
  final holesPath = Path();
  var hasAnyHole = false;
  for (var j = 0; j < kRevealedTileSubgridSize; j++) {
    final rowNorthLat = tile.tileNorthLat - j * cellLatSpan;
    final rowSouthLat = tile.tileNorthLat - (j + 1) * cellLatSpan;
    var runStart = -1; // -1 = no run currently open
    for (var i = 0; i < kRevealedTileSubgridSize; i++) {
      final bitIndex = j * kRevealedTileSubgridSize + i;
      final byteIndex = bitIndex >> 3;
      final bitOffset = bitIndex & 7;
      final bit = (tile.bitmap[byteIndex] >> bitOffset) & 1;
      if (bit == 1) {
        // Revealed cell — open a run if not already open.
        if (runStart < 0) runStart = i;
        continue;
      }
      // Unrevealed cell — close any open run and emit one rect for it.
      if (runStart >= 0) {
        _addRowRunRect(
          holesPath,
          tile: tile,
          viewport: viewport,
          canvasSize: canvasSize,
          runStartCol: runStart,
          runEndColExclusive: i,
          rowNorthLat: rowNorthLat,
          rowSouthLat: rowSouthLat,
          cellLonSpan: cellLonSpan,
        );
        hasAnyHole = true;
        runStart = -1;
      }
    }
    // Row ended with an open run extending to the east edge.
    if (runStart >= 0) {
      _addRowRunRect(
        holesPath,
        tile: tile,
        viewport: viewport,
        canvasSize: canvasSize,
        runStartCol: runStart,
        runEndColExclusive: kRevealedTileSubgridSize,
        rowNorthLat: rowNorthLat,
        rowSouthLat: rowSouthLat,
        cellLonSpan: cellLonSpan,
      );
      hasAnyHole = true;
    }
  }

  // No revealed cells in this tile — the fog is the full tile rect, no
  // need for the (more expensive) Path.combine difference op.
  if (!hasAnyHole) return tileRectPath;

  // Path.combine returns a fresh Path representing the boolean
  // difference; the tile rect minus the revealed-cell holes.
  return Path.combine(PathOperation.difference, tileRectPath, holesPath);
}

/// Projects one row-run (`[runStartCol, runEndColExclusive)`) to screen
/// space and adds it as a single rect to [holesPath]. Pulled out of the
/// double-loop body to keep [buildFogClipPath] readable.
void _addRowRunRect(
  Path holesPath, {
  required VisibleMirkTile tile,
  required MirkViewportBbox viewport,
  required Size canvasSize,
  required int runStartCol,
  required int runEndColExclusive,
  required double rowNorthLat,
  required double rowSouthLat,
  required double cellLonSpan,
}) {
  final westLon = tile.tileWestLon + runStartCol * cellLonSpan;
  final eastLon = tile.tileWestLon + runEndColExclusive * cellLonSpan;
  final nw = MirkProjection.latLonToScreen(lat: rowNorthLat, lon: westLon, viewport: viewport, size: canvasSize);
  final se = MirkProjection.latLonToScreen(lat: rowSouthLat, lon: eastLon, viewport: viewport, size: canvasSize);
  holesPath.addRect(Rect.fromPoints(nw, se));
}
