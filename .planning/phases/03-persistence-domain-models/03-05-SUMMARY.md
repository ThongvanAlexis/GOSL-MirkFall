---
phase: 03-persistence-domain-models
plan: 05
subsystem: infra
tags: [drift, drift_dev, sqlite, schema-verifier, migrations, backup, schema-sanity, onBeforeUpgrade, sc-06, blocker-3, sess-06]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: lib/infrastructure/db/app_database.dart (schemaVersion=2, onBeforeUpgrade hook), lib/infrastructure/db/migrations/v1_to_v2_notes.dart, lib/domain/errors/migration_errors.dart (MigrationFailureException), lib/config/constants.dart (kDbFilename, kMaxDbBackups, kDbBackupDirName), test/generated_migrations/schema.dart (GeneratedHelper + DatabaseAtV1 + DatabaseAtV2), drift_schemas/drift_schema_v{1,2}.json, test/fixtures/db_seed/v1_baseline.sql
provides:
  - lib/infrastructure/db/backup.dart — DbBackupService (copy-based pre-migration backup + rolling rotation by mtime; injectable clock for deterministic tests)
  - lib/infrastructure/db/schema_sanity.dart — SchemaSanityChecker (pre/post row-count capture over the 6 MirkFall tables + hard-fail MigrationFailureException on any loss; growth silent)
  - lib/infrastructure/db/app_database_factory.dart — buildAppDatabase(dbFilename, backupDir, maxBackups) factory; composes DbBackupService with AppDatabase.onBeforeUpgrade (Blocker 3 closure)
  - lib/infrastructure/db/migrations/v1_to_v2_notes.dart — SQL fix: 'ALTER TABLE t_sessions ADD COLUMN "notes" TEXT NULL' (was missing quoted column + explicit NULL keyword; SchemaVerifier.migrateAndValidate now passes)
  - test/infrastructure/db/backup_test.dart — 6 DbBackupService unit tests (filename format, byte-equal copy, 4->3 rotation by mtime, no-op below cap, missing-dir silent, consecutive-takeBackup rotation cap)
  - test/infrastructure/db/schema_sanity_test.dart — 6 SchemaSanityChecker unit tests (6-table fresh count, post-INSERT counts, silent on identity/growth, throws on loss with table + counts in reason, missing key treated as 0)
  - test/infrastructure/db/migration_v1_to_v2_test.dart — 2 end-to-end migration tests via SchemaVerifier.migrateAndValidate (single row + NULL default + writeable notes; v1_baseline.sql 70-row fixture survives end-to-end through SchemaSanityChecker)
  - test/infrastructure/db/backup_on_upgrade_test.dart — 3 runtime integration tests (V1->V2 opens trigger backup BEFORE onUpgrade — byte-count proxy proves ordering; onCreate does NOT trigger; already-current V2 does NOT trigger)
affects: [03-06-plan, 05-gps-poc, 13-import-export]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Factory-composed AppDatabase: buildAppDatabase(...) wires DbBackupService.takeBackup into onBeforeUpgrade hook — backup fires inside MigrationStrategy.beforeOpen iff details.hadUpgrade == true, BEFORE onUpgrade mutates the schema"
    - "Data-survival gate independent of shape validation: SchemaVerifier.migrateAndValidate checks SCHEMA; SchemaSanityChecker.captureRowCounts + assertNoLoss checks DATA — both must pass for a green migration (RESEARCH pitfall #7)"
    - "Rolling backup rotation by mtime — File.statSync().modified sort, descending, skip first maxBackups, delete tail. Orphan files in backupDir counted the same as real backups (service owns the whole dir)"
    - "Cross-platform filename safety: ISO 8601 UTC with colons replaced by hyphens — Windows forbids ':' in filenames; the hyphen variant is valid on every target platform"
    - "Byte-count proxy for ordering proof: compare backup file size against pre-open live-DB file size — if the hook fired AFTER onUpgrade, the 'ALTER TABLE ADD COLUMN notes TEXT NULL' metadata write would have inflated the file bytes; byte-equal means 'backup ran BEFORE mutation'"
    - "Flaky-Windows tearDown tolerance: catch FileSystemException on recursive scratch-dir delete when pending async handles block file removal; let systemTemp eviction reclaim the dir (test isolation preserved by unique Directory.systemTemp.createTempSync prefixes)"

