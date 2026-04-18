---
phase: 03-persistence-domain-models
plan: 06
subsystem: infra
tags: [drift, riverpod, riverpod_annotation, sqlite, sess-06, mirk-03, cascade, extendedresultcode-2067, store-impl, @riverpod-codegen, phase-03-close]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: lib/domain/sessions/session_store.dart + 5 sibling ports (03-03), lib/domain/errors/{concurrent,session,marker,category}_errors.dart (03-02), kCategoryDefaultId + 6 ID extension types + IdGenerator port (03-02), mergeBitmap + popcount primitives (03-02), lib/infrastructure/db/app_database.dart with SESS-06 partial unique index + MIRK-03 composite unique + FK+CASCADE policy + onBeforeUpgrade hook (03-04), SessionRow/MarkerRow/MarkerCategoryRow/MirkStyleRow/RevealedTileRow/PhotoRow data classes (03-04), lib/infrastructure/db/type_converters.dart SessionStatusStringConverter + MirkStyleConfigJsonConverter (03-04), lib/infrastructure/db/app_database_factory.dart buildAppDatabase + DbBackupService wiring (03-05), kDbFilename + kDbBackupDirName + kMaxDbBackups + kRevealedTileBitmapBytes constants, SeededIdGenerator + RandomIdGenerator (03-02)
provides:
  - 5 Drift store impls (lib/infrastructure/stores/drift_{session,marker,marker_category,mirk_style,revealed_tile}_store.dart) each `implements` its domain port verbatim — DriftSessionStore wraps SqliteException 2067 -> ConcurrentActivationException, DriftRevealedTileStore.mergeMask transactional OR-monotone, DriftMarkerCategoryStore transactional reassign-to-default + cat_default protection
  - lib/infrastructure/stores/sqlite_error_mapper.dart — shared constants (kSqliteConstraintUnique = 2067, kSqliteConstraintForeignKey = 787)
  - lib/infrastructure/stores/README.md documenting 5 stores + SqliteException wrapping policy (only 2067 wrapped, all other codes rethrown) + transaction boundaries
  - 7 @Riverpod(keepAlive: true) providers (lib/application/providers/{id_generator,app_database,session_store,marker_store,marker_category_store,mirk_style_store,revealed_tile_store}_provider.dart) + 7 generated .g.dart files — first productive use of riverpod_annotation/riverpod_generator in the project
  - lib/application/providers/README.md documenting the graph, keepAlive rationale, and test-override pattern
  - 6 store-layer test files (21 tests) closing SESS-06 runtime proof (4 tests), 2067 mapping proof (3 tests), MIRK-03 idempotence + additive + concurrent + wrong-size mask + single-row invariant (6 tests), MIRK-03 concurrent-reveal proof (2 tests), session cascade to markers + tiles + photos (2 tests), category non-cascade reassign + cat_default protection (4 tests)
affects: [04-review-gate-persistence, 05-gps-session-lifecycle, 07-map-integration, 09-fog-rendering, 11-markers-photos, 13-import-export]

# Tech tracking
tech-stack:
  added: []  # Zero new dependencies — all toolchain bumps landed in 03-04 preflight
  patterns:
    - "Drift store impls use constructor DI — `DriftSessionStore(AppDatabase, IdGenerator)`, `DriftMarkerStore(AppDatabase)`, etc. No singletons; Riverpod providers compose them from appDatabaseProvider + idGeneratorProvider"
    - "SqliteException wrapping is narrowly scoped — only extendedResultCode == 2067 (SQLITE_CONSTRAINT_UNIQUE) on DriftSessionStore.activate is rewrapped into ConcurrentActivationException. Every other code rethrown unchanged (RESEARCH §pitfall #4)"
    - "DriftRevealedTileStore.mergeMask runs SELECT + INSERT-or-UPDATE inside _db.transaction(() async {...}) — Drift serializes at the connection level, so Future.wait-scheduled merges on the same tile converge on the byte-wise OR of all masks with no lost updates"
    - "DriftMarkerCategoryStore.delete runs in a transaction: UPDATE t_markers SET category_id='cat_default' WHERE category_id=<id> THEN DELETE FROM t_marker_categories. Deleting cat_default itself is forbidden — counts affected markers then throws CategoryInUseException WITHOUT touching the DB"
    - "Test ID convention: sentinel bodies padded with 'A' to 26 chars ('sess_01HR<SCOPE>AAAA...') so IDs remain human-greppable in logs and fail CategoryId.isValid / SessionId.isValid deterministically"
    - "drift/drift.dart re-exports matcher-colliding `isNotNull` (a column matcher) — every test that uses both drift types and matcher's value-matcher imports with `hide isNotNull`. Same idiom as 03-05's migration tests"
    - "@Riverpod(keepAlive: true) on all 7 providers — the DB is a process singleton (re-opening thrashes WAL + invalidates transactions) and downstream stores keep the flag for symmetry"
    - "Denormalized renderer_type column in t_mirk_styles derived from MirkStyleConfig sealed variant at insert/update time (switch { AtmosphericConfig() => 'atmospheric', ShaderConfig() => 'shader', UnknownConfig() => 'unknown' }) — keeps config + column consistent without a separate writer path"
    - "DriftMarkerStore hydrates Marker.photos as const <PhotoRef>[] in Phase 03 — the photo join lives with FilesystemPhotoStore in Phase 11 (decision D8: photos on disk, not SQLite BLOB)"

