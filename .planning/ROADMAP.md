# Roadmap: MirkFall

## Overview

MirkFall est livré en 8 phases de code entrelacées de 8 phases de review gates (16 phases au total, numérotation séquentielle 01-16 sans décimales conformément à `CLAUDE.md`). La progression suit la dépendance imposée par l'architecture : fondations (licence, CI, logging) → persistance (modèle bitmap + DB Drift + envelope versionné) → GPS background (le risque #1 du projet, validé par POC sur OEM Android et iOS avant tout travail en aval) → carte → rendu du mirk → markers et catégories → import/export (core value exercé sur modèles stables) → polish, À propos, release. Chaque Review Gate est une phase à part entière qui audite la phase de code précédente avant de débloquer la suivante.

## Phases

**Phase Numbering:**
- Numérotation séquentielle entière (01..16). Pas de décimales.
- Pattern imposé par `CLAUDE.md` : `Phase NN Code` suivi immédiatement de `Phase NN+1 Review Gate`.
- Décimales réservées à d'éventuelles insertions urgentes via `/gsd:insert-phase` (pas prévues en V1.0).

- [x] **Phase 01: Foundation** - Projet Flutter scaffolded, GOSL headers, CI Android+iOS, logging fichier, Riverpod bootstrap, licence hygiene
 (completed 2026-04-17)
- [x] **Phase 02: Review Gate — Foundation** - Audit phase 01 (licence scan, headers, CI verte, zéro warning)
 (completed 2026-04-17)
- [x] **Phase 03: Persistence & Domain Models** - Drift schema + Freezed models + stores + TileMath + RevealCalculator + JsonMigrator framework (completed 2026-04-18)
- [x] **Phase 04: Review Gate — Persistence** - Audit phase 03 (migrations testées, invariants DB, pureté du domaine) (5/5 plans — 04-REVIEW status=closed, CI green on 26f3d99, all Blockers + Shoulds fixed in 10 atomic batches, Phase 05 unblocked)
 (completed 2026-04-19)
