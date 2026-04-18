// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

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
/// **NOT IMPLEMENTED in Phase 03** — the geometry kernel is finalized in
/// Phase 09 alongside the fog renderer (MIRK-01..02). The signature is
/// committed here so:
/// - 03-06 stores can import the symbol and write idempotence tests
///   using pre-computed fixture masks.
/// - The Phase 09 implementation lands as a body change with no caller
///   churn.
Uint8List computeRevealMask({
  required double centerLat,
  required double centerLon,
  required double radiusMeters,
  required int parentX,
  required int parentY,
  required int parentZoom,
}) {
  throw UnimplementedError(
    'computeRevealMask is finalized in Phase 09 (fog rendering). '
    'Phase 03 commits only the signature + algebra primitives '
    '(mergeBitmap, popcount).',
  );
}
