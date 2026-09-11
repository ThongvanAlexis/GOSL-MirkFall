---
status: awaiting_human_verify
trigger: "la zone découverte se décale du point bleu quand je pan sur android (UAT Phase 09.1 same-canvas fog port-back, Pixel 6 Pro, build f347eeb)"
created: 2026-09-11T00:00:00Z
updated: 2026-09-11T21:00:00Z
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

## Fix 2 (working tree, uncommitted) — renderer re-created on every GPS fix

root_cause_2: `activeMirkRendererProvider` watched the whole `activeSessionControllerProvider`; the controller publishes `state = AsyncData(current.copyWith(fixCount: +1, lastFix: fix))` on EVERY accepted fix (active_session_controller.dart:363), so every flush rebuilt the provider → `factory.create` + `dispose()` of the live renderer → new SdfCache (fallback fog for 1-2 frames), shader reloaded, wisp warm-up reset, and one frame with NO fog (disposed renderer early-returns). This is the "three `FragmentProgram.fromAsset` loads in 80 s, one per flush" of the UAT log. The POC keeps one shader + one SdfCache per screen (map_screen.dart:148, :337).
fix_2: new narrow `activeSessionIdProvider` (`SessionId?`; a functional provider notifies dependents only when `previous != next`, riverpod provider.dart:349, and `SessionId` is a value type) watched by `activeMirkRenderer` instead of the controller (active_mirk_renderer_provider.dart:59). `select` is not usable there: `riverpod_annotation` re-exports riverpod through a `show` list without `ProviderListenableSelect`, and the application layer stays free of `flutter_riverpod`.
verification_2: active_mirk_renderer_provider_test 'a new fix on the SAME session (Tracking.copyWith) keeps the SAME renderer — nothing re-created, nothing disposed' — RED against the HEAD provider (verified by swapping the file back), GREEN with the fix. Codegen regenerated (`dart run build_runner build`) then `dart format --line-length 160` (the committed .g.dart files are 160-col formatted); only `active_mirk_renderer_provider.g.dart` + the new `active_session_id_provider.g.dart` differ. `active_session_controller.g.dart` had a stale debug source hash before this work — restored, not part of the fix.
files_changed_2:
  - lib/application/providers/active_session_id_provider.dart (+ .g.dart) — NEW
  - lib/application/providers/active_mirk_renderer_provider.dart (+ .g.dart regenerated)
  - test/application/providers/active_mirk_renderer_provider_test.dart (+1 scenario; fake controller gains `emit`)
  - test/presentation/widgets/fog_puck_alignment_test.dart — NEW (projection identity + pixel-level raster proof)

## Exhaustive diff — POC `mirk-poc-debug` @ 90c9321 vs MirkFall @ 017b0ea (+ working tree)

Legend — **IDENTICAL**: same code / same values. **EQUIVALENT**: different code, same effect, named test proves it. **RELEVANT → FIXED**: user-visible divergence, fixed in this session. Line numbers: POC = `git show 90c9321:<file>`; MirkFall = HEAD 017b0ea unless marked (tree).

Engine baseline (both): Flutter 3.41.7 stable (POC ci.yml:23 / MirkFall workflows :38,:241,:337 / local), flutter_map 7.0.2, latlong2 0.9.1, vector_map_tiles 8.0.0, vector_map_tiles_pmtiles 1.5.0, vector_tile_renderer 5.2.0 (both pubspec.lock). No Impeller override in either AndroidManifest (POC :21-34, MirkFall :82,:112 — only NormalTheme / flutterEmbedding) nor Info.plist → identical default backend (Impeller; Vulkan on Adreno 618 and Mali-G78).

