// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:freezed_annotation/freezed_annotation.dart';

part 'mirk_viewport_bbox.freezed.dart';

/// Freezed view of a lat/lon bbox decoupled from MapLibre types.
///
/// Represented as four doubles — NOT `LatLngBounds` — so consumers in
/// `lib/domain/` and the [MirkPaintContext] stay MapLibre-type-free per
/// the MAP-06 seam discipline. A thin adapter in
/// `lib/infrastructure/map/` converts `LatLngBounds` → `MirkViewportBbox`
/// at the platform boundary.
///
/// ## Antimeridian wrap
///
/// `east < west` is permitted when the viewport crosses the ±180° line —
/// concretely when `west > 0 && east < 0` (e.g. west=170°, east=-170°).
/// The primary user of this semantic is the Phase 09
/// `RevealStreamingController.visibleParentTilesAtZ14` helper (plan 09-03),
/// which relies on the same wrap convention used by MapLibre's
/// `LatLngBounds`.
@freezed
abstract class MirkViewportBbox with _$MirkViewportBbox {
  @Assert('south <= north', 'MirkViewportBbox: south must be <= north (got south=\$south, north=\$north)')
  @Assert('west <= east || (west > 0 && east < 0)', 'MirkViewportBbox: east < west only permitted on antimeridian wrap')
  factory MirkViewportBbox({required double south, required double west, required double north, required double east}) = _MirkViewportBbox;
}

/// Widens [bbox] by [factor] × its height above and below and [factor] × its width on
/// each side — the disc query of the `FogLayerConnector` fetches the ring around the
/// viewport ahead of a pan (RESEARCH §7). Latitude is clamped to the Web Mercator
/// limit; longitude wraps into `[-180, 180)`.
MirkViewportBbox padMirkViewportBbox(MirkViewportBbox bbox, double factor) => throw UnimplementedError('09.1-07 Task 1 GREEN');
