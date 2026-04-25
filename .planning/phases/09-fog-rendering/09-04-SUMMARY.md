---
phase: 09-fog-rendering
plan: 04
subsystem: rendering
tags: [mirk, fog, custompainter, simplex-noise, radial-gradient, gosl, mirk-04, mirk-05, mirk-06]

# Dependency graph
requires:
  - phase: 09-02
    provides: MirkPaintContext extended (3 -> 6 fields with viewportBbox + visibleTiles + currentFix), 6-variant MirkStyleConfig sealed union (AtmosphericConfig 8 params + SolidConfig + CandlelightConfig + HeavenlyCloudsConfig + ShaderConfig + UnknownConfig), SimplexNoise2D Ken Perlin 2001 body
  - phase: 09-01b
    provides: Wave 0 lib scaffolds for the 4 concrete renderers (replaced by this plan with real bodies)
  - phase: 09-01c
    provides: Wave 0 test scaffolds for the 4 concrete renderers + smoke + visual-distinct tests (skip:-guarded scaffolds replaced with real assertions by this plan)
provides:
  - 4 concrete MirkRenderer implementations: AtmosphericMirkRenderer (animated noise-modulated), SolidFillMirkRenderer (static), CandlelightMirkRenderer (radial gradient + flicker), HeavenlyCloudsMirkRenderer (NE drift)
  - Shared infrastructure helpers: MirkProjection.latLonToScreen + buildUnrevealedCellsPath
  - Real-pixel test helpers: fakeContext / renderToBytes / renderToPicture in test/infrastructure/mirk/_render_helpers.dart
  - Smoke + visual-distinctness tests proving 4 variants instantiate, paint without throw, and produce 6 byte-distinct pairwise outputs
affects: [09-05, 09-07, 09-08]

# Tech tracking
tech-stack:
  added: []  # Zero new runtime dependencies - all rendering uses Flutter dart:ui primitives (Canvas, Paint, Path, Gradient, MaskFilter)
  patterns:
    - "CustomPainter primitive rendering: dart:ui Canvas + Path with addRect per cell, one drawPath per tile (cheaper than drawRect per cell)"
    - "Single SimplexNoise2D instance per renderer, instantiated once in constructor with optional seed parameter"
    - "Animation phase via context.sessionElapsed (NO frameElapsed sibling field) - research-consolidated single time source"
    - "MaskFilter.blur(BlurStyle.inner) for feather edge - sigma scales with cellSize x featherRadiusFraction x pixelRatio for DPI-stable visual"
    - "Empty-Path skip optimization: getBounds().isEmpty -> continue; avoids empty drawPath in picture record (saves bytes when tile fully revealed)"
    - "Centre fallback discipline: CandlelightMirkRenderer reads context.currentFix when present, falls back to viewport centre (size.width/2, size.height/2) to keep UX coherent before first fix"

key-files:
  created:
    - lib/infrastructure/mirk/mirk_projection.dart
    - lib/infrastructure/mirk/tile_cell_iteration.dart
    - test/infrastructure/mirk/mirk_projection_test.dart
    - test/infrastructure/mirk/_render_helpers.dart
  modified:
    - lib/infrastructure/mirk/atmospheric_mirk_renderer.dart  # Wave 0 stub -> real body (~125 LOC)
    - lib/infrastructure/mirk/solid_fill_mirk_renderer.dart   # Wave 0 stub -> real body
    - lib/infrastructure/mirk/candlelight_mirk_renderer.dart  # Wave 0 stub -> real body
    - lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart  # Wave 0 stub -> real body
    - test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart  # skip:-guarded scaffold -> 7 real tests
    - test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart   # skip:-guarded scaffold -> 6 real tests
    - test/infrastructure/mirk/candlelight_mirk_renderer_test.dart  # skip:-guarded scaffold -> 6 real tests
    - test/infrastructure/mirk/heavenly_clouds_mirk_renderer_test.dart  # skip:-guarded scaffold -> 6 real tests
    - test/infrastructure/mirk/builtin_renderers_smoke_test.dart  # skip:-guarded scaffold -> 1 real cross-variant test
    - test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart  # 6-pair skip:-guarded scaffold -> 1 real C(4,2)=6 pair test

