---
phase: 03-persistence-domain-models
plan: 03
subsystem: domain
tags: [freezed, json-serializable, sealed-class, dart3, extension-type, json-converter, envelope, mirk-config-union, tdd]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: 6 typed ID extension types (SessionId, MarkerId, CategoryId, MirkStyleId, PhotoRefId, RevealedTileId), kCategoryDefaultId, IdGenerator port, 7 domain exceptions (ConcurrentActivationException, SessionNotFoundException, InvalidSessionTransition, MarkerNotFoundException, CategoryNotFoundException, CategoryInUseException, MirkStyleConfigException, ImportValidationException, MigrationFailureException), JsonMigrator + JsonMigration + IdentityMigrationV1 + V1ToV2RenameRadius, tile_math, reveal_calculator, session_v1.json + session_v2.json + mirk_style_unknown_renderer.json fixtures
provides:
  - 7 Freezed domain entities (Session, SessionStatus enum, Marker, MarkerCategory, MirkStyle, sealed MirkStyleConfig { AtmosphericConfig, ShaderConfig, UnknownConfig }, RevealedTile, PhotoRef) — SC#4 closed verbatim
  - Envelope Freezed class with pure-arrow fromJson (Freezed 3.2.3 requirement) + static validateOrThrow + Envelope.parse convenience (validate + parse in one call) — Blocker 1 fix, SC#4 Envelope half closed
  - 6 abstract store ports (SessionStore, MarkerStore, MarkerCategoryStore, MirkStyleStore, RevealedTileStore, PhotoStore) with find/require split + SESS-06 + MIRK-03 + reassign-to-default-category docstrings — ready for 03-06 Drift impls
  - id_json_converters.dart — per-field top-level converter functions (sessionIdFromJson/toJson, markerIdFromJson/toJson, ...) bridging json_serializable to Dart-3 extension types
  - 5 new domain test files (session_invariants, session_timezone, mirk_style_config_fromjson, envelope_fromjson, json_migrator_v1_to_v2) — 23 new tests
  - Fixture-driven end-to-end SC#5 proof: session_v1.json -> Envelope.parse -> JsonMigrator([V1ToV2RenameRadius()]) -> payload byte-equal to session_v2.json payload
affects: [03-04-plan, 03-05-plan, 03-06-plan, 09-fog-render, 11-markers-photos, 13-import-export]

# Tech tracking
tech-stack:
  added: []  # Zero new deps — freezed/json_serializable/freezed_annotation/json_annotation were already pinned by Phase 01
  patterns:
    - "Freezed 3.x syntax: `@freezed abstract class X with _$X` for single-variant, `@Freezed(unionKey: ..., fallbackUnion: ...) sealed class Y` for unions"
    - "factory (not const factory) for Freezed entities carrying @Assert invariants — Dart 3.11 rejects method invocation (displayName.trim().isNotEmpty) in const constructor asserts"
    - "Per-field @JsonKey(fromJson: fn, toJson: fn) with top-level converter functions as the bridge between json_serializable and Dart-3 extension-type IDs (class-level JsonConverter annotation does not reach extension types)"
    - "@JsonKey readValue: hook on UnknownConfig.raw — captures the WHOLE parent map verbatim so forward-compatibility fallback preserves all fields, not just a nested 'raw' key"
    - "Envelope.fromJson must stay a pure arrow redirect (Freezed's needsJsonSerializable check requires ExpressionFunctionBody); pre-validation lives in static Envelope.validateOrThrow, composed via Envelope.parse(json)"
    - "`// ignore_for_file: invalid_annotation_target` on Freezed source files — analyzer flags @JsonKey on factory parameters because it has Target(field|getter); Freezed copies the annotation onto the generated field where it IS valid"
    - "Handwritten fromJson on sealed MirkStyleConfig alternative rejected (needed for UnknownConfig raw-map capture but broke nested AtmosphericConfig.fromJson / ShaderConfig.fromJson generation); readValue hook is the cleaner Freezed-idiomatic path"

