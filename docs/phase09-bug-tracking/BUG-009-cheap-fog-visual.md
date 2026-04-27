# BUG-009 — Le rendu fog est "Temu / cheap", besoin d'un visuel premium

**Status:** ✅ closed — TIER 2 shader + BUG-010 Option B (disc-based SDF) shipped. Remaining boundary-stepping symptom structurally resolved by BUG-010 continuous geometry (`9bd0c93`…`f9b6f1a`). User UAT 2026-04-27 on `97d5978` confirmed volumetric fog visible and strobing solved (see BUG-012). No further iteration planned.
**Reported:** 2026-04-25 (iOS UAT walk après build `632a210`)
**Platform:** iOS sideloaded (mais le bug est cross-platform — c'est un défaut de design)
**Phase context:** L'effet livré par BUG-004 fix (commit `632a210`) consiste en : noise grayscale 256×256 pré-rasterisé tilé, qui drift à 30/50 px/s en ligne droite via translateMatrix, par-dessus un fog uni avec mask filter. Visuel inspecté par l'utilisateur : ressemble à "bruit qui slide vers la gauche", pas à du brouillard.

## Final state (2026-04-27, post-BUG-010 Option B)

**Visuel.** TIER 2 shader active with volumetric fog body (curl-scale triangle wave 0..4 over 60 s), watercolour boundary restored (`4736342`), opacity user-controllable (burger-menu slider, default 0.58, persisted). The boundary-stepping symptom that remained after `118b95a` was **structurally resolved** by the BUG-010 Option B disc-based SDF refactor (`9bd0c93`…`f9b6f1a`) — reveals are now analytic circles, not cell-grid rectangles.

**Pipeline-level.** Confirmed healthy — shader path active, ~96 fps, SDF rebuilds 1-9 ms from disc list. Logger functional (`RandomAccessFile.flushSync` in `16db03c`).

**Decision taken.** User chose Voie A (skip Option D, ship BUG-010 Option B directly). Option B shipped 2026-04-26. BUG-009's remaining boundary symptom resolved as a side-effect.

## Comportement attendu

L'utilisateur veut un effet "wow" — sensation de regarder **un monde embrumé volumétrique vu du dessus**. Trois propriétés clés :

1. **Volumétrique** — pas une texture plate qui drift. Profondeur visible, layers à différentes densités, structure 3D-ish même si techniquement 2D.
2. **Vu du dessus** — perspective top-down (on regarde une carte). Le fog doit ressembler à des **nuages denses ou une chape de brume vue d'avion / d'oiseau**, pas à une fumée latérale.
3. **Réactif aux frontières du reveal** — c'est la propriété la plus importante et la plus manquante actuellement. Le fog ne peut PAS juste glisser indifféremment au-dessus de tout. Aux frontières de la zone révélée, il doit :
   - Se condenser / s'accumuler / "buter" contre le bord
   - Ou s'effilocher / se dissiper / s'évaporer au contact
   - Ou tourbillonner / spiraler autour de l'edge
   - Ou avoir un "rim glow" / godrays partant du contour
   - Bref, un comportement qui rend visuellement crédible que la zone révélée a "chassé" le fog
   - Pas juste une texture qui passe au-dessus en faisant comme si la frontière n'existait pas

## Comportement observé (pourquoi c'est cheap)

- Translation linéaire constante (drift unidirectionnel) → le cerveau humain reconnaît immédiatement le pattern qui se répète
- Aucune interaction avec les frontières du reveal — le fog passe au travers comme s'il n'existait pas
- Pas de variation de densité spatiale → ressemble à un wallpaper animé
- Pas de profondeur (pas de parallaxe entre couches)
- Pas d'organique — la texture simplex est tileable mais le mouvement est purement géométrique

## Recherche en cours

4 researchers parallèles dans `.planning/research/bug-009-fog-visual/` :

1. `visual-references.md` — état de l'art visuel (jeux, apps cartos, weather)
2. `shader-techniques.md` — techniques GLSL pour fog volumétrique top-down
3. `boundary-reactive-fog.md` — algos qui font réagir le fog à un SDF / boundary
4. `flutter-shader-constraints.md` — capacités/limites de `ui.FragmentShader` sur iOS+Android

Synthèse à venir avec 2-3 propositions concrètes.

## Resolution

**Resolved:** 2026-04-25 (TIER 2 implementation — same day as report)

### Approach retained

After 4-researcher parallel investigation (visual references v1+v2,
shader techniques, boundary-reactive fog, Flutter shader constraints)
the user chose **TIER 2** — full volumetric-feeling shader replacing
the cheap noise-sliding ImageShader. Highlights:

- Recommended stack from `shader-techniques.md`: 3D-sliced FBM (T6) +
  curl-noise UV advection (T7-derived) + multi-octave parallax (T7)
  + faux directional shading (T6 IQ Clouds / Lague Coding Adventure)
  + sub-grey hue variation (Reference 5 NASA SVS) + two-stop
  watercolour boundary (Reference 11 Heaven's Vault) + curl-rotated
  edge field (boundary reactivity).
- Palette A (Northern atlas indigo) for atmospheric, palette B
  (Hebridean dawn) for heavenly clouds. Both work over light AND
  dark OSM tiles.
- CPU wisp particles spawned at newly-revealed cells (~200 cap,
  curl-noise advection on Dart side, additive blend).
- All 7 TIER 2 quality dimensions implemented inside ONE
  `assets/shaders/atmospheric_fog.frag` — atmospheric and heavenly
  share the asset and pass different uniforms.

### Commit sequence

| # | SHA | Description |
|---|-----|-------------|
| 1 | `671bd10` | Add TIER 2 fog visual tunables to constants — kMirkFogXxx prefix, 14 test cases, palette A+B + drift / scale / opacity / curl / faux light / hue / boundary / SDF / wisps. |
| 2 | `7e67517` | Scaffold FragmentShader pipeline with Paint fallback — `assets/shaders/atmospheric_fog.frag` placeholder + `FogShaderService` (memoised load, Paint fallback on `FragmentProgram.fromAsset` failure per Flutter issue #108037) + 7 structural tests. |
| 3 | `cddd789` | Add CPU SDF builder for revealed area — `RevealedSdfBuilder`, midpoint-128 signed-distance encoding, chamfer 3-4 two-pass distance transform run twice (once on seed, once inverted) for signed result, 6 structural tests. |
| 4 | `a07dff9` | Write full TIER 2 fog .frag body — all 7 quality dimensions inside one shader. 40 float uniform slots, 1 sampler, no unused uniforms (Impeller startup-fail guard), FlutterFragCoord(), OpenGLES Y-flip guard. |
| 5 | `07aba36` | Route atmospheric+heavenly through TIER 2 fog shader — both renderers materialise the shader on construction, paint-time `obtainShaderSync()` + per-frame uniform setting via `FogShaderUniforms.setAll`. SDF caching with bitmap+viewport hash invalidation. Fallback path = solid colour with feather (no noise — that was the bug). |
| 6 | `d98260e` | Add CPU wisp particle system + integrate to renderers — `WispParticleSystem` with spawn / advance / render, LRU cap at kMirkFogWispMaxCount=200, curl-noise advection matching the .frag's curl2(), additive blend. Renderers diff bitmap byte-by-byte to spawn wisps at 0→1 cell flips. |
| 7 | (this) | Doc update — BUG-009 status pending → fixed, commit list, BUG-006 supersession + BUG-008 startup note. |

### BUG-006 supersession

The previous `BlurStyle.normal` MaskFilter (BUG-006 fix) is superseded
on the SHADER PATH by the watercolour two-stop boundary inside the
.frag (sharp inner gradient 0→0.7 over `kMirkFogBoundarySharpDistance`,
long-tail bleed 0.7→1.0 over `kMirkFogBoundaryBleedDistance`). The
MaskFilter remains on the FALLBACK PATH so worst-case devices still
see rounded reveals.

BUG-006's "square reveal" symptom is therefore visually addressed by
the new shader — but the user should validate on real device sideload
before formally closing BUG-006. The fix is structurally in place.

### BUG-008 (no fog at startup) note

The new shader pipeline initialises automatically without requiring a
map gesture. On first frame:
  - `FogShaderService.load()` is kicked off on construction (in
    `AtmosphericMirkRenderer` / `HeavenlyCloudsMirkRenderer`).
  - First `paint()` call triggers SDF build (async).
  - While loading, the FALLBACK path paints solid fog at the base
    palette colour with feather — never a transparent canvas.
  - Subsequent frames pick up the shader + SDF → switch to the
    shader path automatically.

No "no fog at startup" symptom should manifest. To verify on UAT,
launch the app, observe fog colour at the first frame (should be
indigo for atmospheric / dawn-grey for heavenly), then watch the
volumetric texture appear ~100-300 ms later as the SDF resolves.

### Files added (BUG-009 fix)

- `assets/shaders/atmospheric_fog.frag` — single-asset shader for both
  builtins.
- `lib/infrastructure/mirk/shader/fog_shader_service.dart`
- `lib/infrastructure/mirk/shader/fog_shader_uniforms.dart` — 40-slot
  uniform layout single source of truth.
- `lib/infrastructure/mirk/sdf/revealed_sdf_builder.dart`
- `lib/infrastructure/mirk/wisp/wisp_particle.dart`
- `lib/infrastructure/mirk/wisp/wisp_particle_system.dart`

### Files modified

- `lib/config/constants.dart` — kMirkFogXxx tunables block.
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — shader
  path + fallback + wisp integration.
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — same.
- `pubspec.yaml` — declares `flutter.shaders:` block.
- `test/constants_test.dart` — 14 new test cases for the tunables.
- `test/infrastructure/mirk/noise_overlay_test.dart` — pivoted from
  BUG-004-style pixel assertions (which can't run under flutter test's
  software rasteriser for fragment shaders) to BUG-009 structural
  assertions: shaderReady resolves, fallback paints visible, no-throw.

### Verification

- `flutter analyze --fatal-warnings --fatal-infos lib/ test/` — clean.
- `dart format --line-length 160 --set-exit-if-changed lib/ test/` — clean.
- `flutter test` — 991 / 991 pass. 50k-tile perf 11.11 ms avg (well
  under 16 ms device target).

The actual visual quality is verified on real device sideload — the
flutter test software rasteriser does not execute fragment shaders,
so structural assertions are the right level for this layer.

### Files NOT modified (intentional scope-out)

- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart` — different
  visual idiom (radial gradient + flicker). Out of TIER 2 scope.
- `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart` — minimalist
  proof-of-seam. Out of scope.
- `lib/infrastructure/mirk/noise/noise_texture.dart` — no longer used
  by the renderers but kept in tree as `NoiseTexture` static class
  (potential future reuse, no analyzer warnings since it's still
  declared). A separate cleanup commit can remove it post-Phase 11.

## Iterative work post-TIER-2 (2026-04-25 onwards)

La résolution ci-dessus (jusqu'à `a6dbf35` inclus, doc-update du TIER 2) a été écrite à chaud par l'agent qui a livré la stack TIER 2. Les UAT walks suivants ont surfacé que le résultat à l'écran ne ressemble PAS à ce que le shader est censé produire : le fog s'affiche comme une **feuille grise / indigo uniforme**, sans le pattern volumétrique attendu. Plusieurs régressions de pipeline reveal et de logging sont aussi apparues. Le statut est donc repassé à **iterating** et l'investigation continue.

### Log chronologique des commits subséquents

| # | SHA | Description | Outcome on device |
|---|-----|-------------|-------------------|
| 1 | `90bc982` | diag: fog stack logging (FogShaderService, AtmosphericRenderer, HeavenlyClouds, SDF builder) pour identifier la racine du fallback. | Pas exploitable seul — les logs étaient tronqués à cause de la cadence de flush trop haute. |
| 2 | `501f053` | chore: dart format align après le commit de logging. | — |
| 3 | `5c55896` | fix: élargit le contraste visuel du fog — nouveau pattern colour-blend (density lerp uHighlight↔uShadow + shadeDelta + abs(hueShift) tint) ; densityAlpha 0.55→1.0 ; bump des tunables (curl 0.45, lightOffset 0.12, lightStrength 1.4, hueStrength 0.7). | Walk suivant : toujours un corps gris uniforme. Le shader run mais ne produit pas le pattern attendu. |
| 4 | `9fcbf38` | diag: SDF input + projection diagnostics (totalSetBits par renderer + cells-marked par tile). | Confirme que le SDF reçoit bien des bits non-nuls quand l'utilisateur a marché. Le shader path est actif, pas le fallback. |
| 5 | `0e851c5` | diag: user-action checkpoints + reveal pipeline (Start button, MapScreen mount, MirkOverlay build, ActiveSessionController.start, RevealStreamingController, RevealedTileStore.mergeMask, visibleMirkTilesProvider). | Surface le vrai bug en parallèle de BUG-009 : le 1er reveal de 20m ne s'écrit pas sur cold launch. Voir #7. |
| 6 | `fb35154` | fix(logging): force-flush sur lifecycle + timer périodique 2s + threshold abaissé à 5 records. | Ne suffit pas — les walks perdent encore les logs post-pmtiles. Threshold descendu à 1 dans `cbde5bf`. |
| 7 | `935b9de` | fix: débloque le 1er reveal 20m sur cold launch. Root cause : `await ref.read(revealedTileStoreProvider.future)` manquait dans `ActiveSessionController.start()` — le provider retournait null sync parce que le bootstrap path_provider du keep-alive store n'était pas attendu. Fonctionnait dès la 2e session parce que le keep-alive était déjà chaud. **Couvre de fait ce qu'on aurait appelé BUG-008 (pas de fog au démarrage).** | Vérifié on device — le reveal initial fonctionne dès la 1ère session. |
| 8 | `cbde5bf` | fix(logging): drop flush threshold à 1 pour le mode diag. Workaround brut-mais-fiable ; la bonne archi à terme = ring buffer non-bloquant + isolate flusher. | Logs maintenant complets jusqu'au crash / kill. |
| 9 | `1b570d1` | diag: ajout d'un toggle de debug shader density. Constante `kMirkFogDebugOutputDensity` + define GLSL `MIRK_FOG_DEBUG_OUTPUT_DENSITY`. Quand activé, le shader sort `dN` brut en RGB, ce qui permet de vérifier si la noise génère vs si c'est le colour-blend qui collapse. | Outil de debug — produit l'analyse en clair-code qui a identifié les 3 bugs math du shader (ci-dessous). |
| 10 | `76dfca4` | fix: corrige les 3 bugs math du shader colour-collapse. (1) `fbm3` range mismatch — `noise3` retourne `[0,1]`, l'accumulateur donne `density ∈ [0, 0.875]`, donc `dN = density*0.5+0.5` clampait dans `[0.5, 0.94]` ; fix = diviser par 0.875 pour spanner `[0,1]`. (2) `uHueStrength` double-appliqué — `hueShift` incluait déjà le scale, puis le mix `abs(hueShift)*uHueStrength` le ré-appliquait ; en plus le `mix(..., uBase.rgb, ...)` tirait toujours vers uBase indépendamment du signe → flatten au lieu de tint. Fix = directional mix vers uHighlight ou uShadow selon le signe. (3) `uLightStrength` double-appliqué pareil dans la ligne additive `(uHighlight - uShadow)*shadeDelta*uLightStrength` ; fix = drop la 2e multiplication. | À vérifier sur le prochain walk device. |
| 11 | `dcffede` | (build sous lequel le walk 2026-04-26 a tourné — voir entrée chronologique ci-dessous pour le diagnostic.) | Sur device : fog reste une feuille grise plate, **et le file logger n'a capturé que 4 lignes** (main armed + Start button + ActiveSessionController.start + gps.stream). Aucun log du renderer ni de MirkOverlay → soit `paint()` n'est jamais appelé, soit il rentre dans une early-return silencieuse avant le moindre `_log.info`. |
| 12 | (this) | diag(09-bug-009): instrument `paint()` early-return paths and map-page mount to surface silent bailouts. Ajoute en INFO (au lieu de FINE) sur les 4 renderers (atmospheric / heavenly_clouds / candlelight / solid_fill) : (a) un log « first invocation » au tout premier `paint()`, (b) un heartbeat « entry heartbeat » toutes les 60 frames AVANT les guards, (c) un log de transition pour chaque early-return (`disposed` / `visibleTiles.isEmpty` / `clipPath.bounds.isEmpty` / `none`), throttle pour ne logger qu'au changement d'état. Sur `MirkOverlay` : log INFO au premier `build` + log INFO à chaque transition de la cause de bail-out (`rendererAsync not hasValue` / `tilesAsync not hasValue` / `viewport==null` / `zoom==null` / `rendering`). Le heartbeat post-paint des deux renderers shader passe FINE → INFO. | À tester au prochain walk device. |
| 13 | `16db03c` | **fix(logging): IOSink → RandomAccessFile.flushSync — eliminates the async race + ensures iOS durability.** Date: 2026-04-26. Root cause : (1) `IOSink` + `Stream.listen` ne await pas les callbacks `async` → `StateError: StreamSink is bound` sur flush concurrent → catch nulle le sink → ~99 % des records perdus en silence pour le reste de la session. (2) `IOSink.flush()` ne fsync pas — userspace → page cache uniquement, jeté par iOS jetsam pendant le download pmtiles 5.2 GB. What changed : remplace `IOSink` par `RandomAccessFile` ouvert en `FileMode.writeOnlyAppend`, `_onRecord` est maintenant synchrone, chaque record fait `writeStringSync` + `flushSync` (vrai `fsync(2)`). Le timer périodique 2 s, le compteur de threshold et les deux constantes (`kFileLoggerFlushEveryNRecords`, `kFileLoggerFlushPeriodSeconds`) sont supprimés (redondants quand chaque record flush). Watchdog isolate skippe `FileLogger.bootstrap()` (évite un fichier de log parallèle — théorie A.H3) et route via `dart:developer log()`. Bootstrap logue le path absolu en première ligne (cross-check anti container-UUID drift iOS — théorie B.4). Test de régression ajouté : 100 records en boucle serrée, vérifie qu'ils arrivent tous sur disque. What the next walk should produce : **des centaines de lignes de log attendues**. Si toujours <10 lignes, le bug est ailleurs (probablement le silence du pipeline renderer instrumenté dans `7b6d819`). Postmortem complet dans `docs/flutter-discoveries.md` §2.1-2.4. |
| 14 | `0bb407a` | chore(09-bug-009): bump fog drift speeds ~4x. UAT post-`16db03c` confirme le pipeline render-side healthy : shader path actif, `sessionElapsed` advance, uniforms bound, ~96 fps. Le walk-N captura "feuille grise plate", root-cause = drift constants trop lentes. Atmospheric Z far/mid/near `0.018/0.035/0.075 → 0.07/0.15/0.30`, heavenly bumpé proportionnellement (`0.028/0.060/0.115 → 0.11/0.24/0.46`). Au précédent niveau le Far octave (poids 0.55) drift ~0.4 unités noise sur 22 s — sous le seuil perceptuel humain pour "ça bouge". `constants_test` rewrité en assertions structurelles (ladder near>mid>far, heavenly>atmospheric) — pinning d'exact-values transformait chaque tuning UAT en update de test. Outcome on device : user reporte fog encore plat-gris post-bump → la racine de "uniform sheet" n'est pas le drift seul → continue. |
| 15 | `c95d429` | chore(maps): refresh catalog.json — ajout `frm` "France-Melun" ~4 MB. Bundle régional pour itérer plus vite que le FRA 5.5 GB sur les UAT walks autour de Melun. Pas un fix BUG-009 mais accélère la boucle dev. |
| 16 | `b76169a` | feat(maps): ajout polygone FRM dans le country-resolver. Hand-authored bbox `2.55..2.80, 48.45..48.62`. Le contrôleur trie maintenant les polygones par `ascending ring-bbox area` avant de construire `CountryResolver`, donc FRM (~0.04 deg²) gagne sur FRA (~140 deg²) en first-match-wins quand un fix GPS tombe dans les deux. Tie-break alphabétique sur alpha3 pour déterminisme. Ne touche pas BUG-009 directement mais fait partie de la même session de tuning UAT (Melun). |
| 17 | `af6be15` | feat(09-bug-009): **live mirk tuner**. Itérer fog visual via build/sideload/walk = unsustainable (~15 min/cycle). Bottom sheet `DraggableScrollableSheet` sur `MapScreen` avec un slider par paramètre shader (drift/scale/opacity Z far/mid/near, curl, light dir/offset/strength, hue, boundary, density debug). `MirkRuntimeTunables.instance` (ChangeNotifier singleton) shadow les `const` de `lib/config/constants.dart` ; renderers lisent live à 96 fps. Reset par-slider + reset global. Constants restent authoritatifs ; tunable n'est qu'un override runtime. Entry-point gated `if (kDebugMode)` (sera fix dans `503dcd0`). |
| 18 | `503dcd0` | fix(09-bug-009): **unconditional tuner icon — `kDebugMode` is always false in sideload**. Le commit précédent gatait `_MirkTunerButton` sur `kDebugMode`, mais iOS sideload via SideStore = `flutter build ios --release --no-codesign` → AOT-compiled binary sans Apple Developer account → `kDebugMode == false` partout. Tuner icon était permanently invisible sur device. Drop the gate. Solo-dev avec sideload comme seul canal de distribution → chaque install IS un dev build → l'icône reste là. Pour Phase 15+ (ship to non-dev users) : wrap dans `FutureBuilder<bool>(future: FileLogger.readVerbosePref(), ...)` qui gate sur le 7-tap easter-egg. Discovery majeure capturée dans `flutter-discoveries.md` §1.1. |
| 19 | `e7847bc` | fix(09-bug-009): **tuner UX — cap sheet à 50 % screen + scale slider max ×2**. User UAT report sur `c95d429` walk-N+1 : (a) sheet à 92 % cachait la map → impossible d'évaluer l'effet en live ; cap `_kMaxSheetSize` à 0.50 (initial 0.45) pour garder la map visible. (b) Les 3 sliders scale (Far/Mid/Near, atmospheric ET heavenly) saturaient au précédent max — bumped ×2 (`3→6, 5→10, 10→20`) pour donner du headroom. |
| 20 | `0d5a96e` | feat(09-bug-009): **export tunables JSON via share-sheet**. Bouton "Exporter JSON" en bas du tuner. Tap → sérialise `MirkRuntimeTunables` (26 fields, alphabetical, pretty) → `share_plus` (déjà 12.0.2, pas de nouvelle dep). User mail/copy-pastes les valeurs dans le chat agent pour bake → constants.dart. |
| 21 | `b0c362e` | chore(09-bug-009): **bake tuned mirk values from UAT walk N**. Atmospheric drift/scale/opacity, curl, light, hue, boundary tous dialed in à partir de l'export JSON du user. Heavenly inchangé. Arrondi 2-3 sig figs. `MirkRuntimeTunables.reset()` re-init à partir de ces nouvelles constantes. Note de garde-fou : ce bake a inadvertamment écrit `boundaryBleedDistance: 0.0` — sera fix dans `4736342`. |
| 22 | `3aa90d4` | feat(mirk): **user-facing fog opacity slider in burger menu**. "Densité du brouillard" 0.2..1.0, default 0.58. Sets les 3 octaves opacity à la même valeur. Persiste via `SharedPreferences` (clé `kMirkFogOpacityPrefKey`), lu au boot dans `main.dart` → carry-over entre launches. Indépendant du dev tuner (qui a toujours les sliders per-octave) ; les deux écrivent dans les mêmes champs `MirkRuntimeTunables`. |
| 23 | `3e74699` | feat(09-bug-009): **auto-animate curlScale (triangle wave 0→10→0 over 20s)**. UAT discovery du user : varier slowly `curlScale` rend le fog "vraiment vivant" volumétriquement. Bake l'animation par défaut. Helper `triangleWave()` générique + unit tested ; future params peuvent adopter le même pattern (lightDirRadians pour rotating light, hueNoiseScale pour breathing palette). Toggleable dans dev tuner ; static slider = fallback quand off. |
| 24 | `42cd669` | chore(09-bug-009): retune curlScale animation **0..4 over 40s** (était 0..10 over 20s). UAT walk N+1 : 0..10 frantique + visible "boil-over" à apex. 0..4 sweep over 40s feels less frantic. Half-period 20s up + 20s down (rate ±0.1/sec). |
| 25 | `03cf8ba` | chore(09-bug-009): retune curlScale period **40s → 60s**. UAT walk N+2 : 60s ressemble à "ambient breathing" plutôt qu'active motion, matche le "alive but calm" volumetric look. Min/max inchangés (0..4). |
| 26 | `4736342` | fix(09-bug-009): **restore watercolour boundary — kill hard white line + banding**. Régression introduite par le bake (`b0c362e`) : `boundaryBleedDistance: 0.0` collapse le watercolour two-stop blend en un hard step ; combiné à la quantisation 8-bit du SDF → hard white edge avec concentric rings of light. Trois corrections dans `atmospheric_fog.frag` : (1) restore `kMirkFogBoundaryBleedDistance = 0.12` (la long-tail smoothstep est designée pour cacher exactement le SDF stepping ; zeroing it defeated the design). (2) Replace inside-edge `step(0.0, sdf)` par `smoothstep` sur `[-uBoundarySharpDistance, 0]` → inside transition aussi watercolour-soft. Guards contre 0-values du live tuner. (3) Ordered dither 1-byte sur le SDF sample (white-noise hashé sur `FlutterFragCoord`) pour masquer le banding 8-bit — le cerveau average les rings adjacents en gradient smooth. (4) "Watercolour pigment pool" — `kMirkFogBoundaryDensityBoost = 0.15` boost la densité fog dans la bleed band → le fog visiblement réagit au boundary, "nearby fog reacting to it" per user. Nouveau uniform `uBoundaryDensityBoost` slot 36, `uSdfRect` push slots 37..40, `totalFloatSlots 40 → 41`. Outcome : fog "thicker" sur l'inside edge. |
| 27 | `a9c7ced` | fix(09-bug-009): blur SDF post-chamfer to kill cell-rasterisation stair-steps. **REVERTED dans `118b95a`.** Theory : le chamfer SDF est nourri d'un seed binary (cells écrites 0/1 sans AA), donc les rectangle stair-steps des cells sont baked dans le distance field — aucun shader uniform ne peut les cacher. Tentative : 5-tap separable Gaussian σ=1.0 (Pascal `[1,4,6,4,1]/16`) sur `signedDistPixels` AVANT encoding uint8. Coût ~650k ops sur field 256² — négligeable. Outcome on device : insuffisant. Cells projettent sur 20-30 pixels SDF chacune ; un blur radius 3-5 lisse les corners mais pas le caractère rectangulaire. User a aussi observé "mirk aspect changed" — probablement le boundary glow band qui s'étend sur un wider radius autour du smoothed boundary. |
| 28 | `118b95a` | **REVERT de `a9c7ced`.** Le post-chamfer Gaussian σ=1.0 était trop weak pour la résolution réelle des cells (20-30 px chacune), et changeait l'aspect global du mirk. Décision : pas de bandaid sur le SDF builder ; le bug réel est en amont (cells rasterisées en rectangles), il faut soit (a) attaquer Option D dans BUG-010 — rasteriser en circles, soit (b) attaquer BUG-010 Option B — refonte data layer en géométrie continue. |
| 29 | `fe92f5f` | chore: curl period 40 → 60s un cran plus tôt dans la timeline (probablement un revert intermédiaire avant `03cf8ba` reprenait la valeur à 60s). Cosmétique. |

### Diagnostic 2026-04-26 — silent paint bailout suspecté (commit `dcffede` walk)

**Symptôme.** Walk iOS sideload sur build `dcffede` : kill app → cold launch → tap "Démarrer" → tap "Carte plein écran" → walk 100 m → stop. Le fog rendu reste une feuille grise plate, sans aucun pattern volumétrique visible. **Et plus critique** : le file logger n'a capturé que 4 lignes au total :

```
{"level":"INFO","logger":"main","msg":"MirkFall starting — logger armed — commit: dcffedeb6f46b8136c7e5f0d6596ef8e1f710137"}
{"level":"INFO","logger":"presentation.session_detail","msg":"_handleStart: Start button pressed for session=...(state=Idle)"}
{"level":"INFO","logger":"application.controllers.active_session","msg":"start(): called for session=..."}
{"level":"FINE","logger":"gps.stream","msg":"stream start · session=... distanceFilter=5m accuracyCeiling=50.0m"}
```

**Signal positif.** Le 4ᵉ log est en niveau FINE → la sink + filtering FINE marchent. Le problème n'est PAS le logger.

**Hypothèse racine.** Aucun log du renderer (`infrastructure.mirk.atmospheric` etc.), aucun log de `presentation.mirk_overlay`, aucun log de `presentation.map_screen` (`MapScreen.initState: mounted`). Donc soit :

- (a) `MapScreen` n'a jamais été monté (l'utilisateur n'a pas atteint la `/map` route, ou la build de Scaffold s'arrête avant `_buildMapStack`),
- (b) `MapScreen` est monté mais `MirkOverlay` ne l'est pas (le `MirkInitialRevealFade` ou la chaîne `Stack > Positioned.fill > IgnorePointer > RepaintBoundary > MirkInitialRevealFade > MirkOverlay` s'arrête avant),
- (c) `MirkOverlay` est monté mais bail-out à chaque build avant l'INFO de `initState` (impossible — `initState` log était déjà INFO),
- (d) `MirkOverlay.build()` retourne `SizedBox.shrink()` à chaque rebuild parce qu'un prerequisite reste null (`rendererAsync` / `tilesAsync` / `viewport` / `zoom`) — dans ce cas le `CustomPaint` n'est jamais wired, donc `_MirkPainter.paint()` n'est jamais appelé, donc aucun renderer n'a la moindre raison d'émettre un log.

**Diagnostic landed (this commit).** Voir entrée #12 dans la table des commits. Instrumentation INFO sur 6 fichiers :

- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart`
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart`
- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart`
- `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart`
- `lib/presentation/widgets/mirk_overlay.dart`
- (le `MapScreen.initState` log INFO existait déjà — non touché)

Toutes les transitions sont throttled (log seulement au changement d'état) ou heartbeated (log toutes les 60 frames) pour éviter de saturer le file logger à 60 Hz.

**Sortie attendue au prochain walk** — pattern de discrimination :

1. **Si `MapScreen` n'est pas atteint** : pas de log `MapScreen.initState: mounted`. Hypothèse (a) confirmée — investiguer la GoRouter route `/map` ou le Scaffold `body` (rewriterAsync / sourceAsync resté loading ?).
2. **Si `MapScreen` est monté mais `MirkOverlay` ne l'est pas** : on voit `MapScreen.initState: mounted` mais pas `MirkOverlay: initState — Ticker started`. Hypothèse (b) — investiguer `MirkInitialRevealFade` ou la branche `_buildMapStack`.
3. **Si `MirkOverlay` est monté mais bail-out** : on voit `MirkOverlay: initState`, puis un `build: prerequisite state (initial) → <reason>` qui pointe la cause (`rendererAsync not hasValue (AsyncLoading<MirkRenderer>)`, `tilesAsync not hasValue`, `viewport==null`, `zoom==null`). Hypothèse (d) — investiguer le provider qui ne résout pas (`activeMirkRendererProvider` / `visibleMirkTilesProvider` / `mapViewportProvider` / `mapViewportZoomProvider`).
4. **Si tout monte ET le renderer paint** : on voit en plus `paint(): first invocation — disposed=false visibleTiles=N canvasSize=WxH` du renderer actif (atmospheric / heavenly / candlelight / solid_fill selon le style sélectionné), suivi de `paint(): early-return state (initial) → <none|disposed|visibleTiles.isEmpty|clipPath.bounds.isEmpty>`. Si `→ none` : paint() exécute le path complet — dans ce cas on revient à un bug visuel pur (le shader `dcffede` post-`76dfca4` a un défaut non couvert par les 3 bugs math fix), et on attend un log `paint(): path transition (initial) → shader` ou `→ fallback` qui dit lequel des deux pipelines tourne. Si `→ visibleTiles.isEmpty` ou `→ clipPath.bounds.isEmpty` : la pipeline de tiles ne propage pas les bits jusqu'au renderer (régression cousine de `935b9de`).

**Verdict possible après le walk** : un seul de ces 4 patterns devrait matcher, ce qui pinpointe le bug en une seule itération au lieu d'avancer à l'aveugle.

### Findings clés à garder en tête

1. **Bugs math du shader (résolus dans `76dfca4`, à valider on device).** Le colour-collapse observé sur les walks 3-9 vient probablement de ces 3 bugs cumulés. Le shader run, le SDF est correct, le pattern noise est généré, mais le pipeline final écrasait toute variation. La fix est landed mais demande validation sur device avant de re-fermer le bug.
2. **Tuning des constantes** — déjà bumpé une fois dans `5c55896` (curl 0.18→0.45, lightOffset 0.04→0.12, lightStrength 0.55→1.4, hueStrength 0.35→0.7). Ces valeurs ont été choisies AVANT que les bugs math soient corrigés ; il faudra probablement 2-3 itérations on device après `76dfca4` pour les rééquilibrer (les bugs math suréchelonnaient la light/hue de fait, donc la fix peut faire baisser le signal visible).
3. **Ce que l'utilisateur observe sur les derniers walks (avant `76dfca4`) :**
   - ✅ Reveal initial fonctionne dès la 1ère session (race fix dans `935b9de`)
   - ✅ Boundary watercolour visible : gradient + bord blanc autour de la zone clear
   - ❌ Corps du fog reste un gris/indigo uniforme, pas de noise volumétrique visible
   - Suspect (et probablement résolu par `76dfca4`) : les 3 bugs math ci-dessus.

### Régression cousine — BUG-006 (reveal carré)

`BlurStyle.normal` (le fix BUG-006 d'origine) lissait les coins du blob mais à 25 m de rayon le reveal reste **visiblement carré** : data layer stocke en grille 64×64 cellules par parent tile (cellules de 19 m), 25 m couvre ~1.5 cellule, ce qui produit un "+" structurel quel que soit le rendu en aval. Voir `BUG-006-square-reveal-instead-of-circle.md` (followup post-walk) et **BUG-010** (refonte data layer en géométrie continue).

### Follow-ups non-liés au shader

- **Audit `fake_async`.** Le commit `fb35154` a ajouté `fake_async: 1.3.3` en dev_dependency sans mettre à jour `DEPENDENCIES.md` comme l'exige `CLAUDE.md`. À auditer + documenter dans un commit séparé (audit licence + télémétrie + dépendances transitives, puis ajout `DEPENDENCIES.md`). Hors scope du fix BUG-009.
