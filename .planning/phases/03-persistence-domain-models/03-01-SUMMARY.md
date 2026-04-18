---
phase: 03-persistence-domain-models
plan: 01
subsystem: infra
tags: [custom_lint, riverpod_lint, drift, ci, fixtures, domain-purity, sqlite]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: tool/check_headers.dart, tool/check_licenses.dart, tool/check_dependencies_md.dart, lib/config/constants.dart, .github/workflows/ci.yml gates job, DEPENDENCIES.md audit table
provides:
  - custom_lint 0.8.1 + riverpod_lint 3.1.0 pinned and active (Open Question #1 closed)
  - 7 Phase 03 constants in lib/config/constants.dart (kDbFilename, kDbBackupDirName, kMaxDbBackups, kDbBusyTimeoutMs, kRevealedTileParentZoom, kRevealedTileSubgridSize, kRevealedTileBitmapBytes)
  - test/fixtures/json/ envelope-shaped JSON samples (session_v1, session_v2, markers_only_v1, mirk_style_unknown_renderer)
  - test/fixtures/db_seed/v1_baseline.sql (3 categories + 10 sessions + 50 markers + 5 revealed_tiles + 2 mirk_styles)
  - tool/check_domain_purity.dart + 5-case unit test
  - .github/workflows/ci.yml: libsqlite3 install + drift schema drift guard + plain-Dart test runner (hashFiles-guarded)
  - dart_test.yaml with `migration` tag declared
affects: [03-02-plan, 03-03-plan, 03-04-plan, 03-05-plan, 03-06-plan]

# Tech tracking
tech-stack:
  added:
    - custom_lint 0.8.1 (Apache-2.0)
    - riverpod_lint 3.1.0 (MIT)
    - 8 transitives: analysis_server_plugin 0.3.3, analyzer_plugin 0.13.10, ci 0.1.0, cli_util 0.4.2, custom_lint_core 0.8.1, custom_lint_visitor 1.0.0+8.4.0, rxdart 0.28.0, yaml_edit 2.2.4
  patterns:
    - "Probe-then-pin: throwaway `dart pub add --dry-run` resolves exact compatible triple before touching pubspec.yaml"
    - "hashFiles-guarded CI steps: defer activation until target files exist, no per-plan ci.yml edits required"
    - "Frozen vs rolling drift schema dumps: drift_schema_v{1,2}.json immutable, drift_schema_current.json dumped + diffed every CI run"
    - "Fixture envelope contract documented at fixture-tree-root README, consumed by every parser test"

key-files:
  created:
    - tool/check_domain_purity.dart
    - tool/test/check_domain_purity_test.dart
    - test/fixtures/README.md
    - test/fixtures/json/session_v1.json
    - test/fixtures/json/session_v2.json
    - test/fixtures/json/markers_only_v1.json
    - test/fixtures/json/mirk_style_unknown_renderer.json
    - test/fixtures/db_seed/v1_baseline.sql
    - dart_test.yaml
  modified:
    - pubspec.yaml
    - pubspec.lock
    - analysis_options.yaml
    - lib/config/constants.dart
    - .github/workflows/ci.yml
    - DEPENDENCIES.md

key-decisions:
  - "Pin custom_lint 0.8.1 + riverpod_lint 3.1.0 — highest pair compatible with analyzer<9 stack (flutter_lints 6.0.0 + riverpod_generator 4.0.0+1 both gate <9). riverpod_lint 3.1.1+ requires analyzer ^9, breaks custom_lint 0.8.1."
  - "custom_lint family is Apache-2.0, not MIT as plan stated — correction documented in DEPENDENCIES.md row. Apache-2.0 is on CLAUDE.md allowlist; no GOSL-incompatibility."
  - "Domain purity scanner exempts generated files (.g.dart, .freezed.dart, .gr.dart, .config.dart, .mocks.dart) — produced from annotated source, may legitimately need package:flutter / package:drift, are not in scope for hand-written purity rule."
  - "CI 'Plain-Dart tests' step scoped to test/domain/ + test/infrastructure/ subdirectories rather than root test/ — existing test/*.dart files all import package:flutter_test and would break under the plain-Dart runner. Plan's 'catch-all dart test test/' was naive in this regard; scoping is the safer interpretation."
  - "Bitmap blobs in v1_baseline.sql use zeroblob(512) with set_bit_count=0 — identity round-trip tests in 03-04 don't need bit-level shape; 03-09 paint tests will seed a separate fixture with realistic bit density."

requirements-completed: []  # Plan declares `requirements: []` in frontmatter — Wave 0 bootstrap, no PROJECT.md req IDs attached.

# Metrics
duration: 12 min
completed: 2026-04-18
---

# Phase 03 Plan 01: Wave 0 Bootstrap Summary

**custom_lint 0.8.1 + riverpod_lint 3.1.0 pinned and active, Phase 03 constants seeded, JSON envelope + SQL baseline fixtures committed, domain-purity scanner shipped with CI wiring, libsqlite3 + frozen/rolling drift schema guard added to gates job — Wave 0 unblocks 03-02..03-06 entirely.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-18T09:07:45Z
- **Completed:** 2026-04-18T09:19:51Z
- **Tasks:** 3
- **Files modified:** 14 (8 created, 6 modified)

## Accomplishments

- Closed Phase 01 deferred Open Question #1: lint stack re-adopted with the highest compatible pin.
- All 7 Phase 03 constants live in `lib/config/constants.dart` for downstream consumption (03-04 DB wiring, 03-05 backups, 03-06 stores).
- Four envelope-shaped JSON fixtures + one 70-row SQL seed live under `test/fixtures/`, ready for 03-02 (`JsonMigrator`) and 03-03 (`MirkStyleConfig.fromJson`) and 03-04/03-05 (DB identity + V1->V2 migration tests).
- `tool/check_domain_purity.dart` + 5-case unit suite enforces SC#4 from the moment it runs; CI wires it as a gate.
- `.github/workflows/ci.yml` gates job extended with libsqlite3 system install (no PR will fail on missing native lib when 03-04 lands), drift schema-drift guard (frozen vs rolling fixture distinction baked in), and a plain-Dart test runner scoped to `test/domain/` + `test/infrastructure/`.

## Task Commits

1. **Task 1: pin custom_lint + riverpod_lint, activate plugin, update DEPENDENCIES.md** — `58a86e3` (chore)
2. **Task 2: Phase 03 constants + JSON/SQL fixtures + dart_test.yaml** — `57aa1d0` (feat)
3. **Task 3: domain purity tool + tests + CI extensions (libsqlite3, drift schema, plain-Dart tests)** — `ec724f8` (feat)

**Plan metadata commit:** _added by post-task gsd-tools step._

## Resolution Trace — custom_lint + riverpod_lint Version Pin

**Probe protocol:**

1. Inspected current analyzer stack with `flutter pub deps --style=list | grep -E "^(.*\s+)?(analyzer|lints|flutter_lints)\s"` — confirmed `flutter_lints 6.0.0` + `riverpod_generator 4.0.0+1` both gate `analyzer >=7.x <9.0.0`, current resolved version `analyzer 8.4.1`.
2. Probe `dart pub add --dev custom_lint --dry-run` (in-project, no commit) → resolver picked `custom_lint 0.8.1` cleanly, no analyzer upgrade required.
3. Probe `dart pub add --dev riverpod_lint --dry-run` (separately) → resolver picked `riverpod_lint 3.1.0`, downgraded `analyzer 8.4.1 -> 8.4.0` (still in <9 range).
4. Combined probe `dart pub add --dev custom_lint:0.8.1 riverpod_lint:3.1.0 --dry-run` → succeeded, 11 packages would change.
5. Tried `dart pub add --dev custom_lint:0.8.2 riverpod_lint:3.1.3 --dry-run`:
   - **Rejected:** `custom_lint 0.8.2` does not exist on pub.dev (only `custom_lint_core 0.8.2`).
6. Tried `dart pub add --dev custom_lint:0.8.1 riverpod_lint:3.1.3 --dry-run`:
   - **Rejected:** `Because riverpod_lint >=3.1.1 depends on analyzer ^9.0.0 and custom_lint >=0.8.1 depends on analyzer ^8.0.0, riverpod_lint >=3.1.1 is incompatible with custom_lint >=0.8.1.`

**Final pin** (committed in `pubspec.yaml`):
```yaml
custom_lint: 0.8.1
riverpod_lint: 3.1.0
```

**`pubspec.lock` excerpt** (versions resolved after `flutter pub get`):
```
analyzer:               8.4.0   (was 8.4.1 — resolver convergence)
custom_lint:            0.8.1
custom_lint_core:       0.8.1
custom_lint_visitor:    1.0.0+8.4.0
riverpod_lint:          3.1.0
analysis_server_plugin: 0.3.3
analyzer_plugin:        0.13.10
ci:                     0.1.0
cli_util:               0.4.2
rxdart:                 0.28.0
yaml_edit:              2.2.4
```

**Plugin activation** (`analysis_options.yaml`):
```yaml
analyzer:
  plugins:
    - custom_lint
```

**Sanity check:** `dart run custom_lint` returned `No issues found!` against current `lib/` — no false positives forced a Phase 01 code change.

## CI Diff Summary

Three new gates-job steps + one extension; rationale per step:

| New step | Position | Rationale |
|----------|----------|-----------|
| `Install libsqlite3` | After `Pub get` | Required by Drift `NativeDatabase.memory()` in 03-04+ tests on the Ubuntu runner. Pre-provisioning avoids per-plan ci.yml edits. |
| `Check domain purity` | After `Check DEPENDENCIES.md` | Gates SC#4 from day one. Currently a no-op (lib/domain/ has only README); fails the moment 03-02 / 03-03 land a forbidden import. |
| `Check drift schema (current) is committed and fresh` | After `Tool scripts unit tests` | hashFiles-guarded on `lib/infrastructure/db/app_database.dart` so the step is silent until 03-04 ships the DB. Once present, every PR re-dumps `drift_schema_current.json` and `git diff --exit-code` proves the file is fresh. The version-specific `drift_schema_v{1,2}.json` fixtures are FROZEN historical snapshots produced once at schema-version bump time and are NEVER touched by this step. |
| `Plain-Dart domain + infra tests` | After Flutter test steps | Scoped to `test/domain/` + `test/infrastructure/` subdirs (existing `test/*.dart` at repo root all use `flutter_test`). hashFiles-guarded so the step is silent until those subdirs exist. Downstream plans add tests there without touching ci.yml. |

`hashFiles` guarding is the key pattern: every step that depends on a future artefact silently no-ops until the artefact lands. This means **no downstream plan in Phase 03 needs to touch `.github/workflows/ci.yml`** — the gates pipeline self-activates as the codebase grows.

## Fixture Invariants for Downstream Plans

**Envelope contract (consumed by 03-02 `JsonMigrator`):**
```json
{ "schemaVersion": 1, "type": "session" | "bundle" | "markers_only" | "mirk_style", "payload": { ... } }
```

**V1->V2 rename contract:**
- V1 `session.payload.mirk_radius_m` → V2 `session.payload.reveal_radius_m`
- All other fields identical (same `id`, same `displayName`, same timestamps).

**Unknown-rendererType contract (consumed by 03-03 `MirkStyleConfig.fromJson`):**
- Fixture `mirk_style_unknown_renderer.json` payload has `rendererType: "non-existent-future-renderer-v99"` with arbitrary extra fields under `config`.
- `MirkStyleConfig.fromJson(payload)` MUST produce `UnknownConfig(raw: payload)` — round-trip MUST preserve the original JSON body byte-for-byte (no normalization).

**SQL seed column-name claims** (`v1_baseline.sql`):
- Tables: `t_marker_categories`, `t_sessions`, `t_markers`, `t_revealed_tiles`, `t_mirk_styles`
- Timestamp columns: `<x>_at_utc` (INTEGER, ms epoch UTC) + `<x>_at_offset_minutes` (INTEGER, minutes offset from UTC at the moment of capture)
- Bitmap column: `bitmap` (BLOB, exactly 512 bytes) + `set_bit_count` (INTEGER, populated by writer)
- ID prefixes: `cat_`, `sess_`, `mrk_`, `rvt_`, `mst_` (ULID-shaped, 26-char body)
- `t_mirk_styles.config`: TEXT (JSON-encoded)

**Authoritative schema:** 03-04 owns `lib/infrastructure/db/app_database.dart`. If a column-name divergence is discovered there, the seed file is updated by 03-04 (tracked explicitly in 03-04 must_haves) — never silently in a downstream consumer.

## Files Created/Modified

**Created:**
- `tool/check_domain_purity.dart` — forbidden-import scanner for `lib/domain/`, exits 0/1/2 per Phase 01 contract.
- `tool/test/check_domain_purity_test.dart` — 5 cases (happy, flutter violation, drift violation, missing root, generated-file exemption).
- `test/fixtures/README.md` — layout, envelope contract, schema-authority forward-declaration to 03-04.
- `test/fixtures/json/session_v1.json` — V1 session envelope (mirk_radius_m).
- `test/fixtures/json/session_v2.json` — V2 session envelope (reveal_radius_m), same identity as V1.
- `test/fixtures/json/markers_only_v1.json` — standalone markers payload, single Eiffel Tower marker.
- `test/fixtures/json/mirk_style_unknown_renderer.json` — unknown rendererType blob for 03-03 fallback test.
- `test/fixtures/db_seed/v1_baseline.sql` — 70-row baseline seed (3 categories + 10 sessions + 50 markers + 5 revealed_tiles + 2 mirk_styles).
- `dart_test.yaml` — declares `migration` tag with 2x timeout multiplier for 03-05 SchemaVerifier suite.

**Modified:**
- `pubspec.yaml` — added `custom_lint: 0.8.1` + `riverpod_lint: 3.1.0` under dev_dependencies, replaced Phase 01 deferral note with pin rationale.
- `pubspec.lock` — regenerated (11 packages changed: 2 new direct dev + 9 new transitives, analyzer downgraded 8.4.1 -> 8.4.0).
- `analysis_options.yaml` — added `analyzer.plugins: [custom_lint]` block.
- `lib/config/constants.dart` — appended Phase 03 section with 7 new constants.
- `.github/workflows/ci.yml` — added 4 steps to gates job (libsqlite3 install, domain-purity check, drift schema guard, plain-Dart test runner).
- `DEPENDENCIES.md` — added 11 audit rows (2 new direct dev + 9 new transitives + analyzer version bump from 8.4.1 -> 8.4.0).

## Decisions Made

See frontmatter `key-decisions` for the 5 logged decisions. Key call-outs:

1. **custom_lint license correction.** Plan stated "MIT" for both lint packages. Inspecting the LICENSE files in the local pub cache showed `custom_lint`, `custom_lint_core`, and `custom_lint_visitor` are Apache-2.0 (only `riverpod_lint` is MIT). DEPENDENCIES.md rows were written with the actual license; both Apache-2.0 and MIT are on CLAUDE.md's allowlist so no GOSL incompatibility.
2. **CI plain-Dart test step scoping.** The plan suggested a "catch-all `dart test test/`" step. That would have failed immediately because every existing `test/*.dart` file imports `package:flutter_test` and crashes under the plain-Dart runner. The step was scoped to `test/domain/` + `test/infrastructure/` subdirectories so future pure-Dart suites land cleanly while existing widget/binding tests stay under `flutter test`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] custom_lint license is Apache-2.0, not MIT**
- **Found during:** Task 1 (audit step before writing DEPENDENCIES.md rows)
- **Issue:** Plan's audit row template stated `MIT` for both `custom_lint` and `riverpod_lint`. Inspection of LICENSE preambles in the local pub cache (`C:/Users/oliver/AppData/Local/Pub/Cache/hosted/pub.dev/custom_lint-0.8.1/LICENSE`) shows `Apache License Version 2.0, January 2004`. Same for `custom_lint_core` and `custom_lint_visitor`. Only `riverpod_lint` is MIT.
- **Fix:** DEPENDENCIES.md rows for `custom_lint`, `custom_lint_core`, `custom_lint_visitor` written as Apache-2.0; correction noted explicitly in the `custom_lint` row's audit column.
- **Files modified:** `DEPENDENCIES.md`
- **Verification:** `dart run tool/check_licenses.dart` → `OK (185 packages)`. Apache-2.0 is on CLAUDE.md allowlist (`§Licences acceptées`), no policy violation.
- **Committed in:** `58a86e3` (Task 1)