### Stage 1 — FlutterMap composition
| Row | POC | MirkFall | Verdict | Evidence |
|---|---|---|---|---|
| MapOptions.crs | default Epsg3857 | default Epsg3857 | IDENTICAL | POC map_screen.dart:408; flutter_map_map_view.dart:255 |
| interactionOptions | `InteractiveFlag.all & ~rotate` | same | IDENTICAL | POC :442 / MirkFall :265 |
| min / max zoom | 10 / 20 (constants:198,:204) | 2 / 20 (constants:853,:857) | different, not positional (zoom range only) | — |
| initial camera | Melun const, z19 (constants:194); one-shot auto-recenter `move(fix, 19)` (map_screen:257) | session fix, z15 (map_screen.dart:239, constants:238) | different, not positional | — |
| cameraConstraint / backgroundColor | none / default grey | none / kMapBackgroundColorArgb | cosmetic | :260 |
| child order | [VectorTileLayer, FogLayer, CircleLayer] (:445,:472,:486) | [VectorTileLayer, fogLayers, CircleLayer] (:269,:277,:278) | IDENTICAL | map_screen_fog_composition_test 'mounts fogLayers between VectorTileLayer and the puck CircleLayer' |
| VectorTileLayer | tileProviders + theme, default raster mode | + `key` (archive/theme) + `cacheFolder`, default raster mode | EQUIVALENT (cache config only; reads the same MapCamera.of) | :269-276 |
| puck | flutter_map `CircleLayer` + `CircleMarker(radius 7, useRadiusInMeter false, fill 0xFF2B7CD6, stroke 2 white)` (blue_dot_marker.dart, constants:290-296) | same `CircleLayer` / `CircleMarker` values (constants:884-894, `_buildUserPuck` :285-291) | IDENTICAL | — |
| puck projection vs hole projection | CirclePainter `camera.getOffsetFromOrigin` (painter.dart:53) vs clip `latLngToScreenPoint` (fog_clip_path) | same pair (fog_clip_path.dart:27) | IDENTICAL math: `project(p)−pixelOrigin` == `project(p)−(project(center)−nonRotatedSize/2)` at rotation 0 (camera.dart:77 vs :263). **Now asserted**: fog_puck_alignment_test 'CirclePainter projection == fog clip projection at fractional zoom, off-centre' (1e-9 px) + raster rows | — |
| wrapper around the fog | none | `MirkInitialRevealFade` → `FadeTransition` (map_screen.dart:247, mirk_initial_reveal_fade.dart:88). `RenderAnimatedOpacityMixin` is a **repaint boundary whenever alpha > 0** (proxy_box.dart:985, :1058) — i.e. permanently once faded in | EQUIVALENT — an OpacityLayer is composited in the same frame (no retained frame); inside it `getTransform()` carries no offset and the puck's canvas has none either (map-local origin 0) → FOG-13 compensation is a no-op on both. **Proven**: fog_puck_alignment_test raster at fade 1.0 and 0.6, DPR 3.5, z16.37, puck centred and panned (95,−60): hole edges symmetric ±2 physical px, radius == metric | Note: the map_screen.dart:241-246 / fog_layer.dart docstring claim "a repaint boundary would put the fog one frame behind" is not how Flutter's pipeline works; comment-only, harmless |
| RepaintBoundary in the map subtree | flutter_map's own (widget.dart:90) | same + the FadeTransition above | see row above | map_screen_fog_composition_test 'no RepaintBoundary / IgnorePointer around it' |
| pointer / hit testing | CustomPaint without hitTest override; `applyPointerTranslucencyToLayers` default | same | IDENTICAL | map_screen_fog_composition_test 'a drag on the map pans the camera — the fog child does not capture pointers' |

### Stage 2 — FogLayer widget
| Row | POC | MirkFall | Verdict | Evidence |
|---|---|---|---|---|
| camera read | `MapCamera.of(context)` once per build (fog_layer.dart:311) → `InheritedModel.inheritFrom(aspect: camera)` (inherited_model.dart:33-38) | same (fog_layer.dart:136) | IDENTICAL | fog_layer_camera_snapshot_test, fog_layer_single_camera_snapshot_test |
| rebuild during a gesture | `MapInteractiveViewer.onMapStateChange => setState` (map_interactive_viewer.dart:140) on every controller change → `MapInheritedModel` rebuilt → dependents rebuilt the same frame | same package, same path | IDENTICAL | fog_pan_translation_test ('a new camera snapshot → a new painter') |
| transformer | `MobileLayerTransformer` (OverflowBox camera.size + Transform.rotate 0) (:322) | same (:139) | IDENTICAL | fog_layer_test 'wrapped by MobileLayerTransformer' |
| repaint policy | Ticker → `_repaint.notifyListeners()` per frame (:260); `shouldRepaint`: identical(camera/discs/sdfImage) (:899) | Ticker → `_repaint.tick()` (:122); `shouldRepaint`: camera != / discs identity / renderer / currentFix / pixelRatio / isAndroid (:272) | EQUIVALENT (superset; the Ticker repaints every frame anyway) | fog_layer_test |
| widget inputs | `discRepository.snapshot()` (all in-memory discs) in build (:309); shader + SdfCache owned by MapScreen state | discs / currentFix / renderer injected by `FogLayerConnector` (fog_layer_connector.dart:90-93, :113-114) | EQUIVALENT — see B | fog_layer_connector_test |
| platform predicate | `Platform.isAndroid` evaluated in paint (:595, :693) | `Platform.isAndroid` evaluated once in initState (:121), forwarded | EQUIVALENT (process constant) | fog_platform_corrections_test |
| lifecycle | StatefulWidget + SingleTickerProvider; two Stopwatches (fog + wisp) | StatefulWidget + SingleTickerProvider; one Stopwatch (wisps use `sessionElapsed`) | EQUIVALENT | fog_layer_wisp_render_test, wisp_particle_system_test |

