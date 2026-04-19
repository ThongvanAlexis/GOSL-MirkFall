// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Type-safe wrapper for fix identifiers.
///
/// Zero-cost at runtime (Dart 3 extension type) — identical to a plain
/// `String` in IL, but the compiler rejects cross-type assignment
/// (`SessionId` → `FixId` is a static error). The prefix (`fix_`) is
/// carried inside the stored value so a copy-pasted ID is
/// self-describing — identical convention to [SessionId].
extension type const FixId(String value) {
  /// Prefix embedded in every fix ID. Storing it inside [value] (rather
  /// than tacking it on at JSON serialization time) keeps the value
  /// self-describing in logs / SQL inspector output / bug reports.
  static const String prefix = 'fix_';

  /// Parses a raw string into a [FixId], validating the prefix. Throws
  /// [ArgumentError] on mismatch — use the plain constructor when the
  /// value is already known-good (e.g. hydrating a DB row).
  factory FixId.parse(String raw) {
    if (!raw.startsWith(prefix)) {
      throw ArgumentError.value(raw, 'raw', 'Expected $prefix prefix');
    }
    return FixId(raw);
  }

  /// True iff [value] starts with [prefix] and the ULID body has the
  /// canonical 26-char length.
  bool get isValid => value.startsWith(prefix) && value.length == prefix.length + 26;
}