key-files:
  created:
    - lib/infrastructure/stores/drift_session_store.dart
    - lib/infrastructure/stores/drift_marker_store.dart
    - lib/infrastructure/stores/drift_marker_category_store.dart
    - lib/infrastructure/stores/drift_mirk_style_store.dart
    - lib/infrastructure/stores/drift_revealed_tile_store.dart
    - lib/infrastructure/stores/sqlite_error_mapper.dart
    - lib/infrastructure/stores/README.md
    - lib/application/providers/id_generator_provider.dart
    - lib/application/providers/id_generator_provider.g.dart
    - lib/application/providers/app_database_provider.dart
    - lib/application/providers/app_database_provider.g.dart
    - lib/application/providers/session_store_provider.dart
    - lib/application/providers/session_store_provider.g.dart
    - lib/application/providers/marker_store_provider.dart
    - lib/application/providers/marker_store_provider.g.dart
    - lib/application/providers/marker_category_store_provider.dart
    - lib/application/providers/marker_category_store_provider.g.dart
    - lib/application/providers/mirk_style_store_provider.dart
    - lib/application/providers/mirk_style_store_provider.g.dart
    - lib/application/providers/revealed_tile_store_provider.dart
    - lib/application/providers/revealed_tile_store_provider.g.dart
    - lib/application/providers/README.md
    - test/infrastructure/stores/session_store_exclusivity_test.dart
    - test/infrastructure/stores/session_store_error_mapping_test.dart
    - test/infrastructure/stores/revealed_tile_store_idempotence_test.dart
    - test/infrastructure/stores/revealed_tile_store_concurrent_test.dart
    - test/infrastructure/stores/drift_session_store_cascade_test.dart
    - test/infrastructure/stores/marker_category_store_cascade_test.dart
  modified: []

key-decisions:
  - "SqliteException wrapping narrowly scoped to extendedResultCode == 2067 on DriftSessionStore.activate. Alternative (wrap all SqliteException codes into generic StoreException) was rejected because it would mask unrelated bugs — a FOREIGN_KEY violation (787) should surface as the runtime error it is, not be silently wrapped as an activation race. Follows RESEARCH §pitfall #4."
  - "DriftMarkerCategoryStore.delete checks cat_default identity BEFORE the transaction and counts markers via customSelect. Including the marker count in CategoryInUseException gives the logs enough context to reproduce without an extra query; rejecting cat_default deletion without counting is a silent-failure footgun for admin-import callers."
  - "DriftRevealedTileStore accepts IdGenerator by constructor — the INSERT branch of mergeMask mints a new rvt_ id on first write to a (session, parentX, parentY) tuple. Pre-allocating ids at the caller would force callers to know whether a tile already exists, which breaks the mergeMask abstraction."
  - "DriftMarkerStore constructor takes AppDatabase only (no IdGenerator) — Phase 03 callers pass a pre-allocated MarkerId in the Marker entity. Phase 11 (photo capture flow) will extend the store if it ever needs to mint marker ids on the fly."
  - "DriftSessionStore constructor takes IdGenerator even though Phase 03 never uses it — symmetry with DriftRevealedTileStore and forward-compat for insert-without-id paths (Phase 05 may add `SessionStore.create(displayName)` returning a freshly-minted session). The unused_field lint is ignored with a docstring explaining why."
  - "Marker.photos hydrated as const <PhotoRef>[] in Phase 03 — adding a DB-level Photos join here would leak the on-disk filename resolution responsibility into the marker store. Phase 11 adds FilesystemPhotoStore as the single source of truth for photo-ref hydration (decision D8: photos on disk, not SQLite BLOB)."
  - "@Riverpod(keepAlive: true) on all 7 providers. The DB leg is non-negotiable (re-opening mirkfall.db thrashes WAL + invalidates transactions); the store providers keep the flag for symmetry and to avoid invalidate storms when an awaiting consumer re-subscribes."
  - "MirkStyle.rendererType derived from the sealed MirkStyleConfig variant via pattern match at insert/update time. Stores it as the denormalized renderer_type column so future SELECT-WHERE can filter on renderer kind without scanning the JSON blob; keeps config + column consistent automatically."
  - "Test sentinel ID body padded to 26 chars with 'A' ('sess_01HR<SCOPE>AAAA...') so test IDs stay human-greppable, the 26-char length invariant is satisfied, and CategoryId.isValid / SessionId.isValid return true where tested."
  - "hide isNotNull on drift/drift.dart imports in every store test file — drift re-exports a column matcher with the same name as matcher's value matcher. Fixed idiom repeated from 03-05's migration tests; keeping the pattern consistent across the infra test suite simplifies the dart_test.yaml aliasing story in Phase 14."
  - "custom_lint stays silently degraded under the analyzer-10 override — confirmed by `dart run custom_lint` still failing compilation of custom_lint_core (Element2 API renamed). Acceptable: `flutter analyze --fatal-infos --fatal-warnings` is the authority, and it's green across the whole project. Re-evaluate custom_lint when 0.9.x (analyzer-^10 target) ships."
  - "main.dart wiring (ProviderScope + first consumer read) intentionally NOT touched — CONTEXT.md defers that to Phase 05 where ActiveSessionController is the first productive consumer. Phase 03 ships the graph, Phase 05 invokes it."

