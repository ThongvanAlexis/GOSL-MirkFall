# Requirements: MirkFall

**Defined:** 2026-04-17
**Core Value:** Ne jamais perdre sa progression — import/export JSON versionné durable entre instances.

## v1 Requirements

Requirements pour release initiale V1.0. Chaque REQ est mappé à exactement une phase du roadmap.

### Foundation (FOUND)

<!-- Guardrails Day-1 — non-négociables, tout le reste en dépend. -->

- [x] **FOUND-01**: Repo Flutter initialisé avec `analysis_options.yaml` strict (`strict-casts`, `strict-inference`, `strict-raw-types`)
- [x] **FOUND-02**: Chaque fichier source contient le header de licence GOSL v1.0 obligatoire
- [x] **FOUND-03**: `DEPENDENCIES.md` à la racine, tenu à jour (licence + audit télémétrie par dépendance)
- [x] **FOUND-04**: Pipeline GitHub Actions CI construit un APK Android (ubuntu-latest) et un build iOS non-signé (macos-latest) sur chaque push
- [x] **FOUND-05**: Versions des dépendances `pubspec.yaml` strictement pinnées (pas de `^`, pas de `~`)
- [x] **FOUND-06**: Logger configurable via `--dart-define=DEBUG=true` et menu debug in-app ; logs écrits dans `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt`
- [x] **FOUND-07**: Constantes partagées (rayon défaut, timeouts, tailles limites) centralisées dans `lib/config/constants.dart`
- [x] **FOUND-08**: `flutter analyze` passe avec zéro warning ; `dart format` appliqué partout

### Sessions (SESS)

- [x] **SESS-01**: Utilisateur peut créer une session avec un nom
- [x] **SESS-02**: Utilisateur peut renommer une session existante
- [x] **SESS-03**: Utilisateur peut supprimer une session (avec confirmation)
- [x] **SESS-04**: Utilisateur peut démarrer (Start) une session
- [x] **SESS-05**: Utilisateur peut arrêter (Stop) une session active
- [x] **SESS-06**: Démarrer une session arrête automatiquement toute autre session en cours (exclusivité enforcée au niveau DB)
- [x] **SESS-07**: L'état d'une session (mirk révélé, markers, métadonnées) est persisté localement en continu
- [x] **SESS-08**: Utilisateur peut voir la liste de toutes ses sessions avec leur état (active / arrêtée)
- [x] **SESS-09**: Utilisateur peut créer un nombre illimité de sessions

### GPS / Tracking (GPS)

- [x] **GPS-01**: L'app demande la permission de localisation "Always" à la première session démarrée, avec écran d'explication préalable (pre-prompt rationale)
- [x] **GPS-02**: Une session active tracke la position utilisateur en temps réel (foreground)
- [x] **GPS-03**: Une session active continue à tracker en arrière-plan (app backgroundée, écran éteint) — Android foreground service + iOS background location
- [x] **GPS-04**: Une notification persistante signale qu'une session est en cours (Android foreground service notification + équivalent iOS)
- [x] **GPS-05**: Tracking respecte un `distanceFilter` configurable pour limiter la consommation batterie (pas de poll 1 Hz en stationnaire)
- [x] **GPS-06**: Si l'app est killée par l'OS en background, le tracking reprend automatiquement au redémarrage de la session
- [x] **GPS-07**: Écran dédié "Permissions" qui explique pourquoi MirkFall a besoin de la localisation et guide vers les paramètres système si permission refusée
- [x] **GPS-08**: Documentation utilisateur intégrée mentionnant les contraintes OEM Android (Xiaomi/Huawei/Samsung/OnePlus background killers) avec liens `dontkillmyapp.com`

### Mirk (MIRK)

