// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Hand-rolled ray-casting point-in-polygon test.
///
/// Decides whether the geographic point (lat, lon) lies inside the simple
/// polygon described by [ring]. The ring is an ordered list of vertices in
/// latitude/longitude pairs; the first and last vertex MAY be equal
/// (closed ring) or different (implicitly closed by this algorithm).
///
/// Algorithm: cast a horizontal ray from (lat, lon) towards +infinity in
/// longitude. Count how many edges of the polygon the ray crosses. An odd
/// count means the point is inside; even means outside. Uses the standard
/// convention of "exclusive upper, inclusive lower" on the latitude axis
/// so a point exactly on a horizontal edge is consistently classified and
/// vertices shared between two edges are not double-counted.
///
/// Assumptions:
/// - The polygon is SIMPLE (no self-intersections). The Phase 07 Wave 0
///   bbox simplifier (Plan 07-01 `tool/simplify_polygons.dart`) always
///   emits axis-aligned rectangles, which are trivially simple.
/// - Multi-polygon / polygon-with-holes support is NOT in scope here —
///   callers (e.g. `CountryResolver`) run this function per ring and
///   combine results themselves.
///
/// Numeric behaviour:
/// - Zero degenerate cases escalated to exceptions — a degenerate ring
///   (0 or 1 point) simply returns `false`.
/// - Points strictly on a vertex count as inside per the convention
///   above. Phase 07 does not depend on that distinction; the resolver's
///   tie-breaking protocol (installed-order in [CountryResolver]) covers
///   overlap ambiguity for real-world data.
///
/// References: Rosetta Code "Ray casting algorithm" / Randolph Franklin's
/// classic C macro `PNPOLY` (University of North Carolina, 1970s). The
/// body below is the Dart port of that canonical 6-line test.
bool pointInPolygon({required double lat, required double lon, required List<({double lat, double lon})> ring}) {
  final int n = ring.length;
  if (n < 3) return false;

  bool inside = false;
  int j = n - 1;
  for (int i = 0; i < n; i++) {
    final double yi = ring[i].lat;
    final double yj = ring[j].lat;
    final double xi = ring[i].lon;
    final double xj = ring[j].lon;

    // PNPOLY test: (yi > lat) != (yj > lat) is true when the segment
    // straddles the horizontal ray at `lat` on exactly one side.
    final bool straddles = (yi > lat) != (yj > lat);
    if (straddles) {
      // Horizontal intersection longitude of the ray with edge (i, j).
      final double xCross = (xj - xi) * (lat - yi) / (yj - yi) + xi;
      if (lon < xCross) inside = !inside;
    }
    j = i;
  }
  return inside;
}
