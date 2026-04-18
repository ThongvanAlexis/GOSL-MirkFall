// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math';

/// Slippy-map tile coordinate triple (x, y, zoom).
///
/// Reference: https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
class TilePosition {
  const TilePosition({required this.x, required this.y, required this.zoom});

  final int x;
  final int y;
  final int zoom;

  @override
  bool operator ==(Object other) =>
      other is TilePosition && other.x == x && other.y == y && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(x, y, zoom);

  @override
  String toString() => 'TilePosition($x, $y, z=$zoom)';
}

/// Slippy-map tile math — OSM Web Mercator projection (EPSG:3857).
///
/// Static-only namespace; instantiation has no meaning. The two public
/// converters are inverses within the floor-rounding tolerance of the
/// tile grid (NW-corner convention — `tileToLatLon` returns the
/// north-west corner of the tile, not the center).
class TileMath {
  TileMath._();

  /// Web-Mercator latitude clamp per OSM. Beyond ±85.0511° the projection
  /// stretches the map asymptotically (poles are at infinity), so polar
  /// inputs are clamped here rather than producing NaN downstream.
  static const double maxLatMercator = 85.05112878;

  /// Converts a (lat, lon) pair to a tile position at [zoom]. Polar inputs
  /// (|lat| > [maxLatMercator]) are clamped to the Mercator-valid range
  /// before projection so the result is always in `[0, 2^zoom)`.
  static TilePosition latLonToTile({
    required double lat,
    required double lon,
    required int zoom,
  }) {
    final clampedLat = lat.clamp(-maxLatMercator, maxLatMercator);
    final n = pow(2.0, zoom).toDouble();
    final maxIndex = n.toInt() - 1;
    final latRad = clampedLat * pi / 180.0;
    // Floating-point math near the Mercator clamp can spit out values just
    // outside [0, n-1] (e.g. y = -1 for clampedLat = +85.0511). Clamp the
    // tile indices defensively so callers always get a valid array address.
    final x = ((lon + 180.0) / 360.0 * n).floor().clamp(0, maxIndex);
    final y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n).floor().clamp(0, maxIndex);
    return TilePosition(x: x, y: y, zoom: zoom);
  }

  /// Returns the NW corner of tile ([x], [y], [zoom]) as a `(lat, lon)`
  /// record. Inverse of [latLonToTile] within floor-rounding tolerance.
  static ({double lat, double lon}) tileToLatLon({
    required int x,
    required int y,
    required int zoom,
  }) {
    final n = pow(2.0, zoom).toDouble();
    final lon = x / n * 360.0 - 180.0;
    final latRad = atan(_sinh(pi * (1.0 - 2.0 * y / n)));
    return (lat: latRad * 180.0 / pi, lon: lon);
  }

  /// Hyperbolic sine — `dart:math` does not ship `sinh`, so we inline it.
  static double _sinh(double x) => (exp(x) - exp(-x)) / 2.0;
}
