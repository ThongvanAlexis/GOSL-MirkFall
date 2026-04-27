# BUG-012 — Fog strobes during map pan/zoom

**Status:** fixed (3 iterations)
**Reported:** 2026-04-26 (UAT walk on `c41f31d` after BUG-010 disc refactor shipped)
**Platform:** cross-platform (renderer CPU-side, same on iOS + Android)

## Symptoms

When panning or zooming the map, the fog boundary "strobes" — flickers between different positions. Standing still, the fog is stable.

## Root cause (original — iteration 1, `8486d3e`)

`_computeSdfHash` included the viewport bbox. During a pan gesture the viewport changes every frame → hash changes → `buildFromDiscs` triggered on every frame not already mid-build. Each build takes 200+ ms. By the time build A completes, the viewport has moved; the SDF is shown for position A while the map shows position B → visual mismatch. The next build fires for position B, and the cycle repeats, causing the reveal boundary to jump between stale viewport positions on every build-completion.

## Fix (iteration 1)

Split the hash into disc-list-hash and viewport-hash. Disc changes trigger immediate rebuilds (GPS fix → reveal must appear now). Viewport-only changes are debounced (200 ms, configurable via `kMirkFogSdfViewportDebounceMs`): during a gesture the old SDF is reused (slightly misaligned but stable); 200 ms after the gesture settles, one rebuild aligns the SDF to the final viewport.

Applied to both `atmospheric_mirk_renderer.dart` and `heavenly_clouds_mirk_renderer.dart` (the only two renderers with the SDF rebuild pattern). Candlelight and solid_fill do not use SDF.

## Fix (iteration 2 — `c0c14a6`)

Added dynamic `sdfRect` computation — track which viewport the SDF was built for (`_sdfViewport`) and map it onto the current viewport each frame. The reveal now stays pinned at its true lat/lon position during pan/zoom instead of sliding with the viewport.

## Root cause (persistent strobe — iteration 3, 2026-04-27)

Strobe persisted despite the debounce + sdfRect fixes because the root cause was at the **widget layer**, not the renderer layer.

`discsInViewportProvider` is a Riverpod family provider keyed by `MirkViewportBbox`. Every viewport change (20 Hz during pan) creates a **new** provider instance that starts in `AsyncLoading` with no previous value. The overlay's bail-out logic checked `!discsAsync.hasValue` and returned `SizedBox.shrink()`, making the fog disappear for one frame. The disc query resolves in < 2 ms, so the fog reappears on the next frame — but the off/on cycle at 20 Hz produces the visible strobe.

**Evidence from logs (`20260427_0926.28_logs.txt`):** During a pinch-zoom gesture, the overlay logged `rendering → discsAsync not hasValue (AsyncLoading<List<RevealDisc>>)` and `discsAsync not hasValue → rendering` alternating every ~50 ms, confirming the overlay toggled between rendering and returning `SizedBox.shrink()` on every viewport update.

## Fix (iteration 3)

Added a `_lastKnownDiscs` field to `_MirkOverlayState`. When `discsAsync` has data, cache it. When `discsAsync` is loading (new family instance, no previous value), use the cached list instead of bailing out. The fog keeps painting with stale-but-stable data until the fresh query resolves (< 2 ms). The stale data contains the same disc IDs — the viewport bbox changed but the discs within it are identical — so there is zero visual difference.

**File modified:** `lib/presentation/widgets/mirk_overlay.dart`

## Trade-off

During a pan gesture, the disc list used for painting may be from the previous viewport (stale by one query cycle, < 2 ms). Since the disc content is identical (same discs, same lat/lon/radius), this has no visual impact. The SDF rebuild debounce + sdfRect mapping from iterations 1-2 handle the renderer-level viewport alignment independently.
