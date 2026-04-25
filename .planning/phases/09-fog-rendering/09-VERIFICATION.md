---
phase: 09-fog-rendering
verified: 2026-04-25T12:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
human_verification:
  - test: "Visual approval of 4 builtin renderer variants on real device"
    expected: "atmospheric (animated dark noise), solid (static flat), candlelight (warm orange radial glow), heavenly_clouds (lighter drifting blobs) — all visually distinct and satisfying"
    why_human: "Pixel-comparison tests confirm byte-distinctness but cannot verify subjective visual quality or the 'living fog' feel specified in MIRK-04 / 09-CONTEXT.md"
  - test: "Real-device frame budget: 50k-tile fixture ≤ 16 ms on Android Pixel 4a and iOS device"
    expected: "atmospheric renderer holds 16 ms / 60 fps on mid-range device with Impeller GPU acceleration"
    why_human: "Widget-test env has no Impeller/GPU so MaskFilter.blur runs on CPU (observed 88-93 ms avg). Phase 10 review gate is designated for real-device validation. Test ceiling is 150 ms (widget-test bound) and passes — not 16 ms."
  - test: "RepaintBoundary isolation via DevTools Highlight Repaints overlay during a live session"
    expected: "Only the mirk overlay layer flashes red on each Ticker frame; map tiles, FAB, attribution, country banner do NOT repaint"
    why_human: "The test confirms siblings do not rebuild (counter-checked, passes) but DevTools visual validation of the actual GPU repaint tree is the Phase 10 gate requirement."
  - test: "In-session style picker UX: tap each of the 4 builtin styles in the burger menu, verify immediate fog appearance change"
    expected: "Burger menu opens MirkStylePickerSheet; tapping a style updates the fog immediately on the map; a checkmark appears on the selected style"
    why_human: "The wire-up is code-verified (MirkStylePickerSheet + MirkStyleSessionController + activeMirkRendererProvider invalidation chain all present), but the end-to-end UX tap flow on a real device cannot be confirmed programmatically."
---

# Phase 09: Fog Rendering — Verification Report

