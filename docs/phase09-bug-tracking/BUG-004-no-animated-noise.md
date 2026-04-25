# BUG-004 — Pas d'effet "moving noise" visible sur atmospheric / heavenly_clouds

**Status:** fixed (2026-04-25)
**Reported:** 2026-04-25 (iOS UAT walk après build `0b96197`)
**Platform:** iOS sideloaded
**Phase context:** Régression introduite par le fix BUG-003 issue A (commit `2811900` — viewport-level fog).

## Comportement attendu

`AtmosphericMirkRenderer` et `HeavenlyCloudsMirkRenderer` doivent afficher un brouillard avec un pattern de bruit animé (le fog "respire" / dérive). Le Ticker d'animation existe déjà dans `MirkOverlay`, et `tickerElapsed` est passé dans `MirkPaintContext`.

## Comportement observé

Le fog est uniforme (un seul ton de noir/gris légèrement pulsant). Aucun pattern visible. Pas de mouvement texturé.

## Hypothèse forte

Le commit `2811900` du sous-agent fix-A a remplacé la modulation per-tile/per-cell par "one time-evolving sample per frame (uniform fog density evolving over time)" pour adapter le rendering au nouveau path full-viewport. Conséquence : la noise atmospheric n'est plus DESSINÉE comme texture, juste utilisée pour moduler une alpha globale.

Le fix BUG-003 a corrigé le damier mais a tué la texture animée. Il faut **ré-ajouter la peinture du noise pattern** À L'INTÉRIEUR du fog clip path (typiquement via `canvas.clipPath(fogPath)` puis `canvas.drawPaint(noiseShader)` ou équivalent, animé par `tickerElapsed`).

## Diagnostic à confirmer

- Lire `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` (post-fix) — comment le `Paint` est-il configuré ? `Paint..color` uniforme ou `Paint..shader` animé ?
- Lire `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` (post-fix) — même question.
- Lire `lib/infrastructure/mirk/noise/simplex_noise_2d.dart` — comment le SimplexNoise2D est-il consommé maintenant ? Une seule sample(time) ou un sampling 2D animé ?
- Le `tickerElapsed` dans le `MirkPaintContext` est-il toujours câblé / consommé ?

## Solutions possibles

1. **Shader-based noise** (préféré côté GPU) — `Paint..shader = ImageShader(noiseTexture, repeat, repeat, matrix)` avec une matrice ou une texture qui évolue avec `tickerElapsed`.
2. **CPU-rasterised noise** — pré-générer une `ui.Image` de noise (256×256, repeat) une fois, dessinée via `canvas.drawImageRect` à travers le clip path, avec un offset qui évolue dans le temps (drift).
3. **FragmentShader (`ui.FragmentShader`)** — shader procédural qui prend `time` en uniforme. Plus propre mais nécessite un asset shader compilé. Probablement overkill.
4. **Path subdivision avec couleurs modulées** — revenir à une version per-tile MAIS sans MaskFilter à BlurStyle.inner. Compromis : moins performant que viewport-level mais conserve la modulation visible per-cell.

Le plus simple et le moins invasif est probablement (2) — pré-rasteriser un noise tile (256×256) une fois, le dessiner en mode tiled repeat avec un offset animé.

## Resolution

**Resolved:** 2026-04-25

### Findings on the diagnostic hypothesis

The bug-doc hypothesis was correct: the BUG-003 fix collapsed all spatial noise modulation into a single `noiseSample` per frame (modulating only the global alpha). The viewport-level path was painted with one uniform fog colour; the user saw "uniform fog with subtle pulse" instead of texture.

`tickerElapsed` was still wired through `MirkPaintContext.sessionElapsed` and reaching the renderers — the noise sampler was being called every frame with a time-evolving input — but the result was a single number (alpha modulation) rather than a per-pixel pattern.

### Fix — pre-rasterised tileable noise texture + ImageShader (option 2 from the bug doc)

**New file `lib/infrastructure/mirk/noise/noise_texture.dart`** — a `NoiseTexture.build(...)` static that asynchronously builds a 256×256 grayscale `ui.Image` containing tileable simplex noise. Tileability is achieved via the standard "Perlin torus blend" trick — each pixel is the bilinear blend of four simplex samples taken at the cell's wrap-corners, weighted by `(1-u, 1-v)` etc. The image is built ONCE per renderer (~5-15 ms one-time cost on construction) and reused across all subsequent frames.

**Atmospheric + heavenly_clouds renderers** now paint TWO passes per frame:

