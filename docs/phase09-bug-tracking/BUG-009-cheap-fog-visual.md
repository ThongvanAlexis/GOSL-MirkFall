# BUG-009 — Le rendu fog est "Temu / cheap", besoin d'un visuel premium

**Status:** iterating (TIER 2 a landé le 2026-04-25 mais plusieurs régressions et un symptôme persistant "feuille grise indigo / pas de pattern volumétrique" sont sortis sur les UAT walks suivants ; voir log chronologique en bas)
**Reported:** 2026-04-25 (iOS UAT walk après build `632a210`)
**Platform:** iOS sideloaded (mais le bug est cross-platform — c'est un défaut de design)
**Phase context:** L'effet livré par BUG-004 fix (commit `632a210`) consiste en : noise grayscale 256×256 pré-rasterisé tilé, qui drift à 30/50 px/s en ligne droite via translateMatrix, par-dessus un fog uni avec mask filter. Visuel inspecté par l'utilisateur : ressemble à "bruit qui slide vers la gauche", pas à du brouillard.

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
