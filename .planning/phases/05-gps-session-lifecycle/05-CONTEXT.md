# Phase 05: GPS & Session Lifecycle - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Prouver le **risque #1 du projet** — tracking GPS en arrière-plan — avant que la moindre ligne de carte, fog, marker ou import/export n'en dépende. Livrer un cycle de session complet "start → background 30 min écran éteint → stop → la DB contient les positions" sur Android réel ET iOS réel, sinon toute la V1.0 est en question.

**Livrables Phase 05 (UI sessions + pipeline GPS complet + validation POC) :**
- UI sessions complète : liste (= home `/`), create/rename/delete, start/stop, session detail screen
- Status dashboard texte pendant une session active (chrono, last fix, #fixes, parent tiles touchés, distance filter)
- Bandeau persistant "session active" cross-route (+ iOS Dynamic Island si faisable GOSL-compatible)
- Route `/settings` minimale hébergeant le slider `distanceFilter` (OPT-02 partiel, étendu Phase 13)
- Pipeline GPS complet : `geolocator` foreground → fg service Android → iOS background location mode → write fixes DB
- Nouvelle table `t_fixes` (ou équivalent) via migration Drift V2→V3 (schema bump)
- Permission flow full-screen : rationale pre-prompt → OS prompt → OEM guidance (détection `Build.MANUFACTURER`) → start session
- Écran permission-denied recovery (GPS-07) avec deep-link vers paramètres système
- Notification persistante (titre seul, pas d'action inline) via `flutter_local_notifications` 21.0.0
- Auto-resume post-kill OS : Android `BOOT_COMPLETED` receiver + iOS significant-change/region-monitoring watchdog → notif locale "tap pour reprendre" (pas de reprise silencieuse)
- Info.plist `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription` copy FINAL
- `docs/store-review-rationale.md` rédigé (angle local-only / zero telemetry / open-source GOSL)
- Tool `tool/plot_session_fixes.py` qui lit la DB et dessine le trajet sur tile map (validation visuelle POC)
- `ProviderScope` wiring de `AppDatabase` dans `main.dart` (déferred Phase 03, premier consommateur productif = `ActiveSessionController`)
- Tests : unit Dart sur controllers + stores, widget tests sur écrans clés, POC end-to-end sur devices réels

**Requirements couverts (20) :** SESS-01, SESS-02, SESS-03, SESS-04, SESS-05, SESS-07, SESS-08, SESS-09, GPS-01, GPS-02, GPS-03, GPS-04, GPS-05, GPS-06, GPS-07, GPS-08, QUAL-01 (partial Pixel), QUAL-02, QUAL-03, QUAL-04.

**Hors scope (autres phases, confirmé) :**
- Rendu fog + `MirkRenderer` (MIRK-01..02, 04..06) — Phase 09
- Carte OSM + `flutter_map` interactivity (MAP-01..05) — Phase 07
- Markers CRUD + pipeline photos (MARK-*, CAT-*) — Phase 11
- Import/Export JSON + ZIP + `SCHEMA.md` (PORT-*) — Phase 13
- Écran options global complet (OPT-03..07) — Phase 13 (étend le `/settings` minimal de Phase 05)
- About/Legal polish (ABOUT-*) + QUAL-05 airplane-mode smoke — Phase 15
- Splash screen logo 3 s — Phase 15 polish (user a demandé, noté en deferred)
- POC sur OEM battery-killer réel (Xiaomi/Samsung/Huawei/OnePlus) — deferred Phase 15 ou emprunt device pré-release (gap documenté)

</domain>

<decisions>
## Implementation Decisions

### UI : Session list = home, pas de carte en 05

- **Route `/` = SessionListScreen** : remplace `PlaceholderHomeScreen`. Liste sessions ordonnée `startedAtUtc DESC`. FAB "+" ouvre dialog/bottom-sheet de création (displayName + start immédiat ou juste create). Tap session = route `/sessions/:id`.
- **Empty state premier lancement** : message + CTA "Créer ma première session" (aligne avec le FAB).
- **`/sessions/:id` = SessionDetailScreen** : si session active → status dashboard texte (chrono depuis `startedAtUtc`, last fix lat/lon/accuracy/timestamp, #fixes écrits, #parent tiles touchés, `distanceFilter` actif) + bouton Stop + menu (rename). Si stopped → résumé (durée totale, #fixes final, "Carte viendra Phase 07" placeholder léger, bouton delete).
- **Règles session active** :
  - Rename = autorisé (simple UPDATE `displayName`)
  - Delete = bloqué avec message "Arrête la session d'abord"
  - Start d'une autre session = stop auto de l'active (SESS-06 DB partial unique index déjà enforced Phase 03, maintenant testé end-to-end)
  - Noms dupliqués autorisés (ULID différencie)

### UI : Indicateur session active cross-route

- **Bandeau slim top-of-screen** (~40dp) : "Session active : [nom] • Stop". Tap = navigue `/sessions/:id`. Bouton Stop inline = arrête. Présent sur toutes les routes sauf `/sessions/:id` elle-même. Implémenté comme Scaffold bodyWrapper ou layout shell go_router.
- **iOS Dynamic Island (nice-to-have si faisable)** : sur iPhone 14 Pro+ (incluant 17 Pro du user), afficher un Live Activity compact avec `[nom session] • [chrono]`. Nécessite extension Swift WidgetKit + ActivityKit bridge. Faisabilité + audit licence package Flutter (ex: `live_activities`, `flutter_live_activities`) à investiguer en RESEARCH. **Fallback = bandeau Flutter**, disponible sur tout iPhone + tout Android. Si le package communautaire ne passe pas l'audit GOSL/télémétrie, on drop Dynamic Island et ship uniquement le bandeau. Aucun blocker.

### Permission flow : wizard full-screen 1 écran + OEM guidance ciblée

- **Trigger** : click "Start" sur la PREMIÈRE session que l'user démarre (SharedPreferences flag `permission_flow_completed`). Jamais re-promptée ensuite sauf si permission révoquée système → denied-recovery screen.
- **Écran rationale (1 full-screen)** :
  - Titre : "Pour suivre ton exploration"
  - 3-4 lignes : "MirkFall a besoin de ta localisation en arrière-plan pour continuer à révéler le brouillard pendant que ton téléphone est dans ta poche, écran éteint. Tes positions restent sur ton téléphone. Aucun serveur, aucune publicité, aucune analytique."
  - Bouton primary "Continuer" → OS prompt `permission_handler` `Permission.locationAlways`
  - Bouton secondary "Pas maintenant" → retour session list, session pas démarrée
- **Après OS prompt accordée** :
  - Détection `Build.MANUFACTURER` (Android) via platform channel ou `device_info_plus` (audit dep)
  - Si match Xiaomi/Redmi/POCO/Samsung/Huawei/OnePlus/OPPO/Realme → écran OEM guidance ciblé : "Ton [Manufacturer] peut tuer l'app en arrière-plan. Fais ces 2 étapes : (1) [step 1 vendor-specific], (2) [step 2 vendor-specific]. Plus d'info : dontkillmyapp.com/[vendor]" + CTA "OK j'ai fait" → session démarre
  - Si autre OEM / iOS → skip écran OEM, session démarre directement
  - Flag SharedPreferences `oem_guidance_seen` — montre une seule fois par device
- **Après OS prompt refusée (GPS-07)** :
  - Écran permission-denied : "MirkFall a besoin de la localisation pour révéler le brouillard. Tu l'as refusé — tu peux l'accorder dans les paramètres système."
  - CTA "Ouvrir les paramètres" → deep-link `openAppSettings()` de `permission_handler`
  - CTA secondaire "Retour" → session list, session non démarrée
- **Écran OEM guidance toujours accessible post-first-run** : depuis `/settings` → "Aide : batterie & arrière-plan" (réutilise le composant)

### Tracking behavior : 5m distance filter, 50m accuracy reject, write immédiat

- **`kDefaultDistanceFilterMeters = 5`** dans `lib/config/constants.dart`. Dense volontairement — user veut une trace fine pour la qualité du fog Phase 09. Conso batterie plus élevée à profiler en POC.
- **Slider distanceFilter dès Phase 05** dans `/settings` minimal : range 2–100 m (en pas de 1 m ou snap sur 5/10/25/50/100). Persisté via `SharedPreferences`. Phase 13 OPT-02 étendra ce même écran au lieu de le recréer.
- **Accuracy filter** : reject tout fix avec `accuracy > 50.0` mètres. Constante `kMaxAcceptableAccuracyMeters = 50.0`. Source : indoor GPS typiquement >100m, outdoor open-sky <15m, urban canyon 20–40m — 50m est la frontière signal/bruit.
- **Write cadence** : 1 fix accepté = 1 row insérée immédiatement dans `t_fixes`. Pas de batch — simple, zero data loss en cas de kill OS entre batches, conso I/O négligeable à 1 fix / ~5–20 sec.
- **Stationary dedup** : Claude's discretion (probablement skip si delta < 1m ET delta_time < 10s, sinon write). À préciser en plan.
- **Timeout first-fix** : affichage "En attente du GPS…" si aucun fix depuis plus de 30 sec depuis start. Constante `kFirstFixTimeoutSeconds = 30`. N'empêche pas le tracking de continuer.

### Schema DB : nouvelle table `t_fixes` via migration V2→V3

- **Phase 05 ship la migration Drift V2 → V3** qui ajoute `t_fixes` (un row par fix GPS écrit) :
  - `id: TEXT PRIMARY KEY` (ULID préfixé `fix_`, ex: `fix_01HR...`)
  - `session_id: TEXT NOT NULL REFERENCES t_sessions(id) ON DELETE CASCADE`
  - `recorded_at_utc: INTEGER NOT NULL` (unix ms)
  - `recorded_at_offset_minutes: INTEGER NOT NULL`
  - `latitude: REAL NOT NULL`
  - `longitude: REAL NOT NULL`
  - `accuracy_meters: REAL NOT NULL`
  - `altitude_meters: REAL NULLABLE`
  - `speed_mps: REAL NULLABLE`
  - `heading_degrees: REAL NULLABLE`
  - Index : `idx_t_fixes_session_id` + composite `idx_t_fixes_session_recorded_at`
- **Nouvelle migration V2→V3** s'inscrit dans le framework Drift Phase 03 (`MigrationStrategy.onUpgrade` + pré-backup + sanity row-count). V1→V2 fictive (notes) reste en place.
- **JsonMigrator** : idem, V2→V3 JSON migration à ajouter pour cohérence (fixes sortent potentiellement en export Phase 13). Shape exact du payload = Claude's discretion (probablement `"fixes": [{recordedAt, lat, lon, accuracyM, ...}]`).
- **`FixStore` port** dans `lib/domain/fixes/fix_store.dart` + `DriftFixStore` impl dans `lib/infrastructure/stores/`.
- **Entité Freezed `Fix`** dans `lib/domain/fixes/fix.dart` avec `@Assert` invariants (lat ±90, lon ±180, accuracy ≥ 0).

### Notification persistante : titre seul, pas d'action inline

- **Android foreground service notification** via `flutter_local_notifications` 21.0.0 :
  - Title: `MirkFall • [session displayName]`
  - Body: vide (ou `Suivi actif`) — pas de compteur de fixes en temps réel (OS notification churn)
  - Pas d'action button inline (décision utilisateur)
  - Tap notif = ouvre app → route `/sessions/:id`
  - Channel importance: Low (pas de son/vibration, persistante mais discrète)
- **iOS** : équivalent via `UILocalNotification` ou `UNUserNotificationCenter` silent background notification maintenue tant que background mode `location` actif. Pas d'action inline.
- **Dismiss** : le seul chemin = Stop la session depuis l'app (→ bandeau ou `/sessions/:id`). La notif disparaît immédiatement au Stop.

### Auto-resume post-kill OS : notif "tap pour reprendre", pas de reprise silencieuse

- **Android** : `BroadcastReceiver` `BOOT_COMPLETED` déclaré dans `AndroidManifest.xml`. Au boot, le receiver check la DB (via isolate Drift) — si une session avait `status='active'` au moment du kill, push une `flutter_local_notifications` locale "Session [nom] interrompue par le système. Tap pour reprendre le tracking". Tap → ouvre l'app, redémarre le foreground service + réactive la session. Si l'user ignore la notif, elle reste (sticky) jusqu'à action ou reboot suivant.
- **iOS** : pas de `BOOT_COMPLETED` équivalent direct. Utilise `significant-change location service` (faible coût batterie, réveille l'app périodiquement) comme watchdog — quand l'app est réveillée par iOS (~toutes les 500m / 5 min), elle check la DB : si session active sans fix récent (> 5 min), push notif locale équivalente "Session interrompue, tap pour reprendre". Alternative si SCLS trop agressif : `region monitoring` sur la dernière position connue. À trancher en RESEARCH.
- **Explicit user control** : aucune reprise automatique silencieuse. L'user reste au courant via la notif + confirme le reprise manuellement.

### Permission + Store copy : FINAL en Phase 05

- **`NSLocationWhenInUseUsageDescription`** (iOS Info.plist, texte final) :
  > MirkFall utilise ta position pour révéler le brouillard de ta carte d'exploration personnelle. Tout reste sur ton téléphone — aucun serveur, aucun partage, aucune publicité.
- **`NSLocationAlwaysAndWhenInUseUsageDescription`** (iOS Info.plist, texte final) :
  > MirkFall continue à suivre ta position en arrière-plan pour que ta carte d'exploration se révèle pendant que ton téléphone est dans ta poche, écran éteint — comme une vraie sortie. Tout reste sur ton téléphone. Aucune donnée n'est envoyée ni partagée.
- **`docs/store-review-rationale.md`** rédigé Phase 05 avec sections :
  - Project description (1 paragraphe : journal personnel d'exploration géographique, local-first, open-source sous GOSL v1.0)
  - Why Always location is required (justification technique : exploration session peut durer heures, écran éteint, pas de push alternatif)
  - Data handling (zero server, zero sharing, zero analytics, zero telemetry, vérifié par airplane-mode smoke test QUAL-05 Phase 15)
  - Source code accessibility (lien GitHub, licence GOSL v1.0)
  - Contact email (à remplir par l'user)

### POC QUAL-01/02 : devices + protocole + validation

- **Android devices POC** : Pixel 4a + Pixel 6 Pro (tous deux stock Android AOSP). Pixel 4a = minSdk-proche, 6 Pro = device récent Tensor. Couvre "ça tient sur Android propre".
- **iOS device POC** : iPhone 17 Pro (iOS récent, Dynamic Island-capable). Sideload via SideStore après build CI macos-latest non-signé → download artifact GitHub Releases.
- **Protocole 30-min walk** : user démarre session via UI, verrouille l'écran, met le téléphone en poche, sort 30 min (marche, transport, mix) avec un comportement déplacement réel. Stop la session au retour. Dump DB via `tool/inspect_db.sql` ou `tool/walk_db.dart`. Pas de desk-stationnaire avec `adb emu geo fix` — roadmap exige un device réel + déplacement réel.
- **Critères succès mesurables** :
  - >= 50 fixes écrits sur 30 min (≈ 1 fix toutes les 36 sec, cohérent avec 5m filter + marche ~4km/h)
  - Intervalle max entre deux fixes consécutifs < 3 min (pas de trou prolongé = pas de kill OS silencieux)
  - Dernier fix timestamp > (start + 29 min) (session n'a pas été killed avant la fin)
  - Visualisation : `tool/plot_session_fixes.py` lit la DB, exporte le trajet sur une tile map (OSM static image) → user valide visuellement la cohérence (pas de sauts aberrants, le trajet ressemble à la balade réelle)
- **Document d'évidence POC** : `docs/qual-01-02-poc.md` commité après chaque run, contenant :
  - Device + OS version + build number MirkFall
  - Datetime start/stop + durée
  - Row count `t_fixes` + histogramme intervalles
  - Path image PNG export par le script Python
  - Verdict : PASS / FAIL + notes
- **Gap OEM battery-killer documenté** : ROADMAP.md Phase 05 SC#1 sera annoté "partial : Pixel-validated; OEM POC (Xiaomi/Samsung/Huawei/OnePlus) deferred to Phase 15 polish ou emprunt device pré-release". Phase 05 SHIP l'écran GPS-08 OEM guidance défensif (pour tout user qui installerait sur OEM), mais la VALIDATION empirique OEM est reportée.

### Outil Python `tool/plot_session_fixes.py`

- Script Python 3.x standalone (pas de dep Flutter, pas de runtime projet).
- Lit `<app_support>/mirkfall.db` (path passé en arg) via `sqlite3` stdlib.
- Query : `SELECT latitude, longitude, recorded_at_utc FROM t_fixes WHERE session_id = ? ORDER BY recorded_at_utc`.
- Dessine le trajet sur tile map OSM statique (via package `staticmap` ou `contextily` ou équivalent MIT/BSD — **audit licence obligatoire avant ajout**, ajouter à `tool/requirements.txt` séparé de `pubspec.yaml`).
- Output : PNG timestampé dans `docs/poc-artifacts/`.
- **Note :** script Python = hors du Flutter app proper. Vit dans `tool/`. Ses deps Python ne sont PAS dans `pubspec.yaml` ni `DEPENDENCIES.md` (qui couvre seulement les deps Dart qui se retrouvent dans le binaire distribué). Une petite entrée dans `tool/README.md` documente les deps Python + licence.

### Wiring ProviderScope + AppDatabase dans main.dart

- **Phase 03 CONTEXT a déféré ce wiring à Phase 05** — ici est la phase qui a le premier consommateur productif (`ActiveSessionController`).
- Dans `lib/main.dart`, après `FileLogger.bootstrap()` et avant `runApp`, on ne peut pas await `appDatabaseProvider` (c'est un Riverpod async provider — il se résout quand son premier watcher le demande). Deux options :
  - (a) **Laisse Riverpod résoudre lazy** : `ProviderScope(child: MirkFallApp())` comme aujourd'hui, l'`ActiveSessionController` watch `appDatabaseProvider.future` et gère le loading state côté UI (spinner pendant l'ouverture DB).
  - (b) **Pré-chauffe explicite** : `ProviderContainer` temporaire créé dans `main`, `await container.read(appDatabaseProvider.future)`, puis `UncontrolledProviderScope(container: ...)` autour de `MirkFallApp`. DB garantie ouverte avant runApp.
- **Décision** : option (a) — simple, garde Riverpod pattern pure, le splash screen natif Android/iOS fait office de loading state. Si le spinner first-frame est visible et moche, on passe à option (b) en retrofit.

### Claude's Discretion

- Composition exacte des widgets (spacings, typo sizes, layout details)
- Format exact du chrono session active (mm:ss vs HH:mm:ss selon durée)
- Icon exacte de la notification persistante (mipmap ou vector)
- Channel name + ID Android notification (probablement `mirkfall_session_tracking`)
- Stratégie stationary dedup exacte (seuils delta_distance + delta_time)
- Choix iOS watchdog `significant-change` vs `region monitoring` (arbitrage RESEARCH sur conso vs fiabilité)
- Package Flutter Dynamic Island à auditer (ou platform channel Swift custom si aucun ne passe l'audit GOSL)
- Shape exact de la migration V2→V3 (comment on ajoute `t_fixes` via raw `customStatement` comme V1→V2 l'a fait, ou via Drift `m.createTable`)
- Taxonomie exceptions GPS (à ajouter à `lib/domain/errors/`) : `LocationPermissionDeniedException`, `LocationServiceDisabledException`, `TrackingBackgroundKilledException` (pour la branche post-kill)
- Package Python pour tile map dans `tool/plot_session_fixes.py` (audit licence)
- Layout exact du slider `/settings` Phase 05 (simple Column ou ListView anticipant Phase 13 extension)
- Copy exact des boutons (FR vs EN — probablement FR car l'user est FR, à confirmer si polyglot plus tard)
- Format du SharedPreferences key namespace (préfixe `mirkfall.` ou plat)

</decisions>

<specifics>
## Specific Ideas

- **Pixel 4a + 6 Pro + iPhone 17 Pro** sont les trois devices physiques sur lesquels l'utilisateur valide. Le 17 Pro active la voie Dynamic Island.
- **Dynamic Island iOS** — mention verbatim de l'utilisateur : "mais sur ios on devrais utiliser la dynamic island pour dire qu'une session est active". À intégrer si faisable avec dep GOSL-compatible, fallback bandeau sinon.
- **Tool Python pour valider visuellement** — "let's draw the path on a map (with a custom tool, probably a python script we'll make) so I can validate what it recorded" — idée UX d'auto-validation visuelle post-POC, préférée aux métriques numériques seules.
- **distanceFilter 5m + slider Phase 05** — densité de trace privilégiée sur autonomie batterie à ce stade. Le user veut pouvoir régler et voir l'impact pendant la POC QUAL-01/02.
- **Notification volontairement sobre** — titre seul, pas de bouton Stop inline, pas de compteur temps réel. User veut une notif discrète, pas une dashboard OS.
- **Pas de reprise silencieuse post-kill** — le user choisit une notif "tap pour reprendre" plutôt qu'un auto-restart invisible. Préfère un contrôle explicite à la magie.
- **Copy rationale angle** : "journal personnel d'exploration, local-only, zero telemetry, open-source GOSL". Défendable sur App Store + Play Store review.
- **Session list = home + FAB +** : workflow usuel, zero détour. Le user sait pourquoi il ouvre l'app, la liste des sessions est le contexte immédiat.
- **Splash-logo 3s → deferred Phase 15** : idée exprimée pendant la discussion ("j'aimerais bien avoir un splashscreen avec un logo pendant 3 secondes"), capturée mais hors scope 05.
- **Gap OEM — Pixel-validated, OEM POC déferré** : le user préfère avancer plutôt que se bloquer sur un device qu'il n'a pas. Décision pragmatique documentée dans ROADMAP.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 01–04)

- **`pubspec.yaml` : deps Phase 05 déjà pinnées et auditées** :
  - `geolocator: 14.0.2` — GPS fg/bg, BSD
  - `permission_handler: 12.0.1` — prompt OS + `openAppSettings()`, MIT
  - `flutter_local_notifications: 21.0.0` — notif persistante Android + iOS, BSD
  - `shared_preferences: 2.5.5` — flags `permission_flow_completed`, `oem_guidance_seen`, `distanceFilter` user override
  - `flutter_riverpod: 3.3.1` + `riverpod_annotation: 4.0.2` — `@Riverpod` providers pour stores + controllers
  - `go_router: 16.0.0` — nouvelles routes `/sessions`, `/sessions/:id`, `/settings`, `/permissions/denied`, `/permissions/oem`
  - `drift: 2.32.1` + `drift_flutter: 0.3.0` — migration V2→V3, table `t_fixes`
- **`lib/config/constants.dart`** : déjà ouvert avec slot commenté `kDefaultRevealRadiusMeters (Phase 09)`. Phase 05 ajoute : `kDefaultDistanceFilterMeters = 5`, `kMaxAcceptableAccuracyMeters = 50.0`, `kFirstFixTimeoutSeconds = 30`, `kNotificationChannelId = 'mirkfall_session_tracking'`, `kSessionActiveBannerHeightDp = 40.0`.
- **`lib/domain/sessions/`** : entité `Session` Freezed + `SessionStatus` enum + `SessionStore` port + exceptions (`SessionNotFoundException`, `ConcurrentActivationException`, `InvalidSessionTransition`) déjà livrés Phase 03. Phase 05 CONSOMME sans modifier.
- **`lib/infrastructure/stores/drift_session_store.dart`** : `DriftSessionStore` impl complète avec SqliteException 2067 wrap scope (insert/update/activate) + throw `SessionNotFoundException` sur activate/deactivate 0 rows. Phase 05 CONSOMME.
- **`lib/infrastructure/db/app_database.dart`** : schema V2, `onBeforeUpgrade` hook wiré vers `DbBackupService`, `SchemaSanityChecker` post-upgrade. Phase 05 AJOUTE la table `t_fixes` via migration V2→V3 dans le même pattern (`customStatement('CREATE TABLE t_fixes ...')` ou équivalent Drift-idiomatique selon ce que RESEARCH décide).
- **`lib/application/providers/app_database_provider.dart`** : `appDatabaseProvider` async Riverpod `keepAlive: true` — Phase 05 l'AppDatabase est consommée via `ref.watch(appDatabaseProvider.future)` par les controllers.
- **`lib/application/providers/session_store_provider.dart`** : `sessionStoreProvider` déjà wiré. Phase 05 l'utilise comme-dep dans `activeSessionControllerProvider`.
- **`lib/presentation/router.dart`** : `appRouterProvider` `@riverpod` avec 3 routes. Phase 05 ajoute ~5 routes sessions/settings/permissions.
- **`lib/presentation/screens/debug_menu_screen.dart`** : pattern Scaffold + ListView + tiles clickables — réutilisable pour SessionListScreen.
- **`lib/main.dart`** : `runZonedGuarded` + `ProviderScope` pattern armé Phase 01 + fixé Phase 04. Phase 05 ajoute zero modification structurelle.
- **`lib/infrastructure/logging/file_logger.dart`** : `Logger('application.sessions')`, `Logger('infrastructure.gps')`, `Logger('infrastructure.notifications')` écrivent dans `<app_docs>/logs/` — Phase 05 instrumente massivement (start/stop/fix/kill/resume) via ces loggers.
- **Tests `dart test` (Ubuntu CI)** : pattern domain + infrastructure tests via `NativeDatabase.memory()` déjà en place. Phase 05 étend avec `t_fixes` + `FixStore` tests + migration V2→V3 tests (via `drift_dev schema dump` pattern Phase 03).
- **`.github/workflows/ci.yml` jobs `gates / android / ios`** : structure en place. Phase 05 ajoute zero nouveau job, les tests `dart test` s'ajoutent au job `gates`. Le build iOS `macos-latest` produit un artifact que l'user download pour sideload POC.
- **Info.plist existants TODO** : `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription` ont des placeholders "TODO Phase 05" — Phase 05 les remplace par le copy final (ci-dessus).
- **`AndroidManifest.xml`** actuellement minimal (activity MainActivity, pas de permissions, pas de service, pas de receiver). Phase 05 ajoute : `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS` (Android 13+), `RECEIVE_BOOT_COMPLETED`, déclaration `<service android:name=".SessionTrackingService" android:foregroundServiceType="location" />`, déclaration `<receiver android:name=".BootCompletedReceiver" android:exported="false">`.
- **`docs/store-review-rationale.md`** : le fichier n'existe pas encore. Phase 05 le crée (QUAL-03).
- **`tool/walk_db.dart` + `tool/inspect_db.sql`** : outils DB inspector ajoutés Phase 04, utiles pour la POC (dump contenu `t_fixes` post-walk).

### Established Patterns

- **CLAUDE.md règles** (toutes confirmées des phases précédentes) :
  - `xxxFilename` / `xxxFileName` / `xxxBasename` / `xxxDir` nommage
  - `p.join()` toujours
  - Pas de magic number hors `constants.dart`
  - Sealed classes + pattern match (exceptions GPS à ajouter en sealed hierarchy)
  - Injection via constructor + Riverpod, pas de singleton caché
  - Type hints stricts, pas de `dynamic`, `Object?` si inconnu
  - `analysis_options.yaml` strict : zero warning toléré
  - Timeouts sur appels externes (constants.dart slot pour `kHttpTimeout` Phase 07, Phase 05 ajoute `kFirstFixTimeoutSeconds`)
  - Pin exact deps, audit DEPENDENCIES.md pour chaque nouvelle
- **Test runner split** : `dart test` pour pure Dart + Drift in-memory (Phase 03 pattern), `flutter test` widget tests pour screens, iOS real-device POC pour QUAL-02
- **Atomic commits par tâche** : `feat(05-XX): ...`, `test(05-XX): ...`, `docs(05-XX): ...`
- **Layer READMEs** : si Phase 05 crée `lib/domain/fixes/`, `lib/domain/gps/` (controller port), `lib/application/controllers/`, y ajouter des READMEs courts (règles import inter-layers)
- **`@Assert` invariants Freezed** : `Fix` entity asserts (lat ±90, lon ±180, accuracy ≥ 0, offset ±720/+840)
- **Drift `@TableIndex.sql` pour partial unique indices** : pattern Phase 03, réutilisé potentiellement pour `idx_t_fixes_session_recorded_at`
- **Extension type IDs** : `FixId(String value)` avec préfixe `fix_`, `sessionIdFromJson`/`sessionIdToJson` converters pattern
- **Exceptions domain typées `implements Exception`** (jamais Error) — ajouter `LocationPermissionDeniedException`, `LocationServiceDisabledException` dans `lib/domain/errors/`

### Integration Points

- **`lib/main.dart`** : zero modification structurelle (option (a) wiring Riverpod lazy). Si retrofit nécessaire (option b), modif localisée à `main()`.
- **`lib/presentation/router.dart`** : ajouter routes `/sessions`, `/sessions/:id`, `/settings`, `/permissions/denied`, `/permissions/oem`.
- **`lib/presentation/screens/`** : nouveaux screens `session_list_screen.dart`, `session_detail_screen.dart`, `settings_screen.dart`, `permission_rationale_screen.dart`, `permission_denied_screen.dart`, `oem_guidance_screen.dart`.
- **`lib/presentation/widgets/`** : nouveau widget `active_session_banner.dart` (cross-route indicator) + layout shell dans `app.dart` ou `router.dart` pour l'injecter.
- **`lib/domain/fixes/`** : nouveau sous-arbre domain : `fix.dart` (Freezed entity), `fix_store.dart` (port), `fix_id.dart` (extension type ID).
- **`lib/domain/gps/`** : nouveau sous-arbre : `location_stream.dart` (port abstraction over geolocator), `gps_errors.dart` (sealed exceptions).
- **`lib/domain/sessions/active_session.dart`** : controller pattern (entity pour l'état courant en mémoire + mutations).
- **`lib/application/controllers/active_session_controller.dart`** : `@Riverpod(keepAlive: true)` `ActiveSessionController` — orchestrateur principal Phase 05. Start/Stop session, consume `LocationStream`, write `Fix`s via `FixStore`, merge reveal mask via `RevealedTileStore` (préparation Phase 09, à confirmer scope — peut-être juste buffer les fixes et laisser Phase 09 brancher le reveal).
- **`lib/infrastructure/gps/`** : `geolocator_location_stream.dart` (impl `LocationStream` via `geolocator`).
- **`lib/infrastructure/notifications/`** : `session_notification_service.dart` (wrapper `flutter_local_notifications` avec le channel `kNotificationChannelId`).
- **`lib/infrastructure/platform/oem_detector.dart`** : `Build.MANUFACTURER` via platform channel ou `device_info_plus` (audit dep).
- **`lib/infrastructure/stores/drift_fix_store.dart`** : impl `FixStore` pour `t_fixes`.
- **`lib/infrastructure/db/migrations/v2_to_v3_fixes.dart`** : migration Drift ajoutant `t_fixes`.
- **`lib/infrastructure/db/app_database.dart`** : bump `schemaVersion` to 3, enregistrer la nouvelle migration dans `onUpgrade`.
- **`android/app/src/main/AndroidManifest.xml`** : permissions + service + receiver (détails ci-dessus).
- **`android/app/src/main/kotlin/.../MainActivity.kt`** (ou Java) : platform channel pour `Build.MANUFACTURER` si pas de dep Flutter.
- **`android/app/src/main/kotlin/.../SessionTrackingService.kt`** : foreground service bindé par `flutter_local_notifications` ou via plugin `flutter_background_service` (audit — ALTERNATIVE: pur Kotlin service déclenché par geolocator). À trancher RESEARCH.
- **`android/app/src/main/kotlin/.../BootCompletedReceiver.kt`** : receiver qui check la DB + push notif "tap pour reprendre".
- **`ios/Runner/Info.plist`** : copy final UsageDescription (remplacement TODO).
- **`ios/Runner/Info.plist` + `ios/Runner.xcodeproj`** : ajout `UIBackgroundModes` = `location`, `fetch` (pour significant-change), + entitlements si Dynamic Island.
- **`ios/Runner/AppDelegate.swift`** : setup ActivityKit + significant-change watchdog si on va sur cette voie.
- **`docs/store-review-rationale.md`** : nouveau fichier, rédigé Phase 05.
- **`docs/qual-01-02-poc.md`** : artifact POC commité après chaque run device.
- **`tool/plot_session_fixes.py`** : script Python standalone + `tool/requirements.txt` + entrée `tool/README.md`.
- **`test/`** : `test/domain/fixes/`, `test/infrastructure/gps/`, `test/infrastructure/notifications/`, `test/application/controllers/active_session_controller_test.dart`, `test/infrastructure/db/v2_to_v3_migration_test.dart`, `test/widget/session_list_screen_test.dart`, etc.
- **`test/fixtures/drift_schemas/drift_schema_v3.json`** : nouveau dump frozen via `dart run drift_dev schema dump`.
- **`drift_schemas/`** (racine) : `drift_schema_v3.json` ajouté.
- **`.github/workflows/ci.yml` job `gates`** : les nouveaux tests s'ajoutent au `dart test` existant, pas de nouveau step (le Phase 03 pattern couvre `test/` top-level).
- **`DEPENDENCIES.md`** : entrées pour toute nouvelle dep non déjà pinnée (ex: `device_info_plus` si choisi, ou un package Dynamic Island si choisi, ou un package boot receiver helper). Audit licence + télémétrie obligatoire.

</code_context>

<deferred>
## Deferred Ideas

- **Splash screen Flutter avec logo 3 s** → Phase 15 polish (user l'a demandé pendant la discussion : "j'aimerais bien avoir un splashscreen avec un logo pendant 3 secondes au debut"). Pas de requirement V1.0 qui l'exige. Phase 15 avec icône d'app finale + copy stores est le bon moment.
- **POC sur OEM battery-killer réel (Xiaomi/Samsung/Huawei/OnePlus)** → Phase 15 ou emprunt device pré-release. ROADMAP.md SC#1 sera annoté "partial : Pixel-validated; OEM POC deferred". L'écran GPS-08 guidance OEM est shipped défensivement en Phase 05 malgré l'absence de POC empirique OEM.
- **Full settings screen global (OPT-03..07)** → Phase 13. Phase 05 crée `/settings` minimal avec uniquement le slider `distanceFilter` (OPT-02 partiel). Phase 13 étend le même écran : sélecteur mirk style (OPT-03), gestion styles importés (OPT-04), gestion catégories markers (OPT-05), import/export (OPT-06), activation logger debug (OPT-07).
- **Controller `ActiveSessionController` integration avec `RevealedTileStore.mergeMask`** → peut rester en Phase 05 (buffer naïf : chaque fix → compute reveal mask 5m → merge) ou être déferré Phase 09 (Phase 05 ne fait qu'écrire les fixes, Phase 09 branche le reveal). À trancher en RESEARCH/plan selon la complexité du couplage avec `computeRevealMask` (UnimplementedError Phase 03, finalisé Phase 09). **Recommandation initiale** : Phase 05 NE TOUCHE PAS à `RevealedTileStore`. Les fixes sont écrits bruts dans `t_fixes`, Phase 09 ajoute un consommateur qui lit `t_fixes` + appelle `mergeMask`. Garde Phase 05 focalisée sur le risque #1 (bg tracking survit) sans mélanger avec le risque #2 (fog perf).
- **Stats distance/% du monde révélé (STAT-*)** → V1.1+, out of scope V1.0.
- **Multi-langue (FR/EN)** → V1.x (I18N-*). Phase 05 ship en FR uniquement.
- **QUAL-05 airplane-mode smoke test (zero outgoing requests)** → Phase 15 polish (mapped to Phase 15 in REQUIREMENTS.md).
- **Dynamic Island iOS** : si audit de package Flutter ActivityKit échoue (télémétrie, licence non-compatible GOSL), drop le Dynamic Island entirely et garder uniquement le bandeau Flutter. Pas un blocker Phase 05.
- **Stationary dedup heuristic fine-tuning** → observer pendant POC QUAL-01/02 puis ajuster si trop/pas assez de fixes dedup.
- **Rotation logs par âge (14 jours, etc.)** → Phase 15 polish (déjà noté Phase 01 deferred, confirmé ici).
- **Debug toggle "Verbose tracking logs"** dans debug menu — possiblement utile pour le POC QUAL-01/02, mais `Logger('infrastructure.gps')` est déjà contrôlable via le toggle `debug_logging_enabled` existant du debug menu. Pas de flag dédié.
- **Geocoding inverse (nom de lieu à partir de lat/lon)** → jamais dans V1.0 (réseau, télémétrie risk). Future work éventuelle avec deps offline only.
- **Pré-import markers pour POC** (ex: "test une session avec déjà 3 markers pré-importés") → Phase 11 (markers) + Phase 13 (import flow). Pas Phase 05.
- **Notification "fix count live"** (si l'user change d'avis sur le texte sobre) → deferable Phase 15 UI polish.

</deferred>

---

*Phase: 05-gps-session-lifecycle*
*Context gathered: 2026-04-19*
