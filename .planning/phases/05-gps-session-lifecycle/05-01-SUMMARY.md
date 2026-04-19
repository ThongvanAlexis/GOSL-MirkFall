---
phase: 05-gps-session-lifecycle
plan: 01
subsystem: database
tags: [drift, freezed, riverpod, sqlite, migrations, gps, fix-entity, wave-0, tdd]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: "AppDatabase schemaVersion=2, Session/Marker/RevealedTile/MirkStyle/Photo Drift tables, migration framework (SchemaVerifier, SchemaSanityChecker, DbBackupService), JsonMigrator + V1ToV2RenameRadius, extension-type IDs (SessionId/MarkerId/...), Freezed @Assert pattern, Riverpod @keepAlive store providers"
  - phase: 04-review-gate-persistence
    provides: "DB CHECK constraints on offset columns, SqliteException 2067 wrap scope locked, v1_baseline.sql fixture + drift_schema_v{1,2}.json dumps, main.dart runZonedGuarded bootstrap"
provides:
  - "Fix Freezed entity with @Assert invariants (lat [-90,90], lon [-180,180], accuracy >= 0, offset [-720,+840])"
  - "FixId extension type (prefix fix_, parse factory, isValid getter)"
  - "FixStore port (insert/list/watch/count/deleteAll by session)"
  - "LocationStream abstract port stub (signature only; impl Plan 05-03)"
  - "DriftFixStore impl backed by t_fixes table, FK CASCADE verified"
  - "AppDatabase schemaVersion=3 + Fixes Drift table + V2ToV3Fixes migration"
  - "Frozen drift_schema_v3.json (production + test fixture) + generated schema_v3.dart"
  - "SessionStore.watchAll() stream extension (emits on t_sessions row change)"
  - "fixStoreProvider Riverpod keepAlive provider"
  - "V2ToV3Fixes JsonMigration identity step (framework completeness)"
  - "5 Phase 05 constants in lib/config/constants.dart"
  - "23 Wave-0 test files + 2 reusable fake helpers (Nyquist-compliant scaffolding)"
affects: [05-02-gps-infrastructure, 05-03-permissions, 05-04-ui-settings, 05-05-session-ui, 05-06-store-review-poc]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "V2→V3 Drift migration: m.createTable(db.fixes) + explicit createIndex for @TableIndex.sql-declared indexes (Drift 2.32.1 does NOT auto-emit indexes via createTable — Pitfall #7)"
    - "Wave-0 Nyquist scaffolding: every test file downstream plans need exists on disk before any downstream task runs — RED stubs for same-plan targets, skip-marked stubs (with named downstream plan) for later-plan targets"
    - "DriftFixStore follows Phase 03 Markers convention: NO SqliteException wrapping on insert (duplicate-id is an infrastructure bug, not a domain contract break)"
    - "SessionStore.watchAll() via Drift select().watch() — first emission carries snapshot, downstream emissions on row change, ordered by startedAtUtc DESC"
    - "Hoist // ignore: recursive_getters to file-level ignore_for_file — dart format 3.x reflows .check(column.expr) across multiple lines, moving diagnostic origin away from narrow // ignore: placement"

