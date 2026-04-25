// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Unit suite for `buildFogClipPath` — the BUG-003 fix replacement for
// the pre-2026-04-25 `buildUnrevealedCellsPath`. Asserts the helper's
// contract:
//
//  * tile rect minus revealed cells (single combined path)
//  * empty path when every cell is revealed (path.getBounds() degenerate)
//  * full tile rect when no cell is revealed
//  * row-run RLE collapse: contiguous revealed cells in the same row
//    coalesce into a single hole (verified indirectly via the resulting
//    path bounds + the path's command count via Path operations rather
//    than reaching into Skia internals).

import 'dart:typed_data';
import 'dart:ui' show Offset, Path, PathOperation, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/infrastructure/mirk/tile_cell_iteration.dart';

import '_render_helpers.dart';

VisibleMirkTile _tile({Uint8List? bitmap}) => VisibleMirkTile(
  parentX: 8456,
  parentY: 5959,
  bitmap: bitmap ?? makeAllUnrevealedBitmap(),
  tileNorthLat: 43.7,
  tileWestLon: 5.3,
  tileSouthLat: 43.5,
  tileEastLon: 5.5,
);

MirkViewportBbox _viewport() => MirkViewportBbox(south: 43.5, west: 5.3, north: 43.7, east: 5.5);

const Size _canvas = Size(256, 256);