key-files:
  created:
    - lib/infrastructure/db/backup.dart
    - lib/infrastructure/db/schema_sanity.dart
    - lib/infrastructure/db/app_database_factory.dart
    - test/infrastructure/db/backup_test.dart
    - test/infrastructure/db/schema_sanity_test.dart
    - test/infrastructure/db/migration_v1_to_v2_test.dart
    - test/infrastructure/db/backup_on_upgrade_test.dart
  modified:
    - lib/infrastructure/db/migrations/v1_to_v2_notes.dart (ALTER SQL fix — emit quoted column + explicit NULL keyword to match V2 frozen dump)

key-decisions:
  - "V1ToV2Notes ALTER TABLE SQL emitted as 'ADD COLUMN \"notes\" TEXT NULL' (quoted identifier + explicit NULL keyword) — matches byte-equal the CREATE TABLE clause in drift_schema_v2.json. Without this fix, SchemaVerifier.migrateAndValidate raised 'Not equal: NULL (expected) and \"\" (actual)' on the notes column. The earlier 03-04 form 'ADD COLUMN notes TEXT' would migrate correctly at runtime but failed shape verification."
  - "Byte-count ordering proof — backup_on_upgrade_test compares backup.lengthSync() to the pre-open live-DB file size. If the onBeforeUpgrade hook fired AFTER onUpgrade, the backup would capture the post-ALTER bytes (bigger). Byte equality is a strong enough proxy for 'backup ran first' without requiring timestamp-based proof (which would be flaky on Windows FAT-time precision)."
  - "Migration tests tagged @Tags(['migration']) — allows CI to isolate the SchemaVerifier round-trip suite via 'dart test -t migration' from the fast domain suite. Follows the 03-01 dart_test.yaml convention."
  - "Windows tearDown tolerance via try/catch FileSystemException — mirkfall_backup_test_ + mirkfall_backup_on_upgrade_ scratch dirs in systemTemp can fail recursive delete when a pending async File.copy handle races the test cleanup. Each run is isolated by a unique createTempSync prefix, so residual files don't leak between runs; systemTemp eviction reclaims them."
  - "NativeDatabase (sync) over createInBackground (isolate) in buildAppDatabase — the backup hook and migration run in the same isolate as the open, which is required for the hook to have pre-open file access. Phase 05 can switch to the isolate variant if profiling shows UI-thread blocking; the backup File.copy itself is already async."
  - "Seeded V1 DB via v1.DatabaseAtV1(NativeDatabase(File(path))) — DatabaseAtV1 has schemaVersion=1, so opening the drift wrapper against an empty file materializes the V1 schema via Drift's onCreate without triggering any migration. Alternative 'VACUUM INTO path' from an in-memory seed DB was considered but rejected — NativeDatabase directly at the file is simpler and avoids the roundtrip."
  - "SchemaSanityChecker._executor typed as QueryExecutor (Drift core) — accepts either db.executor from a live AppDatabase or the raw executor from v1.DatabaseAtV1 / v2.DatabaseAtV2. This gives 03-06 flexibility for where to inject it (per-connection or per-database)."