### Stage 3 — Painter
| Row | POC (fog_layer.dart) | MirkFall (fog_layer.dart) | Verdict | Evidence |
|---|---|---|---|---|
| early return | `if (sdfImage == null) return;` (:437) — no fog until the first SDF | none; renderer paints the CPU fallback until SDF / shader ready (atmospheric :236, :415) | different, not positional (startup / renderer swap only; after fix 2 only at session start, under the fade-in) | fog_edge_feather_test |
| getTransform ×1 | :480 | :205 | IDENTICAL | fog_rect_viewport_coverage_test 'paint call order' |
| save → translate(−offset) → clipPath | :483, :489, :498 | :208, :215, :219 | IDENTICAL order | fog_canvas_frame_alignment_test |
| clip path | `computeFogClipPath(camera, discs)`: rect(camera.size) − ovals at `latLngToScreenPoint`, radius = m × px/m probed (lat,0)→(lat+1/111320,0) | split into `cameraScreenProjector` / `cameraMetersToPixels` (fog_clip_path.dart:27-41) + pure `buildFogClipPath` (fog_clip_geometry.dart:38-49) — same formulas | IDENTICAL math | fog_clip_path_test (hole at latLngToScreenPoint, metric radius, ×4 z13→z15), fog_clip_geometry_test |
| feathering on the shader path | none | none (feather only on the CPU fallback, fog_edge_feather.dart:60 saveLayer in the same identity frame) | IDENTICAL on the shader path | fog_edge_feather_test |
| draw + wisps + restore | drawRect(shader) :707 → `_renderWisps` :718 → restore :720 | `renderer.paint` (:264 → shader rect fog_shader_renderer.dart:152 → wisps atmospheric :293) → restore :265 | IDENTICAL order | fog_layer_wisp_render_test 'wisp circles are drawn AFTER the shader rect and BEFORE restore' |
| hit testing | none | none | IDENTICAL | map_screen_fog_composition_test |

### Stage 4 — Camera-derived quantities (exact formulas)
| Quantity | POC | MirkFall | Verdict | Evidence |
|---|---|---|---|---|
| pixelOrigin | `camera.pixelOrigin` (:566) → `boundedX = trunc(x)+frac(x)` (identity, :567-573) → Android `(x, −y)`, iOS `(x, y)` (:595) | `camera.pixelOrigin` raw → `applyPlatformShaderCorrections`: Android `(x, −y)`, iOS `(x, y)` (fog_platform_corrections.dart:57-62; fog_layer:223) | IDENTICAL values | fog_pixel_origin_decomposition_test (NUMERICAL identity at 4.26 M / 17 M), fog_platform_corrections_test 'Android: pixelOrigin.y sign-flipped' |
| zoomScale | `pow(2, zoom − kPocFogReferenceZoom=13)` (:605, constants:469) | `pow(2, zoom − kMirkFogReferenceZoom=13)` (:231, constants:901) | IDENTICAL | fog_zoom_invariant_basis_test |
| sdfRect | Android `(0,1,1,−1)`, iOS `(0,0,1,1)` (:693-695) | `kFogSdfRectAndroidVFlip` / `kFogSdfRectIdentity` (fog_platform_corrections.dart:12-16) | IDENTICAL | fog_platform_corrections_test 'Android: … sdfRect V-flip (0, 1, 1, -1)' |
| uResolution | painter `size` = camera.size (CustomPaint Size.infinite under the OverflowBox) | same | IDENTICAL | fog_layer_test |
| DPR | not used in geometry | not used in geometry (context.pixelRatio → fallback feather sigma only, atmospheric :425) | IDENTICAL; DPR 3.5 exercised by fog_sdf_follows_pan_test + fog_puck_alignment_test | — |
| uTime | mount Stopwatch by reference (:439) | mount Stopwatch by reference (:241) | IDENTICAL | fog_layer_test 'live uTime' |
| SDF viewport | `camera.visibleBounds` (:361) | `camera.visibleBounds` (`_viewportFromCamera`) | IDENTICAL | — |