key-files:
  created:
    - lib/domain/sessions/session_status.dart
    - lib/domain/sessions/session.dart
    - lib/domain/sessions/session.freezed.dart
    - lib/domain/sessions/session.g.dart
    - lib/domain/sessions/session_store.dart
    - lib/domain/sessions/README.md
    - lib/domain/markers/marker.dart
    - lib/domain/markers/marker.freezed.dart
    - lib/domain/markers/marker.g.dart
    - lib/domain/markers/marker_category.dart
    - lib/domain/markers/marker_category.freezed.dart
    - lib/domain/markers/marker_category.g.dart
    - lib/domain/markers/marker_store.dart
    - lib/domain/markers/marker_category_store.dart
    - lib/domain/markers/README.md
    - lib/domain/mirk/mirk_style.dart
    - lib/domain/mirk/mirk_style.freezed.dart
    - lib/domain/mirk/mirk_style.g.dart
    - lib/domain/mirk/mirk_style_config.dart
    - lib/domain/mirk/mirk_style_config.freezed.dart
    - lib/domain/mirk/mirk_style_config.g.dart
    - lib/domain/mirk/mirk_style_store.dart
    - lib/domain/mirk/README.md
    - lib/domain/revealed/revealed_tile.dart
    - lib/domain/revealed/revealed_tile.freezed.dart
    - lib/domain/revealed/revealed_tile_store.dart
    - lib/domain/revealed/README.md
    - lib/domain/photos/photo_ref.dart
    - lib/domain/photos/photo_ref.freezed.dart
    - lib/domain/photos/photo_ref.g.dart
    - lib/domain/photos/photo_store.dart
    - lib/domain/photos/README.md
    - lib/domain/envelope/envelope.dart
    - lib/domain/envelope/envelope.freezed.dart
    - lib/domain/envelope/envelope.g.dart
    - lib/domain/ids/id_json_converters.dart
    - test/domain/session_invariants_test.dart
    - test/domain/session_timezone_test.dart
    - test/domain/mirk_style_config_fromjson_test.dart
    - test/domain/envelope_fromjson_test.dart
    - test/domain/json_migrator_v1_to_v2_test.dart
  modified: []

key-decisions:
  - "Freezed 3.2.3 `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` IS supported — Open Question #5 closed here. The generator emits a fromJson switch that falls back to UnknownConfig.fromJson on unknown rendererType."
  - "UnknownConfig.raw capture problem solved via `@JsonKey(readValue: _readWholeMap, fromJson: _unknownRawFromJson)` — the `readValue` hook instructs json_serializable to pass the ENTIRE source map (not just a nested 'raw' field) to the converter. Alternative (hand-written MirkStyleConfig.fromJson) was rejected because it broke AtmosphericConfig.fromJson / ShaderConfig.fromJson generation."
  - "JSON timestamp shape: split fields `(startedAtUtc: DateTime, startedAtOffsetMinutes: int)` shipped for Phase 03. Single-ISO-string `'2026-04-01T08:00:00+02:00'` export deferred to Phase 13 SCHEMA.md. Rationale: avoids a custom json_serializable converter in Phase 03 (risk reduction); either shape is round-trip safe and SC#5 JsonMigrator doesn't care about the shape."
  - "factory (not const factory) on Freezed entities carrying @Assert invariants — Dart 3.11 rejects method invocation (displayName.trim()) inside const constructor asserts. Affects Session, Marker, MarkerCategory, MirkStyle; PhotoRef and RevealedTile keep const factory (no asserts)."
  - "ID extension types need per-field @JsonKey converters (top-level function pair: sessionIdFromJson/toJson, markerIdFromJson/toJson, ...) — class-level JsonConverter annotations do NOT propagate to extension types because json_serializable resolves T through the declared type, and extension types collapse to their underlying representation at that boundary."
  - "Envelope.fromJson must stay a pure arrow redirect `=> _$EnvelopeFromJson(json)` — Freezed 3.2.3's needsJsonSerializable check (`constructor.body is ExpressionFunctionBody`) rejects block bodies. Validation moved to static Envelope.validateOrThrow; Envelope.parse composes validate + fromJson for the standard import-boundary flow."
  - "Generated files (.freezed.dart, .g.dart) are committed for build determinism — tool/check_domain_purity.dart excludes them by extension filter; analysis_options.yaml excludes them from analyzer warnings."
  - "ROADMAP SC#4 closed verbatim in this plan (all 7 named domain models Freezed, including Envelope)."
  - "ROADMAP SC#5 closed: JsonMigrator fixture-driven integration (session_v1.json -> Envelope.parse -> migrate -> byte-equal to session_v2.json payload) passes under dart test."

