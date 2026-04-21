# Phase 07: Map Integration - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning (with upstream-doc amendments required — see §amendments)

<domain>
## Phase Boundary

Afficher une carte interactive vectorielle rendue par `maplibre_gl 0.25.0` (pinned) contre des fichiers PMTiles **100 % locaux**, derrière une interface `MapView` domain-level (vocabulaire MirkFall, zéro fuite de type MapLibre au-dessus de `lib/infrastructure/map/`). Day-1 UX : un world map bundlé z2 est copié vers `<app_support>/maps/world.pmtiles` au premier lancement. Day-N : écran "Télécharger une carte" permet d'installer des pays individuels depuis un catalog JSON **bundlé en asset** qui pointe vers un GitHub Release (`ThongvanAlexis/countries-pmtiles`, tag `v20260419`) contenant des **chunks binaires multi-parts** (pas des ZIPs — voir §amendments) qui se réassemblent par concat en un unique `.pmtiles` par pays.

**Livrables Phase 07 :**
- Nouvelle route `/map` full-screen avec `MapView` domain-level interface
- Map aussi intégrée dans `SessionDetailScreen` (vue session-spécifique, fixes affichés quand disponibles en Phase 09)
- Burger menu top-left in-session : style change, take picture (unwired), place marker (unwired), lat/long live, distance walked, session time
- Orientation portrait + landscape supportée
- Section "Cartes" dans `/settings` avec 2 entrées : "Télécharger une carte" + "Gérer les cartes installées"
- Boutons unwired "Importer/Exporter un style" dans `/settings` naviguant vers écrans placeholder
- World bundle z2 bundlé dans `assets/maps/world.pmtiles` + copie first-launch vers `<app_support>/maps/world.pmtiles` (check existence + sha256 verify)
- Catalog bundlé en asset (`assets/maps/catalog.json`) — rebuild app pour update
- Pipeline download pays : queue FIFO 1-à-la-fois, progress bar global + bytes, pause manuelle + retry auto coupure réseau, sha256 chunk + global, concat binaire, rename atomique
- Check disk space avant download (refuse si < 110% taille attendue)
- Détection d'update (catalog bumpé) via badge "Mise à jour disponible" dans `/maps/manage`
- Country resolver polygone-based : source unique `mirkfall_map` swapée au franchissement du centre viewport, fallback `world.pmtiles` pour zoom<3 ou pays non-installé
- Banner in-map "Télécharger ce pays" (texte informationnel "Disponible dans Paramètres › Télécharger une carte", pas de deep-link)
- Follow-me toggle (défaut ON à l'ouverture de session)
- Attribution icon 'i' bas-droit expandable au tap (OSM + Protomaps + liens)
- Fog layer stub : interface `MirkRenderer` + no-op impl + layer déclaratif dans style.json (z-order gelé : base → POIs → fog → user location)
- Lints custom via tool/ scripts CI-only (pas de plugin custom_lint) : `check_avoid_maplibre_leak.dart` + `check_avoid_remote_pmtiles.dart` + tests + ci.yml gates
- État cartes installées via manifest JSON `<app_support>/maps/installed.json` (pas de table Drift — pas de migration V3→V4)
- Tests : `FakeMapView` in-memory state-tracking + MockHTTPServer (package:shelf) pour download soak + HTTP interceptor pour airplane-mode unit test + point-in-polygon tests country resolver
- Remplacement `flutter_map: 8.3.0` → `maplibre_gl: 0.25.0` dans `pubspec.yaml` + audit `DEPENDENCIES.md` (maplibre_gl + archive éventuel + shelf dev)
- Amendements documentaires upstream (voir §amendments)

**Requirements couverts (10) :** MAP-01, MAP-02, MAP-03, MAP-04, MAP-05, MAP-06, MAP-07, MAP-08, MAP-09, MAP-10.

**Hors scope Phase 07 (autres phases, confirmé) :**
- Rendu fog + `MirkRenderer` impl (MIRK-01..06) — Phase 09 (Phase 07 ship le stub no-op + interface seulement)
- Markers CRUD + pipeline photos (MARK-*, CAT-*) — Phase 11 (Phase 07 ship le squelette menu burger avec boutons unwired)
- Import/Export JSON complet (PORT-*) — Phase 13 (Phase 07 ship les boutons placeholder dans /settings)
- Sélecteur de style mirk complet + import styles (MIRK-07, 08, 09) — Phase 13
- Écran options complet (OPT-03..07) — Phase 13
- POC OEM battery-killer réel — Phase 15
- QUAL-05 airplane-mode end-to-end smoke — Phase 15 (Phase 07 ship le unit test HTTP interceptor couvrant le subset map)

</domain>

<decisions>
## Implementation Decisions

### Navigation & map entry

- **Route `/map` autonome** dans `lib/presentation/screens/map_screen.dart` — carte full-screen, accessible depuis SessionListScreen (bouton / tile menu) une fois qu'au moins une session existe.
- **Map aussi intégrée dans `SessionDetailScreen`** — quand la session est active, on voit la position courante + (Phase 09) les fixes ; quand stoppée, résumé + (Phase 09) trajet historique. Deux entrées vers le même widget `MapView`, DI des fakes en widget tests.
- **Carte non accessible avant qu'une session n'existe** — au premier lancement (zéro session), l'utilisateur est funneled vers la création de session (UX Phase 05 existante). L'entrée vers `/map` n'apparaît qu'après la première session.
- **Banner session active cross-route** : pattern Phase 05 inchangé — tap = `/sessions/:id` (dashboard texte + carte intégrée). Pas de deep-link vers `/map` depuis le banner.
- **Section "Cartes" dans `/settings`** : extend l'écran existant (Phase 05) avec 2 ListTile — "Télécharger une carte" → `/maps/download`, "Gérer les cartes installées" → `/maps/manage`. Pattern cohérent avec l'extension Phase 13 OPT-04..06.
- **Import/Export style dans `/settings`** : 2 ListTile supplémentaires qui naviguent vers 2 écrans placeholder (`/styles/import`, `/styles/export`) affichant "En construction — disponible Phase 13". Décision user : ship les nav stubs pour freezer la disposition UI.

### Session map UX (in-session burger menu)

- **Carte full-screen** sur `/map` + `/sessions/:id` (pas d'AppBar visible).
- **Burger menu top-left** : bouton rond ~48dp avec 3 tirets, dans le coin haut-gauche en overlay sur la carte. Tap = vertical drawer slide-in depuis la gauche (pattern standard Material `Drawer`).
- **Contenu du drawer** (ListTile ordonnés) :
  1. "Changer le style" — affiche la liste des styles installés (carte + mirk). Phase 07 n'en ship qu'un de chaque, le sélecteur montre juste l'actif. Scope complet en Phase 13.
  2. "Prendre une photo" — ship unwired avec dialog/snackbar "Disponible en Phase 11".
  3. "Placer un marker" — ship unwired idem.
  4. Séparateur.
  5. "Position : lat, lon" — read-only, mise à jour live via `ActiveSessionController` (ou fallback "En attente GPS…" si pas de fix récent).
  6. "Distance parcourue : X.Y km" — read-only, cumul via stream de fixes (calcul `haversine` sur les deltas). Compteur simple Phase 07, optimisations Phase 09 si besoin.
  7. "Durée session : HH:MM:SS" — read-only, chrono depuis `startedAtUtc`, 1s tick (existing pattern Phase 05 `_ChronoCard`).
- **Landscape ET portrait** : drawer width responsive (75% width en portrait, 40% en landscape), layout testé dans widget tests.
- **Bouton follow-me** (crosshair FAB bas-droit) : toggle on/off. Défaut ON à l'ouverture de session. Pan manuel désactive auto (pattern standard).

### Session opening behavior

- **À l'ouverture de `/map` ou `/sessions/:id`** quand la session est active :
  - Camera centrée sur la position courante (ou dernier fix connu si pas encore de fix live)
  - **Zoom Z=13** (quartier/ville) — visible + suffisamment zoomed pour voir un rayon 20m d'ouverture.
  - Follow-me ON par défaut
- **Reveal initial 20m autour de l'utilisateur** : bitmap pré-marqué dans `RevealedTileStore` à l'ouverture de session. **Phase 07 NE PEINT PAS** le fog (stub no-op), donc le 20m reveal est data-only, consumable par Phase 09. La logique de reveal-on-fix (streaming) reste Phase 09. Phase 07 assure juste que l'invariant "au session start, la zone 20m autour de la position initiale est marquée revealed" est écrit en DB.
  - **Note** : implique un call à `RevealedTileStore.mergeMask` + `computeRevealMask` qui étaient `UnimplementedError` en Phase 03. Une décision plan : soit Phase 07 implémente ces 2 méthodes (pre-Phase-09 early drop-in), soit Phase 07 skip le reveal initial et Phase 09 le rattrape à son premier fix. **Recommandation initiale** : skip en Phase 07, capturer l'intent UX, laisser Phase 09 livrer le reveal complet.

### Catalog + world bundle + hosting

- **Catalog = asset bundlé** — `assets/maps/catalog.json` (132 KB, 192+ pays). Pas de `kMapCatalogUrl` remote fetch. Update du catalog = nouveau build de l'app. Le ROADMAP SC#6 mentionne `kMapCatalogUrl` : amendement nécessaire (voir §amendments).
- **Schema catalog** (confirmé via lecture du fichier user) :
  ```
  {
    "countries": [
      {
        "alpha3": "fra",
        "name": "France",
        "parts": [ { "sha256": "...", "size": 1500000000, "url": "https://github.com/ThongvanAlexis/countries-pmtiles/releases/download/v20260419/fra.part01" }, ... ],
        "reassembled": { "sha256": "...", "size": 5242225731 }
      },
      ...
    ]
  }
  ```
- **Granularité pays = ISO 3166-1 alpha-3** (`fra`, `deu`, `usa`, `jpn`...). Codes et noms tirés directement du catalog — pas de subdivisions régionales en V1.0.
- **Version globale = tag du GitHub Release** (ex `v20260419`). Pas de champ `pmtilesVersion` par entrée. Le catalog complet porte implicitement la version via l'URL des parts. Plan : stocker le tag global dans `installed.json` per-pays (champ `pmtiles_version`) pour détection d'update au bump.
- **World bundle = `assets/maps/world.pmtiles`** (fichier user `C:\claude_checkouts\files_for_mirkfall\world-z2.pmtiles`, 856 KB, zoom 0-2). Copié vers `<app_support>/maps/world.pmtiles` au first launch (check existence + sha256 verify pour auto-heal). Le sha256 attendu est stocké dans une entrée spéciale du catalog (alpha3 = "world" ou champ `world.sha256` — choix schema à trancher en plan) OU hardcodé dans une constante Dart générée à la build (option plus simple).
- **Country PMTiles pré-générés** (URL dans catalog pointent sur le GitHub Release). Pas de tooling de génération à livrer en Phase 07. Un script `tool/update_catalog.dart` (ou Python) sera utile à terme pour automatiser la maintenance du catalog, mais hors scope Phase 07 (manuel OK).
- **`kMapCatalogUrl` supprimé / renommé** : remplacé par `kMapCatalogAssetPath = 'assets/maps/catalog.json'` dans `constants.dart`.

### Pipeline download pays

- **Chunks = binaire brut, pas ZIP** — chaque `.partNN` est un morceau binaire du `.pmtiles` final (1.5 GB max par chunk, limite GitHub Release = 2 GB/asset). Reassemblage = `concat` binaire (read part01 + write, append part02 + write, ...). Pas d'extraction d'archive, pas besoin du package `archive`.
- **Protocole download atomique** :
  1. Download séquentiel des N parts vers `<app_support>/maps/staging/<alpha3>/<alpha3>.partNN`
  2. Vérification `sha256` de chaque part avant de passer au suivant (si mismatch → retry chunk 1 fois, sinon fail+abort)
  3. Concat binaire des N parts vers `<app_support>/maps/staging/<alpha3>/<alpha3>.pmtiles`
  4. Vérification `sha256` global du fichier reconstitué (match `reassembled.sha256`)
  5. Rename atomique vers `<app_support>/maps/countries/<alpha3>.pmtiles`
  6. Update `<app_support>/maps/installed.json` (ajout entrée)
  7. Cleanup staging `<alpha3>/`
- **Interruption à n'importe quelle étape** → soit reprise (staging complet partiel), soit cleanup si user abandon explicite. Jamais de pays partiel visible dans `installed.json` ou dans `countries/`.
- **Queue = FIFO, 1 pays à la fois** — l'utilisateur peut enfiler plusieurs pays, ils se traitent séquentiellement. Queue persistée dans `<app_support>/maps/download_queue.json` pour survivre aux relances app.
- **UX download en arrière-plan** — user peut quitter `/maps/download`, naviguer ailleurs, le job continue (Riverpod controller keepAlive). Progress visible via indicateur discret dans AppBar (badge avec % global) quand un download est actif. Notification persistante Android = nice-to-have deferable (pas requis Phase 07).
- **Progress bar global + bytes** — affiche `"France — 42% (2.1 GB / 5.0 GB)"`. Chunks invisibles à l'utilisateur. Fréquence update : throttled à 200-500 ms pour éviter UI churn.
- **Pause manuelle + reprise auto sur coupure réseau** :
  - Bouton Pause/Reprendre dans l'UI du pays en cours.
  - Coupure réseau → retry auto avec backoff exp (1s / 5s / 30s, max 3 tentatives) sur le chunk courant. Si 3 échecs consécutifs → pause auto + banner "Réseau indisponible, reprise manuelle". HTTP Range support si le serveur GitHub Releases le permet (vérifier en plan — si oui : reprise au byte près ; sinon re-download du chunk entier).
  - Kill app mid-download → staging intact. Au prochain launch, scan des staging/ présents → prompt "Reprendre le download de <pays> ?" + options (Reprendre / Abandonner / Plus tard).
- **Check disk space avant download** — query free space (via package audité, candidats : `disk_space_plus` BSD / Apache, ou API native via platform channel si audit recale tout). Refuse si `free < sizeBytesTotal * 1.1`. Message UX : "Espace insuffisant : besoin de X GB, tu en as Y GB disponibles".
- **Détection d'update** — au startup, compare `catalog.json` bundlé tag vs `installed.json` per-pays `pmtiles_version`. Mismatch → badge orange "Mise à jour disponible" sur le pays dans `/maps/manage` + CTA "Mettre à jour" (re-download même pipeline + atomic replace). Opt-in, pas d'auto-update silencieuse.

### Map screen UX

- **Style visuel Phase 07 = Protomaps basemaps officiel, variante neutre** (light ou white). Fichier source commité dans `assets/maps/style.json`. Le style parchment (`fantasy-parchment-style_v0.json` + `fantasy-parchment.zip` fournis par user) est DEFERRED Phase 13 (cf. §deferred) — même problème glyphs/sprites HTTPS, les assets bundlés locaux seront un concern partagé.
- **Glyphs + sprites bundlés en asset** — le style Protomaps officiel référence `https://protomaps.github.io/basemaps-assets/fonts/...` et `.../sprites/...` qui violeraient "zero network for tiles" (MAP-01 SC#1). Plan : télécharger one-shot les fonts (`.pbf`) + sprite sheet + `sprite.json` vers `assets/maps/glyphs/` + `assets/maps/sprites/`, rewrite du style.json au build-time via `tool/prepare_style.dart` pour pointer `asset:///` ou `file:///` URIs. Audit licence Protomaps basemaps-assets à documenter dans `DEPENDENCIES.md` (CC-BY OSM / BSD — à confirmer). Impact APK ~5-10 MB.
- **Runtime rewrite du `url` placeholder** — le style.json contient `"url": "pmtiles://YOUR_TILES_URL.pmtiles"` placeholder. `PmtilesSource` substitue cette URL par le path du pays courant (ou world) lors de la configuration de la source MapLibre. Substitution côté infrastructure, invisible au layer app.
- **Follow-me toggle** — FAB crosshair bas-droit (pattern Google Maps). Tap pendant pan manuel = réactive + recentre. Défaut ON à l'ouverture de session.
- **Fallback non-installé = world bundle z2 silencieusement + banner informationnel** — si viewport center dans un pays non installé, la source MapLibre reste sur le world.pmtiles (visuel grossier acceptable). Simultanément, banner non-intrusive bas-de-screen : "Carte détaillée de <Pays> disponible dans Paramètres › Télécharger une carte". PAS de CTA navigation (user learns where the feature lives).
- **Attribution OSM + Protomaps** — icon 'i' circular bas-droit ~32dp (opacity ~80%). Tap → overlay/bottom-sheet avec texte complet + 2 liens cliquables externes (openstreetmap.org/copyright + protomaps.com). Conforme MAP-03.

### Country resolver (polygones)

- **Source of truth pour les polygones** : fichiers GeoJSON fournis par l'utilisateur dans `C:\claude_checkouts\countries\data\<alpha3>.geo.json` (les mêmes polygones utilisés pour extraire le PMTiles planet vers les PMTiles par pays — pas de divergence possible).
- **Ship en assets** : Phase 07 bundle les polygones (possiblement simplifiés low-res pour taille raisonnable) dans `assets/maps/polygons/<alpha3>.geo.json` OU un fichier agrégé `assets/maps/polygons.json` (`{alpha3: [polygon]}`). Budget visé : ≤ 5 MB total (simplification via `mapshaper` ou équivalent tool/ one-shot — hors audit, pas runtime). Le plan décide du layout + granularité.
- **Algorithme resolver** :
  - Zoom < 3 → toujours source = world bundle.
  - Zoom ≥ 3 → point-in-polygon du viewport center contre les alpha3 installés (les polygons non-installés ne participent pas au swap mais sont utilisés pour la banner "Télécharger ce pays"). Si match → swap source vers `<alpha3>.pmtiles`. Si aucun match parmi installés mais match dans la liste complète → banner. Sinon → fallback world.
  - Swap au franchissement du centre viewport (pas onMoveEnd). Glitch frontière acceptable.
- **Hot-swap source MapLibre** : PmtilesSource expose 1 seule source nommée `mirkfall_map`. Swap = remove+add source ou update source URL (à confirmer en RESEARCH selon l'API maplibre_gl 0.25.0).

### Installed maps state

- **Manifest filesystem `<app_support>/maps/installed.json`** — PAS de table Drift (pas de migration V3→V4 Phase 07). Structure :
  ```
  {
    "schemaVersion": 1,
    "catalogVersion": "v20260419",
    "installed": {
      "fra": { "installed_at_utc": 1761000000000, "file_size": 5242225731, "pmtiles_version": "v20260419", "sha256": "...", "file_path": "countries/fra.pmtiles" },
      "deu": { ... }
    }
  }
  ```
- **Update = lire + modifier + rewrite atomique** (tempfile + rename). Pas de concurrency write (1 download à la fois = pas de race).
- **First-launch world bundle copy** — check file existence + sha256 verify (auto-heal). Si world.pmtiles absent ou sha256 mismatch → copie depuis `assets/maps/world.pmtiles`. Idempotent. Budget ~1s premier lancement (856 KB copy).

### Fog layer stub + custom lints

- **Interface `MirkRenderer`** dans `lib/domain/mirk/mirk_renderer.dart` (interface Phase 09, placée maintenant pour figer le contrat) — méthodes `paint(Canvas, Size, MirkPaintContext)`, `update(Duration)`, `dispose()`. Ne fuit aucun `ui.Image` ni format intermédiaire.
- **Impl no-op** dans `lib/infrastructure/mirk/noop_mirk_renderer.dart` — paint vide, update vide, dispose vide. Registered as default via Riverpod provider (remplacé en Phase 09 par `AtmosphericMirkRenderer`).
- **Layer déclaratif dans `style.json`** — layer `"id": "mirk_fog"`, placé dans la liste entre POIs et user-location. Phase 07 : `fill-opacity: 0` ou `source` vide, invisible. Phase 09 : tune le layer avec la vraie source fog-of-war (GeoJSON tuilée côté client ou équivalent — MAP-04).
- **Ordre des layers gelé + unit test** — style.json contient la liste [background, landcover, water, boundaries, roads, pois, mirk_fog, user_location] dans cet ordre. Test `test/presentation/map_style_layer_order_test.dart` parse le style.json + asserte l'ordre. Phase 09 peut tuner les layers mais pas les réordonner.
- **Lints custom via tool/ scripts CI-only** — pattern établi (`check_domain_purity.dart`, `check_platform_manifests.dart`) :
  - `tool/check_avoid_maplibre_leak.dart` — scan tous les `.dart` hors `lib/infrastructure/map/` pour `import 'package:maplibre_gl/...'`. Exit 1 si trouvé.
  - `tool/check_avoid_remote_pmtiles.dart` — scan tous les `.dart` pour `pmtiles://http...`. Exit 1 si trouvé.
  - Tests unitaires paired dans `tool/test/` (pattern Phase 02/06).
  - Steps ajoutés à `.github/workflows/ci.yml` job `gates`.
  - Exit codes 0/1/2 (clean/violation/config-error) conforme contrat Phase 01.
- `custom_lint` officiel reste silently degraded — re-évaluation potentielle Phase 15.

### Tests strategy

- **FakeMapView** in-memory state-tracking dans `test/fakes/fake_map_view.dart` — implémente `MapView` domain interface, trace `layersAdded`, `cameraMoves`, `markersAdded`, etc. via getters observables. Injecté via Riverpod override dans widget tests `MapScreen`.
- **MockHTTPServer** via `package:shelf` (dev_dependency, audit licence Apache-2.0 OK) — tests de download interrompu : serveur local qui kill après N bytes ou après N chunks, assert que le controller resume correctement, sha256 réchoue + retry, concat final OK.
- **HTTP interceptor unit test pour airplane-mode** — test qui wrap l'HttpClient global en intercepteur fail-all, fait tourner MapScreen + pan/zoom/country-switch, asserte zero interception. Couvre le subset Phase 07 de QUAL-05 (Phase 15 fera le smoke end-to-end device).
- **Country resolver tests** — fixtures avec 5 pays (FR, DE, ES, UK, US) + polygones simplifiés + 10-20 lat/lon de test :
  - "Paris lat/lon → FR"
  - "Berlin lat/lon → DE"
  - "Frontière FR/DE → pays dominant déterministe"
  - "Mid-Atlantic → null → fallback world"
  - "Zoom < 3 → toujours world"
  - "Pays in polygon mais non-installé → banner CTA correct"

### Amendements upstream documentaires (pré-requis avant plan-phase)

Trois amendements nécessaires — à appliquer avant `/gsd:plan-phase 07` :

1. **ROADMAP.md Phase 07** : Terminologie "ZIPs multi-parts" → "chunks binaires multi-parts". La réalité (confirmée catalog.json fourni) : les parts sont des morceaux binaires bruts (`.partNN`) qui se réassemblent par concat, pas des archives ZIP. Le mot ZIP pollue le plan (pas besoin du package `archive`, pas d'extraction). Impacté : lignes roadmap Phase 07 + Phase 08 + REQUIREMENTS.md MAP-08/09.
2. **PROJECT.md Out of Scope** : Retirer la ligne "Rendu du mirk par session — le choix de style est global à l'app en V1.0". Le user a décidé que **style carte + mirk sont par session**.
3. **REQUIREMENTS.md MIRK-10** : Changer "Le choix du style est global à l'application (pas par session en V1.0)" → "Le choix du style (carte + mirk) est par session". Également reconsidérer MIRK-07/08 pour cohérence (sélection par session dans le menu burger, pas global dans /settings).

Un amendement optionnel supplémentaire : **ROADMAP.md Phase 07 SC#6** mentionne `kMapCatalogUrl` → maintenant `kMapCatalogAssetPath = 'assets/maps/catalog.json'`. Texte du SC à ajuster.

### Claude's Discretion

- Exact layout du burger drawer (spacings, dividers, typo sizes)
- Icon exacte du bouton burger (3 tirets classiques vs icône custom)
- Icon exacte du FAB follow-me (crosshair material vs custom)
- Format exact des read-only lignes lat/long (decimals 6 ? DMS ? toggle ?)
- Format distance walked (km si > 1000 m, m sinon ? unités métriques uniquement V1.0 — I18N V1.x)
- Copy exact français des tooltips + snackbars + banners
- Stratégie de simplification polygones (mapshaper command line, tolerance Douglas-Peucker, budget taille)
- Choix exact du style Protomaps "basemaps" variant (light ou white) — arbitrage visuel au plan
- Layout `/maps/download` list — list simple alphabetic, grouping par continent, search fonctionnement (contains / starts-with / fuzzy)
- Layout `/maps/manage` list — affichage disk space par pays + total cumul
- Exact channel name + ID de la notification persistante download (si elle arrive en Phase 07)
- Mécanique pause/reprendre — 1 bouton toggle ou 2 boutons séparés
- Stratégie de simplification du polygone resolver (point-in-polygon ray casting vs bbox-first + poly-confirm pour perf)
- Asset name convention pour `country polygons` (1 fichier par pays vs 1 fichier agrégé)
- Shape exact de la `MirkRenderer` interface (signature de `paint` — quels args Phase 09 aura besoin)
- Exact `MapView` domain interface signatures (dérivées de MAP-06 : `showMap(region)`, `moveCameraTo(location)`, `markVisited(polygon)`, `getUnvisitedAreas()`, `addLocationMarker(user)`, `addPointOfInterest(poi)`, `setTheme(standard | rpgParchment)` — possibly amended)
- Naming des providers Riverpod (`mapViewProvider`, `countryResolverProvider`, `downloadControllerProvider`, `installedMapsProvider`, …)
- Format du schema `installed.json` (champs optionnels, flags futurs)
- Seuil de retry exacts + backoff (plan du RESEARCH)

</decisions>

<specifics>
## Specific Ideas

- **Fichiers fournis par le user (non commités, à copier dans assets/ Phase 07)** :
  - `C:\claude_checkouts\files_for_mirkfall\catalog.json` → `assets/maps/catalog.json` (source of truth pour le catalog)
  - `C:\claude_checkouts\files_for_mirkfall\world-z2.pmtiles` → `assets/maps/world.pmtiles` (world bundle z2, 856 KB)
  - `C:\claude_checkouts\files_for_mirkfall\fantasy-parchment-style_v0.json` + `fantasy-parchment.zip` → **deferred Phase 13** (même problème glyphs/sprites HTTPS, assets bundlés partageront la solution)
  - `C:\claude_checkouts\countries\data\<alpha3>.geo.json` → source des polygones → `assets/maps/polygons/` après simplification
- **Validation user du style parchment** : `file:///C:/claude_checkouts/GOSL-MirkFall/pmtiles-viewer.html` — outil HTML de prévisualisation qui fonctionne avec les PMTiles locaux. Peut servir de référence pour tester le pipeline end-to-end pendant le dev.
- **GitHub Release hosting** : `github.com/ThongvanAlexis/countries-pmtiles` tag `v20260419` — séparé du repo projet MirkFall (évite pollution du repo projet par les GBs de binaires).
- **France = 4 parts** (3×1.5GB + 1×742MB, total 5.24 GB, single `.pmtiles` reassembled) — cas de test fort pour le soak test.
- **Aruba = 1 part** (4 MB) — cas de test simple/rapide pour le happy-path test.
- **Menu burger mention verbatim user** : "je voudrais que la map prenne tous l'ecran et qu'en haut a gauche il y a un rond avec 3 tirer (menu burger), quand on appui dessus un menu vertical a gauche slide vers la droite".
- **Style per session mention verbatim user** : "ça veut dire que finalement les bouton pour le changement de style ne sont pas dans parametre et donc qu'un style est lié a une session" — confirmation explicite de l'amendement à MIRK-10.
- **Banner "dans Paramètres" verbatim** : "bien indiquer que c'est dans 'parametre'" — user veut durabilité du savoir, pas magie deep-link.
- **Orientation landscape requirement** : "l'utilisateur dois pouvoir passer en mode vertical et horizontal" — premier phase où on cadre l'orientation landscape explicitement. Les écrans Phase 05 étaient tous portrait-first implicitement.
- **UX ouverture session verbatim** : "quand l'utilisateur ouvre une session la carte se positionne sur sa position avec un zoom Z=3, une zone d'un rayon de 20M autour de lui est decouverte (sans mirk/fog)" — Z=3 corrigé à Z=13 après discussion (vue quartier/ville où le 20m est visible). Le 20m reveal est une instruction data-only Phase 07 (Phase 09 peint le fog).

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 01–06)

- **`pubspec.yaml` actuel** : contient `flutter_map: 8.3.0` + `latlong2: 0.9.1` (legacy day-1 pin Phase 01). Phase 07 les **REMPLACE** par `maplibre_gl: 0.25.0` + audit DEPENDENCIES.md (les transitives `dart_earcut`, `mgrs_dart`, `proj4dart`, `wkt_parser`, `simple_sparse_list`, `http`, `xml` actuellement flutter_map-only doivent être réexaminées).
- **`lib/config/constants.dart`** : slot commenté réservé `kHttpTimeout (Phase 07 — tile fetch timeout)`. Phase 07 ajoute `kHttpTimeout = 60000` (download chunks, valeur plus haute que les 30s Phase 05 car chunks de 1.5 GB sur 4G/5G), `kMapCatalogAssetPath = 'assets/maps/catalog.json'`, `kWorldPmtilesAssetPath = 'assets/maps/world.pmtiles'`, `kWorldPmtilesInternalPath` (`maps/world.pmtiles` relative à `<app_support>`), `kCountriesDir`, `kStagingDir`, `kInstalledManifestPath`, `kCountryPolygonsAssetPath`, `kStyleJsonAssetPath`, `kInitialSessionMapZoom = 13`, `kInitialRevealRadiusMeters = 20`, `kDiskSpaceSafetyMarginMultiplier = 1.1`, `kDownloadRetryAttempts = 3`, `kDownloadRetryBaseDelayMs = 1000`.
- **Pattern custom lint via `tool/check_*.dart`** : `tool/check_domain_purity.dart`, `tool/check_headers.dart`, `tool/check_licenses.dart`, `tool/check_dependencies_md.dart`, `tool/check_platform_manifests.dart` — 5 exemples existants avec exit 0/1/2 contract + tests unitaires dans `tool/test/`. Phase 07 ajoute 2 nouveaux (`check_avoid_maplibre_leak.dart`, `check_avoid_remote_pmtiles.dart`) + paired tests + ci.yml steps.
- **`.github/workflows/ci.yml` job `gates`** : déjà structuré avec steps pour les check scripts + `Tool scripts unit tests` + `dart test tool/test/`. Phase 07 ajoute 2 steps + possiblement 1 step mock-server download test.
- **`lib/infrastructure/` sous-directories** : `db/`, `gps/`, `ids/`, `logging/`, `notifications/`, `platform/`, `stores/`. Phase 07 crée `lib/infrastructure/map/` (interdit d'import hors de ce dossier par lint `avoid_maplibre_leak`).
- **`lib/domain/`** : `envelope/`, `errors/`, `fixes/`, `gps/`, `ids/`, `markers/`, `mirk/`, `photos/`, `revealed/`, `sessions/`. Phase 07 ajoute `lib/domain/map/` (interface `MapView` + exceptions) + étend `lib/domain/mirk/` (interface `MirkRenderer` + `MirkPaintContext`).
- **`lib/domain/revealed/revealed_tile_store.dart`** : port existant Phase 03. `computeRevealMask` est `UnimplementedError` (Phase 09). Phase 07 recommandation : NE PAS toucher (reveal initial 20m déferré Phase 09).
- **`lib/domain/mirk/`** : `mirk_style.dart` (Freezed entity), `mirk_style_config.dart` (sealed `AtmosphericConfig | ShaderConfig | UnknownConfig`). Phase 07 ajoute `mirk_renderer.dart` (interface abstract) + `mirk_paint_context.dart` (Freezed).
- **`lib/presentation/screens/`** : existants — `about_placeholder_screen.dart`, `debug_menu_screen.dart`, `oem_guidance_screen.dart`, `permission_denied_screen.dart`, `permission_rationale_screen.dart`, `session_detail_screen.dart`, `session_list_screen.dart`, `settings_screen.dart`. Phase 07 ajoute `map_screen.dart`, `maps_download_screen.dart`, `maps_manage_screen.dart`, `style_import_placeholder_screen.dart`, `style_export_placeholder_screen.dart`. `settings_screen.dart` est étendu avec la section "Cartes" + les 2 boutons import/export style. `session_detail_screen.dart` intègre `MapView` widget quand active/stopped.
- **`lib/presentation/widgets/`** : existants — `active_session_banner.dart`, `app_shell.dart`. Phase 07 ajoute `session_burger_menu.dart` (drawer contenu), `map_follow_me_fab.dart`, `map_attribution_icon.dart`, `map_country_banner.dart` (banner "Télécharger ce pays"), `map_download_progress_chip.dart` (badge AppBar pendant download actif).
- **`lib/presentation/router.dart`** : existing routes `/`, `/sessions/:id`, `/settings`, `/permissions/*`, `/about`, `/debug`. Phase 07 ajoute `/map`, `/maps/download`, `/maps/manage`, `/styles/import`, `/styles/export`. `AppShell` cross-route banner pattern reste inchangé.
- **Fakes test pattern** : `test/fakes/` existe déjà avec `FakeLocationStream`, `FakeSessionStore`, fakes notifications. Phase 07 ajoute `FakeMapView` + `FakePmtilesSource` + `FakeInstalledMapsManifest` + `FakeDownloadController`.
- **`tool/test/`** : 6+ sibling tests pour les check scripts existants. Phase 07 ajoute 2 tests paired.
- **Infra pattern `xxxFilename` / `xxxFileName` / `xxxBasename` / `xxxDir`** (CLAUDE.md) : Phase 07 instrumente heavily (staging path, country path, world path, manifest path).
- **`lib/infrastructure/logging/file_logger.dart`** : `Logger('infrastructure.map')`, `Logger('infrastructure.pmtiles')`, `Logger('application.downloads')` à instancier Phase 07. Pattern `logger.info/warn/severe` existants.

### Established Patterns

- **CLAUDE.md rules** (confirmés 6 phases) — singulier/pluriel nomming, `p.join()`, pas de magic numbers hors constants.dart, sealed classes + pattern match, DI via constructeur + Riverpod, types stricts, `dart format`, `flutter analyze` zero warning, timeouts obligatoires, pin exact deps + audit DEPENDENCIES.md.
- **Test runner split** : `dart test` pour pure Dart + Drift in-memory, `flutter test` pour widget tests. Phase 07 tests grosso modo répartis ainsi (infra map + pmtiles source + country resolver + manifest = plain dart ; screens + FakeMapView widget = flutter test).
- **4-parallel sub-agent audit pattern (review gates)** validé 3 cycles (Phase 02/04/06) — à reconduire Phase 08 review gate.
- **Batched fix loop Strategy B** (Phase 04/06 review gates) — pattern validé pour les review gates longs.
- **Adversarial Option B** (poison + on.push.branches expansion sur throwaway branch) — validé 3 cycles, à reconduire Phase 08.
- **Inertness-guard idiom** dans les permanent regression-guard unit tests (Phase 02/04/06) — pattern locked pour Phases 08+.
- **Atomic commits par tâche** : `feat(07-XX): ...`, `test(07-XX): ...`, `docs(07-XX): ...`.
- **Layer READMEs** : si Phase 07 crée `lib/infrastructure/map/`, `lib/domain/map/`, ajouter des READMEs courts (règles import inter-layers + pointeur vers lint `avoid_maplibre_leak`).
- **`@Assert` invariants Freezed** : pour les entities Phase 07 (ex: `InstalledCountry` si on choisit une Freezed entity, `DownloadProgress`).
- **Extension type IDs** : probablement pas nécessaire Phase 07 (alpha3 strings sont assez étroits). Éventuellement `CountryCode(String value)` extension type si le plan le juge utile.
- **Exceptions domain `implements Exception`** : ajouter `MapAssetMissingException`, `PmtilesCorruptException`, `CountryNotInstalledException`, `DownloadInterruptedException`, `SchemaValidationException` (catalog), `DiskSpaceInsufficientException`.

### Integration Points

- **`pubspec.yaml`** : retirer `flutter_map: 8.3.0`, `latlong2: 0.9.1`. Ajouter `maplibre_gl: 0.25.0`. Ajouter dev_dependency `shelf: <version>` pour MockHTTPServer tests (audit Apache-2.0). Possiblement `disk_space_plus` ou équivalent pour free-space check (audit obligatoire). `archive` NON nécessaire (chunks binaires, pas ZIP). Bump `pubspec.lock` atomique au début de Phase 07 plan 01.
- **`DEPENDENCIES.md`** : audit entries pour `maplibre_gl` + transitives (dropping flutter_map transitives) + `shelf` (dev) + disk-space package + Protomaps basemaps-assets (glyphs/sprites, hébergement licence CC-BY ou autre — à confirmer research).
- **`lib/main.dart`** : zero structural modification (wiring Riverpod lazy reste pattern Phase 05).
- **`lib/presentation/router.dart`** : ajouter routes `/map`, `/maps/download`, `/maps/manage`, `/styles/import`, `/styles/export`. Respect rule existante : routes qu'on push/go déterministique selon pattern `context.push`/`context.go`.
- **`lib/presentation/screens/settings_screen.dart`** : extend avec section "Cartes" + section "Styles" (import/export placeholder).
- **`lib/presentation/screens/session_detail_screen.dart`** : intégrer widget `MapView` — remplace / augmente le dashboard texte actuel. Burger menu overlay.
- **`lib/domain/map/`** (nouveau sous-arbre) : `map_view.dart` (interface), `country_code.dart` (optionnel extension type), `map_errors.dart` (sealed exceptions), `country_catalog.dart` (Freezed entité + parsing).
- **`lib/domain/mirk/`** (étendu) : `mirk_renderer.dart` (interface), `mirk_paint_context.dart` (Freezed DTO).
- **`lib/domain/downloads/`** (nouveau) : `download_job.dart`, `download_state.dart` (sealed : Idle / Downloading / Paused / Error / Completed / Cancelled), `download_errors.dart`.
- **`lib/domain/installed_maps/`** (nouveau) : `installed_country.dart` (Freezed), `installed_manifest.dart` (Freezed + parsing + validation).
- **`lib/infrastructure/map/`** (nouveau — seul dossier autorisé pour `maplibre_gl` imports) : `maplibre_map_view.dart` (adapter concret de `MapView`), `pmtiles_source.dart` (seam local-only), `style_rewriter.dart` (runtime substitution `pmtiles://YOUR_TILES_URL.pmtiles` → `pmtiles:///<path>`), `layer_order_guard.dart` (validation runtime du z-order), `country_resolver.dart` (viewport center → alpha3 + swap decision).
- **`lib/infrastructure/downloads/`** (nouveau) : `pmtiles_download_controller.dart` (Riverpod), `http_chunk_downloader.dart` (dart:io HttpClient + Range), `sha256_verifier.dart`, `binary_concatenator.dart`, `atomic_renamer.dart`, `disk_space_checker.dart`.
- **`lib/infrastructure/installed_maps/`** (nouveau) : `installed_manifest_repository.dart` (read/write `<app_support>/maps/installed.json`), `first_launch_world_copier.dart` (asset→app_support).
- **`lib/application/controllers/`** (existant, étendu) : `active_session_controller.dart` Phase 05 — inchangé (Phase 07 NE touche PAS à Phase 05). Ajouter `map_camera_controller.dart`, `country_resolver_controller.dart`, `download_queue_controller.dart`, `installed_maps_controller.dart`.
- **`lib/application/providers/`** : ajouter providers `@riverpod keepAlive: true` correspondants aux controllers + `mapViewProvider`, `countryCatalogProvider`, `installedManifestProvider`, `styleJsonProvider`.
- **`assets/maps/`** (nouveau) : `world.pmtiles` (856 KB), `catalog.json` (132 KB), `style.json` (Protomaps basemaps neutral, rewritten), `polygons/<alpha3>.geo.json` (ou agrégé, décision plan), `glyphs/<fontstack>/<range>.pbf`, `sprites/sprite.json` + `sprite.png` / `sprite@2x.png`.
- **`pubspec.yaml` `flutter.assets`** : ajouter `assets/maps/` (récursif).
- **`tool/`** : ajouter `tool/check_avoid_maplibre_leak.dart`, `tool/check_avoid_remote_pmtiles.dart`, `tool/prepare_style.dart` (build-time rewrite), possiblement `tool/simplify_polygons.dart` (one-shot simplification polygons). Tests paired dans `tool/test/`.
- **`.github/workflows/ci.yml`** : 2 nouveaux steps pour les lints + possiblement un step `dart test` spécifique pour les tests download (MockHTTPServer) — évaluer si le test suite gates default les couvre déjà.
- **`android/app/src/main/AndroidManifest.xml`** : ajouter permission `INTERNET` (pour les downloads ; GPS, notifications déjà Phase 05). Si notification persistante download, éventuellement ajouter un channel (décision plan).
- **`ios/Runner/Info.plist`** : `NSAppTransportSecurity` pas nécessaire (GitHub HTTPS par défaut OK), pas de nouvelle UsageDescription (les téléchargements ne demandent pas de permission iOS). Double-check ATS exceptions si le serveur GitHub Releases n'utilise pas TLS 1.2+ (il le fait).
- **`test/`** : nouveaux sous-arbres `test/domain/map/`, `test/domain/downloads/`, `test/domain/installed_maps/`, `test/infrastructure/map/`, `test/infrastructure/downloads/`, `test/infrastructure/installed_maps/`, `test/application/controllers/map_*_test.dart`, `test/presentation/screens/map_screen_test.dart`, `test/presentation/screens/maps_download_screen_test.dart`, `test/presentation/screens/maps_manage_screen_test.dart`, `test/presentation/widgets/session_burger_menu_test.dart`, `test/presentation/map_style_layer_order_test.dart` (parse style.json + assert order).
- **`test/fakes/`** : `fake_map_view.dart`, `fake_pmtiles_source.dart`, `fake_installed_manifest_repository.dart`, `fake_download_controller.dart`, `fake_country_resolver.dart`.
- **`test/fixtures/`** : `test/fixtures/catalogs/mini_catalog.json` (5 pays FR/DE/ES/UK/US), `test/fixtures/polygons/<alpha3>.geo.json` simplifiés, `test/fixtures/pmtiles/tiny.pmtiles` (stub 1 KB — just valid header).

</code_context>

<deferred>
## Deferred Ideas

- **Style parchment "fantasy" fourni par user** (`fantasy-parchment.zip` + `fantasy-parchment-style_v0.json`) → **Phase 13** (OPT-03/04 — sélecteur de style + import). Même problème glyphs/sprites HTTPS que le style Protomaps neutre, qui sera résolu en bundling des assets en Phase 07 ; la transition parchment bénéficiera de cette infrastructure. User a validé le style localement via `pmtiles-viewer.html`.
- **Boutons "take picture" + "place marker" câblés** → **Phase 11** (MARK-01, MARK-05). Phase 07 ship les ListTile unwired avec snackbar/dialog "Disponible Phase 11".
- **Boutons "import / export style" câblés** → **Phase 13** (MIRK-08, PORT-08). Phase 07 ship les ListTile + routes placeholder.
- **Génération systématique des ~200 pays PMTiles (tool/ + Protomaps CLI)** → pas nécessaire Phase 07 (les PMTiles sont déjà pré-générés et hébergés par le user sur le GitHub Release). Automation de régénération différée post-V1.0 ou maintenance ad-hoc.
- **Sub-divisions régionales (ISO 3166-2)** → out of scope V1.0. Si un pays est trop gros pour un seul download UX (ex. USA, Russia, China), traitement futur avec sub-regions. V1.0 reste au pays entier (chunks multi-parts gèrent les gros pays).
- **Reveal initial 20m au session open — Phase 07 skip, Phase 09 livre** → Phase 07 capture l'intent UX mais n'implémente pas le `mergeMask` + `computeRevealMask` (UnimplementedError Phase 03). Phase 09 finalise le reveal streaming + rattrape le reveal initial sur le premier fix.
- **Notification persistante pendant download** (Android) → deferable Phase 15 polish. Phase 07 ship un badge AppBar indiquant qu'un download est en cours, suffisant pour la UX de base.
- **HTTP Range granulaire au byte près** → si GitHub Releases ne supporte pas Range, Phase 07 fait re-download du chunk entier sur échec. Optim au byte près deferable si pain point POC.
- **Country resolver avec polygone précis point-in-polygon** → Phase 07 ship le ray casting simple ; optim bbox-first + poly-confirm deferable si perf pain point.
- **Update auto-check au startup** → Phase 07 utilise la comparaison `catalog bundlé vs installed.json` au premier accès `/maps/manage`. Phase 15 pourra pousser un badge persistant plus agressif si nécessaire.
- **Multi-language (FR/EN)** → V1.x (I18N-*). Phase 07 ship en FR uniquement.
- **`tool/update_catalog.dart`** (automation maintenance du catalog + upload GitHub Release) → deferable post-V1.0 ou maintenance manuelle.
- **Test airplane-mode device end-to-end (QUAL-05)** → Phase 15 polish. Phase 07 unit test HTTP interceptor couvre le subset.
- **iOS Dynamic Island pour download progress** → nice-to-have, probablement jamais (pattern déjà discuté Phase 05 deferred Dynamic Island session).
- **Storage quota UI global (total map storage)** → Phase 07 montre per-country + total cumul, pas de graph / tendance. Ajouts Phase 15 polish éventuels.
- **Onboarding tutorial pour first download** → Phase 15 polish.
- **Complétude du style (rivières, POIs riches, bâtiments, labels de rue, relief/altitude)** → **V1.x (phase dédiée à créer)**. Le style livré Phase 07 est intentionnellement minimal (8 couches : background, landcover, water (polygones uniquement), boundaries, roads, pois basique, mirk_fog, user_location). Amendement post-device-smoke 2026-04-21 (commit `7425c37`) : la couche `water` filtre désormais `geometry-type in [Polygon, MultiPolygon]` parce que le source-layer `water` de Protomaps contient aussi des LineString (rivières), que MapLibre peignait en wedges bleus dégénérés quand on laissait un `type: fill` sans filtre. **Résultat : les rivières-en-ligne sont donc actuellement invisibles**. Par ailleurs `fill-antialias: false` a été ajouté sur `water` pour éliminer les coutures blanches fines aux bordures de tuiles. Les fonctionnalités suivantes sont volontairement hors-scope Phase 07 et devront être ajoutées par une phase future consacrée à la richesse du rendu :
  - couche dédiée `rivers` (`type: line`, filtrée sur le sous-ensemble LineString du source-layer `water` avec le `kind`/`class` approprié selon le schéma Protomaps basemaps)
  - couche `buildings` (fill + éventuellement fill-extrusion pour la 3D selon décision UX)
  - enrichissement des POIs (catégories multiples, icons contextuels, minzoom par catégorie — la couche actuelle est une symbol monolithique `dot` à partir de zoom 12)
  - labels de rues (symbol sur `roads` avec `text-field` + collision detection)
  - relief / hillshade / contours (nécessite une source raster ou un source-layer dédié — probablement un autre PMTiles que celui actuellement bundlé)
  - landcover enrichi (forêt, prairie, urbain — les différents `kind` du source-layer au lieu d'un unique fill beige)
  Lors de l'ajout, respecter l'ordre de couches gelé (Phase 07 : background → landcover → water → boundaries → roads → pois → mirk_fog → user_location ; test de régression `test/presentation/map_style_layer_order_test.dart` à mettre à jour en même temps que `lib/infrastructure/map/style_layer_order.dart`). Attention aussi : le schéma exact des source-layers Protomaps basemaps (noms de propriétés `kind`, `class`, `pmap:kind`) doit être vérifié contre la version PMTiles effectivement bundlée avant de définir les filtres — les schémas ont changé entre les versions Protomaps basemaps.

</deferred>

---

*Phase: 07-map-integration*
*Context gathered: 2026-04-20*
