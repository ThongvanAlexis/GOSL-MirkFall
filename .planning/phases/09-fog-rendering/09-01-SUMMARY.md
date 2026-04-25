---
phase: 09-fog-rendering
plan: 01
subsystem: infra
tags: [constants, fog-rendering, dart-test-tags, style-layer-order, regression-test]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: kRevealedTileParentZoom (D3 — zoom-14 parent tiles + 64x64 sub-grid) — Phase 09 reuses, does NOT duplicate
  - phase: 07-map-integration
    provides: kStyleLayerOrder + kInitialRevealRadiusMeters — Phase 09 docstrings extend, value preserved
provides:
  - 19 new Phase 09 tunables in lib/config/constants.dart (reveal radius/flush cadence + atmospheric/candlelight/heavenly-clouds/solid renderer defaults)
  - mirk-perf dart_test tag (timeout 10x) for Wave 7 50k-tile perf probe
  - Phase 11 append-above-mirk_fog contract documented on kStyleLayerOrder docstring
  - test/constants_test.dart Phase 09 regression group (20 assertions)
affects: [09-01b, 09-01c, 09-02, 09-03, 09-04, 09-05, 09-06, 09-07, 09-08, 11-poi-icons]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Phase 09 tunables hoisted into single lib/config/constants.dart block — downstream renderers + reveal streaming import named symbols, never literals (CLAUDE.md §Magic numbers)"
    - "Cross-phase symbol reuse — kRevealedTileParentZoom declared once in Phase 03 block, consumed (not duplicated) in Phase 09 block"
    - "dart_test tag discipline — heavyweight tests (mirk-perf alongside soak / migration / integration) excluded from default suite, gated by explicit --tags flag"

key-files:
  created:
    - test (modified) — test/constants_test.dart Phase 09 group
  modified:
    - lib/config/constants.dart (19 new constants appended in Phase 09 block)
    - dart_test.yaml (mirk-perf tag added)
    - lib/infrastructure/map/style_layer_order.dart (kStyleLayerOrder docstring extended; constant value unchanged)
    - test/constants_test.dart (Phase 09 group appended; pre-existing Phase 01 + Phase 07 groups preserved)

key-decisions:
  - "kRevealedTileParentZoom NOT duplicated — Phase 09 reuses the Phase 03 D3 declaration at lib/config/constants.dart:75 (single source of truth, no shadowing)"
  - "kDefaultRevealRadiusMeters (25.0) co-exists with kInitialRevealRadiusMeters (20) — both are intentional per 09-CONTEXT.md §Géométrie du reveal (25 m default for in-session, 20 m initial pop-in at startSession)"
  - "DB flush cadence 2 s / 20 fixes (amended from ROADMAP's 5 s / 50 fixes) — user decision in 09-CONTEXT.md, hot-tunable in dev"
  - "kStyleLayerOrder constant value unchanged — Phase 11 markers will APPEND a new layer id at end (after mirk_fog), never reorder existing 7 entries; 30%-alpha-under-mirk composite trick is delivered via MapLibre annotations (addCircle / addSymbol), not by interleaving a markers layer below mirk_fog (per 09-RESEARCH §Rendering Strategy Decision)"
  - "mirk-perf tag follows soak / migration / integration excluded-from-default discipline — gated by explicit `flutter test --tags mirk-perf test/performance/`"

patterns-established:
  - "Phase-scoped constant block — each major phase appends its tunables under a clearly-commented block (Phase 03 / Phase 05 / Phase 07 / Phase 09) so cross-phase reuse is visually anchored"
  - "Test-tag namespacing — heavyweight tests get a phase-specific tag (`mirk-perf` for Phase 09, `soak` for Phase 07, `migration` for Phase 03) excluded from default suite, gated by explicit --tags flag"

requirements-completed: [MIRK-02, MIRK-04, MIRK-05, MIRK-06]

# Metrics
duration: 6 min
completed: 2026-04-25
---

# Phase 09 Plan 01: Fog-Rendering Constants + Test Scaffolding Summary

