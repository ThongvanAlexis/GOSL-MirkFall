// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Type-safe wrapper for session identifiers.
///
/// Zero-cost at runtime (Dart 3 extension type) — identical to a plain
/// `String` in IL, but the compiler rejects cross-type assignment
/// (`MarkerId` → `SessionId` is a static error). Keeps the prefix in
/// the stored value so an ID lifted from logs / SQL inspector / a bug
/// report is immediately identifiable without context.
extension type const SessionId(String value) {
  /// Prefix embedded in every session ID. Storing it inside [value] (rather
  /// than tacking it on at JSON serialization time) is the deliberate choice:
  /// a copy-pasted ID is self-describing.
  static const String prefix = 'sess_';

  /// Parses a raw string into a [SessionId], validating the prefix. Throws
  /// [ArgumentError] on mismatch — use the plain constructor when the
  /// value is already known-good (e.g. hydrating a DB row). Mirrors
  /// [FixId.parse]; callers hydrating from notification `resume:<id>`
  /// payloads or import files need a parse-with-validation helper rather
  /// than a best-effort `isValid` check after construction.
  factory SessionId.parse(String raw) {
    if (!raw.startsWith(prefix)) {
      throw ArgumentError.value(raw, 'raw', 'Expected $prefix prefix');
    }
    return SessionId(raw);
  }

  /// True iff [value] starts with [prefix] and the ULID body has the
  /// canonical 26-char length.
  bool get isValid => value.startsWith(prefix) && value.length == prefix.length + 26;
}
