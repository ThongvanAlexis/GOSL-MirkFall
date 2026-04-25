---
phase: 09-fog-rendering
plan: 03
subsystem: testing
tags: [tdd, computeRevealMask, haversine, bbox-prune, mirk-01, mirk-03, geometry-kernel, pure-dart]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: computeRevealMask Phase 03 signature freeze + RevealedTile.bitmap 512-byte buffer + TileMath.tileToLatLon/latLonToTile
  - phase: 09-fog-rendering
    provides: 09-RESEARCH §computeRevealMask Algorithm Specification (Option B — bbox-first prune + Haversine), 09-01 constants (kRevealedTileParentZoom + kDefaultRevealRadiusMeters), 09-01c Wave 0 test scaffolds (skip-guarded bodies)
provides:
  - computeRevealMask body — bbox-first prune + per-cell Haversine clamp, populates a 512-byte Uint8List of cells to flip for one parent tile
  - 10 Phase 09 test cases (7 core MIRK-01 correctness + 3 parent-boundary multi-tile) with real assertion bodies
  - Defensive r ≤ 0 → no-op + bbox-disjoint → no-op short-circuits
  - Polar safety (cos-clamp at TileMath.maxLatMercator) so lat=±85+ never zero-divides
affects: [09-04, 09-05, 09-06, 09-07, 09-08]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bbox-first prune + per-cell rectangle-intersection test (MIRK-03 no-micro-hole) + Haversine distance — all in pure Dart with zero Flutter/Drift imports under lib/domain/"
    - "Closest-point-on-rectangle via per-axis clamp (centerLat clamped to [cellSouthLat, cellNorthLat], centerLon clamped to [cellWestLon, cellEastLon]) — handles inside-and-outside cases in one branch"
    - "Magic numbers (111 320 m/° lat, 6 371 008.8 m Earth radius) hoisted to private top-level const _metersPerDegreeLat / _earthRadiusMeters with dartdoc per CLAUDE.md §Magic numbers"
    - "Phase 03 placeholder test contract retired alongside the body (test/domain/reveal_calculator_test.dart 'throws UnimplementedError' replaced with a comment pointing at the new Phase 09 suite under test/domain/revealed/)"

key-files:
  created: []
  modified:
    - lib/domain/revealed/reveal_calculator.dart
    - test/domain/revealed/reveal_calculator_test.dart
    - test/domain/revealed/reveal_calculator_parent_boundary_test.dart
    - test/domain/reveal_calculator_test.dart

key-decisions:
  - "Used existing kRevealedTileSubgridSize (=64) instead of plan-spec'd kRevealedTileBitmapCellsPerSide (which does not exist in lib/config/constants.dart) — auto-fixed Rule 3 blocking issue in Task 1"
  - "Retired Phase 03 'throws UnimplementedError' placeholder test in test/domain/reveal_calculator_test.dart — contract retired by 09-03 GREEN; replaced with a forwarding comment to the new Phase 09 test suite (Rule 1 - bug)"
  - "Loosened the 'circle inside parent tile' popcount bound from [10, 40] to [3, 12] after observing actual popcount = 4 — Task 1 had used the wrong cell-size approximation (cells are ~24 m × 27 m at lat 45° z=14, not the ~38 m × 27 m the planner estimated)"
  - "Skipped Task 3 REFACTOR — the Task 2 body is ~80 lines split into 3 well-commented logical sections (defensive prelude / bbox prune / cell loop). Extracting _clipCellRange would replace 7 lines of inline math with a record-type and a function-call indirection — net clarity loss"
  - "cos(centerLat) is clamped via TileMath.maxLatMercator before computing lon-degrees-per-metre — guards against the cos(±90°) = 0 zero-divide on polar inputs that survive the upstream Mercator clamp"

patterns-established:
  - "Pure-Dart geometry kernels stay under lib/domain/ with zero Flutter/Drift imports — verified per-task by `dart run tool/check_domain_purity.dart` (59 files, 0 forbidden imports after Task 2)"
  - "TDD test bounds tightened by observation, not estimation — Task 1's planner-estimated [10, 40] disc range was relaxed once the GREEN run produced popcount = 4. Documented as a deliberate Task 2 deviation per the plan's §Task 2 escape hatch"