### Stage 5 — SDF
| Row | POC | MirkFall | Verdict | Evidence |
|---|---|---|---|---|
| builder | visibleBounds, no padding, north → row 0, west → col 0 (revealed_sdf_builder.dart) | verbatim (`diff -w --strip-trailing-cr` empty) | IDENTICAL | disc_sdf_build_perf_test, sdf_cache_test |
| cache key | discs 1e-6° / 1 mm ⊕ bbox 1e-4° (sdf_cache.dart) | same constants; + generation guard on dispose | IDENTICAL key | sdf_cache_test |
| when getOrBuild is called | in `build()` on every camera / disc change, `_pendingSdfBuild ??=` chain (:320; reset on disc change :265-269) | **was**: viewport-only change → 200 ms debounce re-armed per frame (never fires during a gesture) | **RELEVANT → FIXED (351c4c1)**: now in `paint()` on every viewport / disc change, one in flight + coalescing (atmospheric :462-489, heavenly same) | fog_sdf_follows_pan_test (RED at f347eeb: lag +12 px per frame → 300 px; GREEN: < 36 px), sdf_refresh_policy_test (18) |
| while a build is in flight | painter keeps the previous `sdfImage` | renderer keeps `_currentSdfImage` | IDENTICAL behaviour | sdf_refresh_policy_test 'stale, never absent' |
| image publication | `setState` on resolve (:345-353) → rebuild → new painter | field swap, picked up by the next Ticker paint | EQUIVALENT | sdf_refresh_policy_test 'the new image is picked up once resolved' |
| decode latency | `decodeImageFromPixels` (one event-loop turn) | same | IDENTICAL | — |
| eviction | single entry, previous disposed on miss | same (+ dispose generation) | IDENTICAL | sdf_cache_test |
| SdfCache lifetime | one per MapScreen (map_screen:148) | one per renderer — **was** one per GPS fix (renderer re-created) | **RELEVANT → FIXED (tree)**: one per session via `activeSessionIdProvider` | active_mirk_renderer_provider_test 'a new fix on the SAME session … keeps the SAME renderer' (RED at HEAD) |

### Stage 6 — Shader
| Row | POC | MirkFall | Verdict | Evidence |
|---|---|---|---|---|
| `.frag` | atmospheric_fog.frag | `diff -w --strip-trailing-cr`: only comment lines 134, 294-300, 303-305 differ | IDENTICAL code | fog_shader_uniforms_test source-reflection tests |
| uniform slots | 42 floats + sampler 0 (fog_shader_uniforms.dart) | same; `(double,double)` record → `({x,y})` record (:117) | IDENTICAL layout | fog_shader_uniforms_test 'setAll binds exactly the 42 slots' |
| y-conventions in the shader | `FlutterFragCoord()` (:262); `#ifdef IMPELLER_TARGET_OPENGLES fragUv.y = 1−fragUv.y` (:267-268); `sdfUv = (fragUv−origin)/size` clamped (:238-240) | identical text | IDENTICAL | fog_shader_uniforms_test 'keeps the OpenGLES fragUv flip' |
| sampler wrap / filter | `setImageSampler(0, sdf)` — engine default (clamp, linear) | same (:182) | IDENTICAL | — |
| FragmentShader creation | `program.fragmentShader()` once per MapScreen (map_screen:337) | `_shader ??= obtainShaderSync()` once per renderer (atmospheric :222, fog_shader_service.dart:140) — **was** once per fix | after fix 2: once per session | — |
| per-frame draw | `Paint()..shader` + `drawRect(Offset.zero & size)` (:707) | same (fog_shader_renderer.dart:152) | IDENTICAL | — |
| tunable values | `kMirkFog*` constants (constants:91-182) | `MirkRuntimeTunables` defaults = the same constants (constants:513-726, all 20 values equal) + curlScale triangle-wave animation (MirkFall-only) | different (curl animation, baseAlpha 1.0 vs 0.99) — appearance only, not the reveal position | — |