- [ ] **MIRK-01**: Un rayon de révélation circulaire est effacé autour de la position actuelle au fil du déplacement
- [ ] **MIRK-02**: Le rayon de révélation est configurable dans les options globales (défaut à fixer en Phase Fog, proposition 25-50 m)
- [x] **MIRK-03**: Le mirk effacé reste effacé pour toute la durée de vie de la session (pas de re-brumage)
- [ ] **MIRK-04**: Le mirk a un rendu vivant / atmosphérique (nuageux, mouvant, animé) — pas un simple aplat noir
- [ ] **MIRK-05**: L'architecture de rendu expose une interface `MirkRenderer` abstraite : ajouter un style ne demande qu'un nouveau fichier, zéro modification du cœur
- [ ] **MIRK-06**: L'app fournit au moins un style de mirk par défaut (atmosphérique)
- [ ] **MIRK-07**: Un sélecteur dans le menu in-session (burger menu Phase 07) permet de choisir le style de mirk actif **pour la session courante** parmi les styles installés ; le changement s'applique immédiatement à la carte
- [ ] **MIRK-08**: Utilisateur peut importer un style de mirk depuis un fichier JSON (format versionné)
- [ ] **MIRK-09**: Utilisateur peut supprimer un style de mirk importé
- [ ] **MIRK-10**: Le choix du style (carte + mirk) est **par session** — chaque session mémorise son style carte + mirk actif ; l'écran options global (OPT-03) fixe seulement le défaut appliqué aux nouvelles sessions (amendé 2026-04-20 Phase 07 CONTEXT)

### Map (MAP)

<!-- Pivot 2026-04-19 : cartographie 100 % offline. Abandon du modèle PMTiles hébergé sur bucket object-storage (coûts + streaming). Remplacé par : bundle world low-zoom dans l'APK + téléchargement par pays depuis un GitHub Release externe (chunks binaires multi-parts). Aucune requête réseau pour les tuiles — jamais, ni en dev ni en prod. Les anciens OFFL-01..04 v2 sont absorbés dans cette section. Amendement 2026-04-20 Phase 07 CONTEXT : catalog JSON bundlé en asset (pas fetch remote), chunks binaires bruts (pas ZIPs) réassemblés par concat binaire. -->

