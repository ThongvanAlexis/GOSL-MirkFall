---
status: awaiting_human_verify
trigger: "la zone découverte se décale du point bleu quand je pan sur android (UAT Phase 09.1 same-canvas fog port-back, Pixel 6 Pro, build f347eeb)"
created: 2026-09-11T00:00:00Z
updated: 2026-09-11T18:00:00Z
---

## Current Focus

hypothesis: CONFIRMED and fixed locally — screen-glued SDF during pan (overlay-era viewport-only debounce kept while the dynamic sdfRect that made it harmless was removed by 09.1)
test: user UAT on the Pixel 6 Pro (and iPhone) with a build containing the fix, panning with a walked session
expecting: the revealed zone (soft SDF halo + clip hole) stays glued to the blue puck while the finger moves; no snap-back after release. If a shift persists on Android only, re-open H1 (Impeller-Vulkan on Mali) with verbose logging ON (fog_transform + sdf rollups).
next_action: orchestrator reviews the uncommitted working tree, commits, ships a CI build; user confirms on device → archive session

## Symptoms

expected: fog holes (revealed discs) stay glued to the blue CircleLayer puck and to the tiles while panning
actual: on Android (Pixel 6 Pro, Impeller?), the revealed zone shifts relative to the blue dot when panning
errors: none in INFO log (to verify in logcat)
reproduction: open map with a walked session, pan with one finger
started: first UAT of phase 09.1 build f347eeb; POC on Pixel 4a validated with no drift
unknowns: transient (snaps back) vs permanent; direction vs pan; iPhone?

## Eliminated

- hypothesis: H1 — Android corrections (FOG-21 V-flip / FOG-23 pixelOrigin.y sign) applied to the wrong quantity or wrong for Impeller-Vulkan on Mali
  evidence: corrections touch only uPixelOrigin (noise sampling) and the static sdfRect V-flip; neither depends on the pan. A wrong V-flip would be a STATIC vertical mirror of the halo, not a displacement that grows with the pan. Clip path / projector / metersToPixels use the raw camera (fog_layer.dart paint(), fog_clip_path.dart).
  timestamp: 2026-09-11 step 4
- hypothesis: H2 — devicePixelRatio 3.5 mixed into one geometry path but not the other
  evidence: pixelRatio only reaches the CPU feather sigma (atmospheric _paintFallbackPath) — not the clip, not uResolution (= logical size), not pixelOrigin, not sdfRect. FlutterFragCoord/uResolution is DPR-agnostic.
  timestamp: 2026-09-11 step 4
- hypothesis: H3 — stale MapCamera snapshot in the Ticker-driven painter while flutter_map layers use the live camera
  evidence: FogLayer.build depends on MapInheritedModel aspect `camera` (flutter_map 7.0.2 inherited_model.dart 33-38) exactly like CircleLayer; a new painter is created per camera change (fog_pan_translation_test proves a new painter after move). POC used the identical mechanism and validated on device.
  timestamp: 2026-09-11 step 4
- hypothesis: H5 — float32 precision of worldPx at z15-18 near lon 2.6° / lat 48.5°
  evidence: worldPx feeds only the NOISE (uPixelOrigin); the reveal is the clip (CPU double) + the SDF sampled at fragUv (small numbers). fp32 loss there = sub-pixel noise jitter, not a reveal displacement.
  timestamp: 2026-09-11 step 4

## Evidence

- timestamp: 2026-09-11 step 1
  checked: lib/presentation/widgets/fog_layer.dart painter order vs POC fog_layer.dart @90c9321 lines 480-500
  found: identical order — getTransform ×1 → save → translate(-canvasOffset) → clipPath(raw) → corrections on raw pixelOrigin → shader. DPR only reaches the CPU feather sigma. Clip and CircleLayer use the same camera.latLngToScreenPoint.
  implication: H1 (corrections on the wrong quantity) and H2 (DPR mixed in) have no code support in the painter; the clip hole and the puck share one projection.

- timestamp: 2026-09-11 step 2
  checked: assets/shaders/atmospheric_fog.frag sampleSdf(): sdfUv = (fragUv - origin)/size with the static rect → the SDF texel at screen-normalised fragUv. RevealedSdfBuilder maps the BUILD viewport bbox to the 256² texture (west→col 0, north→row 0).
  found: the shader assumes SDF-build-viewport ≡ current camera viewport on EVERY paint. Any staleness of the SDF = the reveal is pinned to the screen, not to the map.
  implication: the SDF must be rebuilt whenever the viewport moves more than the cache quantisation, on every paint, or the rect must compensate.