1. **Solid coloured fog** — the existing post-BUG-003 path. `MaskFilter.blur(BlurStyle.normal, sigma)` over `buildViewportFogClipPath(...)`. This pass owns BUG-006's rounded reveals and BUG-003's seam-free fog density. `noiseSample` still modulates the global alpha for slow density "breathing".
2. **Animated noise overlay** — `canvas.saveLayer(bounds, paint with reduced alpha)` then `drawPath(fogPath, paintWithImageShader)`. The shader's transform matrix translates the sample point by `(tSec × pxPerSec × driftX, tSec × pxPerSec × driftY)`, so the noise pattern visibly drifts in the configured direction at ~30 px/s (atmospheric) or ~50 px/s (heavenly_clouds). The saveLayer's reduced alpha (80 atmospheric, 140 heavenly) dims the noise pass — the fog stays visibly dark on atmospheric while showing bright noise peaks at ~25% strength.

The 2-pass cost is one extra `drawPath` per frame; the noise image is GPU-resident after the first paint so the per-frame cost is just a shader sample. No per-cell loop, no return to the BUG-003 damier.

### Why saveLayer instead of softLight / overlay blend modes

Tried `BlendMode.softLight` first — it crushes against pure-black destinations because the blend formula goes `2*src*dst` for dst <= 0.5, and `dst=0` always yields `0`. The atmospheric fog (RGB=0,0,0) erased the noise overlay completely. Tried alpha-modulated white texture (RGB white, alpha = noise byte) with default srcOver — but the simplex envelope rarely drops near zero, so every pixel painted as near-opaque white, bleaching the fog. The grayscale-RGB-with-saveLayer approach reads correctly across both atmospheric (dark) and heavenly_clouds (light) fogs without per-variant blend tuning.

### Test coverage

`test/infrastructure/mirk/noise_overlay_test.dart` (NEW) — 6 tests:

- **atmospheric: visible spatial RGB variance** — renders a fully-fogged tile, awaits the noise texture's async build via the new `noiseReady` getter, samples a 192-px-wide horizontal strip in the canvas interior, and asserts per-channel variance > 10. Pre-fix: variance ≈ 0 (uniform RGB). Post-fix: variance ~30-100 (visible texture).
- **atmospheric: noise pattern moves between frames** — renders at t=0 and t=5s, samples 16 evenly-spaced pixels along the strip, counts those whose R-byte changed by >= 5. Asserts >= 4 of 16 moved. Pre-fix: 0 moved (only the global alpha pulse changes, RGB stays constant). Post-fix: ~16 moved (the entire pattern drifts ~150 px in 5s at 30 px/s).
- **heavenly_clouds: visible spatial RGB variance** — same shape as atmospheric.
- **heavenly_clouds: noise pattern moves between frames** — same shape as atmospheric.
- **atmospheric: pre-noise-ready paint is a no-op overlay** — renders BEFORE awaiting `noiseReady`. The renderer falls back to solid coloured fog only and does not crash. Guards the production "first frame before texture loaded" path.
- **candlelight is intentionally NOT in this cohort** — documentation test recording the scope boundary (candlelight uses radial gradient + flicker, not moving noise).

The existing animation-proof tests (atmospheric_mirk_renderer_test.dart, heavenly_clouds_mirk_renderer_test.dart) continue to pass — the alpha-pulse animation path is unchanged.

### Files changed

- `lib/infrastructure/mirk/noise/noise_texture.dart` (NEW, 95 lines) — tileable noise texture builder
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — added noise pass + `noiseReady` test seam + dispose hygiene
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — same shape, brighter overlay alpha
- `test/infrastructure/mirk/noise_overlay_test.dart` (NEW, 6 tests)

Candlelight + solid renderers UNCHANGED. Candlelight's radial-flicker visual is a different idiom (per the bug doc, scope is atmospheric + heavenly_clouds); solid is the minimalist proof-of-seam variant.

### Verification

- `flutter analyze --fatal-warnings --fatal-infos lib/ test/` — clean.
- `dart format --line-length 160 --set-exit-if-changed lib/ test/` — clean.
- `flutter test --exclude-tags mirk-perf` — 949 / 949 tests pass.
- The 50k-tile perf test (`fog_50k_tiles_perf_test.dart`) is excluded by tag from the default suite (per its docstring) and was not exercised in this cycle. The added per-frame cost is one extra `drawPath` on the same path geometry — no algorithmic change. Phase 10's device probe will validate the 16 ms target on real hardware.

### Concerns for the user

- **Sigma + alpha values are heuristic.** The atmospheric overlay alpha (80/255 ≈ 31%) and heavenly_clouds (140/255 ≈ 55%) were tuned against the test pixel-variance threshold, NOT against a human eye on a real iOS device. Expect a tuning iteration after the next UAT walk: if atmospheric noise is too subtle, bump to 100-120; if too prominent, drop to 60.
- **`saveLayer` is moderately expensive on Android.** Skia must allocate an offscreen buffer the size of the path bounds. At a 1080×1920 viewport this is ~8 MB per frame. Should be fine for the GPU on modern devices but Phase 10's device probe should watch for jank on low-end hardware.
- **Candlelight does not yet have a noise overlay.** If the user wants drifting texture inside the candlelight glow's halo, that's a follow-up — not a regression of BUG-004.