key-files:
  created:
    - "lib/domain/fixes/fix.dart"
    - "lib/domain/fixes/fix_store.dart"
    - "lib/domain/fixes/README.md"
    - "lib/domain/ids/fix_id.dart"
    - "lib/domain/gps/location_stream.dart"
    - "lib/domain/envelope/v2_to_v3_fixes.dart"
    - "lib/infrastructure/db/migrations/v2_to_v3_fixes.dart"
    - "lib/infrastructure/stores/drift_fix_store.dart"
    - "lib/application/providers/fix_store_provider.dart"
    - "drift_schemas/drift_schema_v3.json"
    - "test/fixtures/drift_schemas/drift_schema_v3.json"
    - "test/fixtures/json/v2_to_v3_envelope.json"
    - "test/generated_migrations/schema_v3.dart"
    - "test/helpers/fake_location_stream.dart"
    - "test/helpers/in_memory_shared_preferences.dart"
    - "test/domain/fix_invariants_test.dart"
    - "test/domain/json_migrator_v2_to_v3_test.dart"
    - "test/infrastructure/db/v2_to_v3_migration_test.dart"
    - "test/infrastructure/stores/drift_fix_store_test.dart"
    - "test/infrastructure/stores/drift_session_store_rename_test.dart"
    - "test/infrastructure/stores/drift_session_store_stress_test.dart"
    - "test/application/controllers/active_session_controller_test.dart (skip-stub)"
    - "test/application/permissions/location_permission_flow_test.dart (skip-stub)"
    - "test/infrastructure/gps/location_settings_factory_test.dart (skip-stub)"
    - "test/infrastructure/gps/geolocator_location_stream_test.dart (skip-stub)"
    - "test/infrastructure/notifications/session_notification_service_test.dart (skip-stub)"
    - "test/infrastructure/platform/oem_detector_test.dart (skip-stub)"
    - "test/infrastructure/platform/boot_completed_watchdog_test.dart (skip-stub)"
    - "test/presentation/screens/session_list_screen_test.dart (skip-stub)"
    - "test/presentation/screens/session_detail_screen_test.dart (skip-stub)"
    - "test/presentation/screens/permission_rationale_screen_test.dart (skip-stub)"
    - "test/presentation/screens/permission_denied_screen_test.dart (skip-stub)"
    - "test/presentation/screens/oem_guidance_screen_test.dart (skip-stub)"
    - "test/presentation/screens/settings_screen_test.dart (skip-stub)"
    - "tool/test/store_rationale_exists_test.dart (skip-stub)"
    - "tool/test/info_plist_final_copy_test.dart (skip-stub)"
  modified:
    - "lib/infrastructure/db/app_database.dart (Fixes table + schemaVersion=3 + onUpgrade chain + file-level ignore_for_file: recursive_getters)"
    - "lib/infrastructure/stores/drift_session_store.dart (watchAll() impl)"
    - "lib/domain/sessions/session_store.dart (watchAll() port addition)"
    - "lib/domain/ids/id_json_converters.dart (fixId converters appended)"
    - "lib/domain/envelope/README.md (V2ToV3Fixes entry)"
    - "lib/config/constants.dart (5 Phase 05 constants)"
    - "test/infrastructure/db/backup_on_upgrade_test.dart (filename assertion relaxed to match current schemaVersion)"
    - "test/infrastructure/db/app_database_schema_test.dart (schemaVersion assertion 2 -> 3)"

key-decisions:
  - "Drift V2 to V3 migration: generator-native m.createTable(db.fixes) + explicit createIndex for each @TableIndex.sql-declared index. Drift 2.32.1 does NOT auto-emit indexes via createTable (Pitfall #7); separate createIndex calls required."
  - "V2ToV3Fixes JsonMigration is an identity step — DB adds t_fixes in Phase 05, but the export-payload shape for fixes is Phase 13 scope (SCHEMA.md finalization). Keeps the JsonMigrator chain complete and additive."
  - "V2 to V3 migration test uses direct sqlite_master probes (not SchemaVerifier.migrateAndValidate) — regenerating schema_v1.dart/schema_v2.dart via drift_dev exposes a pre-existing divergence between frozen drift_schema_v{1,2}.json (CHECK constraints present) and the stale helpers they were generated from (CHECK constraints absent). V1 to V2 test keeps the stale helpers for backward-compat; V2 to V3 test mirrors that decision by NOT using migrateAndValidate (would compare new V3 helper against stale V2 shape)."
  - "DriftFixStore does NOT wrap SqliteException — duplicate FixId is an infrastructure bug (ID generator must produce uniques), matches Phase 03 Markers convention. Only SessionStore wraps 2067 because partial-unique-index violation IS a domain concept (ConcurrentActivationException)."
  - "FixStore.deleteAllForSession is idempotent — second call on an empty session is a no-op, documented in port contract."
  - "SessionStore.watchAll() resolves 05-RESEARCH Open Question #5 — single consumer planned (SessionListScreen in Plan 05-05), Phase 11 and Phase 13 will reuse."
  - "LocationStream.positions takes Object sessionId (not SessionId) — keeps the port minimal, avoids a lateral peer-domain import from sessions/ into gps/. Plan 05-03 can tighten to SessionId in the concrete impl if desired."
  - "Hoist // ignore: recursive_getters to file-level ignore_for_file in app_database.dart — dart format 3.x reflows .check(column.expr) across multiple lines, which moves the diagnostic origin line away from any narrow // ignore: placement and generates new analyzer warnings on every format pass. File-scope ignore is stable across format reflows."

