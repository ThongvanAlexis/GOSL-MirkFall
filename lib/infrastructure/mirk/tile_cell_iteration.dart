// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui' show Path, PathOperation, Rect, Size;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import 'mirk_projection.dart';

/// Builds the screen-space fog Path for a single [VisibleMirkTile] using
/// "tile-rect MINUS revealed cells" semantics.
///
/// **Per-tile**, used by tests and as the building block for
/// [buildViewportFogClipPath]. Most renderer callers should reach for
/// the viewport-level helper instead — see BUG-003 fix below.
///
/// ## Bit-unpack semantics
///
/// `tile.bitmap` is 512 bytes = 4096 bits. Bit `(j * 64 + i)` represents
/// cell `(i, j)` where `i` is the column index (0 = west, 63 = east)
/// and `j` is the row index (0 = north, 63 = south). Bit value `1` =
/// REVEALED (carve out — let the basemap show through). Bit value `0` =
/// UN-revealed (keep covered by fog).
///
/// ## RLE encoding of holes
///
/// Contiguous revealed cells in the same row collapse into a single
/// rect. Reduces hole count from up to 4096 small rects to a handful
/// of wider rects when large patches are revealed (the common case
/// after a few session minutes of walking).
Path buildFogClipPath({required VisibleMirkTile tile, required MirkViewportBbox viewport, required Size canvasSize}) {
  // Outer tile rect in screen space — the full fog area before holes.
  final tileNw = MirkProjection.latLonToScreen(lat: tile.tileNorthLat, lon: tile.tileWestLon, viewport: viewport, size: canvasSize);
  final tileSe = MirkProjection.latLonToScreen(lat: tile.tileSouthLat, lon: tile.tileEastLon, viewport: viewport, size: canvasSize);
  final tileRectPath = Path()..addRect(Rect.fromPoints(tileNw, tileSe));

  final holesPath = Path();
  final hasHoles = _addTileRevealedHoles(holesPath, tile: tile, viewport: viewport, canvasSize: canvasSize);

  if (!hasHoles) return tileRectPath;

  return Path.combine(PathOperation.difference, tileRectPath, holesPath);
}

/// Builds a SINGLE composite fog Path covering the entire viewport bbox
/// with every revealed cell across every visible tile subtracted —
/// the canonical "fog-of-war" path strategy since BUG-003 (2026-04-25).
///
/// Renderers (atmospheric / candlelight / heavenly_clouds / solid)
/// invoke this once per frame and emit a SINGLE `canvas.drawPath` per
/// `paint()`. Two key consequences:
///
///  1. The `MaskFilter.blur(BlurStyle.inner, sigma)` feather is applied
///     to ONE path, ONCE — alpha erodes only along the global fog/clear
///     boundary (the outer viewport rect minus the revealed cells across
///     the whole 2D union). Pre-BUG-003, each tile drew with its own
///     mask filter, so the parent-tile seams accumulated TWO feather
///     passes (one from each side), producing the visible bright bands.
///  2. The cell-grid internal edges within a tile do not matter for the
///     same reason adjacent rects in [Path.addRect] form one filled
///     blob: Skia rasterises by fill rule, not by sub-path, and inner
///     blur applies to the rasterised silhouette.
///
/// ## Inputs
///
/// * [visibleTiles] — every parent tile intersecting the viewport (the
///   same list the renderer iterates pre-BUG-003). Tiles fully outside
///   the [viewport] still contribute correct geometry; the resulting
///   path simply has corresponding regions outside [canvasSize] which
///   Skia clips at draw time.
/// * [viewport] / [canvasSize] — passed through to projection.
///
/// ## Returns
///
/// A non-null [Path]. Empty visibleTiles → returns a fresh empty Path
/// (caller should still check `path.getBounds().isEmpty` to skip the
/// drawPath call cleanly).
///
/// ## Cost
///
/// Two boolean ops per frame: one Op.union to merge the per-tile
/// revealed-cell hole paths, one Op.difference to subtract the union
/// from the viewport rect. Hot-path budget remains generous — Phase 09
/// plan 09-08 measured ~90 ms / frame on the 50k-tile fixture *with*
/// the per-tile boolean strategy. Viewport-level merges scale better.
Path buildViewportFogClipPath({required Iterable<VisibleMirkTile> visibleTiles, required MirkViewportBbox viewport, required Size canvasSize}) {
  // Outer fog area = the union of every visible-tile rect. In production
  // the `visibleMirkTilesProvider` synthesises a dense list (one entry
  // per (x, y) tile slot in the viewport bbox, with all-zero bitmaps for
  // unstored slots), so the union IS effectively the viewport rect. In
  // tests / sparse fixtures the union is exactly what the renderer
  // should fog — areas with no visible tile entry stay clear (matches
  // the pre-BUG-003 per-tile-loop semantics that existing tests assert).
  final tilesRect = Path();
  for (final tile in visibleTiles) {
    final nw = MirkProjection.latLonToScreen(lat: tile.tileNorthLat, lon: tile.tileWestLon, viewport: viewport, size: canvasSize);
    final se = MirkProjection.latLonToScreen(lat: tile.tileSouthLat, lon: tile.tileEastLon, viewport: viewport, size: canvasSize);
    tilesRect.addRect(Rect.fromPoints(nw, se));
  }

  // Aggregate ALL revealed-cell holes across ALL visible tiles into a
  // single Path. addRect (cheaper than Path.combine union) is correct
  // here because we don't need the holes union path to be a topology-
  // simplified region — Path.combine(difference) at the end uses the
  // even-odd / fill rule of the holes path, and overlapping rects are
  // fine.
  final allHoles = Path();
  var hasAnyHole = false;
  for (final tile in visibleTiles) {
    if (_addTileRevealedHoles(allHoles, tile: tile, viewport: viewport, canvasSize: canvasSize)) {
      hasAnyHole = true;
    }
  }

  if (!hasAnyHole) return tilesRect;

  return Path.combine(PathOperation.difference, tilesRect, allHoles);
}