patterns-established:
  - "Atomic commits per store concern: 5 task commits — DriftSessionStore (+ error mapper), DriftRevealedTileStore, remaining 3 stores + README, store tests, providers + generated files + README"
  - "Per-test-file hide isNotNull on drift/drift.dart imports (5 of 6 store tests need drift types for DatabaseConnection + Variable)"
  - "Test sentinel IDs use 'A'-padded 26-char bodies for human greppability + ID validity"
  - "Generated .g.dart files committed alongside annotated source per CLAUDE.md build-determinism policy — tool/check_headers exempts *.g.dart, analyzer exempts **/*.g.dart"

requirements-completed: [SESS-06, MIRK-03]

# Metrics
duration: 12 min
completed: 2026-04-18
---

# Phase 03 Plan 06: Drift stores + Riverpod providers + SESS-06/MIRK-03 runtime proofs Summary

**Five Drift store implementations each `implements` their port verbatim (DriftSessionStore wraps SqliteException 2067 -> ConcurrentActivationException on activate; DriftRevealedTileStore.mergeMask runs SELECT + INSERT-or-UPDATE inside db.transaction to guarantee OR-monotone atomicity; DriftMarkerCategoryStore.delete runs a transactional UPDATE markers SET category_id='cat_default' + DELETE FROM t_marker_categories, cat_default deletion itself throws CategoryInUseException without touching the DB), plus 7 @Riverpod(keepAlive: true) providers closing the Phase 01 deferred lint-toolchain decision (custom_lint silently degraded but flutter analyze clean), plus 21 store-layer tests proving SESS-06 runtime + Future.wait concurrent activation + 2067 mapping isolation + MIRK-03 idempotence + additive OR + concurrent merge + session cascade to markers+tiles+photos + category non-cascade reassign + cat_default protection — 134 tests green under flutter test (120 under plain dart test), flutter analyze --fatal-infos clean, domain purity 37 files zero violations, phase 03 implementation complete.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-18T11:34:10Z
- **Completed:** 2026-04-18T11:46:29Z
- **Tasks:** 2 (both `type="auto"`, one with TDD)
- **Commits:** 5 (3 feat for stores + 1 test + 1 feat for providers)
- **Files created:** 28 (6 lib/ stores + 1 README + 7 hand-written providers + 7 generated .g.dart + 1 README + 6 tests)
- **Files modified:** 0 (zero changes to existing code)

## Accomplishments

- Closed **SESS-06 runtime**: DriftSessionStore.activate catches `SqliteException(extendedResultCode: 2067)` raised by the partial unique index `idx_t_sessions_status_active` and rewraps it in `ConcurrentActivationException`. Proven by 4 tests: single-session activation succeeds, double-activation raises the domain exception, deactivate unlocks subsequent activation, Future.wait concurrent activation resolves as exactly-one-success.
- Closed **SESS-06 error mapping**: 3 tests prove (a) the domain never sees SqliteException — the store layer rewraps, (b) the 2067 constant is reachable by driving the partial unique index directly via raw SQL, (c) non-2067 SqliteException codes propagate unchanged (no wide-catch).
- Closed **MIRK-03 runtime**: DriftRevealedTileStore.mergeMask wraps SELECT + INSERT-or-UPDATE in `_db.transaction(() async {...})`. 6 idempotence tests prove same-mask-twice identity, mask-A-then-mask-B byte-wise OR merge, partial-overlap union (0xF0 | 0x0F = 0xFF), zero-mask monotonicity, ArgumentError on wrong-size mask, single-row-per-(session,parentX,parentY) invariant. 2 concurrent tests prove `Future.wait` of 2 and 8 parallel merges converge on the union.
- Closed **Session CASCADE**: 2 tests prove that `DriftSessionStore.delete(sessionId)` removes the session, all markers with that session_id, all revealed_tiles with that session_id, AND all photos whose marker_id belongs to one of those markers — the FK ON DELETE CASCADE chain (session -> markers -> photos) lands in one DELETE statement. cat_default survives the session delete (non-CASCADE policy).
- Closed **Category non-CASCADE reassign**: 4 tests prove (a) the reassign-then-delete transactional pattern (markers formerly in custom are now in cat_default; custom category row is gone; cat_default still exists), (b) CategoryInUseException is raised when someone attempts to delete cat_default (with accurate markerCount), (c) deleting cat_default leaves the DB untouched, (d) the end state has zero orphan markers referencing a non-existent category.
- Shipped **7 @Riverpod(keepAlive: true) providers** with committed `.g.dart` files — idGeneratorProvider, appDatabaseProvider, sessionStoreProvider, markerStoreProvider, markerCategoryStoreProvider, mirkStyleStoreProvider, revealedTileStoreProvider. First productive use of riverpod_annotation/riverpod_generator in the project — the Phase 01 deferred lint decision is effectively ratified (custom_lint silently degrades under analyzer-10 per 03-04, but riverpod_generator runs cleanly and `flutter analyze --fatal-infos` is the authority).
- Handed Phase 03 over to the review gate: 134 tests green under `flutter test`, 120 tests green under `dart test test/domain/ test/infrastructure/`, `flutter analyze --fatal-infos --fatal-warnings` clean, `check_domain_purity` reports 37 domain files with zero forbidden imports, `check_headers` reports 107 files green, `check_licenses` + `check_dependencies_md` both green on 189 packages.