**Phase Goal:** Deliver the visual identity of the product — a living atmospheric mirk that dissolves around the user in real time, with a strictly decoupled `MirkRenderer` architecture. Maintain ≤ 50k-tile performance.
**Verified:** 2026-04-25
**Status:** PASSED (with 4 items deferred to human/Phase 10 review)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GPS fix → `computeRevealMask` → `RevealedTileStore` → renderer is end-to-end wired | VERIFIED | `RevealStreamingController` buffers fixes, calls `computeRevealMask` per tile, calls `store.mergeMask`; `ActiveSessionController` hooks `revealInitial` at session start; `MirkOverlay` watches `visibleMirkTilesProvider` which reads the store |
| 2 | 4 builtin renderers each in their own file, each visually distinct | VERIFIED | 4 concrete renderer files confirmed: `atmospheric_mirk_renderer.dart`, `solid_fill_mirk_renderer.dart`, `candlelight_mirk_renderer.dart`, `heavenly_clouds_mirk_renderer.dart`; `builtin_renderers_visual_distinct_test.dart` confirms all 6 pair-combinations produce distinct pixel buffers; smoke test confirms all 4 instantiate + paint + dispose without throw |
| 3 | `MirkRendererFactory` + `activeMirkRendererProvider` chain resolves from active session | VERIFIED | `activeMirkRendererProvider` watches `activeSessionControllerProvider` → reads `SessionStore.findById` → reads `MirkStyleStore.findById` → calls `MirkRendererFactory.create(config)` → returns concrete renderer; fallback to `AtmosphericMirkRenderer` when session null or style missing; `NoopMirkRenderer` when no active session |
| 4 | In-session style swap persists to `Session.mirkStyleId` (schema v3→v4 migration) | VERIFIED | `V3ToV4SessionMirkStyle` migration adds `mirk_style_id` column with `ON DELETE SET NULL` FK; `Session` Freezed entity includes `MirkStyleId? mirkStyleId` field; `SessionStore.updateMirkStyle` method present; `MirkStyleSessionController.select()` writes to store then calls `invalidateRenderer()` to trigger `activeMirkRendererProvider` re-resolution; migration test at `test/infrastructure/db/migrations/v3_to_v4_session_mirk_style_test.dart` |
| 5 | `MirkOverlay` is `RepaintBoundary`-isolated and viewport-filtered | VERIFIED | `RepaintBoundary` wraps `MirkInitialRevealFade(MirkOverlay)` in `MapScreen._buildMapStack` (line 279); `map_screen_repaint_boundary_test.dart` confirms structural ancestor chain + behavioural sibling non-rebuild over 10 Ticker frames; `visibleMirkTilesProvider` iterates only parent tiles intersecting current viewport bbox |
| 6 | 50k-tile perf probe exists with defined budget and passes | VERIFIED | `test/performance/fog_50k_tiles_perf_test.dart` loads `fifty_k_tiles_seed.sql.gz` (50k rows), runs 60-frame paint loop, asserts avg ≤ 150 ms (widget-test ceiling); observed 88-93 ms avg at plan close; viewport-filter test confirms ≤ 20 `findByParent` calls for a Paris-sized bbox over 1000-tile DB; tagged `@Tags(['mirk-perf'])` to exclude from default suite |
| 7 | MIRK-05 seam structurally enforced: adding a variant requires exactly 3-4 file edits, verified by `tool/check_mirk_variant_file_count.dart` CI gate | VERIFIED | Tool confirms exactly 6 `*_mirk_renderer.dart` files (4 builtins + noop + shader); sealed switch in `MirkRendererFactory` is exhaustive at compile time (Dart 3 exhaustiveness enforcement); CI gate `check_mirk_variant_file_count` wired in `.github/workflows/ci.yml` line 157 |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` | Default animated renderer (MIRK-04) | VERIFIED | Substantive: simplex noise `_noise.noise2(...)` drives alpha modulation, `MaskFilter.blur` for feathering, session-elapsed-based drift animation; not a stub |
| `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart` | Static flat-color renderer | VERIFIED | Distinct implementation (no noise, no animation); imports `tile_cell_iteration.dart` not `simplex_noise_2d.dart` |
| `lib/infrastructure/mirk/candlelight_mirk_renderer.dart` | Warm glow renderer | VERIFIED | Distinct: uses radial gradient anchored on GPS fix, high-frequency flicker noise — imports `mirk_projection.dart` for lat/lon → canvas coordinate projection |
| `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` | Airy drifting clouds | VERIFIED | Distinct: coarse simplex noise blobs drifting NE at 45° default, lighter baseline alpha |
| `lib/infrastructure/mirk/mirk_renderer_factory.dart` | Sealed switch factory | VERIFIED | Exhaustive `switch (config)` over all 6 variants; `UnknownConfig` logs and falls back to atmospheric |
| `lib/infrastructure/mirk/builtin_mirk_styles.dart` | Registry of 4 descriptors | VERIFIED | `kBuiltinMirkStyles` list with exactly 4 `BuiltinMirkStyleDescriptor` entries in canonical order; deterministic IDs `style_builtin_{atmospheric,solid,candlelight,heavenly_clouds}` |
| `lib/application/providers/active_mirk_renderer_provider.dart` | Session-scoped renderer provider | VERIFIED | Watches `activeSessionControllerProvider`; fallback cascade (idle→noop, missing style→atmospheric); `ref.onDispose(renderer.dispose)` lifecycle management |
| `lib/application/providers/builtin_mirk_styles_provider.dart` | Lazy-seeding provider | VERIFIED | Seeds 4 builtin rows on first read; idempotent on re-read; tested in `builtin_mirk_styles_provider_test.dart` |
| `lib/application/controllers/reveal_streaming_controller.dart` | GPS fix buffer + flush | VERIFIED | 2s/20-fix dual-trigger batch flush; `revealInitial` for session-start 20m disc; dispose flushes buffered fixes |
| `lib/application/controllers/mirk_style_session_controller.dart` | In-session style swap | VERIFIED | `select()` validates style+session exist, no-ops on same-style, writes `updateMirkStyle`, calls `invalidateRenderer()` |
| `lib/presentation/widgets/mirk_overlay.dart` | Ticker-driven CustomPainter overlay | VERIFIED | `ConsumerStatefulWidget` + `SingleTickerProviderStateMixin`; bails out on null prerequisites; passes `MirkPaintContext` with viewport/tiles/fix |
| `lib/presentation/widgets/mirk_style_picker_sheet.dart` | Burger-menu style picker | VERIFIED | `ConsumerWidget` listing 4 builtins from `builtinMirkStylesProvider`; trailing checkmark on current style; tap calls `MirkStyleSessionController.select()` |
| `lib/domain/revealed/reveal_calculator.dart` → `computeRevealMask` body | GPS→bitmap geometry | VERIFIED | Full Haversine + bbox-prune + per-cell closest-point implementation (was `UnimplementedError` in Phase 03); 155-line function body |
| `lib/infrastructure/db/migrations/v3_to_v4_session_mirk_style.dart` | DB schema migration | VERIFIED | `ALTER TABLE t_sessions ADD COLUMN "mirk_style_id" TEXT NULL REFERENCES t_mirk_styles(id) ON DELETE SET NULL`; applied via `AppDatabase.onUpgrade` chain |
| `test/fixtures/mirk/fifty_k_tiles_seed.sql.gz` | 50k-tile DB fixture | VERIFIED | 4,149,955 bytes; 50,001 INSERT statements (1 session + 50,000 tiles); deterministic gzip (mtime=0) |
| `tool/check_mirk_variant_file_count.dart` | CI gate for MIRK-05 seam | VERIFIED | Scans `lib/infrastructure/mirk/` for `*_mirk_renderer.dart`; expects exactly `kExpectedRendererBasenames` (6 files); wired in `ci.yml` |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `active_mirk_renderer_provider.dart` | `sessionStoreProvider` + `mirkStyleStoreProvider` | `ref.watch(activeSessionControllerProvider)` + `ref.watch(sessionStoreProvider.future)` + `ref.watch(mirkStyleStoreProvider.future)` | WIRED | Both store providers resolved async before style lookup; pattern confirmed in source lines 50-94 |
| `MirkRendererFactory.create(switch)` | 6 concrete renderer files | Constructor call per sealed variant (exhaustive) | WIRED | All 6 cases present: atmospheric/solid/candlelight/heavenlyCloudsMirkRenderer + ShaderMirkRenderer + `_atmosphericFallback(UnknownConfig)` |
| `MirkStylePickerSheet` tap | `MirkStyleSessionController.select()` → `sessionStore.updateMirkStyle` → `invalidateRenderer()` → `activeMirkRendererProvider` re-resolution | `ref.read(mirkStyleSessionControllerProvider).select(...)` | WIRED | Burger-menu opens sheet; tap calls controller; controller invalidates provider; provider rebuilds with new renderer |
| `ActiveSessionController._onFix` / `_handleInitialReveal` | `RevealStreamingController.onFix` / `revealInitial` | `revealStreamingControllerProvider(sessionId)` resolved per session | WIRED | `active_session_controller.dart` lines 165-389 show both the fast-path (initial reveal on start) and the per-fix path |
| `RevealStreamingController._writeCircleReveal` | `computeRevealMask` → `RevealedTileStore.mergeMask` | Direct function call + `store.mergeMask(...)` | WIRED | `reveal_streaming_controller.dart` lines 131-163; tile enumeration → `computeRevealMask` → `store.mergeMask`; empty masks skipped |
| `MirkOverlay` | `visibleMirkTilesProvider` + `activeMirkRendererProvider` + `mapViewportProvider` | `ref.watch(...)` in `build()` | WIRED | All 5 prerequisite providers watched; bail-out on null/not-ready prevents empty paint calls |
| `MapScreen` Stack | `RepaintBoundary(MirkInitialRevealFade(MirkOverlay))` | `Positioned.fill` sibling in Stack | WIRED | `map_screen.dart` lines 278-282; narrowest legal scope around the moving widget |

---

### Requirements Coverage

| Requirement | Phase | Description | Status | Evidence |
|-------------|-------|-------------|--------|----------|
| MIRK-01 | 09 | Circular reveal radius effaced around current position in real time | SATISFIED | `RevealStreamingController` + `computeRevealMask` + `RevealedTileStore.mergeMask` + initial 20m hook in `ActiveSessionController` |
| MIRK-02 | 09 | Reveal radius configurable (default 25–50 m, defined in constants) | SATISFIED | `kDefaultRevealRadiusMeters = 25.0` in `lib/config/constants.dart` line 349; UI slider deferred to Phase 13 (OPT-02) per spec |
| MIRK-04 | 09 | Vivid / atmospheric / animated mirk — not a flat black layer | SATISFIED | `AtmosphericMirkRenderer` uses simplex noise for alpha modulation + `MaskFilter.blur` feathering + directional drift; animation proof test confirms frames at different `sessionElapsed` produce distinct pixel buffers |
| MIRK-05 | 09 | `MirkRenderer` abstract interface: adding a style = new file, zero core modification | SATISFIED | Interface frozen at 3 methods; sealed switch in factory enforces compile-time exhaustiveness; `check_mirk_variant_file_count` CI gate enforces 1-file-per-variant structurally |
| MIRK-06 | 09 | 4 builtin styles (atmospheric/solid/candlelight/heavenly_clouds), each a distinct class | SATISFIED | 4 renderer files confirmed; `builtin_renderers_visual_distinct_test.dart` passes (6 pair-combinations, all byte-distinct); `builtin_renderers_smoke_test.dart` passes |
| MIRK-07 | 09 | In-session style picker (burger menu) allows selecting mirk style; change applies immediately | SATISFIED | `MirkStylePickerSheet` wired into `session_burger_menu.dart`; `MirkStyleSessionController.select()` persists + invalidates renderer; `activeMirkRendererProvider` re-resolves on invalidation |

**No orphaned requirements for Phase 09.** MIRK-08, MIRK-09, MIRK-10 are correctly assigned to Phase 13 and remain unstarted.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/performance/fog_50k_tiles_perf_test.dart` | 55 | Frame-budget assertion relaxed from 25 ms to 150 ms due to widget-test env (no Impeller/GPU) | INFO | Intentional — documented deviation. Real-device 16 ms target is Phase 10 gate. Not a code smell. |
| `lib/infrastructure/mirk/shader_mirk_renderer.dart` | body | `UnimplementedError('Phase 13 — ShaderConfig body')` stub | INFO | Intentional — ShaderConfig is declared for sealed-switch exhaustiveness; its renderer arrives in Phase 13. This is the correct Phase 09 treatment. |

