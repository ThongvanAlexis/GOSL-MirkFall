# Phase 09: Fog Rendering - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning (with upstream-doc amendments required — see §amendments)

<domain>
## Phase Boundary

Livrer le rendu du mirk — le brouillard de guerre vivant qui donne son identité au produit. Fournir :

- **Un renderer seam `MirkRenderer`** (interface déjà figée Phase 07) qui encapsule tout le rendu fog sans fuir de détail d'implémentation ni de type Flutter/MapLibre à la couche app.
- **4 variants built-in**, chacun comme une classe renderer distincte dans `lib/infrastructure/mirk/`, prouvant le seam **3 fois** ("ajouter un style = nouveau fichier, zéro core modification" — MIRK-05) :
  1. `atmospheric` — brouillard noir mouvant avec noise-variable density (default, MIRK-04, MIRK-06)
  2. `solid` — aplat opaque, zéro noise, zéro anim (proof-de-seam minimaliste)
  3. `candlelight` — lueur chaude orangée, feel "feu de camp" la nuit
  4. `heavenly_clouds` — nuages aériens clairs, feel "explorateur"
- **Le reveal streaming** depuis les fixes GPS de la `ActiveSessionController` Phase 05 → batch flush 2s / 20 fixes (configurable) → merge OR dans `t_revealed_tiles` → rendu fog dissipé en quasi temps réel.
- **Le finalisation de `computeRevealMask`** (actuellement `UnimplementedError` Phase 03) — algèbre géométrique cercle 25m → bitmap 64×64 par parent tile affecté.
- **Le reveal initial 20m** au session start (déféré Phase 07 → delivré ici), écrit en DB dès que la session démarre avec fallback sur le premier fix si position indisponible.
- **Le wire-up du menu burger "Changer le style"** (stub ListTile Phase 07) pour permettre la sélection d'un des 4 builtins par session (pull MIRK-07 de Phase 13 → Phase 09).
- **L'architecture du seam `MirkStyleConfig` finalisée** : le sealed union passe de 3 variants (atmospheric / shader / unknown) à **6 variants** (atmospheric / solid / candlelight / heavenly / shader / unknown), préparé pour l'import utilisateur Phase 13 sans refactor du core.
- **La viewport filtering** pour SC#5 — seuls les parent-tiles intersectant la viewport sont peints.
- **L'isolation `RepaintBoundary`** pour SC#4 — l'animation du mirk ne déclenche aucun rebuild des autres layers (base map, user location, futurs markers).
- **La fixture 50k sub-tiles** + test de perf confirmant frame ≤ 16ms sur device milieu de gamme Android.

**Requirements couverts (5 + 1 pull) :** MIRK-01, MIRK-02, MIRK-04, MIRK-05, MIRK-06 + **MIRK-07 pulled from Phase 13**.

**Hors scope Phase 09 (autres phases, confirmé) :**
- Sélecteur de style dans l'écran options global / import d'un style JSON / suppression de styles importés (MIRK-08, MIRK-09, OPT-03, OPT-04) — Phase 13
- Renderer GLSL shader complet (`MirkStyleConfig.shader` reste déclaré mais non implémenté) — Phase 13
- Rayon de reveal slider UI (OPT-02) — Phase 13 (constants.dart en Phase 09 seulement)
- Markers visibles sous mirk en transparence 30% (MARK-07) — Phase 11 (mais architecture anticipée en Phase 09)
- Export d'une session incluant bitmap de révélé — Phase 13
- Shader validation + sandbox pour imports JSON — Phase 13
- Ripple animation / tap-to-reveal manuel — reporté Phase 15 polish ou plus tard
- Auto-bascule perf sur device low-end — non adopté

</domain>

<decisions>
## Implementation Decisions

### Identité visuelle du style atmospheric (défaut)

