// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:mirkfall/config/constants.dart';

import 'tile_math.dart';

/// Bytewise OR of two equal-length bitmaps.
///
/// Returns a NEW [Uint8List] — neither input is mutated. The operation
/// is the algebraic foundation of MIRK-03:
/// - **Idempotent:** `mergeBitmap(mergeBitmap(a, b), a) == mergeBitmap(a, b)`
///   because `(a | b) | a == a | b`.
/// - **Commutative:** `mergeBitmap(a, b) == mergeBitmap(b, a)` because
///   `a | b == b | a`.
/// - **Monotone:** for every byte index `i`, `result[i] | a[i] == result[i]`
///   (no bit ever turns off — once revealed, always revealed).
///
/// Throws [ArgumentError] if [current] and [mask] have different lengths.
Uint8List mergeBitmap(Uint8List current, Uint8List mask) {
  if (current.length != mask.length) {
    throw ArgumentError.value(mask, 'mask', 'length ${mask.length} != current length ${current.length}');
  }
  final result = Uint8List(current.length);
  for (var i = 0; i < current.length; i++) {
    result[i] = current[i] | mask[i];
  }
  return result;
}

/// Population count (number of set bits) in [bytes].
///
/// Uses the classic SWAR popcount per byte — three masks, four ops, O(n)
/// in bytes. Fast enough at the 512-byte revealed-tile size that the
/// outer loop dominates.
int popcount(Uint8List bytes) {
  var count = 0;
  for (final b in bytes) {
    var v = b;
    v = v - ((v >> 1) & 0x55);
    v = (v & 0x33) + ((v >> 2) & 0x33);
    count += (v + (v >> 4)) & 0x0F;
  }
  return count;
}