No blockers or warnings found. The two info items are documented intentional design decisions, not oversight.

---

### Human Verification Required

#### 1. Visual quality of 4 builtin renderer variants

**Test:** On a real Android or iOS device, start a session, then open the burger menu and cycle through all 4 styles (Atmospheric, Solide, Lueur de bougie, Nuages célestes).
**Expected:** Each style is visually distinct: atmospheric shows animated dark noise with soft feathered edges; solid shows a flat opaque layer; candlelight shows a warm orange radial glow anchored on the GPS position; heavenly clouds shows lighter, larger, slowly-drifting fog blobs. The default atmospheric should feel "alive" (movement visible within a few seconds).
**Why human:** Pixel distinctness is confirmed programmatically (`builtin_renderers_visual_distinct_test.dart`), but the subjective "living fog" quality (MIRK-04 specification: "nuageux, mouvant, animé — pas un simple aplat noir") requires visual inspection on real hardware with Impeller GPU rendering.

#### 2. Real-device frame budget: ≤ 16 ms on mid-range Android

**Test:** Phase 10 review gate — run the 50k-tile perf probe on an Android Pixel 4a (or equivalent) with DevTools CPU/GPU profiling enabled. Measure average frame time under the atmospheric renderer with a 50k-row DB fixture.
**Expected:** Average frame time ≤ 16 ms (60 fps). The widget-test baseline (88-93 ms on CPU without Impeller) is not representative of production Impeller-accelerated rendering.
**Why human:** No automated test can measure real Impeller/GPU performance in CI. The `fog_50k_tiles_perf_test.dart` uses a 150 ms ceiling (widget-test env bound) and passes, but the real target requires a device.