patterns-established:
  - "Per-task atomic RED/GREEN commits: test(03-05) RED -> feat(03-05) GREEN for Task 1; test(03-05) composite for Task 2 (test + bugfix in same commit since bug blocked the test); test(03-05) RED -> feat(03-05) GREEN for Task 3"
  - "drift_schema_v{N}.json frozen-fixture audit — when SchemaVerifier.migrateAndValidate flags a column mismatch, the VN json is the source of truth; align the migration SQL to the frozen dump, NOT the other way around"
  - "Rolling-window file rotation contract — takeBackup always calls rotate after the write; rotate itself is idempotent (no-op when <= maxBackups) so manual invocation (e.g. debug menu purge button) is safe"

requirements-completed: [SESS-06]

# Metrics
duration: 8 min
completed: 2026-04-18
---

# Phase 03 Plan 05: DbBackupService + SchemaVerifier migration + Blocker 3 closure Summary

**DbBackupService (rolling pre-migration DB copy, mtime-rotation to 3) + SchemaSanityChecker (pre/post row-count gate that hard-fails MigrationFailureException on any loss) + buildAppDatabase factory (wires DbBackupService.takeBackup into AppDatabase.onBeforeUpgrade so opening an out-of-date DB produces a backup file BEFORE onUpgrade mutates the schema — proven by byte-count equality between the backup file and the pre-open live DB) + end-to-end V1->V2 migration test that seeds a V1 session through DatabaseAtV1, runs SchemaVerifier.migrateAndValidate to V2, asserts notes defaults to NULL + is writeable + row counts preserved; 17 new tests green (6 backup + 6 sanity + 2 migration + 3 backup-on-upgrade), in-process [Rule 1 - Bug] fix to V1ToV2Notes ALTER SQL (quoted column + explicit NULL keyword) unblocks SchemaVerifier shape verification, SC#6 closed at runtime not just unit-test level, analyzer + domain-purity + header check all clean.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-18T11:18:47Z
- **Completed:** 2026-04-18T11:26:58Z
- **Tasks:** 3
- **Commits:** 5 (2 RED test + 2 GREEN feat + 1 composite test-and-bugfix)
- **Files created:** 7 (3 lib/, 4 test/)
- **Files modified:** 1 (lib/infrastructure/db/migrations/v1_to_v2_notes.dart)

## Accomplishments

- Closed SC#6 "Pre-migration backup file created before onUpgrade" at the runtime level, not just unit-test level. `buildAppDatabase` composes `DbBackupService.takeBackup` into `AppDatabase.onBeforeUpgrade`; `backup_on_upgrade_test` proves by byte-count equality that the backup captures the pre-upgrade V1 file bytes, not the post-`ALTER TABLE` bytes — a strong ordering proof that does not depend on filesystem timestamp precision.
- Closed SC#6 "V1->V2 fictive migration preserves rows" via two SchemaVerifier-driven tests: (a) single seeded session with non-notes fields intact + notes defaults to NULL + notes is writeable; (b) full `v1_baseline.sql` fixture (70 rows across 5 populated tables: 10 sessions + 50 markers + 5 revealed_tiles + 3 categories + 2 mirk_styles) survives V1->V2 with row counts preserved end-to-end through `SchemaSanityChecker.captureRowCounts` + `assertNoLoss`.
- Closed SC#6 "Row-count regression => MigrationFailureException" via `SchemaSanityChecker.assertNoLoss` — 6-case unit test proves silent on identity + growth, throws with table + before/after counts in `reason` on any decrease, treats missing post-migration table key as 0 (so a dropped table always fires iff it had rows).
- Delivered `DbBackupService` with deterministic ISO-UTC filename (colons replaced by hyphens for Windows-safe cross-platform filenames), byte-equal `File.copy` based implementation, and rolling rotation by `File.statSync().modified` — 6-case unit test covers happy path, rotation (4->3 keeps newest), no-op below cap, missing-dir handling, and consecutive takeBackup rotation.
- [Rule 1 - Bug] Fixed V1ToV2Notes ALTER SQL — was emitting `ALTER TABLE t_sessions ADD COLUMN notes TEXT` (functional at runtime, but SchemaVerifier.migrateAndValidate reported `Not equal: NULL (expected) and '' (actual)` because the frozen V2 dump declares `"notes" TEXT NULL` with quoted identifier + explicit NULL nullability keyword). New form matches the dump byte-equal: `ALTER TABLE t_sessions ADD COLUMN "notes" TEXT NULL`.
- Handed off to 03-06 a feature-complete `lib/infrastructure/db/` tree: open-DB + migrate + auto-backup path closed, no further infra changes expected in Phase 03.