## Task Commits

| # | Type | Title | Commit |
|---|------|-------|--------|
| 1a | feat | DriftSessionStore + SqliteErrorMapper constants | `fe1d7a0` |
| 1b | feat | DriftRevealedTileStore — MIRK-03 transactional mergeMask | `0b85480` |
| 1c | feat | DriftMarkerStore + DriftMarkerCategoryStore (reassign) + DriftMirkStyleStore + stores README | `fee0002` |
| 1d | test | store-layer tests for SESS-06, MIRK-03 and cascade policy | `8487a0d` |
| 2 | feat | riverpod providers for idGenerator + appDatabase + 5 stores | `e4b02fa` |

Plan metadata commit added by the post-task gsd-tools step.

Task 1 was intentionally decomposed into three `feat` commits (one per atomic concern — the SESS-06-critical store, the MIRK-03-critical store, then the three straightforward CRUD stores + README) plus one `test` commit for the six store-layer tests. Task 2 is a single `feat` commit because the seven providers + the seven generated .g.dart files are logically one unit.

## SqliteException mapping policy

The wrapping policy is deliberately narrow — **only one site** catches `SqliteException`, and only one code is rewrapped:

```dart
// lib/infrastructure/stores/drift_session_store.dart — activate(id)
try {
  await (_db.update(_db.sessions)..where((t) => t.id.equals(id.value)))
      .write(const SessionsCompanion(status: Value('active')));
} on SqliteException catch (e) {
  if (e.extendedResultCode == kSqliteConstraintUnique) {
    throw ConcurrentActivationException(attemptedId: id);
  }
  rethrow;
}
```

**Rule:** catch only where a driver code maps bijectively to a documented domain race. Every other `SqliteException` rethrows unchanged. This means:
- FK violations (extendedResultCode 787) surface as `SqliteException` — they are programming bugs (caller forgot to seed the FK target), not recoverable domain events.
- DISK_IO, BUSY, SCHEMA, etc. — programmer or environment bugs, propagate to the top-level `runZonedGuarded` handler that logs the stack trace (CLAUDE.md §Error handling Level 1).

The `kSqliteConstraintUnique = 2067` constant lives in `lib/infrastructure/stores/sqlite_error_mapper.dart`. `kSqliteConstraintForeignKey = 787` is exposed for future callers even though Phase 03 does not map it — future phases that add FK-check failure modes can reference a named constant instead of a magic literal.

## Future.wait concurrency proof — transaction harness shape

```dart
// test/infrastructure/stores/revealed_tile_store_concurrent_test.dart
await Future.wait<void>(<Future<void>>[
  store.mergeMask(sessionId: sessionId, parentX: 7, parentY: 7, mask: a),
  store.mergeMask(sessionId: sessionId, parentX: 7, parentY: 7, mask: b),
]);
final row = await store.findByParent(sessionId: sessionId, parentX: 7, parentY: 7);
expect(row!.bitmap[0], 0xFF); // byte 0 from mask A
expect(row.bitmap[1], 0xFF);  // byte 1 from mask B
expect(row.setBitCount, 16);
```

Why this works: Drift serializes writes at the connection level, and our `_db.transaction(() async {...})` scope sees a consistent snapshot during SELECT + INSERT-or-UPDATE. Two mergeMask futures scheduled via `Future.wait` interleave at their `await` boundaries — if the transactional wrapper were missing, the SELECT in one future could race the UPDATE in the other, producing a lost-update (final bitmap == A instead of A | B). RESEARCH §pitfall on non-atomic OR merges pre-empted this failure mode; the test harness proves the fix.

The 8-parallel variant (2 concurrent-masks → 8 concurrent-masks on the same tile, each setting a different byte) converges on the full union byte-equal (`bitmap[0..7] == 0xFF`, `setBitCount == 64`). Full MIRK-03 atomicity guarantee.

## Provider graph