**Wave 0 scaffold (Part 1 of 3) — declares 19 Phase 09 tunable constants, registers `mirk-perf` dart_test tag, documents Phase 11 append-above-mirk_fog contract on `kStyleLayerOrder` docstring, and adds 20-assertion regression test group; zero production behaviour change.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-25T03:35:31Z
- **Completed:** 2026-04-25T03:41:09Z
- **Tasks:** 3 / 3
- **Files modified:** 4

## Accomplishments

- 19 new Phase 09 constants (reveal geometry, DB flush cadence, atmospheric / candlelight / heavenly-clouds / solid renderer defaults) declared in `lib/config/constants.dart` with full dartdoc; downstream plans 09-01b, 09-02, 09-04, 09-05, 09-06, 09-07, 09-08 can now import named symbols.
- `mirk-perf` test tag registered in `dart_test.yaml` (timeout `10x`) — Wave 7 perf probe (`test/performance/fog_50k_tiles_perf_test.dart`) can now annotate `@Tags(['mirk-perf'])` without "tag not specified" warnings.
- `kStyleLayerOrder` docstring documents the Phase 11 append-above-mirk_fog contract (constant value unchanged at 7 entries `[background, landcover, water, boundaries, roads, pois, mirk_fog]`) — protects the 30%-alpha-under-mirk composite trick from accidental refactor.
- `test/constants_test.dart` gains a 20-assertion `group('Phase 09 constants', ...)` regression guard — value + type guard on every new tunable plus a cross-phase guard on `kRevealedTileParentZoom`. Existing Phase 01 + Phase 07 groups preserved (append-only).

## Task Commits

Each task was committed atomically:

1. **Task 1: Append Phase 09 constants to constants.dart** — `1944c18` (feat)
2. **Task 2: Extend dart_test.yaml + style_layer_order.dart docstring** — `57c75e0` (chore)
3. **Task 3: Append Phase 09 regression group to constants_test.dart** — `fd158f3` (test)

**Plan metadata commit:** *pending* (created with this SUMMARY.md)

## Files Created/Modified

- `lib/config/constants.dart` — 19 new Phase 09 constants appended under `// Phase 09 — Fog Rendering` block. Note documents that `kRevealedTileParentZoom` is reused from the Phase 03 block above (line 75), not duplicated.
- `dart_test.yaml` — `mirk-perf` tag added with `timeout: 10x`, alongside existing `migration` / `soak` / `integration` tags. Gate command: `flutter test --tags mirk-perf test/performance/`.
- `lib/infrastructure/map/style_layer_order.dart` — `kStyleLayerOrder` docstring extended with Phase 11 append-contract paragraph. Constant value unchanged.
- `test/constants_test.dart` — `group('Phase 09 constants', ...)` appended with 20 `test(...)` cases (one per new constant + cross-phase `kRevealedTileParentZoom` guard). Existing Phase 01 + Phase 07 assertions preserved.

## Decisions Made