patterns-established:
  - "Wave-0 scaffolding: 23 test files + 2 fake helpers created up front so downstream tasks never hit MISSING verify under Nyquist sampling"
  - "Drift migration test shape: direct sqlite_master probes + row-count assertions, NOT SchemaVerifier.migrateAndValidate, when schema_vN.dart generated helpers are stale relative to the current @Assert/CHECK shape of the code"
  - "FixStore insert-path error policy: raw SqliteException propagates on duplicate-id; no domain wrapping (matches Phase 03 Markers)"
  - "SessionStore.watchAll() contract: first emission = current snapshot, downstream = on row change, ordering startedAtUtc DESC (same as listAll)"

requirements-completed:
  - SESS-01
  - SESS-02
  - SESS-03
  - SESS-07
  - SESS-08
  - SESS-09

# Metrics
duration: "~26 min"
completed: 2026-04-19
---

# Phase 05 Plan 01: Wave-0 Foundation + Fixes Persistence Summary

**t_fixes Drift table + Fix Freezed entity with @Assert invariants + FixStore port/impl + 23 Wave-0 test scaffolds + SessionStore.watchAll() — the complete persistence foundation Phase 05 downstream plans (02-06) build on.**

## Performance

- **Duration:** ~26 min
- **Started:** 2026-04-19T09:09:07Z
- **Completed:** 2026-04-19T09:34:52Z
- **Tasks:** 4
- **Files created:** 38
- **Files modified:** 8 (+ 12 regenerated .g.dart from build_runner)

## Accomplishments

- **23 Wave-0 test files landed** — 5 become GREEN this plan (fix_invariants, drift_fix_store, drift_session_store_rename, drift_session_store_stress, v2_to_v3_migration), 18 remain skip-marked stubs with downstream plan references (05-02 through 05-06). Zero MISSING verify targets for the rest of Phase 05.
- **Fix domain entity** with 4 @Assert invariants mirroring the DB CHECK constraints — a Fix that violates lat/lon/accuracy/offset bounds cannot reach the store, so any CHECK-violation SqliteException is provably an infrastructure bug.
- **DriftFixStore persistence** — insert / listBySession / watchBySession / countBySession / deleteAllForSession against `t_fixes`. FK CASCADE verified end-to-end (session delete removes fixes).
- **SessionStore.watchAll()** stream extension — closes 05-RESEARCH Open Question #5, unblocks SessionListScreen in Plan 05-05.
- **AppDatabase schemaVersion=3** with the V2 to V3 migration chained after V1 to V2 in onUpgrade. Frozen `drift_schema_v3.json` dump (byte-identical copy in `test/fixtures/`). SessionStore exclusivity / error-mapping / cascade tests from Phase 03 all still green — zero regression.
- **JsonMigrator V2 to V3 identity step** — keeps the versioned-envelope chain complete for Phase 13's fixes-export shape.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold 23 Wave-0 test files + 2 helpers + LocationStream port** — `edb429d` (test)
2. **Task 2: Fix entity + FixId + FixStore port + id_json_converters + constants + V2ToV3 JsonMigration** — `f462cf3` (feat)
3. **Task 3: AppDatabase schemaVersion 3 + Fixes Drift table + V2ToV3Fixes migration + frozen schema dump** — `6b9fa1b` (feat)
4. **Task 4: DriftFixStore + DriftSessionStore.watchAll + rename/stress green + fixStoreProvider** — `f28bf3d` (feat)

## Files Created/Modified

### Created