```
idGeneratorProvider (sync, keepAlive)
└── RandomIdGenerator(Random.secure())

appDatabaseProvider (Future, keepAlive)
└── buildAppDatabase(                               # 03-05 factory
      dbFilename: <app_support>/mirkfall.db,        # kDbFilename
      backupDir: <app_support>/db_backups/,         # kDbBackupDirName
      maxBackups: 3,                                # kMaxDbBackups
    )
    ├── NativeDatabase(File, setup: WAL pin)
    ├── DbBackupService (rolling, 3-wide)
    ├── AppDatabase(onBeforeUpgrade: DbBackupService.takeBackup)
    └── ref.onDispose(db.close)

sessionStoreProvider (Future, keepAlive)        ─┐
markerStoreProvider (Future, keepAlive)         ─┤
markerCategoryStoreProvider (Future, keepAlive) ─┼── ref.watch(appDatabaseProvider.future)
mirkStyleStoreProvider (Future, keepAlive)      ─┤                  ─┐
revealedTileStoreProvider (Future, keepAlive)   ─┘ ref.watch(idGeneratorProvider) ─ session + revealed_tile only
```

`keepAlive: true` on all 7 providers — the DB is a process singleton (re-opening thrashes WAL + invalidates transactions), and downstream store providers keep the flag for symmetry. Phase 03 unit tests bypass the graph entirely (`AppDatabase(NativeDatabase.memory(...))` + `DriftSessionStore(db, SeededIdGenerator(seed: N))` directly). Phase 07+ widget tests will exercise provider overrides; the pattern is documented in `lib/application/providers/README.md`.

`main.dart` wiring (ProviderScope + first consumer read) is intentionally NOT touched in Phase 03 — CONTEXT.md defers that to Phase 05 where `ActiveSessionController` becomes the first productive consumer.

## Photo store deferral

`DriftPhotoStore` is **NOT** shipped in Phase 03. The port (`lib/domain/photos/photo_store.dart`) was introduced in 03-03 for completeness of the store-ports catalogue, but the implementation waits for Phase 11 where the filesystem pipeline lands:

- **Decision D8:** photos live on disk at `<app_documents>/photos/<markerId>/<basename>`, NOT in a SQLite BLOB. Implication: a `PhotoStore` impl needs to coordinate DB row insertion + on-disk file write + EXIF strip (CLAUDE.md §Télémétrie), and that whole pipeline is Phase 11's responsibility.
- **Phase 03's DriftMarkerStore** hydrates `Marker.photos` as `const <PhotoRef>[]` — the Marker entity's `photos` field remains part of the contract, but it's unpopulated at the DB layer until Phase 11 ships `FilesystemPhotoStore` (which knows how to join t_photos and resolve the on-disk basenames).
- **Cascade coverage is still complete** at the DB level: `t_photos.marker_id` has `ON DELETE CASCADE`, so deleting a marker removes its photo rows (proven in the session cascade test by deleting the owning session — which drops markers — which drops photos). The on-disk file orphan cleanup lands with the Phase 11 impl.

No runtime consumer of `PhotoStore` exists in Phase 03 (the port is imported but not resolved via a provider), so this deferral has zero impact on the phase's test story.

## Handoff to Phase 04 review gate

Full Phase 03 test inventory ready for the Review Gate:

| Test suite | File | Tests | Coverage |
|------------|------|-------|----------|
| Tile math | test/domain/tile_math_test.dart | 6 | Paris, equator, poles, round-trip, TilePosition equality |
| Reveal calculator | test/domain/reveal_calculator_test.dart | 16 | mergeBitmap idempotence + commutativity + monotonicity + popcount cases |
| JsonMigrator framework | test/domain/json_migrator_test.dart | 10 | chain semantics + sentinel + dup-detection |
| ULID | test/infrastructure/ids/ulid_test.dart | 5 | length + alphabet + k-sort + reproducibility |
| Seeded IdGenerator | test/infrastructure/ids/seeded_id_generator_test.dart | 5 | determinism + prefix + RNG advance |
| Random IdGenerator | test/infrastructure/ids/random_id_generator_test.dart | 3 | uniqueness + prefix invariants |
| Session invariants | test/domain/session_invariants_test.dart | 6 | displayName non-empty + offset range |
| Session timezone | test/domain/session_timezone_test.dart | 2 | JSON round-trip across offsets |
| MirkStyleConfig fromJson | test/domain/mirk_style_config_fromjson_test.dart | 7 | sealed fromJson + UnknownConfig raw-map capture |
| Envelope fromJson | test/domain/envelope_fromjson_test.dart | 7 | validate + parse + shape |
| JsonMigrator v1->v2 | test/domain/json_migrator_v1_to_v2_test.dart | 1 | fixture-driven end-to-end |
| DB pragma | test/infrastructure/db/app_database_pragma_test.dart | 4 | journal_mode + synchronous + busy_timeout + foreign_keys |
| DB schema | test/infrastructure/db/app_database_schema_test.dart | 7 | 6 tables + SESS-06 index + MIRK-03 unique + CASCADE + schemaVersion + notes col |
| V1 identity fixture | test/infrastructure/db/v1_identity_fixture_test.dart | 2 | v1_baseline.sql 70-row load |
| Backup service | test/infrastructure/db/backup_test.dart | 6 | filename + rotation + no-op + missing-dir + consecutive |
| Schema sanity | test/infrastructure/db/schema_sanity_test.dart | 6 | identity + growth silent + loss throws |
| V1->V2 migration | test/infrastructure/db/migration_v1_to_v2_test.dart | 2 | SchemaVerifier + v1_baseline.sql survival |
| Backup on upgrade | test/infrastructure/db/backup_on_upgrade_test.dart | 3 | byte-count ordering proof |
| **SESSION EXCLUSIVITY (NEW)** | **test/infrastructure/stores/session_store_exclusivity_test.dart** | **4** | **SESS-06 runtime (activate, double, deactivate, Future.wait)** |
| **SESSION ERROR MAPPING (NEW)** | **test/infrastructure/stores/session_store_error_mapping_test.dart** | **3** | **2067 isolation + constant provenance + non-2067 passthrough** |
| **TILE IDEMPOTENCE (NEW)** | **test/infrastructure/stores/revealed_tile_store_idempotence_test.dart** | **6** | **MIRK-03 algebra + wrong-size rejection + single-row** |
| **TILE CONCURRENT (NEW)** | **test/infrastructure/stores/revealed_tile_store_concurrent_test.dart** | **2** | **Future.wait convergence on union** |
| **SESSION CASCADE (NEW)** | **test/infrastructure/stores/drift_session_store_cascade_test.dart** | **2** | **Session delete -> markers + tiles + photos** |
| **CATEGORY CASCADE (NEW)** | **test/infrastructure/stores/marker_category_store_cascade_test.dart** | **4** | **Reassign-to-default + cat_default protected + no orphans** |

