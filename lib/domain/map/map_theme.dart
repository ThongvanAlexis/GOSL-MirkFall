// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Sealed hierarchy of user-selectable map rendering themes.
///
/// Not a Freezed union — the variants carry no payload, so a vanilla
/// sealed class with `const` subclasses is the lightest shape. Any
/// future payload-carrying theme (e.g. `MapThemeCustom(colorTable)`)
/// can be added as a new variant without touching existing call sites
/// thanks to the exhaustive switch guarantee of `sealed`.
///
/// - [MapThemeStandard] is the Phase 07 default (the Protomaps-derived
///   neutral basemap shipped in `assets/maps/style.json`).
/// - [MapThemeRpgParchment] is a forward-declared stub for Phase 13
///   (creative rendering). Surfaced here so call sites in 07-04+ can
///   pattern-match over every variant without needing a cross-phase
///   refactor.
sealed class MapTheme {
  const MapTheme();

  /// Stable string identifier for cross-isolate / persistence round-trip.
  /// Used by `lib/infrastructure/map/` adapters to persist the user's
  /// theme choice via `shared_preferences` without coupling the
  /// persistence layer to a domain enum type (which would force a
  /// migration every time a new variant lands).
  String toJsonString() => switch (this) {
    MapThemeStandard() => 'standard',
    MapThemeRpgParchment() => 'rpgParchment',
  };

  /// Inverse of [toJsonString]. Throws [FormatException] on unknown
  /// values — callers at the import boundary should catch and fall back
  /// to [MapThemeStandard] rather than propagate the exception to the UI.
  static MapTheme fromJsonString(String raw) {
    return switch (raw) {
      'standard' => const MapThemeStandard(),
      'rpgParchment' => const MapThemeRpgParchment(),
      _ => throw FormatException('Unknown MapTheme string: "$raw"'),
    };
  }
}

/// Phase 07 default theme — Protomaps-derived neutral basemap.
final class MapThemeStandard extends MapTheme {
  const MapThemeStandard();
}

/// Phase 13 stub — parchment-styled creative rendering. Created here for
/// forward compatibility so call sites can pattern-match exhaustively.
final class MapThemeRpgParchment extends MapTheme {
  const MapThemeRpgParchment();
}