#### 3. DevTools RepaintBoundary isolation during a live session

**Test:** Open DevTools → "Highlight Repaints" overlay; start a session and observe which layers repaint per Ticker frame.
**Expected:** Only the `MirkOverlay` / `MirkInitialRevealFade` layer flashes. The map tiles, attribution icon, follow-me FAB, country banner, and download progress chip should NOT repaint on Ticker frames.
**Why human:** The regression test (`map_screen_repaint_boundary_test.dart`) uses `TestMapScreenHarness` with counter-wrapped builders and confirms zero re-builds — but the DevTools visual overlay on a real device (with the actual MapLibre platform view) provides the definitive confirmation that the `RepaintBoundary` placement is correct across the Flutter platform view composition boundary.

#### 4. End-to-end in-session style swap UX

**Test:** During an active tracking session on a real device: open the burger menu, tap "Changer le style", select each of the 4 builtin styles in sequence, observe the map fog changing immediately.
**Expected:** Each tap immediately changes the visible fog style. The selected style shows a checkmark. Closing and re-opening the picker shows the last-selected style as current. A new session inherits the global default (atmospheric) — the per-session override survives app background/foreground transitions.
**Why human:** The code path (picker → controller → DB write → provider invalidation → renderer swap) is fully wired and tested in unit tests. The end-to-end UX responsiveness, the visual swap animation, and session-persistence across lifecycle events require physical device testing.