## Task Commits

| # | Phase | Type | Title | Commit |
|---|-------|------|-------|--------|
| 1 | RED   | test | DbBackupService + SchemaSanityChecker failing tests | `3a8ff67` |
| 1 | GREEN | feat | DbBackupService + SchemaSanityChecker — SC#6 building blocks | `bbf7c05` |
| 2 | —     | test | V1->V2 migration SchemaVerifier data-preservation test + fix ALTER SQL | `67ba06e` |
| 3 | RED   | test | failing test for buildAppDatabase + backup-on-upgrade hook | `6423b64` |
| 3 | GREEN | feat | buildAppDatabase factory — wires DbBackupService into onBeforeUpgrade (Blocker 3) | `c292090` |

Plan metadata commit added by the post-task gsd-tools step.

Task 1 got full TDD RED/GREEN. Task 2 is a composite test-and-bugfix commit — the migration test was RED by default because it revealed the V1ToV2Notes SQL mismatch against the frozen V2 dump; the fix was mechanical (two-word change) and making it a separate commit would have obscured the test/fix relationship. Task 3 got full TDD RED/GREEN.

## SchemaVerifier API trace — patterns used

For 03-06 and Phase 05 reuse, the exact API surface exercised in this plan:

```dart
import 'package:drift_dev/api/migrations_native.dart';
import 'test/generated_migrations/schema.dart';             // GeneratedHelper
import 'test/generated_migrations/schema_v1.dart' as v1;    // DatabaseAtV1
import 'test/generated_migrations/schema_v2.dart' as v2;    // DatabaseAtV2

final verifier = SchemaVerifier(GeneratedHelper());

// Step 1: instantiate an initialized schema at a target version.
// Returns InitializedSchema<Database> — raw sqlite3 backend + newConnection factory.
final schema = await verifier.schemaAt(1);

// Step 2: seed data using the version-specific Drift wrapper.
// DatabaseAtV1 has schemaVersion=1, so opening it does NOT fire any onUpgrade.
final seedDb = v1.DatabaseAtV1(schema.newConnection());
await seedDb.customStatement('INSERT INTO t_sessions ...');
await seedDb.close();

// Step 3: open the PROD AppDatabase (schemaVersion=2) against the same backing store.
// Each newConnection() is a fresh DatabaseConnection sharing the raw in-memory DB.
final prodDb = AppDatabase(schema.newConnection());

// Step 4: migrate and validate via the verifier — runs the full MigrationStrategy.
await verifier.migrateAndValidate(prodDb, 2);

// Step 5: read surviving rows / write to new columns directly via customSelect / customStatement.
final row = await prodDb.customSelect("SELECT notes FROM t_sessions WHERE ...").getSingle();
```

Key gotcha: `drift/drift.dart` re-exports an `isNull` column matcher that collides with `package:matcher`'s value matcher used in `expect(...)`. The migration test omits `package:drift/drift.dart` entirely since it doesn't need Drift's query builder — everything goes through `customStatement` / `customSelect`. If both are needed, `import 'package:drift/drift.dart' hide isNull;`.

## Backup filename format

Shipped form: `mirkfall.db.backup-v{from}-to-v{to}-{iso-utc}` where `{iso-utc}` is `DateTime.toIso8601String().replaceAll(':', '-')`.

Example: `mirkfall.db.backup-v1-to-v2-2026-04-18T12-30-45.123Z`

