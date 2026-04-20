---
phase: 07-map-integration
plan: 02
type: execute
wave: 2
depends_on: ["07-01"]
files_modified:
  - lib/domain/map/map_view.dart
  - lib/domain/map/country_code.dart
  - lib/domain/map/map_theme.dart
  - lib/domain/map/country_catalog.dart
  - lib/domain/map/map_errors.dart
  - lib/domain/map/README.md
  - lib/domain/downloads/download_job.dart
  - lib/domain/downloads/download_state.dart
  - lib/domain/downloads/download_errors.dart
  - lib/domain/downloads/README.md
  - lib/domain/installed_maps/installed_country.dart
  - lib/domain/installed_maps/installed_manifest.dart
  - lib/domain/installed_maps/installed_manifest_repository.dart
  - lib/domain/installed_maps/README.md
  - lib/domain/mirk/mirk_renderer.dart
  - lib/domain/mirk/mirk_paint_context.dart
  - test/domain/map/country_catalog_test.dart
  - test/domain/map/country_code_test.dart
  - test/domain/map/map_errors_test.dart
  - test/domain/downloads/download_state_test.dart
  - test/domain/installed_maps/installed_manifest_test.dart
  - test/domain/mirk/mirk_renderer_contract_test.dart
  - test/fakes/fake_map_view.dart
  - test/fakes/fake_pmtiles_source.dart
  - test/fakes/fake_installed_manifest_repository.dart
  - test/fakes/fake_download_controller.dart
  - test/fakes/fake_country_resolver.dart
autonomous: true
requirements:
  - MAP-05
  - MAP-06
  - MAP-08
  - MAP-09
  - MAP-10

must_haves:
  truths:
    - "`MapView` is a pure-Dart abstract class in `lib/domain/map/map_view.dart` with method signatures expressed in MirkFall vocabulary (no MapLibre types leak)"
    - "`CountryCatalog`, `CountryEntry`, `ChunkPart`, `ReassembledMeta` are Freezed entities that round-trip parse `mini_catalog.json` and the real `assets/maps/catalog.json`"
    - "`InstalledManifest`, `InstalledCountry` are Freezed entities; `InstalledManifestRepository` is a port interface (no impl here — that's Plan 07-04)"
    - "`DownloadJob`, sealed `DownloadState { Idle | Downloading | Paused | Error | Completed | Cancelled }`, and typed exceptions compile"
    - "`MirkRenderer` abstract interface + `MirkPaintContext` Freezed DTO compile; contract test asserts the 3 methods (paint / update / dispose) are the ONLY public surface (no ui.Image leak)"
    - "All 7 map-layer exceptions (`MapAssetMissingException`, `PmtilesCorruptException`, `CountryNotInstalledException`, `SchemaValidationException`, `DiskSpaceInsufficientException`, `MapStyleCorruptException`, `CannotDeleteWorldBundleException`) implement `Exception` and carry structured context fields"
    - "`CountryCode.world` sentinel (`CountryCode._('wld')`) exists as a domain-locked constant; 07-04 CountryDeleteService compares against it rather than the raw string `'wld'`"
    - "All 3 download-layer exceptions (`DownloadInterruptedException`, `Sha256MismatchException`, `ConcatFailureException`) implement `Exception` with expected / actual fields"
    - "`FakeMapView`, `FakePmtilesSource`, `FakeInstalledManifestRepository`, `FakeDownloadController`, `FakeCountryResolver` fully implement their port interfaces with in-memory state tracking (public observable getters: `cameraMovesObserved`, `layersAddedObserved`, etc.)"
    - "`tool/check_domain_purity.dart` still exits 0 — the new `lib/domain/map/` and `lib/domain/downloads/` and `lib/domain/installed_maps/` subtrees import nothing outside `dart:*`, `package:freezed_annotation`, `package:json_annotation`, `package:collection`, and the existing pure-Dart project domain"
    - "`tool/check_avoid_maplibre_leak.dart` still exits 0 (no domain file imports maplibre_gl)"
  artifacts:
    - path: "lib/domain/map/map_view.dart"
      provides: "abstract class MapView with MirkFall-vocabulary signatures"
      contains: "abstract class MapView"
    - path: "lib/domain/map/country_catalog.dart"
      provides: "Freezed CountryCatalog + CountryEntry + ChunkPart + ReassembledMeta"
      contains: "class CountryCatalog"
    - path: "lib/domain/map/map_errors.dart"
      provides: "6 sealed Exception classes"
      contains: "implements Exception"
    - path: "lib/domain/downloads/download_state.dart"
      provides: "sealed DownloadState + 6 variants"
      contains: "sealed class DownloadState"
    - path: "lib/domain/installed_maps/installed_manifest.dart"
      provides: "Freezed InstalledManifest + parse/validate + repository port"
      contains: "class InstalledManifest"
    - path: "lib/domain/mirk/mirk_renderer.dart"
      provides: "abstract MirkRenderer interface — paint/update/dispose"
      contains: "abstract class MirkRenderer"
    - path: "test/fakes/fake_map_view.dart"
      provides: "in-memory MapView double for widget tests"
      contains: "class FakeMapView implements MapView"
  key_links:
    - from: "lib/domain/map/country_catalog.dart"
      to: "assets/maps/catalog.json"
      via: "CountryCatalog.fromJson parses the real asset byte-identically"
      pattern: "factory CountryCatalog.fromJson"
    - from: "lib/domain/mirk/mirk_renderer.dart"
      to: "lib/infrastructure/mirk/noop_mirk_renderer.dart"
      via: "NoopMirkRenderer implements MirkRenderer (created in Plan 07-03)"
      pattern: "implements MirkRenderer"
    - from: "test/fakes/fake_map_view.dart"
      to: "lib/domain/map/map_view.dart"
      via: "FakeMapView implements MapView — compile-checked"
      pattern: "implements MapView"