**Domain:**
- `lib/domain/fixes/fix.dart` — Freezed Fix entity with 4 @Assert invariants
- `lib/domain/fixes/fix_store.dart` — FixStore port (insert + list/watch/count/deleteAll by session)
- `lib/domain/fixes/README.md` — layer import rules + invariants + wire shape
- `lib/domain/ids/fix_id.dart` — FixId extension type (prefix `fix_`, parse factory, isValid)
- `lib/domain/gps/location_stream.dart` — abstract LocationStream port stub (impl Plan 05-03)
- `lib/domain/envelope/v2_to_v3_fixes.dart` — V2ToV3Fixes JsonMigration identity step

**Infrastructure:**
- `lib/infrastructure/db/migrations/v2_to_v3_fixes.dart` — `m.createTable(db.fixes)` + 2× `createIndex`
- `lib/infrastructure/stores/drift_fix_store.dart` — DriftFixStore impl backed by t_fixes

**Application:**
- `lib/application/providers/fix_store_provider.dart` — Riverpod @keepAlive FixStore

**Schema / fixtures:**
- `drift_schemas/drift_schema_v3.json` — production-path V3 dump
- `test/fixtures/drift_schemas/drift_schema_v3.json` — byte-identical fixture copy
- `test/fixtures/json/v2_to_v3_envelope.json` — minimal V2 session envelope
- `test/generated_migrations/schema_v3.dart` — drift_dev-generated V3 helper

**Tests (23 Wave-0 files):**
- Pure-Dart: `test/domain/fix_invariants_test.dart` (GREEN), `test/domain/json_migrator_v2_to_v3_test.dart` (GREEN)
- Infrastructure GREEN this plan: `test/infrastructure/db/v2_to_v3_migration_test.dart`, `test/infrastructure/stores/drift_fix_store_test.dart`, `test/infrastructure/stores/drift_session_store_rename_test.dart`, `test/infrastructure/stores/drift_session_store_stress_test.dart`
- Skip-stubs (turn GREEN in named downstream plan):
  - Plan 05-02 targets: `active_session_controller_test.dart`, `location_permission_flow_test.dart`, `location_settings_factory_test.dart`, `geolocator_location_stream_test.dart`, `session_notification_service_test.dart`, `oem_detector_test.dart`
  - Plan 05-03 targets: `permission_rationale_screen_test.dart`, `permission_denied_screen_test.dart`
  - Plan 05-04 targets: `oem_guidance_screen_test.dart`, `settings_screen_test.dart`, `session_detail_screen_test.dart` (end-to-end UI), `active_session_controller_test.dart` (SESS-05 end-to-end)
  - Plan 05-05 targets: `session_list_screen_test.dart`, `session_detail_screen_test.dart` (skeleton), `boot_completed_watchdog_test.dart`
  - Plan 05-06 targets: `tool/test/store_rationale_exists_test.dart` (QUAL-03), `tool/test/info_plist_final_copy_test.dart` (QUAL-04)

**Helpers:**
- `test/helpers/fake_location_stream.dart` — reusable FakeLocationStream
- `test/helpers/in_memory_shared_preferences.dart` — primeSharedPreferences wrapper

### Modified

