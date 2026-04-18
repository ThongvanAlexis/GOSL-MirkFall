---
phase: 03-persistence-domain-models
plan: 04
subsystem: infra
tags: [drift, drift_dev, sqlite, wal, pragmas, schema-verifier, migrations, analyzer-10, onBeforeUpgrade, sess-06, mirk-03]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: lib/config/constants.dart (kDbFilename, kDbBusyTimeoutMs, kRevealedTileBitmapBytes), lib/domain/sessions/session_status.dart (active|stopped), lib/domain/mirk/mirk_style_config.dart (sealed union + toJson/fromJson), test/fixtures/db_seed/v1_baseline.sql, tool/check_domain_purity.dart, tool/check_headers.dart, tool/check_dependencies_md.dart, tool/check_licenses.dart
provides:
  - lib/infrastructure/db/app_database.dart — @DriftDatabase with 6 tables (t_sessions, t_marker_categories, t_markers, t_revealed_tiles, t_mirk_styles, t_photos), SESS-06 partial unique index, MIRK-03 composite unique key, FK+CASCADE policy per CONTEXT.md, schemaVersion=2
  - lib/infrastructure/db/pragma_setup.dart — applyRuntimePragmas (synchronous=NORMAL, busy_timeout=5000, foreign_keys=ON)
  - lib/infrastructure/db/type_converters.dart — UnixMsToDateTimeConverter, SessionStatusStringConverter, MirkStyleConfigJsonConverter
  - lib/infrastructure/db/migrations/v1_to_v2_notes.dart — V1ToV2Notes.apply via raw customStatement
  - lib/infrastructure/db/README.md — documents tables, pragma order, migration workflow, onBeforeUpgrade contract
  - drift_schemas/drift_schema_v1.json (frozen) + drift_schema_v2.json (frozen) + drift_schema_current.json (rolling)
  - test/generated_migrations/schema.dart + schema_v1.dart + schema_v2.dart (drift_dev auto-generated)
  - AppDatabase.onBeforeUpgrade hook — Blocker 3 wiring point for 03-05 DbBackupService.takeBackup
  - 13 new in-memory DB tests (pragma, schema, V1 identity fixture)
affects: [03-05-plan, 03-06-plan]

# Tech tracking
tech-stack:
  added:
    - drift_dev 2.32.1 (MIT, dev dep — Drift codegen + schema dump CLI)
    - sqlparser 0.44.3 (MIT, transitive via drift_dev)
    - recase 4.1.0 (BSD-2-Clause, transitive via drift_dev)
    - charcode 1.4.0 (BSD-3-Clause, transitive via drift_dev)
  bumped:
    - analyzer 8.4.0 -> 10.0.1 (via dependency_overrides, required by drift_dev 2.32.1 ^10.0.0)
    - _fe_analyzer_shared 91.0.0 -> 93.0.0 (with analyzer)
    - analyzer_buffer 0.1.11 -> 0.3.1
    - build_runner 2.9.0 -> 2.13.1 (analyzer APIs removed in 10 — LibraryElement2, Element2, element2)
    - build_config 1.2.0 -> 1.3.0 (with build_runner)
    - dart_style 3.1.3 -> 3.1.7 (via dependency_overrides — 3.1.8 requires analyzer ^12)
    - freezed 3.2.3 -> 3.2.5 (supports analyzer >=9 <11)
    - json_annotation 4.9.0 -> 4.11.0 (required by json_serializable 6.13.1)
    - json_serializable 6.11.2 -> 6.13.1 (supports analyzer >=10 <13)
    - flutter_riverpod 3.1.0 -> 3.3.1 (riverpod 3.2.1 chain)
    - riverpod 3.1.0 -> 3.2.1 (via flutter_riverpod)
    - riverpod_analyzer_utils 1.0.0-dev.8 -> 1.0.0-dev.9
    - riverpod_annotation 4.0.0 -> 4.0.2 (riverpod 3.2.1 chain)
    - riverpod_generator 4.0.0+1 -> 4.0.3
    - riverpod_lint 3.1.0 -> 3.1.3 (latest stable, matches riverpod 3.2.1 chain)
    - source_helper 1.3.8 -> 1.3.11 (with json_serializable)
  degraded-gracefully:
    - custom_lint 0.8.1 (kept — no release targets analyzer ^10; analyzer plugin cannot load under analyzer 10 and silently no-ops; acceptable because no @riverpod targets yet)
    - riverpod_lint 3.1.3 (bumped but still host-dependent on custom_lint — inherits the silent-degradation until custom_lint ships analyzer-^10)
  patterns:
    - "dependency_overrides: analyzer ^10.0.0 + dart_style 3.1.7 — forces the entire codegen toolchain onto analyzer-10 (drift_dev's required ceiling) while clamping dart_style below the 3.1.8 release that requires analyzer ^12"
    - "AppDatabase.onBeforeUpgrade: Future<void> Function(OpeningDetails)? — fires inside MigrationStrategy.beforeOpen iff details.hadUpgrade == true, BEFORE onUpgrade — 03-05 injects DbBackupService.takeBackup"
    - "Pragma order split: PRAGMA journal_mode=WAL on the raw sqlite3 handle via NativeDatabase.memory's setup: callback (pitfall #2 — WAL must be set before Drift's first query); synchronous + busy_timeout + foreign_keys via MigrationStrategy.beforeOpen (every open)"
    - "Migration raw customStatement over m.addColumn — portable across Drift 2.x, avoids circular AppDatabase dependency in the migration file, survives future column-accessor renames"
    - "Frozen vs rolling schema dumps — drift_schema_v{N}.json is a versioned immutable fixture, drift_schema_current.json is the rolling CI-guarded mirror (Blocker 4 prevention: versioned files never get trampled by a schema-version bump)"
    - "In-memory SQLite always reports journal_mode='memory' regardless of PRAGMA journal_mode=WAL — WAL requires on-disk shared memory region. Unit tests accept the observable value; file-backed WAL lands in 03-05 integration."