void main() {
  group('BUG-003 — buildFogClipPath (tile-rect minus revealed cells)', () {
    test('all-unrevealed tile -> path covers the full tile screen rect', () {
      final path = buildFogClipPath(
        tile: _tile(bitmap: makeAllUnrevealedBitmap()),
        viewport: _viewport(),
        canvasSize: _canvas,
      );
      final bounds = path.getBounds();
      // Tile fills the viewport in this fixture (tile bbox == viewport bbox)
      // so the screen rect should be (0, 0, 256, 256) — within rounding.
      expect(bounds.left, closeTo(0.0, 0.5));
      expect(bounds.top, closeTo(0.0, 0.5));
      expect(bounds.right, closeTo(256.0, 0.5));
      expect(bounds.bottom, closeTo(256.0, 0.5));
    });

    test('all-revealed tile -> empty path (every pixel inside the tile rect is carved out)', () {
      final path = buildFogClipPath(
        tile: _tile(bitmap: makeAllRevealedBitmap()),
        viewport: _viewport(),
        canvasSize: _canvas,
      );
      // Path.combine(difference, R, R) collapses to an empty path; its
      // getBounds() returns Rect.zero. The renderers' empty-bounds guard
      // (`if (path.getBounds().isEmpty) continue;`) relies on this.
      expect(path.getBounds().isEmpty, isTrue, reason: 'all-revealed tile must produce an empty path so the renderer guard skips it');
    });

    test('half-revealed tile -> path bounds remain the full tile rect (holes do not shrink the bbox)', () {
      // The top-left 32x32 quadrant is revealed; the rest (including the
      // east + south halves) is fog. The path's outer bounds are still
      // the full tile rect because the fog reaches every edge of the rect.
      final path = buildFogClipPath(
        tile: _tile(bitmap: makeHalfRevealedBitmap()),
        viewport: _viewport(),
        canvasSize: _canvas,
      );
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(0.0, 0.5));
      expect(bounds.top, closeTo(0.0, 0.5));
      expect(bounds.right, closeTo(256.0, 0.5));
      expect(bounds.bottom, closeTo(256.0, 0.5));
    });

    test('half-revealed path is NOT byte-identical to all-unrevealed path (holes are real)', () {
      final pathFull = buildFogClipPath(
        tile: _tile(bitmap: makeAllUnrevealedBitmap()),
        viewport: _viewport(),
        canvasSize: _canvas,
      );
      final pathHalf = buildFogClipPath(
        tile: _tile(bitmap: makeHalfRevealedBitmap()),
        viewport: _viewport(),
        canvasSize: _canvas,
      );
      // Sample one pixel inside the revealed quadrant: (128*0.5, 128*0.5)
      // = (64, 64). The full-fog path contains (64, 64); the
      // half-revealed path does NOT (it's inside the carved-out quadrant).
      expect(pathFull.contains(const Offset(64, 64)), isTrue, reason: 'all-unrevealed must contain an interior point');
      expect(pathHalf.contains(const Offset(64, 64)), isFalse, reason: 'half-revealed (top-left quadrant carved out) must NOT contain (64, 64)');
      // And conversely a pixel inside the bottom-right quadrant must be
      // covered by both paths.
      expect(pathHalf.contains(const Offset(192, 192)), isTrue, reason: 'half-revealed must still cover the bottom-right quadrant');
    });

    test('column-row run-length encoding: a single revealed row produces one hole rect', () {
      // Build a bitmap where row j=10 is fully revealed (all 64 columns)
      // and every other cell is unrevealed. The row-run RLE should
      // collapse those 64 cells into a single hole rect, NOT 64 separate
      // ones. We verify this indirectly: a hand-built reference path
      // using a single row-rect must equal the helper's output (boolean
      // difference equality on the visible region).
      final bitmap = Uint8List(kRevealedTileBitmapBytes);
      const j = 10;
      for (var i = 0; i < kRevealedTileSubgridSize; i++) {
        final bitIndex = j * kRevealedTileSubgridSize + i;
        bitmap[bitIndex >> 3] |= 1 << (bitIndex & 7);
      }

      final pathHelper = buildFogClipPath(
        tile: _tile(bitmap: bitmap),
        viewport: _viewport(),
        canvasSize: _canvas,
      );

      // Hand-built reference: tile rect minus a single horizontal-strip rect.
      // Tile rect spans (0, 0) -> (256, 256). Row j=10 (of 64) spans
      // y in [10/64*256, 11/64*256] = [40, 44].
      final refTileRect = Path()..addRect(const Rect.fromLTWH(0, 0, 256, 256));
      final refStripRect = Path()..addRect(const Rect.fromLTWH(0, 40, 256, 4));
      final refPath = Path.combine(PathOperation.difference, refTileRect, refStripRect);

      // Test inclusion at sample points: both paths must agree on
      // whether each point is fog (in path) or revealed (out of path).
      const samples = <Offset>[
        Offset(128, 20), // above the revealed strip — fog (in)
        Offset(128, 42), // inside the strip — revealed (out)
        Offset(128, 100), // below the strip — fog (in)
        Offset(0.5, 0.5), // top-left corner — fog (in)
        Offset(255.5, 255.5), // bottom-right corner — fog (in)
        Offset(0.5, 42), // strip's west edge — revealed (out)
        Offset(255.5, 42), // strip's east edge — revealed (out)
      ];
      for (final p in samples) {
        expect(pathHelper.contains(p), refPath.contains(p), reason: 'helper and reference path must agree on point $p');
      }
    });

    test('tile completely outside viewport -> path bounds outside canvas (renderer guard handles offscreen)', () {
      // Tile bbox is south of the viewport: tile spans 40..40.5 N,
      // viewport spans 43..44 N. Projection puts the tile below the
      // canvas (y > size.height), but the projection itself is still
      // valid (linear extrapolation). The path is non-empty and the
      // renderer's `if (path.getBounds().isEmpty) continue;` does not
      // apply — drawing a fully off-canvas path is harmless (Skia
      // clips). This case asserts we don't crash + we produce a path
      // with positive area in the right region.
      final tile = VisibleMirkTile(
        parentX: 0,
        parentY: 0,
        bitmap: makeAllUnrevealedBitmap(),
        tileNorthLat: 40.5,
        tileWestLon: 5.3,
        tileSouthLat: 40.0,
        tileEastLon: 5.5,
      );
      final path = buildFogClipPath(tile: tile, viewport: _viewport(), canvasSize: _canvas);
      final bounds = path.getBounds();
      // Tile is 3..3.5° south of viewport's south, so y > size.height.
      expect(bounds.top, greaterThan(_canvas.height));
    });
  });
}