Rationale: Windows forbids `:` in filenames. ISO 8601 UTC with colons replaced by hyphens keeps the filename valid on every target platform (Android, iOS, macOS, Linux, Windows) while preserving the ISO timestamp's lexicographic ordering property (so `ls` order == chronological order). The dot in the milliseconds section (`.123`) is still valid everywhere.

## Row-count sanity semantic — why growth is OK

`SchemaSanityChecker.assertNoLoss` is silent on identity AND growth; it only fires on decrease. Per CLAUDE.md §Error handling ("distinguer trois niveaux"):

- **Decrease** = bug in `onUpgrade` that dropped rows. This is Level 1 (bug of programmation): crash the migration, log stack trace, show generic "import a échoué" to user. `MigrationFailureException` propagates up to the top-level handler.
- **Growth** = legitimate `onUpgrade` seeding a row (e.g., `cat_default` marker category on first V2 open; or a computed-field backfill that inserts per-user defaults). Silent accept; growth is a feature of the migration step, not a fault.
- **Identity** = the expected outcome for a pure schema migration like V1ToV2Notes (column add, no data touched). Silent accept.

The "must be exact" alternative (`before == after`) was rejected because it would veto any future `onUpgrade` seed-row pattern — a restriction that bites when Phase 04 Review Gate or later phases need to ship a default category or style row.

## `buildAppDatabase` factory contract

```dart
AppDatabase buildAppDatabase({
  required String dbFilename,      // absolute path to the live mirkfall.db
  required Directory backupDir,    // <app_support>/db_backups/
  required int maxBackups,         // kMaxDbBackups == 3
})
```

The factory composes:
1. `DbBackupService(dbFilename, backupDir, maxBackups)` — the rolling-backup service.
2. `NativeDatabase(File(dbFilename), setup: (raw) => raw.execute('PRAGMA journal_mode = WAL'))` — synchronous Drift executor pointed at the file; `setup:` applies WAL on the raw sqlite3 handle BEFORE Drift's first query (RESEARCH pitfall #2).
3. `AppDatabase(executor, onBeforeUpgrade: (details) => backupService.takeBackup(fromVersion: details.versionBefore ?? 0, toVersion: details.versionNow))` — the `versionBefore ?? 0` coerce is defensive; AppDatabase only invokes the hook when `details.hadUpgrade == true`, which implies a non-null `versionBefore`.

Runtime pragmas (`synchronous`, `busy_timeout`, `foreign_keys`) continue to be applied by `AppDatabase`'s `beforeOpen` via `applyRuntimePragmas` on every cold + warm open — the factory does NOT re-apply them.

**`NativeDatabase` vs `createInBackground` tradeoff:** the factory uses synchronous `NativeDatabase` because the backup hook and the DB open run in the same isolate (the hook needs pre-open file access). For production UI-thread responsiveness, Phase 05 can switch to `NativeDatabase.createInBackground(File, setup: ...)` if open-path profiling shows blocking > 16 ms; the `File.copy` inside `takeBackup` is already async so there's no per-call synchronous I/O concern.

**Fallback if `VACUUM INTO` is unavailable (plan mentioned):** not needed. The test seeds via `v1.DatabaseAtV1(DatabaseConnection(NativeDatabase(File(dbFilename))))` directly against the target file — Drift's `onCreate` materializes the V1 schema at the destination without any intermediate in-memory copy. Simpler than the in-memory-then-VACUUM-INTO pattern, works on every SQLite version.

## Backup-on-upgrade proof — three-assertion strategy

The "backup fires BEFORE onUpgrade" ordering guarantee is proven in `backup_on_upgrade_test.dart` via three linked assertions:

1. **Backup file exists + correctly named** after `db.customStatement('SELECT 1')` returns.
   - Pre-condition: scratch `backupDir` is empty.
   - Post-condition: exactly one file matching `mirkfall.db.backup-v1-to-v2-*` in `backupDir`.