- [x] **MAP-01**: La carte s'affiche sur un fond vectoriel PMTiles (données Protomaps dérivées d'OSM) **100 % local** — fichier `.pmtiles` sur le disque de l'appareil, consommé via une URI `pmtiles:///<path>` par `maplibre_gl`. Aucune requête réseau de tuiles, jamais, ni en dev ni en prod. Mode airplane = carte pleinement fonctionnelle sur la zone couverte par les fichiers installés.
- [x] **MAP-02**: La carte reste interactive (pan, zoom) sous le mirk.
- [x] **MAP-03**: Attribution `© OpenStreetMap contributors` + `© Protomaps` visible sur la carte et dans l'écran À propos, avec liens vers les pages de copyright officielles ; conforme aux licences amont (les données PMTiles dérivent d'OSM via Protomaps, l'attribution reste requise même hors ligne).
- [x] **MAP-04**: L'overlay mirk s'intègre au rendu vectoriel MapLibre comme un layer natif (source GeoJSON tuilée côté client ou équivalent), avec RepaintBoundary / isolation de rebuild, sans référencer directement le SDK MapLibre depuis la couche app.
- [x] **MAP-05**: Le chemin de données des tuiles est derrière un `PmtilesSource` minimal qui expose **uniquement** des URI locales (`pmtiles:///<path>`). Aucune implémentation "hosted / remote" n'existe dans le code — un lint custom `avoid_remote_pmtiles` interdit tout `pmtiles://https?://...`. Un country resolver sélectionne le bon fichier selon la zone affichée (fallback world bundle si le pays visualisé n'est pas téléchargé). Validé par mock test. _(Plan 07-01 scaffolding landed: lint gate live, PmtilesSource impl pending Plan 07-03.)_
- [x] **MAP-06**: L'app code (controllers, screens, services) ne dépend que d'une interface `MapView` **domain-level** exprimée dans le vocabulaire MirkFall : `showMap(region)`, `moveCameraTo(location)`, `markVisited(polygon)`, `getUnvisitedAreas()`, `addLocationMarker(user)`, `addPointOfInterest(poi)`, `setTheme(standard | rpgParchment)`. Les types du SDK (`MapLibreMapController`, `SymbolOptions`, `CameraUpdate`, le schéma du `style.json`) **ne remontent jamais** au-dessus de `lib/infrastructure/map/`. Règle d'odeur : toute méthode dont la signature révèle un type MapLibre est disqualifiée (interdiction mécanique via lint custom `avoid_maplibre_leak`). Validé par un `FakeMapView` qui implémente l'interface en mémoire et par lequel passent tous les tests Phase 07+ qui touchent à la carte. _(Plan 07-01 scaffolding landed: lint gate live + FakeMapView shell forward-declared, MapView interface pending Plan 07-02.)_
- [x] **MAP-07**: Un world map PMTiles low-zoom (zoom 0-5, fichier fourni par l'utilisateur) est **bundlé dans l'APK/IPA** sous `assets/maps/world.pmtiles` et copié vers `<app_support>/maps/world.pmtiles` au premier lancement. Day-1 UX : l'utilisateur voit une carte monde dès l'ouverture de l'app, sans aucun téléchargement requis. Ce fichier ne peut pas être supprimé par l'utilisateur (hardcoded floor). _(Plan 07-01 scaffolding landed: asset bundled + kWorldBundleSha256 emitted, first-launch copier pending Plan 07-03.)_
- [x] **MAP-08**: Un écran "Télécharger une carte" (accessible depuis l'écran options + depuis une bannière carte quand l'utilisateur navigue sur un pays non téléchargé) liste les pays disponibles à partir d'un catalogue JSON **bundlé en asset** (`assets/maps/catalog.json`, lu via `kMapCatalogAssetPath` dans `lib/config/constants.dart` ; update = rebuild app). Chaque entrée du catalogue déclare : `alpha3` (ISO 3166-1 alpha-3), `name` (display), `parts[]` (ordonnés, chacun `{sha256, size, url}` — chunks binaires bruts de 1.5 GB max hébergés sur GitHub Release externe `ThongvanAlexis/countries-pmtiles` pour contourner la limite 2 GB/asset), et `reassembled {sha256, size}` (hash + taille du `.pmtiles` final après concat). La version globale = tag du GitHub Release (ex `v20260419`). (amendé 2026-04-20 Phase 07 CONTEXT) _(Plan 07-01 scaffolding landed: catalog bundled + mini_catalog schema fixture, CountryCatalog Freezed entity pending Plan 07-02, download screen pending Plan 07-06.)_
- [x] **MAP-09**: Le téléchargement d'un pays suit un protocole atomique : (1) download séquentiel des N **chunks binaires** (`.partNN`) vers `<app_support>/maps/staging/<alpha3>/`, (2) vérification `sha256` par chunk contre la valeur déclarée dans le catalog, (3) **concaténation binaire** (pas d'extraction d'archive — les chunks sont des morceaux binaires bruts du fichier `.pmtiles` final) vers un `.pmtiles` reconstitué en staging, (4) vérification `sha256` global contre `reassembled.sha256`, (5) commit atomique par rename vers `<app_support>/maps/countries/<alpha3>.pmtiles` + update du manifest `<app_support>/maps/installed.json`. Interruption à n'importe quelle étape laisse le pays **soit absent soit complet** — jamais partiellement installé. Téléchargements interrompus reprennent au chunk échoué (HTTP Range si le serveur supporte, sinon re-download du chunk seul — pas redownload total). Staging nettoyé en cas d'abandon explicite par l'utilisateur. (amendé 2026-04-20 Phase 07 CONTEXT) _(Plan 07-01 scaffolding landed: chunk recipe README + sha256 pipeline ready, atomic pipeline impl pending Plan 07-04.)_
- [x] **MAP-10**: Écran de gestion des cartes : liste les pays installés avec leur espace disque consommé et leur `pmtilesVersion` ; l'utilisateur peut supprimer un pays (libère l'espace, le pays redeviendra téléchargeable) ; le world bundle est présent en lecture seule et ne peut pas être supprimé. Affichage de l'espace disque total utilisé par les cartes.

### Markers (MARK)