- **`kRevealedTileParentZoom` NOT duplicated** — already declared in the Phase 03 block at line 75. The plan explicitly allowed either hoisting or cross-referencing; cross-referencing was chosen because the symbol already lives in the right place under the Phase 03 D3 invariant. The new Phase 09 comment block contains a `NOTE` pointing readers to the Phase 03 declaration so future contributors don't redeclare.
- **Constants block placement** — appended to the END of `constants.dart`, AFTER the Phase 07 block, mirroring the existing per-phase ordering convention (Phase 01 root → Phase 03 → Phase 05 → Phase 07 → Phase 09). Preserves a chronological-historical narrative when reading top-to-bottom.
- **`test/constants_test.dart` left on `flutter_test`, not migrated to pure `dart test`** — the plan suggested "pure `dart test` file" but the existing file already imports `package:flutter_test/flutter_test.dart` (set up by FOUND-07 / Phase 01). Migrating to pure `dart test` would have required overwriting the file (forbidden by the plan's "if exists, APPEND only" directive) and would have changed the runner for the existing 20 Phase 01 + Phase 07 assertions. Append-only preserves the existing harness.

## Deviations from Plan

None — plan executed exactly as written.

The single notable judgement call (whether to duplicate `kRevealedTileParentZoom` or cross-reference) was explicitly delegated to the executor by the plan's NOTE block ("if this constant already exists elsewhere, DO NOT duplicate — reuse"). The cross-reference path was chosen and documented in-place via a `NOTE:` comment in the Phase 09 block.

## Issues Encountered

**Out-of-scope analyzer errors observed (NOT introduced by Plan 09-01)**

`flutter analyze --fatal-warnings --fatal-infos` at full-project scope reports 6 errors in `test/infrastructure/mirk/{atmospheric,candlelight,heavenly_clouds,solid_fill}_mirk_renderer_test.dart` (`argument_type_not_assignable` on the `skip:` parameter). These errors:

1. Were introduced by prior plans 09-01b (commit `68cfd54`) and 09-01c (commit `4d19408`), NOT by Plan 09-01.
2. Live entirely in files NOT listed in Plan 09-01's `<files_modified>` frontmatter.
3. Are already documented in `.planning/phases/09-fog-rendering/deferred-items.md` (an entry was added at Plan 09-01 close to flag the persistence).

Per the GSD SCOPE BOUNDARY rule, these errors were NOT auto-fixed during Plan 09-01 — fixing them would breach scope and modify files outside the plan's declared surface. Suggested owner: Plan 09-02 (`AtmosphericMirkRenderer` impl) — the natural integration point for aligning the `*_renderer_test.dart` test signatures with the real renderer constructor.

**Plan 09-01-only verification (in scope) is GREEN:**

- `dart format --set-exit-if-changed` on the 4 modified files: clean.
- `flutter analyze` on the 3 modified Dart files (`constants.dart`, `style_layer_order.dart`, `constants_test.dart`): *No issues found! (ran in 1.1s)*.
- `flutter test test/constants_test.dart`: 40 / 40 tests pass (5 root + 15 Phase 07 + 20 Phase 09).
- `flutter test test/presentation/map_style_layer_order_test.dart`: 3 / 3 tests pass (constant value unchanged confirmed).
- `flutter test --tags mirk-perf`: tag recognized, no warning, no tests match the (intentionally empty) selector — Wave 7 perf probe slot is reserved.
- `grep "Phase 11 will APPEND" lib/infrastructure/map/style_layer_order.dart`: 1 occurrence — docstring contract documented.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Plan 09-01b** (lib/ scaffolds — already executed in prior session, commit `68cfd54`) — its constants imports now resolve. SUMMARY.md not yet created (separate orchestration task).
- **Plan 09-01c** (test/tool scaffolds — already executed in prior session, commit `4d19408`) — `mirk-perf` tag now registered, perf probe slot reserved. SUMMARY.md not yet created.
- **Plan 09-02** (Wave 2 — `AtmosphericMirkRenderer` real impl) — can now consume `kMirkNoiseScaleDefault`, `kMirkNoiseSpeedDefault`, `kMirkDriftDirectionDegDefault`, `kDefaultMirkBaselineAlpha`, `kDefaultRevealRadiusMeters`, `kFeatherRadiusFraction`, `kRevealedTileParentZoom` as named imports. Should also fix the deferred `*_renderer_test.dart` `skip:` errors as a bundle.
- **Plans 09-04, 09-05, 09-06, 09-07, 09-08** (Wave 3-7) — all constant imports unblocked.

---
*Phase: 09-fog-rendering*
*Plan: 01*
*Completed: 2026-04-25*

## Self-Check: PASSED

- `lib/config/constants.dart` — FOUND (Phase 09 block appended, 19 new constants).
- `dart_test.yaml` — FOUND (`mirk-perf` tag registered).
- `lib/infrastructure/map/style_layer_order.dart` — FOUND (docstring extended, value unchanged).
- `test/constants_test.dart` — FOUND (`group('Phase 09 constants', ...)` appended).
- `.planning/phases/09-fog-rendering/09-01-SUMMARY.md` — FOUND (this file).
- `.planning/phases/09-fog-rendering/deferred-items.md` — FOUND (Plan 09-01 deferred-entry appended).
- Commit `1944c18` (Task 1) — FOUND in git log.
- Commit `57c75e0` (Task 2) — FOUND in git log.
- Commit `fd158f3` (Task 3) — FOUND in git log.
