# domain/map/

Pure-Dart domain types for map integration (Phase 07).

**Allowed imports:**

- `dart:*` (core + async + collection + ui)
- `package:freezed_annotation/*`
- `package:json_annotation/*`
- `package:collection/*`
- Other `lib/domain/*` siblings (e.g. `../gps/fix.dart`)

**Forbidden:**

- `package:flutter/*` (UI layer)
- `package:drift/*` (persistence layer)
- `package:maplibre_gl/*` (infrastructure layer)
- Any `lib/application/` or `lib/infrastructure/` import

Enforced by `tool/check_domain_purity.dart` (Phase 03) and
`tool/check_avoid_maplibre_leak.dart` (Phase 07-01).

**Exports:**

- `MapView` — domain-level abstract port expressing MirkFall vocabulary
  (`showMap`, `moveCameraTo`, `markVisited`, `addPointOfInterest`…).
  Infrastructure implementation lives in `lib/infrastructure/map/` (Plan 07-03).
- `CountryCode` — zero-cost extension type wrapping a validated alpha-3
  lowercase string, with `CountryCode.world` sentinel for the bundled
  world basemap.
- `MapTheme` — sealed hierarchy (`MapThemeStandard`, `MapThemeRpgParchment`).
- `CountryCatalog` / `CountryEntry` / `ChunkPart` / `ReassembledMeta` —
  Freezed entities round-tripping `assets/maps/catalog.json` and the
  synthetic `test/fixtures/catalogs/mini_catalog.json`.
- 7 map-layer exceptions (see `map_errors.dart`) — all `implements Exception`.
