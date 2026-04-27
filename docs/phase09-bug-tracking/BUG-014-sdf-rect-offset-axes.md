# BUG-014 — Fog overlay doesn't track map movement (SDF in screen space, not map space)

**Status:** 🔴 OPEN — 4 iterations attempted and all reverted or insufficient. Root cause is architectural: the mirk overlay is a Flutter `CustomPainter` in screen space, not a map-integrated layer. Decision: render fog as a MapLibre custom layer.
**Reported:** 2026-04-27 (UAT walk at zoom ~12.28 on iOS, post-BUG-010 disc refactor)
**Platform:** cross-platform (Flutter overlay architecture, not GPU-specific)

## Symptoms

1. **Offset during pan/zoom/combined gestures:** The revealed area displaces from its correct geo-position. Pure pan and pure zoom were partially fixed, but combined pinch-zoom+pan still displaces.
2. **Fog moves with the camera:** The fog overlay moves as if painted on the screen, not as actual fog on the map. When you pan, the fog slides with the camera for 1-2 frames then snaps back. This is the ROOT symptom — the offset bugs are consequences.
3. **White ellipse artefact:** Fast zoom+move creates a persistent large white ellipse on the boundary.

## Root cause (architectural)

The mirk (fog) is rendered as a **Flutter `CustomPainter` widget overlaid on top of the MapLibre map widget**. It lives in screen space, not map space.

- MapLibre renders map tiles natively at 60fps via Metal/Vulkan/OpenGL.
- The Flutter overlay repaints when: (a) the viewport provider delivers a new bbox, (b) the widget tree rebuilds.
- There is inherent **latency** between the map's native camera movement and the Flutter overlay catching up — the overlay bbox comes from a platform channel query at ~20 Hz, not synced to the map's GPU frame.

Every fog-of-war application solves this by rendering the fog **as part of the map's rendering pipeline** (a map layer), not as an overlay. The fog texture is in world coordinates; camera movement changes the UV sampling, not the texture.

## Iterations attempted (all insufficient)

### Iteration 1 — Shader slot reorder (`d05dbb2`)

**Hypothesis:** Impeller's SPIR-V→MSL transpiler misaligned the `uSdfRect` float slots because `uniform sampler2D uSdf` was declared between float uniforms.
**Fix:** Moved `uSdfRect` declaration before the sampler.
**Result:** Fixed pure pan + pure zoom. Combined zoom+pan still broke.
**Status:** Kept (the slot ordering fix is correct regardless).

### Iteration 2 — vec4 → 4 scalar uniforms (`bf6532b`)

**Hypothesis:** Metal reorders vec4 components near a sampler boundary.
**Fix:** Decomposed `uniform vec4 uSdfRect` into 4 scalar `uniform float`.
**Result:** No change for combined zoom+pan.
**Status:** Kept (scalar uniforms are more robust regardless).

### Iteration 3 — Drop dynamic sdfRect entirely (`af15c12`)

**Hypothesis:** The sdfRect remapping math is unreliable due to viewport bbox platform-channel lag.
**Fix:** Always pass identity sdfRect `(0, 0, 1, 1)`. Accept that the SDF watercolour boundary drifts during gestures, let the clip path provide the hard boundary, rebuild SDF when gesture settles (200ms debounce).
**Result:** User rejected. The revealed area stays in place during gestures (stale SDF) and snaps to position after rebuild — ugly. Fast zoom+move creates a persistent white ellipse.
**Status:** ⬅️ REVERTED (`f5d5b27`).

### Iteration 4 — Build SDF in disc-bbox coordinates (`a1d58ad`)

**Hypothesis:** Building the SDF in world coordinates (disc bounding box) instead of viewport coordinates — the fog-of-war standard approach. SDF rebuilds only on disc-list change, not viewport change. Per-frame UV remapping from screen to disc-bbox space.
**Fix:** `buildFromDiscs` returns `SdfBuildResult` with both image + disc bbox. Renderers compute `_computeSdfRect` per frame mapping disc bbox onto current viewport.
**Result:** Made things worse — weird ellipse boundary, no correct repositioning.
**Status:** ⬅️ REVERTED (`f5d5b27`).

## Why all 4 iterations failed

