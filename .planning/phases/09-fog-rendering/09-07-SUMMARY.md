---
phase: 09-fog-rendering
plan: 07
subsystem: ui
tags: [riverpod, widget, ticker, custom-painter, repaint-boundary, fade-transition, fog-of-war]

# Dependency graph
requires:
  - phase: 09-fog-rendering
    provides: activeMirkRendererProvider (plan 09-05), MirkStyleSessionController (plan 09-06), MirkPaintContext + VisibleMirkTile + MirkViewportBbox (plan 09-02), 4 concrete renderers (plan 09-04)
  - phase: 07-map-integration
    provides: MapView port + MapLibreMapViewWidget + mapViewProvider (plan 07-03 / 07-06), session_burger_menu (plan 07-06)
  - phase: 05-gps-session-lifecycle
    provides: ActiveSessionController + Tracking state (plan 05-02 / 05-04)
provides:
  - "MapView.queryViewportBounds() — port method returning MirkViewportBbox; MapLibre adapter reads getVisibleRegion() and adapts at the platform boundary (MAP-06)"
  - "mapViewportProvider — @Riverpod(keepAlive: true) class notifier publishing MirkViewportBbox?; subscribes to MapView.viewportUpdates and debounces 50 ms"
  - "visibleMirkTilesProvider — async @riverpod returning the list of parent tiles intersecting the current viewport, hydrated from RevealedTileStore (all-zero bitmap when no row); viewport filtering (SC#5) seam"
  - "MirkOverlay widget — ConsumerStatefulWidget with SingleTickerProviderStateMixin + CustomPainter that renders the active MirkRenderer's output; bails to SizedBox.shrink when prerequisites unresolved"
  - "MirkStylePickerSheet — bottom sheet listing the 4 builtin mirk styles; tap → MirkStyleSessionController.select → close"
  - "currentSessionMirkStyleIdProvider — async family provider resolving the session row's mirkStyleId for the picker checkmark"
  - "MirkInitialRevealFade — ConsumerStatefulWidget with dedicated AnimationController; fades opacity 0 → 1 over 500 ms (kInitialRevealFadeInMs) on Idle → Tracking transition; resets on Tracking → Idle"
  - "MapScreen Stack integration — Positioned.fill child wrapping MirkInitialRevealFade(MirkOverlay) in a RepaintBoundary as a sibling of the MapLibre platform view (per 09-RESEARCH §Pitfall 2)"
  - "Burger menu Changer le style — replaces Phase 13 snackbar stub with the live picker sheet (or Aucune session active snackbar when Idle)"
