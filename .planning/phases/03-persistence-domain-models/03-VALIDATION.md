---
phase: 03
slug: persistence-domain-models
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `package:test` 1.30.0 (already pinned Phase 02 dev_dependency) + Drift test utilities (`NativeDatabase.memory()`, `SchemaVerifier`) |
| **Config file** | None required (optional `dart_test.yaml` for tags; not a blocker) |
| **Quick run command** | `dart test test/domain/ -r compact` (domain-only, seconds) |
| **Full suite command** | `dart test test/` |
| **Estimated runtime** | ~30-60s full suite (in-memory DB) |

**Ubuntu CI prerequisite:** `sudo apt-get install -y libsqlite3-0 libsqlite3-dev` must run in the `gates` job BEFORE the `dart test` step (Wave 0 CI gap).

---

## Sampling Rate

- **After every task commit:** Run `dart test test/<lens>` (domain-only, infra-only, or migration-only depending on task focus — sub-30s)
- **After every plan wave:** Run `dart test test/` (full suite, ~30-60s)
- **Before `/gsd:verify-work`:** Full suite must be green in CI `gates` job
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

> Plan IDs will be finalized by the gsd-planner. Rows below map each success criterion / requirement ID to the test file and command that proves it. `Plan` / `Wave` / `Task ID` columns will be filled by the planner once PLAN.md files are produced.

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| SESS-06 | Double-activation fails with DB constraint, not caller assertion | integration | `dart test test/infrastructure/stores/session_store_exclusivity_test.dart` | ❌ W0 | ⬜ pending |
| SESS-06 | Partial unique index `idx_t_sessions_status_active` exists in schema | schema | `dart test test/infrastructure/db/app_database_schema_test.dart` | ❌ W0 | ⬜ pending |
| SESS-06 | `SqliteException 2067` → `ConcurrentActivationException` mapping | unit | `dart test test/infrastructure/stores/session_store_error_mapping_test.dart` | ❌ W0 | ⬜ pending |
| SESS-06 | `@Assert` invariants (empty displayName → `AssertionError`) | unit | `dart test test/domain/session_invariants_test.dart` | ❌ W0 | ⬜ pending |
| MIRK-03 | Setting a bit cannot unset it (OR-monotone at store level) | integration | `dart test test/infrastructure/stores/revealed_tile_store_idempotence_test.dart` | ❌ W0 | ⬜ pending |
| MIRK-03 | `Uint8List | Uint8List` merge is idempotent and commutative (pure) | unit | `dart test test/domain/reveal_calculator_test.dart` | ❌ W0 | ⬜ pending |
| MIRK-03 | Concurrent writes → final bitmap = OR of both masks | integration | `dart test test/infrastructure/stores/revealed_tile_store_concurrent_test.dart` | ❌ W0 | ⬜ pending |
| MIRK-03 | Schema contract (bitmap BLOB NOT NULL + unique key) | schema | `dart test test/infrastructure/db/app_database_schema_test.dart` | ❌ W0 | ⬜ pending |
| SC#1 | `PRAGMA journal_mode=wal`, `synchronous=1`, `busy_timeout=5000` | integration | `dart test test/infrastructure/db/app_database_pragma_test.dart` | ❌ W0 | ⬜ pending |
| SC#1 | V1 seed loads, schema dump matches canonical (V1→V1 identity) | migration | `dart test test/infrastructure/db/v1_identity_fixture_test.dart` | ❌ W0 | ⬜ pending |
| SC#4 | `lib/domain/` zero Flutter / Drift imports | static | `dart test tool/test/check_domain_purity_test.dart` (via `tool/check_domain_purity.dart`) | ❌ W0 | ⬜ pending |
| SC#5 | `tile_math` + `reveal_calculator` run under `dart test` (no Flutter in graph) | unit | `dart test test/domain/tile_math_test.dart test/domain/reveal_calculator_test.dart` | ❌ W0 | ⬜ pending |
| SC#5 | `JsonMigrator` identity v1 + slot v2 (rename `mirk_radius_m` → `reveal_radius_m`) | unit | `dart test test/domain/json_migrator_test.dart test/domain/json_migrator_v1_to_v2_test.dart` | ❌ W0 | ⬜ pending |
| SC#6 | Pre-migration backup file created before `onUpgrade` | integration | `dart test test/infrastructure/db/backup_test.dart` | ❌ W0 | ⬜ pending |
| SC#6 | Row-count regression → `MigrationFailureException` | integration | `dart test test/infrastructure/db/schema_sanity_test.dart` | ❌ W0 | ⬜ pending |
| SC#6 | V1→V2 fictive migration preserves rows, `notes` column writeable | migration | `dart test test/infrastructure/db/migration_v1_to_v2_test.dart` (via `SchemaVerifier`) | ❌ W0 | ⬜ pending |
| — (ULID) | 26 chars, Crockford base32, timestamp monotonic, k-sortable | unit | `dart test test/infrastructure/ids/ulid_test.dart` | ❌ W0 | ⬜ pending |
| — (IdGen) | Seeded IdGenerator → reproducible IDs | unit | `dart test test/infrastructure/ids/seeded_id_generator_test.dart` | ❌ W0 | ⬜ pending |
| — (cascade) | Delete session → markers + revealed_tiles gone | integration | `dart test test/infrastructure/stores/drift_session_store_cascade_test.dart` | ❌ W0 | ⬜ pending |
| — (cascade) | Delete category → markers reassigned to `cat_default` | integration | `dart test test/infrastructure/stores/marker_category_store_cascade_test.dart` | ❌ W0 | ⬜ pending |
| — (style) | Unknown `rendererType` JSON → `UnknownConfig(raw)` fallback | unit | `dart test test/domain/mirk_style_config_fromjson_test.dart` | ❌ W0 | ⬜ pending |
| — (tz) | DateTime UTC + offset round-trip, ISO 8601 export with `+HH:MM` | unit | `dart test test/domain/session_timezone_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All test files above are **new** — the project has no Phase 03 tests yet. Wave 0 of the plan MUST include:

- [ ] `test/fixtures/drift_schemas/drift_schema_v1.json` — produced by `dart run drift_dev schema dump`, committed
- [ ] `test/fixtures/drift_schemas/drift_schema_v2.json` — idem after V1→V2 fictive is added
- [ ] `test/generated_migrations/` — produced by `dart run drift_dev schema generate ... --data-classes --companions`, committed
- [ ] `test/fixtures/db_seed/v1_baseline.sql` — hand-written INSERT statements (10 sessions, 50 markers, 5 tiles, 3 categories, 2 styles) for V1 identity test
- [ ] `test/fixtures/json/session_v1.json` — sample session envelope for JsonMigrator
- [ ] `test/fixtures/json/mirk_style_unknown_renderer.json` — malformed-rendererType sample for UnknownConfig fallback
- [ ] `tool/check_domain_purity.dart` + `tool/test/check_domain_purity_test.dart` — grep-based static purity check
- [ ] `dart_test.yaml` (optional) — `migration` tag for slower tests
- [ ] CI `gates` step addition: `sudo apt-get install -y libsqlite3-0 libsqlite3-dev` BEFORE `dart test`
- [ ] CI `gates` step addition: `dart run drift_dev schema dump lib/.../app_database.dart drift_schemas/ && git diff --exit-code drift_schemas/` — guard against forgotten regen
- [ ] Dev-dep resolution: `custom_lint` + `riverpod_lint` at compatible versions (Research Open Question #1 — resolve via scratch-branch `pub get` as first task)

---

## Manual-Only Verifications

*None — all phase behaviors have automated verification.*

Rationale: Phase 03 is pure persistence + pure Dart domain. No UI surface, no device-specific hardware, no user interaction required for verification. Everything runs under `dart test` with an in-memory Drift DB.

---

## SESS-06 & MIRK-03 Coverage Matrix

| Requirement | Layer tested | Test type | Test command | Covers angle |
|-------------|--------------|-----------|--------------|-------------|
| **SESS-06** | Domain (invariants) | unit | `dart test test/domain/session_invariants_test.dart` | Dart-level `@Assert` for obvious caller misuse |
| **SESS-06** | DB schema shape | schema | `dart test test/infrastructure/db/app_database_schema_test.dart` | Partial unique index exists on `status` with `WHERE status='active'` |
| **SESS-06** | DB enforcement at runtime | integration | `dart test test/infrastructure/stores/session_store_exclusivity_test.dart` | Two concurrent activation paths → one wins, other gets `ConcurrentActivationException` (wrapped from `SqliteException 2067`) |
| **SESS-06** | Store error mapping | unit | `dart test test/infrastructure/stores/session_store_error_mapping_test.dart` | `SqliteException 2067` → `ConcurrentActivationException`; other codes rethrow |
| **MIRK-03** | Pure bitmap algebra | unit | `dart test test/domain/reveal_calculator_test.dart` | `a \| b ≥ a` bitwise; `(a \| b) \| a == a \| b`; idempotence |
| **MIRK-03** | Store idempotence | integration | `dart test test/infrastructure/stores/revealed_tile_store_idempotence_test.dart` | Apply same mask twice → unchanged; additive mask → OR-merge; no bit ever turns off |
| **MIRK-03** | Concurrent writes | integration | `dart test test/infrastructure/stores/revealed_tile_store_concurrent_test.dart` | Two writes via `Future.wait` → final = OR of both masks; `setBitCount` matches popcount |
| **MIRK-03** | Schema contract | schema | `dart test test/infrastructure/db/app_database_schema_test.dart` | `t_revealed_tiles` has `bitmap BLOB NOT NULL` + unique `(session_id, parent_x, parent_y, parent_zoom)` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (test files + fixtures + CI system deps)
- [ ] No watch-mode flags (`--watch`, etc.)
- [ ] Feedback latency < 60s (full suite) / < 30s (per-task)
- [ ] `nyquist_compliant: true` set in frontmatter once planner fills Task IDs + planner confirms the above

**Approval:** pending — gsd-planner to flip `nyquist_compliant: true` and map Task IDs once PLAN.md files are produced.