### Stage 7 — Wisps and edge feather
| Row | POC | MirkFall | Verdict | Evidence |
|---|---|---|---|---|
| projection | `camera.latLngToScreenPoint(wisp.position)` (:825) | `context.projectToScreen` = `cameraScreenProjector(camera)` (atmospheric :293) | IDENTICAL | fog_layer_wisp_render_test 'one per active wisp at its projected position', wisp_pan_invariance_test |
| transform / saveLayer | none (same clipped identity frame) | none | IDENTICAL | — |
| blend / radius / alpha | plus; 6 → 22 px; (1−age²)×0.35×tintA | same (constants:760-770) | IDENTICAL (tint colour C8DCFF vs E0E6F0 — cosmetic) | — |
| edge feather | none | CPU fallback only: `saveLayer(viewport)` + dstOut blurred stroke along the same hole outline (fog_edge_feather.dart:55-62) | different, fallback-only, same frame → no displacement | fog_edge_feather_test |

### A — Platform-specific behaviour (exhaustive grep on both trees: Platform.is*, defaultTargetPlatform, TargetPlatform, flipY, mirror, invert, uFlip, "1.0 -", "-1", Impeller, Skia, Vulkan, GLES)
| Site | POC iOS | POC Android | MirkFall iOS | MirkFall Android | Verdict |
|---|---|---|---|---|---|
| FOG-23 uPixelOrigin.y | `+y` (fog_layer:595) | `−y` | `+y` | `−y` (fog_platform_corrections.dart:61) | IDENTICAL; predicate `dart:io Platform.isAndroid` on both (POC per paint; MirkFall once at mount, fog_layer:121) |
| FOG-21 uSdfRect | `(0,0,1,1)` (:695) | `(0,1,1,−1)` (:694) | `kFogSdfRectIdentity` | `kFogSdfRectAndroidVFlip` (:12-16) | IDENTICAL |
| shader GLES guard | `#ifdef IMPELLER_TARGET_OPENGLES fragUv.y = 1−fragUv.y` | same | same | same | IDENTICAL (compile-time, engine-defined) |
| SDF texture row order at build | north → row 0 (`cy = (north−lat)/dLat·n`) | same | same | same | IDENTICAL, no platform branch |
| canvasOffset / clip path / wisp positions / noise UV beyond pixelOrigin.y | no platform branch | no platform branch | no platform branch | no platform branch | IDENTICAL |
| CPU renderers (candlelight / solid) | n/a (POC had none) | n/a | `rawPixelOriginOf` un-flips for CPU noise (fog_platform_corrections.dart:75-79) | same | MirkFall-only, not the active atmospheric path; fog_platform_corrections_test 'round trip' |
| other Platform / TargetPlatform uses | shader_sanity_screen.dart:348 (debug screen, not ported) | — | GPS settings, iOS backup / watchdog, OEM detector, first-launch bootstrap — outside the fog path | — | not in the rendering path |
| engine flags | none in AndroidManifest / Info.plist | — | none | — | IDENTICAL defaults (Impeller Vulkan on both test phones) |

### B — MirkFall does, POC does not (whole fog lifecycle)
| Item | MirkFall | Verdict |
|---|---|---|
| startup fallback fog (solid + feather) before shader / SDF ready | atmospheric :236, :415-445 | different, not positional; after fix 2 only at session start under the 500 ms fade |
| initial reveal fade (`FadeTransition`, repaint boundary while alpha > 0) | mirk_initial_reveal_fade.dart:88 | EQUIVALENT — fog_puck_alignment_test (fade 0.6 and 1.0) |
| style swap mid-session | `ref.invalidate(activeMirkRendererProvider)` → new renderer | intended; map_screen_fog_composition_test 'invalidating activeMirkRendererProvider mid-session swaps the FogLayer renderer' |
| **renderer re-creation on every GPS fix** | `activeMirkRenderer` watched the whole controller; controller `state = copyWith(fixCount+1, lastFix)` per fix (active_session_controller.dart:363) → factory.create + dispose per fix (UAT log: 3 shader loads / 80 s) | **RELEVANT → FIXED (tree)**: `activeSessionIdProvider` (new) watched instead (active_mirk_renderer_provider.dart:59); regression test RED at HEAD / GREEN |
| throttled viewport provider (50 ms) → padded disc re-query (½ viewport) → fresh List per query | map_viewport_provider.dart:26; fog_layer_connector.dart:113-114 | EQUIVALENT: renderer compares disc CONTENT (`_discListSignature`), the SDF builder only uses viewport-intersecting discs on both sides; fog_layer_connector_test 'queries … PADDED bbox', 'keeps the last known discs'; sdf_refresh_policy_test 'a fresh List … is NOT a disc change' |
| Riverpod rebuilds of `FogLayerConnector` per fix / viewport tick | rebuild → new `FogLayer` widget, same State (Ticker, Stopwatch kept) | EQUIVALENT — POC did `setState(() => _lastFix = fix)` per fix (map_screen:283); map_screen_fog_composition_test 'Ticker frames do NOT rebuild sibling widgets' |
| saveLayer edge feather | fallback path only | see Stage 7 |
| `Isolate.run` noise texture | heavenly renderer only (noise_texture.dart:95) | not in the atmospheric path |
| diagnostics (FrameDeltaProbe, FogTransformLogger, SdfRebuildLogger, WispTransformLogger) | verbose-only no-ops (the INFO log shows none) | same loggers existed in the POC; no-ops |
| RepaintBoundary in the map subtree | none added (the FadeTransition acts as one) | see Stage 1 |
| tile-cancellation guard / `_ArchiveTileProvider` refcount | flutter_map_map_view.dart:305-345 | tile fetch path only; no transform; VectorTileLayer reads the same MapCamera.of |
| follow-me camera controller | programmatic `move` on fixes while following; a user gesture switches to FreePan (map_camera_controller.dart:337-372, 1 s echo window) | not positional (fog and puck both follow the camera); POC had a one-shot auto-recenter (map_screen:257) |
| `setUserFix` → host setState per fix | flutter_map_map_view.dart:222 | EQUIVALENT to POC :283 |
| runtime tunables + curl animation + fog opacity preference | atmospheric :356-411 | appearance only |

