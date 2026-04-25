---
phase: 09-fog-rendering
plan: 05
subsystem: mirk-rendering
tags: [riverpod, drift, sealed-switch, factory, freezed, migration, fog-of-war]

# Dependency graph
requires:
  - phase: 09-fog-rendering
    provides: 4 concrete MirkRenderer implementations (plan 09-04) + extended MirkPaintContext + 6-variant MirkStyleConfig (plan 09-02)
  - phase: 03-persistence-domain-models
    provides: MirkStyle entity, MirkStyleStore port, t_mirk_styles + t_sessions Drift tables, ActiveSessionState sealed hierarchy
provides:
  - "MirkRendererFactory.create(MirkStyleConfig) — sealed-switch dispatch resolving any of the 6 variants to its concrete renderer"
  - "kBuiltinMirkStyles registry constant — 4 BuiltinMirkStyleDescriptor entries in canonical UI order (atmospheric, solid, candlelight, heavenly_clouds)"
  - "mirkRendererFactoryProvider — Riverpod singleton (keepAlive: true) over the factory"
  - "builtinMirkStylesProvider — lazy-seeding @Riverpod async function inserting the 4 builtin MirkStyle rows into t_mirk_styles on first read; idempotent + self-healing"
  - "activeMirkRendererProvider — session-scoped Riverpod async provider resolving Session.mirkStyleId -> MirkStyle -> MirkStyleConfig -> concrete MirkRenderer with explicit fallback cascade and ref.onDispose lifecycle"
  - "Schema v4: t_sessions.mirk_style_id TEXT NULL REFERENCES t_mirk_styles(id) ON DELETE SET NULL — DB-side support for per-session style selection"
  - "Session.mirkStyleId nullable Freezed field with bespoke null-passthrough JSON converter pair (extension types cannot be Object? in JsonConverter)"
  - "FakeMirkStyleStore (test fake) — in-memory MirkStyleStore for provider/controller suites"
affects:
  - plan 09-06 (MirkStyleSessionController.select() will ref.invalidate(activeMirkRendererProvider) to swap renderers mid-session + Session.mirkStyleId UPDATE)
  - plan 09-07 (MirkOverlay reads ref.watch(activeMirkRendererProvider) for the live renderer; burger-menu picker reads ref.watch(builtinMirkStylesProvider) for the 4 entries)
  - phase 13 (delete-if-not-builtin semantics OPT-04 use the deterministic style_builtin_<variant> id prefix)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sealed-switch factory: exhaustive Dart 3 switch enforces 'add a variant -> edit 3 files' invariant via analyzer error on missing case"
    - "Lazy provider seed: @Riverpod build body inserts deterministic rows on first read instead of main.dart bootstrap; idempotent + self-healing"
    - "Bespoke nullable JSON converter pair for extension-type IDs in Freezed optional fields"
    - "Schema-sentinel timestamp: deterministic createdAtUtc (Phase 09 landing date 2026-04-25 UTC midnight, offset 0) for built-in rows — parallels cat_default's 2026-04-18"
    - "ON DELETE SET NULL for FK from session to style — degrades to renderer-side default rather than orphaning or cascade-deleting"
    - "ref.onDispose for renderer lifecycle: provider invalidation triggers exactly-one dispose() call on prior renderer (asserted via SpyingFactory + FakeMirkRenderer counter)"