patterns-established:
  - "TDD RED-GREEN per task: RED commit (failing test) then GREEN commit (passing impl). No REFACTOR commits needed for this plan."
  - "GOSL header on every .dart file (enforced by tool/check_headers.dart)"
  - "README.md per domain subdir (sessions/, markers/, mirk/, revealed/, photos/) documenting invariants + subsystem contract"
  - "Abstract store ports live in lib/domain/<subsystem>/<entity>_store.dart; Drift impls will live in lib/infrastructure/stores/ (03-06)"
  - "Find-vs-require split enforced at the port API level (findById returns Nullable, requireById throws)"
  - "Pre-existing files are NOT reformatted mid-task to keep commits narrowly scoped (dart format runs against the whole tree can be out-of-scope; reverted those changes before Task 1 commit)"

requirements-completed: [SESS-06, MIRK-03]

# Metrics
duration: 19 min
completed: 2026-04-18
---

# Phase 03 Plan 03: Freezed domain entities + store ports + Envelope Summary

**7 Freezed domain entities (Session + Marker + MarkerCategory + MirkStyle + sealed MirkStyleConfig + RevealedTile + PhotoRef + Envelope) + 6 abstract store ports + 5 new test files closing ROADMAP SC#4 (every named domain model Freezed) + SC#5 (session_v1.json -> JsonMigrator -> session_v2.json fixture-driven round-trip), with 56 domain tests green and `lib/domain/` still at zero Flutter/Drift imports (37 hand-written .dart files, purity clean).**

## Performance

- **Duration:** 19 min
- **Started:** 2026-04-18T09:40:33Z
- **Completed:** 2026-04-18T10:00:27Z
- **Tasks:** 3 (all TDD: RED + GREEN per task)
- **Files created:** 41 (5 tests, 18 hand-written lib files, 13 generated .freezed.dart/.g.dart files, 5 README.md)

## Accomplishments

- Closed **ROADMAP SC#4 verbatim**: every domain model named in the spec (Session, Marker, MarkerCategory, MirkStyle, RevealedTile, PhotoRef, **Envelope**) is now Freezed-generated, immutable, with `@Assert` invariants where applicable.
- Closed **ROADMAP SC#5 verbatim** (JsonMigrator integration half): the fixture-driven `session_v1.json -> Envelope.parse -> JsonMigrator([V1ToV2RenameRadius()]) -> session_v2.json payload` round-trip passes under `dart test` in 5 ms.
- Resolved **RESEARCH Open Question #5**: Freezed 3.2.3 DOES support `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` — the generator emits a dispatching `fromJson` that falls through to `UnknownConfig.fromJson` on any unrecognized value. No manual fromJson dispatch needed.
- Solved the **extension-type + json_serializable** impedance mismatch (6 ID types): class-level `JsonConverter` does not propagate through the declared-type resolution; per-field `@JsonKey(fromJson: fn, toJson: fn)` with top-level converter function pairs is the working pattern. Documented in `lib/domain/ids/id_json_converters.dart`.
- Solved the **UnknownConfig raw-map capture** problem with `@JsonKey(readValue: _readWholeMap, ...)` — the `readValue` hook tells json_serializable to hand the entire source map to `UnknownConfig.raw` instead of looking up a nested `'raw'` key. The alternative (hand-written MirkStyleConfig.fromJson) was rejected because it broke the nested `AtmosphericConfig.fromJson` / `ShaderConfig.fromJson` generators.
- Shipped **6 abstract store ports** (Session, Marker, MarkerCategory, MirkStyle, RevealedTile, Photo) with find-vs-require split + SESS-06 docstring on `SessionStore.activate` + MIRK-03 monotonic-OR docstring on `RevealedTileStore.mergeMask` + reassign-to-`kCategoryDefaultId` docstring on `MarkerCategoryStore.delete`.
- **Domain purity invariant holds**: `dart run tool/check_domain_purity.dart` scans 37 hand-written `.dart` files and reports zero forbidden imports. Generated `.freezed.dart` / `.g.dart` files are excluded by the tool's extension filter.

## Task Commits

Each task decomposed into a RED commit (failing test) followed by a GREEN commit (passing implementation). No REFACTOR commits were needed — GREEN implementations were at the desired final shape on the first pass.