/// Appends RLE-encoded "revealed cell" hole rects from [tile] into
/// [holesPath]. Returns `true` if at least one rect was added.
///
/// Pulled out of [buildFogClipPath] / [buildViewportFogClipPath] so
/// both share the same row-iteration logic without duplication.
bool _addTileRevealedHoles(Path holesPath, {required VisibleMirkTile tile, required MirkViewportBbox viewport, required Size canvasSize}) {
  final cellLatSpan = (tile.tileNorthLat - tile.tileSouthLat) / kRevealedTileSubgridSize;
  final cellLonSpan = (tile.tileEastLon - tile.tileWestLon) / kRevealedTileSubgridSize;
  var added = false;
  for (var j = 0; j < kRevealedTileSubgridSize; j++) {
    final rowNorthLat = tile.tileNorthLat - j * cellLatSpan;
    final rowSouthLat = tile.tileNorthLat - (j + 1) * cellLatSpan;
    var runStart = -1;
    for (var i = 0; i < kRevealedTileSubgridSize; i++) {
      final bitIndex = j * kRevealedTileSubgridSize + i;
      final byteIndex = bitIndex >> 3;
      final bitOffset = bitIndex & 7;
      final bit = (tile.bitmap[byteIndex] >> bitOffset) & 1;
      if (bit == 1) {
        if (runStart < 0) runStart = i;
        continue;
      }
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
        added = true;
        runStart = -1;
      }
    }
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
      added = true;
    }
  }
  return added;
}

/// Builds a SINGLE composite fog Path covering the entire viewport rect
/// with every [RevealDisc] subtracted as a circular hole — the BUG-010
/// Option B continuous-geometry replacement for [buildViewportFogClipPath].
///
/// The returned path is `viewportRect − union(discCircles_in_screen_space)`.
/// Each disc's screen-space radius is computed from the viewport's
/// average metres-per-pixel, mirroring [`RevealedSdfBuilder.buildFromDiscs`]'s
/// projection so the clip path and the SDF agree on disc extents to
/// within sub-pixel precision.
///
/// ## Inputs
///
///   * [discs] — every disc the SDF builder will consume this frame.
///     Empty list yields a non-empty path equal to the viewport rect
///     (whole canvas reads as fog — there is nothing revealed).
///   * [viewport] / [canvasSize] — projection inputs. Same convention as
///     [`buildViewportFogClipPath`]: viewport.north → screen y=0,
///     viewport.south → screen y=canvasSize.height.
///
/// ## Returns
///
/// A non-null [Path]. With [discs] empty the path equals the viewport
/// rect; with at least one intersecting disc, the path is the rect
/// minus the union of disc circles. Caller still checks
/// `path.getBounds().isEmpty` to short-circuit (rare — the viewport
/// rect would have to be degenerate).
Path buildViewportFogClipPathFromDiscs({required Iterable<RevealDisc> discs, required MirkViewportBbox viewport, required Size canvasSize}) {
  final viewportRect = Path()..addRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));

  final dLat = viewport.north - viewport.south;
  final dLon = viewport.east - viewport.west;
  if (dLat <= 0 || dLon <= 0 || canvasSize.width <= 0 || canvasSize.height <= 0) {
    // Degenerate viewport — fog covers the (degenerate) rect, no holes.
    return viewportRect;
  }

  // Mean-latitude longitude scale + geometric-mean metres-per-pixel
  // — matches `RevealedSdfBuilder.buildFromDiscs` so the clip-path edge
  // and the SDF zero-isoline coincide.
  final meanLatRad = (viewport.south + viewport.north) * 0.5 * math.pi / 180.0;
  final cosMeanLat = math.cos(meanLatRad);
  final metersPerPixelY = (dLat * kMetersPerDegreeLat) / canvasSize.height;
  final metersPerPixelX = (dLon * kMetersPerDegreeLat * cosMeanLat) / canvasSize.width;
  final metersPerPixel = math.sqrt(metersPerPixelX * metersPerPixelY);
  if (metersPerPixel <= 0) return viewportRect;

  final holesPath = Path();
  var hasAnyHole = false;
  for (final disc in discs) {
    if (!disc.intersectsBbox(viewport)) continue;
    final centre = MirkProjection.latLonToScreen(lat: disc.lat, lon: disc.lon, viewport: viewport, size: canvasSize);
    final radiusPx = disc.radiusMeters / metersPerPixel;
    if (radiusPx <= 0) continue;
    holesPath.addOval(Rect.fromCircle(center: centre, radius: radiusPx));
    hasAnyHole = true;
  }
  if (!hasAnyHole) return viewportRect;
  return Path.combine(PathOperation.difference, viewportRect, holesPath);
}

/// Projects one row-run (`[runStartCol, runEndColExclusive)`) to screen
/// space and adds it as a single rect to [holesPath].
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