---

<objective>
Land every pure-Dart domain interface and data type that downstream Phase 07 plans consume. No infrastructure, no UI, no Riverpod providers — strictly vocabulary and contracts. This plan freezes the three most expensive-to-revisit decisions: (1) `MapView` domain-level interface, (2) `PmtilesSource` abstraction (port signature — impl in 07-03), (3) catalog + manifest + download schemas.

Purpose: Per CONTEXT.md, these three seams are "the single most expensive thing in the phase to revisit later". Getting their signatures right before any impl lands prevents cascading rewrites in 07-03..07-06. Also fills the forward-declared fake shells from Plan 07-01.
Output: A compiling `lib/domain/map/ + lib/domain/downloads/ + lib/domain/installed_maps/ + lib/domain/mirk/` subtree + fully-implementing fakes + unit tests exercising the Freezed round-trip and exception contracts.
</objective>

<execution_context>
@C:/Users/oliver/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/oliver/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-map-integration/07-CONTEXT.md
@.planning/phases/07-map-integration/07-RESEARCH.md
@.planning/phases/07-map-integration/07-01-SUMMARY.md
@CLAUDE.md
@lib/domain/README.md
@lib/domain/gps/fix.dart
@lib/domain/sessions/session.dart
@lib/domain/errors/
@lib/domain/envelope/envelope.dart
@tool/check_domain_purity.dart

<interfaces>
<!-- Domain conventions inherited from Phases 03/05. -->

Freezed entity pattern (Phase 03):
```dart
@Freezed()
class Fix with _$Fix {
  const factory Fix({
    required FixId id,
    required SessionId sessionId,
    required DateTime timestampUtc,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) = _Fix;

  factory Fix.fromJson(Map<String, dynamic> json) => _$FixFromJson(json);
}
```

Extension-type ID pattern (Phase 03):
```dart
extension type const SessionId(String value) {
  factory SessionId.parse(String raw) => ...;
}
```

Sealed state pattern (Phase 05 `ActiveSessionState`):
```dart
sealed class ActiveSessionState {}
class Idle extends ActiveSessionState { ... }
class Starting extends ActiveSessionState { ... }
// etc.
```

Exception pattern (Phase 03, all 7 domain errors):
```dart
class ConcurrentActivationException implements Exception {
  const ConcurrentActivationException({required this.attemptedSessionId, required this.activeSessionId});
  final SessionId attemptedSessionId;
  final SessionId activeSessionId;
  @override String toString() => '...';
}
```