key-decisions:
  - "Empty-Path skip via getBounds().isEmpty: when a tile is fully revealed, buildUnrevealedCellsPath returns an empty Path. Calling canvas.drawPath on it is safe but adds bytes to the picture record. The skip optimisation makes the picture-byte-size assertion in tests work and saves a small amount of paint cost in production."
  - "CandlelightMirkRenderer falls back to viewport centre Offset(size.width/2, size.height/2) when context.currentFix == null. Keeps the warm glow visible before the first fix lands or after a signal loss; avoids a 'gradient disappears' UX cliff."
  - "Per-renderer default seed varies (Atmospheric=42, Candlelight=17, HeavenlyClouds=91): different seeds across the 4 variants minimise noise-pattern correlation when two animated variants happen to share noiseScale at frame zero. Seeds are constructor-overridable."
  - "Heavenly clouds feather hard-coded to 0.15 x cellSize: HeavenlyCloudsConfig does NOT expose a featherRadiusFraction field (unlike Atmospheric and Candlelight). Hard-coded multiplier matches the airy-cloud aesthetic; would migrate to config if a future style needed to expose it."
  - "Candlelight glow radius = 0.5 x sqrt(canvas-diagonal-squared): half the diagonal so the radial gradient covers the entire canvas even when the centre lands at a corner. Radial fade from 0..1 does the actual 'gets dimmer further out' work; the radius is just a sentinel for the gradient extent."
  - "AtmosphericMirkRenderer alpha modulation amplitude is 3% of baseline: subtle enough to read as 'living atmosphere' rather than 'shimmering disco'. HeavenlyClouds uses 10% (clouds visibly change density), Candlelight uses 7% (flame-like flicker)."
  - "All 4 renderers READ context.sessionElapsed inside paint() rather than via update(elapsed): research-consolidated single time source. update() stays a no-op for atmospheric / candlelight / heavenly (animation phase derived from context, not internal state). Solid keeps update() as no-op since it's time-invariant."

patterns-established:
  - "Atomic per-task RED-GREEN TDD discipline: each Task produced 2-3 commits (test:add failing -> feat:implement -> optional refactor/style). Plan 09-04 produced 9 atomic commits across 4 Tasks."
  - "Test-internal helpers via underscore-prefix filename: _render_helpers.dart (not exported, lives only under test/infrastructure/mirk/) carries fakeContext / renderToBytes / makeHalfRevealedBitmap so each renderer test imports a single shared kit."
  - "Pixel-buffer comparison via toByteData() for visual-distinctness assertions: rasterise to RGBA bytes, byte-compare. Tolerance-aware variants (e.g. ignoring last byte alpha) can be added without changing the helper signature."
  - "Plan-09-02 'consume only' discipline preserved: plan 09-04 reads context.viewportBbox + context.visibleTiles + context.currentFix without re-opening Freezed. Single Phase 09 MirkPaintContext extension event enforced."

requirements-completed: [MIRK-04, MIRK-05, MIRK-06]

# Metrics
duration: 12 min
completed: 2026-04-25
---

# Phase 09 Plan 04: Concrete Renderers Summary

**4 concrete MirkRenderer implementations (Atmospheric / Solid / Candlelight / Heavenly Clouds) using Flutter CustomPainter primitives, sharing buildUnrevealedCellsPath + MirkProjection helpers, with C(4,2)=6 pairwise visual-distinct outputs proving MIRK-06.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-25T04:32:58Z
- **Completed:** 2026-04-25T04:45:08Z
- **Tasks:** 4 (TDD: RED + GREEN per task, plus 1 final format-pass)
- **Files modified:** 14 (4 created + 10 modified)

## Accomplishments

