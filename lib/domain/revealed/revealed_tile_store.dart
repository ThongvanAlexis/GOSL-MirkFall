// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import '../ids/session_id.dart';
import 'revealed_tile.dart';

/// Port for revealed-tile persistence + MIRK-03 merge semantic.
///
/// Implementations live in `lib/infrastructure/stores/` (Phase 03-06 Drift
/// impl). The contract is deliberately narrow: the UI reads whole rows,
/// the GPS pipeline merges masks — no partial reads, no bit-level
/// accessors at this layer.
abstract class RevealedTileStore {
  /// Returns all revealed tiles for [sessionId], ordered by
  /// `(parentX, parentY)` ascending.
  Future<List<RevealedTile>> listBySession(SessionId sessionId);

  /// Returns the revealed tile at `(parentX, parentY)` for [sessionId],
  /// or null if no row has been written yet.
  Future<RevealedTile?> findByParent({
    required SessionId sessionId,
    required int parentX,
    required int parentY,
  });

  /// Merges [mask] into the bitmap for `(sessionId, parentX, parentY)` at
  /// the default parent zoom (`kRevealedTileParentZoom` = 14).
  ///
  /// Semantic is **monotonically OR-merged** (MIRK-03): a bit set to 1 in
  /// the existing row can never be unset by a subsequent merge within a
  /// session. Creates the row (popcount = `popcount(mask)`) if absent;
  /// otherwise updates in place with `newBitmap[i] = oldBitmap[i] | mask[i]`
  /// byte-wise.
  ///
  /// [mask] MUST be exactly `kRevealedTileBitmapBytes` long (512 bytes).
  /// Implementations throw `ArgumentError` on a mask of wrong length.
  Future<void> mergeMask({
    required SessionId sessionId,
    required int parentX,
    required int parentY,
    required Uint8List mask,
  });
}