1. **Task 1 RED: failing Session invariants + timezone round-trip tests** — `39edcdb` (test)
2. **Task 1 GREEN: 7 Freezed entities + ID JSON converters + generated files + 5 READMEs** — `dece540` (feat)
3. **Task 2 GREEN: 6 store ports + MirkStyleConfig UnknownConfig fallback test** — `70f3c28` (feat; no separate RED because the test references the ports + configs which both landed in this same commit)
4. **Task 3 RED: failing Envelope.fromJson + v1->v2 migration tests** — `fca8380` (test)
5. **Task 3 GREEN: Envelope Freezed + validate/parse + v1->v2 integration green** — `8aed6eb` (feat)

**Plan metadata commit:** _added by post-task gsd-tools step._

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Extension-type IDs not JSON-serializable out of the box**
- **Found during:** Task 1 GREEN first build_runner run
- **Issue:** `json_serializable` emitted `Could not generate fromJson code for SessionId / MarkerId / CategoryId / MirkStyleId / PhotoRefId` for every Freezed entity whose ID field was a Dart-3 extension type. The generator sees the wrapper name and has no default rule for the underlying String. Class-level `JsonConverter<SessionId, String>` annotations did NOT work either because the declared-type resolution boundary in json_serializable collapses extension types to their representation.
- **Fix:** Created `lib/domain/ids/id_json_converters.dart` with 6 top-level function pairs (`sessionIdFromJson` / `sessionIdToJson`, ...) and applied them per-field via `@JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson)`. Added `// ignore_for_file: invalid_annotation_target` on every entity source because the analyzer flags `@JsonKey` on factory params (Freezed copies them onto the generated field where they ARE valid).
- **Files modified:** `lib/domain/ids/id_json_converters.dart` (new), all 6 Freezed entities
- **Verification:** build_runner emits `.g.dart` files; all entity JSON round-trip tests pass; `flutter analyze --fatal-infos` returns clean.
- **Committed in:** `dece540` (Task 1 GREEN)

**2. [Rule 3 - Blocking] Dart 3.11 rejects method invocation in const constructor asserts**
- **Found during:** Task 1 GREEN first compile of `session.freezed.dart`
- **Issue:** The plan's specified `@Assert('displayName.trim().isNotEmpty', ...)` on a `const factory Session` generated a `const _Session({...}) : assert(displayName.trim().isNotEmpty, ...)` that the analyzer flagged as `invalid_constant - Methods can't be invoked in constant expressions`. Dart 3.11 does not permit method invocations (`.trim()`) or even some property getters (`.isNotEmpty`) inside `assert()` within `const` constructor initializer lists.
- **Fix:** Dropped `const` from the factory on every entity carrying a `@Assert`: `Session`, `Marker`, `MarkerCategory`, `MirkStyle`. Kept `const factory` on entities without asserts: `RevealedTile`, `PhotoRef`. Freezed propagates the factory's const-ness to the generated constructor, so this is the right knob to turn. Documented in the entity doc-comments.
- **Files modified:** `lib/domain/sessions/session.dart`, `lib/domain/markers/marker.dart`, `lib/domain/markers/marker_category.dart`, `lib/domain/mirk/mirk_style.dart`
- **Verification:** `dart test test/domain/session_invariants_test.dart` — all 6 assert invariant tests pass (empty displayName, whitespace displayName, offset below -720, offset above 840, boundary values -720/840 succeed, happy path succeeds).
- **Committed in:** `dece540` (Task 1 GREEN)

**3. [Rule 3 - Blocking] UnknownConfig.raw captured a nested 'raw' key instead of the whole payload**
- **Found during:** Task 1 GREEN build_runner run after the first ID-converter fix landed
- **Issue:** With `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')`, json_serializable generated `UnknownConfig.fromJson(json)` that read `json['raw']` — but real-world payloads (the `mirk_style_unknown_renderer.json` fixture, for example) have the unknown config fields flat at the top level. The generated fallback dispatcher would produce `UnknownConfig(raw: null)` and throw a cast error.
- **Fix:** Added `@JsonKey(readValue: _readWholeMap, fromJson: _unknownRawFromJson, toJson: _unknownRawToJson, disallowNullValue: true)` on the `raw` parameter. `_readWholeMap` is a `(Map, String) -> Object?` hook that returns the ENTIRE source map regardless of field name, so the generated fromJson captures the whole payload into `raw`. An alternative (hand-written `MirkStyleConfig.fromJson` with a manual switch) was tried and rejected: it broke the automatic generation of `AtmosphericConfig.fromJson` and `ShaderConfig.fromJson`, requiring hand-writing every variant's JSON codec.
- **Files modified:** `lib/domain/mirk/mirk_style_config.dart`
- **Verification:** `test/domain/mirk_style_config_fromjson_test.dart` — 7 cases including the fixture-driven test on `mirk_style_unknown_renderer.json`; `UnknownConfig.raw` preserves `rendererType`, `displayName`, and nested objects verbatim.
- **Committed in:** `dece540` (Task 1 GREEN)