### C — POC does, MirkFall does not
| Item | POC | MirkFall | Verdict |
|---|---|---|---|
| no paint before the first SDF | fog_layer:437 | fallback fog | different, not positional |
| `setState` on SDF resolve | :345-353 | field swap + Ticker | EQUIVALENT (sdf_refresh_policy_test) |
| `_onDiscsChanged` → reset chain + setState | :265-269 | disc signature → immediate build | EQUIVALENT (sdf_refresh_policy_test 'new disc triggers IMMEDIATE rebuild') |
| SDF build started from `build()` (every camera change) | :320 | started from `paint()` (every camera change since 351c4c1) | EQUIVALENT (fog_sdf_follows_pan_test) |
| shader / SdfCache created once per screen | map_screen:148, :337 | once per renderer = once per session (fix 2) | EQUIVALENT after fix 2 |
| trunc+frac "bounded" pixelOrigin (identity) | :567-573 | raw forward | IDENTICAL values (fog_pixel_origin_decomposition_test NUMERICAL) |
| `shouldRepaint` on sdfImage identity | :899 | n/a (renderer-owned) | EQUIVALENT (Ticker) |
| wisp radius basis switch (`screenPx` active) / `_derivePxPerMetre` | :855-885 | screen-px constants only | IDENTICAL active branch |
| wisp clock `advanceFromWallClock(stopwatch)` | :775 | `advanceFromElapsed(sessionElapsed)` | EQUIVALENT (wisp_particle_system_test) |
| debug spiral layer, shader sanity screen, FPS / frame-delta overlays, walk simulator, DevMarker | debug-only | not ported (CONTEXT: "ne pas porter") | not in the production path |
| recenter FAB + one-shot auto-recenter | map_screen:257 | follow-me controller | not positional |
| all discs in memory every build | :309 | padded DB subset | EQUIVALENT (see B) |
| `baseAlpha: 1.0`, constant curlScale 0.8, wisp tint C8DCFF, min zoom 10, initial zoom 19 | — | 0.99 / animated / E0E6F0 / 2 / 15 | appearance / range only |
| explicit camera listener / MapController usage per frame | none (only the one-shot move) | none | IDENTICAL |
| SDF padding / build-viewport enlargement / clamps | none (visibleBounds; builder clamps the signed distance to ±distMax) | none (verbatim builder) | IDENTICAL |

### Residual, not decidable from code
Everything in the pan-time path is now identical or proven equivalent, with two relevant divergences fixed (SDF debounce; renderer per fix). One item cannot be settled headless: whether Impeller-Vulkan on Mali-G78 (Pixel 6 Pro) applies the same texture-V-up sampling / uPixelOrigin.y codegen behaviour as on Adreno 618 (FOG-21 / FOG-23). Both apps share identical code and engine, so the POC APK (`C:\claude_checkouts\mirk-poc-debug\mirk-poc-debug-android-debug-apk-0cd9994`, built from 0cd9994 which carries the FOG-21/23 corrections) installed on the Pixel 6 Pro is the direct discriminator: correct there → the remaining behaviour was MirkFall's and is covered by the two fixes; a static vertical mirror of the halo there too → an engine / GPU-vendor difference that applies to both apps equally.