- **Feel** : "brouillard mouvant noir" (verbatim user) — plus générique que la référence RTS Warcraft 3 de PROJECT.md, moins médiéval/gamy. Le feel reste cohérent avec un futur style parchemin V2 mais ne le suppose pas.
- **Palette** : noir / gris profond monochrome. Maximum de contraste avec la carte révélée, neutre sur le basemap Protomaps (Phase 07) et portable sur le futur parchemin.
- **Densité** : dense mais variable via noise fn au-dessus d'un baseline opaque. Le noise module l'alpha autour du baseline pour créer un feel "nuage varié" sans jamais laisser passer complètement la carte.
- **Baseline alpha** : **99% configurable** via `kDefaultMirkBaselineAlpha` dans `lib/config/constants.dart`. Le user ajustera en dev — le fond de carte reste très légèrement devinable (1% de basemap qui transparaît) ce qui facilite le composite-trick Phase 11 (markers à 30% alpha sous mirk).
- **Animation** : drift lent subtil — période ~10–20 s, mouvement d'une noise fn simplex/perlin. Vivant sans être distrayant, budget frame prévisible. Pas de swirling marqué, pas de statique.

### Géométrie du reveal

- **Rayon par défaut** : **25 m**, stocké dans `kDefaultRevealRadiusMeters` (`lib/config/constants.dart`). Cohérent avec le `kInitialRevealRadiusMeters = 20` existant (Phase 07) pour l'ouverture de session — les deux constantes restent distinctes, c'est intentionnel (l'initial 20m à l'ouverture + les 25m par fix ongoing).
- **Bord** : **feather** (dégradé doux) — le rendu passe de 100% opaque à 0% sur ~10% du rayon (≈ 2,5 m de bande de transition à 25 m). L'implémentation (mask bitmap non-binaire post-blur, ou composite blur runtime) est Claude's discretion → tranchée en research. Le stockage bitmap reste binaire (MIRK-03 monotone OR intact), le feather est une propriété de rendu.
- **Cells flip** : **toutes les cellules 64×64 touchées par le cercle 25 m** sont flippées à 1 (intersection géométrique, pas centre-inside). Résultat : zone révélée légèrement plus large qu'exactement 25 m (demi-cellule en plus au bord, ~1 m). Évite les micro-trous sur traces zigzag.
- **Cadence flush DB** : **2 s ou 20 fixes** (le premier des deux déclencheurs). Configurable via `kRevealFlushIntervalSeconds` et `kRevealFlushMaxFixes` dans `lib/config/constants.dart` (le user veut pouvoir tuner en dev). **Remplace le 5s/50fixes du ROADMAP SC#1 — amendement nécessaire (voir §amendments).**
- **Animation d'apparition du reveal initial 20 m** : fade-in doux sur **~500 ms** à l'ouverture de session. Cohérent avec le feather edge — feel "brume qui se dissipe".

### Variants built-in

- **4 variants** ship en Phase 09 : atmospheric (défaut) + solid + candlelight + heavenly_clouds.
- **Chaque variant = une classe renderer distincte** dans `lib/infrastructure/mirk/` (pas juste des instances à params différents). Prouve SC#2 "ajouter un style = nouveau fichier" trois fois plutôt qu'une.
- **Pas de fallback perf auto** — les 4 variants sont des choix esthétiques. Si le renderer atmospheric ne tient pas les 16 ms sur device cible, c'est un bug Phase 09 à corriger (simplifier la noise, optimiser, viewport culling plus strict), pas un parachute.
- **Sélection par l'utilisateur** : **wire-up du menu burger "Changer le style"** Phase 07 (ListTile stub déjà placé) est **activé en Phase 09** avec les 4 builtins. Persistence via `t_sessions.mirk_style_id` déjà en place Phase 03. Pull de MIRK-07 de Phase 13 → 09 (voir §amendments).
- **Détails visuels de candlelight + heavenly_clouds** : au discrétion Claude en planning (intensité lumineuse + rayon + teinte pour candlelight ; densité + teinte + drift pour heavenly). Convergera en research + plan.

### Under-mirk visibility + initial reveal