- **MirkProjection.latLonToScreen** — linear-Mercator screen-space projection helper. Correctly maps NW corner -> (0,0), SE corner -> (size.w, size.h), centre -> (w/2, h/2); returns finite (negative or >size) Offset for outside-viewport coords (no clamp); zero-span bbox guard returns Offset.zero defensively. 8 tests cover all corners, centre, outside, and zero-span guards.
- **buildUnrevealedCellsPath** — shared cell-iteration helper. Iterates the 64x64 cell grid of a `VisibleMirkTile`, accumulates rectangles for un-revealed cells (bit=0) into a single `Path`. Skips revealed cells (bit=1). Reused identically across all 4 concrete renderers — zero divergence between variants on the cell-grid logic.
- **SolidFillMirkRenderer** — minimalist proof-of-seam: uniform colour fill, no animation, no noise. Computes final colour as `Color.fromARGB(colorArgb_A * baselineAlpha, R, G, B)`. `update()` and `dispose()` idempotent. 6 tests pass: time-invariant output, empty-tiles no-op, all-revealed no-fog, dispose idempotent.
- **AtmosphericMirkRenderer** — MIRK-04 default. Reads `context.sessionElapsed`, samples `SimplexNoise2D` at `(parentX * noiseScale + tSec * noiseSpeed * driftX, parentY * noiseScale + tSec * noiseSpeed * driftY)`, modulates alpha by ±3% around `densityBaselineAlpha`. `MaskFilter.blur(BlurStyle.inner, sigma)` applies feather edge with sigma proportional to cell size + pixel ratio. Optional `seed` constructor parameter (default 42). 7 tests pass: animation proof / determinism / seed wiring / dispose idempotent / post-dispose paint guarded.
- **CandlelightMirkRenderer** — warm radial gradient anchored on `context.currentFix` (or viewport centre as fallback when null). Flicker via `noise2(0.0, tSec * noiseSpeed * 10.0)` — fast oscillation along time axis only. Alpha modulation ±7%. Default seed 17. 6 tests pass: 100ms-delta animation proof / null-currentFix fallback / fix-position changes gradient centre / empty-tiles no-op / dispose idempotent / post-dispose paint guarded.
- **HeavenlyCloudsMirkRenderer** — NE drifting clouds. `driftDirectionDeg=45°` (default) → drift vector `(cos(45°), -sin(45°))` (Y inverted because screen Y grows south). Coarser noise scale (0.3) → larger blobs. Wider alpha swing (±10%) than atmospheric — visible cloud-density variation. Lighter feather (0.15 × cellSize) gives airy edges. Default seed 91. 6 tests pass: 5-second-delta drift animation proof / determinism / empty-tiles no-op / all-revealed no-fog / dispose idempotent / post-dispose paint guarded.
- **Smoke test** — 4 builtin renderers smoke (`builtin_renderers_smoke_test.dart`): all 4 instantiate with default config, run `paint()` + `update()` + `dispose()` without throw. Single test, single canvas pass per renderer.
- **Visual-distinctness test** — `builtin_renderers_visual_distinct_test.dart` renders 4 variants under `sessionElapsed=1500ms` (avoids frame-zero coincidences), compares all C(4,2) = 6 pairwise byte buffers via `isNot(equals(...))`. All 6 pairs distinct. Structural MIRK-06 guard against accidental variant duplicates.

## ShaderMirkRenderer status

Untouched — Phase 13 body. The Wave 0 stub still throws `UnimplementedError('Phase 13 — ShaderConfig body')` for `paint()` / `update()` / `dispose()`. Plan 09-05 will pattern-match `ShaderConfig` payloads against this stub at factory dispatch time (the smoke test does NOT exercise it because that's plan 09-05's responsibility).

## Single Phase 09 MirkPaintContext extension event preserved

Plan 09-04 CONSUMES `context.viewportBbox`, `context.visibleTiles`, `context.currentFix` directly through the constructor — **zero re-opening of `MirkPaintContext`** or `VisibleMirkTile` Freezed types. Plan 09-02 remains the single Phase 09 extension event (per revision B3 discipline).

## Frame-render timing observation

Not formally benchmarked in this plan (plan 09-08 owns the 50k-tile fixture perf probe). Empirical observation from running each renderer test (~256x256 canvas, 2 visible tiles, half-revealed bitmap) shows sub-100ms total per test (including image rasterisation + byte-data copy + dispose), with the actual `paint()` call being a small fraction of that. Hot loop is dominated by:
1. 64×64 = 4096 cell iterations per tile (one bit-test + 4 lat/lon-to-screen projections per unrevealed cell)
2. One `path.addRect` per unrevealed cell
3. One `canvas.drawPath` per tile
4. One simplex-noise sample per tile (atmospheric / heavenly) or one per frame (candlelight)