**4. [Rule 3 - Blocking] Envelope.fromJson block body prevented json_serializable from emitting @JsonSerializable**
- **Found during:** Task 3 GREEN first build_runner run
- **Issue:** My first Envelope implementation put pre-validation directly inside `factory Envelope.fromJson(json) { validate(json); return _$EnvelopeFromJson(json); }`. Freezed 3.2.3's `needsJsonSerializable` check (`lib/src/models.dart:1346`) tests `constructor.body is ExpressionFunctionBody` — block bodies fail the check, so no `@JsonSerializable` annotation was emitted on the generated `_Envelope` class, and `envelope.g.dart` was never written. Compilation failed with `The method 'toJson' isn't defined for the type 'Envelope'` and `part 'envelope.g.dart'` referencing a non-existent file.
- **Fix:** Kept `Envelope.fromJson` as a pure arrow redirect `=> _$EnvelopeFromJson(json)`. Moved pre-validation into `static void validateOrThrow(Map<String, Object?> json)`. Added `static Envelope parse(json)` convenience that composes validate + fromJson. Updated the 6 test cases that needed validation behavior to call `Envelope.parse(json)` instead of `Envelope.fromJson(json)`.
- **Files modified:** `lib/domain/envelope/envelope.dart`, `test/domain/envelope_fromjson_test.dart`, `test/domain/json_migrator_v1_to_v2_test.dart`
- **Verification:** `envelope.g.dart` now generated; `dart test test/domain/envelope_fromjson_test.dart test/domain/json_migrator_v1_to_v2_test.dart` — all 8 tests pass (7 envelope + 1 fixture-driven migration).
- **Committed in:** `8aed6eb` (Task 3 GREEN)

**5. [Rule 2 - Missing] `invalid_annotation_target` warnings on @JsonKey-on-parameter usage**
- **Found during:** Task 1 GREEN `flutter analyze --fatal-infos` after the ID-converter fix
- **Issue:** The analyzer emitted 8 `invalid_annotation_target` warnings — `@JsonKey` has `@Target({TargetKind.field, TargetKind.getter})` in json_annotation, and the analyzer checks the literal syntactic position (a factory constructor parameter), not where Freezed ends up placing the annotation in the generated code. Under `--fatal-infos`, this would fail CI.
- **Fix:** Added `// ignore_for_file: invalid_annotation_target` with an explanatory comment on every Freezed source file that uses `@JsonKey` on a factory parameter (5 files: `session.dart`, `marker.dart`, `marker_category.dart`, `mirk_style.dart`, `mirk_style_config.dart`, `photo_ref.dart`, `envelope.dart`). Standard Freezed convention; the generated files already have the same ignore directive.
- **Files modified:** the 7 Freezed source files listed above
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` — `No issues found!`.
- **Committed in:** `dece540` and `8aed6eb` (part of the respective task commits)

**6. [Rule 1 - Bug] avoid_redundant_argument_values in mirk_style_config_fromjson_test.dart**
- **Found during:** Task 2 GREEN post-implementation `flutter analyze`
- **Issue:** `const MirkStyleConfig cfg = AtmosphericConfig(baseColorArgb: 0xFF000000, noiseScale: 0.5)` — both arguments match the Freezed `@Default` values, and the linter flagged them under `avoid_redundant_argument_values`. Project policy is `--fatal-infos`.
- **Fix:** Simplified to `const MirkStyleConfig cfg = AtmosphericConfig()` — relies on the defaults.
- **Files modified:** `test/domain/mirk_style_config_fromjson_test.dart`
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` — `No issues found!`; test still passes.
- **Committed in:** `70f3c28` (Task 2 commit)

---