key-files:
  created:
    - lib/infrastructure/db/migrations/v3_to_v4_session_mirk_style.dart
    - lib/application/providers/builtin_mirk_styles_provider.g.dart
    - lib/application/providers/mirk_renderer_factory_provider.g.dart
    - lib/application/providers/active_mirk_renderer_provider.g.dart
    - test/infrastructure/db/migrations/v3_to_v4_session_mirk_style_test.dart
    - test/application/providers/builtin_mirk_styles_provider_test.dart
    - test/application/providers/active_mirk_renderer_provider_test.dart
    - test/fakes/fake_mirk_style_store.dart
    - drift_schemas/drift_schema_v4.json
  modified:
    - lib/domain/sessions/session.dart
    - lib/infrastructure/db/app_database.dart
    - lib/infrastructure/stores/drift_session_store.dart
    - lib/infrastructure/mirk/mirk_renderer_factory.dart
    - lib/infrastructure/mirk/builtin_mirk_styles.dart
    - lib/infrastructure/mirk/shader_mirk_renderer.dart
    - lib/application/providers/mirk_renderer_factory_provider.dart
    - lib/application/providers/builtin_mirk_styles_provider.dart
    - lib/application/providers/active_mirk_renderer_provider.dart
    - drift_schemas/drift_schema_current.json
    - test/infrastructure/db/app_database_schema_test.dart
    - test/infrastructure/mirk/mirk_renderer_factory_test.dart

key-decisions:
  - "USER-APPROVED scope expansion (Task 0): land the missing v3 -> v4 schema migration + Session.mirkStyleId entity field as part of plan 09-05, since activeMirkRendererProvider (the consumer that motivates the column) lands in Tasks 1-3 of this same plan. Documented as Phase 03 work in 09-CONTEXT.md:159 but never shipped."
  - "FK semantics: ON DELETE SET NULL (NOT cascade or RESTRICT) — deleting a user-imported style degrades the session to the renderer-side default rather than orphaning or cascade-deleting the session row. Built-in styles are protected from deletion at the application layer in Phase 13 (OPT-04)."
  - "MirkStyleStore.findById was already on the Phase 03 port — no port extension needed (the plan note flagged it as a potential add, but findById has been in MirkStyleStore since 03-06)."
  - "UnknownConfig fallback degrades to AtmosphericMirkRenderer with default config (NOT NoopMirkRenderer). Rationale: forward-compat payloads should still render fog so the user sees something rather than a black/empty screen; the factory logs the degradation via Logger('infrastructure.mirk.factory')."
  - "ShaderConfig dispatches to ShaderMirkRenderer stub (Phase 13 body, paint() throws UnimplementedError). No V1.0 user path reaches this branch (the burger menu only surfaces the 4 builtins; user-imported shaders ship Phase 13 MIRK-08), but the factory must wire it for sealed-switch exhaustiveness."
  - "Lazy seed inside builtinMirkStylesProvider.build() rather than main.dart bootstrap. Trade-off: a consumer must read the provider to trigger the seed. Plan 09-07's burger-menu picker is the natural first reader. Until then the seed is dormant."
  - "Deterministic builtin IDs (style_builtin_atmospheric, style_builtin_solid, style_builtin_candlelight, style_builtin_heavenly_clouds) — NOT ULIDs. The id prefix doubles as a DB-layer marker of 'built-in' for Phase 13's OPT-04 delete-if-not-builtin semantics."
  - "BuiltinMirkStyleDescriptor as plain Dart class (NOT Freezed): internal registry record with no JSON / equality / copyWith needs."
  - "MirkStyleConfig Function() (factory) rather than const MirkStyleConfig literal in the descriptor: lets Phase 13 extend with runtime parameters (user-imported shader byte sources) without breaking the registry shape."
  - "Test scaffolding: _FakeActiveSessionController returns the seed SYNCHRONOUSLY from build() (the controller declares FutureOr<ActiveSessionState> build() so a sync return is contract-compatible). Async returns trigger Riverpod's loading-state path which races against the dependent provider's dispose chain in tests. Same pattern used by map_screen_test.dart."