- timestamp: 2026-09-11 step 3
  checked: AtmosphericMirkRenderer._refreshSdfIfNeeded (HEAD) vs POC FogLayer.build (@90c9321 line 319-320) vs pre-09.1 renderer (d2c4ac1)
  found: HEAD: viewport-only change → cancel + re-arm a 200 ms Timer (kMirkFogSdfViewportDebounceMs), NO rebuild while the timer keeps being re-armed. POC: `_pendingSdfBuild ??= sdfCache.getOrBuild(discs, viewport)` on every build (no debounce; quantised key 1e-4°). Pre-09.1 (d2c4ac1 lines 145-149, 584-609): same 200 ms debounce BUT `_computeSdfRect(currentViewport)` remapped the stale SDF's build viewport onto the current viewport every paint, so staleness was harmless.
  implication: Phase 09.1 removed the dynamic rect (POC invariant 9) but kept the debounce (SdfCache docstring: 'renderer keeps its 200 ms viewport-only debounce IN FRONT of getOrBuild'). The two are incompatible: static rect requires a fresh SDF per paint. ROOT-CAUSE CANDIDATE.

- timestamp: 2026-09-11 step 5
  checked: docs/phase09-bug-tracking/BUG-012-sdf-strobe-on-pan.md
  found: Iteration 1 (8486d3e) added the 200 ms viewport-only debounce; Iteration 2 (c0c14a6) then had to fix the EXACT symptom now reported — "during a pan the revealed area visibly slid with the viewport (the SDF was painted at fixed pixel coordinates, not at fixed geo coordinates)" — with the dynamic sdfRect. Phase 09.1 removed the dynamic sdfRect (invariant 9, POC) and kept the debounce.
  implication: the UAT symptom is the documented BUG-012 iteration-2 regression, re-opened by keeping iteration 1 without iteration 2. Platform-independent: the iPhone will show it too.

- timestamp: 2026-09-11 step 6
  checked: device INFO log 20260911_1621.08 (52 atmospheric lines) and adb
  found: shader path active and stable (path=shader, sdf=true, 2-3 discs, canvas 411.4x867.4 logical = Pixel 6 Pro at DPR 3.5); no SEVERE, no fallback flapping. Session at lat 48.528644 lon 2.655185 (Melun). Side observation: activeMirkRendererProvider rebuilt the renderer after the 16:21:33 disc flush (renderer ready→loading→ready, new first-invocation) and the shader was re-loaded again at 16:22:37 and 16:22:45 after each flush — renderer churn on disc flush, not related to the drift but worth a look (wisp warm-up / SDF cache reset on every flush). adb: device not found at investigation time → Impeller backend line not captured.
  implication: nothing in the log contradicts H4'; the log cannot discriminate (verbose rollups off).

## Resolution

root_cause: The shader samples the SDF through the platform-static sdfRect (Phase 09.1 invariant 9), which assumes the SDF texture was built for the viewport being painted. AtmosphericMirkRenderer/HeavenlyCloudsMirkRenderer._refreshSdfIfNeeded still applies the overlay-era 200 ms viewport-only debounce (BUG-012 it.1) that is re-armed on every camera change, so during a continuous pan the SDF is never rebuilt and its reveal (alpha≈0 inside sdf<0 + halo) stays pinned to the SCREEN while the clip hole and the CircleLayer puck move with the map. Iteration 2 of BUG-012 (dynamic sdfRect) that made the debounce harmless was removed by the port-back; the POC never had the debounce (getOrBuild on every build, quantised key).
fix: Dropped the 200 ms viewport-only debounce in AtmosphericMirkRenderer and HeavenlyCloudsMirkRenderer (`_refreshSdfIfNeeded`): a viewport change now schedules the SDF build immediately through the existing single-in-flight + coalescing path, exactly like a disc change (POC policy, FogLayer.build @ 90c9321). `kMirkFogSdfViewportDebounceMs` and the `Timer` fields are removed; the SdfCache quantised key (1e-4°) remains the only rate limiter. No change to the shader, the sdfRect (still platform-static, invariant 9), the MirkRenderer seam or the FogLayer.
verification: (self) new widget regression test `fog_sdf_follows_pan_test` — RED at HEAD (SDF lag 12.6 → 300.6 px over a 300 px continuous pan, +12 px per frame, control clip-hole-on-puck green) → GREEN after the fix (lag < 36 px on every frame). `sdf_refresh_policy_test` (18 scenarios × 2 renderers) replaces `sdf_debounce_test`. flutter analyze --fatal-infos --fatal-warnings clean, dart format 160 clean, flutter test 1264 passed, 9 tool/check_* gates OK, dart test tool/test 96 passed. (human) pending — device UAT.
files_changed:
  - lib/infrastructure/mirk/atmospheric_mirk_renderer.dart
  - lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart
  - lib/infrastructure/mirk/sdf/sdf_cache.dart (docstring)
  - lib/config/constants.dart (kMirkFogSdfViewportDebounceMs removed)
  - test/constants_test.dart
  - test/_helpers/fog_layer_test_harness.dart (devicePixelRatio / isAndroid params)
  - test/_helpers/atmospheric_fog_layer_harness.dart (comment)
  - test/presentation/widgets/fog_sdf_follows_pan_test.dart (NEW regression)
  - test/infrastructure/mirk/sdf_refresh_policy_test.dart (NEW, replaces sdf_debounce_test.dart — deleted)
  - test/presentation/widgets/fog_layer_single_camera_snapshot_test.dart, test/performance/disc_sdf_build_perf_test.dart, test/infrastructure/mirk/wisp/wisp_sdf_firewall_test.dart (comments)