key-files:
  created:
    - lib/infrastructure/db/app_database.dart
    - lib/infrastructure/db/app_database.g.dart
    - lib/infrastructure/db/pragma_setup.dart
    - lib/infrastructure/db/type_converters.dart
    - lib/infrastructure/db/migrations/v1_to_v2_notes.dart
    - lib/infrastructure/db/README.md
    - drift_schemas/drift_schema_v1.json
    - drift_schemas/drift_schema_v2.json
    - drift_schemas/drift_schema_current.json
    - test/generated_migrations/schema.dart
    - test/generated_migrations/schema_v1.dart
    - test/generated_migrations/schema_v2.dart
    - test/infrastructure/db/app_database_pragma_test.dart
    - test/infrastructure/db/app_database_schema_test.dart
    - test/infrastructure/db/v1_identity_fixture_test.dart
  modified:
    - pubspec.yaml (preflight: 15 version bumps + drift_dev add + dependency_overrides block)
    - pubspec.lock (regenerated by flutter pub get)
    - analysis_options.yaml (custom_lint plugin block commented out — cannot load under analyzer 10)
    - DEPENDENCIES.md (preflight: 17 version updates + 4 new rows — drift_dev, sqlparser, recase, charcode)
    - test/fixtures/db_seed/v1_baseline.sql (status='paused' -> 'stopped', forward-declared 03-01 handoff)
    - tool/check_headers.dart (exempt test/generated_migrations/ from scan)
    - lib/presentation/router.g.dart (dart_style 3.1.7 reformat — codegen side-effect)

key-decisions:
  - "REVERSED from 03-01: the analyzer-<9 pin is dropped in favour of analyzer ^10.0.0 via dependency_overrides because drift_dev 2.32.1 requires analyzer ^10. custom_lint 0.8.1 is the highest release and targets analyzer ^8, so it silently degrades under the override — accepted because no @riverpod targets exist until plan 03-06. Re-evaluate the override when custom_lint ships analyzer-^10 support."
  - "V1ToV2Notes uses raw customStatement('ALTER TABLE t_sessions ADD COLUMN notes TEXT') — portable across Drift 2.x versions, no circular AppDatabase dependency in the migration file, survives future column-accessor renames. Alternative m.addColumn(db.sessions, db.sessions.notes) was rejected because it would require passing AppDatabase into the migration."
  - "AppDatabase exposes onBeforeUpgrade: Future<void> Function(OpeningDetails)? constructor parameter (nullable) — fires inside MigrationStrategy.beforeOpen iff details.hadUpgrade == true, BEFORE onUpgrade runs. 03-05 wires DbBackupService.takeBackup into it so a pre-migration snapshot lands before any schema change. The details.hadUpgrade guard prevents backup fires on first-open (onCreate) paths."
  - "Offset-minutes CHECK constraint uses the self-referencing getter pattern Drift documents in the official docs (creationTime.isBiggerThan(...) inside creationTime's own getter). Dart analyzer's recursive_getters warning is a false positive — Drift's codegen rewrites the body at build time — so the getter is explicitly `// ignore: recursive_getters`."
  - "Frozen vs rolling schema dumps: drift_schema_v1.json and drift_schema_v2.json are immutable historical snapshots produced once at version-bump time, drift_schema_current.json is the CI-guarded rolling mirror. Blocker 4 prevention: a schema-version bump refreshes current.json but NEVER touches lower-version fixtures. Verified in Task 2 via git diff --exit-code drift_schema_v1.json after dumping V2."
  - "test/fixtures/db_seed/v1_baseline.sql reconciliation: sessions 04 and 07 switched from status='paused' to 'stopped' with real stopped_at timestamps. 'paused' was never a valid SessionStatus enum value (only active | stopped). 03-01-SUMMARY.md forward-declared this as 03-04's responsibility under 'Authoritative schema: 03-04 owns lib/infrastructure/db/app_database.dart'."
  - "In-memory SQLite journal_mode test expects 'memory' not 'wal' — SQLite ignores PRAGMA journal_mode=WAL on in-memory DBs (sqlite.org/wal.html §2.1: WAL requires an on-disk shared-memory region). The setup: hook still fires for consistency; file-backed WAL verification lands in 03-05 integration."
  - "Explicit MirkStyleConfig + SessionStatus imports in app_database.dart — the generated .g.dart is `part of 'app_database.dart'` so its free-floating references to those types need the enclosing library to import them directly. type_converters.dart's own imports don't re-export through a `part` boundary."