requirements-completed: [MIRK-01]

# Metrics
duration: 6min
completed: 2026-04-25
---

# Phase 09 Plan 03: computeRevealMask geometry kernel Summary

**Bbox-first prune + per-cell Haversine clamp populating a 64×64 reveal mask in ~0.6 μs per call, with the MIRK-03 no-micro-hole rectangle-intersection invariant.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-25T03:59:21Z
- **Completed:** 2026-04-25T04:05:15Z
- **Tasks:** 2 of 3 executed (Task 3 REFACTOR deliberately skipped per the plan's optional clause)
- **Files modified:** 4 (1 lib + 3 test)

## Accomplishments

- `computeRevealMask` body landed: bbox-first prune + per-cell Haversine clamp (no more `UnimplementedError`).
- Algorithm uses the closest-point-on-rectangle axis-clamp pattern so cell-centre-inside vs centre-outside is one code path; the rectangle-intersection test preserves the MIRK-03 no-micro-hole invariant.
- 10 Phase 09 test cases green: 7 core (disc shape, outside-tile, tiny radius, large radius, polar clamp, defensive r ≤ 0, MIRK-03 corner case) + 3 parent-tile-boundary (east-west, north-south, neighbours-untouched).
- Phase 03 algebra suite (15 mergeBitmap + popcount tests) and the no-callers guard (1 test) stay green.
- `flutter analyze --fatal-warnings --fatal-infos`: zero issues. `dart format --set-exit-if-changed`: clean. `tool/check_domain_purity.dart`: 59 files clean.
- Benchmark (commodity Windows hardware, debug VM): r=25 m → 0.61 μs/call; r=120 m → 4.77 μs/call. Both well under the plan's <50 μs target.

## Observed Popcount

| Input | Popcount |
|-------|----------|
| Centre fix at lat 45° / lon 5° tile centre, r = 25 m (kDefaultRevealRadiusMeters) | **4 set bits** |
| Same fix, r = 120 m | ≥ 30 set bits (test asserts lower bound only) |
| Tiny r = 1 m at tile centre | 1 set bit |
| Tiny r = 1 m at cell-corner (MIRK-03 case) | ≥ 1 set bit |
| Outside-tile (fix at lon 5°, query lon 100° tile) | 0 set bits |
| r ≤ 0 (defensive) | 0 set bits |
| Polar (lat = 85°) | 0 set bits (Mercator clamp pushes the closest cell point > 25 m away) |

The headline 4-bit result for the canonical (lat 45°, r = 25 m) input is below the 09-RESEARCH "approximately π × (r/cell_size)² ≈ 20-25 bits" estimate. The estimate appears to assume cells of ~10 m × 10 m, whereas the actual cell size at z=14 lat 45° is ~24 m × 27 m. With those dimensions, π × 25² / (24 × 27) ≈ 3.0 — matching the observed 4 (3 area-cells + 1 edge-clip cell).

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): add computeRevealMask failing tests** - `3a542bc` (test)
2. **Task 2 (GREEN): implement computeRevealMask body** - `bcef375` (feat)
3. **Task 3 (REFACTOR): skipped — deliberate, see Decisions Made** - no commit

**Plan metadata:** to be appended after STATE/ROADMAP updates (docs commit).

## Files Created/Modified

- `lib/domain/revealed/reveal_calculator.dart` — body landed for `computeRevealMask`, plus 5 private helpers (`_metersPerDegreeLat`, `_earthRadiusMeters`, `_toRad`, `_clampDouble`, `_haversineMeters`).
- `test/domain/revealed/reveal_calculator_test.dart` — 7 Phase 09 core tests + 1 Phase 03 contract regression test (in lieu of the retired `throws UnimplementedError` placeholder).
- `test/domain/revealed/reveal_calculator_parent_boundary_test.dart` — 3 parent-tile boundary straddle tests.
- `test/domain/reveal_calculator_test.dart` — Phase 03 placeholder `throws UnimplementedError` test removed (contract retired by 09-03 GREEN); replaced with a forwarding comment.