All attempts tried to keep the fog as a **Flutter screen-space overlay** and compensate for the mismatch between screen space and map space via SDF coordinate tricks. The fundamental problem is that:

1. The viewport bbox arrives via platform channel with 1-2 frame lag.
2. During combined gestures (pinch-zoom+pan), both translation AND scale change per frame — any remapping amplifies the lag.
3. The `CustomPainter` is repainted after the map's native rendering, so the fog is always 1+ frames behind the map.

**No amount of SDF coordinate trickery can fix a screen-space overlay lagging behind a native map renderer.**

## Decision: render fog as a MapLibre custom layer

**Decided:** 2026-04-27, after iteration 4 revert.

The fog must be rendered **inside MapLibre's rendering pipeline** so it moves with the map natively at 60fps, with zero lag.

### Options evaluated

| Option | Description | Effort | Lag |
|--------|-------------|--------|-----|
| **(A) MapLibre raster tile source** | Generate fog as raster tiles (256×256 per tile), inject as a MapLibre raster source. MapLibre composites them with the map natively. | Medium (~3-5 days) | Zero |
| **(B) `onCameraMove` transform** | Keep Flutter overlay but apply an affine `Transform` widget matching the map's camera delta. | Small (~1 day) | Low (1 frame) |
| **(C) MapLibre custom GL layer** | Inject a custom OpenGL/Metal draw call via MapLibre's custom layer API. | Large (~1 week) | Zero |
| **(D) MapLibre fill-extrusion or fill layer** | Use MapLibre's built-in polygon fill layers with the revealed area as inverted GeoJSON. | Medium (~2-3 days) | Zero |

**Recommended: Option A (raster tile source)** — MapLibre is designed to composite raster tiles. We generate the fog as tiles on the CPU (reusing the SDF builder logic), inject them as a raster source, and MapLibre handles compositing, caching, and camera tracking. No shader porting needed — the fog texture IS the tile.

**Option D** is the simplest if the fog doesn't need the watercolour/noise visual effects (just a solid semi-transparent fill with a smooth boundary). Worth prototyping first.

**Option B** is a quick win for reducing lag from ~3 frames to ~1 frame, but doesn't eliminate it. Could be a stop-gap while Option A is built.

### Performance (user question: "can the phone handle 60fps?")

Yes. The GPU is ALREADY rendering the fog shader at ~60fps in the current Flutter overlay. Moving it to MapLibre's pipeline is the same GPU work in a different pipeline. The SDF texture (256×256) is tiny. The heavy CPU work (`buildFromDiscs`) only runs on disc-list change (~1/sec), not per frame. Mobile games render fog-of-war over 3D terrain with lighting + shadows + particles at 60fps on the same hardware.

## Current state after reverts

After reverting `af15c12` and `a1d58ad` (revert commit `f5d5b27` + `ebb7097`), the codebase is back to the state after iteration 1+2:
- Shader has correct scalar uniform slots (iterations 1+2 kept)
- SDF builds in viewport coordinates (original architecture)
- Viewport-only changes debounced 200ms (BUG-012 fix kept)
- The fog still moves with the camera (screen-space overlay)
- Combined zoom+pan still displaces the reveal (iterations 1+2 didn't fully fix this)

**Next step:** Implement Option A or D from the table above. This is a Phase 09.1 or Phase 10 scope item — requires map-layer integration, not just renderer tweaks.

## Commits (chronological)

```
d05dbb2  fix(09-bug-014): correct sdfRect axis mapping (X↔Y swap during pan) [kept]
bf6532b  fix(09-bug-014): decompose vec4 into scalar uniforms [kept]
af15c12  fix(09-bug-014): drop dynamic sdfRect; identity mapping [REVERTED]
a1d58ad  fix(09-bug-014): build SDF in disc-bbox coordinates [REVERTED]
f5d5b27  Revert a1d58ad
ebb7097  Revert af15c12
```

## Links

- **BUG-010** — the disc-based reveal refactor that surfaced this bug
- **BUG-011** — oval boundary (fixed, metre-space distance)
- **BUG-012** — strobing (fixed, widget-layer disc cache + debounce)
- **BUG-013** — mirk disappears off-screen (fixed, removed empty-disc early-return)
- **BUG-015** — wisp burst on open (fixed, time-based warm-up)
