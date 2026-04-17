# Requirements: MirkFall

**Defined:** 2026-04-17
**Core Value:** Ne jamais perdre sa progression — import/export JSON versionné durable entre instances.

## v1 Requirements

Requirements pour release initiale V1.0. Chaque REQ est mappé à exactement une phase du roadmap.

### Foundation (FOUND)

<!-- Guardrails Day-1 — non-négociables, tout le reste en dépend. -->

- [ ] **FOUND-01**: Repo Flutter initialisé avec `analysis_options.yaml` strict (`strict-casts`, `strict-inference`, `strict-raw-types`)
- [ ] **FOUND-02**: Chaque fichier source contient le header de licence GOSL v1.0 obligatoire
- [ ] **FOUND-03**: `DEPENDENCIES.md` à la racine, tenu à jour (licence + audit télémétrie par dépendance)
- [ ] **FOUND-04**: Pipeline GitHub Actions CI construit un APK Android (ubuntu-latest) et un build iOS non-signé (macos-latest) sur chaque push
- [ ] **FOUND-05**: Versions des dépendances `pubspec.yaml` strictement pinnées (pas de `^`, pas de `~`)
- [ ] **FOUND-06**: Logger configurable via `--dart-define=DEBUG=true` et menu debug in-app ; logs écrits dans `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt`
- [ ] **FOUND-07**: Constantes partagées (rayon défaut, timeouts, tailles limites) centralisées dans `lib/config/constants.dart`
- [ ] **FOUND-08**: `flutter analyze` passe avec zéro warning ; `dart format` appliqué partout

### Sessions (SESS)

- [ ] **SESS-01**: Utilisateur peut créer une session avec un nom
- [ ] **SESS-02**: Utilisateur peut renommer une session existante
- [ ] **SESS-03**: Utilisateur peut supprimer une session (avec confirmation)
- [ ] **SESS-04**: Utilisateur peut démarrer (Start) une session
- [ ] **SESS-05**: Utilisateur peut arrêter (Stop) une session active
- [ ] **SESS-06**: Démarrer une session arrête automatiquement toute autre session en cours (exclusivité enforcée au niveau DB)
- [ ] **SESS-07**: L'état d'une session (mirk révélé, markers, métadonnées) est persisté localement en continu
- [ ] **SESS-08**: Utilisateur peut voir la liste de toutes ses sessions avec leur état (active / arrêtée)
- [ ] **SESS-09**: Utilisateur peut créer un nombre illimité de sessions

### GPS / Tracking (GPS)

- [ ] **GPS-01**: L'app demande la permission de localisation "Always" à la première session démarrée, avec écran d'explication préalable (pre-prompt rationale)
- [ ] **GPS-02**: Une session active tracke la position utilisateur en temps réel (foreground)
- [ ] **GPS-03**: Une session active continue à tracker en arrière-plan (app backgroundée, écran éteint) — Android foreground service + iOS background location
- [ ] **GPS-04**: Une notification persistante signale qu'une session est en cours (Android foreground service notification + équivalent iOS)
- [ ] **GPS-05**: Tracking respecte un `distanceFilter` configurable pour limiter la consommation batterie (pas de poll 1 Hz en stationnaire)
- [ ] **GPS-06**: Si l'app est killée par l'OS en background, le tracking reprend automatiquement au redémarrage de la session
- [ ] **GPS-07**: Écran dédié "Permissions" qui explique pourquoi MirkFall a besoin de la localisation et guide vers les paramètres système si permission refusée
- [ ] **GPS-08**: Documentation utilisateur intégrée mentionnant les contraintes OEM Android (Xiaomi/Huawei/Samsung/OnePlus background killers) avec liens `dontkillmyapp.com`

### Mirk (MIRK)