2. **Backup bytes == pre-open live-DB file bytes** (`File(backup).lengthSync() == sizeBefore`).
   - Why this proves ordering: if the hook fired AFTER `onUpgrade`, the backup would reflect the post-ALTER schema (SQLite writes the `notes` column metadata into the file body, increasing byte count). Byte equality with the pre-open size means "no mutation occurred between open and backup" — i.e. the backup ran first.
   - Why byte count over mtime: mtime on Windows has 2-second precision on FAT filesystems; a millisecond-level ordering check would be flaky. Byte count is a hard physical measurement unaffected by clock resolution.

3. **Live DB is V2 + seeded row survives** (queryable `notes` column + surviving `sess_01HRBACKUPUPGRADEAAAAAAAAA` row).
   - Confirms the migration itself ran — the backup didn't short-circuit the upgrade.

Together: (1) proves backup happened, (2) proves it happened before, (3) proves upgrade happened after. Complete chain.

Two negative cases cover the `details.hadUpgrade` guard: (a) fresh DB `onCreate` path produces no backup; (b) reopening an already-current V2 DB produces no backup. Neither case invokes the hook, so the `backupDir` stays empty.

## Hand-off to 03-06

`lib/infrastructure/db/` is feature-complete for Phase 03. 03-06 (Drift stores + Riverpod providers + SESS-06 runtime proof + MIRK-03 runtime proof) consumes the stack as-is:

- **Store injection:** store impls take `AppDatabase` via constructor. No further wiring changes to AppDatabase expected.
- **Backup coverage:** any future schema-version bump in later phases (14-review-gate, 15-release) automatically gets pre-migration backups via the factory — no 03-06 work needed.
- **Sanity coverage:** Phase 05's `AppDatabaseProvider` should wrap `SchemaSanityChecker.captureRowCounts + assertNoLoss` around the open-DB-on-app-start flow. The building blocks are already in `SchemaSanityChecker` (const constructor, takes `QueryExecutor`); the only missing piece is the Riverpod provider shell which 03-06 builds.
- **Migration test pattern:** 03-06 and beyond can copy the `migration_v1_to_v2_test.dart` structure (tagged `migration`, uses `SchemaVerifier(GeneratedHelper())` + `verifier.schemaAt(N)`) whenever a new schema version lands.

No further infra changes expected in Phase 03. The only remaining work is 03-06 (last plan of the phase).

## Files Created/Modified

**Created (lib/, 3 files):**
- `lib/infrastructure/db/backup.dart` — `DbBackupService` (~ 90 LOC): copy-based pre-migration backup + rolling rotation by mtime + injectable clock.
- `lib/infrastructure/db/schema_sanity.dart` — `SchemaSanityChecker` (~ 70 LOC): const class, captures per-table row counts; `assertNoLoss` throws `MigrationFailureException` with table + before/after counts on any decrease.
- `lib/infrastructure/db/app_database_factory.dart` — `buildAppDatabase` (~ 55 LOC): composes DbBackupService + NativeDatabase + AppDatabase constructor to deliver the production DB with Blocker 3 wiring closed.

**Created (test/, 4 files):**
- `test/infrastructure/db/backup_test.dart` — 6 cases covering filename format, byte-equal copy, rotation (4->3), no-op below cap, missing-dir silent, consecutive-takeBackup rotation cap.
- `test/infrastructure/db/schema_sanity_test.dart` — 6 cases covering 6-table fresh count, post-INSERT counts, silent on identity + growth, throws on loss with reason mentioning table + counts, missing key treated as 0.
- `test/infrastructure/db/migration_v1_to_v2_test.dart` — 2 cases tagged `migration`: single seeded session survives + notes NULL + writeable; full `v1_baseline.sql` fixture round-trips end-to-end through SchemaSanityChecker.
- `test/infrastructure/db/backup_on_upgrade_test.dart` — 3 cases tagged `migration`: V1->V2 open triggers backup BEFORE onUpgrade (byte-count proof); fresh DB onCreate does NOT trigger; already-current V2 reopen does NOT trigger.