---

## Gaps Summary

No gaps found. All 7 observable truths are verified. All required artifacts exist and are substantive. All key links are wired.

The 4 human verification items are Phase 10 review gate responsibilities, not Phase 09 defects. They are listed here for completeness and to provide a clear handoff to the review gate.

**Schema v3→v4 migration note:** The `t_sessions.mirk_style_id` column addition was a user-approved scope expansion in plan 09-05 (decision checkpoint Option 1). It is a legitimate Phase 09 deliverable. The `Session.mirkStyleId` Freezed field, the `V3ToV4SessionMirkStyle` migration, and the `SessionStore.updateMirkStyle` method are all present and tested.

---

## Overall Assessment

Phase 09 delivered all committed deliverables:

- **Render pipeline end-to-end:** GPS fix → `computeRevealMask` → `RevealedTileStore` → `visibleMirkTilesProvider` → `MirkOverlay` → renderer → Canvas. All links wired.
- **4 visually distinct builtins:** Each in its own file, each producing distinct pixel output, each exercised by both smoke and visual-distinctness tests.
- **Factory + seam:** Sealed switch with compile-time exhaustiveness; `check_mirk_variant_file_count` CI gate; `kBuiltinMirkStyles` registry.
- **In-session style swap:** `MirkStylePickerSheet` wired into burger menu; `MirkStyleSessionController` + `activeMirkRendererProvider` invalidation chain; v3→v4 schema migration.
- **RepaintBoundary isolation:** Structural test + 10-frame behavioural test confirm Ticker frames do not cascade to sibling widgets.
- **Viewport filtering:** `visibleMirkTilesProvider` confirmed ≤ 20 `findByParent` calls for a Paris-sized bbox over a 1000-tile DB.
- **50k-tile perf probe:** Passes widget-test 150 ms ceiling; real-device 16 ms target is Phase 10's responsibility.
- **Zero new dependencies:** Hand-rolled `SimplexNoise2D` maintained throughout.

---

_Verified: 2026-04-25_
_Verifier: Claude (gsd-verifier)_