- [ ] **MARK-01**: Utilisateur peut créer un marker à une position donnée (tap long sur la carte ou bouton "+")
- [ ] **MARK-02**: Un marker contient : position lat/lon, titre, texte libre (description/notes), 0..n photos, une catégorie avec icône
- [ ] **MARK-03**: Utilisateur peut modifier un marker existant (tous les champs sauf position, ou position éditable aussi — à préciser en plan phase)
- [ ] **MARK-04**: Utilisateur peut supprimer un marker (avec confirmation)
- [ ] **MARK-05**: Utilisateur peut ajouter des photos à un marker depuis la caméra ou la galerie
- [ ] **MARK-06**: Photos attachées aux markers sont downscalées avant stockage (taille raisonnable, pas full camera resolution)
- [ ] **MARK-07**: Markers sont visibles sur la carte en transparence même dans les zones encore sous mirk (use-case "liste de lieux à visiter pré-importée")
- [ ] **MARK-08**: Tap sur un marker ouvre une fiche détaillée (titre, texte, galerie photos)
- [ ] **MARK-09**: Utilisateur peut lister tous les markers d'une session depuis un écran dédié
- [ ] **MARK-10**: Suppression d'un marker supprime proprement les photos associées (pas d'orphelin)

### Catégories / Icônes (CAT)

- [ ] **CAT-01**: L'app fournit un jeu de catégories / icônes par défaut (style RPG : maison, trésor, donjon, auberge, etc.)
- [ ] **CAT-02**: Utilisateur peut créer une catégorie custom avec nom et icône
- [ ] **CAT-03**: Utilisateur peut modifier une catégorie (nom et/ou icône)
- [ ] **CAT-04**: Utilisateur peut supprimer une catégorie (markers utilisant cette catégorie sont reassignés à une "default" — à préciser en plan phase)
- [ ] **CAT-05**: Interface `MarkerIconPack` abstraite en place dès V1.0 — permet d'ajouter des packs d'icônes complets plus tard sans modifier le cœur
- [ ] **CAT-06**: Icônes des markers affichés sur la carte ont un style visuel RPG (bannière, pin stylisé, pas un marker Material Design générique)

### Import / Export (PORT) — core value

- [ ] **PORT-01**: Format JSON d'échange versionné (champ `schemaVersion` en tête de document)
- [ ] **PORT-02**: Schéma JSON lisible à la main (pas de blob binaire injustifié)
- [ ] **PORT-03**: Utilisateur peut exporter une session individuelle au format JSON (incluant mirk révélé, markers, catégories, photos)
- [ ] **PORT-04**: Utilisateur peut exporter toutes les sessions en une seule opération (archive unique)
- [ ] **PORT-05**: Export bundle les photos avec leurs références (ZIP contenant JSON + dossier photos/ — format à confirmer au début de la phase import/export)
- [ ] **PORT-06**: Utilisateur peut importer un fichier JSON de session(s) exporté depuis n'importe quelle instance de l'app
- [ ] **PORT-07**: Utilisateur peut importer un fichier JSON de markers seuls (pré-peupler une session avec une liste de lieux à visiter)
- [ ] **PORT-08**: Utilisateur peut importer un fichier JSON de style de mirk (voir MIRK-08)
- [ ] **PORT-09**: Import de session est transactionnel : tout ou rien, pas d'état incohérent en cas d'erreur
- [ ] **PORT-10**: UI de prévisualisation avant import : ce qui va être importé, collisions éventuelles avec des sessions existantes
- [ ] **PORT-11**: Export vérifie l'intégrité round-trip avant de déclarer succès (relire le fichier écrit et confirmer que tout est bien là)
- [ ] **PORT-12**: Document `SCHEMA.md` à la racine du repo documente le format JSON pour chaque version supportée
- [ ] **PORT-13**: Matrice de tests cross-version : import d'un fichier V1.0 dans une instance future doit être garanti

### Options / Settings (OPT)

