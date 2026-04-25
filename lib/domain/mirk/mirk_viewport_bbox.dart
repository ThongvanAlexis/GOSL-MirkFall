// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Bounding box of the current map viewport, expressed in lat/lon.
///
/// Phase 09 introduces this type to keep [MirkPaintContext] free of
/// MapLibre types (`LatLngBounds`) per the MAP-06 seam discipline. The
/// real Freezed declaration lands in plan 09-02; Wave 0 emits this
/// placeholder so downstream scaffolds can import the type name.
///
/// TODO(09-02): replace with `@freezed abstract class MirkViewportBbox`.
class MirkViewportBbox {
  const MirkViewportBbox({required this.south, required this.west, required this.north, required this.east});
  final double south;
  final double west;
  final double north;
  final double east;
}
