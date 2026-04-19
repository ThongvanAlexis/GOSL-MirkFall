# Phase 05: GPS & Session Lifecycle - Research

**Researched:** 2026-04-19
**Domain:** Background GPS tracking (Android foreground service + iOS background location mode), session lifecycle UI, Drift schema migration V2→V3, permission flow UX, persistent notification, auto-resume post-kill
**Confidence:** HIGH on core stack (geolocator / permission_handler / flutter_local_notifications / Drift patterns already pinned and audited project-side); MEDIUM on OEM-specific behaviour (no Xiaomi/Samsung device for POC — gap formally accepted by CONTEXT.md); MEDIUM on iOS auto-resume watchdog choice (significant-change vs region monitoring arbitrage empirical); LOW on one niche question (Dynamic Island package licence audit — MIT is ostensibly fine but the package has transitive network call via `LiveActivityFileFromUrl` that must be walled off — see §Open Questions).

## Summary

Phase 05 carries the project's #1 risk: prove that a start → background (screen off, 30 min) → stop cycle actually writes GPS fixes on Android OEM and iOS real devices. The stack is locked — `geolocator 14.0.2` + `permission_handler 12.0.1` + `flutter_local_notifications 21.0.0` are all pinned, licence-audited BSD/MIT, and already in `pubspec.yaml`. The plan consumes them; it does not add `flutter_background_service`, `background_locator_2`, or `flutter_background_geolocation` (that last one was explicitly rejected in Phase 03 decisions: commercial licence incompatible with GOSL).

The critical technical facts:

1. **Android foreground service is handled by geolocator itself** — not a separate plugin. Setting `foregroundNotificationConfig` inside `AndroidSettings` makes `geolocator_android` promote its internal service to foreground and show a persistent notification. This avoids `flutter_background_service` (a separate, heavier dep) entirely. The `flutter_local_notifications` package is used ONLY for the auto-resume "tap to reprendre" notification (post-kill branch) and the ongoing indicator if we want richer control than geolocator's built-in notification channel.

2. **iOS background requires BOTH Info.plist keys AND runtime config.** `UIBackgroundModes: location`, `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` (already TODO-ed) in Info.plist; `allowsBackgroundLocationUpdates: true` + `pauseLocationUpdatesAutomatically: false` + `showBackgroundLocationIndicator: true` in `AppleSettings`. The `pauseLocationUpdatesAutomatically` default in community examples is `true` (battery-friendly) but CONTEXT.md implicitly wants continuous tracking for walks — **must flip to `false`** to prevent iOS from silently pausing during stationary moments (café stops).

3. **Permission request is a two-step chain, not a single call.** `Permission.locationAlways.request()` on Android 10+ is IGNORED if `Permission.locationWhenInUse` hasn't been granted first. The only valid sequence is: `whenInUse.request()` → user grants → `locationAlways.request()` → OS presents the second dialog ("Change to Always Allow / Keep Only While Using"). The plan's permission flow screen must orchestrate this explicitly.

4. **Drift V2→V3 migration (add `t_fixes` table) should use `m.createTable(fixes)` via generated `$FixesTable` reference — not `customStatement`.** The V1→V2 path used raw SQL because V1 was an `ALTER TABLE ADD COLUMN` (well-supported idiom, no generator dependency). For a new table, `m.createTable` gets full CHECK constraints, indexes via `@TableIndex.sql`, and column-mapping correctness for free. The `SchemaVerifier` will byte-compare against `drift_schema_v3.json` (produced by `dart run drift_dev schema dump`), so the CREATE TABLE shape must match the generator emission exactly — another reason to prefer the generator path.

5. **Android 14+ requires `FOREGROUND_SERVICE_LOCATION` permission AND `android:foregroundServiceType="location"` in the `<service>` declaration** — both are strict, missing either crashes at startup with `ForegroundServiceStartNotAllowedException` (bg→fg promotion) or `SecurityException` (missing permission).

6. **Post-kill auto-resume**: Android `BOOT_COMPLETED` can launch a foreground-service of type `location` only if the app has `ACCESS_BACKGROUND_LOCATION`; this path is fragile on OEMs. iOS has no `BOOT_COMPLETED` equivalent — must use `significant-change location service` (500m threshold, ≥5 min interval, cheap on battery) as a watchdog to wake the app, detect a stale active session, and push a local notification. Both platforms follow the **explicit user control** rule from CONTEXT.md: no silent resume, always a notification.

**Primary recommendation:** Consume the already-pinned dep stack. Build the GPS pipeline as a single `ActiveSessionController` (`@Riverpod(keepAlive: true)`) that owns the `StreamSubscription<Position>`, a `FixStore` port abstraction, and the notification lifecycle. The domain layer gets `LocationStream` port + `GpsFix` entity (Freezed, `@Assert` invariants) so geolocator can be replaced in tests. Expose platform-specific settings via a `LocationSettingsFactory` seam that returns `AndroidSettings` on Android and `AppleSettings` on iOS, keeping the controller platform-agnostic. The validation strategy is three-tiered: (a) pure Dart unit tests on the controller (feed a `Stream<Position>` via a fake), (b) widget tests on the session UI (mocked controller), (c) real-device POC on Pixel 4a / 6 Pro / iPhone 17 Pro with a Python script (`tool/plot_session_fixes.py`) that reads `t_fixes` and draws the trajet on an OSM static tile — visual validation of the walk.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**UI : Session list = home, pas de carte en 05**

