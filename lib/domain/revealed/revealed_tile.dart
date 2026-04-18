// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../ids/revealed_tile_id.dart';
import '../ids/session_id.dart';

part 'revealed_tile.freezed.dart';

/// One zoom-14 parent tile with a 64×64 sub-grid bitmap (64² bits = 512 bytes
/// per [bitmap]) tracking which sub-tiles are revealed for a given session.
///
/// Decision D3 — revealed mirk is stored as parent tiles at zoom 14, each
/// carrying a dense 64×64 bitmap. [setBitCount] is precomputed (redundant
/// with a popcount over [bitmap]) so per-row stats queries avoid re-scanning
/// the 512-byte buffer.
///
/// NOTE: No `fromJson` / `toJson` — `RevealedTile` is NEVER round-tripped
/// through the [Envelope] export pipeline. The raw [Uint8List] bitmap is
/// not JSON-friendly; Phase 13 exports use a dedicated `RevealedTileExport`
/// DTO with a base64-encoded bitmap field. Revealed tiles are persisted
/// exclusively through the Drift store (Phase 03-06).
@freezed
abstract class RevealedTile with _$RevealedTile {
  const factory RevealedTile({
    required RevealedTileId id,
    required SessionId sessionId,
    required int parentX,
    required int parentY,
    @Default(14) int parentZoom,
    required Uint8List bitmap,
    required int setBitCount,
    required DateTime updatedAtUtc,
  }) = _RevealedTile;
}