patterns-established:
  - "Sealed-switch factory: 1 dispatcher + 1 registry + 1 sealed union = 3-file edit cost for a new variant, analyzer-enforced"
  - "Lazy provider seed: @Riverpod build body inserts deterministic rows on first read; idempotent + self-healing if rows are deleted out-of-band"
  - "Renderer lifecycle: ref.onDispose → renderer.dispose() exactly once per instance; tested via SpyingFactory + FakeMirkRenderer.disposeCallCount"
  - "Optional extension-type ID JSON: bespoke nullable converter pair (xxxFromJsonNullable / xxxToJsonNullable) for Freezed optional fields"

requirements-completed: [MIRK-05, MIRK-06, MIRK-07]

# Metrics
duration: 33 min
completed: 2026-04-25
---

# Phase 09 Plan 05: Renderer factory + builtin registry + active-renderer provider — Summary

**Three-layer wiring (factory + 4-builtin registry + 3 Riverpod providers) that makes the 4 concrete MirkRenderer implementations from plan 09-04 reachable from the UI layer, plus the long-deferred t_sessions.mirk_style_id schema v4 migration that the resolver depends on.**

## Performance

- **Duration:** ~33 min
- **Started:** 2026-04-25T05:46:35Z
- **Completed:** 2026-04-25T06:19:11Z
- **Tasks:** 4 (Task 0 scope expansion + Tasks 1, 2, 3 from original plan)
- **Files modified/created:** 21 (9 created + 12 modified)

## Accomplishments

- **Schema v4 migration shipped (Task 0 — user-approved scope expansion).** `t_sessions.mirk_style_id TEXT NULL REFERENCES t_mirk_styles(id) ON DELETE SET NULL` plus the matching `Session.mirkStyleId` Freezed field, store mapping, schema dump, and migration test (2/2 green: column exists / NULL default / writeable / SET NULL fires on delete).
- **MirkRendererFactory landed (Task 1).** Sealed-switch over the 6-variant `MirkStyleConfig` resolves each variant to its concrete renderer. `UnknownConfig` degrades to atmospheric default (logged); `ShaderConfig` -> Phase 13 stub. Adding a new variant now requires editing exactly 3 files — analyzer-enforced.
- **kBuiltinMirkStyles registry shipped (Task 1).** 4 descriptors in canonical UI order (atmospheric, solid, candlelight, heavenly_clouds) with deterministic `style_builtin_<variant>` IDs. Plain Dart class (not Freezed); the registry is a `const List<>` literal with `MirkStyleConfig Function()` tear-offs.
- **3 Riverpod providers wired (Tasks 2 + 3).** `mirkRendererFactoryProvider` (singleton, keepAlive), `builtinMirkStylesProvider` (lazy-seeding the 4 rows on first read; idempotent + self-healing), `activeMirkRendererProvider` (session-scoped, ref.onDispose lifecycle, falls back to atmospheric on null/missing styleId).
- **27 new tests (TDD where applicable).** 14 factory + registry, 5 builtin-styles-provider (seed / idempotence / self-heal / metadata / factory singleton), 8 active-renderer-provider (cascade + dispose lifecycle).

## Provider wiring diagram

```
                                            +--------------------------+
                                            | mirkRendererFactoryProvider |
                                            | (const singleton)        |
                                            +-------------+------------+
                                                          |
                                                          v
+---------------------------+      +---------------------------------+      +-----------------------+
| activeSessionController   |----->|  activeMirkRendererProvider     |<-----| sessionStoreProvider  |
| Provider                  |      |  (session-scoped, ref.onDispose)|      | (Future<SessionStore>)|
| (sealed: Idle/Starting/   |      |                                 |      +-----------+-----------+
|  Tracking)                |      | resolves: state -> SessionId    |                  |
+---------------------------+      |          -> Session.mirkStyleId |                  v
                                   |          -> MirkStyle.config    |       +----------+-----------+
                                   |          -> renderer            |       | mirkStyleStoreProvider|
                                   +---------------------------------+------>| (Future<MirkStyleStore>)
                                                          |                  +----------+-----------+
                                                          |                             |
                                                          v                             v
                                            +---------------------------+   +-----------+-----------+
                                            | concrete MirkRenderer     |   | builtinMirkStylesProvider|
                                            | (one of 6 variants;       |   | (4 builtins, lazy seed)  |
                                            |  Noop on Idle/Starting)   |   +--------------------------+
                                            +---------------------------+

Plan 09-06 wire-up (next plan): MirkStyleSessionController.select(styleId) ->
  1. sessionStore.update(session.copyWith(mirkStyleId: styleId))
  2. ref.invalidate(activeMirkRendererProvider)  // forces re-resolution
```