**Total deviations:** 6 auto-fixed (1 bug, 1 missing critical, 4 blocking).
**Impact on plan:** All six auto-fixes were necessary to get the plan's stated outputs to compile or pass analysis on Dart 3.11 / Freezed 3.2.3 / json_serializable 6.11.2. No scope creep — every fix was a narrow adaptation to a toolchain constraint the plan didn't anticipate (pre-plan RESEARCH at the time couldn't predict all these exact surface-level breakages). The `id_json_converters.dart` file is the one new artifact, and it's a small 50-line bridge file that unblocks SC#4 — absent it, extension-type IDs could not be serialized at all.

## Issues Encountered

None beyond the auto-fixes above. Every breakage was caught at `build_runner` or `dart analyze` time — no test flakes, no runtime surprises, no data-corruption near misses.

## Authentication Gates

None — no external services touched.

## User Setup Required

None — pure-Dart additions only, zero new dependencies, zero env vars.

## Freezed 3.2.3 fallbackUnion Resolution (RESEARCH Open Question #5)

**Status: CLOSED — `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` works as documented.**

The generator emits the following in `mirk_style_config.freezed.dart`:

```dart
MirkStyleConfig _$MirkStyleConfigFromJson(Map<String, dynamic> json) {
  switch (json['rendererType']) {
    case 'atmospheric':  return AtmosphericConfig.fromJson(json);
    case 'shader':       return ShaderConfig.fromJson(json);
    default:             return UnknownConfig.fromJson(json);
  }
}
```

The `fallbackUnion: 'unknown'` parameter picks the variant whose factory name matches (`MirkStyleConfig.unknown -> UnknownConfig`). The manual-dispatch fallback described in the plan's Task 1 Step 3 was NOT needed.

The only wrinkle was `UnknownConfig.raw`'s capture behavior (auto-fix #3) — solved with `@JsonKey(readValue: _readWholeMap)` rather than hand-written dispatch.

## JSON Timestamp Shape Decision

**Status: Split-fields shipped for Phase 03. Combined ISO 8601 export deferred to Phase 13.**

`Session` carries two pairs of timestamp fields:
- `startedAtUtc: DateTime` (UTC instant) + `startedAtOffsetMinutes: int` (wall-clock offset captured at session start)
- `stoppedAtUtc: DateTime?` + `stoppedAtOffsetMinutes: int?`

JSON wire shape emitted by `Session.toJson()`:
```json
{
  "id": "sess_01HR...",
  "displayName": "Paris 2026",
  "status": "stopped",
  "startedAtUtc": "2026-04-01T06:00:00.000Z",
  "startedAtOffsetMinutes": 120,
  "stoppedAtUtc": "2026-04-01T12:30:00.000Z",
  "stoppedAtOffsetMinutes": 120,
  "notes": null
}
```

This matches `DateTime.toIso8601String()` on a UTC DateTime (trailing `Z`) plus the offset as a separate field. The CONTEXT.md §DateTime strategy target — a single combined field `"startedAt": "2026-04-01T08:00:00+02:00"` — is deferred to Phase 13 SCHEMA.md finalization because:
1. It requires a custom json_serializable converter (split 2 fields -> 1 field on toJson, parse back on fromJson).
2. The parser must handle `DateTime.parse('...+02:00').toUtc()` and capture `.timeZoneOffset.inMinutes` before the UTC conversion.
3. Phase 03's risk-reduction priority preferred to keep the entity-level JSON dumb and move the boundary formatting to the export pipeline (Phase 13 owns PORT-02 readability gate).

The fixture files `test/fixtures/json/session_v1.json` and `session_v2.json` already use the combined `"startedAt": "2026-04-01T10:00:00+02:00"` form — they're not round-tripped through `Session.fromJson` in this plan (they're consumed as raw `Map<String, Object?>` payloads by the JsonMigrator test). Phase 13 will reconcile the two shapes.

## Generated-Files Policy

`.freezed.dart` and `.g.dart` files are committed to the repo alongside their source. Rationale:
- **Build determinism**: running `dart run build_runner build --delete-conflicting-outputs` twice produces byte-equal output on the same Dart SDK, so the committed files reflect a deterministic state.
- **CI economy**: CI (Android, iOS, plain-Dart) skips the codegen step when generated files are already on disk — saves roughly 5 seconds per job.
- **Audit trail**: a reviewer reading a PR can see EXACTLY what code was generated, which surfaces accidental-regressions in the generator stack.
- **`check_domain_purity.dart` exclusion**: the scanner skips files ending in `.g.dart`, `.freezed.dart`, `.gr.dart`, `.config.dart`, `.mocks.dart` (configured in `tool/check_domain_purity.dart:23-29`), so generated files do NOT count against the domain purity score.
- **Analyzer exclusion**: `analysis_options.yaml` adds `**/*.g.dart` and `**/*.freezed.dart` to the `analyzer.exclude` list so generated code does not have to pass the project lint stack.

