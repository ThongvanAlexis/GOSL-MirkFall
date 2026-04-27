# BUG-012 — Fog strobes during map pan/zoom

**Status:** ✅ fixed — `8486d3e`, `c0c14a6`, `d6784a4` (3 iterations)
**Reported:** 2026-04-26 (UAT walk on `c41f31d` after BUG-010 disc refactor shipped)
**Platform:** cross-platform (renderer CPU-side + widget layer, same on iOS + Android)

## Symptoms

When panning or zooming the map, the fog boundary "strobes" — flickers between different positions. Standing still, the fog is stable. The flicker is rapid (20 Hz during gestures) and makes the fog feel broken.

## Investigation findings

This bug required 3 iterations to fully resolve because the visible symptom (strobe) had two independent root causes at different layers of the stack. The renderer-level fixes (iterations 1 and 2) reduced but did not eliminate the strobe, which prompted deeper investigation into the widget layer.

### Iteration 1 — SDF rebuild thrashing (renderer layer)

**Root cause:** `_computeSdfHash` included the viewport bbox. During a pan gesture the viewport changes every frame, hash changes, `buildFromDiscs` triggered on every frame not already mid-build. Each build takes 200+ ms. By the time build A completes, the viewport has moved; the SDF is shown for position A while the map shows position B — visual mismatch. The next build fires for position B, and the cycle repeats, causing the reveal boundary to jump between stale viewport positions on every build-completion.

**What was tried:** Considered (a) making the SDF build faster (spatial index), (b) debouncing viewport changes, (c) freezing the SDF during gestures. Chose (b) because it was the simplest correct fix — the SDF only needs to be pixel-accurate when the gesture settles, not mid-gesture.

**Fix:** Split the hash into disc-list-hash and viewport-hash. Disc changes trigger immediate rebuilds (GPS fix — reveal must appear now). Viewport-only changes are debounced (200 ms, configurable via `kMirkFogSdfViewportDebounceMs`): during a gesture the old SDF is reused (slightly misaligned but stable); 200 ms after the gesture settles, one rebuild aligns the SDF to the final viewport.

Applied to both `atmospheric_mirk_renderer.dart` and `heavenly_clouds_mirk_renderer.dart` (the only two renderers with the SDF rebuild pattern). Candlelight and solid_fill do not use SDF.

### Iteration 2 — SDF viewport drift (renderer layer)

**Remaining symptom:** After the debounce, the fog no longer strobed rapidly, but during a pan the revealed area visibly slid with the viewport (the SDF was painted at fixed pixel coordinates, not at fixed geo coordinates).

**Fix:** Added dynamic `sdfRect` computation — track which viewport the SDF was built for (`_sdfViewport`) and map it onto the current viewport each frame. The reveal now stays pinned at its true lat/lon position during pan/zoom instead of sliding with the viewport.

### Iteration 3 — Widget-layer AsyncLoading gap (2026-04-27)

**Remaining symptom:** Strobe persisted despite the debounce + sdfRect fixes.

**Root cause:** The root cause was at the **widget layer**, not the renderer layer. `discsInViewportProvider` is a Riverpod family provider keyed by `MirkViewportBbox`. Every viewport change (20 Hz during pan) creates a **new** provider instance that starts in `AsyncLoading` with no previous value. The overlay's bail-out logic checked `!discsAsync.hasValue` and returned `SizedBox.shrink()`, making the fog disappear for one frame. The disc query resolves in < 2 ms, so the fog reappears on the next frame — but the off/on cycle at 20 Hz produces the visible strobe.

**Evidence from logs (`20260427_0926.28_logs.txt`):** During a pinch-zoom gesture, the overlay logged `rendering → discsAsync not hasValue (AsyncLoading<List<RevealDisc>>)` and `discsAsync not hasValue → rendering` alternating every ~50 ms, confirming the overlay toggled between rendering and returning `SizedBox.shrink()` on every viewport update.

**Fix:** Added a `_lastKnownDiscs` field to `_MirkOverlayState`. When `discsAsync` has data, cache it. When `discsAsync` is loading (new family instance, no previous value), use the cached list instead of bailing out. The fog keeps painting with stale-but-stable data until the fresh query resolves (< 2 ms). The stale data contains the same disc IDs — the viewport bbox changed but the discs within it are identical — so there is zero visual difference.

## Trade-off

During a pan gesture, the disc list used for painting may be from the previous viewport (stale by one query cycle, < 2 ms). Since the disc content is identical (same discs, same lat/lon/radius), this has no visual impact. The SDF rebuild debounce + sdfRect mapping from iterations 1-2 handle the renderer-level viewport alignment independently.

## Commits

```
8486d3e  fix(09-bug-012): debounce SDF rebuild on viewport-only changes (anti-strobe)
5871be0  docs(09-bug-012): stamp commit SHA in BUG-012 tracker
c0c14a6  fix(09-bug-012): pin SDF to lat/lon via dynamic sdfRect during pan/zoom
d6784a4  fix(09-bug-012): cache disc list across viewport changes to stop widget-layer strobe
```

## Files modified

- `lib/config/constants.dart` — added `kMirkFogSdfViewportDebounceMs`
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — debounce logic + sdfRect computation
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — parallel debounce + sdfRect changes
- `lib/presentation/widgets/mirk_overlay.dart` — `_lastKnownDiscs` cache to survive AsyncLoading gaps
- `test/infrastructure/mirk/sdf_debounce_test.dart` — debounce regression test

## Test coverage

- `sdf_debounce_test.dart` — verifies that viewport-only changes are debounced (no immediate SDF rebuild) while disc-list changes trigger immediate rebuilds
- The widget-layer cache fix (iteration 3) was verified via log analysis during UAT rather than a unit test, because the symptom depends on Riverpod family provider lifecycle timing that is difficult to reproduce in isolation

## Known follow-ups

- [ ] Consider replacing the Riverpod family provider keyed by `MirkViewportBbox` with a single provider that updates in-place, eliminating the `AsyncLoading` gap entirely (structural fix vs the cache workaround)
- [ ] The debounce constant `kMirkFogSdfViewportDebounceMs = 200` may need tuning on slower devices — too short reintroduces thrashing, too long makes the fog visibly lag after a gesture

## Links

- **BUG-010** — parent refactor that introduced the disc-based SDF rebuild triggering mechanism
- **BUG-011** — discovered in the same UAT walk session
- **BUG-013** — related empty-disc-list handling issue (fog disappears when no discs in viewport)
- **BUG-014** — sdfRect axis swap discovered while testing the sdfRect mapping from iteration 2