**2. [Rule 1 - Bug] Plan's "catch-all dart test test/" CI step would have failed immediately**
- **Found during:** Task 3 (writing the catch-all step)
- **Issue:** Every existing `test/*.dart` file at the repo root imports `package:flutter_test` (verified via `head -10 test/*.dart`). Running `dart test test/` would attempt to load those files under the plain-Dart runner and crash on the `flutter_test` import. The plan's `hashFiles('test/**/*_test.dart')` guard is always-true (existing files match) so the step would activate immediately and break every CI run.
- **Fix:** Scoped the step to `test/domain/` + `test/infrastructure/` subdirectories (which won't exist until 03-02+ lands plain-Dart suites there). Both checked at runtime via `if [ -d ... ]; then dart test ...; fi` so an empty subdir is silently skipped. hashFiles guard updated to match the same subdirs.
- **Files modified:** `.github/workflows/ci.yml`
- **Verification:** `dart run` of the YAML parser confirms 15 gates job steps and the file is structurally valid. Step is currently a no-op (neither subdir exists), so no CI break.
- **Committed in:** `ec724f8` (Task 3)

**3. [Rule 1 - Bug] analyzer transitive downgraded 8.4.1 → 8.4.0 by `flutter pub get`**
- **Found during:** Task 1 (post-`flutter pub get` lockfile inspection)
- **Issue:** Adding `custom_lint 0.8.1` introduced a tighter constraint (`custom_lint_visitor 1.0.0+8.4.0` requires `analyzer >=8.0.0 <9.0.0` with a different upper-bound interaction) that converged the resolver on `analyzer 8.4.0` instead of the previously locked 8.4.1. `tool/check_dependencies_md.dart` flagged the version mismatch immediately.
- **Fix:** Updated the `analyzer` row in `DEPENDENCIES.md` from `8.4.1 → 8.4.0` and appended `custom_lint` to the "Pulled in by" column. Date stamp bumped to 2026-04-18.
- **Files modified:** `DEPENDENCIES.md`
- **Verification:** `dart run tool/check_dependencies_md.dart` → `OK (185 packages)`.
- **Committed in:** `58a86e3` (Task 1)

---

**Total deviations:** 3 auto-fixed (3 bugs, 0 missing critical, 0 blocking, 0 architectural).
**Impact on plan:** All three were corrections to plan-supplied details (license string, naive CI step scope, missed transitive version drift). No scope creep; outputs match the plan's intent exactly. The CI step revision is the most consequential — it prevents a guaranteed-CI-break on the next push.

## Issues Encountered

None — all three tasks executed against working tooling. The deviations above were caught at verification time and resolved within the same task commit.

## Authentication Gates

None — no external services touched.

## User Setup Required

None — no external service configuration.

## Next Phase Readiness

**Wave 0 closed.** Wave 1 / 2 plans (03-02 `JsonMigrator`, 03-03 `MirkStyleConfig`) can now start in parallel:
- JSON fixtures are on disk for `JsonMigrator` round-trip tests.
- `MirkStyleConfig.fromJson` test input is on disk.
- Domain-purity gate is wired so the moment those plans land their first `lib/domain/` types, the import rule is enforced.
- `custom_lint` + `riverpod_lint` are live so any `@riverpod` provider added in 03-06 is linted automatically.
- `lib/config/constants.dart` exposes the 7 Phase 03 constants so 03-04 + 03-05 don't need to invent them ad hoc.
- `dart_test.yaml` declares the `migration` tag so 03-05 can opt in cleanly.

**Forward-declarations to honour:**
- 03-04 owns the authoritative DB schema. If column names diverge from `v1_baseline.sql` (e.g. `started_at_ms` instead of `started_at_utc`), 03-04 updates the seed file there.
- The first commit under `lib/infrastructure/db/app_database.dart` will trigger the drift-schema-drift CI guard automatically — 03-04 must commit a fresh `drift_schemas/drift_schema_current.json` in the same PR.
- The first `_test.dart` under `test/domain/` will activate the plain-Dart CI step — 03-02 must verify the test runs cleanly under `dart test` (no `flutter_test` imports).

---
*Phase: 03-persistence-domain-models*
*Completed: 2026-04-18*

## Self-Check: PASSED

All 9 created files exist on disk and all 3 task commit hashes (`58a86e3`, `57aa1d0`, `ec724f8`) are reachable from `git log --all`.