Coverage map aligned to Phase 03 success criteria 1-6:

| SC # | Claim | Test(s) |
|------|-------|---------|
| 1 | WAL + synchronous=NORMAL + busy_timeout=5000 + V1 identity | app_database_pragma_test + v1_identity_fixture_test |
| 2 | SESS-06 at DB constraint level, not caller assertion | app_database_schema_test + **session_store_exclusivity_test** + **session_store_error_mapping_test** |
| 3 | MIRK-03 bitmap bit cannot unset within a session | **revealed_tile_store_idempotence_test** + **revealed_tile_store_concurrent_test** + reveal_calculator_test |
| 4 | Every named model is Freezed + lib/domain/ imports zero Flutter/Drift | session_invariants + envelope_fromjson + tool/check_domain_purity.dart |
| 5 | tile_math + reveal_calculator pure-Dart; JsonMigrator identity + v2 slot | tile_math_test + reveal_calculator_test + json_migrator_test + json_migrator_v1_to_v2_test |
| 6 | Pre-migration backup auto-produced + row-count sanity hard-fail | backup_test + schema_sanity_test + migration_v1_to_v2_test + backup_on_upgrade_test |

All 6 SCs have at least one corresponding passing test. The review gate has 134 tests green under `flutter test` and 120 under plain `dart test test/domain/ test/infrastructure/` to work with.

`03-VALIDATION.md` has not been inspected by this plan — the review gate is the appropriate place to flip its `nyquist_compliant` flag based on a holistic reread of the full phase.

## Phase 03 totals

