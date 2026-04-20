// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Zero-cost wrapper over a validated ISO-3166-1 alpha-3 country code
/// (always lower-case, exactly 3 ASCII letters).
///
/// Compiles to a plain `String` at runtime (Dart 3 extension type) but the
/// type system rejects cross-type assignment (`String` → `CountryCode` is a
/// static error), preventing a class of bugs where a raw alpha-3 string is
/// passed where a validated one is required.
///
/// Construction is validated through [CountryCode.parse]. The private
/// unnamed constructor [CountryCode._] is reserved for domain-internal use
/// (e.g. the [CountryCode.world] sentinel) so callers can never bypass
/// validation.
///
/// ## The reserved `'wld'` code
///
/// `'wld'` is a **domain-reserved** alpha-3 code identifying the bundled
/// world basemap (shipped as `assets/maps/world.pmtiles`). The sentinel
/// [CountryCode.world] exposes this reserved value as a domain-locked
/// constant. `CountryCode.parse('wld')` succeeds and returns a value
/// equal to [CountryCode.world] — the sentinel is a valid [CountryCode]
/// like any other. Callers that want to reject or guard against the world
/// bundle (e.g. `CountryDeleteService` in Plan 07-04) MUST compare against
/// [CountryCode.world] rather than the raw string literal `'wld'`.
///
/// The raw-literal comparison path would silently break if ISO-3166-1
/// ever reassigned `'wld'` to a real country or if the reserved value was
/// ever renamed — the sentinel compare stays correct under both
/// evolutions.
extension type const CountryCode._(String value) {
  /// Parses [raw] into a validated [CountryCode].
  ///
  /// Validation rules:
  /// - Length == 3
  /// - Every char is ASCII `a-z` or `A-Z`
  /// - Input is lower-cased before wrapping
  ///
  /// Throws [FormatException] on any failure, with a message identifying
  /// which rule was violated.
  factory CountryCode.parse(String raw) {
    if (raw.length != 3) {
      throw FormatException('CountryCode must be exactly 3 chars, got ${raw.length}: "$raw"');
    }
    for (var i = 0; i < raw.length; i++) {
      final int code = raw.codeUnitAt(i);
      final bool isUpper = code >= 0x41 && code <= 0x5A; // 'A'-'Z'
      final bool isLower = code >= 0x61 && code <= 0x7A; // 'a'-'z'
      if (!isUpper && !isLower) {
        throw FormatException('CountryCode must be ASCII alpha only, got "$raw"');
      }
    }
    return CountryCode._(raw.toLowerCase());
  }

  /// Domain-locked sentinel for the bundled world basemap. See the class
  /// docstring for the reservation contract.
  static const CountryCode world = CountryCode._('wld');
}

/// json_serializable converter — JSON string → [CountryCode]. Declared as
/// a top-level function (not a `JsonConverter` class) because the
/// json_serializable generator resolves extension-type `T` through its
/// underlying representation at declaration-time, and the class-based
/// `JsonConverter<CountryCode, String>` approach does not round-trip (same
/// carve-out as Phase 03's `id_json_converters.dart`). Wire per-field via
/// `@JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson)`.
CountryCode countryCodeFromJson(String json) => CountryCode.parse(json);

/// json_serializable converter — [CountryCode] → JSON string.
String countryCodeToJson(CountryCode value) => value.value;
