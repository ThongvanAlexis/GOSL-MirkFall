// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/revealed/reveal_calculator.dart';
import 'package:mirkfall/domain/revealed/tile_math.dart';
import 'package:test/test.dart';

/// Phase 09 plan 09-03 — parent-tile boundary split case (MIRK-01).
///
/// When a fix sits near the edge of a zoom-14 parent tile, the disc
/// straddles two (or four) parent tiles. The kernel itself is per-tile —
/// the streaming controller (plan 09-06) walks the touched parent set —
/// but here we exercise the per-tile contract: calling once per tile must
/// produce two non-empty bitmaps whose union covers the full disc, with
/// no double-counted bits in the overlap (each cell belongs to exactly
/// one parent tile by construction).
void main() {
  group('09-03 — computeRevealMask parent-tile boundary split (MIRK-01)', () {
    test(
      'circle straddling east-west boundary populates both neighbour tiles',
      () {
        // Anchor the fix slightly east of a tile's WEST edge so the disc
        // crosses into the western neighbour tile. We pick lat 45° / lon 5°
        // for unambiguous tile coords, then place the fix at the WEST edge
        // of the home tile.
        const fixLat = 45.0;
        const seedLon = 5.0;
        final homeTile = TileMath.latLonToTile(
          lat: fixLat,
          lon: seedLon,
          zoom: kRevealedTileParentZoom,
        );
        final homeNw = TileMath.tileToLatLon(
          x: homeTile.x,
          y: homeTile.y,
          zoom: kRevealedTileParentZoom,
        );

        // Place fix exactly on the west boundary (epsilon east so it is
        // unambiguously inside the home tile per the half-open NW convention).
        final fixLon = homeNw.lon + 1e-9;

        final radiusMeters =
            kDefaultRevealRadiusMeters *
            4; // 100 m disc to comfortably straddle a ~38 m cell band
        final homeMask = computeRevealMask(
          centerLat: fixLat,
          centerLon: fixLon,
          radiusMeters: radiusMeters,
          parentX: homeTile.x,
          parentY: homeTile.y,
          parentZoom: kRevealedTileParentZoom,
        );
        final westMask = computeRevealMask(
          centerLat: fixLat,
          centerLon: fixLon,
          radiusMeters: radiusMeters,
          parentX: homeTile.x - 1,
          parentY: homeTile.y,
          parentZoom: kRevealedTileParentZoom,
        );

        expect(homeMask.length, kRevealedTileBitmapBytes);
        expect(westMask.length, kRevealedTileBitmapBytes);
        expect(
          popcount(homeMask),
          greaterThan(0),
          reason: 'home tile must contain part of the disc',
        );
        expect(
          popcount(westMask),
          greaterThan(0),
          reason: 'west neighbour must contain the leaked portion of the disc',
        );
        // Together they must reveal more than the home tile alone.
        final unionPopcount = popcount(_orMasks(homeMask, westMask));
        expect(
          unionPopcount,
          equals(popcount(homeMask) + popcount(westMask)),
          reason:
              'home + west cells are disjoint by construction (different parent tiles)',
        );
      },
    );

    test(
      'circle straddling north-south boundary populates both neighbour tiles',
      () {
        const fixLat = 45.0;
        const fixLonSeed = 5.0;
        final homeTile = TileMath.latLonToTile(
          lat: fixLat,
          lon: fixLonSeed,
          zoom: kRevealedTileParentZoom,
        );
        final homeNw = TileMath.tileToLatLon(
          x: homeTile.x,
          y: homeTile.y,
          zoom: kRevealedTileParentZoom,
        );

        // Place fix on the NORTH edge of the home tile so the disc leaks
        // into the northern neighbour (parentY - 1).
        final fixLatOnEdge = homeNw.lat - 1e-9;
        final fixLon =
            homeNw.lon + 0.001; // safely inside the tile longitudinally

        final radiusMeters = kDefaultRevealRadiusMeters * 4;
        final homeMask = computeRevealMask(
          centerLat: fixLatOnEdge,
          centerLon: fixLon,
          radiusMeters: radiusMeters,
          parentX: homeTile.x,
          parentY: homeTile.y,
          parentZoom: kRevealedTileParentZoom,
        );
        final northMask = computeRevealMask(
          centerLat: fixLatOnEdge,
          centerLon: fixLon,
          radiusMeters: radiusMeters,
          parentX: homeTile.x,
          parentY: homeTile.y - 1,
          parentZoom: kRevealedTileParentZoom,
        );

        expect(
          popcount(homeMask),
          greaterThan(0),
          reason: 'home tile must contain south half of disc',
        );
        expect(
          popcount(northMask),
          greaterThan(0),
          reason: 'north neighbour must contain the leaked portion',
        );
        final unionPopcount = popcount(_orMasks(homeMask, northMask));
        expect(
          unionPopcount,
          equals(popcount(homeMask) + popcount(northMask)),
          reason: 'home + north cells are disjoint by construction',
        );
      },
    );

    test('circle far from any boundary populates only the home tile', () {
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

      // Default 25 m radius at the parent-tile centre cannot leak (parent tile
      // is ~2444 m × 1727 m at lat 45° z=14, much larger than the disc).
      final eastMask = computeRevealMask(
        centerLat: centreLat,
        centerLon: centreLon,
        radiusMeters: kDefaultRevealRadiusMeters,
        parentX: homeTile.x + 1,
        parentY: homeTile.y,
        parentZoom: kRevealedTileParentZoom,
      );
      final westMask = computeRevealMask(
        centerLat: centreLat,
        centerLon: centreLon,
        radiusMeters: kDefaultRevealRadiusMeters,
        parentX: homeTile.x - 1,
        parentY: homeTile.y,
        parentZoom: kRevealedTileParentZoom,
      );
      final northMask = computeRevealMask(
        centerLat: centreLat,
        centerLon: centreLon,
        radiusMeters: kDefaultRevealRadiusMeters,
        parentX: homeTile.x,
        parentY: homeTile.y - 1,
        parentZoom: kRevealedTileParentZoom,
      );
      final southMask = computeRevealMask(
        centerLat: centreLat,
        centerLon: centreLon,
        radiusMeters: kDefaultRevealRadiusMeters,
        parentX: homeTile.x,
        parentY: homeTile.y + 1,
        parentZoom: kRevealedTileParentZoom,
      );

      expect(popcount(eastMask), 0, reason: 'east neighbour must be untouched');
      expect(popcount(westMask), 0, reason: 'west neighbour must be untouched');
      expect(
        popcount(northMask),
        0,
        reason: 'north neighbour must be untouched',
      );
      expect(
        popcount(southMask),
        0,
        reason: 'south neighbour must be untouched',
      );
    });
  });
}

/// Helper: bytewise OR of two equal-length 512-byte masks.
Uint8List _orMasks(Uint8List a, Uint8List b) {
  final out = Uint8List(a.length);
  for (var i = 0; i < a.length; i++) {
    out[i] = a[i] | b[i];
  }
  return out;
}