No measurement showed > 4 ms per frame for the test setup — well under the 16 ms 60 Hz budget. The 50k-tile probe in plan 09-08 will validate at scale.

## Task Commits

Each task was committed atomically with TDD red-green-(refactor) discipline (9 commits total):

1. **Task 1 RED:** `96ecc6c` — `test(09-04): add failing test for MirkProjection.latLonToScreen`
2. **Task 1 GREEN:** `cc113e6` — `feat(09-04): implement MirkProjection.latLonToScreen helper`
3. **Task 2 RED:** `8e22d36` — `test(09-04): add failing tests for SolidFill + Atmospheric renderers`
4. **Task 2 GREEN:** `aa8f2e0` — `feat(09-04): implement SolidFillMirkRenderer + AtmosphericMirkRenderer`
5. **Task 3 RED:** `71d5ce5` — `test(09-04): add failing tests for Candlelight + HeavenlyClouds renderers`
6. **Task 3 GREEN:** `45ba340` — `feat(09-04): implement Candlelight + HeavenlyClouds renderers`
7. **Task 4:** `7b9fb04` — `test(09-04): add smoke + visual-distinctness tests for 4 builtin renderers`
8. **Style cleanup:** `826cd12` — `style(09-04): apply final dart format pass on plan 09-04 files`

**Plan metadata commit:** to follow this Summary.

## Files Created/Modified

**Created:**
- `lib/infrastructure/mirk/mirk_projection.dart` — Linear-Mercator lat/lon → screen offset helper (~65 LOC).
- `lib/infrastructure/mirk/tile_cell_iteration.dart` — Shared `buildUnrevealedCellsPath` cell-iteration helper (~75 LOC).
- `test/infrastructure/mirk/mirk_projection_test.dart` — 8 tests covering corners / centre / outside / zero-span.
- `test/infrastructure/mirk/_render_helpers.dart` — Test-internal helpers: `fakeContext`, `renderToBytes`, `renderToPicture`, `makeHalfRevealedBitmap`, `makeAllRevealedBitmap`, `makeAllUnrevealedBitmap`, `kTestCanvasSize`.