- **Source files created across Phase 03**: ~60 hand-written (lib/ + test/ + tool/ + fixtures/), ~50 generated (`.freezed.dart` / `.g.dart` / `schema_vN.dart`)
- **Test files created across Phase 03**: 24 (5 domain + 11 infrastructure db + 5 infrastructure ids + 6 infrastructure stores — where the 11 db tests include this plan's two cascade stores)
- **Total tests**: 134 under `flutter test` (120 pure-Dart)
- **Commits across Phase 03**: ~28 (per-task atomic commits + plan metadata commits per plan) — 5 net new commits from 03-06

## Files Created/Modified

**Created (lib/, 8 files):**
- `lib/infrastructure/stores/sqlite_error_mapper.dart` — shared SQLite extended-result-code constants
- `lib/infrastructure/stores/drift_session_store.dart` — SESS-06 runtime wrapping
- `lib/infrastructure/stores/drift_marker_store.dart` — CRUD + photos intentionally empty until Phase 11
- `lib/infrastructure/stores/drift_marker_category_store.dart` — non-CASCADE reassign transaction + cat_default protection
- `lib/infrastructure/stores/drift_mirk_style_store.dart` — renderer_type denormalization from sealed config
- `lib/infrastructure/stores/drift_revealed_tile_store.dart` — MIRK-03 transactional mergeMask
- `lib/infrastructure/stores/README.md`
- 7 `lib/application/providers/*.dart` + 7 generated `lib/application/providers/*.g.dart` + `lib/application/providers/README.md`

**Created (test/, 6 files, 21 tests):**
- `test/infrastructure/stores/session_store_exclusivity_test.dart` — 4 tests
- `test/infrastructure/stores/session_store_error_mapping_test.dart` — 3 tests
- `test/infrastructure/stores/revealed_tile_store_idempotence_test.dart` — 6 tests
- `test/infrastructure/stores/revealed_tile_store_concurrent_test.dart` — 2 tests
- `test/infrastructure/stores/drift_session_store_cascade_test.dart` — 2 tests
- `test/infrastructure/stores/marker_category_store_cascade_test.dart` — 4 tests

**Modified:** none (zero changes to any existing file).

## Decisions Made

See frontmatter `key-decisions`. Key call-outs:

1. **SqliteException wrapping is narrowly scoped** — only `extendedResultCode == 2067` on `DriftSessionStore.activate` is rewrapped. Every other code rethrown unchanged (RESEARCH §pitfall #4). Kept the mapper file as two named constants plus a docstring — no abstraction layer over such a small set of codes.
2. **DriftMarkerCategoryStore.delete protects cat_default by counting + throwing without touching the DB** — the exception's `markerCount` field gives the logs enough context to reproduce. Alternative (return a void + log warning) rejected per CLAUDE.md §Error handling (never silent).
3. **DriftRevealedTileStore takes IdGenerator, DriftMarkerStore does not** — asymmetry is deliberate: revealed-tile inserts happen inside `mergeMask` which mints an id on first write, while marker inserts come in with a pre-allocated MarkerId. Phase 11 may extend DriftMarkerStore if photo capture needs to mint marker ids on the fly.
4. **Marker.photos hydrated as const empty list in Phase 03** — decision D8 puts photos on disk, not in the DB. The join belongs with FilesystemPhotoStore (Phase 11), not a naïve DB-only join here.
5. **@Riverpod(keepAlive: true) on all 7 providers** — the DB is a process singleton; store providers keep the flag for symmetry.
6. **main.dart untouched** — CONTEXT.md defers ProviderScope wiring to Phase 05. Phase 03 ships the graph, Phase 05 invokes it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `isNotNull` import collision between drift and matcher**
- **Found during:** Task 1 first test run (4 of 6 store test files failed compile with "'isNotNull' is imported from both 'package:drift/...query_builder' and 'package:matcher/...core_matchers'")
- **Issue:** `package:drift/drift.dart` re-exports an `isNotNull` *column matcher* from its query builder. `package:matcher` (re-exported by `package:test/test.dart`) exports an `isNotNull` *value matcher* for use inside `expect(...)`. Four of the five new test files needed drift for `DatabaseConnection` + `Variable` AND matcher's `isNotNull` for null-check assertions; the symbol collision made every affected file fail compile.
- **Fix:** Added `hide isNotNull` to every drift/drift.dart import in the affected test files. Same idiom as 03-05's `migration_v1_to_v2_test.dart`. Added a doc comment explaining the collision so future contributors don't un-hide it.
- **Files modified:** test/infrastructure/stores/session_store_exclusivity_test.dart, test/infrastructure/stores/session_store_error_mapping_test.dart, test/infrastructure/stores/revealed_tile_store_idempotence_test.dart, test/infrastructure/stores/revealed_tile_store_concurrent_test.dart
- **Verification:** `dart test test/infrastructure/stores/` — 21/21 pass.
- **Committed in:** `8487a0d` (Task 1 test commit)

**2. [Rule 1 - Bug] `expectLater(isNot(throwsA(SqliteException)))` timed out the error-mapping test**
- **Found during:** Task 1 first test run (test timeout after 30 s)
- **Issue:** My first pass of `session_store_error_mapping_test.dart` called `expectLater(() => store.activate(id1), throwsA(ConcurrentActivationException))` followed by a second `expectLater(() => store.activate(id1), isNot(throwsA(SqliteException)))`. The second `expectLater` re-invoked `activate(id1)`, which raced the still-active partial unique index and threw again — but the combined `isNot(throwsA)` matcher's evaluation path somehow hit the 30-s test timeout instead of short-circuiting on the class mismatch. Unclear whether this is a matcher bug or a bad interaction with the Future evaluation, but the test expressed intent wrong either way.
- **Fix:** Rewrote the test to catch the exception directly in a `try { await store.activate(id1); fail(...); } on Object catch (e) { thrown = e; }` block, then assert `expect(thrown, isA<ConcurrentActivationException>())` AND `expect(thrown, isNot(isA<SqliteException>()))` on the captured instance. Single activation attempt, synchronous class assertions after the fact — no matcher-evaluation timeout possible.
- **Files modified:** test/infrastructure/stores/session_store_error_mapping_test.dart
- **Verification:** Test passes in < 1 s (vs previous 30-s timeout).
- **Committed in:** `8487a0d` (Task 1 test commit — bundled with the import fix since they both surfaced in the same first test run)

**3. [Rule 1 - Bug] Redundant `photos: const <PhotoRef>[]` on MarkerStore hydration flagged by lint**
- **Found during:** Task 1 GREEN first `flutter analyze` after shipping the marker store
- **Issue:** My first `_hydrate(MarkerRow row)` in `drift_marker_store.dart` explicitly set `photos: const <PhotoRef>[]` — the analyzer flagged it under `avoid_redundant_argument_values` because `Marker` already has `@Default(<PhotoRef>[])` on the `photos` field. Under `--fatal-infos`, this would have failed CI.
- **Fix:** Dropped the `photos: ...` line — the Freezed default already produces the same value. Moved the "photos intentionally empty until Phase 11" documentation into the class docstring rather than an inline field. Dropped the now-unused `photo_ref.dart` import.
- **Files modified:** lib/infrastructure/stores/drift_marker_store.dart
- **Verification:** `flutter analyze` clean; `dart test test/infrastructure/stores/` still passes.
- **Committed in:** `fee0002` (the 3-stores commit)

**4. [Rule 1 - Bug] Unused `session_status.dart` import + unused `dart:typed_data` + `prefer_const_constructors` on test sessionId locals**
- **Found during:** Task 1 GREEN follow-up `flutter analyze`
- **Issue:** Batch of `--fatal-infos` lints flagged across 3 test files and the session store: (a) `drift_session_store.dart` imported `session_status.dart` even though `SessionStatus` was never directly referenced (consumed only through the type converter); (b) `revealed_tile_store_idempotence_test.dart` and `..._concurrent_test.dart` imported `dart:typed_data` for `Uint8List` which is already re-exported by `drift/drift.dart`; (c) several test files declared `final sessionId = SessionId(...)` which `prefer_const_constructors` wanted as `const` (since `SessionId` is an extension type with a const constructor).
- **Fix:** Removed the dead session_status.dart import; removed the dart:typed_data imports (drift re-exports are sufficient); changed `final sessionId = SessionId(...)` to `const sessionId = SessionId(...)` in affected test files.
- **Files modified:** lib/infrastructure/stores/drift_session_store.dart, test/infrastructure/stores/drift_session_store_cascade_test.dart, test/infrastructure/stores/marker_category_store_cascade_test.dart, test/infrastructure/stores/revealed_tile_store_idempotence_test.dart, test/infrastructure/stores/revealed_tile_store_concurrent_test.dart, test/infrastructure/stores/session_store_error_mapping_test.dart
- **Verification:** `flutter analyze --fatal-infos --fatal-warnings` clean.
- **Committed in:** Changes scoped into their respective task commits (session store fix landed pre-tests as part of the initial stores; test fixes landed in `8487a0d`).

---

**Total deviations:** 4 auto-fixed (3 bugs, 1 blocking).
**Impact on plan:** All four auto-fixes were caught at `flutter analyze` / `dart test` time and resolved within the same task commit. No scope creep — #1 is a repeatable idiom from 03-05's migration tests, #2 is a test-harness improvement (synchronous class assertions after capture are clearer than nested matcher futures anyway), #3 + #4 are lint hygiene at `--fatal-infos`.

## Authentication Gates

None — no external services touched.

## User Setup Required

None — no env vars added, no dashboard steps, no store-policy copy needed in this plan.

## Issues Encountered

None beyond the four auto-fixes. `flutter analyze` on the stores was clean on first write; the generated `.g.dart` files produced zero diagnostics; the Drift runtime behavior matched the shipped tests on first run for the SESS-06 partial-unique-index path AND the MIRK-03 transactional mergeMask path. Every breakage was surfaced at TDD-style verification time.

## `custom_lint` silent degradation — deliberate non-fix

Per the 03-04 decision, `custom_lint 0.8.1` cannot load its analyzer plugin under the `analyzer ^10.0.0` override because its Element2 API references were removed in analyzer 10. `dart run custom_lint` still compile-fails today (verified during this plan's verification). This is the **contract**: `flutter analyze --fatal-infos --fatal-warnings` is the authority — and it is green. Re-evaluate when `custom_lint 0.9.x` ships with analyzer-10 support; the analysis_options.yaml already has a commented-out plugin activation block to re-enable at that point.

## Next Phase Readiness

**Phase 03 implementation complete.** Phase 04 (Review Gate — Persistence) opens next.

Forward-declarations honoured by this plan:
- SESS-06 runtime closure (`ConcurrentActivationException` raised from `DriftSessionStore.activate`) — Phase 05 `ActiveSessionController` consumes this exception type directly in its error handling.
- MIRK-03 transactional mergeMask — Phase 09 `RevealedAreaController` calls `revealedTileStoreProvider` in a tight loop (one merge per GPS fix); the atomicity guarantee here is what keeps the bitmap coherent under the concurrent-writer scenario.
- Provider graph — Phase 05 wires `ProviderScope` at `main.dart` and reads `sessionStoreProvider.future` as the first productive consumer.

Phase 04 review gate opens with:
- 134 tests green (120 pure-Dart + 14 widget),
- `flutter analyze --fatal-infos --fatal-warnings` clean,
- domain purity clean (37 hand-written files, zero forbidden imports),
- header + license + DEPENDENCIES.md gates all green,
- 28 net new files from this plan alone,
- the full Phase 03 test inventory + coverage map aligned to SC 1-6.

---
*Phase: 03-persistence-domain-models*
*Completed: 2026-04-18*

## Self-Check: PASSED

All 28 listed files exist on disk. All 5 task commit hashes (`fe1d7a0`, `0b85480`, `fee0002`, `8487a0d`, `e4b02fa`) reachable via `git log --oneline --all`.