## Task Commits

1. **Task 0: schema v4 migration + Session entity field** — `0764a46` (feat)
2. **Task 1 RED: failing factory + registry tests** — `f02be5c` (test)
3. **Task 1 GREEN: factory + registry implementation** — `b7bb50a` (feat)
4. **Task 2: factory + builtin styles providers** — `5629eb3` (feat)
5. **Task 3: activeMirkRendererProvider + lifecycle** — `9c088c2` (feat)
6. **Format follow-up: dart-format reflow on builtin_mirk_styles_provider_test.dart** — `c4f9e8e` (chore)

## Files Created/Modified

### New (9)
- `lib/infrastructure/db/migrations/v3_to_v4_session_mirk_style.dart` — V3→V4 migration adding the `mirk_style_id` FK column.
- `lib/application/providers/builtin_mirk_styles_provider.g.dart` — generated Riverpod glue.
- `lib/application/providers/mirk_renderer_factory_provider.g.dart` — generated Riverpod glue.
- `lib/application/providers/active_mirk_renderer_provider.g.dart` — generated Riverpod glue.
- `test/infrastructure/db/migrations/v3_to_v4_session_mirk_style_test.dart` — 2 tests: column shape + ON DELETE SET NULL.
- `test/application/providers/builtin_mirk_styles_provider_test.dart` — 5 tests covering seed / idempotence / self-heal / metadata / factory singleton.
- `test/application/providers/active_mirk_renderer_provider_test.dart` — 8 tests covering the resolution cascade + lifecycle dispose.
- `test/fakes/fake_mirk_style_store.dart` — in-memory MirkStyleStore for tests.
- `drift_schemas/drift_schema_v4.json` — frozen V4 schema snapshot.

### Modified (12)
- `lib/domain/sessions/session.dart` — added nullable `MirkStyleId mirkStyleId` field with bespoke null-passthrough JSON converter pair.
- `lib/infrastructure/db/app_database.dart` — added `mirkStyleId` column on Sessions, bumped `schemaVersion` 3 → 4, wired `V3ToV4SessionMirkStyle.apply` into onUpgrade.
- `lib/infrastructure/stores/drift_session_store.dart` — `_hydrate` reads + `_toInsertCompanion` writes the new column.
- `lib/infrastructure/mirk/mirk_renderer_factory.dart` — sealed-switch dispatch over all 6 variants + UnknownConfig logging fallback.
- `lib/infrastructure/mirk/builtin_mirk_styles.dart` — `BuiltinMirkStyleDescriptor` class + `kBuiltinMirkStyles` const list with 4 entries.
- `lib/infrastructure/mirk/shader_mirk_renderer.dart` — constructor now accepts `ShaderConfig` (was no-arg) so Phase 13 has access without a future surface change.
- `lib/application/providers/mirk_renderer_factory_provider.dart` — promoted to `@Riverpod(keepAlive: true)` returning the const factory.
- `lib/application/providers/builtin_mirk_styles_provider.dart` — promoted to `@Riverpod(keepAlive: true)` async function with the lazy-seed body.
- `lib/application/providers/active_mirk_renderer_provider.dart` — promoted to `@riverpod` (NOT keepAlive — session-scoped) async function with the resolution cascade + ref.onDispose lifecycle.
- `drift_schemas/drift_schema_current.json` — refreshed to reflect V4.
- `test/infrastructure/db/app_database_schema_test.dart` — schemaVersion assertion bumped 3 → 4 + added explicit V4 mirk_style_id column probe.
- `test/infrastructure/mirk/mirk_renderer_factory_test.dart` — replaced Wave 0 skip-marker scaffold with 14 concrete dispatch + registry tests.

