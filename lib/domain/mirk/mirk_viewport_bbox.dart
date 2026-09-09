// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mirkfall/domain/revealed/tile_math.dart';

part 'mirk_viewport_bbox.freezed.dart';

/// Freezed view of a lat/lon bbox decoupled from the map-engine types.
///
/// Represented as four doubles — NOT the engine's `LatLngBounds` — so
/// consumers in `lib/domain/` and the [MirkPaintContext] stay engine-type-free
/// per the MAP-06 seam discipline. The flutter_map adapter in
/// `lib/infrastructure/map/` and the `FogLayer` painter convert
/// `LatLngBounds` → `MirkViewportBbox` at the perimeter.
///
/// ## Antimeridian wrap
///
/// `east < west` is permitted when the viewport crosses the ±180° line —
/// concretely when `west > 0 && east < 0` (e.g. west=170°, east=-170°).
/// The primary user of this semantic is the Phase 09
/// `RevealStreamingController.visibleParentTilesAtZ14` helper (plan 09-03);
/// [padMirkViewportBbox] produces such a bbox when the padding crosses the
/// seam.
@freezed
abstract class MirkViewportBbox with _$MirkViewportBbox {
  @Assert('south <= north', 'MirkViewportBbox: south must be <= north (got south=\$south, north=\$north)')
  @Assert('west <= east || (west > 0 && east < 0)', 'MirkViewportBbox: east < west only permitted on antimeridian wrap')
  factory MirkViewportBbox({required double south, required double west, required double north, required double east}) = _MirkViewportBbox;
}

/// Full turn of longitude, in degrees.
const double _fullCircleDeg = 360.0;

/// Half turn of longitude — the antimeridian, in degrees.
const double _halfCircleDeg = 180.0;

/// Widens [bbox] by [factor] × its height above and below and [factor] × its
/// width on each side — the disc query of the `FogLayerConnector` fetches the
/// ring around the viewport ahead of a pan, so discs at the edge already exist
/// when they scroll into view between two throttled bbox refreshes (RESEARCH §7).
///
/// Latitude is clamped to the Web Mercator limit (±[TileMath.maxLatMercator]).
/// Longitude wraps into `[-180, 180)`, so a padded bbox may legitimately cross
/// the antimeridian (`east < west` with `west > 0 && east < 0`, the wrap
/// convention of [MirkViewportBbox]). A padded span the convention cannot
/// express — 360° or more, or a wrapped pair with both edges on the same side
/// of 0° — degrades to the whole longitude range: over-fetching the ring is
/// harmless, an `AssertionError` on a frame is not.
MirkViewportBbox padMirkViewportBbox(MirkViewportBbox bbox, double factor) {
  final double latPadding = (bbox.north - bbox.south) * factor;
  final double lonSpan = _longitudeSpanDegrees(bbox);
  final double lonPadding = lonSpan * factor;
  final double south = (bbox.south - latPadding).clamp(-TileMath.maxLatMercator, TileMath.maxLatMercator);
  final double north = (bbox.north + latPadding).clamp(-TileMath.maxLatMercator, TileMath.maxLatMercator);
  if (lonSpan + 2 * lonPadding >= _fullCircleDeg) {
    return MirkViewportBbox(south: south, west: -_halfCircleDeg, north: north, east: _halfCircleDeg);
  }
  final double west = _wrapLongitude(bbox.west - lonPadding);
  final double east = _wrapLongitude(bbox.east + lonPadding);
  final bool representable = west <= east || (west > 0 && east < 0);
  if (!representable) {
    return MirkViewportBbox(south: south, west: -_halfCircleDeg, north: north, east: _halfCircleDeg);
  }
  return MirkViewportBbox(south: south, west: west, north: north, east: east);
}

/// Width of [bbox] in degrees of longitude, counting across the antimeridian
/// when the bbox wraps (`east < west`).
double _longitudeSpanDegrees(MirkViewportBbox bbox) => bbox.east >= bbox.west ? bbox.east - bbox.west : bbox.east + _fullCircleDeg - bbox.west;

/// Maps any longitude into `[-180, 180)`. Values already inside the range are
/// returned untouched (the modulo would add float noise and change the family
/// key of an otherwise identical query). Dart's `%` is a Euclidean modulo
/// (non-negative for a positive divisor), so `-190` → `170` and `190` → `-170`.
double _wrapLongitude(double longitude) {
  if (longitude >= -_halfCircleDeg && longitude < _halfCircleDeg) return longitude;
  return ((longitude + _halfCircleDeg) % _fullCircleDeg) - _halfCircleDeg;
}