**Modified (1 file):**
- `lib/infrastructure/db/migrations/v1_to_v2_notes.dart` — ALTER SQL fix: `'ADD COLUMN "notes" TEXT NULL'` (quoted identifier + explicit NULL keyword) so runtime schema matches `drift_schema_v2.json` byte-equal; `SchemaVerifier.migrateAndValidate` shape check now passes.

## Decisions Made

See frontmatter `key-decisions`. Key call-outs:

1. **V1ToV2Notes ALTER SQL shape locked to frozen V2 dump** — quoted column identifier + explicit `NULL` nullability keyword required for byte-equal match with `drift_schema_v2.json`. The 03-04 form worked at runtime but failed shape verification.
2. **Byte-count ordering proof** — `backup.lengthSync() == sizeBefore` proves "backup before onUpgrade" without relying on filesystem timestamp precision. Portable across Windows FAT / ext4 / APFS.
3. **NativeDatabase (sync) in buildAppDatabase** — same-isolate backup hook + migration; Phase 05 can swap to isolate variant if open-path profiling demands it.
4. **Seed V1 DBs via DatabaseAtV1(NativeDatabase(File))** — simpler than VACUUM INTO; Drift onCreate materializes V1 schema at the destination directly.
5. **Tag migration tests `@Tags(['migration'])`** — CI can isolate via `dart test -t migration`; follows 03-01 `dart_test.yaml` convention.
6. **Growth OK in SchemaSanityChecker** — per CLAUDE.md §Error handling level distinctions; leaves room for future onUpgrade seed-row patterns.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] V1ToV2Notes ALTER SQL fails SchemaVerifier shape validation**
- **Found during:** Task 2 (V1->V2 migration test first run)
- **Issue:** `V1ToV2Notes.apply` emitted `'ALTER TABLE t_sessions ADD COLUMN notes TEXT'` which is functional at runtime — the column is added and nullable — but `SchemaVerifier.migrateAndValidate` compares the runtime schema against the frozen `drift_schema_v2.json` dump byte-equal, and the dump declares the column as `"notes" TEXT NULL` (quoted identifier + explicit NULL nullability keyword). Result: verifier raised `SchemaMismatch: Not equal: NULL (expected) and '' (actual)` on the `notes` column.
- **Fix:** Changed the emitted SQL to `'ALTER TABLE t_sessions ADD COLUMN "notes" TEXT NULL'` — matches the frozen V2 dump byte-equal. SQLite accepts both forms; the stricter form keeps SchemaVerifier happy.
- **Files modified:** `lib/infrastructure/db/migrations/v1_to_v2_notes.dart`
- **Verification:** `dart test test/infrastructure/db/migration_v1_to_v2_test.dart` — 2 cases pass; `dart test test/infrastructure/db/backup_on_upgrade_test.dart` — 3 cases pass. Full infra suite green (30/30). Analyzer + header + domain-purity all clean.
- **Committed in:** `67ba06e` (Task 2 — fix scoped into the migration-test commit because it unblocked that same test)