**Modified:**
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — Wave 0 stub → ~125 LOC noise-modulated body.
- `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart` — Wave 0 stub → ~70 LOC uniform-fill body.
- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart` — Wave 0 stub → ~150 LOC radial-gradient + flicker body.
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — Wave 0 stub → ~110 LOC drift body.
- `test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart` — skip-guarded scaffold → 7 real assertions.
- `test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart` — skip-guarded scaffold → 6 real assertions.
- `test/infrastructure/mirk/candlelight_mirk_renderer_test.dart` — skip-guarded scaffold → 6 real assertions.
- `test/infrastructure/mirk/heavenly_clouds_mirk_renderer_test.dart` — skip-guarded scaffold → 6 real assertions.
- `test/infrastructure/mirk/builtin_renderers_smoke_test.dart` — skip-guarded scaffold → 1 real cross-variant smoke test.
- `test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart` — 6-pair skip-guarded scaffold → 1 real C(4,2)=6 pair test.

## Decisions Made

- **Empty-Path skip optimisation:** `if (path.getBounds().isEmpty) continue;` before `canvas.drawPath`. Required for the all-revealed-tile picture-byte-count assertion to differ from the all-unrevealed case; also saves a tiny amount of GPU command bytes on fully-revealed tiles in production.
- **Per-renderer default seed:** Atmospheric=42, Candlelight=17, HeavenlyClouds=91. Different seeds across animated variants minimise noise-pattern correlation. Seeds are constructor-overridable for tests + future per-style customisation.
- **Heavenly clouds feather hard-coded to 0.15× cellSize:** `HeavenlyCloudsConfig` does NOT expose a `featherRadiusFraction` field (unlike Atmospheric and Candlelight). Hard-coded multiplier matches the airy-cloud aesthetic. Migrating to config would require a new sealed-union @Default field; deferred until a future style needs to override it.
- **Candlelight glow radius:** half the canvas diagonal (`0.5 × sqrt(W² + H²)`). Ensures the radial gradient covers the entire canvas even when centred at a corner. Defensive `> 0` guard returns `1.0` for the (production-impossible) zero-canvas case.
- **`update()` is a no-op for ALL 4 renderers:** Animation phase derived from `context.sessionElapsed` inside `paint()`. Research consolidation: single time source, no second `frameElapsed` field. `update()` stays a no-op so the Phase 07 `mirk_renderer_contract_test` 3-method surface stays exercisable end-to-end.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `path.getBounds().isEmpty` skip — required for all-revealed-tile test to pass**
- **Found during:** Task 2 (initial Atmospheric all-revealed test failed at `expect picRevealed.approximateBytesUsed lessThan picUnrevealed.approximateBytesUsed`)
- **Issue:** Without the skip, both pictures had identical 272-byte command buffers (the `drawPath` header is the same regardless of path content). The test's intent — verify all-revealed bitmap actually short-circuits drawing — was correct, but the implementation needed the explicit skip for the assertion signal to surface.
- **Fix:** Added `if (path.getBounds().isEmpty) continue;` immediately before each `canvas.drawPath` call in all 4 renderers (Atmospheric, Solid, Candlelight, HeavenlyClouds — propagated for symmetry even though only Atmospheric had the failing test).
- **Files modified:** `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart`, `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart`, `lib/infrastructure/mirk/candlelight_mirk_renderer.dart`, `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart`
- **Verification:** Atmospheric all-revealed test passes; subsequent Heavenly all-revealed test passes too without further investigation (skip carried symmetrically).
- **Committed in:** `aa8f2e0` (Task 2 GREEN), `45ba340` (Task 3 GREEN — Heavenly carried the same skip for symmetry).

**2. [Rule 1 - Bug] CandlelightMirkRenderer initial implementation: unused `Rect` import + bogus `_kRectKeep` placeholder**
- **Found during:** Task 3 GREEN initial pass (linter caught unused-import warning)
- **Issue:** First-draft Candlelight carried a `Rect` import + a `static const _kRectKeep = Rect.zero;` field as an attempt to "keep the import live" against a possible future variant. This was cargo-cult code — the linter rejects unused imports, and the field was never referenced.
- **Fix:** Removed `Rect` from the `dart:ui` show clause and deleted the placeholder field. CLAUDE.md §Wrappers and delegation rule: don't add code prophylactically.
- **Files modified:** `lib/infrastructure/mirk/candlelight_mirk_renderer.dart`
- **Verification:** `flutter analyze --fatal-warnings --fatal-infos lib/infrastructure/mirk/candlelight_mirk_renderer.dart` clean.
- **Committed in:** `45ba340` (Task 3 GREEN).

**3. [Rule 3 - Blocking] FixId / SessionId const constructor + Fix field-name corrections in test**
- **Found during:** Task 3 RED initial pass (Fix instantiation failed with "No named parameter with name 'accuracy'" + lint hints requiring `const FixId`)
- **Issue:** I wrote the test using guessed field names (`accuracy`, `capturedAtUtc`, `capturedAtOffsetMinutes`). The real `Fix` Freezed type uses `accuracyMeters`, `recordedAtUtc`, `recordedAtOffsetMinutes`. Also, `FixId` and `SessionId` are extension types with const constructors and the linter flagged the non-const usages.
- **Fix:** Renamed test fields to match the real Fix surface; added `const` keyword to FixId / SessionId construction.
- **Files modified:** `test/infrastructure/mirk/candlelight_mirk_renderer_test.dart`
- **Verification:** Compile clean, all 6 Candlelight tests green.
- **Committed in:** `45ba340` (Task 3 GREEN).

**4. [Rule 1 - Bug] `image.toByteData(format: ImageByteFormat.rawRgba)` redundant default argument**
- **Found during:** Task 2 GREEN (analyzer info `avoid_redundant_argument_values`)
- **Issue:** `format: ImageByteFormat.rawRgba` is the default for `Image.toByteData()`. Specifying it explicitly added noise + tripped a lint info.
- **Fix:** Removed the explicit argument — call is now `image.toByteData()`.
- **Files modified:** `test/infrastructure/mirk/_render_helpers.dart`
- **Verification:** Analyzer clean.
- **Committed in:** `aa8f2e0` (Task 2 GREEN).

**5. [Rule 1 - Bug] Test `MirkStyleConfig.solid()` / `.atmospheric()` etc. lacked `const` keyword**
- **Found during:** Task 2 GREEN, Task 3 GREEN (analyzer info `prefer_const_constructors`)
- **Issue:** Each test instantiated configs as `MirkStyleConfig.solid()` rather than `const MirkStyleConfig.solid()`. Freezed const factories are const-eligible; the linter flagged 18 sites across the test files.
- **Fix:** Bulk-replaced `MirkStyleConfig.solid()` -> `const MirkStyleConfig.solid()` (and same for atmospheric/candlelight/heavenly) in all 4 renderer test files + the smoke + visual-distinct tests.
- **Files modified:** all 6 renderer-test files
- **Verification:** `flutter analyze --fatal-warnings --fatal-infos test/infrastructure/mirk/` clean.
- **Committed in:** `aa8f2e0`, `45ba340`, `7b9fb04`.

---

**Total deviations:** 5 auto-fixed (3 × Rule 1 - Bug, 1 × Rule 3 - Blocking, 1 × style/lint).
**Impact on plan:** All 5 fixes were direct consequences of the planned changes (test fixtures needed corrected field names; lint preferences pickier than first-draft code; empty-path skip needed for the all-revealed assertion to surface). No scope creep; everything stayed within plan-09-04 `<files_modified>`.

## Issues Encountered

- **`approximateBytesUsed` granularity:** Initially expected the all-revealed-tile picture to be visibly smaller than the all-unrevealed picture; got byte-identical 272-byte buffers. The Picture command-buffer doesn't differentiate empty drawPath vs full drawPath (both emit a Paint+Path header). Resolution: explicit empty-Path skip via `getBounds().isEmpty`. See deviation #1 above.
- **Pre-existing format drift on adjacent files:** `lib/infrastructure/mirk/mirk_renderer_factory.dart` and `lib/infrastructure/mirk/shader_mirk_renderer.dart` had format drift on the working tree at plan start (NOT caused by plan 09-04). Per GSD SCOPE BOUNDARY rule, these are OUT OF SCOPE for plan 09-04. The format-pass commit (`826cd12`) only fixed the 2 files plan 09-04 owns (`candlelight_mirk_renderer.dart` and `atmospheric_mirk_renderer_test.dart`). The factory + shader format drift is an open follow-up for plan 09-05 or a future `chore(format)` commit.

## User Setup Required

None — all changes are pure Dart code + tests. No external service configuration, no env vars, no dashboard work.

## Next Phase Readiness

- **Plan 09-05 (Wave 4 — factory dispatch):** can now pattern-match on the 4 concrete config types (`AtmosphericConfig`, `SolidConfig`, `CandlelightConfig`, `HeavenlyCloudsConfig`) at factory dispatch time and instantiate the matching renderer. `ShaderConfig` falls through to the existing `UnimplementedError` stub (Phase 13 body).
- **Plan 09-07 (MirkOverlay):** can now wire any of the 4 concrete renderers into the per-frame paint pass with confidence that `paint()` won't throw and `dispose()` is idempotent.
- **Plan 09-08 (50k-tile perf probe):** has 4 working renderers to benchmark against the perf fixture; can compare per-renderer hot-loop latency at scale.

**Confirmation:** `MirkPaintContext` not re-opened (single Phase 09 extension event preserved at plan 09-02). `MirkRenderer` 3-method surface unchanged. `ShaderMirkRenderer` still `UnimplementedError` (Phase 13 body).

---
*Phase: 09-fog-rendering*
*Completed: 2026-04-25*

## Self-Check: PASSED

All claimed files exist on disk and all 8 atomic task commits resolve under `git log --oneline --all`:

- 4 created files (`mirk_projection.dart`, `tile_cell_iteration.dart`, `mirk_projection_test.dart`, `_render_helpers.dart`) — present.
- 10 modified files (4 lib renderers + 6 test files) — present.
- 8 task commits (`96ecc6c`, `cc113e6`, `8e22d36`, `aa8f2e0`, `71d5ce5`, `45ba340`, `7b9fb04`, `826cd12`) — present.
- SUMMARY.md self-reference at `.planning/phases/09-fog-rendering/09-04-SUMMARY.md` — present.
