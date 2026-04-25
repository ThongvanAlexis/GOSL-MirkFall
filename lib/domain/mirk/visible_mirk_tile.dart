// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

/// One parent tile's data, pre-projected for the current frame.
///
/// Phase 09 Wave 2 (plan 09-02) rewrites this as `@freezed` and folds it
/// into `MirkPaintContext.visibleTiles`. Wave 0 placeholder — downstream
/// renderer scaffolds (plan 09-04) import the type name.
///
/// TODO(09-02): replace with `@freezed abstract class VisibleMirkTile`.
class VisibleMirkTile {
  const VisibleMirkTile({
    required this.parentX,
    required this.parentY,
    required this.bitmap,
    required this.tileNorthLat,
    required this.tileWestLon,
    required this.tileSouthLat,
    required this.tileEastLon,
  });
  final int parentX;
  final int parentY;
  final Uint8List bitmap;
  final double tileNorthLat;
  final double tileWestLon;
  final double tileSouthLat;
  final double tileEastLon;
}