- [ ] **Phase 05: GPS & Session Lifecycle** - LocationSource + foreground service Android + iOS background + sessions CRUD + POC battery
- [ ] **Phase 06: Review Gate — GPS** - Audit phase 05 (POC background validé sur OEM Android + iOS, permissions, notification)
- [ ] **Phase 07: Map Integration** - flutter_map + TileSource interface + OSM tiles + attribution + FogOfWarLayer stub
- [ ] **Phase 08: Review Gate — Map** - Audit phase 07 (conformité OSM policy, User-Agent, cache borné)
- [ ] **Phase 09: Fog Rendering** - MirkRenderer interface + style atmosphérique animé par défaut + viewport filtering + RevealedAreaController
- [ ] **Phase 10: Review Gate — Fog** - Audit phase 09 (perf 50k-tile fixture, RepaintBoundary isolation, seam stable)
- [ ] **Phase 11: Markers & Categories** - MarkerIconPack + default RPG pack + markers CRUD + photos + catégories CRUD + under-mirk visibility
- [ ] **Phase 12: Review Gate — Markers** - Audit phase 11 (pas d'orphan photos, paths relatifs, EXIF strip, icons pack seam)
- [ ] **Phase 13: Import/Export, Mirk Styles & Options** - Envelope JSON versionné + ZIP archive + transactional import + style JSON import + écran options global
- [ ] **Phase 14: Review Gate — Import/Export** - Audit phase 13 (round-trip, migration matrix, SCHEMA.md, transactions atomiques)
- [ ] **Phase 15: Polish, About & Release** - Écran À propos + legal GOSL + store-policy copy + log rotation + debug menu + CI finale
- [ ] **Phase 16: Review Gate — Release** - Audit final V1.0 (analyze vert, tests verts, licence scan, Info.plist complet, smoke airplane-mode)

## Phase Details

### Phase 01: Foundation
**Goal**: Poser les garde-fous Day-1 (licence, CI, logging, DI, lint strict) avant toute ligne de feature. Objectif : qu'une contamination GPL, une télémétrie introduite par dep update, ou un header de licence manquant soit impossible plus tard.
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, FOUND-08
**Success Criteria** (what must be TRUE):
  1. `flutter pub get` fonctionne à partir d'un `pubspec.yaml` avec toutes les versions pinnées exactement (pas de `^`, pas de `~`) et `pubspec.lock` committé
  2. `flutter analyze` retourne zéro warning avec `strict-casts`, `strict-inference`, `strict-raw-types` activés ; `dart format` appliqué partout
  3. Chaque fichier source `.dart` contient le header GOSL v1.0 exigé par `CLAUDE.md` (vérifié par un pre-commit check ou un script CI)
  4. Le pipeline GitHub Actions construit un APK Android (ubuntu-latest) et un build iOS non-signé (macos-latest) sur chaque push, et échoue si un scan de licences détecte GPL/AGPL/copyleft fort
  5. Le logger écrit dans `<app_docs>/logs/yyyymmdd_hhmm.ss_logs.txt` et son niveau bascule via `--dart-define=DEBUG=true` ou un toggle debug in-app ; `runZonedGuarded` + `FlutterError.onError` sont armés
  6. `DEPENDENCIES.md` à la racine liste chaque dépendance directe avec licence et résultat d'audit télémétrie (stub peuplé avec les packages déjà dans `pubspec.yaml`)
**Plans** (4 plans, 4 waves):
- [ ] 01-foundation/01-01-PLAN.md — Wave 1: Flutter project scaffold, pinned pubspec, strict analyzer, lib/ skeleton, platform identity (Android + iOS bundle ID, minSdk 24, Info.plist TODOs)
- [ ] 01-foundation/01-02-PLAN.md — Wave 2: FileLogger JSONL + debug menu 7-tap + go_router config + MaterialApp.router wiring
- [ ] 01-foundation/01-03-PLAN.md — Wave 3: tool/check_headers.dart + check_licenses.dart + check_dependencies_md.dart with unit tests + DEPENDENCIES.md filled
- [ ] 01-foundation/01-04-PLAN.md — Wave 4: .github/workflows/ci.yml with gates/android/ios jobs + checkpoint to verify first CI run green

### Phase 02: Review Gate — Foundation
**Goal**: Auditer la phase 01 avant d'investir dans de la persistance. Vérifier que les garde-fous tiennent réellement sous pression, pas seulement qu'ils sont présents.
**Depends on**: Phase 01
**Requirements**: — (review gates ne possèdent pas de REQ-ID, ils vérifient les REQ de la phase précédente)
**Success Criteria** (what must be TRUE):
  1. L'utilisateur a été sollicité d'abord ("qu'as-tu vu ?") avant que Claude ne présente ses findings, conformément au protocole `CLAUDE.md §Code Review Phases`
  2. Les findings sont présentés comme une liste de **titres** avec explication courte, pas comme des diffs — l'utilisateur choisit ce qu'on corrige
  3. Le scan de licence CI tourne à vide sur une branche de test qui tenterait d'ajouter une dépendance GPL (le pipeline échoue comme attendu)
  4. Les corrections choisies sont appliquées et la CI repasse au vert avant ouverture de la Phase 03
**Plans** (4 plans, 4 waves):
- [ ] 02-review-gate-foundation/02-01-PLAN.md — Wave 1: Scaffold 02-REVIEW.md 5-section skeleton + user-first IDE review capture into §1
- [ ] 02-review-gate-foundation/02-02-PLAN.md — Wave 2: 4 parallel sub-agent audits (CI gates, bootstrap runtime + Windows visual walk, code quality sweep, tests+tooling+CI), findings synthesis into §2, user triage into §3
- [ ] 02-review-gate-foundation/02-03-PLAN.md — Wave 3: 3 adversarial stress-test branches (real GPL dep, missing GOSL header, missing DEPENDENCIES.md entry), evidence archived in §4, branches deleted local+remote
- [ ] 02-review-gate-foundation/02-04-PLAN.md — Wave 4: Apply fix-triaged findings as atomic commits with CI-gated loop, §5 CI-green confirmation, flip status=closed, update STATE.md + ROADMAP.md, unblock Phase 03

### Phase 03: Persistence & Domain Models
**Goal**: Figer les deux décisions architecturales les plus coûteuses à changer rétroactivement — le modèle de stockage du mirk révélé (bitmap 64×64 par parent-tile, décision D3) et le format d'échange JSON versionné (envelope `{schemaVersion, type, payload}`, décision D9) — avant qu'une seule ligne de GPS ou d'export ne les consomme.
**Depends on**: Phase 02 (Review Gate Foundation)
**Requirements**: SESS-06, MIRK-03
**Success Criteria** (what must be TRUE):
  1. La base Drift s'ouvre en mode WAL avec `synchronous=NORMAL` et `busy_timeout=5000`, et la migration V1→V1 (identity) passe un test de fixture sans perte de données
  2. L'invariant "au plus une session active à la fois" (SESS-06) est garanti par un **partial unique index** Drift au niveau DB ; un test unitaire prouve qu'une double-activation depuis deux code paths concurrents échoue avec une contrainte DB, pas une assertion caller
  3. Une fois un bit du bitmap 64×64 mis à 1 pour une cellule donnée, il ne peut plus redevenir 0 dans la même session (MIRK-03) ; test unitaire sur `RevealedTileStore` confirme l'idempotence du `INSERT OR IGNORE` / OR-mask
  4. Tous les modèles de domaine (`Session`, `Marker`, `MarkerCategory`, `MirkStyle`, `RevealedTile`, `PhotoRef`, `Envelope`) sont générés par Freezed, immuables, et le dossier `lib/domain/` ne contient aucun `import 'package:flutter/...'` ni `import 'package:drift/...'`
  5. `tile_math.dart` et `reveal_calculator.dart` sont purement Dart, sans I/O, et leurs tests unitaires tournent sous `dart test` (pas `flutter test`) ; le framework `JsonMigrator` existe avec une chaîne identity pour v1 et un slot prêt à recevoir v2
  6. Un backup DB pré-migration est produit automatiquement et un sanity check post-migration (row-count) échoue hard si la migration a perdu des lignes
**Plans** (6 plans, 5 waves):
- [ ] 03-persistence-domain-models/03-01-PLAN.md — Wave 1: Wave 0 bootstrap — pin custom_lint + riverpod_lint (Phase 01 deferred), libsqlite3 CI dep, drift-schema-drift guard on drift_schema_current.json (frozen v{1,2}.json fixtures never rewritten), Phase 03 constants, JSON + SQL fixtures, tool/check_domain_purity.dart
- [ ] 03-persistence-domain-models/03-02-PLAN.md — Wave 2: Pure-Dart domain — IDs (6 extension types + IdGenerator + ULID), domain errors (7 exceptions), tile_math + reveal_calculator (MIRK-03 algebra: mergeBitmap + popcount), JsonMigrator framework + V1→V2 rename-radius fictive (Envelope moved to 03-03)
- [ ] 03-persistence-domain-models/03-03-PLAN.md — Wave 3: Freezed entities (Session + Marker + MarkerCategory + MirkStyle + sealed MirkStyleConfig + RevealedTile + PhotoRef + Envelope) + 6 store ports + UnknownConfig fallback test + Envelope.fromJson test + fixture-driven JsonMigrator v1→v2 integration test (SC#4 verbatim, SC#5 closure)
- [ ] 03-persistence-domain-models/03-04-PLAN.md — Wave 4: AppDatabase V1+V2 schema (6 tables + SESS-06 partial unique index + MIRK-03 bitmap BLOB + FK CASCADE) + onBeforeUpgrade hook, pragmas, type converters, V1ToV2Notes migration, drift_schema_v{1,2}.json frozen + drift_schema_current.json rolling, pragma + schema + V1 identity fixture tests
- [ ] 03-persistence-domain-models/03-05-PLAN.md — Wave 5: DbBackupService (3-rolling) + SchemaSanityChecker + V1→V2 SchemaVerifier data-preservation test + buildAppDatabase factory wiring backup into AppDatabase.onBeforeUpgrade hook + backup-on-upgrade integration test (SC#6)
- [ ] 03-persistence-domain-models/03-06-PLAN.md — Wave 5: Five Drift stores (SESS-06 runtime via SqliteException 2067 → ConcurrentActivationException, MIRK-03 transactional mergeMask) + Riverpod providers + SESS-06/MIRK-03/cascade tests

### Phase 04: Review Gate — Persistence
**Goal**: Auditer la phase 03 avant que le GPS ne commence à écrire. Une erreur de modèle rattrapée ici coûte une semaine ; rattrapée en phase 09 elle coûte un mois.
**Depends on**: Phase 03
**Requirements**: —
**Success Criteria** (what must be TRUE):
  1. Revue des migrations : une migration V1→V2 fictive est écrite en test pour valider que le framework fonctionne réellement, pas seulement le cas identity
  2. Les `is` chains sont absents dans le domaine (polymorphisme / sealed classes utilisés) ; aucun `dynamic` non documenté ; aucun singleton global
  3. Le protocole review (user d'abord, puis titres + explications courtes) est appliqué
  4. Les corrections choisies sont intégrées et les tests de persistance restent verts avant ouverture de la Phase 05
**Plans** (5 plans, 5 waves):
- [x] 04-review-gate-persistence/04-01-PLAN.md — Wave 1: Scaffold 04-REVIEW.md 5-section skeleton (+ §1b runtime walk + §2 pre-class + §4 three-test placeholders) + user-first IDE review capture into §1
- [x] 04-review-gate-persistence/04-02-PLAN.md — Wave 2: Runtime walk Windows (dedicated plan before agents) — tool/walk_db.dart + user executes + sqlite3 observation archived verbatim into §1b
- [x] 04-review-gate-persistence/04-03-PLAN.md — Wave 3: Pre-class 3 VERIFICATION candidates into §2 FIRST, then 4 parallel sub-agent audits (schema+migrations / domain+pureté / stores+factory+providers / tests+fixtures+tooling+CLAUDE.md sweep), findings synthesis + user triage into §3
- [x] 04-review-gate-persistence/04-04-PLAN.md — Wave 4: Adversarial wave — Test #1 domain-purity double violation (CI branch), Test #2 drift schema dump stale with build_runner prerequisite (CI branch), Test #3 permanent SchemaSanityChecker row-loss regression guard (unit test), evidence archived in §4, branches deleted local+remote
- [x] 04-review-gate-persistence/04-05-PLAN.md — Wave 5: Atomic fix loop (batched strategy per user approval — 10 fix batches CI-gated) + 3 pre-class fixes (backup filename-ISO sort / custom_lint DEPENDENCIES.md+STATE.md / computeRevealMask no-callers guard) + §5 CI-green closure + status=closed + STATE.md + ROADMAP.md update + Phase 05 unblocked (completed 2026-04-19)

### Phase 05: GPS & Session Lifecycle
**Goal**: Prouver le risque #1 du projet — le tracking GPS en arrière-plan — avant qu'aucun code de carte, fog, ou export ne dépende de lui. Livrer un cycle de session complet "start → background 30 min écran éteint → stop → la DB contient les positions" sur Android OEM (Xiaomi ou Samsung) ET iOS, sinon toute la V1.0 est en question.
**Depends on**: Phase 04 (Review Gate Persistence)
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04, SESS-05, SESS-07, SESS-08, SESS-09, GPS-01, GPS-02, GPS-03, GPS-04, GPS-05, GPS-06, GPS-07, GPS-08, QUAL-01, QUAL-02, QUAL-03, QUAL-04
**Success Criteria** (what must be TRUE):
  1. Sur un device Android OEM connu pour killer les apps (Xiaomi, Samsung, Huawei ou OnePlus — POC documenté), une session démarrée et mise en background écran éteint pendant ≥ 30 min continue d'écrire des fixes dans la DB ; l'argumentaire store et les liens OEM battery killers (`dontkillmyapp.com`) sont accessibles depuis un écran d'aide dans l'app
  2. Sur un device iOS réel (via CI + sideload), une session démarrée et mise en background écran éteint pendant ≥ 30 min continue de tracker avec `allowsBackgroundLocationUpdates=true` et `pauseLocationUpdatesAutomatically=false`
  3. L'utilisateur peut créer, renommer, supprimer, démarrer, arrêter et lister des sessions depuis l'UI ; démarrer une session arrête automatiquement toute session précédemment active (exclusivité DB déjà garantie en Phase 03, maintenant vérifiée end-to-end)
  4. Une notification persistante signale qu'une session est en cours dès que le tracking démarre (Android foreground service notification + équivalent iOS) ; le bouton Stop la fait disparaître immédiatement
  5. La permission localisation "Always" est demandée **après** un écran d'explication (pre-prompt rationale) et uniquement à la première session démarrée ; si l'utilisateur refuse, un écran dédié guide vers les paramètres système (GPS-07)
  6. `Info.plist` contient `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription` avec des textes humains défendables par un reviewer App Store ; l'argumentaire store (QUAL-03) est rédigé dans `docs/store-review-rationale.md`
**Plans** (6 plans, 5 waves):
- [ ] 05-gps-session-lifecycle/05-01-PLAN.md — Wave 1: Wave-0 test scaffolding (22 files + fakes) + Fix entity + FixStore port + LocationStream stub + Drift V2→V3 migration + DriftFixStore + SessionStore.watchAll()
- [ ] 05-gps-session-lifecycle/05-02-PLAN.md — Wave 2: GPS infrastructure (GeolocatorLocationStream + LocationSettingsFactory) + SessionNotificationService + OemDetector + AndroidManifest permissions + Info.plist QUAL-04 final copy + device_info_plus audit
- [ ] 05-gps-session-lifecycle/05-03-PLAN.md — Wave 3: ActiveSessionController orchestration + two-step permission flow + SessionSettings provider + sealed ActiveSessionState
- [ ] 05-gps-session-lifecycle/05-04-PLAN.md — Wave 4: UI — SessionListScreen (replaces PlaceholderHomeScreen) + SessionDetailScreen + SettingsScreen + permission screens + OEM guidance + cross-route banner + routing updates
- [ ] 05-gps-session-lifecycle/05-05-PLAN.md — Wave 4: Auto-resume post-kill — BootCompletedWatchdog (Dart) + Kotlin BootCompletedReceiver + iOS AppDelegate significant-change + tap-to-resume flow
- [ ] 05-gps-session-lifecycle/05-06-PLAN.md — Wave 5: POC tooling (tool/plot_session_fixes.py + tool/requirements.txt) + docs/store-review-rationale.md (QUAL-03) + docs/qual-01-02-poc.md template + real-device 30-min walks on Pixel + iPhone 17 Pro

### Phase 06: Review Gate — GPS
**Goal**: Valider le POC background GPS. Si ce gate rouge, on ne passe pas à la carte — on corrige ou on réévalue la V1.0.
**Depends on**: Phase 05
**Requirements**: —
**Success Criteria** (what must be TRUE):
  1. Les artefacts POC (vidéo ou log extrait) des sessions background 30 min sur Android OEM et iOS sont archivés dans `.planning/pocs/phase-05/`
  2. La consommation batterie mesurée sur le POC est dans un ordre de grandeur acceptable (< 15 %/h en walking mode avec `distanceFilter` configuré), conforme à la mesure de référence geolocator
  3. Le protocole review (user d'abord, titres + explications courtes) est appliqué
  4. Un plan de contournement pour les OEM les plus agressifs (Xiaomi / Huawei) est documenté — deep-links settings, instructions utilisateur, bannière "tracking interrompu" sur prochain launch
**Plans**: TBD

### Phase 07: Map Integration
**Goal**: Afficher une carte interactive OSM conforme à la policy (User-Agent identifiant, attribution visible, pas de bulk prefetch) avec les seams `TileSource` et `FogOfWarLayer` en place. La carte ne montre pas encore de mirk rendu — le stub `FogOfWarLayer` existe mais ne peint rien — mais son intégration layer-stack est gelée ici.
**Depends on**: Phase 06 (Review Gate GPS)
**Requirements**: MAP-01, MAP-02, MAP-03, MAP-04, MAP-05
**Success Criteria** (what must be TRUE):
  1. L'utilisateur ouvre l'app, la carte OSM s'affiche, il peut panner et zoomer fluidement ; la position courante apparaît quand une session est active (hook sur l'`ActiveSessionController` de la Phase 05)
  2. L'attribution `© OpenStreetMap contributors` est visible sur la carte et dans l'écran À propos (prévu), avec un lien vers https://www.openstreetmap.org/copyright
  3. Toutes les requêtes tiles partent avec un `User-Agent: MirkFall/<version> (+<repo-url>)` distinct, vérifié en capturant le trafic local (mitmproxy ou équivalent) pendant le dev
  4. L'interface `TileSource` est le seul point de contact entre la `MapScreen` et les tiles ; l'implémentation `OnlineOsmTileSource` est isolée, et l'ajout d'un `MbtilesFileTileSource` en V1.1 ne demande aucune modification de `MapScreen` (validé par un mock test)
  5. Le `FogOfWarLayer` stub est présent dans le layer-stack avec son `RepaintBoundary`, au bon ordre (tiles → markers → fog → attribution) ; il ne peint rien en Phase 07 mais l'ordre est gelé
  6. Le cache tiles LRU a un plafond explicite (200 MB, constante dans `lib/config/constants.dart`) avec un bouton "Clear map cache" qui sera exposé en Phase 15
**Plans**: TBD

### Phase 08: Review Gate — Map
**Goal**: Auditer la conformité OSM policy et la stabilité du seam `TileSource` avant que le fog ne soit câblé par-dessus.
**Depends on**: Phase 07
**Requirements**: —
**Success Criteria** (what must be TRUE):
  1. Un test manuel de trafic réseau confirme le User-Agent et l'absence de bulk-prefetch ; le cache respecte son plafond sur une session longue
  2. Le seam `TileSource` est relu : pas de fuite `flutter_map` dans le domaine, pas de fuite `http` dans l'UI
  3. Le protocole review (user d'abord, titres + explications courtes) est appliqué
  4. Les corrections choisies sont intégrées avant ouverture de la Phase 09
**Plans**: TBD

### Phase 09: Fog Rendering
**Goal**: Le livrable visuel qui donne au produit son identité : un mirk vivant et atmosphérique (pas un aplat noir) qui se dissipe autour de l'utilisateur en temps réel, avec une architecture de rendu strictement découplée via `MirkRenderer`. Passer ici sans dégrader à > 50k tiles révélées est la barre de qualité.
**Depends on**: Phase 08 (Review Gate Map)
**Requirements**: MIRK-01, MIRK-02, MIRK-04, MIRK-05, MIRK-06
**Success Criteria** (what must be TRUE):
  1. Quand la session est active, un rayon circulaire autour de la position courante est effacé du mirk en temps réel (fréquence pilotée par `distanceFilter` + batch flush 5s/50fixes) ; le rayon par défaut (25-50 m, décidé en début de phase et stocké dans `lib/config/constants.dart`) est configurable (la UI de réglage arrive en Phase 13)
  2. Le style par défaut est **animé et atmosphérique** (noise mouvant, pas un aplat noir) ; un second style built-in variant démontre que le seam fonctionne — ajouter un style ne nécessite qu'un nouveau fichier, zéro modification du cœur (vérifié par code review)
  3. L'interface `MirkRenderer` expose `paint(Canvas, Size, MirkPaintContext)`, `update(Duration)`, `dispose()` et **rien d'autre** ; elle n'impose ni `ui.Image` ni format intermédiaire
  4. Avec une fixture de 50k sub-tiles révélées chargée en DB, le DevTools confirme que l'animation du mirk ne fait rebuild aucun autre layer (`RepaintBoundary` isolation effective) et que la frame reste ≤ 16 ms sur un device milieu de gamme Android
  5. Le viewport filtering est en place : seuls les parent-tiles intersectant la viewport courante sont peints ; un test de régression prévient la dégradation future
**Plans**: TBD

### Phase 10: Review Gate — Fog
**Goal**: Auditer la perf du rendu et la pureté du seam `MirkRenderer`. Le rendu shader V1.x doit pouvoir arriver sans toucher au reste.
**Depends on**: Phase 09
**Requirements**: —
**Success Criteria** (what must be TRUE):
  1. Profiling DevTools archivé sur la fixture 50k-tiles ; décision finale sur sub-tile grid size (O1) et batch flush threshold (O2) documentée dans PROJECT.md Key Decisions
  2. Le seam `MirkRenderer` ne fuit aucun détail d'implémentation vers ses consommateurs (pas de `Paint`, pas de `Canvas` exposé depuis le domaine)
  3. Le protocole review (user d'abord, titres + explications courtes) est appliqué
  4. Les corrections choisies sont intégrées avant ouverture de la Phase 11
**Plans**: TBD

### Phase 11: Markers & Categories
**Goal**: Livrer le layer "journal de voyage" — markers avec photos, catégories à icônes RPG, visibilité sous le mirk — qui différencie MirkFall de Fog of World (qui n'a pas de markers du tout). La gestion des photos (stockage fichier avec path relatif + delete-first order + orphan reconciliation) est le point critique à ne pas rater.
**Depends on**: Phase 10 (Review Gate Fog)
**Requirements**: MARK-01, MARK-02, MARK-03, MARK-04, MARK-05, MARK-06, MARK-07, MARK-08, MARK-09, MARK-10, CAT-01, CAT-02, CAT-03, CAT-04, CAT-05, CAT-06
**Success Criteria** (what must be TRUE):
  1. L'utilisateur peut créer un marker depuis la carte (tap long) ou depuis un bouton "+" , lui donner un titre, un texte libre, une catégorie, et attacher 0..n photos via la caméra ou la galerie (`image_picker` avec `maxWidth=2048`, `imageQuality=85`) ; les photos sont downscalées, EXIF strippé, et stockées en path relatif
  2. L'utilisateur peut modifier et supprimer un marker (avec confirmation) ; la suppression supprime d'abord le fichier photo sur disque puis la ligne DB (delete-first order), et un job de réconciliation au startup nettoie d'éventuels orphans
  3. Les markers apparaissent sur la carte avec des icônes de style RPG (pas les pins Material génériques) ; un tap ouvre la fiche détaillée (titre, texte, galerie photos) ; une liste dédiée affiche tous les markers de la session active
  4. Les markers restent **visibles en transparence** (alpha ~30 %) dans les zones encore sous mirk, pour supporter le use-case "pré-import de lieux à visiter avant un voyage" (composite-trick dans le renderer vérifié visuellement)
  5. L'utilisateur peut créer, renommer, modifier et supprimer des catégories custom ; la suppression d'une catégorie réassigne ses markers à une catégorie "default" (pas d'orphan) ; l'app fournit un set de catégories RPG par défaut (maison, trésor, donjon, auberge, ...) pré-peuplé au premier lancement
  6. L'interface `MarkerIconPack` est en place ; l'ajout d'un pack d'icônes complet en V1.x (ex: packs importés) ne demande qu'un nouveau fichier, zéro modification du cœur — `Info.plist` est mis à jour avec `NSCameraUsageDescription` et `NSPhotoLibraryUsageDescription` (QUAL-04 continu)
**Plans**: TBD

### Phase 12: Review Gate — Markers
**Goal**: Auditer la gestion photos + le seam `MarkerIconPack` avant que l'export ne fige le format fichier.
**Depends on**: Phase 11
**Requirements**: —
**Success Criteria** (what must be TRUE):
  1. Un test de soak (créer 50 markers avec photos, en supprimer 50, restart l'app, orphan reconciler tourne) confirme zéro fichier photo orphelin
  2. Les paths photos stockés en DB sont **tous relatifs** (vérifié par un test qui chercherait un `/` ou `C:\` en tête) — pré-requis pour que l'import cross-device fonctionne en Phase 13
  3. Le protocole review (user d'abord, titres + explications courtes) est appliqué
  4. Les corrections choisies sont intégrées avant ouverture de la Phase 13
**Plans**: TBD

### Phase 13: Import/Export, Mirk Styles & Options
**Goal**: Livrer la **core value** du produit : import/export JSON versionné, résistant, round-trip-verifié, sans lequel MirkFall n'est plus qu'un clone-lite de Fog of World. Tout le travail des phases 03 à 11 est validé ici par un round-trip complet (export → wipe DB → import → égalité observationnelle). L'écran d'options global est livré dans la foulée parce qu'il contrôle principalement les features déjà construites.
**Depends on**: Phase 12 (Review Gate Markers)
**Requirements**: PORT-01, PORT-02, PORT-03, PORT-04, PORT-05, PORT-06, PORT-07, PORT-08, PORT-09, PORT-10, PORT-11, PORT-12, PORT-13, MIRK-07, MIRK-08, MIRK-09, MIRK-10, OPT-01, OPT-02, OPT-03, OPT-04, OPT-05, OPT-06, OPT-07
**Success Criteria** (what must be TRUE):
  1. L'utilisateur peut exporter une session individuelle et "toutes les sessions" via l'OS share sheet ; le fichier est un `.mirkfall` (ZIP) contenant `manifest.json` avec envelope `{schemaVersion: 1, type: "session" | "bundle", payload: {...}}` + dossier `photos/` + `report.txt` de vérification ; un test de round-trip (export → relire le ZIP → comparer) tourne avant que "Export réussi" ne s'affiche (PORT-11)
  2. L'import est **transactionnel** : validation complète du ZIP en staging avant la moindre écriture DB ; tout en une seule transaction Drift ; en cas d'erreur, la DB reste inchangée et les photos staging sont nettoyées ; un écran de prévisualisation liste ce qui va être importé et les collisions éventuelles avec des sessions existantes (PORT-09, PORT-10)
  3. L'utilisateur peut importer un JSON de markers seuls (pour pré-peupler une session avec une liste de lieux à visiter) et un JSON de style de mirk ; le style de mirk importé apparaît dans le sélecteur de l'écran options et peut être choisi comme style global actif (MIRK-07, MIRK-08, MIRK-10, PORT-07, PORT-08)
  4. `SCHEMA.md` à la racine du repo documente le format JSON v1 exhaustivement, avec un exemple complet lisible à la main (PORT-12) ; une matrice de tests cross-version (`test/migration/`) prouve qu'un fichier v1 reste importable après ajout d'un futur champ v2 (PORT-13)
  5. L'écran d'options global expose : slider rayon de révélation (OPT-02), sélecteur de style actif (OPT-03), liste + suppression des styles importés (OPT-04, MIRK-09), gestionnaire de catégories (OPT-05), entrée vers import/export (OPT-06), toggle logger debug (OPT-07) ; accessible depuis l'écran principal (OPT-01)
  6. Le schéma JSON est **lisible à la main** : pas de blob binaire injustifié, les coordonnées sont en clair, les bitmaps du mirk sont base64 avec un header descriptif (PORT-02) ; `schemaVersion` est en tête de chaque document (PORT-01)
**Plans**: TBD

### Phase 14: Review Gate — Import/Export
**Goal**: Auditer la core value. Un bug ici détruit la promesse "ne jamais perdre sa progression" qui différencie le produit.
**Depends on**: Phase 13
**Requirements**: —
**Success Criteria** (what must be TRUE):
  1. Un test de round-trip end-to-end (créer sessions+markers+photos → export → wipe app data → reinstall → import → diff observationnel) passe avec zéro différence
  2. La revue confirme qu'aucun path absolu ne fuit dans le JSON exporté (seuls les basenames photos)
  3. `SCHEMA.md` est complet, versionné, commité ; l'exemple fourni est parseable par le code de l'app
  4. Le protocole review (user d'abord, titres + explications courtes) est appliqué
  5. Les corrections choisies sont intégrées avant ouverture de la Phase 15
**Plans**: TBD

### Phase 15: Polish, About & Release
**Goal**: Fermer les boucles restantes avant le tag v1.0.0 : À propos / Legal GOSL, rotation de logs, bouton debug menu pour les builds production, audit final Info.plist, store-policy strings finales, recovery flow sur session OS-killée, release notes.
**Depends on**: Phase 14 (Review Gate Import/Export)
**Requirements**: ABOUT-01, ABOUT-02, ABOUT-03, ABOUT-04, ABOUT-05, QUAL-05
**Success Criteria** (what must be TRUE):
  1. L'écran "À propos" est accessible depuis les options et affiche : "MirkFall is distributed under GOSL v1.0" (ABOUT-02), un lien vers le texte complet de la licence embarqué dans l'app (ABOUT-03), la liste des dépendances tierces avec leurs licences respectives (ABOUT-04), un lien vers le repo GitHub (ABOUT-05)
  2. Un test "airplane mode" (wifi + cellulaire + location désactivés, app exhaustivement exercée pendant 5 min) capture **zéro** tentative de requête sortante autre que les tiles OSM (qui tombent proprement) — validation de QUAL-05 via inspection réseau
  3. Les logs sont rotés : max 2 MB par fichier, suppression après 14 jours ; l'utilisateur peut activer le logger debug depuis un menu dédié (déjà OPT-07 mais vérifié en conditions de build release sans `--dart-define=DEBUG`)
  4. Une session marquée `active` en DB au launch (suite à OS-kill ou sideload cert expiry) déclenche une bannière de recovery à l'utilisateur ("La session X était active au moment de la fermeture — reprendre ?") au lieu de redémarrer silencieusement le tracking
  5. La CI finale est verte sur les deux plateformes, le scan de licences ne remonte aucune violation, `flutter analyze` retourne zéro warning, tous les tests unitaires et widget passent ; le tag `v1.0.0` est prêt à être poussé
**Plans**: TBD

### Phase 16: Review Gate — Release
**Goal**: Audit final V1.0. Ce gate signe le tag `v1.0.0` et le premier release GitHub.
**Depends on**: Phase 15
**Requirements**: —
**Success Criteria** (what must be TRUE):
  1. Les 86 REQ-IDs v1 sont tous traçables vers une phase complétée dans la Traceability de REQUIREMENTS.md
  2. `DEPENDENCIES.md` liste toutes les dépendances directes finales avec audit télémétrie signé (dernière date de vérification)
  3. Un smoke test manuel couvre : création session → start tracking → background 10 min → stop → marker créé avec photo → export → import sur un second device → observation de la restauration complète
  4. Le protocole review (user d'abord, titres + explications courtes) est appliqué
  5. Le tag v1.0.0 est poussé, le GitHub Release est créé avec les artefacts APK + iOS-unsigned attachés automatiquement par la CI
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in strict numeric order: 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12 → 13 → 14 → 15 → 16. Review gates (even-numbered) bloquent la phase suivante jusqu'à clearance explicite.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 01. Foundation | 4/4 | Complete    | 2026-04-17 |
| 02. Review Gate — Foundation | 3/4 | In Progress|  |
| 03. Persistence & Domain Models | 6/6 | Complete    | 2026-04-18 |
| 04. Review Gate — Persistence | 4/5 | Complete    | 2026-04-18 |
| 05. GPS & Session Lifecycle | 0/6 | Not started | - |
| 06. Review Gate — GPS | 0/TBD | Not started | - |
| 07. Map Integration | 0/TBD | Not started | - |
| 08. Review Gate — Map | 0/TBD | Not started | - |
| 09. Fog Rendering | 0/TBD | Not started | - |
| 10. Review Gate — Fog | 0/TBD | Not started | - |
| 11. Markers & Categories | 0/TBD | Not started | - |
| 12. Review Gate — Markers | 0/TBD | Not started | - |
| 13. Import/Export, Mirk Styles & Options | 0/TBD | Not started | - |
| 14. Review Gate — Import/Export | 0/TBD | Not started | - |
| 15. Polish, About & Release | 0/TBD | Not started | - |
| 16. Review Gate — Release | 0/TBD | Not started | - |

---

## Coverage Summary

**v1 requirements:** 86 total
- FOUND (8) → Phase 01
- SESS (9) → Phase 03 (SESS-06 DB invariant) + Phase 05 (SESS-01..05, 07..09)
- GPS (8) → Phase 05
- MIRK (10) → Phase 03 (MIRK-03 storage invariant) + Phase 09 (MIRK-01, 02, 04, 05, 06) + Phase 13 (MIRK-07, 08, 09, 10)
- MAP (5) → Phase 07
- MARK (10) → Phase 11
- CAT (6) → Phase 11
- PORT (13) → Phase 13
- OPT (7) → Phase 13
- ABOUT (5) → Phase 15
- QUAL (5) → Phase 05 (QUAL-01, 02, 03, 04) + Phase 15 (QUAL-05)

**Mapped:** 86 / 86 (100%)
**Orphaned:** 0
**Duplicates:** 0

---
*Roadmap initial défini: 2026-04-17*
*Last updated: 2026-04-17 after roadmap creation by gsd-roadmapper*