## Decisions Made

(extracted to `key-decisions:` frontmatter — see top of file)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Bumped `schemaVersion 3 → 4` in `app_database_schema_test.dart`**
- **Found during:** Task 0 (full test suite verification post-schema bump)
- **Issue:** Existing assertion `expect(db.schemaVersion, 3)` in `app_database_schema_test.dart` failed after the V4 bump.
- **Fix:** Updated the assertion to `expect(db.schemaVersion, 4)`, renamed the test, and added a parallel V4-specific test that PRAGMA-probes the new `mirk_style_id` column (TEXT, nullable).
- **Files modified:** `test/infrastructure/db/app_database_schema_test.dart`
- **Verification:** `flutter test test/infrastructure/db/app_database_schema_test.dart` — all 9 tests pass.
- **Committed in:** `0764a46` (Task 0 commit)

**2. [Rule 3 - Blocking] Added bespoke nullable JSON converter pair for `Session.mirkStyleId`**
- **Found during:** Task 0 (build_runner regeneration)
- **Issue:** `id_json_converters.dart` only exposes the non-null pair `mirkStyleIdFromJson(String) -> MirkStyleId` / `mirkStyleIdToJson(MirkStyleId) -> String`. json_serializable would have called the non-null converter with `null` if the field were `null`, throwing a type error.
- **Fix:** Added private top-level `_mirkStyleIdFromJsonNullable(String?)` and `_mirkStyleIdToJsonNullable(MirkStyleId?)` in `session.dart` with explicit null-passthrough semantics; wired via `@JsonKey`. The non-null pair stays single-purpose.
- **Files modified:** `lib/domain/sessions/session.dart`
- **Verification:** `flutter analyze --fatal-warnings --fatal-infos` zero issues; Session round-trip tests via `session_invariants_test.dart` (88 tests) all green.
- **Committed in:** `0764a46`

**3. [Rule 3 - Blocking] `ShaderMirkRenderer` constructor extended to accept `ShaderConfig`**
- **Found during:** Task 1 GREEN (factory dispatch implementation)
- **Issue:** Previous `ShaderMirkRenderer()` constructor took no args. The factory's exhaustive switch needs a `ShaderConfig` argument to thread through (and Phase 13 will need `config.shaderAssetPath` to load the .frag asset).
- **Fix:** Added `final ShaderConfig config` field + constructor parameter. Body still throws `UnimplementedError` — Phase 13 implements the actual paint logic.
- **Files modified:** `lib/infrastructure/mirk/shader_mirk_renderer.dart`
- **Verification:** No callers in V1.0 (the burger menu only surfaces the 4 builtins). Existing tests for the stub pass without modification.
- **Committed in:** `b7bb50a` (Task 1 GREEN)

**4. [Rule 3 - Blocking] Switched `_FakeActiveSessionController.build()` from async to sync**
- **Found during:** Task 3 test execution (8/8 tests failed with "provider was disposed during loading state")
- **Issue:** Returning `Future<ActiveSessionState>` from `build()` triggered Riverpod's loading-state path. The dependent `activeMirkRendererProvider`'s dispose chain raced against the loading future, and all 8 tests failed.
- **Fix:** Switched to `ActiveSessionState build() => _initial` (sync). The controller declares `FutureOr<ActiveSessionState> build()` so a sync return is contract-compatible. Same pattern used by `map_screen_test.dart`'s `_FakeActiveSessionController`.
- **Files modified:** `test/application/providers/active_mirk_renderer_provider_test.dart`
- **Verification:** 8/8 tests now pass.
- **Committed in:** `9c088c2` (Task 3 commit)