Port/adapter pattern (Phase 03 stores):
- Port: `abstract class SessionStore { Future<void> activate(SessionId id); ... }`
- Adapter: `class DriftSessionStore implements SessionStore { ... }` in `lib/infrastructure/stores/`

Fake pattern (Phase 05 `test/fakes/fake_location_stream.dart`):
- `class FakeLocationStream implements LocationStream`
- Public observable `List<LocationEvent> emittedEvents` for test assertions
- In-memory state; no real plugin wiring
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Map domain (MapView interface + CountryCatalog Freezed + exceptions + CountryCode extension type)</name>
  <files>
    lib/domain/map/map_view.dart,
    lib/domain/map/country_code.dart,
    lib/domain/map/map_theme.dart,
    lib/domain/map/country_catalog.dart,
    lib/domain/map/map_errors.dart,
    lib/domain/map/README.md,
    test/domain/map/country_catalog_test.dart,
    test/domain/map/country_code_test.dart,
    test/domain/map/map_errors_test.dart
  </files>
  <behavior>
    - `MapView` abstract class: methods named with MirkFall vocabulary only, zero reference to any third-party map type. Signatures:
      - `Future<void> showMap(CountryCode? country)` — `null` means world fallback
      - `Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom})`
      - `Future<void> setTheme(MapTheme theme)`
      - `Future<void> setUserLocation(Fix? fix)` (imports existing `lib/domain/gps/fix.dart`)
      - `Future<({double latitude, double longitude, double zoom})> queryViewport()`
      - `Stream<({double latitude, double longitude, double zoom})> get viewportUpdates`
      - `Future<void> markVisited(List<({double latitude, double longitude})> polygon)` (Phase 09+ stub)
      - `Future<void> addPointOfInterest({required String id, required double latitude, required double longitude, required String iconId})` (Phase 11+ stub)
      - `Future<void> removePointOfInterest(String id)`
      - `Future<void> dispose()`
      - `bool get isFollowMeEnabled`
      - `Future<void> setFollowMeEnabled(bool enabled)`
    - `CountryCode` is a Dart 3 extension type wrapping a `String` (always lower-case alpha-3), with `parse(String raw)` validator (rejects non-3-char, non-alpha) and `toString()` returning the wrapped value.
    - `CountryCode.world` — a domain-locked sentinel `static const CountryCode world = CountryCode._('wld')` exposing the reserved 3-letter code used to identify the bundled world basemap. The `'wld'` value is reserved — `parse('wld')` MUST succeed (the sentinel is a valid CountryCode), but any caller that wants to reject the world bundle (e.g. `CountryDeleteService` in 07-04) MUST compare against `CountryCode.world` rather than the raw string literal. Class docstring documents this reservation explicitly.
    - `MapTheme` is a sealed hierarchy: `MapThemeStandard()` (Phase 07) + `MapThemeRpgParchment()` (Phase 13 stub, created here for forward compat).
    - `CountryCatalog`, `CountryEntry`, `ChunkPart`, `ReassembledMeta` are Freezed with `fromJson`/`toJson` via json_serializable (Phase 03 convention).
    - `CountryCatalog.parseBundled()` (class static) loads `assets/maps/catalog.json` via `rootBundle` — BUT this call site belongs in `lib/application/` (impure I/O). The domain file exposes `fromJson` only; a separate `loadBundledCatalog` is a free function in `lib/application/providers/map_providers.dart` (Plan 07-05).
    - `catalogVersion` derivation: computed from the tag embedded in `parts[0].url` path (e.g. `.../releases/download/v20260419/fra.part01` → `v20260419`). Expose via getter `String get catalogVersion` on `CountryCatalog`, derived lazily.
    - Exceptions in `map_errors.dart`:
      - `MapAssetMissingException({required String assetPath, String? reason})` — world bundle missing / asset not in APK
      - `PmtilesCorruptException({required String filePath, required String expectedSha256, required String actualSha256})`
      - `CountryNotInstalledException({required CountryCode alpha3})`
      - `SchemaValidationException({required String documentPath, required String reason})` — catalog.json / installed.json parse failures
      - `DiskSpaceInsufficientException({required int neededBytes, required int freeBytes})`
      - `MapStyleCorruptException({required String reason})` — style.json missing placeholder / unknown layer order
      - `CannotDeleteWorldBundleException({String? reason})` — thrown when `CountryDeleteService` (07-04) is asked to delete `CountryCode.world`; guards the invariant that the bundled world basemap is read-only. Carries an optional `reason` for log context.
      - All implement `Exception`, all have `toString()` overrides.
    - `lib/domain/map/README.md`: brief — "Pure-Dart domain types for map integration. May import only dart:*, package:freezed_annotation, package:json_annotation, package:collection, and other `lib/domain/*` siblings. No Flutter, no MapLibre, no infrastructure. Enforced by `tool/check_domain_purity.dart` and `tool/check_avoid_maplibre_leak.dart`."
    - Tests:
      - `test/domain/map/country_catalog_test.dart`:
        - Parse `test/fixtures/catalogs/mini_catalog.json` → 6 countries, 12 total chunks, each with expected sha256 and size.
        - `catalogVersion` getter returns `"v20260419"` for real `assets/maps/catalog.json` — reading the real asset via `flutter_test` rootBundle.
        - Round-trip: `CountryCatalog.fromJson(catalog.toJson())` equals original.
        - Schema validation: missing `alpha3` throws FormatException (json_serializable default).
      - `test/domain/map/country_code_test.dart`:
        - `CountryCode.parse('FRA')` lower-cases to `'fra'`.
        - `CountryCode.parse('fr')` throws FormatException.
        - `CountryCode.parse('fra4')` throws.
        - Equality: `CountryCode.parse('fra') == CountryCode.parse('FRA')`.
        - `CountryCode.world.value == 'wld'` AND `CountryCode.parse('wld') == CountryCode.world` (sentinel equality).
      - `test/domain/map/map_errors_test.dart`:
        - Every exception `implements Exception` (pattern match) — including `CannotDeleteWorldBundleException`.
        - `toString()` contains the structured fields (useful for log inspection).
        - `CannotDeleteWorldBundleException` can be constructed with and without the optional `reason` field.
  </behavior>
  <action>
    1. **Create `lib/domain/map/README.md`** documenting the import rules. Tie to the 2 lint scripts.

    2. **`lib/domain/map/country_code.dart`**:
       - GOSL header
       - `extension type const CountryCode._(String value)` with private ctor + `factory CountryCode.parse(String raw)` that:
         - lower-cases
         - rejects non-ASCII
         - rejects length != 3
         - rejects non-alpha
         - throws `FormatException` on any failure
       - `@override` on `toString()` if applicable (extension types don't auto-inherit)
       - JsonConverter free functions `CountryCode _countryCodeFromJson(String)`, `String _countryCodeToJson(CountryCode)` for use in Freezed annotations
       - `static const CountryCode world = CountryCode._('wld');` — domain-locked sentinel for the bundled world basemap. Document the reservation in the class docstring: "'wld' is a reserved alpha-3 code; `parse('wld')` succeeds and returns a value equal to `CountryCode.world`. Callers that wish to guard against the world bundle (e.g. delete, update) must compare against `CountryCode.world`."

    3. **`lib/domain/map/map_theme.dart`**:
       - Sealed hierarchy (not Freezed — no payload):
         ```dart
         sealed class MapTheme { const MapTheme(); }
         class MapThemeStandard extends MapTheme { const MapThemeStandard(); }
         class MapThemeRpgParchment extends MapTheme { const MapThemeRpgParchment(); }
         ```
       - `MapTheme.toJsonString() => switch (this) { MapThemeStandard() => 'standard', MapThemeRpgParchment() => 'rpgParchment' }`
       - `MapTheme.fromJsonString(String s)` static — throws on unknown.

    4. **`lib/domain/map/country_catalog.dart`**:
       - Freezed class `CountryCatalog`:
         - `required List<CountryEntry> countries`
         - Getter `catalogVersion` extracts tag from `countries.first.parts.first.url` — regex `r'/releases/download/([^/]+)/'`
         - `factory CountryCatalog.fromJson(Map<String, dynamic>)` via json_serializable
       - Freezed class `CountryEntry`:
         - `required CountryCode alpha3` (with `@JsonKey(fromJson: _countryCodeFromJson, toJson: _countryCodeToJson)` field-level converters per Phase 03 `id_json_converters.dart` pattern)
         - `required String name`
         - `required List<ChunkPart> parts`
         - `required ReassembledMeta reassembled`
         - Getter `totalBytes` = `parts.fold(0, (a, p) => a + p.size)`
         - `@Assert('parts.isNotEmpty')` invariant
       - Freezed class `ChunkPart`:
         - `required String sha256`, `required int size`, `required String url`
         - `@Assert('sha256.length == 64')` (hex sha256)
         - `@Assert('size > 0')`
       - Freezed class `ReassembledMeta`:
         - `required String sha256`, `required int size`
         - Same asserts

    5. **`lib/domain/map/map_errors.dart`**: 7 exception classes per behavior spec (6 map-layer + `CannotDeleteWorldBundleException` reserved for 07-04's CountryDeleteService). Each:
       - GOSL header (top of file)
       - `const` ctor with named required fields
       - `@override String toString()` with all fields inlined
       - `implements Exception`
       - NO `extends Error` (CLAUDE.md §Error handling — Error is for programming bugs)

    6. **`lib/domain/map/map_view.dart`** abstract class per behavior spec signatures. Imports: `import 'package:mirkfall/domain/map/country_code.dart';`, `import 'package:mirkfall/domain/map/map_theme.dart';`, `import 'package:mirkfall/domain/gps/fix.dart';`. No Flutter, no maplibre_gl.

    7. **Tests** per behavior spec. Use `flutter_test` + rootBundle for the real catalog parse. Put them under `test/domain/map/` (pure-Dart subdir allows `dart test` runner).
       - Caveat: `rootBundle` requires `TestWidgetsFlutterBinding.ensureInitialized()` — use `flutter_test` for that specific test case; the other tests use plain `package:test`.

    8. **Run codegen**: `dart run build_runner build --delete-conflicting-outputs` to emit `*.freezed.dart` + `*.g.dart`. Verify new generated files.

    9. **Lint**: `dart run tool/check_domain_purity.dart` + `dart run tool/check_avoid_maplibre_leak.dart` MUST exit 0.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/domain/map/ test/domain/map/ &&
      flutter test test/domain/map/ &&
      dart run tool/check_domain_purity.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    `lib/domain/map/` compiles with zero warnings, all unit tests green, Freezed + json_serializable codegen emitted, real `assets/maps/catalog.json` parses cleanly and `catalogVersion` extracts correctly, 3 lint gates green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Downloads + installed_maps domains + Mirk renderer interface + typed exceptions</name>
  <files>
    lib/domain/downloads/download_job.dart,
    lib/domain/downloads/download_state.dart,
    lib/domain/downloads/download_errors.dart,
    lib/domain/downloads/README.md,
    lib/domain/installed_maps/installed_country.dart,
    lib/domain/installed_maps/installed_manifest.dart,
    lib/domain/installed_maps/installed_manifest_repository.dart,
    lib/domain/installed_maps/README.md,
    lib/domain/mirk/mirk_renderer.dart,
    lib/domain/mirk/mirk_paint_context.dart,
    test/domain/downloads/download_state_test.dart,
    test/domain/installed_maps/installed_manifest_test.dart,
    test/domain/mirk/mirk_renderer_contract_test.dart
  </files>
  <behavior>
    - `DownloadJob` Freezed: `{CountryCode alpha3, CountryEntry entry, DateTime enqueuedAtUtc, bool userPausedFlag}`
    - `DownloadState` sealed hierarchy:
      ```
      sealed class DownloadState {}
      class DownloadIdle implements DownloadState {}
      class DownloadQueued implements DownloadState { final List<DownloadJob> queue; }
      class DownloadInProgress implements DownloadState { final DownloadJob active; final DownloadProgress progress; final List<DownloadJob> remaining; }
      class DownloadPaused implements DownloadState { final DownloadJob active; final DownloadProgress snapshot; final PauseReason reason; }
      class DownloadError implements DownloadState { final DownloadJob active; final Exception cause; }
      class DownloadCompleted implements DownloadState { final CountryCode alpha3; final Duration totalElapsed; }
      class DownloadCancelled implements DownloadState { final CountryCode alpha3; }
      ```
    - `DownloadProgress` Freezed: `{int bytesDownloaded, int totalBytes, int currentPartIndex, int totalParts}`. Getter `double get fractionDone` = `bytesDownloaded / totalBytes`.
    - `PauseReason` enum: `manual`, `networkLost`, `retryExhausted`.
    - `DownloadErrors`: `DownloadInterruptedException(reason)`, `Sha256MismatchException({expected, actual, at: ChunkIdentifier})`, `ConcatFailureException(reason)`, `HttpRangeNotSupportedException(responseCode)` — every one `implements Exception`.
    - `InstalledCountry` Freezed:
      ```
      required CountryCode alpha3
      required DateTime installedAtUtc
      required int fileSize
      required String pmtilesVersion  // catalog tag at install time
      required String sha256
      required String filePath         // relative to appSupportDir (e.g. 'countries/fra.pmtiles')
      ```
    - `InstalledManifest` Freezed:
      ```
      required int schemaVersion       // 1
      required String catalogVersion   // bump sentinel
      required Map<String, InstalledCountry> installed  // keyed by alpha3.value
      ```
      - `@Assert('schemaVersion == 1')`
      - Getter `int get totalSizeBytes` = sum of `installed.values.map(.fileSize)`
      - Factory `InstalledManifest.empty()` returns `schemaVersion:1, catalogVersion:'', installed:{}`
      - `copyWithInsert(InstalledCountry)` helper
      - `copyWithRemove(CountryCode)` helper
    - `InstalledManifestRepository` abstract interface:
      ```
      Future<InstalledManifest> read();
      Future<void> write(InstalledManifest manifest);
      Stream<InstalledManifest> get updates;
      ```
    - `MirkRenderer` abstract interface:
      ```
      void paint(Canvas canvas, Size size, MirkPaintContext context);
      void update(Duration elapsed);
      Future<void> dispose();
      ```
      - IMPORTANT: `Canvas` + `Size` come from `dart:ui` (not `package:flutter/material.dart`). The domain may import `dart:ui` — verified against existing `lib/domain/mirk/mirk_style_config.dart` imports. Document in the README that `dart:ui` is an allowed domain import (it's part of Dart SDK, not Flutter widgets).
      - UPDATE `tool/check_domain_purity.dart` if needed: add `dart:ui` to the allowed import list (check whether it's already there; Phase 03's mirk_style_config references `@Assert` on ARGB values but does not import dart:ui — if it doesn't, then adding it is a Phase 07 widening. If the purity checker scans for `package:flutter` leaks but not `dart:ui`, we're already fine).
    - `MirkPaintContext` Freezed:
      ```
      required double zoomLevel
      required double pixelRatio
      required Duration sessionElapsed
      // Phase 09 may add more — sealed for the stub
      ```
    - Tests:
      - `download_state_test.dart`: pattern-match every variant, assert `fractionDone` math
      - `installed_manifest_test.dart`:
        - `empty()` has zero entries
        - Insert + lookup round-trip via `copyWithInsert`
        - Remove non-existent key → no-op
        - `totalSizeBytes` correct over 3 countries
        - JSON round-trip (`fromJson`/`toJson`)
      - `mirk_renderer_contract_test.dart`:
        - Uses `noSuchMethod`-based test double to assert `MirkRenderer` exposes EXACTLY 3 public methods (paint, update, dispose) — reflection via `dart:mirrors` is NOT available; instead assert the type's public members via a compile-time witness class that implements the interface and counts overrides. Document as "interface-shape regression guard".
  </behavior>
  <action>
    1. **READMEs** for all 3 new subdirs documenting import rules.

    2. **`lib/domain/downloads/download_errors.dart`** + `download_state.dart` + `download_job.dart` per behavior spec.
       - Run `build_runner` to emit `download_job.freezed.dart` + `download_progress.freezed.dart`.

    3. **`lib/domain/installed_maps/installed_country.dart`** + `installed_manifest.dart` + `installed_manifest_repository.dart` per behavior.
       - Freezed entities + port interface.
       - Field-level `@JsonKey` converters for `CountryCode`.
       - Map-valued JSON: `Map<String, InstalledCountry>` round-trips via json_serializable default.

    4. **`lib/domain/mirk/mirk_renderer.dart`** + `mirk_paint_context.dart`:
       - Abstract `MirkRenderer` with the 3 methods.
       - `MirkPaintContext` Freezed.
       - If `tool/check_domain_purity.dart` complains about `dart:ui` — inspect the script; if it explicitly excludes dart:ui, we're fine (Phase 03 `mirk_style_config` may already have precedent). Otherwise add a documented exception.

    5. **Tests** per behavior. Run under `dart test` (pure Dart). mirk_renderer_contract_test uses a hand-written witness class.

    6. **Lint + build_runner**: `dart run build_runner build --delete-conflicting-outputs` → `flutter analyze` → `tool/check_domain_purity.dart` → `tool/check_avoid_maplibre_leak.dart` — all exit 0.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/domain/downloads/ lib/domain/installed_maps/ lib/domain/mirk/ test/domain/downloads/ test/domain/installed_maps/ test/domain/mirk/ &&
      dart test test/domain/downloads/ test/domain/installed_maps/ test/domain/mirk/ &&
      dart run tool/check_domain_purity.dart &&
      dart run tool/check_avoid_maplibre_leak.dart
    </automated>
  </verify>
  <done>
    Downloads + installed_maps + mirk renderer domains compile + test-green + domain-purity-clean. Every sealed state + exception has a test. MirkRenderer interface is frozen (contract test prevents accidental surface growth in Phase 09).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Fill the 5 test fakes (FakeMapView + FakePmtilesSource + FakeInstalledManifestRepository + FakeDownloadController + FakeCountryResolver)</name>
  <files>
    test/fakes/fake_map_view.dart,
    test/fakes/fake_pmtiles_source.dart,
    test/fakes/fake_installed_manifest_repository.dart,
    test/fakes/fake_download_controller.dart,
    test/fakes/fake_country_resolver.dart,
    test/fakes/fake_map_view_test.dart,
    test/fakes/fake_installed_manifest_repository_test.dart
  </files>
  <behavior>
    - `FakeMapView implements MapView`:
      - In-memory state: `List<CameraMove> cameraMovesObserved`, `List<CountryCode?> showMapInvocations`, `List<String> poiAddObservations`, `List<String> poiRemoveObservations`, `Fix? lastUserLocationSet`, `MapTheme currentTheme`, `bool followMeEnabled`
      - `viewportUpdates` — backed by a `StreamController.broadcast()` the test can push onto via `pushViewport({lat, lon, zoom})`
      - Every interface method fills its corresponding observable + returns a completed `Future`
      - `dispose()` closes the controller + marks `disposedFlag = true`
    - `FakePmtilesSource`:
      - Backing store: `Map<CountryCode?, String> uriOverrides` injected at ctor
      - `String forCountry(CountryCode? code)` returns `uriOverrides[code] ?? 'pmtiles://file:///fake/${code?.value ?? 'world'}.pmtiles'`
      - Records `forCountryCallsObserved` list
    - `FakeInstalledManifestRepository implements InstalledManifestRepository`:
      - In-memory `InstalledManifest _state` + broadcast controller
      - `read()` returns `_state` (cloned to preserve immutability)
      - `write(manifest)` updates `_state`, emits on stream
      - Plus test-only helpers: `void seedWith(InstalledManifest initial)`, `int writesObserved`, `bool simulateWriteFailure` (next `write()` throws `Exception('simulated')`)
    - `FakeDownloadController`:
      - Exposes `Stream<DownloadState>` via broadcast controller
      - Test helpers: `void emitState(DownloadState s)`, `void queueCountry(CountryCode)`, `List<CountryCode> enqueueOrderObserved`, `int pauseCalls`, `int resumeCalls`
      - Needed because Plan 07-04's `PmtilesDownloadController` has a rich Riverpod surface; tests override with this fake
    - `FakeCountryResolver`:
      - `CountryCode? resolveForViewport({required double lat, required double lon, required double zoom})` — returns the value set via `void seed(CountryCode? answer)`
      - Records `List<(double,double,double)> viewportsQueriedObserved`
    - Tests:
      - `fake_map_view_test.dart`: construct fake, call `showMap(CountryCode.parse('fra'))` + `moveCameraTo(…)` + assert `showMapInvocations.length == 1` and `cameraMovesObserved.last == …`. Prove mount + dispose clean.
      - `fake_installed_manifest_repository_test.dart`: seed + read round-trip, write-emits-on-stream, `simulateWriteFailure` throws.
  </behavior>
  <action>
    1. **Replace the forward-declared shells from Plan 07-01** with real implementations. Each file:
       - GOSL header
       - Imports the domain interface being faked
       - In-memory state + observables per behavior
       - `implements` relationship (NOT `extends`) — matches Phase 05 convention
       - No `UnimplementedError` — every method has a sensible default (return completed future, emit empty stream, etc.)

    2. **`test/fakes/fake_map_view.dart`**:
       - Record every method call with timestamp + args in a public `List<String> methodLog` (useful for widget tests that want to assert ordering)
       - Implement all 12 `MapView` methods
       - Define a tiny `CameraMove({lat, lon, zoom, timestamp})` helper class

    3. **Tests** for the two most surface-rich fakes (MapView + InstalledManifestRepository). The other 3 are simpler and covered by their downstream consumers.

    4. **Lint + build**: `flutter analyze` clean. `tool/check_avoid_maplibre_leak.dart` exit 0 (fakes are under `test/`, not `lib/` — the leak scanner scans `lib/` only; double-check against Task 2 of Plan 07-01).
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos test/fakes/ test/domain/ &&
      flutter test test/fakes/fake_map_view_test.dart test/fakes/fake_installed_manifest_repository_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart
    </automated>
  </verify>
  <done>
    5 fakes fully implement their respective ports with observable in-memory state. 2 of them have dedicated unit tests; the other 3 compile against real interfaces and will be exercised by widget / integration tests in later plans.
  </done>
</task>

</tasks>

<verification>
```
dart run build_runner build --delete-conflicting-outputs &&
flutter analyze --fatal-infos --fatal-warnings &&
flutter test test/domain/ test/fakes/fake_map_view_test.dart test/fakes/fake_installed_manifest_repository_test.dart &&
dart test test/domain/downloads/ test/domain/installed_maps/ test/domain/mirk/ &&
dart run tool/check_domain_purity.dart &&
dart run tool/check_avoid_maplibre_leak.dart &&
dart run tool/check_avoid_remote_pmtiles.dart &&
dart run tool/check_headers.dart
```

All steps MUST exit 0. Every Freezed + json_serializable target must have a matching `*.freezed.dart` + `*.g.dart` generated file committed.
</verification>

<success_criteria>
- `MapView` interface frozen with MirkFall-vocabulary signatures (no MapLibre leak)
- `CountryCatalog` parses real `assets/maps/catalog.json` + extracts `catalogVersion` from `parts[].url`
- 6 map-layer exceptions + 4 download-layer exceptions implement `Exception` with structured fields + `toString()` overrides
- `InstalledManifest` Freezed + repository port + helper methods (`copyWithInsert/Remove`, `totalSizeBytes`) work
- `MirkRenderer` + `MirkPaintContext` abstract interfaces frozen with exactly 3 public methods (paint/update/dispose) — Phase 09 slots in
- 5 test fakes fully implement their domain ports with observable state
- All 4 lint gates + build_runner + domain tests green
- Downstream plans (07-03, 07-04, 07-05, 07-06) can consume these types without TypeErrors
</success_criteria>

<output>
After completion, create `.planning/phases/07-map-integration/07-02-SUMMARY.md`:
- Full list of new `lib/domain/map/ + lib/domain/downloads/ + lib/domain/installed_maps/` files + line counts
- Freezed union strategy notes (field-level JsonKey converters for CountryCode — mirrors Phase 03 pattern)
- `dart:ui` allowance decision in `check_domain_purity.dart` if modified
- `MirkRenderer` final signature + Phase 09 handoff note
- Any cases where `@Assert` had to move from const factory to factory (Phase 03 Freezed lesson re. Dart 3.11 const asserts)
- Fake observable getters enumerated for each fake (widget/integration test authors' reference)
- Commit hashes for atomic commits
</output>