affects:
  - plan 09-08 (perf fixture seeds reveal data + reads back through MirkOverlay's pipeline; RepaintBoundary isolation test exercises the boundary this plan inserted; viewport filtering regression test asserts visibleMirkTilesProvider behaviour at 50k+ tiles)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ConsumerStatefulWidget + SingleTickerProviderStateMixin: CustomPainter + Ticker pattern for per-frame Riverpod-watched repaints"
    - "ref.listenManual + idempotence-guard bool: state-transition-driven AnimationController with reset on inverse transition"
    - "Class-based @Riverpod(keepAlive: true) notifier: viewport bbox observable mirroring the Phase 07 MapViewportZoom pattern (debounce + seed + onError-drop)"
    - "Override + ref.onDispose mirroring in tests: swap-test exercises the production lifecycle by re-implementing the ref.onDispose(renderer.dispose) wiring inside the override"
    - "Fixed-cadence pump replacement for pumpAndSettle: any test pumping a tree containing MirkOverlay must use tester.pump() + tester.pump(Duration) — the Ticker never settles"

key-files:
  created:
    - lib/application/providers/map_viewport_provider.dart
    - lib/application/providers/map_viewport_provider.g.dart
    - lib/application/providers/visible_mirk_tiles_provider.g.dart
    - lib/presentation/widgets/mirk_style_picker_sheet.g.dart
    - test/application/providers/map_viewport_provider_test.dart
    - test/application/providers/visible_mirk_tiles_provider_test.dart
    - test/presentation/widgets/mirk_initial_reveal_fade_test.dart
  modified:
    - lib/domain/map/map_view.dart
    - lib/infrastructure/map/maplibre_map_view.dart
    - lib/application/providers/visible_mirk_tiles_provider.dart
    - lib/presentation/widgets/mirk_overlay.dart
    - lib/presentation/widgets/mirk_style_picker_sheet.dart
    - lib/presentation/widgets/mirk_initial_reveal_fade.dart
    - lib/presentation/widgets/session_burger_menu.dart
    - lib/presentation/screens/map_screen.dart
    - test/fakes/fake_map_view.dart
    - test/presentation/widgets/mirk_overlay_feather_test.dart
    - test/presentation/widgets/mirk_overlay_composition_test.dart
    - test/presentation/widgets/mirk_overlay_swap_test.dart
    - test/presentation/widgets/session_burger_menu_style_selector_test.dart
    - test/presentation/screens/map_screen_test.dart
    - integration_test/airplane_mode_test.dart

key-decisions:
  - "mapViewportProvider created as a NEW class-based @Riverpod(keepAlive: true) notifier — Phase 07 only exposed MapViewportZoom (scalar), so plan 09-07 had to land the bbox seam itself rather than reuse an existing provider (resolves revision S2). 50 ms debounce mirrors MapViewportZoom's discipline; onError silently drops viewport-stream errors as Phase 07 convention."
  - "MirkViewportBbox stayed at 4 doubles — NO zoomLevel field added (resolves revision S4). Zoom lives on MirkPaintContext.zoomLevel via the existing MapViewportZoom provider; re-extending the bbox Freezed would have been a second extension event for Phase 09, which the plan 09-02 SUMMARY explicitly closed off."
  - "MapView.queryViewportBounds() port method added rather than computing the bbox from queryViewport() centre + screen size + zoom + Mercator. Cleaner: the MapLibre adapter has the LatLngBounds in hand at call time; a Mercator computation outside infrastructure would have re-derived it from incomplete inputs."
  - "MirkOverlay sessionElapsed uses the Ticker's elapsed Duration (time-since-mount) rather than ActiveSessionController's startedAtUtc-derived duration. Pragmatic alignment per plan 09-02 SUMMARY — renderers consume sessionElapsed for animation phase, which is operationally equivalent to time-since-overlay-mounted. Documented in _MirkPainter."
  - "MirkInitialRevealFade trigger is the Idle → Tracking AsyncValue transition via ref.listenManual, NOT a poll-on-build. listenManual fires `previous, next` callbacks on a safe phase, avoiding the 'modified during build' Riverpod assertion. Idempotence guard (_hasFadedIn) flips false on Tracking → Idle so the next session re-fires."
  - "currentSessionMirkStyleIdProvider was carved out of the picker rather than reading from the controller state directly: ActiveSessionState.Tracking does NOT carry mirkStyleId (it lives on the persisted Session row, behind SessionStore.findById). The new helper provider resolves it via the store; the picker watches it for the trailing checkmark."
  - "Burger menu Changer le style closes the drawer FIRST, then opens the bottom sheet on the underlying Scaffold's context — anchoring the sheet on the drawer's narrow column would clip it. Same pattern future Phase 11/13 wire-ups should follow."
  - "RepaintBoundary wraps MirkInitialRevealFade(MirkOverlay) directly in MapScreen — NOT the entire Stack. Wrapping higher would not isolate the Ticker's repaints from the map platform view's display list (which is what the boundary is for); wrapping lower would be inside MirkInitialRevealFade's FadeTransition, which is also fine but makes the boundary scope harder to reason about. The current placement is the narrowest legal scope around the moving widget."
  - "Test suites swap pumpAndSettle for tester.pump + tester.pump(Duration) anywhere a MirkOverlay-containing tree is pumped. The Ticker is unconditionally on while the overlay is mounted; pumpAndSettle deadlocks. Documented in-tree at every swap site."

requirements-completed: [MIRK-01, MIRK-04, MIRK-05, MIRK-06, MIRK-07]

# Metrics
duration: 24 min
completed: 2026-04-25
---

# Phase 09 Plan 07: MirkOverlay + MirkStylePickerSheet + MapScreen integration — Summary

**End-to-end UI wiring: an active session now paints fog through a Ticker-driven CustomPainter wrapped in a RepaintBoundary, with a 500 ms fade-in on session start, a burger-menu bottom sheet that swaps the renderer on tap, and a viewport-filtered tile snapshot that feeds the renderer paint context.**

## Performance

- **Duration:** ~24 min
- **Started:** 2026-04-25T07:06:54Z
- **Completed:** 2026-04-25T07:30:58Z
- **Tasks:** 5 (all TDD-tagged)
- **Files modified/created:** 22 (7 created + 15 modified)
- **Commits:** 6 atomic commits (5 task commits + 1 follow-up fix)

## Accomplishments

- **Task 1 — `mapViewportProvider` (NEW, resolves revision S2).** Class-based `@Riverpod(keepAlive: true)` notifier publishing `MirkViewportBbox?`. Subscribes to `MapView.viewportUpdates`, debounces 50 ms, refreshes via the new `queryViewportBounds()` port method (returns a MapLibre-free `MirkViewportBbox`). MapLibre adapter implementation reads `getVisibleRegion()` and adapts at the platform boundary per MAP-06. `FakeMapView` extended with `viewportBoundsToReturn` + `queryViewportBoundsCallCount` for test injection. **5 tests** cover null-before-attached, seed-on-first-build, debounce, rapid-fire coalescing, silent error recovery.

- **Task 2 — `visibleMirkTilesProvider` + `MirkOverlay`.** Async `@riverpod` provider enumerates parent tiles (z=14) intersecting the current viewport, hydrates each from `RevealedTileStore`, returns a `List<VisibleMirkTile>`. Tiles without a DB row produce an all-zero bitmap (entire tile = fog). Antimeridian wrap (east < west) short-circuits to empty list per Phase 09 research deferring cross-meridian rendering. `MirkOverlay` is a `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin` hosting a `CustomPainter` that calls `MirkRenderer.paint`. **7 widget tests** cover empty when Idle / no viewport, painting when prerequisites resolved, atmospheric end-to-end smoke through the overlay, Ticker drives multiple paints, bitmap from store flows through verbatim. **4 provider tests** cover the `visibleMirkTilesProvider` behaviour matrix.

- **Task 3 — `MirkStylePickerSheet` + burger menu.** `ConsumerWidget` bottom sheet listing the 4 builtins (loaded via `builtinMirkStylesProvider`). Tap → `MirkStyleSessionController.select` → close. Currently-selected style shows a trailing checkmark resolved through a new `currentSessionMirkStyleIdProvider(SessionId)` helper (the `Tracking` state does not carry `mirkStyleId` — it lives on the persisted `Session` row). Burger menu `Changer le style` ListTile replaces the Phase 13 snackbar stub: closes the drawer, then opens the sheet (or surfaces "Aucune session active" when Idle). **4 widget tests** cover the 4 builtins listed, tap → `updateMirkStyle` call + sheet closes, current selection checkmark, no-session snackbar path.

- **Task 4 — `MirkInitialRevealFade` + `MapScreen` integration (resolves revision B4).** `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin` wraps a child in a `FadeTransition` driven by a dedicated `AnimationController` (decoupled from the main `MirkOverlay` Ticker — fade duration must not depend on the noise tick frequency). Trigger: `activeSessionControllerProvider` Idle → Tracking transition forwards the controller; Tracking → Idle resets opacity to 0 so the next session re-fires the fade. Idempotence guard prevents replay inside a single Tracking session. Duration: `kInitialRevealFadeInMs` (500 ms), `Curves.easeOut`. `MapScreen` Stack now includes a `Positioned.fill` child wrapping `MirkInitialRevealFade(MirkOverlay())` in a `RepaintBoundary` — sibling of the MapLibre platform view per 09-RESEARCH §Pitfall 2. **4 widget tests** cover opacity 0 while Idle, 0 → ~0.5 → 1.0 over 500 ms (easeOut), reset on session end, re-fire on next session start.

- **Task 5 — Renderer swap tests.** `mirk_overlay_swap_test.dart` Wave 0 scaffold replaced with **2 concrete tests**: (a) invalidating `activeMirkRendererProvider` disposes the old renderer (via `ref.onDispose`) AND the new renderer paints on the next frame; (b) multi-swap chain — 3 renderers swapped consecutively, first two disposed, third alive and painting. Tests use `UncontrolledProviderScope` so they can `invalidate(...)` the provider directly through a captured `ProviderContainer`.

## Stack structure (final)

```
MapScreen
├─ Scaffold
│   ├─ drawer: SessionBurgerMenu (Changer le style → MirkStylePickerSheet)
│   └─ body: Stack
│       ├─ Positioned.fill: MapLibreMapViewWidget          (Phase 07)
│       ├─ Positioned.fill: RepaintBoundary                 ← Plan 09-07
│       │   └─ MirkInitialRevealFade
│       │       └─ MirkOverlay
│       │           └─ CustomPaint (MirkRenderer.paint)
│       ├─ Positioned: BackButton + _MenuButton            (Phase 07)
│       ├─ Positioned: MapFollowMeFab + MapAttributionIcon (Phase 07)
│       └─ Positioned: MapCountryBanner                    (Phase 07)
```

## Provider wiring diagram

```
                +-------------------------------+
                | activeSessionControllerProvider|  (Phase 05)
                +---------------+---------------+
                                |
            Tracking(sessionId) | Idle / Starting
                                |
                                v
                +-------------------------------+
                | mapViewportProvider           |  (NEW — plan 09-07)
                | (subscribe + debounce + seed) |  
                +---------------+---------------+
                                |
                                v
                +-------------------------------+
                | visibleMirkTilesProvider      |  (NEW — plan 09-07)
                | (RevealedTileStore.findByParent +
                |  TileMath.latLonToTile)       |
                +---------------+---------------+
                                |
                                v
                +-------------------------------+
                | MirkOverlay widget            |  (NEW — plan 09-07)
                | (Ticker + CustomPainter)      |
                +---------------+---------------+
                                |
                                v
                +-------------------------------+
                | activeMirkRendererProvider    |  (plan 09-05)
                | (resolves session.mirkStyleId)|
                +-------------------------------+
                                |
                  burger menu picker tap
                                v
                +-------------------------------+
                | MirkStyleSessionController    |  (plan 09-06)
                | .select(sessionId, styleId)   |
                +-------------------------------+
                                |
                  ref.invalidate(activeMirkRendererProvider)
```

## Task Commits

1. **Task 1: mapViewportProvider + queryViewportBounds port** — `479f3ac` (feat)
2. **Task 2: visibleMirkTilesProvider + MirkOverlay** — `46cf14a` (feat)
3. **Task 3: MirkStylePickerSheet + burger menu wire-up** — `bfcfe2c` (feat)
4. **Task 4: MirkInitialRevealFade + MapScreen integration** — `57ebc1a` (feat)
5. **Task 5: MirkOverlay swap tests** — `7a7479f` (test)
6. **Follow-up: airplane_mode integration test pumpAndSettle fix** — `5c81c65` (fix)

## Files Created/Modified

### New (7)
- `lib/application/providers/map_viewport_provider.dart` — class-based `@Riverpod(keepAlive: true)` notifier publishing `MirkViewportBbox?`.
- `lib/application/providers/map_viewport_provider.g.dart` — generated Riverpod glue.
- `lib/application/providers/visible_mirk_tiles_provider.g.dart` — generated Riverpod glue.
- `lib/presentation/widgets/mirk_style_picker_sheet.g.dart` — generated Riverpod glue (for `currentSessionMirkStyleIdProvider`).
- `test/application/providers/map_viewport_provider_test.dart` — 5 tests for the new viewport provider.
- `test/application/providers/visible_mirk_tiles_provider_test.dart` — 4 tests for the visible-tile provider.
- `test/presentation/widgets/mirk_initial_reveal_fade_test.dart` — 4 tests for the fade widget.

### Modified (15)

**Production code (8):**
- `lib/domain/map/map_view.dart` — added `queryViewportBounds()` port method.
- `lib/infrastructure/map/maplibre_map_view.dart` — implemented `queryViewportBounds()` via `getVisibleRegion()`.
- `lib/application/providers/visible_mirk_tiles_provider.dart` — Wave 0 stub replaced with the real async provider.
- `lib/presentation/widgets/mirk_overlay.dart` — Wave 0 SizedBox stub replaced with the real Ticker-driven CustomPainter.
- `lib/presentation/widgets/mirk_style_picker_sheet.dart` — Wave 0 SizedBox stub replaced with the real bottom sheet + helper provider.
- `lib/presentation/widgets/mirk_initial_reveal_fade.dart` — Wave 0 passthrough replaced with the dedicated AnimationController + FadeTransition.
- `lib/presentation/widgets/session_burger_menu.dart` — `Changer le style` onTap replaces Phase 13 snackbar with the picker sheet.
- `lib/presentation/screens/map_screen.dart` — Stack now includes `RepaintBoundary(MirkInitialRevealFade(MirkOverlay))` as a sibling of the MapLibre platform view.

**Test code (7):**
- `test/fakes/fake_map_view.dart` — added `queryViewportBounds()` impl + observables.
- `test/presentation/widgets/mirk_overlay_feather_test.dart` — Wave 0 scaffold replaced with 3 concrete tests.
- `test/presentation/widgets/mirk_overlay_composition_test.dart` — Wave 0 scaffold replaced with 4 concrete tests.
- `test/presentation/widgets/mirk_overlay_swap_test.dart` — Wave 0 scaffold replaced with 2 concrete swap-lifecycle tests.
- `test/presentation/widgets/session_burger_menu_style_selector_test.dart` — Wave 0 scaffold replaced with 4 concrete picker-flow tests.
- `test/presentation/screens/map_screen_test.dart` — pumpAndSettle calls swapped for fixed-cadence pumps (MirkOverlay Ticker workaround).
- `integration_test/airplane_mode_test.dart` — pumpAndSettle swapped for fixed-cadence pumps.

## Decisions Made

(extracted to `key-decisions:` frontmatter — see top of file)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Tracking` state does NOT carry `mirkStyleId` — added `currentSessionMirkStyleIdProvider`**
- **Found during:** Task 3 (analyzer error compiling the picker)
- **Issue:** Plan 09-07 Task 3 specified the picker would resolve the current style id via `ref.watch(activeSessionControllerProvider).valueOrNull?.whenOrNull(tracking: (s, _) => s.mirkStyleId)`. The actual `Tracking` class only carries `(sessionId, startedAtUtc, fixCount, distanceFilterMeters, lastFix)` — no `mirkStyleId`. The id lives on the persisted `Session` row.
- **Fix:** Added `currentSessionMirkStyleIdProvider(SessionId)` async family helper that reads the session row from `SessionStore.findById` and returns the row's `mirkStyleId`. Picker watches this provider for the checkmark.
- **Files modified:** `lib/presentation/widgets/mirk_style_picker_sheet.dart`, generated `.g.dart`.
- **Verification:** Test "currently-selected style shows trailing checkmark" passes with the candlelight pre-seed.
- **Committed in:** `bfcfe2c`

**2. [Rule 3 - Blocking] `Override` is not a type in Riverpod 3.x — drop the type annotation**
- **Found during:** Task 1 (initial test compile)
- **Issue:** Test used `overrides: <Override>[...]`; Riverpod 3.x removed the public `Override` type alias.
- **Fix:** Removed the type annotation — Dart infers from the list literal.
- **Files modified:** `test/application/providers/map_viewport_provider_test.dart`.
- **Committed in:** `479f3ac`

**3. [Rule 3 - Blocking] `pumpAndSettle` deadlocks on MirkOverlay's never-settling Ticker**
- **Found during:** Task 2 (mirk_overlay_feather_test first run) and Task 4 (map_screen_test full run) and Task 5 follow-up (airplane_mode integration test 12-min hang)
- **Issue:** `MirkOverlay` mounts a Ticker that fires every frame indefinitely. `tester.pumpAndSettle()` waits until no frame is scheduled — never true while the Ticker runs. All test sites pumping a tree containing `MirkOverlay` would hang.
- **Fix:** Replaced `pumpAndSettle` with `tester.pump() + tester.pump(Duration(milliseconds: …))` in:
  - `test/presentation/widgets/mirk_overlay_feather_test.dart`
  - `test/presentation/widgets/mirk_overlay_composition_test.dart`
  - `test/presentation/screens/map_screen_test.dart` (5 sites)
  - `integration_test/airplane_mode_test.dart`
- **Verification:** All affected test files green; integration suite completes in ~3 min.
- **Committed in:** Mixed across `46cf14a` (Task 2 tests) / `57ebc1a` (Task 4 map_screen_test) / `5c81c65` (integration follow-up).

**4. [Rule 3 - Blocking] Test override of `activeMirkRendererProvider` must mirror the production `ref.onDispose(renderer.dispose)` wiring**
- **Found during:** Task 5 (swap test initial fail — disposeCallCount stayed at 0 after invalidate)
- **Issue:** When a test overrides a provider with a `(ref) async => fakeRenderer` closure, the override REPLACES the production body — including the `ref.onDispose(renderer.dispose)` line. Without re-wiring it, invalidating the provider does not call `renderer.dispose`.
- **Fix:** Test override now re-implements `ref.onDispose(r.dispose)` inside the closure, mirroring the production lifecycle.
- **Files modified:** `test/presentation/widgets/mirk_overlay_swap_test.dart`.
- **Committed in:** `7a7479f`

**5. [Rule 3 - Blocking] `RevealedTile` test fake required `RevealedTileId` extension type + `setBitCount` field**
- **Found during:** Task 2 (visibleMirkTilesProvider test compile)
- **Issue:** `_FakeRevealedTileStore` constructed `RevealedTile(id: 'rvt_test_xy', popcount: …)` — but the entity uses `RevealedTileId(value)` extension type and the field is `setBitCount`, not `popcount`.
- **Fix:** Wrapped in `RevealedTileId(...)` and renamed `popcount` → `setBitCount` (kept the local helper that computes the value).
- **Files modified:** `test/application/providers/visible_mirk_tiles_provider_test.dart`.
- **Committed in:** `46cf14a`

**6. [Rule 3 - Blocking] `avoid_redundant_argument_values` lint after dart-format reflow**
- **Found during:** Tasks 1, 2, 3 (post-format analyzer)
- **Issue:** `dart format` introduced reflows that touched lines and surfaced previously-tolerated `avoid_redundant_argument_values` lints (e.g., `parentZoom: kRevealedTileParentZoom` matched the default).
- **Fix:** Dropped redundant arguments at each surfaced site.
- **Files modified:** various test files.
- **Committed in:** Mixed.

---

**Total deviations:** 6 auto-fixed (5 Rule 3 - Blocking + 1 lint follow-up), all directly caused by plan 09-07's own diff or the Phase 09 Tracking-state shape that the plan author misremembered. Zero deviations escalated to Rule 4 (architectural).

**Impact on plan:** All auto-fixes essential for correctness (current-style helper provider) or testability (Ticker pump cadence + override lifecycle wiring + entity field names). No scope creep beyond the helper provider.

## Issues Encountered

- **Pre-existing flakes still present.** The full suite ships green this round (923 / 7 skipped). The two flakes from plan 09-06 close (`backup_test.dart::rotate keeps the 3 newest`, `download_soak_test.dart::soak: rename_target_already_exists`) did NOT surface in this plan's verification run, but they are still flaky under sustained parallel execution per the deferred-items log. Not addressed — out of scope for plan 09-07.

## User Setup Required

None — no external service configuration required. All changes are local Dart code + Riverpod wiring.

## Revision resolution log

- **Revision S2 — `mapViewportProvider` did not exist.** RESOLVED. Plan 09-07 Task 1 created the provider as a NEW class-based `@Riverpod(keepAlive: true)` notifier. No conditional branching at execution time — the absence was confirmed at plan start, the provider was created.
- **Revision S4 — `MirkViewportBbox` re-extension with a `zoomLevel` field.** REJECTED, NOT EXTENDED. Zoom lives on `MirkPaintContext.zoomLevel` via the existing `MapViewportZoom` provider; `MirkViewportBbox` stays at 4 doubles.
- **Revision B4 — initial reveal fade-in was not split off.** RESOLVED. `MirkInitialRevealFade` widget created with a dedicated `AnimationController`, decoupled from the main `MirkOverlay` Ticker. 500 ms fade-in observed in the widget test (0 → ~0.5+ at 250 ms with `Curves.easeOut`, → 1.0 by 500 ms).

## Next Plan Readiness

Ready for **plan 09-08** (perf fixture + viewport-filtering regression + RepaintBoundary isolation test). Plan 09-08 will:

1. Seed a 50k-tile reveal corpus through this plan's `visibleMirkTilesProvider` + `RevealedTileStore` (plan 09-06).
2. Pump `MirkOverlay` on a small viewport over the dataset, assert the painter sees only the visible parent tiles (viewport filtering SC#5 regression).
3. Use a `RepaintBoundary` debug shader / paint-count probe to assert the boundary inserted in `MapScreen` (plan 09-07 Task 4) actually isolates the noise tick from the rest of the Stack.

The end-to-end visual loop is now closed: start session → mirk fades in → burger menu → pick candlelight → renderer swaps on next frame → mirk re-renders.

## Self-Check: PASSED

All 7 created files verified on disk:
- `lib/application/providers/map_viewport_provider.dart` ✓
- `lib/application/providers/map_viewport_provider.g.dart` ✓
- `lib/application/providers/visible_mirk_tiles_provider.g.dart` ✓
- `lib/presentation/widgets/mirk_style_picker_sheet.g.dart` ✓
- `test/application/providers/map_viewport_provider_test.dart` ✓
- `test/application/providers/visible_mirk_tiles_provider_test.dart` ✓
- `test/presentation/widgets/mirk_initial_reveal_fade_test.dart` ✓

All 6 commits reachable via `git log --oneline -10`:
- `479f3ac` (Task 1) ✓
- `46cf14a` (Task 2) ✓
- `bfcfe2c` (Task 3) ✓
- `57ebc1a` (Task 4) ✓
- `7a7479f` (Task 5) ✓
- `5c81c65` (follow-up fix) ✓

Full suite: 923 tests passed (7 skipped). Integration suite: 14 tests passed.

---
*Phase: 09-fog-rendering*
*Plan: 09-07*
*Completed: 2026-04-25*