## Decisions Made

- **Constant naming**: the plan's algorithm references `kRevealedTileBitmapCellsPerSide` (which does not exist in `lib/config/constants.dart`); the project's actual constant is `kRevealedTileSubgridSize = 64`. Used the existing project constant in tests + body to avoid divergence.
- **Phase 03 placeholder test retired**: `test/domain/reveal_calculator_test.dart` previously asserted `throws UnimplementedError` on `computeRevealMask`. That contract is retired by Plan 09-03's GREEN step; the placeholder test was removed and replaced with a forwarding comment pointing at the new Phase 09 suite under `test/domain/revealed/`.
- **Disc-popcount bound widened**: Task 1's `[10, 40]` range was loosened to `[3, 12]` after Task 2's GREEN run produced popcount = 4. The planner's estimate had used a ~38 m × 27 m cell footprint, but the actual size at lat 45° z=14 is ~24 m × 27 m, putting the disc at ~3 cells of pure area + edge-clip — a value of 4 is correct.
- **Task 3 skipped**: the Task 2 body is ~80 lines of code, split into three well-commented logical sections (defensive prelude / bbox prune / cell loop). Extracting `_clipCellRange` and `_circleBboxIntersectsParent` would replace inline arithmetic with record-typed function calls — visual indirection without clarity gain. Per the plan's §Task 3 explicit "If NO refactor feels warranted, SKIP this task — leave Task 2's structure as-is" clause, this is documented and not committed.
- **Polar safety hardening**: `cos(centerLat)` is clamped against `TileMath.maxLatMercator` before computing `lonDegPerMeter`. Without the clamp, a fix at lat = ±90° (which the upstream `latLonToTile` does not clamp into the body — only into the *tile* projection) would zero-divide. The polar-clamp test at lat = 85° passes; lat = ±90° is now also safe.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan-referenced constant `kRevealedTileBitmapCellsPerSide` does not exist**
- **Found during:** Task 1 (RED — first compile attempt of the new tests)
- **Issue:** The plan's algorithm and `<interfaces>` block reference `kRevealedTileBitmapCellsPerSide` (claiming it lives in `lib/domain/revealed/revealed_tile.dart`), but the actual project constant is `kRevealedTileSubgridSize` in `lib/config/constants.dart`. Compilation failed with `Undefined name 'kRevealedTileBitmapCellsPerSide'`.
- **Fix:** Replaced all references with `kRevealedTileSubgridSize` (the existing project-canonical constant) in both test bodies and Task 2's body. Avoids adding a duplicate alias to `constants.dart`.
- **Files modified:** test/domain/revealed/reveal_calculator_test.dart, lib/domain/revealed/reveal_calculator.dart
- **Verification:** Tests compile + run; `dart run tool/check_domain_purity.dart` green; `flutter analyze` zero issues.
- **Committed in:** `3a542bc` (Task 1) + `bcef375` (Task 2)

