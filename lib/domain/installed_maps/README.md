# domain/installed_maps/

Pure-Dart domain types for the `installed.json` manifest that tracks
which country PMTiles bundles are present on the device.

**Allowed imports:** `dart:*`, `package:freezed_annotation`, `package:json_annotation`, `package:collection`, sibling `lib/domain/*`.

**Forbidden:** `package:flutter/*`, `package:drift/*`, `package:path_provider/*`, `package:maplibre_gl/*`, anything under `lib/application/` or `lib/infrastructure/`. Actual file I/O + path resolution live in `lib/infrastructure/installed_maps/` (Plan 07-04).

**Exports:**

- `InstalledCountry` — Freezed per-country entry: alpha3, installed_at_utc, file_size, pmtiles_version (catalog tag at install time), sha256, file_path (relative to app-support).
- `InstalledManifest` — Freezed root document: schema_version (1), catalog_version (bump sentinel), `Map<String alpha3 → InstalledCountry> installed`. Helpers `empty`, `copyWithInsert`, `copyWithRemove`, `totalSizeBytes`.
- `InstalledManifestRepository` — abstract port interface (read / write / updates stream). Concrete `JsonFileInstalledManifestRepository` lives in Plan 07-04.

The port pattern mirrors Phase 03's store interfaces (`SessionStore`, `FixStore`, etc.): domain exposes an abstract class, infrastructure supplies the adapter.
