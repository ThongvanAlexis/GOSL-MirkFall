# lib/domain/revealed/

Pure-Dart domain layer for revealed-mirk tiles + the MIRK-03 bitmap
algebra. No `package:flutter` / `package:drift` imports (enforced by
`tool/check_domain_purity.dart`).

## Contents

- `tile_math.dart` — Web Mercator slippy-map converters + `TilePosition`
  value class (shipped in 03-02).
- `reveal_calculator.dart` — `mergeBitmap` + `popcount` primitives
  (MIRK-03 algebra, 03-02).
- `revealed_tile.dart` — Freezed `RevealedTile` entity (parent-tile
  bitmap storage unit, decision D3: zoom-14 parent + 64×64 sub-grid =
  512-byte bitmap per row).
- `revealed_tile_store.dart` — Abstract `RevealedTileStore` port; the
  `mergeMask` contract is MIRK-03's monotonic OR semantic.

## Invariants

- `RevealedTile` is NEVER round-tripped through the Envelope export
  pipeline — `Uint8List` is not JSON-friendly. Phase 13 exports use a
  dedicated `RevealedTileExport` DTO with a base64-encoded bitmap; the
  Freezed entity itself has no `fromJson`/`toJson`.
- Every `(sessionId, parentX, parentY)` triple has at most one row per
  session (DB-enforced UNIQUE index).
- `mergeMask` is monotonically OR-merged: a bit set to 1 can never be
  unset within a session. The store throws on an out-of-bounds mask
  length (must equal `kRevealedTileBitmapBytes` = 512).