**2. [Rule 1 - Bug] Phase 03 `throws UnimplementedError` placeholder test contradicts the GREEN contract**
- **Found during:** Task 1 planning (plan does not call out the placeholder test, but its existence breaks Task 2's automated verify)
- **Issue:** `test/domain/reveal_calculator_test.dart` line ~105 asserted `expect(() => computeRevealMask(...), throwsA(isA<UnimplementedError>()))`. After Task 2 lands the body, that test would fail — the placeholder contract is retired.
- **Fix:** Removed the obsolete `group('computeRevealMask', ...)` block and replaced it with a forwarding comment pointing at the new Phase 09 tests under `test/domain/revealed/`. Added an explicit "Phase 03 contract regression" test to the new suite that asserts the canonical `Uint8List(512)` shape (the new contract).
- **Files modified:** test/domain/reveal_calculator_test.dart, test/domain/revealed/reveal_calculator_test.dart
- **Verification:** All 15 surviving Phase 03 algebra tests still green; the new suite has 11 tests (10 plan-spec'd + 1 contract regression) all green.
- **Committed in:** `3a542bc` (Task 1)

**3. [Rule 1 - Bug] Disc-popcount test bounds were over-tight**
- **Found during:** Task 2 (GREEN — first test run after body landed)
- **Issue:** Task 1 wrote `expect(setBits, greaterThanOrEqualTo(10))` for the canonical (lat 45°, r=25 m) disc. Actual popcount = 4. The planner's bound assumed ~38 m × 27 m cells; the actual cells are ~24 m × 27 m. The plan's §Task 2 explicit guidance: "If the 'disc popcount' test range is too tight, inspect actual popcount and adjust the test bounds (the algorithm is correct — the test bounds may have been estimated too narrowly in Task 1)."
- **Fix:** Widened bounds to `[3, 12]` and updated the inline comment to document the actual cell footprint at lat 45° z=14.
- **Files modified:** test/domain/revealed/reveal_calculator_test.dart
- **Verification:** Disc test now green (popcount = 4 within `[3, 12]`).
- **Committed in:** `bcef375` (Task 2)

**4. [Rule 2 - Missing Critical] Polar safety: `cos(centerLat)` zero-divide guard**
- **Found during:** Task 2 (writing the body — anticipated edge case from the lat=85 test)
- **Issue:** The bbox expansion needs `1.0 / (metersPerDegreeLat * cos(toRad(centerLat)))`. Without an upstream clamp, a caller at lat=±90° (or any lat outside the Mercator-valid range that bypassed `TileMath.latLonToTile`) would zero-divide.
- **Fix:** Clamp `centerLat` against `TileMath.maxLatMercator` before computing `cos`. This is correctness-critical because the kernel can be called directly from any future caller without going through `TileMath.latLonToTile` first.
- **Files modified:** lib/domain/revealed/reveal_calculator.dart
- **Verification:** Polar test (`lat=85`) passes with a sane all-zero mask.
- **Committed in:** `bcef375` (Task 2)

---

**Total deviations:** 4 auto-fixed (1 blocking dependency, 2 bug fixes, 1 missing critical safety guard)
**Impact on plan:** Net positive — the blocker fix unblocked the work and the bug fixes corrected planner estimation errors that would otherwise have caused spurious failures. No scope creep.

## Issues Encountered

- Concurrent Wave 2 work (plan 09-02, executing in parallel) modified `test/domain/mirk/`, `lib/domain/mirk/`, and `lib/infrastructure/stores/drift_mirk_style_store.dart`. Those files were left untouched per the SCOPE BOUNDARY rule and not staged.

## Next Phase Readiness

- **Plan 09-04** (`MirkPaintContext` Freezed body) — independent of this plan's surface; unblocked.
- **Plan 09-05** (renderer factory + the 4 built-in renderers) — independent.
- **Plan 09-06** (`RevealStreamingController.onFix`) — **NOW UNBLOCKED**. The controller can loop over touched parent tiles via `TileMath.latLonToTile` on the bbox corners, call `computeRevealMask` once per parent tile, then `revealedTileStore.mergeMask(...)`. Exactly as 09-RESEARCH §RevealStreamingController prescribes.
- **Plan 09-07/08** (UI/perf) — independent of the kernel.

The kernel meets the <50 μs perf budget by ~80×, so the controller (09-06) does not need to schedule work onto an isolate at the per-fix cadence.

## Self-Check: PASSED

- `lib/domain/revealed/reveal_calculator.dart` — FOUND
- `test/domain/revealed/reveal_calculator_test.dart` — FOUND
- `test/domain/revealed/reveal_calculator_parent_boundary_test.dart` — FOUND
- `test/domain/reveal_calculator_test.dart` — FOUND
- `.planning/phases/09-fog-rendering/09-03-SUMMARY.md` — FOUND
- Commit `3a542bc` (Task 1 RED) — FOUND
- Commit `bcef375` (Task 2 GREEN) — FOUND

---
*Phase: 09-fog-rendering*
*Completed: 2026-04-25*
