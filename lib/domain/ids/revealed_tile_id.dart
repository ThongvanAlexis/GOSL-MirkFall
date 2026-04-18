// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Type-safe wrapper for revealed-tile identifiers.
///
/// See [SessionId] doc-comment for the prefix-in-value rationale and the
/// extension-type cost model — same shape, same trade-offs.
extension type const RevealedTileId(String value) {
  /// Prefix embedded in every revealed-tile ID.
  static const String prefix = 'rvt_';

  /// True iff [value] starts with [prefix] and the ULID body has the
  /// canonical 26-char length.
  bool get isValid => value.startsWith(prefix) && value.length == prefix.length + 26;
}