## Handoff to 03-04 (DB Schema)

Each entity's column layout for the Drift schema:

| Entity | Column | SQL type | Nullable | Notes |
| --- | --- | --- | --- | --- |
| `Session` | `id` | TEXT | NO | PRIMARY KEY, ULID prefix `sess_` |
| `Session` | `displayName` | TEXT | NO | CHECK `length > 0` |
| `Session` | `status` | TEXT | NO | `'active'` \| `'stopped'` |
| `Session` | `startedAtUtc` | INTEGER | NO | ms since epoch (Drift `DateTimeColumn` converter) |
| `Session` | `startedAtOffsetMinutes` | INTEGER | NO | CHECK between -720 and 840 |
| `Session` | `stoppedAtUtc` | INTEGER | YES | null while active |
| `Session` | `stoppedAtOffsetMinutes` | INTEGER | YES | null while active |
| `Session` | `notes` | TEXT | YES | |
| `Marker` | `id, sessionId, categoryId, lat, lon, title, createdAtUtc, createdAtOffsetMinutes, notes` | per Freezed shape | FKs to t_sessions(id), t_marker_categories(id) |
| `MarkerCategory` | `id, displayName, iconName, createdAtUtc, createdAtOffsetMinutes` | per Freezed shape | default row `kCategoryDefaultId` seeded |
| `MirkStyle` | `id, displayName, configJson, createdAtUtc, createdAtOffsetMinutes` | `configJson TEXT` carrying `MirkStyleConfig.toJson()` encoded | JSON column (SQLite `json1`) |
| `RevealedTile` | `id, sessionId, parentX, parentY, parentZoom, bitmap, setBitCount, updatedAtUtc` | `bitmap BLOB` 512 bytes; UNIQUE (`sessionId`, `parentX`, `parentY`) | parentZoom defaults to 14 |
| `PhotoRef` | `id, markerId, relativeBasename, widthPx, heightPx, fileSizeBytes, createdAtUtc, createdAtOffsetMinutes` | per Freezed shape | FK to t_markers(id) ON DELETE CASCADE |

ID columns are `TEXT` (not BLOB) at the SQLite level — extension types are zero-cost wrappers, the DB sees plain strings.

## Handoff to 03-06 (Drift Store Impls)

All six abstract store ports are ready. `lib/infrastructure/stores/` implementations must:

1. Match the port signature byte-for-byte (no widening or narrowing).
2. Wrap `SqliteException(extendedCode: 2067)` into `ConcurrentActivationException` on `SessionStore.activate` (SESS-06).
3. Enforce `mask.length == kRevealedTileBitmapBytes` (=== 512) on `RevealedTileStore.mergeMask` with `ArgumentError`.
4. Execute `MarkerCategoryStore.delete` in a transaction that first `UPDATE markers SET categoryId = kCategoryDefaultId.value WHERE categoryId = :id`, then `DELETE FROM marker_categories WHERE id = :id`.
5. Throw `SessionNotFoundException` / `MarkerNotFoundException` / `CategoryNotFoundException` from `requireById` variants when the row is absent.

## Next Phase Readiness

- **Wave 3 closed** (03-03 alone). Wave 4 (03-04 DB schema + 03-05 DB open + migration + backup) can open now.
- 03-04 knows the exact Drift column layout for each entity (handoff table above).
- 03-05 can freeze `drift_schema_v1.json` against entity shapes that are now final.
- 03-06 can start implementing the six stores against port interfaces that will not change.

Forward-declarations:
- Phase 09 will switch on `MirkStyleConfig` sealed union at the render call site (`AtmosphericConfig`, `ShaderConfig`, `UnknownConfig`). The `UnknownConfig` arm should render a placeholder so imported-from-future-version payloads survive.
- Phase 13 SCHEMA.md will decide whether to collapse Session's `(startedAtUtc, startedAtOffsetMinutes)` into a single combined ISO 8601 string for export. Either shape remains round-trip safe.

---
*Phase: 03-persistence-domain-models*
*Completed: 2026-04-18*

## Self-Check: PASSED

All 23 listed files (lib + test) exist on disk, and all 5 task commit hashes (`39edcdb`, `dece540`, `70f3c28`, `fca8380`, `8aed6eb`) are reachable from `git log --all`.
