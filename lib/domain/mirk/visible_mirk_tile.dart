// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'visible_mirk_tile.freezed.dart';

/// One parent tile's data, pre-projected for the current frame.
///
/// Populated by the Phase 09 `visibleMirkTilesProvider` (plan 09-07) for
/// every parent tile intersecting the current viewport. Cached per-frame
/// so renderers iterate a list rather than re-resolving store data on
/// every paint pass.
///
/// Pre-computed tile lat/lon extents (north/west/south/east) spare the
/// renderer from calling `TileMath.tileToLatLon` four times per tile per
/// frame — measurable hot-loop saving at z=14 with 50–100 visible tiles.
///
/// ## `dart:typed_data` in domain
///
/// `Uint8List` comes from `dart:typed_data` (Dart stdlib). The domain
/// purity gate (`tool/check_domain_purity.dart`) only forbids
/// `package:flutter/*` and `package:drift/*`; stdlib imports including
/// `dart:typed_data` are allowed (precedent: `dart:ui` in
/// `mirk_renderer.dart`).
@freezed
abstract class VisibleMirkTile with _$VisibleMirkTile {
  const factory VisibleMirkTile({
    required int parentX,
    required int parentY,
    required Uint8List bitmap,
    required double tileNorthLat,
    required double tileWestLon,
    required double tileSouthLat,
    required double tileEastLon,
  }) = _VisibleMirkTile;
}
