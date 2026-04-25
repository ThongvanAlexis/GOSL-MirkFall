// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/revealed/reveal_calculator.dart';
import 'package:mirkfall/domain/revealed/tile_math.dart';
import 'package:test/test.dart';

/// Phase 09 plan 09-03 — `computeRevealMask` geometry kernel correctness
/// (MIRK-01).
///
/// The Phase 03 algebra suite at `test/domain/reveal_calculator_test.dart`
/// already covers the bytewise merge and popcount primitives. This file
/// exercises the geometric reveal computation: bbox-first prune + per-cell
/// Haversine clamp, including the MIRK-03 no-micro-holes invariant
/// (cells flipped when the cell rectangle intersects the circle, NOT just
/// when the cell centre is inside).
void main() {
  group('09-03 — computeRevealMask (MIRK-01)', () {
    test('circle fully inside parent tile produces a disc-shaped bitmap', () {
      // Pick a fix at lat 45° / lon 5° so the home tile at z=14 is unambiguous,
      // then drop the fix exactly at the centre of the parent tile so the
      // 25 m disc cannot leak across boundaries.
      const fixLat = 45.0;
      const fixLon = 5.0;
      final homeTile = TileMath.latLonToTile(
        lat: fixLat,
        lon: fixLon,
        zoom: kRevealedTileParentZoom,
      );
      final tileNw = TileMath.tileToLatLon(
        x: homeTile.x,
        y: homeTile.y,
        zoom: kRevealedTileParentZoom,
      );
      final tileSe = TileMath.tileToLatLon(
        x: homeTile.x + 1,
        y: homeTile.y + 1,
        zoom: kRevealedTileParentZoom,
      );
      final centreLat = (tileNw.lat + tileSe.lat) / 2.0;
      final centreLon = (tileNw.lon + tileSe.lon) / 2.0;

      final mask = computeRevealMask(
        centerLat: centreLat,
        centerLon: centreLon,
        radiusMeters: kDefaultRevealRadiusMeters,
        parentX: homeTile.x,
        parentY: homeTile.y,
        parentZoom: kRevealedTileParentZoom,
      );

      expect(
        mask,
        isA<Uint8List>(),
        reason: 'mask must be the canonical Uint8List buffer',
      );
      expect(
        mask.length,
        kRevealedTileBitmapBytes,
        reason: 'mask must be 512 bytes (64×64 bits)',
      );
      // At lat 45° / z=14 the parent tile is ~1727 m × 1535 m → cells ~27 m × 24 m.
      // A 25 m disc area is π·25² ≈ 1963 m² ≈ 3 cells of pure area; with the
      // MIRK-03 rectangle-intersection clip this lands around 3 to 12 cells
      // (orientation/alignment-dependent). The bounds stay loose so future
      // grid-rounding micro-changes do not break this case spuriously.
      final setBits = popcount(mask);
      expect(
        setBits,
        greaterThanOrEqualTo(3),
        reason: 'expected ≥ 3 cells revealed for a 25 m disc at lat 45°',
      );
      expect(
        setBits,
        lessThanOrEqualTo(12),
        reason: 'expected ≤ 12 cells revealed for a 25 m disc at lat 45°',
      );
    });

    test('circle fully outside parent tile returns an all-zero mask', () {
      // Fix at lat 45° / lon 5°; query a parent tile far away (lon 100°).
      const fixLat = 45.0;
      const fixLon = 5.0;
      final farTile = TileMath.latLonToTile(
        lat: 45.0,
        lon: 100.0,
        zoom: kRevealedTileParentZoom,
      );
      final mask = computeRevealMask(
        centerLat: fixLat,
        centerLon: fixLon,
        radiusMeters: kDefaultRevealRadiusMeters,
        parentX: farTile.x,
        parentY: farTile.y,
        parentZoom: kRevealedTileParentZoom,
      );

      expect(mask.length, kRevealedTileBitmapBytes);
      expect(
        popcount(mask),
        0,
        reason: 'circle outside parent tile must produce a no-op mask',
      );
    });

    test('tiny radius (1 m) flips at most 4 cells', () {
      const fixLat = 45.0;
      const fixLon = 5.0;
      final homeTile = TileMath.latLonToTile(
        lat: fixLat,
        lon: fixLon,
        zoom: kRevealedTileParentZoom,
      );
      final tileNw = TileMath.tileToLatLon(
        x: homeTile.x,
        y: homeTile.y,
        zoom: kRevealedTileParentZoom,
      );
      final tileSe = TileMath.tileToLatLon(
        x: homeTile.x + 1,
        y: homeTile.y + 1,
        zoom: kRevealedTileParentZoom,
      );
      final centreLat = (tileNw.lat + tileSe.lat) / 2.0;
      final centreLon = (tileNw.lon + tileSe.lon) / 2.0;

      final mask = computeRevealMask(
        centerLat: centreLat,
        centerLon: centreLon,
        radiusMeters: 1.0,
        parentX: homeTile.x,
        parentY: homeTile.y,
        parentZoom: kRevealedTileParentZoom,
      );

      // A 1 m radius is far smaller than any cell (~38 m × 27 m at z=14 lat 45°).
      // It can intersect at most 4 cells (when the centre sits on a 4-corner intersection).
      final setBits = popcount(mask);
      expect(
        setBits,
        greaterThanOrEqualTo(1),
        reason: '1 m disc must still flip at least the home cell',
      );
      expect(
        setBits,
        lessThanOrEqualTo(4),
        reason: '1 m disc cannot intersect more than 4 cells',
      );
    });

    test('large radius (120 m) covers inner cells far from the circle edge', () {
      const fixLat = 45.0;
      const fixLon = 5.0;
      final homeTile = TileMath.latLonToTile(
        lat: fixLat,
        lon: fixLon,
        zoom: kRevealedTileParentZoom,
      );
      final tileNw = TileMath.tileToLatLon(
        x: homeTile.x,
        y: homeTile.y,
        zoom: kRevealedTileParentZoom,
      );
      final tileSe = TileMath.tileToLatLon(
        x: homeTile.x + 1,
        y: homeTile.y + 1,
        zoom: kRevealedTileParentZoom,
      );
      final centreLat = (tileNw.lat + tileSe.lat) / 2.0;
      final centreLon = (tileNw.lon + tileSe.lon) / 2.0;

      final mask = computeRevealMask(
        centerLat: centreLat,
        centerLon: centreLon,
        radiusMeters: 120.0,
        parentX: homeTile.x,
        parentY: homeTile.y,
        parentZoom: kRevealedTileParentZoom,
      );

      // 120 m radius at lat 45° ≈ π × 120² ≈ 45 000 m², per-cell ≈ 38 × 27 = 1026 m²
      // → at minimum ~30 cells fully inside the disc, plus the edge band.
      final setBits = popcount(mask);
      expect(
        setBits,
        greaterThanOrEqualTo(30),
        reason: '120 m disc must reveal a substantial inner area (>=30 cells)',
      );

      // Centre cell (j=32, i=32) MUST be set — it is the cell containing the fix.
      const centreI = kRevealedTileSubgridSize ~/ 2;
      const centreJ = kRevealedTileSubgridSize ~/ 2;
      const centreBitIndex = centreJ * kRevealedTileSubgridSize + centreI;
      const centreByteIndex = centreBitIndex ~/ 8;
      const centreBitOffset = centreBitIndex & 7;
      expect(
        mask[centreByteIndex] & (1 << centreBitOffset),
        isNonZero,
        reason: 'centre cell must be revealed by a 120 m disc',
      );
    });

    test(
      'polar latitude (lat=85) does not crash and yields a valid 512-byte mask',
      () {
        // Mercator clamp at ±85.0511°; lat=85 sits within the clamp boundary.
        // The kernel must not produce NaN / crash; a valid 512-byte buffer is required.
        const fixLat = 85.0;
        const fixLon = 5.0;
        final homeTile = TileMath.latLonToTile(
          lat: fixLat,
          lon: fixLon,
          zoom: kRevealedTileParentZoom,
        );

        Uint8List? mask;
        expect(
          () {
            mask = computeRevealMask(
              centerLat: fixLat,
              centerLon: fixLon,
              radiusMeters: kDefaultRevealRadiusMeters,
              parentX: homeTile.x,
              parentY: homeTile.y,
              parentZoom: kRevealedTileParentZoom,
            );
          },
          returnsNormally,
          reason: 'polar fix must not crash the kernel',
        );
        expect(mask, isNotNull);
        expect(mask!.length, kRevealedTileBitmapBytes);
      },
    );

    test('non-positive radius returns an all-zero mask (defensive)', () {
      const fixLat = 45.0;
      const fixLon = 5.0;
      final homeTile = TileMath.latLonToTile(
        lat: fixLat,
        lon: fixLon,
        zoom: kRevealedTileParentZoom,
      );

      final maskZero = computeRevealMask(
        centerLat: fixLat,
        centerLon: fixLon,
        radiusMeters: 0.0,
        parentX: homeTile.x,
        parentY: homeTile.y,
        parentZoom: kRevealedTileParentZoom,
      );
      final maskNegative = computeRevealMask(
        centerLat: fixLat,
        centerLon: fixLon,
        radiusMeters: -10.0,
        parentX: homeTile.x,
        parentY: homeTile.y,
        parentZoom: kRevealedTileParentZoom,
      );

      expect(popcount(maskZero), 0, reason: 'r=0 must produce no-op mask');
      expect(popcount(maskNegative), 0, reason: 'r<0 must produce no-op mask');
    });

    test(
      'MIRK-03 no-micro-hole: cell partially touched by circle edge still flips',
      () {
        // Position the fix so the circle edge cuts through a cell whose CENTRE
        // is outside the disc. With a centre-inside test the cell would NOT
        // flip (micro-hole). With the rectangle-intersection test (MIRK-03)
        // the cell MUST flip.
        const fixLat = 45.0;
        const fixLon = 5.0;
        final homeTile = TileMath.latLonToTile(
          lat: fixLat,
          lon: fixLon,
          zoom: kRevealedTileParentZoom,
        );
        final tileNw = TileMath.tileToLatLon(
          x: homeTile.x,
          y: homeTile.y,
          zoom: kRevealedTileParentZoom,
        );
        final tileSe = TileMath.tileToLatLon(
          x: homeTile.x + 1,
          y: homeTile.y + 1,
          zoom: kRevealedTileParentZoom,
        );
        const cellsPerSide = kRevealedTileSubgridSize;
        final cellLatSpan = (tileNw.lat - tileSe.lat) / cellsPerSide;
        final cellLonSpan = (tileSe.lon - tileNw.lon) / cellsPerSide;

        // Place the fix at the SHARED CORNER of cells (j, i) and (j+1, i+1) for
        // mid-tile j, i. A small radius then forms a disc tangent-touching all
        // 4 surrounding cells without their centres being inside the disc.
        const j = 32;
        const i = 32;
        final cornerLat = tileNw.lat - j * cellLatSpan;
        final cornerLon = tileNw.lon + i * cellLonSpan;

        // Use 1 m so the centres of all 4 surrounding cells (which are
        // ~ half-cell ≈ 19 m + 13 m off the corner) sit OUTSIDE the disc — a
        // centre-inside heuristic would reveal zero cells.
        final mask = computeRevealMask(
          centerLat: cornerLat,
          centerLon: cornerLon,
          radiusMeters: 1.0,
          parentX: homeTile.x,
          parentY: homeTile.y,
          parentZoom: kRevealedTileParentZoom,
        );

        // MIRK-03 invariant: at least one cell adjacent to the corner must flip.
        // (A pure centre-inside heuristic at this geometry yields popcount=0.)
        expect(
          popcount(mask),
          greaterThan(0),
          reason:
              'MIRK-03 invariant: edge-touched cell must flip even when its centre is outside the circle',
        );
      },
    );
  });

  group('09-03 — computeRevealMask Phase 03 contract regression', () {
    // Phase 03 committed `computeRevealMask` as throwing `UnimplementedError`;
    // the inline `expect(..., throwsA(...))` lived in `test/domain/reveal_calculator_test.dart`.
    // With Phase 09 plan 09-03 implementing the body, that placeholder
    // contract is retired — we now assert the kernel returns the canonical
    // 512-byte buffer for any well-formed input.
    test(
      'returns a 512-byte Uint8List for well-formed input (no longer throws)',
      () {
        final mask = computeRevealMask(
          centerLat: 0.0,
          centerLon: 0.0,
          radiusMeters: 50.0,
          parentX: 0,
          parentY: 0,
          parentZoom: kRevealedTileParentZoom,
        );
        expect(mask, isA<Uint8List>());
        expect(mask.length, kRevealedTileBitmapBytes);
      },
    );
  });
}