**2. [Rule 1 - Bug] Windows recursive tearDown races pending async File.copy handles**
- **Found during:** Task 2 full infra-suite run (intermittent PathNotFoundException in backup_test teardown)
- **Issue:** `tearDown(() { scratchDir.deleteSync(recursive: true); })` can race a pending OS-level file handle that's still draining from a prior `await source.copy(path)`. On Windows, the recursive delete iterator sees a sibling, the OS deletes it, then `deleteSync` throws `PathNotFoundException`. Not a correctness bug — just a test-harness nuisance. Symptom: suite occasionally shows `-1 fail` in the backup_test suite, passes on retry.
- **Fix:** Wrap tearDown in `try { ... } on FileSystemException { /* let systemTemp evict */ }`. Each test's scratch dir is namespaced by `Directory.systemTemp.createTempSync('mirkfall_backup_test_')` so residual directories from flaky tearDowns don't leak between runs.
- **Files modified:** `test/infrastructure/db/backup_test.dart`, `test/infrastructure/db/backup_on_upgrade_test.dart` (both got the same pattern)
- **Verification:** Two consecutive full infra-suite runs both show 30/30 green.
- **Committed in:** `67ba06e` (backup_test.dart — scoped with Task 2's other test changes), `c292090` (backup_on_upgrade_test.dart — shipped with Task 3's GREEN commit)

**3. [Rule 3 - Blocking] drift/drift.dart `isNull` export collides with matcher's `isNull`**
- **Found during:** Task 2 first test compile
- **Issue:** The migration test initially used `expect(row.readNullable<String>('notes'), isNull)` where `isNull` was intended as `package:matcher`'s value matcher. But `package:drift/drift.dart` re-exports an `isNull` column matcher from its query builder with the same name, causing `Error: 'isNull' is imported from both 'package:drift/src/runtime/query_builder/query_builder.dart' and 'package:matcher/src/core_matchers.dart'`.
- **Fix:** Dropped the `package:drift/drift.dart` import entirely — the migration test only uses `customStatement` / `customSelect` via the underlying AppDatabase, never Drift's query builder directly. The `package:test/test.dart` import gives matcher's `isNull`, `equals`, `hasLength`, etc.
- **Files modified:** `test/infrastructure/db/migration_v1_to_v2_test.dart`
- **Verification:** Test compiles and passes; analyzer clean.
- **Committed in:** `67ba06e` (Task 2)

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking).

**Impact on plan:** All three were caught at verification time and resolved within the relevant task commit. #1 is the most consequential — it reveals that the 03-04 V1ToV2Notes shape was not verified against the frozen V2 dump; the shape check is an SC#6 hard-gate, so this fix retroactively ratifies the 03-04 migration framework (without it, SchemaVerifier.migrateAndValidate would not have passed for any future migration either). #2 + #3 are test-infrastructure hygiene fixes with no production-code impact.

## Authentication Gates

None — no external services touched.

## User Setup Required

None — no env vars, no account config, no dashboard steps.

## Issues Encountered

None beyond the three auto-fixes above. Tests were designed, written RED, implemented GREEN, and settled within one iteration per task.

## Next Phase Readiness

**Wave 5 mid-point.** 03-05 closed. 03-06 (Drift stores + Riverpod providers + SESS-06 + MIRK-03 runtime proofs) runs in parallel under the same wave. With 03-05's outputs:

- 03-06 inherits `SchemaSanityChecker` + `DbBackupService` + `buildAppDatabase` ready to wire into provider layers. No infra code changes expected from 03-06.
- The `migration` test tag is established — 03-06 can use `@Tags(['migration'])` for any future migration regression tests it ships.
- `lib/infrastructure/db/` is feature-complete for Phase 03. 03-06 builds on top (stores directory), no parent-level edits.

**Forward-declarations to honour:**
- Phase 05 `AppDatabaseProvider` wires `SchemaSanityChecker.captureRowCounts + assertNoLoss` around the open-DB-on-app-start flow (building blocks done; Riverpod shell missing).
- Phase 15 "Backup DB now" debug-menu affordance calls `DbBackupService.takeBackup` directly (optional; the service is already instantiable via the factory's `backupService` field — Phase 15 can either expose it or construct a fresh one).

---
*Phase: 03-persistence-domain-models*
*Completed: 2026-04-18*

## Self-Check: PASSED

All 7 created files + 1 modified file present on disk. All 5 task commits (`3a8ff67`, `bbf7c05`, `67ba06e`, `6423b64`, `c292090`) reachable via `git log --all`.