- [ ] **OPT-01**: Écran d'options global accessible depuis l'écran principal
- [ ] **OPT-02**: Option : rayon de révélation du mirk (slider ou input avec valeur défaut)
- [ ] **OPT-03**: Option : style de mirk **par défaut pour nouvelles sessions** (sélecteur parmi les styles installés) — chaque session peut override via le menu in-session (MIRK-07) ; amendé 2026-04-20 Phase 07 CONTEXT
- [ ] **OPT-04**: Écran : gestion des styles de mirk importés (liste + suppression)
- [ ] **OPT-05**: Écran : gestion des catégories de markers (CRUD)
- [ ] **OPT-06**: Écran : import / export global (déclenche les flows PORT-*)
- [ ] **OPT-07**: Écran : activation manuelle du logger debug (pour les builds sans `--dart-define=DEBUG`)

### About / Legal (ABOUT)

- [ ] **ABOUT-01**: Écran "À propos" accessible depuis les options
- [ ] **ABOUT-02**: Mention "MirkFall is distributed under GOSL v1.0" visible dans l'écran À propos
- [ ] **ABOUT-03**: Lien vers le texte complet de la licence GOSL (fichier embarqué dans l'app)
- [ ] **ABOUT-04**: Liste des dépendances tierces utilisées avec leurs licences respectives
- [ ] **ABOUT-05**: Lien vers le repo GitHub du projet

### Quality / Release (QUAL)

- [x] **QUAL-01**: POC validation du tracking background sur device Android OEM (Xiaomi ou Samsung) avec session ≥ 30 min écran éteint
- [x] **QUAL-02**: POC validation du tracking background sur device iOS (via CI + sideload) avec session ≥ 30 min écran éteint
- [x] **QUAL-03**: Argumentaire pour revue App Store / Play Store documenté (justification background location)
- [x] **QUAL-04**: `Info.plist` iOS contient toutes les `*UsageDescription` requises (location, camera, photo library) au fur et à mesure des ajouts
- [ ] **QUAL-05**: Aucune dépendance identifiée faisant des appels réseau sans action utilisateur explicite (confirmé par inspection source + test smoke "airplane mode = zéro requête sortante")

## v2 Requirements

Différé à V1.1+, non couvert par la V1.0. Architecture V1.0 prépare ces extensions (interfaces déjà en place) mais code n'est pas livré.

<!-- Les anciens OFFL-01..04 (offline tiles) ont été promus en V1.0 lors du pivot 2026-04-19 et sont désormais couverts par MAP-07..10. Plus de section "Offline tiles" en v2. -->

### Observabilité / Stats

- **STAT-01**: Distance totale parcourue par session
- **STAT-02**: Pourcentage de la ville / région révélée
- **STAT-03**: Nombre de markers par catégorie

### Internationalisation

- **I18N-01**: Sélecteur de langue dans les options
- **I18N-02**: Sélecteur d'unités de mesure (métrique / impérial)

<!-- Section "Mirk par session" retirée 2026-04-20 Phase 07 CONTEXT : MIRK2-01 absorbé dans V1 via amendement de MIRK-10 (le choix du style carte + mirk est désormais par session en V1.0). -->

## Out of Scope

Explicitement exclus de la V1.0 et au-delà, sauf décision explicite de l'utilisateur.

| Feature | Reason |
|---------|--------|
| Synchronisation cloud / multi-appareils | Contraire au design local-first ; la portabilité se fait via import/export JSON manuel (c'est le trait différenciant) |
| Partage de session entre utilisateurs en temps réel | Hors cadre projet personnel |
| Mode multijoueur / sessions partagées | Hors cadre projet personnel |
| Achievements / gamification / badges | Pas dans l'esprit du projet (pas de retention tricks) |
| Re-brumage temporel | Contraire au design (le territoire exploré reste exploré) |
| Intégrations tierces (Strava, Google Photos, etc.) | Viole les principes GOSL (télémétrie, SDK tiers embarqués) |
| Comptes utilisateur / login | Pas nécessaire en local-first ; tout est anonyme sur l'appareil |
| Analytics, crash reporting automatique, télémétrie | Interdit par GOSL v1.0 + CLAUDE.md du projet |
| Achats in-app, abonnement, publicités | Interdit par GOSL v1.0 |
| Publication sur App Store / Play Store (distribution officielle) | Pas de compte Apple Developer payant ; distribution via GitHub Releases + sideload |
| Heatmaps de fréquentation type Strava | Différenciation volontaire : MirkFall raconte TON exploration, pas une carte aggregée |
| Plugins de chat / social / commentaires | Hors cadre |

## Traceability

Mapping requirement → phase. Chaque REQ v1 est mappé à exactement une phase de **code** (phases impaires 01-15). Les Review Gates (phases paires 02-16) vérifient les REQ de la phase de code précédente mais ne les possèdent pas.

**Note :** le compte total précédemment documenté à "77" dans l'en-tête original est une erreur arithmétique. Après les deux révisions successives de la section MAP (MAP-06 ajouté 2026-04-19 pour l'abstraction `MapView` ; MAP-07..10 ajoutés 2026-04-19 lors du pivot offline-only), la somme réelle est **91** v1 requirements (FOUND:8 + SESS:9 + GPS:8 + MIRK:10 + MAP:10 + MARK:10 + CAT:6 + PORT:13 + OPT:7 + ABOUT:5 + QUAL:5 = 91).

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 01 | Complete |
| FOUND-02 | Phase 01 | Complete |
| FOUND-03 | Phase 01 | Complete |
| FOUND-04 | Phase 01 | Complete |
| FOUND-05 | Phase 01 | Complete |
| FOUND-06 | Phase 01 | Complete |
| FOUND-07 | Phase 01 | Complete |
| FOUND-08 | Phase 01 | Complete |
| SESS-01 | Phase 05 | Complete |
| SESS-02 | Phase 05 | Complete |
| SESS-03 | Phase 05 | Complete |
| SESS-04 | Phase 05 | Complete |
| SESS-05 | Phase 05 | Complete |
| SESS-06 | Phase 03 | Complete |
| SESS-07 | Phase 05 | Complete |
| SESS-08 | Phase 05 | Complete |
| SESS-09 | Phase 05 | Complete |
| GPS-01 | Phase 05 | Complete |
| GPS-02 | Phase 05 | Complete |
| GPS-03 | Phase 05 | Complete |
| GPS-04 | Phase 05 | Complete |
| GPS-05 | Phase 05 | Complete |
| GPS-06 | Phase 05 | Complete |
| GPS-07 | Phase 05 | Complete |
| GPS-08 | Phase 05 | Complete |
| MIRK-01 | Phase 09 | Pending |
| MIRK-02 | Phase 09 | Pending |
| MIRK-03 | Phase 03 | Complete |
| MIRK-04 | Phase 09 | Pending |
| MIRK-05 | Phase 09 | Pending |
| MIRK-06 | Phase 09 | Pending |
| MIRK-07 | Phase 13 | Pending |
| MIRK-08 | Phase 13 | Pending |
| MIRK-09 | Phase 13 | Pending |
| MIRK-10 | Phase 13 | Pending |
| MAP-01 | Phase 07 | Complete |
| MAP-02 | Phase 07 | Complete |
| MAP-03 | Phase 07 | Complete |
| MAP-04 | Phase 07 | Complete |
| MAP-05 | Phase 07 | Complete |
| MAP-06 | Phase 07 | Complete |
| MAP-07 | Phase 07 | Complete |
| MAP-08 | Phase 07 | Complete |
| MAP-09 | Phase 07 | Complete (Plan 07-04 — 7-step atomic protocol test-proven end-to-end: preflight / chunk download with Range resume / per-chunk sha256 / streaming concat / global sha256 / atomic rename / manifest write / staging cleanup. 6 soak scenarios exercise absent-or-fully-installed invariant against wire-level failure modes: happy / multi-part / 206 resume / 200 restart / disk insufficient / mid-rename kill heal. FirstLaunchBootstrap pmtiles-heal path closes the mid-rename crash gap.) |
| MAP-10 | Phase 07 | Complete |
| MARK-01 | Phase 11 | Pending |
| MARK-02 | Phase 11 | Pending |
| MARK-03 | Phase 11 | Pending |
| MARK-04 | Phase 11 | Pending |
| MARK-05 | Phase 11 | Pending |
| MARK-06 | Phase 11 | Pending |
| MARK-07 | Phase 11 | Pending |
| MARK-08 | Phase 11 | Pending |
| MARK-09 | Phase 11 | Pending |
| MARK-10 | Phase 11 | Pending |
| CAT-01 | Phase 11 | Pending |
| CAT-02 | Phase 11 | Pending |
| CAT-03 | Phase 11 | Pending |
| CAT-04 | Phase 11 | Pending |
| CAT-05 | Phase 11 | Pending |
| CAT-06 | Phase 11 | Pending |
| PORT-01 | Phase 13 | Pending |
| PORT-02 | Phase 13 | Pending |
| PORT-03 | Phase 13 | Pending |
| PORT-04 | Phase 13 | Pending |
| PORT-05 | Phase 13 | Pending |
| PORT-06 | Phase 13 | Pending |
| PORT-07 | Phase 13 | Pending |
| PORT-08 | Phase 13 | Pending |
| PORT-09 | Phase 13 | Pending |
| PORT-10 | Phase 13 | Pending |
| PORT-11 | Phase 13 | Pending |
| PORT-12 | Phase 13 | Pending |
| PORT-13 | Phase 13 | Pending |
| OPT-01 | Phase 13 | Pending |
| OPT-02 | Phase 13 | Pending |
| OPT-03 | Phase 13 | Pending |
| OPT-04 | Phase 13 | Pending |
| OPT-05 | Phase 13 | Pending |
| OPT-06 | Phase 13 | Pending |
| OPT-07 | Phase 13 | Pending |
| ABOUT-01 | Phase 15 | Pending |
| ABOUT-02 | Phase 15 | Pending |
| ABOUT-03 | Phase 15 | Pending |
| ABOUT-04 | Phase 15 | Pending |
| ABOUT-05 | Phase 15 | Pending |
| QUAL-01 | Phase 05 | Complete |
| QUAL-02 | Phase 05 | Complete |
| QUAL-03 | Phase 05 | Complete |
| QUAL-04 | Phase 05 | Complete |
| QUAL-05 | Phase 15 | Pending |

**Coverage:**
- v1 requirements: **87 total** (FOUND:8, SESS:9, GPS:8, MIRK:10, MAP:6, MARK:10, CAT:6, PORT:13, OPT:7, ABOUT:5, QUAL:5)
- Mapped to phases: **87 / 87 (100%)**
- Unmapped: 0

**Distribution par phase de code :**

| Phase | Catégorie(s) principale(s) | # REQ |
|-------|----------------------------|-------|
| 01 Foundation | FOUND (8) | 8 |
| 03 Persistence & Domain Models | SESS-06 (DB invariant), MIRK-03 (storage invariant) | 2 |
| 05 GPS & Session Lifecycle | SESS (8: 01-05, 07-09), GPS (8), QUAL (4: 01-04) | 20 |
| 07 Map Integration | MAP (6) | 6 |
| 09 Fog Rendering | MIRK (5: 01, 02, 04, 05, 06) | 5 |
| 11 Markers & Categories | MARK (10), CAT (6) | 16 |
| 13 Import/Export, Mirk Styles & Options | PORT (13), MIRK (4: 07-10), OPT (7) | 24 |
| 15 Polish, About & Release | ABOUT (5), QUAL (1: 05) | 6 |
| **Total mappé** | | **87 — chaque REQ mappé à exactement une phase** |

*Somme de vérification : 8 + 2 + 20 + 6 + 5 + 16 + 24 + 6 = 87 ✓*

---
*Requirements defined: 2026-04-17*
*Traceability filled by gsd-roadmapper: 2026-04-17 (also corrected the 77→86 arithmetic)*
*Last updated: 2026-04-23 — Phase 07 closed via Phase 08 Plan 08-01 Task 3 : MAP-05/06/07/08/10 → Complete, integration tests absorbed into Phase 08 Plan 08-04.*
*Previous update: 2026-04-20 — Phase 07 CONTEXT amendments : MAP-08 (catalog en asset bundlé, schema `alpha3/name/parts/reassembled`), MAP-09 (chunks binaires bruts + concat binaire, pas ZIP), MIRK-07 (sélecteur in-session menu), MIRK-10 (style carte + mirk par session, plus global), OPT-03 (défaut pour nouvelles sessions).*