**5. [Rule 3 - Blocking] Added `// ignore: avoid_redundant_argument_values` on the explicit-null mirkStyleId test case**
- **Found during:** Task 3 (`flutter analyze --fatal-warnings --fatal-infos`)
- **Issue:** Test case `Tracking + null mirkStyleId → AtmosphericMirkRenderer` passed `mirkStyleId: null` explicitly to `_buildSession`. The lint flagged it as redundant (null IS the default).
- **Fix:** Added a narrow `// ignore: avoid_redundant_argument_values` directive with a justification comment explaining the explicit null is load-bearing for test readability (the SUT's fallback trigger).
- **Files modified:** `test/application/providers/active_mirk_renderer_provider_test.dart`
- **Verification:** `flutter analyze --fatal-warnings --fatal-infos` zero issues.
- **Committed in:** `9c088c2`

---

**Total deviations:** 5 auto-fixed (5 Rule 3 - Blocking) — all directly caused by the plan's own diff (schema bump, sealed-switch dispatch, test scaffolding). Zero deviations escalated to Rule 4 (architectural). The originally-flagged Rule 4 (the missing v3→v4 migration) was promoted to a USER-APPROVED Task 0 expansion rather than a deviation.

**Impact on plan:** All auto-fixes essential for correctness or testability. No scope creep beyond the user-approved Task 0 expansion.

## Issues Encountered

- **Pre-existing flake:** `test/infrastructure/downloads/atomic_renamer_test.dart::AtomicRenamer — happy paths overwrites an existing target file` fails under full-suite parallel execution but passes in isolation (`flutter test test/infrastructure/downloads/atomic_renamer_test.dart` → 9/9 green). Logged in `.planning/phases/09-fog-rendering/deferred-items.md` for Phase 10 review-gate or follow-up `chore(test)` commit.
- **Auto-format reflow on related files:** `dart format` running on Task 0 files cascaded a format reflow onto pre-existing files (e.g., `mirk_style.dart`, `app.dart`). These were reverted to keep commits minimal/focused — they're unrelated to plan 09-05 and would be picked up by the deferred Phase 04-05 project-wide format pass logged in `phase 04-05 deferred-items.md`.

## User Setup Required

None — no external service configuration required. All changes are local Drift schema + Riverpod wiring + Dart code.

## Next Plan Readiness

Ready for **plan 09-06** (`MirkStyleSessionController` + `RevealStreamingController`). Plan 09-06 will:

1. Use `Session.mirkStyleId` (V4 schema) to persist user style picks via `sessionStore.update(session.copyWith(mirkStyleId: styleId))`.
2. Call `ref.invalidate(activeMirkRendererProvider)` to force renderer re-resolution.
3. Read `ref.watch(builtinMirkStylesProvider)` for the 4-entry picker list.

The factory's exhaustiveness invariant ("ajouter un style = nouveau fichier + 3 core edits") is now structurally enforced — adding a 5th variant requires the analyzer to accept the new switch case before plan 09-06 / 09-07 can compile.

## Sealed-switch exhaustiveness proof outcome (optional verification)

Not attempted in this plan — the proof is well-established in the existing Phase 09 codebase (`drift_mirk_style_store.dart::_rendererTypeFor` and `mirk_style_config_fromjson_test.dart::exhaustive-switch` both rely on the same exhaustiveness contract). The factory adds a third witness; collectively the contract is triple-protected. A targeted "remove a case, watch the analyzer fail" experiment can be re-run at the Phase 10 review-gate if desired.

## Self-Check: PASSED

All 9 created files exist on disk; all 6 commits (`0764a46`, `f02be5c`, `b7bb50a`, `5629eb3`, `9c088c2`, `c4f9e8e`) reachable via `git log`.

---
*Phase: 09-fog-rendering*
*Plan: 09-05*
*Completed: 2026-04-25*