patterns-established:
  - "Per-task atomic commits: preflight (toolchain unblock) -> Task 1 (V1 schema shape) -> Task 2 (V2 bump + migration + dumps) -> Task 3 (tests)"
  - "drift_dev schema dump explicit-filename arg (not directory) to avoid overwriting frozen fixtures"
  - "DEPENDENCIES.md audit rows updated in the same commit that bumps the pinned version (CI gate enforces freshness)"
  - "GOSL header exemption extended to any test/generated_migrations/ path — drift_dev codegen output, not hand-written"

requirements-completed: [SESS-06, MIRK-03]

# Metrics
duration: 20 min
completed: 2026-04-18
---

# Phase 03 Plan 04: Drift AppDatabase + pragmas + V1->V2 migration Summary

**AppDatabase ships 6 Drift tables at schemaVersion=2 with SESS-06 partial unique index + MIRK-03 composite unique + FK+CASCADE policy, V1->V2 symbolic `notes` column migration via raw customStatement, both frozen schema dumps + rolling current mirror committed, SchemaVerifier migration helpers generated, pragma wiring split between `setup:` (first-open WAL pin) and `beforeOpen` (runtime pragmas on every open), `onBeforeUpgrade` hook exposed for 03-05 backup wiring, 13 new in-memory DB tests green (including SC#1 V1 identity fixture loading 70 rows into `DatabaseAtV1` with row counts 10/50/5/3/2), 82-test pure-Dart suite passes, analyzer clean — and the 03-01 analyzer-<9 pin decision is explicitly REVERSED via a `dependency_overrides: analyzer ^10.0.0` block required by drift_dev 2.32.1, with custom_lint silently degrading until it ships analyzer-^10 support.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-04-18T10:49:58Z
- **Completed:** 2026-04-18T11:10:40Z
- **Tasks:** 3 (+ 1 preflight for the toolchain unlock)
- **Commits:** 4 (1 chore + 2 feat + 1 test)
- **Files created:** 15 (9 lib/, 3 test/, 3 drift_schemas/)
- **Files modified:** 7 (pubspec.yaml + pubspec.lock + analysis_options.yaml + DEPENDENCIES.md + v1_baseline.sql + check_headers.dart + router.g.dart codegen side-effect)

## Accomplishments

- Closed SC#1 pragma contract: synchronous=NORMAL, busy_timeout=5000, foreign_keys=ON verified under `dart test`. WAL is wired through `NativeDatabase.memory`'s `setup:` callback (pitfall #2 avoidance) — the raw sqlite3 handle gets `PRAGMA journal_mode=WAL` before Drift's first query. In-memory backends report `'memory'` regardless (SQLite fundamental limitation), so the file-backed verification lands in 03-05.
- Closed SC#1 V1 identity: `test/fixtures/db_seed/v1_baseline.sql` loads into `SchemaVerifier(GeneratedHelper()).schemaAt(1)` and the row counts match the fixture header exactly (10 sessions + 50 markers + 5 revealed_tiles + 3 categories + 2 mirk_styles).
- Closed SESS-06 schema-layer half: partial unique index `idx_t_sessions_status_active` exists with the expected `WHERE status='active'` clause, a second `status='active'` INSERT raises `SqliteException(extendedResultCode: 2067, SQLITE_CONSTRAINT_UNIQUE)`, and multiple `status='stopped'` rows coexist without contention. The store-layer wrapper (`ConcurrentActivationException`) lands in 03-06.
- Closed MIRK-03 schema-layer half: `t_revealed_tiles` has `bitmap BLOB NOT NULL`, composite unique key on `(session_id, parent_x, parent_y, parent_zoom)`, and duplicate inserts raise the same extended code 2067. Idempotent `mergeBitmap` writes in 03-06.
- Closed SC#4 infrastructure side: all Drift code lives under `lib/infrastructure/db/`, `dart run tool/check_domain_purity.dart` still returns OK (37 files, zero forbidden imports) — domain layer remains Flutter/Drift-free.
- Closed SC#6 framework half: `schemaVersion=2`, `V1ToV2Notes.apply` wired in `onUpgrade`, frozen `drift_schema_v{1,2}.json` + rolling `drift_schema_current.json` committed, `test/generated_migrations/` SchemaVerifier helpers generated. The end-to-end V1->V2 migration test lands in 03-05 alongside `DbBackupService`.
- Exposed `AppDatabase(executor, onBeforeUpgrade: hook)` — the Blocker 3 wiring point. Fires inside `beforeOpen` when `details.hadUpgrade == true`, BEFORE `onUpgrade`. 03-05 injects `DbBackupService.takeBackup` into it.
- Reversed the 03-01 analyzer-<9 pin decision: `dependency_overrides: analyzer ^10.0.0` + `dart_style 3.1.7` unblocks drift_dev 2.32.1 (requires analyzer ^10). 15 toolchain packages bumped alongside; DEPENDENCIES.md updated with 4 new rows and 17 version refreshes; `check_dependencies_md` + `check_licenses` both green.
- `custom_lint` 0.8.1 silently degrades under analyzer 10 (no compatible release exists); analysis_options.yaml has the `plugins: [custom_lint]` activation commented out with a re-enable hook. Acceptable because no `@riverpod` targets exist yet — first ones land in 03-06.

## Task Commits

| # | Type | Title | Commit |
|---|------|-------|--------|
| 0 | chore | Preflight: unlock drift_dev toolchain via analyzer-10 override | `e923558` |
| 1 | feat | AppDatabase V1 schema + pragma_setup + type_converters | `58e5a07` |
| 2 | feat | Bump schemaVersion=2, add t_sessions.notes + V1ToV2Notes migration | `314b4b4` |
| 3 | test | Pragma + schema + V1 identity fixture tests | `90c2478` |

Plan metadata commit added by the post-task gsd-tools step.

## V1ToV2Notes implementation choice — raw customStatement

Three options evaluated:

1. **`m.addColumn(db.sessions, db.sessions.notes)`** — requires passing the `AppDatabase` reference into the migration, creates a circular import between `app_database.dart` and `migrations/v1_to_v2_notes.dart`. Rejected.
2. **`m.database.resolvedEngine.attachedDatabase.*`** — tangled Drift internals, version-specific API surface, brittle across Drift 2.x minor releases. Rejected.
3. **Raw `customStatement('ALTER TABLE t_sessions ADD COLUMN notes TEXT')`** — portable across Drift 2.x, no AppDatabase dependency, survives column-accessor renames, trivially testable through SchemaVerifier. **Chosen.**

Shipped form:
```dart
static Future<void> apply(Migrator m, int from, int to) async {
  if (from < 2 && to >= 2) {
    await m.database.customStatement(
      'ALTER TABLE t_sessions ADD COLUMN notes TEXT',
    );
  }
}
```

The `(from, to)` guard makes the migration idempotent: applying it at `(1, 2)` runs once, re-applying at `(2, 2)` or higher skips. SchemaVerifier exercises both paths in 03-05.

## Fixture SQL reconciliation — `test/fixtures/db_seed/v1_baseline.sql`

03-01 seeded the fixture before the schema was locked. Two reconciliations needed once Task 1-2 ratified the Drift shape:

| Before | After | Reason |
|--------|-------|--------|
| `'paused'` (sessions 04, 07) | `'stopped'` with real `stopped_at_utc` + offset | `SessionStatus` enum has only `active | stopped`; `paused` would fail `SessionStatus.fromSql` the moment any store code loaded the rows. 03-01-SUMMARY.md §Handoff explicitly forward-declared this as 03-04's responsibility. |
| Header comment "none status='active' — partial unique index tolerates 0" | "all status='stopped' — SessionStatus enum has only 'active' | 'stopped'; partial unique index tolerates zero actives, which keeps the fixture collision-free" | Clearer correspondence with the enum contract. |

No column-name changes needed — the Drift codegen's default snake_case mapping matched `display_name`, `started_at_utc`, etc. exactly.

## Schema dump workflow (frozen vs rolling)

Two-step sequence followed for V1 -> V2:

1. **Task 1 (V1 state):** Ship AppDatabase with `schemaVersion=1` and NO `notes` column. Run `dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_v1.json` and `cp` to `drift_schema_current.json`.
2. **Task 2 (V2 state):** Add `notes` column, bump `schemaVersion=2`, wire `V1ToV2Notes.apply` in `onUpgrade`. Run `dart run drift_dev schema dump ... drift_schemas/drift_schema_v2.json` and `cp` to `drift_schema_current.json` (overwriting). Verify `git diff --exit-code drift_schemas/drift_schema_v1.json` passes (V1 stays frozen).

**Invariant locked by Blocker 4 prevention (documented in 03-01-SUMMARY):** `drift_schema_vN.json` is an immutable fixture. Every future schema version bump (plan 03-05 and beyond, if any) produces a new `drift_schema_vN+1.json` and refreshes `drift_schema_current.json` — but NEVER touches lower-version files. CI only diff-guards `drift_schema_current.json`.

After every `schemaVersion` bump, run `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/ --data-classes --companions` to regenerate the SchemaVerifier helpers. Three files land: `schema.dart` (GeneratedHelper class), `schema_v1.dart` (DatabaseAtV1), `schema_v2.dart` (DatabaseAtV2). All three committed.

## Pragma verification strategy

Four pragmas under test via `customSelect('PRAGMA <name>').getSingle()`:

| PRAGMA | Expected value (in-memory) | Wiring point |
|--------|---------------------------|--------------|
| `journal_mode` | `'memory'` | `NativeDatabase.memory(setup: (r) => r.execute('PRAGMA journal_mode = WAL'))` — fires BEFORE Drift opens the connection. In-memory DBs ignore WAL (needs on-disk shared mem) and pin `memory`; file-backed DBs in production would show `'wal'`. Documented in the test. |
| `synchronous` | `'1'` (NORMAL) | `applyRuntimePragmas` in `MigrationStrategy.beforeOpen` |
| `busy_timeout` | `'5000'` (kDbBusyTimeoutMs) | `applyRuntimePragmas` |
| `foreign_keys` | `'1'` | `applyRuntimePragmas` — CRITICAL; default is OFF and silently voids CASCADE |

All four return their values as integer strings via `customSelect`; the test compares string-wise after converting the stored constant via `toString()`. Production file-backed verification lands in 03-05 alongside the DB factory.

## `onBeforeUpgrade` hook contract

```dart
AppDatabase(super.executor, {this.onBeforeUpgrade});
final Future<void> Function(OpeningDetails details)? onBeforeUpgrade;
```

Fires inside `MigrationStrategy.beforeOpen`:

```dart
beforeOpen: (OpeningDetails details) async {
  if (details.hadUpgrade && onBeforeUpgrade != null) {
    await onBeforeUpgrade!(details);
  }
  await applyRuntimePragmas(this);
}
```

Key contract points:

1. **Guarded by `details.hadUpgrade`** — fires only on upgrade paths (schemaVersion increase from a previously-opened version). First-open paths (`onCreate` — new installs) do NOT fire the hook; no "backup of an empty DB" writes.
2. **Fires BEFORE `onUpgrade`** — the hook sees the DB in its pre-migration shape. 03-05's `DbBackupService.takeBackup` snapshots the DB file at this point so rollback to the pre-migration state is possible if `onUpgrade` corrupts data.
3. **Nullable** — tests (and the factory's test mode) pass `null` and skip the hook; production factory (03-05) injects the real backup call.
4. **Pragmas run AFTER the hook** — so the hook sees whatever pragma state the previous session left behind. This is intentional: a backup should snapshot the on-disk state exactly as it was, not a pragma-normalized version.

## Frozen-fixture / rolling-current split (Blocker 4 prevention)

| File | Mutability | Refreshed |
|------|------------|-----------|
| `drift_schemas/drift_schema_v1.json` | **FROZEN** | Once, in Task 1 (schemaVersion=1). Never written to again. |
| `drift_schemas/drift_schema_v2.json` | **FROZEN** | Once, in Task 2 (schemaVersion=2). Never written to again. |
| `drift_schemas/drift_schema_current.json` | **ROLLING** | On every schemaVersion bump — current.json is overwritten to match the highest schemaVersion. |

CI's drift-schema diff guard (added in 03-01, activated now) runs `dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_current.json && git diff --exit-code drift_schemas/drift_schema_current.json`. Version-specific frozen files are not re-dumped by the guard — their role is to feed SchemaVerifier, which compares the LIVE schema-at-V1 against the frozen drift_schema_v1.json to prove migrations land back in the expected shape.

Blocker 4 (from the planner research): a naive `dart run drift_dev schema dump lib/.../app_database.dart drift_schemas/` (directory arg) would have overwritten `drift_schema_v1.json` with the current V2 shape the moment Task 2 landed, destroying the V1 fixture forever. The explicit-filename form + the frozen/rolling split prevents this.

## Handoff to 03-05 (DB factory + backup + migration test)

- `SchemaVerifier(GeneratedHelper())` is usable end-to-end: `.schemaAt(1)` returns a V1-shaped DB, `.schemaAt(2)` returns V2. The V1 identity fixture test (`test/infrastructure/db/v1_identity_fixture_test.dart`) demonstrates the full load path.
- `AppDatabase(executor, onBeforeUpgrade: backup.takeBackup)` is the injection point for `DbBackupService`. The hook signature is `Future<void> Function(OpeningDetails details)?`. `details.hadUpgrade` is pre-checked by AppDatabase so the backup callable can unconditionally snapshot.
- Pragmas are re-applied on every open (including post-backup reopens) — `DbBackupService` can close + copy + reopen without worrying about pragma state leakage.
- File-backed WAL verification: 03-05's production factory opens `<app_support>/mirkfall.db` through `drift_flutter.createInBackground(setup: ...)`, and the file-backed flavour of the pragma test asserts `journal_mode='wal'` (vs the in-memory `'memory'` we assert here).

## Handoff to 03-06 (Drift stores + Riverpod providers)

- `AppDatabase(QueryExecutor)` is the single entry point; store implementations (`lib/infrastructure/stores/*.dart`) take an `AppDatabase` reference through constructor injection.
- SESS-06: catch `SqliteException(extendedResultCode: 2067)` in `DriftSessionStore.activate` and wrap in `ConcurrentActivationException` (the domain exception shipped in 03-02). The schema test here proves the DB-layer exception is raised.
- MIRK-03: `DriftRevealedTileStore.mergeMask` reads the existing row, OR's the bitmap bytes in memory (via `mergeBitmap` from 03-02), writes back in a single UPDATE. The composite unique key is already enforced — duplicate-insert paths are unreachable when using Drift's companion-based UPSERT.
- Category delete (CONTEXT.md §cascade): `DriftMarkerCategoryStore.delete` runs in a transaction — first `UPDATE t_markers SET category_id = ? WHERE category_id = ?` with `kCategoryDefaultId.value`, then `DELETE FROM t_marker_categories WHERE id = ?`. The schema layer has NO cascade on `t_markers.category_id` — the store is the enforcer.
- When 03-06 lands its first `@riverpod` provider, re-evaluate the custom_lint silent-degradation decision. If `custom_lint` has shipped analyzer-^10 support by then, drop the plugin comment-out in `analysis_options.yaml`.

## Files Created/Modified

**Created (lib/, 6 files):**

- `lib/infrastructure/db/app_database.dart` — @DriftDatabase (6 tables, schemaVersion=2, migration strategy, onBeforeUpgrade hook)
- `lib/infrastructure/db/app_database.g.dart` — drift_dev codegen (6 table classes + 6 row data classes + companions + database class)
- `lib/infrastructure/db/pragma_setup.dart` — applyRuntimePragmas
- `lib/infrastructure/db/type_converters.dart` — UnixMsToDateTime + SessionStatusString + MirkStyleConfigJson
- `lib/infrastructure/db/migrations/v1_to_v2_notes.dart` — V1ToV2Notes.apply via customStatement
- `lib/infrastructure/db/README.md` — table layout + pragma order + migration workflow + onBeforeUpgrade contract

**Created (drift_schemas/, 3 files):**

- `drift_schemas/drift_schema_v1.json` — FROZEN V1 snapshot
- `drift_schemas/drift_schema_v2.json` — FROZEN V2 snapshot
- `drift_schemas/drift_schema_current.json` — ROLLING, matches V2

**Created (test/, 6 files):**

- `test/generated_migrations/schema.dart` — GeneratedHelper class (drift_dev auto)
- `test/generated_migrations/schema_v1.dart` — DatabaseAtV1 (drift_dev auto)
- `test/generated_migrations/schema_v2.dart` — DatabaseAtV2 (drift_dev auto)
- `test/infrastructure/db/app_database_pragma_test.dart` — 4 pragma assertions
- `test/infrastructure/db/app_database_schema_test.dart` — 7 tests (tables, SESS-06 index, SESS-06 enforcement, MIRK-03 enforcement, CASCADE, schemaVersion, notes column)
- `test/infrastructure/db/v1_identity_fixture_test.dart` — SC#1 identity (row counts) + schema sentinel

**Modified (preflight — scoped into chore(03-04) commit):**

- `pubspec.yaml` — 15 version bumps + drift_dev add + dependency_overrides block
- `pubspec.lock` — 17 packages changed (bumps + additions)
- `analysis_options.yaml` — custom_lint plugin activation commented out with re-enable hook
- `DEPENDENCIES.md` — 17 row updates + 4 new rows (drift_dev, sqlparser, recase, charcode)

**Modified (scoped into per-task commits):**

- `test/fixtures/db_seed/v1_baseline.sql` — Task 3: status='paused' -> 'stopped'
- `tool/check_headers.dart` — Task 2: exempt test/generated_migrations/ path
- `lib/presentation/router.g.dart` — Task 1 (codegen side-effect of dart_style 3.1.3 -> 3.1.7 reformat)

## Decisions Made

See frontmatter `key-decisions` for the full list. Key call-outs:

1. **Analyzer-<9 pin REVERSED.** Supersedes the 03-01 decision ("Held analyzer stack at <9.0 for Phase 01 — No compatible custom_lint + riverpod_lint + analyzer trio exists yet"). The `dependency_overrides: analyzer ^10.0.0` block forces the whole toolchain onto analyzer 10, unblocking drift_dev 2.32.1. `custom_lint` silently degrades until it ships an analyzer-^10 release — acceptable because no `@riverpod` targets exist yet. Re-evaluate when 03-06 adds its first provider.
2. **Raw customStatement over m.addColumn.** The migration file stays independent of AppDatabase; portable across Drift 2.x minor releases; trivially testable through SchemaVerifier.
3. **onBeforeUpgrade as constructor-injected hook.** Nullable (tests can skip), guarded by `details.hadUpgrade` (no first-open bogus backups), fires BEFORE onUpgrade (backup captures pre-migration state).
4. **Frozen vs rolling schema dumps.** Versioned JSON fixtures are immutable; only `drift_schema_current.json` is CI-guarded. Prevents Blocker 4 (accidentally trampling V1 fixture on V2 bump).
5. **In-memory journal_mode returns 'memory'.** SQLite fundamental — WAL requires an on-disk shared-memory region. Unit test accepts the observable; file-backed WAL verification is an integration-test concern for 03-05.
6. **Fixture SQL reconciliation.** 'paused' -> 'stopped' on sessions 04 and 07 (SessionStatus enum has only active|stopped). Forward-declared in 03-01-SUMMARY as 03-04's responsibility.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] drift_dev 2.32.1 requires analyzer ^10.0.0 but 03-01 pinned analyzer <9**
- **Found during:** Plan setup (would have blocked Task 1 build_runner run)
- **Issue:** 03-01 pinned the entire codegen toolchain at analyzer <9 to keep `custom_lint` 0.8.1 + `riverpod_lint` 3.1.0 usable. `drift_dev` 2.32.1's pubspec requires `analyzer: ^10.0.0 <13.0.0`, an irreconcilable version conflict.
- **Fix:** User-authorized reversal (prompt §user_decision). Preflight commit `e923558`: `dependency_overrides: analyzer: ^10.0.0` + `dart_style: 3.1.7`; bumped `build_runner`, `freezed`, `json_serializable`, `json_annotation`, `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `riverpod_lint` to analyzer-10-compatible versions where available; kept `custom_lint 0.8.1` (no newer release targets analyzer ^10) and commented out its plugin activation in analysis_options.yaml since it silently degrades.
- **Files modified:** `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `DEPENDENCIES.md`
- **Verification:** `flutter pub get` resolved cleanly; `flutter analyze` clean; 69-test pre-existing suite still green.
- **Committed in:** `e923558` (preflight — scoped to `chore(03-04):` per user direction)

**2. [Rule 3 - Blocking] build_runner 2.9.0 uses analyzer APIs removed in analyzer 10**
- **Found during:** First `dart run build_runner build` after the analyzer override landed
- **Issue:** `build_runner 2.9.0` imports `LibraryElement2`, `Element2`, `element2` getter, `MultiplyDefinedElement2`, `Fragment`, and `ErrorType.SYNTACTIC_ERROR` — all removed or renamed in analyzer 10. 75+ compile errors in `build_runner/lib/src/build/resolver/resolver.dart` alone.
- **Fix:** Bumped `build_runner: 2.9.0 -> 2.13.1` (supports analyzer >=8.0.0 <13.0.0).
- **Files modified:** `pubspec.yaml`, `pubspec.lock`, `DEPENDENCIES.md`
- **Committed in:** `e923558` (preflight — same commit as auto-fix #1)

**3. [Rule 3 - Blocking] dart_style 3.1.8 requires analyzer ^12 under the analyzer-10 override**
- **Found during:** Second `dart run build_runner` after the analyzer + build_runner bumps
- **Issue:** Resolver pulled `dart_style 3.1.8` (latest) as a transitive, but 3.1.8 requires `analyzer: ^12.0.0`, which the `analyzer: ^10.0.0` override forbids. 20+ compile errors in `dart_style/lib/src/short/source_visitor.dart` (`DottedName.tokens`, `BlockEnumBody`, `EmptyEnumBody`).
- **Fix:** Added `dart_style: 3.1.7` to `dependency_overrides` (3.1.7 supports analyzer >=10 <12 — the ceiling that respects the analyzer-10 constraint).
- **Files modified:** `pubspec.yaml`, `pubspec.lock`, `DEPENDENCIES.md`
- **Committed in:** `e923558` (preflight)

**4. [Rule 3 - Blocking] riverpod_lint 3.1.0 pins riverpod_analyzer_utils 1.0.0-dev.8; riverpod_generator 4.0.2+ requires 1.0.0-dev.9**
- **Found during:** `flutter pub get` version resolution (cascading conflict from auto-fix #1's bumps)
- **Issue:** Pinning `riverpod_generator: 4.0.3` (for the analyzer-10 chain) tried to pull `riverpod_analyzer_utils 1.0.0-dev.9`, but `riverpod_lint 3.1.0` pinned 1.0.0-dev.8. Cascading: bumping riverpod_lint to 3.1.3 pulled `riverpod 3.2.1`, which required `riverpod_annotation 4.0.2`, which required `flutter_riverpod 3.3.1`.
- **Fix:** Bumped the full riverpod chain to its latest compatible releases: `flutter_riverpod 3.1.0 -> 3.3.1`, `riverpod 3.1.0 -> 3.2.1`, `riverpod_annotation 4.0.0 -> 4.0.2`, `riverpod_lint 3.1.0 -> 3.1.3`. All five packages are riverpod-author maintained, zero-telemetry, MIT/Apache.
- **Files modified:** `pubspec.yaml`, `pubspec.lock`, `DEPENDENCIES.md`
- **Committed in:** `e923558` (preflight)

**5. [Rule 1 - Bug] Drift `check()` getter triggers `recursive_getters` lint false positive**
- **Found during:** Task 1 first `flutter analyze` after codegen
- **Issue:** `IntColumn get startedAtOffsetMinutes => integer().check(startedAtOffsetMinutes.isBetweenValues(-720, 840))()` — the Drift-documented pattern (`creationTime.isBiggerThan(Constant(...))` inside `creationTime`'s own body) triggers Dart's `recursive_getters` lint. Under `--fatal-infos`, this would fail CI.
- **Fix:** `// ignore: recursive_getters` comments on the two lines where the self-reference appears. Documented inline that Drift's build_runner rewrites the body so no runtime recursion occurs.
- **Files modified:** `lib/infrastructure/db/app_database.dart`
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` returns "No issues found!"; CHECK constraint is preserved in the Drift schema (verified in the V2 schema dump).
- **Committed in:** `58e5a07` (Task 1)

**6. [Rule 3 - Blocking] `.g.dart` part file references `MirkStyleConfig` / `SessionStatus` but `app_database.dart` never imports them directly**
- **Found during:** Task 3 test run (compile errors: "MirkStyleConfig isn't a type" in app_database.g.dart line 2414+)
- **Issue:** `type_converters.dart` imports `MirkStyleConfig` and `SessionStatus` internally, but the generated `app_database.g.dart` is `part of 'app_database.dart'` and cannot see imports from sibling files. The drift-generated code references both types directly (TypeConverter parameters + row data class fields).
- **Fix:** Added direct imports of both types in `app_database.dart`. `SessionStatus` carries `// ignore: unused_import` because the enclosing library doesn't use it directly — the part file does.
- **Files modified:** `lib/infrastructure/db/app_database.dart`
- **Verification:** `dart run build_runner build` clean; `dart test test/infrastructure/db/` green (13/13).
- **Committed in:** `90c2478` (Task 3 — where the test-run surfaced the issue)

**7. [Rule 3 - Blocking] Naive semicolon-split of v1_baseline.sql executes comment prose as SQL**
- **Found during:** Task 3 V1 identity fixture test first run
- **Issue:** My first statement-splitter filtered lines starting with `--` AFTER splitting on `;`. The fixture header contained `"'stopped'; partial unique index tolerates zero"` inside a multi-line comment. Splitting on `;` produced a fragment `partial unique index tolerates zero` that started without `--` (the comment prefix was on the previous line fragment) and SQLite tried to execute it.
- **Fix:** Strip line comments BEFORE splitting on `;` — replace any line whose `trimLeft()` starts with `--` with empty, then split + trim.
- **Files modified:** `test/infrastructure/db/v1_identity_fixture_test.dart`
- **Verification:** V1 identity test passes; row counts match (10/50/5/3/2).
- **Committed in:** `90c2478` (Task 3)

**8. [Rule 1 - Bug] In-memory SQLite ignores `PRAGMA journal_mode=WAL`**
- **Found during:** Task 3 pragma test first run
- **Issue:** Test asserted `journal_mode == 'wal'` but actual value returned was `'memory'`. SQLite in-memory databases cannot use WAL — WAL requires an on-disk shared-memory region (sqlite.org/wal.html §2.1). The `setup:` hook still fires, but the raw `PRAGMA journal_mode=WAL` is silently ignored for in-memory backends.
- **Fix:** Updated the test to expect `'memory'` for in-memory DBs. Inline documentation explains why and forward-declares the file-backed assertion for 03-05.
- **Files modified:** `test/infrastructure/db/app_database_pragma_test.dart`
- **Verification:** All 4 pragma tests pass.
- **Committed in:** `90c2478` (Task 3)

**9. [Rule 2 - Missing] test/generated_migrations/ files lack GOSL header**
- **Found during:** Task 2 post-codegen `tool/check_headers.dart` run
- **Issue:** `drift_dev schema generate` produces `schema.dart`, `schema_v1.dart`, `schema_v2.dart` WITHOUT the GOSL header; `check_headers.dart` only excluded `.g.dart`/`.freezed.dart`/etc. suffixes, so the three generated files tripped the header gate.
- **Fix:** Added an exclusion regex `r'[/\\]generated_migrations[/\\]'` to `tool/check_headers.dart` — same rationale as the suffix exclusions (produced by codegen, not hand-written).
- **Files modified:** `tool/check_headers.dart`
- **Verification:** `dart run tool/check_headers.dart` returns "OK (78 files)"; `dart test tool/test/` green (22/22 — confirms the pattern didn't break existing exemptions).
- **Committed in:** `314b4b4` (Task 2)

**10. [Rule 2 - Missing] Unnecessary `package:sqlite3` import triggers `depend_on_referenced_packages`**
- **Found during:** Task 3 post-test `flutter analyze`
- **Issue:** `app_database_schema_test.dart` imported `SqliteException` from `package:sqlite3/sqlite3.dart`; but `sqlite3` is not a direct dependency (it's transitive through drift). `depend_on_referenced_packages` + `unnecessary_import` both fired.
- **Fix:** Consume `SqliteException` through `package:drift/native.dart` (re-export) so the test file stays within direct + Drift-transitive imports only.
- **Files modified:** `test/infrastructure/db/app_database_schema_test.dart`
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` returns "No issues found!".
- **Committed in:** `90c2478` (Task 3 — where the analyze surfaced the issue)

---

**Total deviations:** 10 auto-fixed (2 bugs, 2 missing, 6 blocking).
**Impact on plan:** All ten were caught at verification time and resolved within the same task commit (or in the preflight commit for the four toolchain-level blockers). No scope creep — every fix was a necessary adaptation to the analyzer-10 toolchain (four preflight fixes), a drift_dev codegen quirk (one fix), or a pre-existing fixture drift the planner had explicitly forward-declared for 03-04 to resolve (one fix). The most consequential is the analyzer-10 override — it's the keystone that unblocks every downstream Drift plan.

## Authentication Gates

None — no external services touched.

## User Setup Required

None — all toolchain bumps are pub.dev-hosted, zero env vars added.

## Issues Encountered

None beyond the auto-fixes. The preflight commit's four toolchain reconciliations were all caught by `flutter pub get` + `dart run build_runner` feedback loops within a few iterations; no silent failures, no test flakes, no runtime surprises.

## Next Phase Readiness

**Wave 4 opens.** With 03-04 closed:

- **03-05** (DB factory + backup + migration test) unblocks entirely. It gets:
  - `SchemaVerifier(GeneratedHelper())` → V1 & V2 instantiation already proven.
  - `AppDatabase(executor, onBeforeUpgrade: hook)` constructor contract fixed.
  - Pragma wiring split (`setup:` for first-open WAL + `beforeOpen` for runtime pragmas) already in place.
  - The three committed schema artifacts (`drift_schema_v{1,2,current}.json`) feed the CI diff guard from 03-01.
- **03-06** (Drift stores + Riverpod providers) unblocks in parallel with 03-05. It gets:
  - All 6 Drift tables + Row data classes + companion classes ready to `SELECT` / `INSERT` / `UPDATE`.
  - FK+CASCADE policy already in schema — stores do NOT manually cascade.
  - SESS-06 raises SqliteException 2067 from the DB layer — stores catch and wrap in `ConcurrentActivationException`.
  - MIRK-03 composite unique key enforces idempotence — `mergeMask` becomes a `SELECT-OR-INSERT-OR-UPDATE` flow.

Forward-declarations to honour:

- 03-05 must add the analyzer-^10-aware file-backed WAL pragma integration test (asserting `journal_mode='wal'` on a real file, which in-memory cannot prove).
- 03-06 must re-evaluate the `custom_lint` silent-degradation when it lands its first `@riverpod` provider. If `custom_lint` ships analyzer-^10 support, re-enable the `plugins: [custom_lint]` block in `analysis_options.yaml` and drop the `dependency_overrides: analyzer` if it's no longer needed for the whole stack.

---
*Phase: 03-persistence-domain-models*
*Completed: 2026-04-18*

## Self-Check: PASSED

All 16 listed files exist on disk, and all 4 task commit hashes (`e923558`, `58e5a07`, `314b4b4`, `90c2478`) are reachable from `git log --all`.