- **Baseline alpha 99%** (cf. identité visuelle) → le basemap est toujours très légèrement devinable. Cohérent avec le design markers alpha 30% sous mirk Phase 11 (ROADMAP Phase 11 SC#4).
- **Anticiper Phase 11 markers composite-trick** : l'architecture `MirkPaintContext` + le layer ordering doivent permettre au marker layer Phase 11 de se paint en transparence **par-dessus** le mirk sans modifier le core Phase 09. Deux pistes à investiguer en research :
  - Hook sur `MirkRenderer` exposant un blend-mode pour un overlay marker (contre le principe "3 méthodes frozen" — risque).
  - Layer ordering via MapLibre — les markers Phase 11 arrivent dans un layer au-dessus de `mirk_fog` dans `kStyleLayerOrder` (cela reorder la constante → violerait le contrat "frozen layer order" Phase 07). **Préférer** : ajouter un nouveau layer marker au-dessus de `mirk_fog` sans déplacer les layers existants (append, pas reorder).
- **Initial reveal 20 m au session start** : écrit en DB **dès que la session démarre** (`ActiveSessionController.startSession()` → write bitmap 20 m autour de la dernière position connue). **Fallback** : si aucune position n'est disponible au moment du start (premier lancement, GPS pas encore accroché), attendre le premier fix et écrire le 20 m autour de lui. UX ciblée : "dès que je start ma session, je me vois au centre d'un rond révélé".
- **`computeRevealMask` finalisée** Phase 09 (body change sur la signature frozen Phase 03) — tant pour le 20 m initial que pour les 25 m streaming.

### Architecture import/export mirk styles (anticipation Phase 13)

- **Scope import utilisateur** : **parameter-based + shader GLSL**. Le JSON utilisateur peut décrire soit une combinaison de params sur un variant existant (atmospheric-like avec couleurs custom), soit un shader GLSL embarqué (puissance max + risque GPU assumé par le user).
- **Paramètres exposés sur atmospheric** (liste large, Freezed-extensible d'entrée de jeu Phase 09) :
  - `baseColorArgb` (ARGB du fog de base)
  - `secondaryColorArgb` (2e couleur pour noise gradient, optionnelle)
  - `noiseScale` (fréquence spatiale de la noise fn)
  - `noiseSpeed` (vitesse d'anim de la noise)
  - `driftDirectionDeg` (direction du drift en degrés, 0 = nord)
  - `densityBaselineAlpha` (0..1, baseline opacité — 0.99 défaut)
  - `featherRadiusFraction` (0..1, fraction du rayon où l'edge feather)
  - `edgeSoftness` (0..1, courbe du feather)
- Les 4 variants built-in n'utilisent qu'un sous-ensemble, mais le Freezed est conçu d'emblée pour tous. Ajouter un param Phase 13+ = `@Default` sur le Freezed, zéro breaking change.
- **Validation** : **strict à l'import Phase 13** (refus du JSON invalide — ne persiste jamais un style corrompu). Le runtime `MirkStyleConfig.unknown` fallback (déjà en place Phase 03) reste la **défense secondaire** pour les imports cross-version (future schema bump). Deux couches de défense coexistent : Phase 13 refuse au import, Phase 09 runtime ne crash jamais même si un variant inconnu arrive (bascule vers `unknown` → default atmospheric).
- **Sealed union cible** : `MirkStyleConfig` passe de `{atmospheric, shader, unknown}` Phase 03 à `{atmospheric, solid, candlelight, heavenly, shader, unknown}` Phase 09. **6 variants**. Chacun authorable par JSON utilisateur (Phase 13 wire-up) avec son propre schema de params.
- **Shader variant** reste déclaré en Phase 09 (entry dans le sealed union + Freezed) mais **son renderer n'est pas implémenté** — reste `UnimplementedError` ou un stub `NoopMirkRenderer`-like jusqu'à Phase 13. Phase 09 prouve juste que le seam supporte son existence (registration Riverpod ready, fromJson ready).

### Performance + viewport filtering

- **Viewport filtering** (SC#5) : seuls les parent-tiles (z=14) intersectant la viewport courante `MapView` sont peints. Le `MirkPaintContext` Freezed est **étendu** Phase 09 pour porter : viewport bbox, current fix, frame time. L'extension respecte le principe "Freezed friction force une review" — c'est un changement de contrat volontaire, pas un drift.
- **RepaintBoundary isolation** (SC#4) : le widget porteur du `CustomPainter` / `FragmentShader` est entouré d'un `RepaintBoundary`. Les autres layers (base map, user location, futur markers) ne rebuild pas quand la noise fn tick. DevTools valide.
- **Fixture 50k sub-tiles** : test dédié qui charge une DB de test avec 50k rows `t_revealed_tiles` (≈ 800 parent-tiles × 64 cellules active moyenne). Mesure le frame time sous Flutter driver. Pass = 16 ms max sur emulator milieu de gamme. Cible device réel différée à Phase 10 review gate.
- **Pas d'auto-fallback perf** (cf. variants decision) — si 16 ms fail sur atmospheric, on optimise, on ne switch pas.

### Claude's Discretion

- Stratégie de rendu : MapLibre layer `mirk_fog` converti en type `fill` avec GeoJSON tuilée côté client, OU Flutter `CustomPainter` / `FragmentShader` overlay sous `RepaintBoundary` au-dessus du `MapView` widget. Tranché en research selon perf + composite Phase 11 implications.
- Implémentation du feather edge : mask non-binaire post-blur vs composite runtime blur vs shader-driven smoothstep.
- Noise fn exacte : simplex, perlin, ou procédurale maison. Période + scale + amplitude.
- Paramètres visuels exacts de candlelight (teinte orangée, rayon lumineux, fall-off).
- Paramètres visuels exacts de heavenly_clouds (densité, teinte, drift speed).
- Paramètres visuels exacts de solid (gris très sombre vs noir pur ; opacity statique).
- Algorithme de `computeRevealMask` : bbox-first + per-cell geometry intersect, ou raster fill bresenham-style, ou autre.
- Format de la fixture 50k-tiles (seed SQL vs JSONL vs Dart fixture builder).
- Naming exact des nouveaux renderer classes (AtmosphericMirkRenderer / SolidFillMirkRenderer / CandlelightMirkRenderer / HeavenlyCloudsMirkRenderer — conventions à valider).
- Registration pattern des 4 builtins (Riverpod MultiProvider vs Factory pattern vs registry constant).
- `FragmentShader` vs `CustomPainter` pour l'animation de la noise fn.
- Stratégie de gestion du `session.mirk_style_id` changement in-session (immédiat vs next session).
- Exact signature extended `MirkPaintContext` Phase 09 (viewport bbox représentation, fix optional, frame time).
- Copy UI du burger menu ListTile "Changer le style" (titre, sous-titre, badge si custom).
- Test strategy pour les 50k-tiles (emulator seul vs inclure un probe device CI).

</decisions>

<specifics>
## Specific Ideas

### Mentions verbatim du user

- **Brouillard** : "une sorte de brouillard mouvant noir" — feel plus générique que Warcraft 3, plus brute. Le noir domine, le mouvement est visible, pas de romance médiévale imposée.
- **Baseline alpha configurable** : "alpha a 99% dans le fichier de config dart, je jouerais avec pour faire des test" — le user va tuner lui-même en dev. Constants.dart, pas settings UI.
- **Variants** : "atmospheric + solid + candlelight + heavenly clouds" — 4 builtins, augmentation franche par rapport aux 2 minimum SC#2.
- **Flush cadence** : "2s ou 20 fixes, rend le configurable au cas ou on se rend compte que c'est pas bon" — 2.5× plus réactif que le ROADMAP SC#1 initial + tunable en dev.
- **Import/export architecture** : "parlon de l'import/export du style de mirk pour prevoir l'architecture" — demande explicite d'anticiper Phase 13 en Phase 09 pour ne pas avoir à refactor le seam.

### Références

- Warcraft 3 fog of war (cité PROJECT.md) — reste une ambiance directrice côté Claude pour la densité + la cinématique lente, même si le user formule "brouillard mouvant noir" plus génériquement.
- Fog of World (app concurrente) — le mirk plus simple de FoW est le floor acceptable ; l'objectif est au-dessus (plus vivant, plus varié).
- Le style parchemin RPG V2 (différé `PROJECT.md §V2 Backlog`) est un basemap, **pas** un style de mirk. Aucune interaction architecturale entre les deux — les 4 mirk builtins doivent fonctionner sur n'importe quel basemap (Protomaps neutre Phase 07 ou parchemin V2).

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 03–07)

- **`lib/domain/mirk/mirk_renderer.dart`** (Phase 07) — interface abstract frozen : `paint(Canvas, Size, MirkPaintContext)` + `update(Duration elapsed)` + `Future<void> dispose()`. Zéro méthode de plus. Le `mirk_renderer_contract_test` guard la surface. Phase 09 implémente 4 classes concrètes sans toucher à l'interface.
- **`lib/domain/mirk/mirk_paint_context.dart`** (Phase 07) — Freezed avec `zoomLevel` + `pixelRatio` + `sessionElapsed`. Phase 09 ÉTEND avec viewport bbox + current fix + frame time (Freezed friction = review explicite du contrat élargi).
- **`lib/infrastructure/mirk/noop_mirk_renderer.dart`** (Phase 07) — stub no-op. Phase 09 : reste présent pour le wiring tests, **4 nouveaux renderers concrets** ajoutés dans le même dossier.
- **`lib/domain/mirk/mirk_style.dart`** (Phase 03) — Freezed entity `{id, displayName, config, createdAtUtc, createdAtOffsetMinutes}` avec `fromJson`/`toJson`. Phase 09 peuple avec les 4 builtins + garde la shape pour les imports Phase 13.
- **`lib/domain/mirk/mirk_style_config.dart`** (Phase 03) — sealed union `{AtmosphericConfig, ShaderConfig, UnknownConfig}`. Phase 09 étend à 6 variants : `+ SolidConfig + CandlelightConfig + HeavenlyCloudsConfig`. Le fallback `UnknownConfig` reste la défense forward-compat Phase 03. `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` supporté.
- **`lib/domain/mirk/mirk_style_store.dart`** (Phase 03) — port Drift backed. Lit les styles du `t_mirk_styles`. Phase 09 ajoute les 4 builtins seed au first-launch bootstrap.
- **`lib/domain/revealed/reveal_calculator.dart`** (Phase 03) :
  - `mergeBitmap(Uint8List, Uint8List)` + `popcount(Uint8List)` — **ready**, utilisables en l'état.
  - `computeRevealMask({centerLat, centerLon, radiusMeters, parentX, parentY, parentZoom})` → `UnimplementedError` Phase 03. **Phase 09 body change** (signature immuable).
- **`lib/domain/revealed/revealed_tile_store.dart`** (Phase 03) — port avec `listBySession`, `findByParent`, `mergeMask`. Phase 03-06 DriftRevealedTileStore déjà impl. Phase 09 consomme `mergeMask` pour le flush batch.
- **`lib/domain/revealed/revealed_tile.dart`** (Phase 03) — Freezed entity avec `bitmap: Uint8List` (512 bytes, 64×64 bits) + `setBitCount` + assertions MIRK-03. Aucune modif Phase 09.
- **`lib/domain/revealed/tile_math.dart`** (Phase 03) — `TileMath.latLonToTile` + `TileMath.tileToLatLon` (clamped Mercator). Phase 09 consomme pour la conversion lat/lon → parent-tile coords.
- **`lib/application/controllers/active_session_controller.dart`** (Phase 05) — expose le stream de `Fix` depuis le `LocationSource`. Phase 09 : le consumer primaire (reveal streaming). Hook `startSession` pour l'initial 20 m reveal.
- **`lib/infrastructure/stores/drift_revealed_tile_store.dart`** (Phase 03-06) — implémentation Drift avec transactional `mergeMask`. Phase 09 consomme en l'état.
- **`t_revealed_tiles` Drift table** (Phase 03 V2 schema) — primary key `(session_id, parent_x, parent_y)`, BLOB bitmap, index sur `session_id`. FK CASCADE vers `t_sessions`.
- **`t_sessions.mirk_style_id`** (Phase 03) — FK vers `t_mirk_styles`, nullable. Phase 09 écrit à la sélection in-session burger menu.
- **`assets/maps/style.json`** (Phase 07) — contient un layer `"id": "mirk_fog", "type": "background", "background-opacity": 0` en position 7/7 dans `kStyleLayerOrder` frozen. Phase 09 **peut tuner** le paint + type mais **ne peut pas reorder**. Si Phase 09 choisit rendering via MapLibre layer : convertit `mirk_fog` en type `fill` avec source GeoJSON tuilée côté client (MAP-04 pattern décrit en Phase 07 CONTEXT). Si Phase 09 choisit rendering via Flutter overlay : laisse `mirk_fog` en background opacity 0 et paint par-dessus.
- **`lib/infrastructure/map/style_layer_order.dart`** (Phase 07) — constante `kStyleLayerOrder = ['background', 'landcover', 'water', 'boundaries', 'roads', 'pois', 'mirk_fog']`. Guarded par `assertStyleLayerOrder` + `test/presentation/map_style_layer_order_test.dart`. Phase 11 ajoutera un layer marker **au-dessus** de `mirk_fog` — Phase 09 doit documenter cet append prévu pour ne pas avoir à reorder.
- **`lib/presentation/widgets/session_burger_menu.dart`** (Phase 07) — ListTile "Changer le style" unwired + snackbar "Phase 13". Phase 09 remplace le stub par la vraie wire-up : bottom sheet / dialog listant les 4 builtins + write `session.mirk_style_id`.
- **`lib/config/constants.dart`** — Phase 09 ajoute :
  - `kDefaultRevealRadiusMeters = 25`
  - `kRevealFlushIntervalSeconds = 2`
  - `kRevealFlushMaxFixes = 20`
  - `kDefaultMirkBaselineAlpha = 0.99`
  - `kInitialRevealFadeInMs = 500`
  - `kFeatherRadiusFraction = 0.1` (fraction du rayon où l'edge feather)
  - `kMirkNoiseScaleDefault = 0.5` (placeholder — Claude tune en research)
  - `kMirkNoiseSpeedDefault = 0.05` (placeholder)
  - `kMirkDriftDirectionDegDefault = 0.0` (nord par défaut)
  - Constantes supplémentaires pour candlelight + heavenly au discrétion research
- **`lib/infrastructure/logging/file_logger.dart`** — `Logger('infrastructure.mirk')` + `Logger('application.reveal')` à instancier Phase 09. Pattern `logger.info/warn/severe` existants.

### Established Patterns

- **CLAUDE.md** (confirmé 8 phases code + review gates) — singulier/pluriel, p.join, pas de magic numbers hors constants.dart, sealed + pattern match, DI Riverpod, types stricts, `dart format`, zéro warning, timeouts, pin exact, audit DEPENDENCIES.md.
- **Freezed sealed union + fallbackUnion** (confirmé Phase 03 avec `UnknownConfig`) — pattern `@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')` prouvé.
- **Renderer seam exactly 3 methods** — garded par `mirk_renderer_contract_test` Phase 07. Phase 09 ne peut rien ajouter.
- **MIRK-03 monotone OR merge** — invariants Drift + tests Phase 03. Phase 09 consomme en l'état.
- **Test runner split** — pure Dart + Drift in-memory via `dart test`, widget tests via `flutter test`. Phase 09 mix : compute + store tests en pure Dart, renderer + burger menu tests en flutter widget.
- **Atomic commits par tâche** — `feat(09-XX): ...`, `test(09-XX): ...`, `docs(09-XX): ...`, `refactor(09-XX): ...`.
- **Layer READMEs** — `lib/infrastructure/mirk/` existe déjà avec README Phase 07. Phase 09 met à jour avec les 4 renderers + règle import.
- **Inertness-guard idiom** pour les permanent regression tests (Phase 02/04/06/08 review gates) — à réutiliser Phase 09 pour la fixture 50k-tiles + viewport culling regression.
- **4-parallel sub-agent audit pattern** — review gate Phase 10 reproduira ce pattern validé 4 cycles.
- **Exceptions domain `implements Exception`** — Phase 09 ajoute potentiellement `MirkStyleUnknownException`, `RevealMaskComputationException`, `MirkRendererDisposedException` selon besoin research.

### Integration Points

- **`pubspec.yaml`** — Phase 09 peut ajouter une dépendance noise fn / FragmentShader helper si le plan l'exige (audit DEPENDENCIES.md obligatoire — candidate packages à évaluer research : `simplex_noise`, raw FragmentShader sans dep externe, etc.). Aucune dépendance réseau / télémétrie acceptable. Shader-runtime GPU → pas de concern licence au runtime (assets ne se distribuent pas).
- **`DEPENDENCIES.md`** — entry si nouvelle lib noise. Le shader GLSL (pour `ShaderConfig` future Phase 13) reste asset interne : pas de dep externe Phase 09.
- **`lib/infrastructure/mirk/`** — nouveau layout :
  - `atmospheric_mirk_renderer.dart` (default, MIRK-04)
  - `solid_fill_mirk_renderer.dart` (minimaliste, proof-de-seam)
  - `candlelight_mirk_renderer.dart` (warm glow)
  - `heavenly_clouds_mirk_renderer.dart` (airy)
  - `noop_mirk_renderer.dart` (conserved, wiring tests)
  - `mirk_renderer_factory.dart` (registration + resolution `MirkStyleConfig` → `MirkRenderer`)
  - `shaders/` (FragmentShader GLSL files si applicable)
- **`lib/domain/mirk/`** — Phase 09 étend :
  - `mirk_paint_context.dart` → Freezed élargi (viewport bbox + current fix + frame time)
  - `mirk_style_config.dart` → sealed union à 6 variants (ajouts SolidConfig, CandlelightConfig, HeavenlyCloudsConfig)
  - `mirk_renderer.dart` → **non modifié** (interface frozen)
- **`lib/domain/revealed/reveal_calculator.dart`** — `computeRevealMask` body implémenté (signature immuable).
- **`lib/application/controllers/`** — Phase 09 ajoute :
  - `reveal_streaming_controller.dart` (buffer fixes + flush batch DB)
  - `mirk_style_session_controller.dart` (écriture `session.mirk_style_id` + notification renderer swap)
- **`lib/application/providers/`** — Phase 09 ajoute :
  - `mirkRendererFactoryProvider` (résout `MirkStyleConfig` → concrete renderer)
  - `activeMirkRendererProvider` (renderer courant de la session active, keepAlive)
  - `revealStreamingControllerProvider`
  - `builtinMirkStylesProvider` (expose les 4 builtins seed)
- **`lib/presentation/widgets/session_burger_menu.dart`** — Phase 09 remplace le stub "Changer le style" unwired par :
  - Ouverture d'un bottom sheet listant les 4 builtins (nom + preview visuel si faisable)
  - Tap = write `session.mirk_style_id` + swap du renderer en live
  - Bouton "Importer un style" reste unwired avec "Phase 13"
- **`lib/presentation/screens/map_screen.dart`** — Phase 09 wraps le widget `MapView` (et sa superposition mirk) dans un `RepaintBoundary` dédié pour SC#4 isolation. Selon la stratégie de rendu (MapLibre layer vs Flutter overlay), l'intégration diffère — research tranche.
- **`assets/maps/style.json`** — Phase 09 potentiellement convertit le layer `mirk_fog` de `background` à `fill` avec source GeoJSON tuilée côté client. OU le laisse en background opacity 0 et paint via Flutter overlay. Test `map_style_layer_order_test.dart` éventuellement mis à jour (mais `kStyleLayerOrder` reste identique — juste le type du layer change).
- **`test/`** — nouveaux sous-arbres :
  - `test/domain/revealed/reveal_calculator_test.dart` (body de `computeRevealMask` + fixtures masks)
  - `test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart` (+ 3 autres renderers)
  - `test/infrastructure/mirk/mirk_renderer_factory_test.dart`
  - `test/application/controllers/reveal_streaming_controller_test.dart`
  - `test/application/controllers/mirk_style_session_controller_test.dart`
  - `test/presentation/widgets/session_burger_menu_style_selector_test.dart`
  - `test/presentation/map_screen_repaint_boundary_test.dart`
  - `test/performance/fog_50k_tiles_perf_test.dart` (SC#4 frame budget, `@Tags(['perf'])`)
  - `test/presentation/map_screen_viewport_filtering_test.dart` (SC#5 regression)
- **`test/fakes/`** — Phase 09 ajoute :
  - `fake_mirk_renderer.dart` (observable paint/update/dispose calls)
  - `fake_reveal_streaming_controller.dart`
  - `fake_mirk_style_session_controller.dart`
- **`test/fixtures/`** — Phase 09 ajoute :
  - `test/fixtures/mirk/fifty_k_tiles_seed.sql` (fixture 50k revealed sub-tiles)
  - `test/fixtures/mirk/builtin_styles.json` (sérialisation canonique des 4 builtins pour cross-check round-trip)
  - `test/fixtures/mirk/imported_style_valid.json` (atmospheric-variant authorable) — pour anticiper les tests Phase 13
  - `test/fixtures/mirk/imported_style_unknown_type.json` (futur variant inconnu → fallback `UnknownConfig`)
- **`tool/`** — pas de nouveau check script anticipé Phase 09 (le `mirk_renderer_contract_test` reste un test runtime, pas un gate tool). Research peut proposer.
- **Seed des 4 builtins au first launch** — pattern similaire aux catégories default Phase 11. Soit via `FirstLaunchSeeder` existant (si Phase 05 l'a instauré), soit nouveau bootstrap Phase 09 dans `main.dart` (éviter — préférer un provider qui lazy-seed au premier accès au `MirkStyleStore`).

</code_context>

<deferred>
## Deferred Ideas

### Reportées en Phase 13 (Import/Export + Styles UI)
- **Sélecteur de style dans l'écran options global** (OPT-03) — défaut pour les nouvelles sessions.
- **Gestion des styles de mirk importés** (OPT-04, MIRK-09) — liste + suppression d'un style importé par le user.
- **Import d'un style JSON utilisateur** (MIRK-08, PORT-08) — flow complet avec schema validation strict.
- **Renderer GLSL shader complet** — `MirkStyleConfig.shader` reste déclaré Phase 09 mais son renderer concret arrive Phase 13 (validation + sandbox + GPU crash handling).
- **Slider UI rayon de révélation** (OPT-02) — Phase 09 a la constante, Phase 13 a l'UI.

### Reportées en Phase 11 (Markers)
- **Markers visibles sous mirk en transparence 30%** (MARK-07, ROADMAP Phase 11 SC#4) — architecture Phase 09 anticipe le composite-trick (layer append au-dessus de `mirk_fog`, pas reorder de `kStyleLayerOrder`), Phase 11 livre le layer marker + la composite-opacité.

### Reportées en Phase 15 (Polish) ou plus tard
- **Tap-to-reveal manuel d'urgence** (bouton "révéler ici" dans le burger menu, utile si GPS inaccessible mais position certaine) — nice-to-have polish.
- **Ripple / ondulation expansive** à l'apparition du reveal (alternative au fade-in) — variant stylisé futur.
- **Auto-bascule sur solid si frame budget dépasse 16 ms** — rejeté (les 4 variants sont des choix esthétiques, pas des parachutes perf).

### V2 Backlog (documenté `PROJECT.md §V2 Backlog`)
- Le **style parchemin RPG V2** reste un basemap, aucune interaction avec les mirk variants.

### Hors scope global / jamais
- UI settings pour la cadence de flush DB (kRevealFlushIntervalSeconds / kRevealFlushMaxFixes) — pas dans les OPT-* requirements. Constants.dart uniquement (user tunable en dev).
- Multi-language — V1.x I18N.
- Achievements / gamification / stats — hors scope V1 (V2 STAT-*).

</deferred>

<amendments>
## Amendements upstream documentaires (pré-requis avant planning)

**Trois amendements nécessaires** — à appliquer avant `/gsd:plan-phase 09` :

1. **ROADMAP.md Phase 09 SC#1** — remplacer "fréquence pilotée par `distanceFilter` + batch flush 5s/50fixes" par "fréquence pilotée par `distanceFilter` + batch flush **2s/20fixes** (configurable via `kRevealFlushIntervalSeconds` + `kRevealFlushMaxFixes` dans `lib/config/constants.dart`)". Aligne la SC sur la décision Phase 09 CONTEXT (ci-dessus).

2. **REQUIREMENTS.md MIRK-07** — déplacer **de Phase 13 → Phase 09**. La wire-up du menu burger "Changer le style" in-session (sélecteur parmi les styles installés) est livrée Phase 09 en même temps que les 4 built-ins. Les imports (MIRK-08) + le delete (MIRK-09) + la gestion dans l'options global (OPT-03, OPT-04) restent Phase 13. Mettre à jour le tableau `Traceability` + le résumé par phase en fin de REQUIREMENTS.md. Le compte par phase devient : Phase 09 = 6 REQ (MIRK-01, 02, 04, 05, 06, **07**), Phase 13 = 23 REQ au lieu de 24.

3. **REQUIREMENTS.md MIRK-06** — élargir "L'app fournit au moins un style de mirk par défaut (atmosphérique)" en "L'app fournit **4 styles de mirk built-in** en Phase 09 : atmospheric (défaut), solid, candlelight, heavenly_clouds. Chacun = une classe renderer distincte dans `lib/infrastructure/mirk/`, prouvant le seam MIRK-05 trois fois." Aligne MIRK-06 avec la decision Phase 09 CONTEXT.

**Amendement optionnel** :

4. **ROADMAP.md Phase 09 SC#2** — expliciter les 4 variants built-in au lieu de "un second style built-in variant démontre que le seam fonctionne". Reformulation : "L'app fournit 4 variants built-in (atmospheric, solid, candlelight, heavenly_clouds), chacun implémenté comme une classe distincte dans `lib/infrastructure/mirk/` ; ajouter un style ne nécessite qu'un nouveau fichier, zéro modification du cœur (vérifié par code review)."

</amendments>

---

*Phase: 09-fog-rendering*
*Context gathered: 2026-04-24*
