# BUG-012 — Fog strobes during map pan/zoom

**Status:** fixed
**Reported:** 2026-04-26 (UAT walk on `c41f31d` after BUG-010 disc refactor shipped)
**Platform:** cross-platform (renderer CPU-side, same on iOS + Android)

## Symptoms

When panning or zooming the map, the fog boundary "strobes" — flickers between different positions. Standing still, the fog is stable.

## Root cause

`_computeSdfHash` included the viewport bbox. During a pan gesture the viewport changes every frame → hash changes → `buildFromDiscs` triggered on every frame not already mid-build. Each build takes 200+ ms. By the time build A completes, the viewport has moved; the SDF is shown for position A while the map shows position B → visual mismatch. The next build fires for position B, and the cycle repeats, causing the reveal boundary to jump between stale viewport positions on every build-completion.

## Fix

Split the hash into disc-list-hash and viewport-hash. Disc changes trigger immediate rebuilds (GPS fix → reveal must appear now). Viewport-only changes are debounced (200 ms, configurable via `kMirkFogSdfViewportDebounceMs`): during a gesture the old SDF is reused (slightly misaligned but stable); 200 ms after the gesture settles, one rebuild aligns the SDF to the final viewport.

Applied to both `atmospheric_mirk_renderer.dart` and `heavenly_clouds_mirk_renderer.dart` (the only two renderers with the SDF rebuild pattern). Candlelight and solid_fill do not use SDF.

## Trade-off

During a pan gesture, the revealed area "slides" slightly because the old SDF was built for the pre-gesture viewport. This is cosmetically imperfect but dramatically better than the strobe. A future spatial-index optimisation (TODO at `revealed_sdf_builder.dart:103`) that brings build time to sub-16 ms would allow per-frame rebuilds and eliminate both the strobe and the slide.
