// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Type-safe wrapper for marker-category identifiers.
///
/// Reserved well-known value: `cat_default` (see [`kCategoryDefaultId`] in
/// `default_ids.dart`) — the reassign target when a custom category is
/// deleted. Its body deliberately is NOT a 26-char ULID, so the
/// reserved sentinel is recognizable at a glance.
extension type const CategoryId(String value) {
  /// Prefix embedded in every category ID.
  static const String prefix = 'cat_';

  /// True iff [value] starts with [prefix] and the ULID body has the
  /// canonical 26-char length.
  ///
  /// Returns false for the reserved [`kCategoryDefaultId`] (`cat_default`)
  /// — that constant uses a non-ULID body by design (see `default_ids.dart`).
  bool get isValid => value.startsWith(prefix) && value.length == prefix.length + 26;
}