- Route `/` = SessionListScreen : remplace `PlaceholderHomeScreen`. Liste sessions ordonnée `startedAtUtc DESC`. FAB "+" ouvre dialog/bottom-sheet de création (displayName + start immédiat ou juste create). Tap session = route `/sessions/:id`.
- Empty state premier lancement : message + CTA "Créer ma première session" (aligne avec le FAB).
- `/sessions/:id` = SessionDetailScreen : si session active → status dashboard texte (chrono depuis `startedAtUtc`, last fix lat/lon/accuracy/timestamp, #fixes écrits, #parent tiles touchés, `distanceFilter` actif) + bouton Stop + menu (rename). Si stopped → résumé (durée totale, #fixes final, "Carte viendra Phase 07" placeholder léger, bouton delete).
- Règles session active :
  - Rename = autorisé (simple UPDATE `displayName`)
  - Delete = bloqué avec message "Arrête la session d'abord"
  - Start d'une autre session = stop auto de l'active (SESS-06 DB partial unique index déjà enforced Phase 03, maintenant testé end-to-end)
  - Noms dupliqués autorisés (ULID différencie)

**UI : Indicateur session active cross-route**

- Bandeau slim top-of-screen (~40dp) : "Session active : [nom] • Stop". Tap = navigue `/sessions/:id`. Bouton Stop inline = arrête. Présent sur toutes les routes sauf `/sessions/:id` elle-même.
- iOS Dynamic Island (nice-to-have si faisable) : sur iPhone 14 Pro+ (incluant 17 Pro du user), afficher un Live Activity compact avec `[nom session] • [chrono]`. Faisabilité + audit licence package à investiguer. **Fallback = bandeau Flutter**. Si le package communautaire ne passe pas l'audit GOSL/télémétrie, on drop Dynamic Island et ship uniquement le bandeau. Aucun blocker.

**Permission flow : wizard full-screen 1 écran + OEM guidance ciblée**

- Trigger : click "Start" sur la PREMIÈRE session que l'user démarre (SharedPreferences flag `permission_flow_completed`). Jamais re-promptée ensuite sauf si permission révoquée système → denied-recovery screen.
- Écran rationale (1 full-screen) : titre "Pour suivre ton exploration" + 3-4 lignes copy + bouton primary "Continuer" → OS prompt + bouton secondary "Pas maintenant" → retour session list.
- Après OS prompt accordée : détection `Build.MANUFACTURER` ; si match Xiaomi/Redmi/POCO/Samsung/Huawei/OnePlus/OPPO/Realme → écran OEM guidance ciblé ; autre OEM / iOS → skip.
- Après OS prompt refusée (GPS-07) : écran permission-denied avec CTA "Ouvrir les paramètres" → `openAppSettings()`.
- Écran OEM guidance toujours accessible post-first-run depuis `/settings` → "Aide : batterie & arrière-plan" (réutilise le composant).

**Tracking behavior : 5m distance filter, 50m accuracy reject, write immédiat**

- `kDefaultDistanceFilterMeters = 5` dans `lib/config/constants.dart`. Dense volontairement.
- Slider distanceFilter dès Phase 05 dans `/settings` minimal : range 2–100 m.
- Accuracy filter : reject tout fix avec `accuracy > 50.0` mètres. Constante `kMaxAcceptableAccuracyMeters = 50.0`.
- Write cadence : 1 fix accepté = 1 row insérée immédiatement. Pas de batch.
- Stationary dedup : Claude's discretion (probablement skip si delta < 1m ET delta_time < 10s).
- Timeout first-fix : affichage "En attente du GPS…" si aucun fix depuis plus de 30 sec depuis start. Constante `kFirstFixTimeoutSeconds = 30`.

**Schema DB : nouvelle table `t_fixes` via migration V2→V3**

- Phase 05 ship la migration Drift V2 → V3 qui ajoute `t_fixes` :
  - `id: TEXT PRIMARY KEY` (ULID préfixé `fix_`)
  - `session_id: TEXT NOT NULL REFERENCES t_sessions(id) ON DELETE CASCADE`
  - `recorded_at_utc: INTEGER NOT NULL` (unix ms)
  - `recorded_at_offset_minutes: INTEGER NOT NULL`
  - `latitude: REAL NOT NULL`, `longitude: REAL NOT NULL`, `accuracy_meters: REAL NOT NULL`
  - `altitude_meters: REAL NULLABLE`, `speed_mps: REAL NULLABLE`, `heading_degrees: REAL NULLABLE`
  - Index : `idx_t_fixes_session_id` + composite `idx_t_fixes_session_recorded_at`.
- Nouvelle migration V2→V3 s'inscrit dans le framework Drift Phase 03 (`MigrationStrategy.onUpgrade` + pré-backup + sanity row-count). V1→V2 fictive (notes) reste en place.
- JsonMigrator : V2→V3 JSON migration à ajouter pour cohérence.
- `FixStore` port + `DriftFixStore` impl + entité Freezed `Fix` avec `@Assert` invariants (lat ±90, lon ±180, accuracy ≥ 0).

**Notification persistante : titre seul, pas d'action inline**

- Android foreground service notification via `flutter_local_notifications` 21.0.0 (OU via geolocator's built-in `foregroundNotificationConfig` — see §Standard Stack §alternative discussion) :
  - Title: `MirkFall • [session displayName]`
  - Body: vide (ou `Suivi actif`)
  - Pas d'action button inline
  - Tap notif = ouvre app → route `/sessions/:id`
  - Channel importance: Low (persistante mais discrète)
- iOS : équivalent via silent background notification maintenue tant que background mode `location` actif.
- Dismiss : le seul chemin = Stop la session depuis l'app. La notif disparaît immédiatement au Stop.

**Auto-resume post-kill OS : notif "tap pour reprendre", pas de reprise silencieuse**

- Android : `BroadcastReceiver` `BOOT_COMPLETED` déclaré dans `AndroidManifest.xml`. Au boot, le receiver check la DB via isolate Drift → si une session avait `status='active'` au moment du kill, push une `flutter_local_notifications` locale "Session [nom] interrompue. Tap pour reprendre le tracking". Tap → ouvre app, redémarre fg service + réactive session.
- iOS : pas de `BOOT_COMPLETED` équivalent direct. Utilise `significant-change location service` comme watchdog OU `region monitoring`. À trancher en RESEARCH.
- Explicit user control : aucune reprise automatique silencieuse.

**Permission + Store copy : FINAL en Phase 05**

- `NSLocationWhenInUseUsageDescription` final (iOS Info.plist) :
  > MirkFall utilise ta position pour révéler le brouillard de ta carte d'exploration personnelle. Tout reste sur ton téléphone — aucun serveur, aucun partage, aucune publicité.
- `NSLocationAlwaysAndWhenInUseUsageDescription` final :
  > MirkFall continue à suivre ta position en arrière-plan pour que ta carte d'exploration se révèle pendant que ton téléphone est dans ta poche, écran éteint — comme une vraie sortie. Tout reste sur ton téléphone. Aucune donnée n'est envoyée ni partagée.
- `docs/store-review-rationale.md` rédigé Phase 05 (sections : project description, why Always, data handling, source code accessibility, contact email).

**POC QUAL-01/02 : devices + protocole + validation**

- Android devices POC : Pixel 4a + Pixel 6 Pro (stock AOSP).
- iOS device POC : iPhone 17 Pro. Sideload via SideStore.
- Protocole 30-min walk : user démarre session UI, verrouille écran, sort 30 min (marche, transport, mix). Stop. Dump DB.
- Critères succès : >= 50 fixes en 30 min ; intervalle max entre deux fixes < 3 min ; dernier fix timestamp > (start + 29 min) ; visualisation via `tool/plot_session_fixes.py`.
- `docs/qual-01-02-poc.md` commité après chaque run.
- Gap OEM battery-killer documenté : Pixel-validated ; OEM POC (Xiaomi/Samsung/Huawei/OnePlus) deferred to Phase 15.

**Outil Python `tool/plot_session_fixes.py`**

- Standalone Python 3.x (pas de dep Flutter). Lit `<app_support>/mirkfall.db` via `sqlite3` stdlib.
- Query : `SELECT latitude, longitude, recorded_at_utc FROM t_fixes WHERE session_id = ? ORDER BY recorded_at_utc`.
- Dessine trajet sur tile map OSM statique (package `staticmap` ou `contextily` — audit licence obligatoire).
- Output : PNG timestampé dans `docs/poc-artifacts/`.
- Deps Python dans `tool/requirements.txt` séparé de `pubspec.yaml`.

**Wiring ProviderScope + AppDatabase dans main.dart**

- Phase 03 CONTEXT a déféré ce wiring à Phase 05. Décision : option (a) — laisse Riverpod résoudre `appDatabaseProvider.future` lazy. Simple, garde Riverpod pattern pure. Si spinner first-frame moche, retrofit option (b).

### Claude's Discretion

- Composition exacte des widgets (spacings, typo sizes, layout details)
- Format exact du chrono session active (mm:ss vs HH:mm:ss selon durée)
- Icon exacte de la notification persistante (mipmap ou vector)
- Channel name + ID Android notification (probablement `mirkfall_session_tracking`)
- Stratégie stationary dedup exacte (seuils delta_distance + delta_time)
- Choix iOS watchdog `significant-change` vs `region monitoring` (arbitrage RESEARCH sur conso vs fiabilité)
- Package Flutter Dynamic Island à auditer (ou platform channel Swift custom si aucun ne passe l'audit GOSL)
- Shape exact de la migration V2→V3 (raw `customStatement` ou Drift `m.createTable`)
- Taxonomie exceptions GPS (`LocationPermissionDeniedException`, `LocationServiceDisabledException`, `TrackingBackgroundKilledException`)
- Package Python pour tile map (audit licence)
- Layout exact du slider `/settings` Phase 05 (anticipant Phase 13 extension)
- Copy exact des boutons (FR)
- Format du SharedPreferences key namespace

### Deferred Ideas (OUT OF SCOPE)

- Splash screen Flutter avec logo 3 s → Phase 15 polish
- POC sur OEM battery-killer réel (Xiaomi/Samsung/Huawei/OnePlus) → Phase 15 ou emprunt device pré-release
- Full settings screen global (OPT-03..07) → Phase 13
- `ActiveSessionController` integration avec `RevealedTileStore.mergeMask` → **Phase 05 NE TOUCHE PAS** (recommendation initiale confirmée ici). Fixes écrits bruts dans `t_fixes` ; Phase 09 branche le reveal.
- Stats distance/% du monde révélé (STAT-*) → V1.1+
- Multi-langue (FR/EN) → V1.x
- QUAL-05 airplane-mode smoke test → Phase 15
- Dynamic Island iOS si audit échoue → drop entirely
- Stationary dedup heuristic fine-tuning → observer pendant POC puis ajuster
- Rotation logs par âge → Phase 15 polish
- Debug toggle "Verbose tracking logs" dédié → toggle `debug_logging_enabled` existant suffit
- Geocoding inverse → jamais V1.0
- Pré-import markers pour POC → Phase 11 + 13
- Notification "fix count live" → Phase 15 UI polish
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SESS-01 | Utilisateur peut créer une session avec un nom | §Architecture Patterns (SessionListScreen + FAB + `SessionStore.insert`) — store port exists Phase 03, DriftSessionStore tested. Plan ships UI + controller. |
| SESS-02 | Utilisateur peut renommer une session existante | `SessionStore.update` path (modify `displayName`) — already implemented Phase 03; plan adds rename dialog in SessionDetailScreen menu. |
| SESS-03 | Utilisateur peut supprimer une session (avec confirmation) | `SessionStore.delete` CASCADE already in schema (FK markers/revealed_tiles/fixes after V3 migration). Plan adds AlertDialog confirmation + block-if-active rule. |
| SESS-04 | Utilisateur peut démarrer (Start) une session | `ActiveSessionController.start(id)` → activates session (SESS-06 exclusivity DB-enforced) → fires location stream → shows fg notification. |
| SESS-05 | Utilisateur peut arrêter (Stop) une session active | `ActiveSessionController.stop()` → cancels stream → cleans fg notification → calls `sessionStore.deactivate`. |
| SESS-07 | État session persisté localement en continu | Every accepted fix `INSERT` into `t_fixes` (no batch). DB is the source of truth. |
| SESS-08 | Liste sessions visible avec état | SessionListScreen streams `SessionStore.watchAll()` (NEW watch API, see §Open Questions) ou polling ; badge "active" sur ligne. |
| SESS-09 | Nombre illimité de sessions | No limit in schema; tests should include stress case (100+ sessions list render performance smoke test). |
| GPS-01 | Permission "Always" demandée à la première session + pre-prompt | Two-step chain: `Permission.locationWhenInUse.request()` puis `Permission.locationAlways.request()`. SharedPrefs flag `permission_flow_completed`. |
| GPS-02 | Session active tracke en temps réel (foreground) | `Geolocator.getPositionStream(locationSettings:)` returns `Stream<Position>`. |
| GPS-03 | Tracking continue en arrière-plan (Android fg service + iOS background mode) | Android: `AndroidSettings.foregroundNotificationConfig` promotes to fg service. iOS: `AppleSettings.allowsBackgroundLocationUpdates = true` + `UIBackgroundModes=location` + `pauseLocationUpdatesAutomatically = false`. |
| GPS-04 | Notification persistante tracking actif | Two options (see §Standard Stack): (a) built-in via `foregroundNotificationConfig` (simpler), (b) custom via `flutter_local_notifications` (more control, needed for auto-resume anyway). Recommend hybrid. |
| GPS-05 | Tracking respecte distanceFilter configurable | `AndroidSettings.distanceFilter` + `AppleSettings.distanceFilter` (meters). `kDefaultDistanceFilterMeters = 5`. Slider persists via SharedPreferences. |
| GPS-06 | Tracking reprend si killée OS, au redémarrage | Android `BOOT_COMPLETED` receiver + iOS `significant-change location service` watchdog → local notif "tap pour reprendre". NO silent resume. |
| GPS-07 | Écran permissions denied + deep-link vers settings | `PermissionDeniedScreen` + `openAppSettings()` from `permission_handler`. |
| GPS-08 | Doc OEM battery-killers dans l'app | `OemGuidanceScreen` detects `Build.MANUFACTURER` via `device_info_plus` 13.0.0 ; lists vendor-specific steps + `dontkillmyapp.com/[vendor]` link ; opened via `url_launcher` OR share-sheet (no url_launcher dep yet — see §Open Questions). |
| QUAL-01 | POC validation Android OEM 30 min | Pixel 4a/6 Pro pragmatic substitute (CONTEXT.md gap accepted); `docs/qual-01-02-poc.md` evidence. |
| QUAL-02 | POC validation iOS 30 min | iPhone 17 Pro via CI macos-latest artifact + SideStore sideload. |
| QUAL-03 | Argumentaire store review | `docs/store-review-rationale.md` (local-only / zero telemetry / GOSL angle). |
| QUAL-04 | Info.plist iOS UsageDescription copy final | `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription` copy from CONTEXT.md §Permission + Store copy. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `geolocator` | 14.0.2 (pinned, already in pubspec) | GPS foreground + Android fg service + iOS bg mode | MIT ; `geolocator_android` + `geolocator_apple` are the plugin owners' official sub-packages. Replaces `flutter_background_geolocation` (commercial, GOSL-incompatible — rejected in Phase 03 decisions). `background_locator_2` is community with weaker maintenance and carries more transitive surface. |
| `permission_handler` | 12.0.1 (pinned) | OS prompt + `openAppSettings()` deep-link | MIT ; Baseflow (same publisher as geolocator). Only realistic choice for `Permission.locationWhenInUse` / `Permission.locationAlways` orchestration. |
| `flutter_local_notifications` | 21.0.0 (pinned) | Local notification for auto-resume branch + optional richer session-active notif | BSD-3 ; maintained Flutter team-adjacent, no telemetry. Required because `BOOT_COMPLETED` receiver branch MUST fire a notification. |
| `shared_preferences` | 2.5.5 (already in pubspec) | Flags `permission_flow_completed`, `oem_guidance_seen`, `distanceFilter_meters` | BSD-3 ; standard choice. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `device_info_plus` | 13.0.0 (TO ADD — audit in DEPENDENCIES.md) | `Build.MANUFACTURER` detection for OEM guidance screen | BSD-3, fluttercommunity.dev verified publisher. No network calls (confirmed by source inspection). Preferred over bespoke Kotlin platform channel because OEM list is bound to grow (OPPO, vivo, ...). |
| `url_launcher` | TO ADD (audit) OR `share_plus` re-use | Open `dontkillmyapp.com/[vendor]` external link | `share_plus` (already in pubspec, BSD-3) can share a URL via OS share sheet; `url_launcher` opens directly in browser. Simpler UX = `url_launcher`. **Decision**: reuse `share_plus` to avoid adding a dep — see §Open Questions. |
| `flutter_riverpod` + `riverpod_annotation` | 3.3.1 / 4.0.2 (already pinned) | `ActiveSessionController`, `fixStoreProvider`, etc. | Project state management (D5). |
| `go_router` | 16.0.0 (already pinned) | New routes: `/sessions`, `/sessions/:id`, `/settings`, `/permissions/rationale`, `/permissions/denied`, `/permissions/oem` | Already used. |
| `drift` + `drift_flutter` | 2.32.1 / 0.3.0 (already pinned) | `t_fixes` table via migration V2→V3, `DriftFixStore` | Project persistence stack (D4). |
| `freezed_annotation` + `freezed` + `json_serializable` | 3.1.0 / 3.2.5 / 6.13.1 (already pinned) | `Fix` entity + JSON serialization for export migration | Project entity convention. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `geolocator` built-in fg service + `foregroundNotificationConfig` | `flutter_background_service` + separate coordinator | Adds a dep, duplicates geolocator's already-present service infrastructure, and forces an isolate boundary between the GPS stream and the DB writer. **Reject** — plugin scope suffices. |
| `geolocator` | `background_locator_2` | Weaker maintenance (last release ~2023 per pub.dev checks), smaller user base, parallel API surface. **Reject**. |
| `geolocator` | `flutter_background_geolocation` (transistorsoft) | Commercial licence (free for dev, paid for release); GOSL-incompatible. **Rejected in Phase 03 decisions.** |
| `device_info_plus` | Kotlin platform channel in `android/app/src/main/kotlin/.../MainActivity.kt` calling `android.os.Build.MANUFACTURER` | Bespoke, one-line Kotlin — avoids a dep, but means a second channel + Swift stub for iOS (which returns something benign like `apple`). `device_info_plus` covers both platforms for ~100 KB of transitive weight. **Recommend dep**; bespoke channel is a fallback if audit surfaces any concern. |
| `url_launcher` | `share_plus.share('https://dontkillmyapp.com/xiaomi')` | `share_plus` already in the project. Share sheet is one extra tap versus direct-browser launch, but avoids adding a dep. **Recommend reuse**. |
| Custom Dynamic Island plugin | `live_activities` 2.4.7 | MIT licence, but transitively carries `flutter_app_group_directory`, `image`, and supports `LiveActivityFileFromUrl` which IS a network call on URL. **Auditable, but the network-call surface must be walled off** — we only pass local strings to the Live Activity, never URLs. If audit says OK, use it; if not, drop Dynamic Island. |

**Installation delta** (to add in `pubspec.yaml`):
```yaml
dependencies:
  # ... existing ...
  device_info_plus: 13.0.0   # Phase 05 — OEM detection for guidance screen
  # live_activities: 2.4.7   # ONLY if audit passes § Open Questions
```

DEPENDENCIES.md audit entry for `device_info_plus` needed before pin.

## Architecture Patterns

### Recommended Project Structure

New tree additions (aligned with existing `lib/domain/`, `lib/infrastructure/`, `lib/application/`, `lib/presentation/` layers):

```
lib/
├── config/
│   └── constants.dart               # +kDefaultDistanceFilterMeters, +kMaxAcceptableAccuracyMeters,
│                                    #  +kFirstFixTimeoutSeconds, +kNotificationChannelId,
│                                    #  +kSessionActiveBannerHeightDp
├── domain/
│   ├── fixes/                       # NEW
│   │   ├── fix.dart                 # Freezed entity + @Assert invariants
│   │   ├── fix.freezed.dart         # generated
│   │   ├── fix.g.dart               # generated
│   │   └── fix_store.dart           # abstract port
│   ├── gps/                         # NEW
│   │   ├── location_stream.dart     # abstract port over geolocator
│   │   └── gps_errors.dart          # sealed exceptions
│   ├── ids/
│   │   └── fix_id.dart              # extension type `FixId` with prefix `fix_`
│   └── errors/                      # ADD: location_permission_errors.dart
├── infrastructure/
│   ├── db/
│   │   ├── app_database.dart        # bump schemaVersion 2 → 3, register V2ToV3Fixes
│   │   └── migrations/
│   │       ├── v1_to_v2_notes.dart  # unchanged
│   │       └── v2_to_v3_fixes.dart  # NEW
│   ├── stores/
│   │   └── drift_fix_store.dart     # NEW
│   ├── gps/                         # NEW
│   │   ├── geolocator_location_stream.dart     # impl LocationStream via geolocator
│   │   └── location_settings_factory.dart      # returns AndroidSettings | AppleSettings
│   ├── notifications/               # NEW
│   │   └── session_notification_service.dart   # wraps flutter_local_notifications
│   └── platform/                    # NEW
│       └── oem_detector.dart        # wraps device_info_plus, returns sealed OemFamily
├── application/
│   ├── controllers/                 # NEW directory (first productive controller)
│   │   └── active_session_controller.dart    # @Riverpod(keepAlive: true)
│   └── providers/
│       ├── fix_store_provider.dart                 # NEW
│       ├── location_stream_provider.dart           # NEW
│       ├── session_notification_service_provider.dart   # NEW
│       └── oem_detector_provider.dart              # NEW
└── presentation/
    ├── screens/
    │   ├── session_list_screen.dart                # NEW — replaces PlaceholderHomeScreen at `/`
    │   ├── session_detail_screen.dart              # NEW
    │   ├── settings_screen.dart                    # NEW — minimal, slider distanceFilter
    │   ├── permission_rationale_screen.dart        # NEW
    │   ├── permission_denied_screen.dart           # NEW
    │   └── oem_guidance_screen.dart                # NEW
    └── widgets/
        └── active_session_banner.dart              # NEW — cross-route indicator
```

Android native additions:
```
android/app/src/main/
├── AndroidManifest.xml                 # EDIT: permissions + service + receiver
└── kotlin/app/gosl/mirkfall/
    └── BootCompletedReceiver.kt        # NEW — boot-time watchdog
```

(Note: the foreground service itself is provided by `geolocator_android` — no custom `SessionTrackingService.kt` needed, which simplifies things considerably.)

iOS native additions:
```
ios/Runner/
├── Info.plist                           # EDIT: UIBackgroundModes=location, final UsageDescription strings
└── AppDelegate.swift                    # EDIT if Live Activity path taken (ActivityKit glue)
```

Tool additions:
```
tool/
├── plot_session_fixes.py                # NEW
├── requirements.txt                     # NEW (python deps)
└── README.md                            # EDIT — document Python section
docs/
├── qual-01-02-poc.md                    # NEW — POC evidence log
├── store-review-rationale.md            # NEW
└── poc-artifacts/                       # NEW dir for PNG plots
```

### Pattern 1: LocationSettings platform branch (seam)

**What:** Abstract the `AndroidSettings` / `AppleSettings` construction behind a factory so `ActiveSessionController` stays platform-agnostic.
**When to use:** Any time geolocator config differs across platforms.
**Example:**
```dart
// lib/infrastructure/gps/location_settings_factory.dart
// Source: https://pub.dev/packages/geolocator (README, verified via WebFetch 2026-04-19)
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:mirkfall/config/constants.dart';

/// Builds platform-appropriate [LocationSettings] for the active session.
///
/// [distanceFilterMeters] comes from SharedPreferences (user-adjustable
/// slider, default [kDefaultDistanceFilterMeters]).
/// [sessionDisplayName] feeds the Android foreground notification title.
LocationSettings buildLocationSettings({
  required int distanceFilterMeters,
  required String sessionDisplayName,
}) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
      // forceLocationManager: false — rely on FusedLocationProviderClient
      // (more accurate indoor). Set to true ONLY if Google Play Services
      // absent (Huawei HMS devices) — handled via runtime detection in
      // Phase 15 if ever needed.
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'MirkFall • $sessionDisplayName',
        notificationText: 'Suivi actif',
        notificationChannelName: 'MirkFall session tracking',
        // enableWakeLock: true — required to prevent Android from
        // suspending location callbacks when screen is off >~30 min.
        // Documented pitfall (see §Common Pitfalls #4).
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      // ActivityType.fitness hints iOS the user is walking/running —
      // best match for MirkFall exploration use case. Alternative:
      // .otherNavigation (generic transit). Pick .fitness so iOS won't
      // assume a stopped car = "park and leave".
      activityType: ActivityType.fitness,
      distanceFilter: distanceFilterMeters.toDouble(),
      // pauseLocationUpdatesAutomatically: FALSE.
      //
      // iOS default in community examples is `true` (battery-friendly),
      // but that makes iOS silently pause updates during stationary
      // moments (café, lunch). For a 30-min walk with stops, we WANT
      // continuous tracking — an explicit Stop is the only valid pause.
      // See §Common Pitfalls #3.
      pauseLocationUpdatesAutomatically: false,
      allowsBackgroundLocationUpdates: true,
      // showBackgroundLocationIndicator: true — shows the blue bar/pill
      // at the top of the screen when the app is getting location in
      // background. User-visible transparency, aligns with GOSL ethics.
      showBackgroundLocationIndicator: true,
    );
  }
  // Desktop (Windows/macOS/Linux): fall back to plain LocationSettings,
  // used only by dev flow `flutter run -d windows`. No background concerns.
  return LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: distanceFilterMeters,
  );
}
```

### Pattern 2: ActiveSessionController orchestration

**What:** Single `@Riverpod(keepAlive: true)` controller owns the end-to-end pipeline (start → stream → filter → store → notif → stop).
**When to use:** As the root consumer for Phase 05 UI. All screens watch it.

```dart
// lib/application/controllers/active_session_controller.dart
// Simplified illustration — actual plan will break into smaller methods.
@Riverpod(keepAlive: true)
class ActiveSessionController extends _$ActiveSessionController {
  StreamSubscription<Position>? _sub;

  @override
  FutureOr<ActiveSessionState> build() {
    // On dispose: cancel the subscription. Riverpod 3.0 pauses on no-listener
    // but ActiveSessionController is keepAlive — we explicitly cancel on stop.
    ref.onDispose(() async {
      await _sub?.cancel();
      _sub = null;
    });
    return const ActiveSessionState.idle();
  }

  Future<void> start(SessionId id) async {
    // 1. DB: flip to active (throws ConcurrentActivationException if
    //    another session is already active — handled by caller UI).
    final store = await ref.read(sessionStoreProvider.future);
    await store.activate(id);

    // 2. Start the location stream. LocationSettings pulled via factory.
    final prefs = await SharedPreferences.getInstance();
    final distance = prefs.getInt('distanceFilter_meters')
        ?? kDefaultDistanceFilterMeters;
    final session = await store.requireById(id);
    final settings = buildLocationSettings(
      distanceFilterMeters: distance,
      sessionDisplayName: session.displayName,
    );

    final fixStore = await ref.read(fixStoreProvider.future);
    final idGen = ref.read(idGeneratorProvider);

    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
      (Position p) => _onPosition(p, id, fixStore, idGen),
      onError: _onStreamError,   // logs + sets state to error
      cancelOnError: false,       // keep the stream alive on transient errors
    );

    state = AsyncData(ActiveSessionState.tracking(
      sessionId: id,
      startedAtUtc: session.startedAtUtc,
      lastFix: null,
      fixCount: 0,
    ));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    final current = state.value;
    if (current is _Tracking) {
      final store = await ref.read(sessionStoreProvider.future);
      await store.deactivate(current.sessionId);
    }
    state = const AsyncData(ActiveSessionState.idle());
  }

  Future<void> _onPosition(Position p, SessionId id, FixStore store, IdGenerator gen) async {
    // Accuracy filter — reject high-error fixes (indoor ambiguity).
    if (p.accuracy > kMaxAcceptableAccuracyMeters) return;

    // Stationary dedup — skip if delta < 1m AND delta_time < 10s since
    // last accepted fix. Claude's discretion; CONTEXT.md mentions the
    // heuristic but leaves exact values open.
    // ... dedup logic ...

    final fix = Fix(
      id: FixId(gen.nextFixId()),
      sessionId: id,
      recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(p.timestamp.millisecondsSinceEpoch, isUtc: true),
      recordedAtOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyMeters: p.accuracy,
      altitudeMeters: p.altitude.isFinite ? p.altitude : null,
      speedMps: p.speed.isFinite ? p.speed : null,
      headingDegrees: p.heading.isFinite ? p.heading : null,
    );
    await store.insert(fix);
    // ... update state.fixCount + lastFix ...
  }
}
```

### Pattern 3: Two-step permission flow

**What:** Request `Permission.locationWhenInUse` FIRST, then `Permission.locationAlways`. Android ignores direct `Always` requests.
**When to use:** Permission rationale screen → "Continuer" button → OS flow.

```dart
// lib/application/permissions/location_permission_flow.dart
// Source: https://pub.dev/packages/permission_handler (Baseflow documentation + GitHub issue #452 verified 2026-04-19)
//
// CRITICAL: On Android 10+, Permission.locationAlways.request() is silently
// ignored if Permission.locationWhenInUse has not been granted FIRST. The
// only working sequence is:
//   1. locationWhenInUse.request() → user picks "While using app" / "Only this time" / "Don't allow"
//   2. If granted: locationAlways.request() → OS shows SECOND dialog
//      "Change to Always Allow / Keep Only While Using"
Future<LocationPermissionOutcome> requestLocationAlways() async {
  // Step 1: foreground permission.
  final whenInUse = await Permission.locationWhenInUse.request();
  if (whenInUse.isPermanentlyDenied) {
    return LocationPermissionOutcome.permanentlyDenied;
  }
  if (!whenInUse.isGranted) {
    return LocationPermissionOutcome.denied;
  }

  // Step 2: background. Android opens SETTINGS (not a dialog) from Android 11+ —
  // user must navigate to "Allow all the time" manually. iOS: second dialog.
  final always = await Permission.locationAlways.request();
  if (always.isGranted) return LocationPermissionOutcome.granted;
  if (always.isPermanentlyDenied) return LocationPermissionOutcome.permanentlyDenied;
  // User got "While using" but not "Always" — acceptable for app usage while
  // open; background tracking will not survive screen-off. Warn in UI.
  return LocationPermissionOutcome.whileInUseOnly;
}
```

### Anti-Patterns to Avoid

- **Requesting `Permission.locationAlways` directly.** Documented to be silently ignored on Android 10+ if `locationWhenInUse` not previously granted. Source: permission_handler README + GitHub issue #452.
- **Starting the location stream without `ensureInitialized` + permission check.** Leads to `LocationServiceDisabledException` that crashes the app before the listener catches it. Guard-clause `await Geolocator.isLocationServiceEnabled()` and `await Geolocator.checkPermission()` before subscribing.
- **Relying on `.then()` for stream lifecycle.** CLAUDE.md forbids `.then()` without justification. Use `async`/`await` + cancel in `ref.onDispose`.
- **Writing a custom Kotlin `SessionTrackingService` when `geolocator_android` already provides one.** Duplicates infrastructure. Only write native if geolocator's service proves insufficient — not speculatively.
- **Updating the notification on every fix.** Causes Android notification-manager churn, user-visible flicker, and battery drain. The CONTEXT.md decision "title only, no live counter" is technically correct. Set once at start, tear down at stop.
- **Using `pauseLocationUpdatesAutomatically: true` on iOS for a walking app.** iOS silently pauses during stationary periods (coffee breaks), leaving gaps. Must flip to `false` and rely on explicit Stop.
- **Setting `forceLocationManager: true` on Android without HMS-only justification.** Disables `FusedLocationProviderClient` (Google Play Services). On typical Google-services devices this degrades accuracy and increases battery use. Documented issue: [geolocator #1290](https://github.com/Baseflow/flutter-geolocator/issues/1290) — reports it breaks live streaming.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Android foreground service for GPS | Custom `SessionTrackingService.kt` + manifest + binder | `geolocator 14.0.2` `AndroidSettings.foregroundNotificationConfig` | geolocator already wires the service, notification, and handles Android 14 `foregroundServiceType="location"` correctly. Writing it yourself means maintaining two implementations of the same pipeline. |
| Permission request orchestration (Android 10+ two-step quirks, iOS Always dialog) | Custom `MethodChannel` wrapping `ActivityCompat.requestPermissions` | `permission_handler 12.0.1` | Correctly handles Android 10+, 11, 12, 13, 14 edge cases (e.g., `locationWhenInUse`-first rule, `ACCESS_BACKGROUND_LOCATION` system-settings redirect). Hand-rolled versions routinely miss the "request is silently ignored" edge case. |
| OS-compatible local notifications (Android 13+ `POST_NOTIFICATIONS`, iOS `UNUserNotificationCenter`) | `notification.dart` helper with platform channels | `flutter_local_notifications 21.0.0` | Handles channel creation, importance levels, tap-handler wiring for foreground / background / terminated states, notification permission request flows on Android 13+. Hand-rolling means re-implementing all of these. |
| ULID-like IDs for fixes | Re-invent | `IdGenerator.nextFixId()` from Phase 03 (`IdGenerator` + ULID already shipped, extension-type `FixId` follows the pattern) | Already in project. |
| Drift schema migration | Raw SQL strings stringly-typed | `Migrator.createTable(fixes)` (Drift API) | `m.createTable` emits exactly the shape that `SchemaVerifier` compares against; raw SQL risks byte-mismatches with the frozen `drift_schema_v3.json` dump. |
| Android `Build.MANUFACTURER` / model lookup | Custom Kotlin channel | `device_info_plus 13.0.0` | Covers Android + iOS in one call; saves a channel + a Swift stub. |
| OSM static tile map for Python plot | Hand-compute tile URLs + stitching | Python `staticmap` (MIT) OR `contextily` (BSD-3) | Both audit-compatible; either does the heavy lifting. See §Open Questions for final pick. |
| JSON migration V2→V3 shape | Inline SQL strings in `JsonMigrator` | Already-shipped Phase 03 migration framework (identity registration + shape-driven registry) | Framework handles version dispatch; plan writes a `V2ToV3Fixes` subclass parallel to the existing `V1ToV2RenameRadius`. |

**Key insight:** The Phase 05 plan is a composition exercise, not a platform-integration exercise. Every hard platform problem (fg service, bg mode, permissions, notifications) is already solved by a pinned, audited dep. The plan's energy goes into (a) correct orchestration of the state machine, (b) error taxonomy, (c) UI flows, and (d) the real-device POC. Avoid the temptation to write "just a small native helper" — each one is a Kotlin + Swift + channel surface that's another audit item.

## Common Pitfalls

### Pitfall 1: Directly requesting `Permission.locationAlways`
**What goes wrong:** On Android 10+, `Permission.locationAlways.request()` returns immediately with the current status without prompting the user — no dialog appears. Users perceive it as "app broken, permission dialog never shows".
**Why it happens:** Google's permission model requires foreground location approval as a prerequisite for the background grant request.
**How to avoid:** Always chain: `locationWhenInUse.request()` → (on grant) → `locationAlways.request()`. Never skip step 1 even if the UI claims the user wants "Always".
**Warning signs:** `locationAlways.request()` returns `denied` without the OS dialog appearing. Check logs for "permission dialog not shown, returning current status".
**Source:** permission_handler README + GitHub issues #452, #1011.

### Pitfall 2: Missing `android:foregroundServiceType="location"` on Android 14+
**What goes wrong:** `SecurityException` / `ForegroundServiceStartNotAllowedException` at start of tracking; app crashes or service never starts.
**Why it happens:** Android 14 (API 34) enforces declared service-type matching runtime permission. `FOREGROUND_SERVICE_LOCATION` permission AND service-type in the manifest are both mandatory.
**How to avoid:** In `android/app/src/main/AndroidManifest.xml`:
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>`
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>`
- NOTE: `geolocator_android` ships its own `<service>` declaration via manifest merge; the plan must VERIFY the merged manifest (`./gradlew app:dependencies` or inspect the APK's AndroidManifest) shows `android:foregroundServiceType="location"`. If missing, add an override declaration.
**Warning signs:** `ForegroundServiceStartNotAllowedException` in logs; service appears to start but gets killed <5 seconds.
**Source:** [Android developer docs — Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), geolocator issue #1739.

### Pitfall 3: `pauseLocationUpdatesAutomatically: true` silently pauses tracking during stationary moments on iOS
**What goes wrong:** During a 30-min walk with a café stop, iOS pauses location updates after ~5 min of stationary. On resume, the stream may or may not automatically restart. Result: gaps of 10+ minutes in the fix record for what the user perceived as a continuous walk.
**Why it happens:** iOS is aggressively battery-conscious; the `pauseLocationUpdatesAutomatically` flag (default in community snippets) asks CoreLocation to pause when the user appears stationary.
**How to avoid:** Set `pauseLocationUpdatesAutomatically: false` in `AppleSettings`. Pair with `activityType: ActivityType.fitness` to signal walking/running context and prevent premature pausing.
**Warning signs:** iPhone POC shows fix timestamps with gaps >5 min while the device was indoors (café, lunch).
**Source:** [transistorsoft/flutter_background_geolocation #93](https://github.com/transistorsoft/flutter_background_geolocation/issues/93) — identical flag behavior documented.

### Pitfall 4: Location stream stops after screen off + device idle (no `enableWakeLock`)
**What goes wrong:** On Android, ~30-60 min of screen-off background tracking, then the stream goes silent. User resumes, screen on, fixes resume — but the 30-min POC has gaps.
**Why it happens:** Android suspends app-process callbacks in deep sleep (Doze mode). Without a wake lock tied to the fg service, location callbacks won't fire even though the service is "alive".
**How to avoid:** Set `enableWakeLock: true` inside `ForegroundNotificationConfig`. Explicitly documented in [geolocator issue #1023](https://github.com/Baseflow/flutter-geolocator/issues/1023).
**Warning signs:** POC shows clean fixes for the first 15-30 min, then a dead zone of 5+ min, then resumes only after screen-on interaction.
**Source:** geolocator GitHub issues #1023, #1727.

### Pitfall 5: `BOOT_COMPLETED` receiver on Android 14+ cannot start a location foreground service without `ACCESS_BACKGROUND_LOCATION`
**What goes wrong:** After device reboot, the receiver fires but its attempt to start the fg service throws `SecurityException`.
**Why it happens:** Android 14 requires the app have background location permission at receiver-invocation time to start a location-type fg service.
**How to avoid:** The `BOOT_COMPLETED` path is WATCHDOG ONLY — it fires `flutter_local_notifications` to notify the user, and does NOT try to restart the fg service directly. User tap on the notif opens the app, which is then in foreground and can legitimately start the service.
**Warning signs:** Logcat on post-reboot shows `SecurityException: Starting FGS with type location ... requires permissions: allOf=true [android.permission.ACCESS_BACKGROUND_LOCATION]`.
**Source:** [Android dev docs — Restrictions on starting FG services from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

### Pitfall 6: iOS significant-change location service and region monitoring do not restart terminated apps reliably since iOS 15
**What goes wrong:** User force-quits the app (or iOS terminates it for memory pressure) with an active session. App does not wake on significant change. Session tracking resumes only when user manually opens the app.
**Why it happens:** Documented regression around iOS 15 — `startMonitoringForRegion` and `startMonitoringSignificantLocationChanges` stopped reliably relaunching terminated apps, and subsequent iOS versions have inconsistent behavior.
**How to avoid:** Accept this as a known limitation. The CONTEXT.md decision — "explicit user control, no silent resume" — is the right architectural choice BECAUSE silent iOS resume is not reliable anyway. The iOS watchdog is a best-effort; plan for graceful degradation. Document clearly in `docs/store-review-rationale.md` and in-app help.
**Warning signs:** iOS POC with force-quit mid-walk shows no notification even after ~1 km of walking.
**Source:** [Apple Developer Forums — Significant-Change / Region Monitoring thread](https://developer.apple.com/forums/thread/79465).

### Pitfall 7: Drift migration tests break when the generator re-emits a slightly different shape
**What goes wrong:** `SchemaVerifier.migrateAndValidate` reports a byte-mismatch between the runtime schema post-migration and `drift_schema_v3.json`. Error looks like `Not equal: "... NOT NULL" (expected) and "..." (actual)`.
**Why it happens:** Mixing `m.customStatement('CREATE TABLE ... ')` with Drift's generator-native path leads to shape drift. Even whitespace / identifier-quoting differences fail the comparison.
**How to avoid:** Use `m.createTable(fixes)` — the generator emits exactly the same SQL that `drift_schema_v3.json` was dumped from. Freeze `drift_schema_v3.json` via `dart run drift_dev schema dump lib/infrastructure/db/app_database.dart drift_schemas/drift_schema_v3.json` AFTER the table class is finalized.
**Warning signs:** Migration test passes for V1→V2 (custom SQL route) but fails for V2→V3.
**Source:** Phase 03 internal decisions (STATE.md — "V1ToV2Notes ALTER SQL locked to frozen V2 dump shape" + Batch B/F findings on identifier quoting).

### Pitfall 8: OEM battery killers silently void `foregroundNotificationConfig` guarantees on Xiaomi / Huawei / OnePlus
**What goes wrong:** POC on Pixel passes. User installs on Xiaomi → foreground service is killed after 30-60 min despite notification-visible, despite `enableWakeLock`. User reports "app stops tracking".
**Why it happens:** OEM-custom battery managers override AOSP Doze semantics. Xiaomi MIUI's "Battery saver" and OnePlus's "App startup manager" can kill any background process, fg service included.
**How to avoid:** There is NO API-level workaround. The ONLY solution is user-side: the OEM guidance screen (GPS-08) that instructs the user to lock the app in recents, whitelist it in battery settings, etc. Link to `dontkillmyapp.com/[vendor]`. CONTEXT.md already made this a first-class concern.
**Warning signs:** POC evidence gaps correlated with OEM + screen-off duration.
**Source:** [dontkillmyapp.com](https://dontkillmyapp.com/), Xiaomi + OnePlus specific entries.

## Code Examples

### Detecting OEM manufacturer for guidance screen

```dart
// lib/infrastructure/platform/oem_detector.dart
// Source: https://pub.dev/packages/device_info_plus
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Recognized OEM families that are documented battery-killers on
/// dontkillmyapp.com. Returned by [OemDetector.detect].
sealed class OemFamily {
  const OemFamily();
}
class XiaomiFamily extends OemFamily { const XiaomiFamily(); }       // Xiaomi, Redmi, POCO
class SamsungFamily extends OemFamily { const SamsungFamily(); }
class HuaweiFamily extends OemFamily { const HuaweiFamily(); }        // Huawei, Honor
class OnePlusFamily extends OemFamily { const OnePlusFamily(); }
class OppoFamily extends OemFamily { const OppoFamily(); }            // OPPO, Realme
class OtherOem extends OemFamily { const OtherOem(); }                // non-targeted
class IosDevice extends OemFamily { const IosDevice(); }              // show nothing

class OemDetector {
  OemDetector(this._plugin);
  final DeviceInfoPlugin _plugin;

  Future<OemFamily> detect() async {
    if (Platform.isIOS) return const IosDevice();
    if (Platform.isAndroid) {
      final info = await _plugin.androidInfo;
      // Lowercase match on manufacturer + brand for belt-and-suspenders —
      // some devices report the brand (POCO) while others report the
      // parent manufacturer (Xiaomi). We match either.
      final String needle = '${info.manufacturer} ${info.brand}'.toLowerCase();
      if (RegExp(r'xiaomi|redmi|poco').hasMatch(needle)) return const XiaomiFamily();
      if (needle.contains('samsung')) return const SamsungFamily();
      if (RegExp(r'huawei|honor').hasMatch(needle)) return const HuaweiFamily();
      if (needle.contains('oneplus')) return const OnePlusFamily();
      if (RegExp(r'oppo|realme').hasMatch(needle)) return const OppoFamily();
      return const OtherOem();
    }
    return const OtherOem();
  }
}
```

### Drift migration V2→V3 adding `t_fixes`

```dart
// lib/infrastructure/db/migrations/v2_to_v3_fixes.dart
// Source: https://drift.simonbinder.eu/migrations/api/ (Migrator.createTable pattern)
import 'package:drift/drift.dart';
import '../app_database.dart';   // gives access to $FixesTable reference

class V2ToV3Fixes {
  V2ToV3Fixes._();

  /// Adds `t_fixes` table + indexes on V2→V3 upgrade. Calling context:
  /// AppDatabase.migrationStrategy.onUpgrade.
  static Future<void> apply(Migrator m, int from, int to) async {
    if (from < 3 && to >= 3) {
      // Use the generator-native path so SchemaVerifier's byte-compare
      // against drift_schema_v3.json passes without whitespace drift
      // (see §Common Pitfalls #7).
      await m.createTable(m.database.tFixes);
      // @TableIndex.sql on the Fixes table declaration emits the indexes
      // as part of createTable — no separate createIndex calls needed.
    }
  }
}
```

Corresponding table declaration (in `app_database.dart`):
```dart
// Source: project existing AppDatabase pattern (Sessions table lines 30-77)
@DataClassName('FixRow')
@TableIndex.sql('CREATE INDEX idx_t_fixes_session_id ON t_fixes(session_id);')
@TableIndex.sql('''
  CREATE INDEX idx_t_fixes_session_recorded_at
    ON t_fixes(session_id, recorded_at_utc);
''')
class Fixes extends Table {
  @override
  String get tableName => 't_fixes';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get recordedAtUtc => integer().map(const UnixMsToDateTimeConverter())();
  // ignore: recursive_getters
  IntColumn get recordedAtOffsetMinutes =>
      // ignore: recursive_getters
      integer().check(recordedAtOffsetMinutes.isBetweenValues(kMinUtcOffsetMinutes, kMaxUtcOffsetMinutes))();
  RealColumn get latitude => real().check(latitude.isBetweenValues(-90.0, 90.0))();  // ignore: recursive_getters
  RealColumn get longitude => real().check(longitude.isBetweenValues(-180.0, 180.0))();  // ignore: recursive_getters
  RealColumn get accuracyMeters => real().check(accuracyMeters.isBiggerOrEqual(const Constant<double>(0)))();  // ignore: recursive_getters
  RealColumn get altitudeMeters => real().nullable()();
  RealColumn get speedMps => real().nullable()();
  RealColumn get headingDegrees => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

And in the `@DriftDatabase` annotation, add `Fixes` to the tables list, bump `schemaVersion => 3`, and update `onUpgrade` to chain V1→V2→V3:
```dart
onUpgrade: (Migrator m, int from, int to) async {
  await V1ToV2Notes.apply(m, from, to);
  await V2ToV3Fixes.apply(m, from, to);
},
```

### Fix entity (Freezed, with @Assert)

```dart
// lib/domain/fixes/fix.dart
// Source: project pattern (lib/domain/sessions/session.dart)
import 'package:freezed_annotation/freezed_annotation.dart';
import '../ids/fix_id.dart';
import '../ids/session_id.dart';
import '../ids/id_json_converters.dart';

part 'fix.freezed.dart';
part 'fix.g.dart';

/// A single GPS fix recorded during a session. One-to-many with [Session].
///
/// `@Assert` invariants mirror the DB CHECKs — the domain REJECTS invalid
/// instances before they reach the store, guaranteeing that SqliteException
/// on CHECK violation is always an infrastructure bug, not a domain contract
/// break.
@freezed
abstract class Fix with _$Fix {
  @Assert('latitude >= -90.0 && latitude <= 90.0', 'Fix.latitude out of [-90, 90]')
  @Assert('longitude >= -180.0 && longitude <= 180.0', 'Fix.longitude out of [-180, 180]')
  @Assert('accuracyMeters >= 0.0', 'Fix.accuracyMeters must be non-negative')
  @Assert('recordedAtOffsetMinutes >= -720 && recordedAtOffsetMinutes <= 840',
          'Fix.recordedAtOffsetMinutes out of range (UTC-12 to UTC+14)')
  factory Fix({
    @JsonKey(fromJson: fixIdFromJson, toJson: fixIdToJson) required FixId id,
    @JsonKey(fromJson: sessionIdFromJson, toJson: sessionIdToJson) required SessionId sessionId,
    required DateTime recordedAtUtc,
    required int recordedAtOffsetMinutes,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    double? altitudeMeters,
    double? speedMps,
    double? headingDegrees,
  }) = _Fix;

  factory Fix.fromJson(Map<String, Object?> json) => _$FixFromJson(json);
}
```

### AndroidManifest.xml additions

```xml
<!-- android/app/src/main/AndroidManifest.xml — Phase 05 additions -->
<!-- Source: https://pub.dev/packages/geolocator README + Android 14 dev docs verified 2026-04-19 -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <!-- GPS -->
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>

  <!-- Foreground service (Android 14+ requires both) -->
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>

  <!-- Notification (Android 13+) -->
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

  <!-- Boot-completed watchdog -->
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

  <application ...>
    <!-- existing activity block unchanged -->

    <!-- NOTE: geolocator_android ships its own <service> via manifest merge —
         verify post-build the merged AndroidManifest shows
         android:foregroundServiceType="location". If absent, add override:

    <service
      android:name="com.baseflow.geolocator.GeolocatorLocationService"
      android:foregroundServiceType="location"
      android:exported="false"
      tools:replace="android:foregroundServiceType"/>
    -->

    <!-- MirkFall-owned BOOT_COMPLETED receiver — fires a local notification
         if the DB shows an active session at boot. Does NOT try to restart
         the fg service directly (Android 14+ SecurityException — see
         §Common Pitfalls #5). -->
    <receiver
      android:name=".BootCompletedReceiver"
      android:exported="true"
      android:directBootAware="false">
      <intent-filter android:priority="1000">
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
      </intent-filter>
    </receiver>
  </application>
</manifest>
```

### Info.plist additions

```xml
<!-- ios/Runner/Info.plist — Phase 05 FINAL copy + bg mode -->
<!-- Source: CONTEXT.md locked decisions (§Permission + Store copy : FINAL en Phase 05) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>MirkFall utilise ta position pour révéler le brouillard de ta carte d'exploration personnelle. Tout reste sur ton téléphone — aucun serveur, aucun partage, aucune publicité.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>MirkFall continue à suivre ta position en arrière-plan pour que ta carte d'exploration se révèle pendant que ton téléphone est dans ta poche, écran éteint — comme une vraie sortie. Tout reste sur ton téléphone. Aucune donnée n'est envoyée ni partagée.</string>

<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

(Phase 11 will add `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` final copy; Phase 05 leaves them as TODO placeholders.)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Android pre-Doze (API <23) — no power management | API 23+ Doze mode + API 34 fg service types | Ongoing since Android 6 / 14 | `FOREGROUND_SERVICE_LOCATION` mandatory on API 34+. Project `minSdk=24` is already Doze-era — acknowledges the reality from day one. |
| iOS 7 significant-change "always relaunches terminated apps" | iOS 15+ unreliable / best-effort | 2021 regression, still present through iOS 18+ | Auto-resume cannot be presented as a guarantee. CONTEXT.md's "explicit user control" positioning is the correct architectural answer. |
| Android < 10 — single `ACCESS_FINE_LOCATION` covers fg + bg | Android 10+ — split `ACCESS_BACKGROUND_LOCATION` + Android 11+ settings redirect for Always | 2019 (Android 10) | Drives the two-step permission flow design. |
| `flutter_background_service` for GPS pipelines | `geolocator` `AndroidSettings.foregroundNotificationConfig` (geolocator ≥9.0) | 2022+ | Eliminates a layered dep; geolocator self-hosts the service. Applies today. |
| Raw `customStatement` for all Drift migrations | Hybrid: `customStatement` for ADD COLUMN legacy, `m.createTable` for new tables | Drift 2.4+ (TableMigration API) | V2→V3 (new table) uses `m.createTable` for byte-stable verifier pass. |

**Deprecated/outdated:**
- `flutter_background_geolocation`: commercial licence, GOSL-incompatible. Do not consider.
- `background_locator_2`: sparsely maintained (last release early 2023 per pub.dev check), no active bug fixes for Android 14. Do not consider.
- Raw `AndroidManifest.xml` `<service>` declaration for GPS: redundant with geolocator's merge.
- `forceLocationManager: true` as a default: degrades accuracy on Google-services devices; issue #1290 reports it also breaks streaming. Keep it `false` unless HMS-only device detected.

## Open Questions

1. **Dynamic Island / Live Activity audit outcome**
   - What we know: `live_activities` 2.4.7 is MIT. Transitive deps include `image` (for bitmap manipulation of activity content), `path_provider`, `permission_handler`, `flutter_app_group_directory`. Exposes `LiveActivityFileFromUrl` which IS a network call on the URL — but optional.
   - What's unclear: Whether we can USE the package without ever invoking `LiveActivityFileFromUrl` (analog to `flutter_map` being audited despite `http` being transitively there, usage-pattern-audit rather than dep-surface-audit). Whether `flutter_app_group_directory` is telemetry-free.
   - Recommendation: **Make Dynamic Island a checkpoint-gated option in the plan**. A first plan task audits the dep per CLAUDE.md §Audit obligatoire (inspect `live_activities` source for any telemetry, inspect `flutter_app_group_directory`), documents in `DEPENDENCIES.md`. If audit passes, a later plan wave wires it. If audit fails, Drop Dynamic Island — CONTEXT.md already says it's nice-to-have with bandeau Flutter as fallback. No blocker.

2. **iOS watchdog — `significant-change location service` vs `region monitoring`**
   - What we know: Both are known-broken-ish since iOS 15 for terminated-app revive (see §Pitfall #6). `significant-change` wakes on ≥500m movement (cheap, <5% battery/day added). Region monitoring wakes on entering/leaving a defined region (requires setting the region at session start = last known position).
   - What's unclear: Which fails less often on iOS 18/19. Anecdotal reports on Apple Developer Forums favor `significant-change` for "keep trying even after termination" scenarios.
   - Recommendation: **Ship `significant-change` as the initial choice** (cheaper, simpler, no "where do I set the region" start-up question). Document the choice in a plan. If the iPhone 17 Pro POC shows it doesn't wake reliably, plan an adjustment to `region monitoring` as a Phase 15 tweak. Not a blocker for Phase 05 core delivery.

3. **Python tile-map library for `tool/plot_session_fixes.py`**
   - What we know: Two candidates widely used: `staticmap` (MIT, minimal) and `contextily` (BSD-3, heavier — depends on `geopandas`-adjacent stack for coordinate transforms).
   - What's unclear: Neither is Flutter/Dart — licence audit per `DEPENDENCIES.md` protocol doesn't strictly apply (CLAUDE.md audit is scoped to deps that ship in the binary, and `tool/` Python is dev-time only). CONTEXT.md already clarifies "script Python = hors du Flutter app proper … deps Python ne sont PAS dans `pubspec.yaml` ni `DEPENDENCIES.md`".
   - Recommendation: **`staticmap` 0.5.x**. Simplest, pure Python + PIL, MIT. Falls back to OSM static tiles with a declared User-Agent. Document its dep in `tool/README.md`. `contextily` is overkill for "draw a line of lat/lon on a basemap".

4. **`url_launcher` vs `share_plus` for `dontkillmyapp.com/[vendor]` link**
   - What we know: `share_plus 12.0.2` is already in the project (audit clean). `url_launcher` is not yet a dep.
   - What's unclear: UX-wise `url_launcher` is one tap, `share_plus` is "open share sheet → pick browser → opens". User-friction difference is small on a rarely-visited screen (OEM guidance, shown once).
   - Recommendation: **Reuse `share_plus.share()` with the URL string** — avoids adding a dep. The OEM screen flow is "read guidance, tap link to open dontkillmyapp.com/xiaomi for more details" — acceptable friction. If during implementation this feels wrong, plan a small follow-up to add `url_launcher` with full DEPENDENCIES.md audit.

5. **`SessionStore.watchAll()` — does Drift stream-refresh work with the current store interface?**
   - What we know: `DriftSessionStore.listAll()` is a one-shot `Future<List<Session>>`. For the SessionListScreen to update live (session status changes, new session created from FAB), we need either (a) Drift's `.watch()` stream on the query, (b) polling, or (c) Riverpod `ref.invalidate` on every mutation.
   - What's unclear: Current `SessionStore` port doesn't expose a watch API. Adding `Stream<List<Session>> watchAll()` is a port-breaking addition (other impls must implement).
   - Recommendation: **Extend `SessionStore` with `Stream<List<Session>> watchAll()`** in Phase 05. Drift implementation trivially supports `_db.select(_db.sessions).watch()`. Single caller; Phase 11 / 13 will benefit too. Test coverage: add a `session_store_watch_test.dart` that inserts rows and asserts the stream emits.

6. **Should the AppDatabase schema bump land in its own plan, or bundled with the fix-writing plan?**
   - What we know: Phase 03 shipped V1→V2 as a migration framework validation. V2→V3 introduces real product data.
   - What's unclear: Whether to isolate the schema change (migration, frozen dump, SchemaVerifier tests) from the consumer (FixStore + controller) for easier review/revert.
   - Recommendation: **Isolate into a dedicated plan (Plan 05-01 Wave 1 — schema + migration)**. Then Plan 05-02 layers domain entity + store impl + tests on top. This matches the Phase 03 split (03-04 schema, 03-05 backup+verifier, 03-06 stores).

## Validation Architecture

`.planning/config.json` shows `workflow.nyquist_validation: true` — section included and required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (widget + unit) + `test` 1.30.0 (plain-Dart for pure domain + Drift in-memory) — already installed |
| Config file | `dart_test.yaml` (root) — already present, declares `migration` tag with 2x timeout; Phase 05 adds `gps_integration` tag for simulated-stream tests |
| Quick run command | `dart test test/domain/ test/infrastructure/` (pure-Dart, ~5s) + `flutter test test/widget/` (widget) |
| Full suite command | `flutter test` (all) — runs every test in `test/` |
| Schema verifier | `dart test -t migration` (isolates the slow SchemaVerifier suite) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SESS-01 | Create session with name | unit | `dart test test/domain/session_invariants_test.dart` (existing) + `flutter test test/presentation/screens/session_list_screen_test.dart::createSessionViaFab` | ❌ Wave 0 (widget test) |
| SESS-02 | Rename session | unit | `dart test test/infrastructure/stores/drift_session_store_rename_test.dart::rename` | ❌ Wave 0 |
| SESS-03 | Delete session (block-if-active) | widget | `flutter test test/presentation/screens/session_detail_screen_test.dart::deleteBlockedWhenActive` | ❌ Wave 0 |
| SESS-04 | Start session | unit | `dart test test/application/controllers/active_session_controller_test.dart::startTransitionsToTracking` | ❌ Wave 0 |
| SESS-05 | Stop session | unit | `dart test test/application/controllers/active_session_controller_test.dart::stopCancelsStreamAndDeactivates` | ❌ Wave 0 |
| SESS-07 | Fixes persisted | integration | `dart test test/infrastructure/stores/drift_fix_store_test.dart::insertRetainsBytes` | ❌ Wave 0 |
| SESS-08 | List sessions with state | widget | `flutter test test/presentation/screens/session_list_screen_test.dart::activeBadgeShown` | ❌ Wave 0 |
| SESS-09 | Unlimited sessions | unit | `dart test test/infrastructure/stores/drift_session_store_stress_test.dart::insertHundredSessionsListsAll` | ❌ Wave 0 |
| GPS-01 | Always permission via pre-prompt | unit | `dart test test/application/permissions/location_permission_flow_test.dart::twoStepChainRespected` (mocks MethodChannel) | ❌ Wave 0 |
| GPS-02 | Foreground tracking | unit | `dart test test/application/controllers/active_session_controller_test.dart::acceptsPositionsFromStream` | ❌ Wave 0 |
| GPS-03 | Background tracking Android+iOS | **manual-only** | **Real-device POC per QUAL-01/02**. Document in `docs/qual-01-02-poc.md`. No automated substitute — this is what the phase EXISTS to validate. | ❌ manual |
| GPS-04 | Persistent notification | unit + manual | `dart test test/infrastructure/notifications/session_notification_service_test.dart::configuresOngoingLow` + manual notif visibility on device | ❌ Wave 0 + manual |
| GPS-05 | distanceFilter respected | unit | `dart test test/infrastructure/gps/location_settings_factory_test.dart::distanceFilterPropagatedPerPlatform` | ❌ Wave 0 |
| GPS-06 | Auto-resume post-kill | unit + manual | `dart test test/infrastructure/platform/boot_completed_watchdog_test.dart::schedulesNotifOnActiveSession` (pure-Dart portion) + manual boot test | ❌ Wave 0 + manual |
| GPS-07 | Permission denied recovery | widget | `flutter test test/presentation/screens/permission_denied_screen_test.dart::openSettingsInvokesHandler` | ❌ Wave 0 |
| GPS-08 | OEM guidance screen | widget + unit | `dart test test/infrastructure/platform/oem_detector_test.dart::xiaomiBrandMatches` + widget test | ❌ Wave 0 |
| QUAL-01 | Android OEM 30-min POC | **manual-only** | Pixel 4a/6 Pro walk — CONTEXT.md gap noted, OEM deferred Phase 15. Evidence in `docs/qual-01-02-poc.md`. | manual |
| QUAL-02 | iOS 30-min POC | **manual-only** | iPhone 17 Pro walk via sideload. Evidence in `docs/qual-01-02-poc.md`. | manual |
| QUAL-03 | Store review rationale doc | file-exists | `dart test tool/test/store_rationale_exists_test.dart::hasRequiredSections` (greps for section headings) | ❌ Wave 0 |
| QUAL-04 | Info.plist UsageDescription final | static-scan | `dart test tool/test/info_plist_final_copy_test.dart::noTodoMarkers` (parses XML, asserts no "TODO" in the 2 keys) | ❌ Wave 0 |
| Migration | V2→V3 adds `t_fixes` correctly | migration | `dart test -t migration test/infrastructure/db/v2_to_v3_migration_test.dart::schemaMatchesV3Dump` (SchemaVerifier) | ❌ Wave 0 |
| Migration | V2→V3 preserves existing data | migration | `dart test -t migration test/infrastructure/db/v2_to_v3_migration_test.dart::v2FixturesSessionsRowsIntact` | ❌ Wave 0 |
| Fix invariants | `@Assert` domain-level | unit | `dart test test/domain/fix_invariants_test.dart::rejectsOutOfRangeLatLon` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `dart test test/domain/ test/infrastructure/` (pure-Dart suite, < 10s) — run on every commit that touches `lib/domain/` or `lib/infrastructure/`.
- **Per wave merge:** `flutter test` (full test tree including widget tests) + `dart test -t migration` (SchemaVerifier).
- **Phase gate (before `/gsd:verify-work`):** Full suite green on CI (`.github/workflows/ci.yml` job `gates`) + `flutter analyze` zero warning + dart format clean + real-device POC artefact committed (`docs/qual-01-02-poc.md` + PNG in `docs/poc-artifacts/`).

### Wave 0 Gaps

Tests/fixtures to create BEFORE first production code:

- [ ] `test/application/controllers/active_session_controller_test.dart` — covers SESS-04, SESS-05, GPS-02, GPS-05 with a fake `LocationStream` emitting controlled `Position` values
- [ ] `test/application/permissions/location_permission_flow_test.dart` — covers GPS-01 with mocked `flutter.baseflow.com/permissions/methods` channel
- [ ] `test/infrastructure/gps/location_settings_factory_test.dart` — covers Pattern 1 seam + GPS-05 per platform branch
- [ ] `test/infrastructure/stores/drift_fix_store_test.dart` — covers SESS-07 with `NativeDatabase.memory()` (follows Phase 03 store-test pattern)
- [ ] `test/infrastructure/stores/drift_session_store_rename_test.dart` — covers SESS-02 rename path
- [ ] `test/infrastructure/stores/drift_session_store_stress_test.dart` — covers SESS-09 (100+ sessions sanity)
- [ ] `test/infrastructure/db/v2_to_v3_migration_test.dart` (tagged `@Tags(['migration'])`) — covers SchemaVerifier round-trip + data preservation
- [ ] `test/infrastructure/notifications/session_notification_service_test.dart` — covers GPS-04 config contract (channel importance, ongoing flag)
- [ ] `test/infrastructure/platform/oem_detector_test.dart` — covers GPS-08 brand-matching for Xiaomi / Samsung / Huawei / OnePlus / OPPO / generic
- [ ] `test/infrastructure/platform/boot_completed_watchdog_test.dart` — covers GPS-06 pure-Dart watchdog logic (not the Kotlin receiver itself)
- [ ] `test/presentation/screens/session_list_screen_test.dart` — widget test for SESS-08 (active badge, empty state, FAB)
- [ ] `test/presentation/screens/session_detail_screen_test.dart` — widget test for SESS-05 Stop button, SESS-03 block-delete-if-active, SESS-02 rename
- [ ] `test/presentation/screens/permission_rationale_screen_test.dart` — widget test for GPS-01 pre-prompt
- [ ] `test/presentation/screens/permission_denied_screen_test.dart` — widget test for GPS-07
- [ ] `test/presentation/screens/oem_guidance_screen_test.dart` — widget test for GPS-08 UI
- [ ] `test/presentation/screens/settings_screen_test.dart` — widget test for slider persistence to SharedPreferences
- [ ] `test/domain/fix_invariants_test.dart` — `@Assert` domain invariants on Fix entity
- [ ] `test/fixtures/drift_schemas/drift_schema_v3.json` — frozen dump from `drift_dev schema dump`
- [ ] `drift_schemas/drift_schema_v3.json` — production-path equivalent (per Phase 03 convention)
- [ ] `test/generated_migrations/schema_v3.dart` — generated via `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`
- [ ] `tool/test/store_rationale_exists_test.dart` — file-level test verifying `docs/store-review-rationale.md` structure
- [ ] `tool/test/info_plist_final_copy_test.dart` — asserts no "TODO" markers in the 2 target Info.plist keys
- [ ] `test/helpers/fake_location_stream.dart` — reusable fake emitting programmed `Position` values (key for all stream-related tests)
- [ ] `test/helpers/in_memory_shared_preferences.dart` — reusable fake store (OR SharedPreferences.setMockInitialValues — standard approach)

**Framework install: None needed** — `flutter_test` + `test` + `mocktail`-free pattern (Phase 03 uses hand-rolled fakes implementing port abstractions, not `mockito`/`mocktail`) already in place. `device_info_plus` ships with a platform-interface that the `OemDetector` seam wraps cleanly for tests.

## Sources

### Primary (HIGH confidence)

- [pub.dev — geolocator 14.0.2](https://pub.dev/packages/geolocator) — README verified via WebFetch 2026-04-19: AndroidSettings / AppleSettings / ForegroundNotificationConfig API, manifest/Info.plist requirements
- [pub.dev — AndroidSettings class API](https://pub.dev/documentation/geolocator_android/latest/geolocator_android/AndroidSettings-class.html) — full property list with defaults (forceLocationManager default: false; accuracy default: best; distanceFilter default: 0)
- [pub.dev — flutter_local_notifications 21.0.0](https://pub.dev/packages/flutter_local_notifications) — POST_NOTIFICATIONS permission requirement, persistent/low-importance notification configuration
- [pub.dev — permission_handler 12.0.1](https://pub.dev/packages/permission_handler) — two-step chain locationWhenInUse → locationAlways, openAppSettings() usage
- [pub.dev — device_info_plus 13.0.0](https://pub.dev/packages/device_info_plus) — BSD-3-Clause, fluttercommunity.dev verified publisher, no network calls, androidInfo.manufacturer API
- [live_activities LICENSE on GitHub](https://github.com/istornz/flutter_live_activities/blob/main/LICENSE) — MIT verified
- [Android Developers — Foreground service types (Android 14+)](https://developer.android.com/develop/background-work/services/fgs/service-types) — FOREGROUND_SERVICE_LOCATION permission + android:foregroundServiceType mandatory
- [Android Developers — Restrictions on starting foreground services from the background](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) — BOOT_COMPLETED restrictions for location-type services
- [Android Developers — Changes to foreground service types for Android 15](https://developer.android.com/about/versions/15/changes/foreground-service-types) — ongoing platform direction
- [Drift migrations API docs](https://drift.simonbinder.eu/migrations/api/) — Migrator.createTable vs customStatement
- [dontkillmyapp.com — Xiaomi](https://dontkillmyapp.com/xiaomi) — OEM-specific guidance steps (CONTEXT.md directly references this domain)
- [dontkillmyapp.com — homepage](https://dontkillmyapp.com/) — list of OEM families (Xiaomi, Huawei, OnePlus, Samsung, OPPO, etc.)
- Project sources: `lib/infrastructure/db/app_database.dart`, `lib/infrastructure/db/migrations/v1_to_v2_notes.dart`, `lib/infrastructure/stores/drift_session_store.dart`, `lib/domain/sessions/session.dart`, `lib/config/constants.dart`, `CLAUDE.md`, `.planning/STATE.md`, `pubspec.yaml`, `DEPENDENCIES.md`

### Secondary (MEDIUM confidence)

- [Baseflow flutter-geolocator GitHub issues #270, #497, #568, #616, #1023, #1290, #1520, #1555, #1663, #1727, #1739](https://github.com/Baseflow/flutter-geolocator/issues/) — empirical pitfall confirmations (error handling, screen-off gaps, forceLocationManager breakage, initial-denied-state stream behavior)
- [Apple Developer Forums — Significant-Change terminated-app relaunch regression since iOS 15](https://developer.apple.com/forums/thread/79465) — confirmed by multiple developers, spans iOS 15→17
- [baseflow permission_handler GitHub issue #452 — Android 11 background location permission issue](https://github.com/Baseflow/flutter-permission-handler/issues/452) — documents the two-step chain requirement
- [baseflow permission_handler GitHub issue #1011 — locationAlways isGranted returns true on "while using"](https://github.com/Baseflow/flutter-permission-handler/issues/1011) — edge case in status reporting
- [transistorsoft/flutter_background_geolocation issue #93](https://github.com/transistorsoft/flutter_background_geolocation/issues/93) — pauseLocationUpdatesAutomatically silently pauses on iOS (same CoreLocation API, same behavior)
- [Riverpod 3.0 what's new](https://riverpod.dev/docs/whats_new) — StreamProvider pauses on no-listener, ref.onDispose pattern
- [Android 14 ForegroundServiceStartNotAllowedException tracker](https://issuetracker.google.com/issues/307329994) — community-observed behavior deviation

### Tertiary (LOW confidence — flagged for in-plan validation)

- Various Medium / Hashnode tutorials that assemble the full stack — consulted for pattern shape, not for API authority
- [Flutter Gems — live_activities](https://fluttergems.dev/packages/live_activities/) — category listing, reputation signal only

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all core deps already pinned, licence-audited, and in `pubspec.yaml`; API surface verified directly against pub.dev docs
- Architecture: HIGH — patterns align with existing Phase 03 seams (port abstractions, Drift migrations framework, extension-type IDs, Freezed `@Assert`); introduces no novel approach
- Pitfalls: HIGH — 8 pitfalls each backed by at least one official doc or reproducible GitHub issue
- OEM behavior: MEDIUM — dontkillmyapp.com is authoritative-by-convention rather than vendor-docced; CONTEXT.md already accepts the Pixel-only POC gap
- iOS watchdog choice: MEDIUM — both approaches are best-effort since iOS 15; empirical tie-break needed in POC
- Dynamic Island: LOW — licence OK but transitive telemetry surface (`LiveActivityFileFromUrl`) needs a code-reading audit before commit; CONTEXT.md already makes it optional with bandeau fallback
- Validation architecture: HIGH — builds on Phase 03 test-runner split (`dart test` domain + in-memory Drift, `flutter test` widgets) + migration-tagged SchemaVerifier path; real-device POC is explicit manual-only per the phase's risk-reducing purpose

**Research date:** 2026-04-19
**Valid until:** 2026-07-19 (approximately 90 days — most sources are stable platform documentation; re-verify geolocator and flutter_local_notifications release notes before Phase 05 kickoff if more than ~60 days pass)