- [ ] **MIRK-01**: Un rayon de révélation circulaire est effacé autour de la position actuelle au fil du déplacement
- [ ] **MIRK-02**: Le rayon de révélation est configurable dans les options globales (défaut à fixer en Phase Fog, proposition 25-50 m)
- [ ] **MIRK-03**: Le mirk effacé reste effacé pour toute la durée de vie de la session (pas de re-brumage)
- [ ] **MIRK-04**: Le mirk a un rendu vivant / atmosphérique (nuageux, mouvant, animé) — pas un simple aplat noir
- [ ] **MIRK-05**: L'architecture de rendu expose une interface `MirkRenderer` abstraite : ajouter un style ne demande qu'un nouveau fichier, zéro modification du cœur
- [ ] **MIRK-06**: L'app fournit au moins un style de mirk par défaut (atmosphérique)
- [ ] **MIRK-07**: Un écran d'options permet de sélectionner le style de mirk actif parmi les styles installés
- [ ] **MIRK-08**: Utilisateur peut importer un style de mirk depuis un fichier JSON (format versionné)
- [ ] **MIRK-09**: Utilisateur peut supprimer un style de mirk importé
- [ ] **MIRK-10**: Le choix du style est global à l'application (pas par session en V1.0)

### Map (MAP)

- [ ] **MAP-01**: La carte s'affiche sur un fond de plan standard (OSM via User-Agent conforme à la policy)
- [ ] **MAP-02**: La carte reste interactive (pan, zoom) sous le mirk
- [ ] **MAP-03**: Attribution OSM visible et conforme à la policy
- [ ] **MAP-04**: La couche `FogOfWarLayer` s'intègre proprement au layer system de flutter_map sans faire rebuild le reste de la carte (RepaintBoundary)
- [ ] **MAP-05**: Interface `TileSource` abstraite en place dès V1.0 — permet d'ajouter en V1.1 un provider de tuiles offline sans modifier le code appelant

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
- [ ] **OPT-03**: Option : style de mirk actif (sélecteur parmi les styles installés)
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

- [ ] **QUAL-01**: POC validation du tracking background sur device Android OEM (Xiaomi ou Samsung) avec session ≥ 30 min écran éteint
- [ ] **QUAL-02**: POC validation du tracking background sur device iOS (via CI + sideload) avec session ≥ 30 min écran éteint
- [ ] **QUAL-03**: Argumentaire pour revue App Store / Play Store documenté (justification background location)
- [ ] **QUAL-04**: `Info.plist` iOS contient toutes les `*UsageDescription` requises (location, camera, photo library) au fur et à mesure des ajouts
- [ ] **QUAL-05**: Aucune dépendance identifiée faisant des appels réseau sans action utilisateur explicite (confirmé par inspection source + test smoke "airplane mode = zéro requête sortante")

## v2 Requirements

Différé à V1.1+, non couvert par la V1.0. Architecture V1.0 prépare ces extensions (interfaces déjà en place) mais code n'est pas livré.

### Offline tiles (OFFL)

- **OFFL-01**: Utilisateur peut télécharger les tuiles d'une zone définie pour usage offline
- **OFFL-02**: Provider de tuiles retenu permet un usage gratuit du download offline
- **OFFL-03**: UI de sélection de zone + gestion du cache tiles
- **OFFL-04**: Purge / gestion des tiles téléchargées

### Observabilité / Stats

- **STAT-01**: Distance totale parcourue par session
- **STAT-02**: Pourcentage de la ville / région révélée
- **STAT-03**: Nombre de markers par catégorie

### Internationalisation

- **I18N-01**: Sélecteur de langue dans les options
- **I18N-02**: Sélecteur d'unités de mesure (métrique / impérial)

### Mirk par session

- **MIRK2-01**: Style de mirk configurable par session (pas seulement global)

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

Mapping requirement → phase. À remplir par `gsd-roadmapper` pendant la création du roadmap.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (Sera peuplé par gsd-roadmapper) | | Pending |

**Coverage:**
- v1 requirements: **77 total** (FOUND:8, SESS:9, GPS:8, MIRK:10, MAP:5, MARK:10, CAT:6, PORT:13, OPT:7, ABOUT:5, QUAL:5)
- Mapped to phases: 0 (en attente du roadmap)
- Unmapped: 77 ⚠️ (normal, avant roadmap)

---
*Requirements defined: 2026-04-17*
*Last updated: 2026-04-17 after initial definition*