- `lib/infrastructure/db/app_database.dart` — added Fixes table declaration, schemaVersion 2→3, V2ToV3Fixes chained after V1ToV2Notes; hoisted `// ignore: recursive_getters` to file-level `ignore_for_file` directive (stable across dart format reflows)
- `lib/infrastructure/stores/drift_session_store.dart` — `watchAll()` impl via Drift `select().watch()`
- `lib/domain/sessions/session_store.dart` — `watchAll()` port addition (resolves Open Question #5)
- `lib/domain/ids/id_json_converters.dart` — appended `fixIdFromJson` / `fixIdToJson`
- `lib/domain/envelope/README.md` — added V2ToV3Fixes row to the files table
- `lib/config/constants.dart` — 5 Phase 05 constants (kDefaultDistanceFilterMeters=5, kMaxAcceptableAccuracyMeters=50.0, kFirstFixTimeoutSeconds=30, kNotificationChannelId, kSessionActiveBannerHeightDp=40.0)
- `test/infrastructure/db/backup_on_upgrade_test.dart` — filename prefix assertion relaxed from `backup-v1-to-v2-` to `backup-v1-to-v` (task-caused: schemaVersion is now 3)
- `test/infrastructure/db/app_database_schema_test.dart` — `expect(db.schemaVersion, 2)` → `3` (task-caused)
- `test/infrastructure/gps/geolocator_location_stream_test.dart` — swapped `flutter_test` for `package:test` (stub sits in the pure-Dart suite dir)
- `test/generated_migrations/schema_v3.dart` — added `strict_raw_type` to the generated-file ignore list (Drift 2.32.1 emits raw TableInfo; V1/V2 helpers used typed TableInfo)
- 12 regenerated `.g.dart` / `.freezed.dart` files across providers, markers, mirk, sessions, app_database, router (build_runner output stability drift; cleaned up while regeneration was required for Task 2/3/4 work)
- Project-wide `dart format --line-length 160` applied across 175 files to match CI gate (`.github/workflows/ci.yml` job `gates`)

## Decisions Made

Eight architectural decisions captured in the frontmatter `key-decisions` field above. Highlights:

1. **Drift V2 to V3 migration via `m.createTable + m.createIndex`** — Drift 2.32.1 does NOT auto-emit `@TableIndex.sql`-declared indexes via `createTable`; separate `createIndex` calls are required. Confirmed by failing SchemaVerifier output pre-fix, then passing post-fix.

2. **V2 to V3 migration test uses direct `sqlite_master` probes** — NOT `SchemaVerifier.migrateAndValidate`. The frozen `drift_schema_v{1,2}.json` dumps carry CHECK constraints added in Phase 04, but the committed `schema_v{1,2}.dart` helpers (generated pre-Phase-04 CHECK additions) do not. Regenerating them would break the V1 to V2 migration test too. Keeping the stale helpers + direct-query validation is the Phase 03 V1 to V2 precedent, now extended.

3. **DriftFixStore no SqliteException wrapping on insert** — matches Phase 03 Markers convention. A duplicate `FixId` is an infrastructure bug (ID generator must produce uniques), NOT a domain concept like SessionStore's `ConcurrentActivationException`.

4. **V2ToV3Fixes JsonMigration = identity step** — Phase 05 adds `t_fixes` at the DB layer but fix export-payload shape is Phase 13 SCHEMA.md scope. Chain stays complete and additive.

5. **LocationStream takes `Object sessionId`** — not `SessionId`. Keeps the port minimal and avoids a lateral peer-domain import chain from `sessions/` into `gps/`. Plan 05-03 can tighten to `SessionId` in the concrete impl.

6. **File-level `ignore_for_file: recursive_getters`** in `app_database.dart` — dart format 3.x reflows `.check(column.expr)` calls across multiple lines, moving the diagnostic origin line away from any narrow `// ignore:` placement and generating new analyzer warnings on every format pass. File-scope ignore is stable.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Drift generated table accessor is `fixes`, not `tFixes`**
- **Found during:** Task 3 (V2ToV3Fixes.apply)
- **Issue:** Plan's code snippet used `m.database.tFixes`; Drift's camelCase accessor derived from the class name `Fixes` is `fixes` (the `t_` prefix only appears in `@override get tableName`).
- **Fix:** Cast `m.database as AppDatabase` and call `db.fixes` + added a comment documenting the naming rule.
- **Files modified:** `lib/infrastructure/db/migrations/v2_to_v3_fixes.dart`
- **Verification:** Migration test green on second run.
- **Committed in:** `6b9fa1b`

**2. [Rule 3 - Blocking] @TableIndex.sql indexes NOT auto-emitted by Drift 2.32.1 `createTable`**
- **Found during:** Task 3 (first SchemaVerifier run)
- **Issue:** SchemaVerifier complained `idx_t_fixes_session_id` / `idx_t_fixes_session_recorded_at` missing from runtime schema — `m.createTable(db.fixes)` creates the table but doesn't emit the `@TableIndex.sql` index SQL. Pitfall #7 from 05-RESEARCH.md.
- **Fix:** Added explicit `await m.createIndex(db.idxTFixesSessionId)` + `db.idxTFixesSessionRecordedAt` after `createTable`.
- **Files modified:** `lib/infrastructure/db/migrations/v2_to_v3_fixes.dart`
- **Verification:** Migration test + `sqlite_master` probe both green.
- **Committed in:** `6b9fa1b`

**3. [Rule 1 - Bug] backup_on_upgrade_test filename assertion hardcoded to `v1-to-v2`**
- **Found during:** Task 3 (post-schemaVersion-bump test run)
- **Issue:** Task-caused regression — `backup_on_upgrade_test.dart:85` asserted `startsWith('mirkfall.db.backup-v1-to-v2-')`; schemaVersion bump to 3 produces `v1-to-v3-...` filenames.
- **Fix:** Relaxed to `startsWith('mirkfall.db.backup-v1-to-v')` + a comment documenting the future-proofing rationale.
- **Files modified:** `test/infrastructure/db/backup_on_upgrade_test.dart`
- **Verification:** 3/3 backup tests green.
- **Committed in:** `6b9fa1b`

**4. [Rule 1 - Bug] app_database_schema_test.dart schemaVersion assertion stale**
- **Found during:** Task 3 (post-schemaVersion-bump test run)
- **Issue:** `expect(db.schemaVersion, 2)` — task-caused regression after schemaVersion 2 → 3 bump.
- **Fix:** Updated assertion + test title.
- **Files modified:** `test/infrastructure/db/app_database_schema_test.dart`
- **Verification:** Test green.
- **Committed in:** `6b9fa1b`

**5. [Rule 1 - Bug] geolocator_location_stream_test stub used flutter_test in pure-Dart dir**
- **Found during:** Task 3 (full dart test run)
- **Issue:** My Task 1 stub for `test/infrastructure/gps/geolocator_location_stream_test.dart` imported `flutter_test` — but that directory runs under `dart test` (pure-Dart suite), which can't load `flutter_test` (pulls in Flutter SDK framework symbols).
- **Fix:** Swapped import to `package:test/test.dart`.
- **Files modified:** `test/infrastructure/gps/geolocator_location_stream_test.dart`
- **Verification:** Test file loads as skipped stub under both `dart test` and `flutter test`.
- **Committed in:** `6b9fa1b`

**6. [Rule 3 - Blocking] `strict_raw_type` warnings on generated schema_v3.dart**
- **Found during:** Task 4 (flutter analyze --fatal-infos --fatal-warnings)
- **Issue:** Drift 2.32.1 codegen emits raw `TableInfo` instead of typed `TableInfo<TSessions, TSessionsData>` in the generated V3 helper (V1/V2 helpers from older drift_dev versions used typed TableInfo). Flutter analyze's `strict_raw_types` lint flagged 7 warnings. CI gate `flutter analyze --fatal-infos --fatal-warnings` would fail.
- **Fix:** Added `strict_raw_type` to the generated-file `// ignore_for_file: type=lint,unused_import` directive.
- **Files modified:** `test/generated_migrations/schema_v3.dart`
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` → No issues found.
- **Committed in:** `f28bf3d`

**7. [Rule 3 - Blocking] Project-wide `dart format --line-length 160` drift**
- **Found during:** Task 4 (post-format CI-equivalent check)
- **Issue:** CI runs `dart format --line-length 160 --set-exit-if-changed .`; the repo had 41 files of pre-existing format drift from `dart_style` version churn (mostly Phase 03+ files unrelated to this plan). My Task 2/3/4 changes that regenerated `.g.dart` files + my new Task 1 files produced extra drift on top of that.
- **Fix:** Ran `dart format --line-length 160 .` project-wide. No semantic changes — only whitespace.
- **Files modified:** 175 files formatted, 41 changed (pre-existing drift) + my new/modified files aligned.
- **Verification:** `dart format --line-length 160 --set-exit-if-changed .` → clean.
- **Committed in:** `f28bf3d`

**8. [Rule 3 - Blocking] `recursive_getters` analyzer infos from hoisted `// ignore:` placement**
- **Found during:** Task 4 (dart analyze post-format)
- **Issue:** `dart format` reflowed `.check(column.expr)` calls across multiple lines, moving the diagnostic origin line away from the narrow `// ignore: recursive_getters` comments. Analyzer flagged 8 new `recursive_getters` infos on Phase 03 code that previously analyzed clean.
- **Fix:** Hoisted to file-level `// ignore_for_file: recursive_getters` at the top of `app_database.dart` with a block comment explaining the stability-across-format rationale. Removed all narrow `// ignore: recursive_getters` comments (kept the `// Finding #NN (Batch X) — ...` comments for Phase 03 rationale preservation).
- **Files modified:** `lib/infrastructure/db/app_database.dart`
- **Verification:** `dart analyze lib/` + `flutter analyze --fatal-infos --fatal-warnings` both clean.
- **Committed in:** `f28bf3d`

---

**Total deviations:** 8 auto-fixed (5 × Rule 3 blocking, 3 × Rule 1 bugs).

**Impact on plan:** All 8 fixes were necessary for correctness and CI-gate compliance. Seven are mechanical (generator-accessor naming, index emission, format/analyzer cascade from `dart_style` version drift, test assertions stale after schemaVersion bump). One (#2, `@TableIndex.sql` indexes not auto-emitted by `createTable`) was explicitly flagged by 05-RESEARCH.md Pitfall #7 but the plan's code sample only used `createTable` — the research warning was not followed into the plan text. No scope creep.

## Issues Encountered

- **Frozen V1/V2 schema dumps diverge from their own generated helpers.** `drift_schemas/drift_schema_v{1,2}.json` carry CHECK constraints added during Phase 04 (offset columns, status column, bitmap length). The committed `test/generated_migrations/schema_v{1,2}.dart` were generated BEFORE those CHECK additions. Regenerating via `drift_dev schema generate` would bring them in sync with the JSON dumps but would also break the existing V1 to V2 migration test (which relies on the stale helpers + the fact that V1 to V2 migration doesn't ADD the CHECK to pre-existing columns). The Phase 03 V1 to V2 test chose to keep stale helpers + direct-query validation; Plan 05-01 Task 3 carries that decision forward for V2 to V3 (direct `sqlite_master` probes, no `SchemaVerifier.migrateAndValidate`). Documented in `lib/infrastructure/db/migrations/v2_to_v3_fixes.dart` + `test/infrastructure/db/v2_to_v3_migration_test.dart` docstrings. A proper fix would be a separate plan: "align schema_v{1,2}.dart with frozen JSON + author a V1 to V2 `ALTER TABLE ADD CHECK` migration to actually enforce the constraints on upgraded databases" — out of scope for 05-01.

## User Setup Required

None - no external service configuration required. The plan lands pure-Dart domain + Drift + Riverpod infrastructure only; no new native permissions, platform channels, or third-party accounts.

## Handoff Notes for Downstream Plans

### Plan 05-02 (GPS Infrastructure)

Wave-0 stubs this plan will turn GREEN:
- `test/infrastructure/gps/location_settings_factory_test.dart` (GPS-05)
- `test/infrastructure/gps/geolocator_location_stream_test.dart` (GPS-02 infra)
- `test/infrastructure/notifications/session_notification_service_test.dart` (GPS-04)
- `test/infrastructure/platform/oem_detector_test.dart` (GPS-08 detection)
- `test/application/controllers/active_session_controller_test.dart` (GPS-02 orchestration, SESS-04, SESS-05)
- `test/application/permissions/location_permission_flow_test.dart` (GPS-01)

Concrete seams needed:
- `GeolocatorLocationStream implements LocationStream` — LocationStream port already landed.
- `LocationSettingsFactory` — returns `AndroidSettings` with `foregroundNotificationConfig` on Android, `AppleSettings` with `allowBackgroundLocationUpdates` on iOS. See 05-RESEARCH.md §Pattern 1.
- `OemDetector` — use `device_info_plus` (not yet pinned — audit required in Plan 05-02). See 05-RESEARCH.md §Code Examples for the lowercase-match regex table.
- `SessionNotificationService` — wraps `flutter_local_notifications` 21.0.0 with channel id `kNotificationChannelId` (already in `lib/config/constants.dart`).

### Plan 05-03 (Permission Flow UI)

Wave-0 stubs this plan will turn GREEN:
- `test/presentation/screens/permission_rationale_screen_test.dart` (GPS-01 pre-prompt)
- `test/presentation/screens/permission_denied_screen_test.dart` (GPS-07)

### Plan 05-04 (Settings + End-to-end UI)

Wave-0 stubs this plan will turn GREEN:
- `test/presentation/screens/oem_guidance_screen_test.dart` (GPS-08 UI)
- `test/presentation/screens/settings_screen_test.dart` (OPT-02 partial)
- `test/presentation/screens/session_detail_screen_test.dart` (end-to-end via SESS-05)

### Plan 05-05 (Session UI)

Wave-0 stubs this plan will turn GREEN:
- `test/presentation/screens/session_list_screen_test.dart` (SESS-01 / SESS-08)
- `test/presentation/screens/session_detail_screen_test.dart` (SESS-03 skeleton)
- `test/infrastructure/platform/boot_completed_watchdog_test.dart` (GPS-06)

### Plan 05-06 (Store Review + POC)

Wave-0 stubs this plan will turn GREEN:
- `tool/test/store_rationale_exists_test.dart` (QUAL-03)
- `tool/test/info_plist_final_copy_test.dart` (QUAL-04)

## Next Phase Readiness

- **Domain + persistence complete.** `Fix` entity, `FixStore` port + impl, `t_fixes` table, FK CASCADE, JsonMigrator V2 to V3, Riverpod provider — all green.
- **Wave-0 scaffolding complete.** All 23 Wave-0 test files exist; downstream plans cannot hit MISSING verify.
- **`SessionStore.watchAll()`** available for SessionListScreen in Plan 05-05.
- **5 Phase 05 constants** reusable across downstream plans (`kDefaultDistanceFilterMeters`, `kMaxAcceptableAccuracyMeters`, `kFirstFixTimeoutSeconds`, `kNotificationChannelId`, `kSessionActiveBannerHeightDp`).
- **FixStore.insert contract** documented: throws raw `SqliteException` on duplicate id; no domain wrapping. ActiveSessionController (Plan 05-02) must pre-allocate a fresh `FixId` per accepted fix via the existing `IdGenerator`.
- **Known debt:** V1/V2 frozen schema helpers diverge from their own JSON dumps (Phase 04 CHECK constraints never propagated to the generated helpers). Not blocking 05-02..05-06; would be its own plan.

---
*Phase: 05-gps-session-lifecycle*
*Completed: 2026-04-19*

## Self-Check: PASSED

- lib/domain/fixes/fix.dart: FOUND
- lib/domain/fixes/fix_store.dart: FOUND
- lib/domain/fixes/README.md: FOUND
- lib/domain/ids/fix_id.dart: FOUND
- lib/domain/gps/location_stream.dart: FOUND
- lib/domain/envelope/v2_to_v3_fixes.dart: FOUND
- lib/infrastructure/db/migrations/v2_to_v3_fixes.dart: FOUND
- lib/infrastructure/stores/drift_fix_store.dart: FOUND
- lib/application/providers/fix_store_provider.dart: FOUND
- drift_schemas/drift_schema_v3.json: FOUND
- test/fixtures/drift_schemas/drift_schema_v3.json: FOUND
- test/generated_migrations/schema_v3.dart: FOUND
- test/helpers/fake_location_stream.dart: FOUND
- test/helpers/in_memory_shared_preferences.dart: FOUND
- test/domain/fix_invariants_test.dart: FOUND
- test/infrastructure/db/v2_to_v3_migration_test.dart: FOUND
- test/infrastructure/stores/drift_fix_store_test.dart: FOUND
- Commit edb429d: FOUND
- Commit f462cf3: FOUND
- Commit 6b9fa1b: FOUND
- Commit f28bf3d: FOUND