/// Builds the 64×64 reveal mask for a circle centered at ([centerLat],
/// [centerLon]) with [radiusMeters], restricted to the bitmap extent of
/// parent tile ([parentX], [parentY], [parentZoom]).
///
/// Algorithm (per 09-RESEARCH §computeRevealMask Algorithm Specification):
/// 1. Defensive early-exit on `radiusMeters <= 0`.
/// 2. Parent-tile bbox via [TileMath.tileToLatLon] (NW + SE corners).
/// 3. Circle bbox via crude Mercator expansion
///    (1° lat ≈ [kMetersPerDegreeLat] m; 1° lon scaled by `cos(lat)`).
/// 4. Bbox-first prune — if circle bbox does not overlap parent-tile
///    bbox, return an all-zero 512-byte mask without entering the cell
///    loop.
/// 5. Clip the cell-index range to [0, 63] then per (i, j) compute the
///    closest point on the cell rectangle to the circle centre
///    (axis-clamp), then [_haversineMeters] distance. If the distance is
///    ≤ [radiusMeters] → flip bit `j * 64 + i` (MIRK-03 invariant —
///    rectangle-intersection test, not centre-inside).
///
/// Bit layout: `bit (j * 64 + i)`, byte `bit >> 3`, offset `bit & 7`.
/// Matches the [mergeBitmap] / [popcount] format above and the storage
/// convention in `RevealedTile.bitmap`.
Uint8List computeRevealMask({
  required double centerLat,
  required double centerLon,
  required double radiusMeters,
  required int parentX,
  required int parentY,
  required int parentZoom,
}) {
  final mask = Uint8List(kRevealedTileBitmapBytes);
  if (radiusMeters <= 0.0) return mask;

  final parentNw = TileMath.tileToLatLon(x: parentX, y: parentY, zoom: parentZoom);
  final parentSe = TileMath.tileToLatLon(x: parentX + 1, y: parentY + 1, zoom: parentZoom);

  // Crude Mercator inverse: degrees per metre. The longitude scale uses
  // the latitude of the circle centre because we only need the bbox
  // estimate accurate enough to skip clearly-outside tiles — the
  // per-cell Haversine inside the loop is what actually decides reveal.
  final latDegPerMeter = 1.0 / kMetersPerDegreeLat;
  // Guard the cosine against the polar Mercator clamp (cos(85.0511°) ≈
  // 0.087 ≠ 0; cos(±90°) would zero-divide). Latitudes outside
  // ±[TileMath.maxLatMercator] are projected back into-range here.
  final clampedCosLat = math.cos(_toRad(centerLat.clamp(-TileMath.maxLatMercator, TileMath.maxLatMercator)));
  final lonDegPerMeter = 1.0 / (kMetersPerDegreeLat * clampedCosLat);

  final circleMinLat = centerLat - radiusMeters * latDegPerMeter;
  final circleMaxLat = centerLat + radiusMeters * latDegPerMeter;
  final circleMinLon = centerLon - radiusMeters * lonDegPerMeter;
  final circleMaxLon = centerLon + radiusMeters * lonDegPerMeter;

  // Bbox-first prune. Lat decreases northward to southward in the parent
  // tile (NW corner has the maximum lat), so parentNw.lat > parentSe.lat
  // and parentNw.lon < parentSe.lon.
  final outsideLat = circleMaxLat < parentSe.lat || circleMinLat > parentNw.lat;
  final outsideLon = circleMaxLon < parentNw.lon || circleMinLon > parentSe.lon;
  if (outsideLat || outsideLon) return mask;

  const cellsPerSide = kRevealedTileSubgridSize; // 64
  final cellLatSpan = (parentNw.lat - parentSe.lat) / cellsPerSide;
  final cellLonSpan = (parentSe.lon - parentNw.lon) / cellsPerSide;

  // Clip the touched-cell rectangle. j=0 is the NORTHmost row;
  // i=0 is the WESTmost column.
  final jStartRaw = ((parentNw.lat - circleMaxLat) / cellLatSpan).floor();
  final jEndRaw = ((parentNw.lat - circleMinLat) / cellLatSpan).ceil();
  final iStartRaw = ((circleMinLon - parentNw.lon) / cellLonSpan).floor();
  final iEndRaw = ((circleMaxLon - parentNw.lon) / cellLonSpan).ceil();
  final jStart = math.max(0, jStartRaw);
  final jEnd = math.min(cellsPerSide - 1, jEndRaw);
  final iStart = math.max(0, iStartRaw);
  final iEnd = math.min(cellsPerSide - 1, iEndRaw);

  for (var j = jStart; j <= jEnd; j++) {
    final cellNorthLat = parentNw.lat - j * cellLatSpan;
    final cellSouthLat = parentNw.lat - (j + 1) * cellLatSpan;
    for (var i = iStart; i <= iEnd; i++) {
      final cellWestLon = parentNw.lon + i * cellLonSpan;
      final cellEastLon = parentNw.lon + (i + 1) * cellLonSpan;

      // Closest point on the cell rectangle to the circle centre
      // (axis-clamp). For a centre INSIDE the rectangle the clamps are
      // no-ops and the Haversine returns 0 → cell flips. For an outside
      // centre the closest edge / corner is returned.
      final closestLat = _clampDouble(centerLat, cellSouthLat, cellNorthLat);
      final closestLon = _clampDouble(centerLon, cellWestLon, cellEastLon);

      final distance = _haversineMeters(centerLat, centerLon, closestLat, closestLon);
      if (distance <= radiusMeters) {
        final bitIndex = j * cellsPerSide + i;
        final byteIndex = bitIndex >> 3;
        final bitOffset = bitIndex & 7;
        mask[byteIndex] |= 1 << bitOffset;
      }
    }
  }
  return mask;
}

// ---------------------------------------------------------------------------
// Helpers (private, top-level).
//
// `kMetersPerDegreeLat` and `kEarthRadiusMeters` live in
// `lib/config/constants.dart` — three call sites across the revealed-domain
// code (this file, `reveal_disc.dart`, `revealed_sdf_builder.dart`) share
// them, promoted out of file-private duplication.
// ---------------------------------------------------------------------------

/// Degrees → radians.
double _toRad(double deg) => deg * math.pi / 180.0;

/// Local clamp that does not depend on `num.clamp` boxing semantics —
/// keeps the inner loop in pure double arithmetic.
double _clampDouble(double value, double low, double high) {
  if (value < low) return low;
  if (value > high) return high;
  return value;
}

/// Great-circle distance between two (lat, lon) pairs, in metres, via
/// the Haversine formula. Choice of Haversine (vs Vincenty) per
/// 09-RESEARCH: better accuracy at small radii than the equirectangular
/// approximation, far cheaper than Vincenty, and the metre-scale
/// difference at ≤ 25 m radius is negligible at any latitude.
double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final l1 = _toRad(lat1);
  final l2 = _toRad(lat2);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(l1) * math.cos(l2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return kEarthRadiusMeters * c;
}
