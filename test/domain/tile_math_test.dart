// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/revealed/tile_math.dart';
import 'package:test/test.dart';

void main() {
  group('TileMath.latLonToTile at zoom 14', () {
    test('Paris (48.8566, 2.3522) maps to tile around (8299, 5635)', () {
      // Reference: OSM Slippy Map calculator at lon=2.3522, lat=48.8566, z=14:
      //   x = floor((182.3522 / 360) * 16384) = floor(8299.06) = 8299
      //   y = floor((1 - asinh(tan(48.8566 deg)) / pi) / 2 * 16384) ≈ 5635
      final t = TileMath.latLonToTile(lat: 48.8566, lon: 2.3522, zoom: 14);
      expect(t.zoom, 14);
      expect(t.x, inInclusiveRange(8298, 8300));
      expect(t.y, inInclusiveRange(5634, 5636));
    });

    test('Equator (0, 0) maps to tile around (8192, 8192) at zoom 14', () {
      final t = TileMath.latLonToTile(lat: 0.0, lon: 0.0, zoom: 14);
      expect(t.x, inInclusiveRange(8191, 8192));
      expect(t.y, inInclusiveRange(8191, 8192));
    });

    test('North pole input clamps to Mercator limit and stays in valid range', () {
      final t = TileMath.latLonToTile(lat: 90, lon: 0, zoom: 14);
      expect(t.y, greaterThanOrEqualTo(0));
      expect(t.y, lessThan(1 << 14));
    });

    test('South pole input clamps and stays in valid range', () {
      final t = TileMath.latLonToTile(lat: -90, lon: 0, zoom: 14);
      expect(t.y, greaterThanOrEqualTo(0));
      expect(t.y, lessThan(1 << 14));
    });
  });

  group('TileMath.tileToLatLon', () {
    test('round-trip (8192, 8192) at zoom 14 is approximately (0, 0)', () {
      final ll = TileMath.tileToLatLon(x: 8192, y: 8192, zoom: 14);
      expect(ll.lat, closeTo(0.0, 0.1));
      expect(ll.lon, closeTo(0.0, 0.1));
    });
  });

  group('TilePosition value semantics', () {
    test('equal positions compare equal and share hashCode', () {
      const a = TilePosition(x: 1, y: 2, zoom: 14);
      const b = TilePosition(x: 1, y: 2, zoom: 14);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different positions are distinct', () {
      const a = TilePosition(x: 1, y: 2, zoom: 14);
      const c = TilePosition(x: 1, y: 3, zoom: 14);
      expect(a, isNot(c));
    });
  });
}
