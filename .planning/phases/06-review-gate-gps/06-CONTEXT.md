# Phase 06: Review Gate — GPS - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Audit exhaustif de Phase 05 (GPS & Session Lifecycle — 6/6 plans livrés 2026-04-19, Pixel 4a POC PASS + iPhone 17 Pro POC PASS-with-caveat, risque projet #1 empiriquement validé) avant que Phase 07 Map Integration ne dépende du tracking GPS. Un bug GPS rattrapé ici coûte un sprint ; rattrapé en Phase 09 fog il coûte la V1.0.

Phase 06 réutilise et étend les patterns Phase 02 Review Gate Foundation + Phase 04 Review Gate Persistence (5-section REVIEW.md, 4 sub-agents `general-purpose` parallèles, sévérité Blocker/Should/Could/Noted, atomic commits CI-vert avant le suivant, pre-classification §2 avant spawn, inertness-guarded unit tests) avec des concerns GPS-runtime-specifiques qui divergent sur plusieurs points clés.

**Dans le scope Phase 06 :**
- Audit exhaustif fichier-par-fichier de tous les artefacts Phase 05 (`lib/domain/sessions/`, `lib/domain/gps/`, `lib/infrastructure/gps/`, `lib/infrastructure/notifications/`, `lib/infrastructure/platform/`, `lib/infrastructure/boot_watchdog/`, `lib/application/permissions/`, `lib/application/controllers/`, `lib/application/providers/`, `lib/presentation/screens/` pour les écrans Phase 05, `lib/presentation/widgets/` banner, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/.../BootCompletedReceiver.kt`, `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`, `test/domain/gps/**`, `test/infrastructure/gps/**`, `test/infrastructure/notifications/**`, `test/infrastructure/platform/**`, `test/infrastructure/boot_watchdog/**`, `test/application/permissions/**`, `test/application/controllers/**`, `test/presentation/**` pour Phase 05, `tool/plot_session_fixes.py`, `tool/requirements.txt`, `docs/store-review-rationale.md`, `docs/qual-01-02-poc.md`, `docs/poc-artifacts/`, `pubspec.yaml` deltas Phase 05 (geolocator, flutter_local_notifications, permission_handler, device_info_plus 12.4.0), `DEPENDENCIES.md` entries Phase 05)
- POC evidence review (§1b) — acceptance de "PASS-with-caveat" iOS 13.5 min + Pixel 4a 28.6 min PASS, validation artifacts `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png`, extraction opportuniste battery delta
- Pre-classification §2 des 8 handoff items connus AVANT spawn des 4 sub-agents (voir §Implementation Decisions ci-dessous)
- Adversarial wave : 4 permanent unit tests (MethodChannel drift / permission cascade / OEM ambiguous match / platform manifest drift) + 1 nouveau garde-fou CI `tool/check_platform_manifests.dart` stress-testé via branche `adversarial/06-manifest-drift` + 5e test de contrat BootCompletedReceiver Android
- Application des fixes choisis (Blocker + Should), commits atomiques `fix(06-rev): <title>`, CI verte avant clearance, batched strategy permissible si user approuve (précédent Phase 04 Plan 04-05)
- Artefact persistant `06-REVIEW.md` (5 sections : User-observed+POC evidence review / Claude audit / Triage / Adversarial / CI-green)
- Amendement ROADMAP.md SC#1 (chemin artifacts `docs/` au lieu de `.planning/pocs/phase-05/`)

**Hors scope (autres phases) :**
- Toute ligne de code Map, Fog, Markers, Import/Export, Mirk Styles — Phases 07+
- "Tracking interrompu on next launch" banner (Phase 15 SC#4 recovery flow)
- Native per-OEM battery-settings deep-link intents (MIUI / EMUI / OneUI / OxygenOS) — Phase 15 polish
- Second iOS POC walk étendu à 30 min — Phase 15 release-confidence test (optionnel selon user)
- Auto-resume-post-kill iOS validation complète — Phase 15 quand FlutterImplicitEngineDelegate sera rewiré
- Xiaomi / Samsung / Huawei / OnePlus device coverage testing — Phase 15 release testing
- Store rationale English copy finalisation — Phase 15 polish
- Fix des MPL-unreachable heuristic `tool/check_licenses.dart` — backlog Phase 02 résiduel ou Phase 16
- Investigation profonde battery profiling + tooling Python dumpsys parser — Phase 15 si user veut measurement formel

</domain>

<decisions>
## Implementation Decisions

### Sub-agent slicing : par layer technique (4 agents)

Layer-based slicing adapté aux concerns Phase 05 (mix pure-Dart + platform-native + POC tooling).

- **Agent #1 — GPS infra + notifications** :
  - `lib/infrastructure/gps/` (GeolocatorLocationStream, LocationSettingsFactory, LocationStream port impl, distanceFilter int typing regression guard)
  - `lib/infrastructure/notifications/` (SessionNotificationService, LocalNotificationsPort, FlutterLocalNotificationsAdapter, Android channel creation, iOS permission requests)
  - `android/app/src/main/AndroidManifest.xml` (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, BootCompletedReceiver declaration)
  - `ios/Runner/Info.plist` (NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, UIBackgroundModes location + fetch, NSUserActivityTypes si applicable)
  - `lib/domain/gps/` (Fix entity, FixStore port, GpsError, LocationStream port)
  - `lib/infrastructure/db/app_database.dart` delta V2→V3 (t_fixes table + indexes)
  - `test/infrastructure/gps/**`, `test/infrastructure/notifications/**`, `test/domain/gps/**`
  - Vérifie : distanceFilter typing (int, pas double), pragma cohérence, permissions déclarées = permissions demandées

- **Agent #2 — Controller + permissions + state** :
  - `lib/application/controllers/active_session_controller.dart` (ActiveSessionController, sealed ActiveSessionState : Idle/Starting/Tracking/Stopping/ErrorState, start()/stop()/resume() lifecycle)
  - `lib/application/permissions/location_permission_flow.dart` (requestLocationAlways, PermissionRequester typedef seam, two-step whenInUse→always chain, Android 13+ POST_NOTIFICATIONS first)
  - `lib/application/providers/` (session_settings_provider, active_session_controller_provider, oem_detector_provider, fix_store_provider, location_stream_provider, session_notification_provider, etc.)
  - `lib/application/settings/session_settings.dart` (distanceFilter, displayName defaults)
  - `test/application/controllers/**`, `test/application/permissions/**`, `test/application/settings/**`
  - Vérifie : cancelOnError: false sur subscription, ConcurrentActivationException propagation non-typée, AsyncValue.value (Riverpod 3.x) pattern, two-step permission invariant (whenInUse avant always)

- **Agent #3 — UI + routing** :
  - `lib/presentation/screens/session_list_screen.dart`, `session_detail_screen.dart`, `settings_screen.dart`, `oem_guidance_screen.dart`, `permission_rationale_screen.dart`, `permission_denied_screen.dart`, `location_interrupted_screen.dart` si existe
  - `lib/presentation/widgets/active_session_banner.dart` (banner InkWell split : inner title-only + peer IconButton stop, pattern Phase 05)
  - `lib/application/routing/router.dart` + `rootNavigatorKey` top-level (NOT inside @riverpod)
  - `test/presentation/**` pour Phase 05 screens + banner widget tests
  - Vérifie : canPop() ? pop() : go('/') discipline sur deep-linkable screens (OemGuidanceScreen), pumpAndSettle avoidance sur écrans avec Stream.periodic, ProviderScope overrides inline (Override pas exporté par flutter_riverpod 3.3.x), WidgetsBinding.addPostFrameCallback pour dispose d'controllers pendant animations

- **Agent #4 — Boot watchdog + native bridges + POC tooling + CLAUDE.md sweep** :
  - `lib/infrastructure/boot_watchdog/boot_completed_watchdog.dart` (BootCompletedWatchdog Dart logic, runBootWatchdogEntryPoint entry point, channel constant 'app.gosl.mirkfall/boot_watchdog', DB reopening via buildAppDatabase factory, mandatory engine.destroy + DB close try/finally)
  - `lib/infrastructure/boot_watchdog/ios_significant_change_watchdog.dart` (wrapper class no-op non-iOS, wraps controller hook)
  - `android/app/src/main/kotlin/.../BootCompletedReceiver.kt` (Android receiver, notification-only NOT fg-service start from boot, channel string literal)
  - `ios/Runner/AppDelegate.swift` (FlutterImplicitEngineDelegate si rewired ; sinon stripped Xcode 26 move — pre-class item)
  - `tool/plot_session_fixes.py`, `tool/requirements.txt` (staticmap 0.5.x + Pillow deps audit)
  - `docs/store-review-rationale.md` (QUAL-03 content + English polish scope)
  - `docs/qual-01-02-poc.md` + `docs/poc-artifacts/*` (POC evidence review — completeness, cadence data, battery deltas si présents)
  - `pubspec.yaml` deltas Phase 05 (geolocator pin, flutter_local_notifications 21.0.0 pin, permission_handler pin, device_info_plus 12.4.0 pin justification vs 13.0.0 win32 conflict), `DEPENDENCIES.md` entries Phase 05
  - CLAUDE.md anti-patterns sweep sur tout le code Phase 05 : magic numbers hors `lib/config/constants.dart`, naming conventions (`xxxFilename` vs `xxxFileName` vs `xxxBasename` vs `xxxDir`, `valueByKey` Maps, `xxxSet` Sets, `xxxs` Lists), DTOs sans sémantique distincte, wrappers de delegation, commentaires narrant le quoi, context.mounted discipline post-await, const constructors widgets, magic de path sans p.join
  - `lib/config/constants.dart` deltas Phase 05 (kDistanceFilterMeters, kFixBatchFlushInterval, timeouts GPS)
  - Vérifie : triple-source-of-truth MethodChannel (Kotlin + Swift + Dart constants match), DEPENDENCIES.md entries Phase 05 complètes, tool Python deps in `tool/requirements.txt` scope-correct (tool-side, pas binary-ship-scoped)

### Audit depth : exhaustif fichier-par-fichier

- Mêmes règles que Phases 02 + 04 (CONTEXT 02 §Audit scope & depth, CONTEXT 04 §Audit depth) :
  - Chaque `.dart` sous `lib/` modifié ou créé Phase 05 audité ligne à ligne
  - Chaque `test/**` Phase 05 audité (assertions réelles vs placebo, @Tags discipline si applicable, mock correctness via fakes au lieu de mockito)
  - Chaque `.kt` / `.swift` / `.plist` / `.xml` native platform audité
  - Chaque fixture committée vérifiée (cohérence fake device_info, parseable JSON, anti-régression)
  - Aucune exclusion silencieuse (les `.g.dart` / `.freezed.dart` ne sont pas audités comme code humain mais leur génération est validée par les tests)
- ~90-120 fichiers `.dart` Phase 05 + ~50-70 test files + 3 native bridges (Kotlin + Swift + Info.plist) + 2 POC docs + 1 Python tool. Charge supérieure à Phase 04 (native code + POC docs ajoutés).

### POC evidence acceptance (pre-class §2 items)

- **iOS walk duration** — 13.5 min / 82 fixes / 6s/fix cadence stable throughout, vs 30 min SC#2 target.
  - **Severity : Noted** (PASS-with-caveat accepted per CONTEXT).
  - Rationale inline §2 : "Convergent same-day Android evidence (Pixel 4a 28.6 min / 342 fixes PASS) supports extrapolation. Stable cadence throughout the 13.5 min walk indicates no background suspension; geolocator foreground path is healthy on iOS 26. A full 30-min walk is a cheap optional top-up in Phase 15 release-confidence if needed."
  - Phase 06 gate CLOSES without re-walk. User may request one in Phase 15 polish.

- **POC artifacts location drift** — SC#1 says `.planning/pocs/phase-05/`, actual files live in `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png`.
  - **Severity : Should** (fix in Phase 06 fix-loop : amend ROADMAP.md SC#1).
  - Rationale : `docs/` is the natural home for narrative + screenshots (indexed by the project, linkable from README/About). `.planning/` is process-internal. Amendment records the reason inline in ROADMAP.md diff.
  - Fix task : 1 commit `docs(06-rev): amend ROADMAP.md SC#1 to match docs/ artifact location` in fix-loop.

- **SC#2 battery measurement** — "< 15%/h walking mode with distanceFilter configured".
  - **Severity : Noted** (record from existing POC evidence if available, else waive with rationale).
  - Rationale : fix cadence stability (6s/fix on iOS, regular deltas on Android) is a proxy for battery-healthy GPS path. Full dumpsys battery_stats measurement → Phase 15 release-confidence if user wants formal proof. Agent #4 extracts opportunistic battery delta from `docs/qual-01-02-poc.md` if present; if absent, inline waiver §2 with the fix-cadence proxy argument.

- **Xiaomi / Samsung / Huawei / OnePlus OEM coverage** — deferred Phase 15 per 05-CONTEXT.md.
  - **Severity : Noted** (already accepted Phase 05 planning).
  - Rationale : ROADMAP SC#1 Phase 05 was annotated "partial" at Phase 05 close. Phase 06 gate does not re-litigate.

- **Auto-resume-post-kill iOS unvalidated** — FlutterImplicitEngineDelegate bridge stripped Xcode 26 move, deferred Phase 15.
  - **Severity : Noted** (already accepted Phase 05 planning).
  - Rationale : Android auto-resume is covered (4 BootCompletedWatchdog unit tests + Plan 05-05). iOS path needs FlutterImplicitEngineDelegate rewire in Phase 15 after Apple stabilizes scene-based API.

- **Store rationale English copy** — final polish Phase 15.
  - **Severity : Noted** (already accepted Phase 05 planning).
  - Rationale : French copy is defended-by-reviewer quality. English polish is an App Store submission concern, not a gate-closure concern.

- **Flaky widget-test pumpAndSettle races** (if re-surface during audit wave).
  - **Severity : Should** (pre-flag as known-pattern ; agents may find more or confirm none).
  - Rationale : Phase 05 explicitly documented pumpAndSettle avoidance on Tracking dashboard (Stream.periodic 1s). If Agent #3 UI lens re-surfaces any `pumpAndSettle()` call in Phase 05 tests not wrapped by bounded `pump(Duration)`, that's a Should fix.

- **dart format drift regression watch** (Phase 04 surprise Blocker).
  - **Severity : Noted** (monitor ; no pre-flag fix assumed).
  - Rationale : Phase 04 surfaced 61-file pre-existing drift on main. `dart format --set-exit-if-changed` CI gate is active since Plan 04-05. Agent #4 runs it locally to confirm zero drift ; if drift found, becomes Should fix in loop.

### SC#4 OEM workaround gate-closure

- **Current state (shipped Phase 05)** :
  - `OemGuidanceScreen` (`lib/presentation/screens/oem_guidance_screen.dart`) renders per-vendor 2-step guidance + `dontkillmyapp.com/[vendor]` link via `share_plus`
  - `OemDetector` (`lib/infrastructure/platform/oem_detector.dart`) detects OemFamily sealed variants from `device_info_plus 12.4.0`
  - `openLocationSettings()` deep-link available in `permission_handler` (used by `permission_denied_screen.dart` and accessible from OemGuidanceScreen by reuse)
  - Cross-route active session banner shipped Plan 05-04

- **Gate-closure requirement (§2 Should fix in loop)** :
  - Build a `§2 OEM workaround plan` table in 06-REVIEW.md listing : OemFamily variant → OemGuidanceScreen copy summary → dontkillmyapp.com URL → openLocationSettings reachability → pre-class severity
  - Link to `docs/store-review-rationale.md` for store-facing user guidance (if content overlap exists)
  - Artifact self-contained : future maintainer reads §2 and understands the Phase 06 signed-off OEM workaround baseline

- **Deferred Phase 15 (Noted pre-class)** :
  - "Tracking interrompu on next launch" banner (overlaps Phase 15 SC#4 recovery banner)
  - Native per-OEM battery-settings intent deep-links (MIUI Security / Huawei PhoneManager / Samsung DeviceCare / OnePlus Battery) — maintenance drift across OS versions, dontkillmyapp.com link suffices for V1.0
  - Second iOS POC walk reaching 30 min target

### Adversarial wave design : 4 permanent unit tests + 1 new CI gate

Ciblent les artefacts runtime Phase 05 + Les garde-fous manquants au niveau platform manifest. Phases 02 + 04 ont couvert les gate scripts (licence/headers/deps/domain-purity/schema-drift). Phase 06 ajoute 1 nouveau gate platform-manifests + 4 permanent unit tests anti-régression.

- **Test #1 — MethodChannel triple-source drift regression guard (permanent unit test)** :
  - Fichier : `test/infrastructure/boot_watchdog/method_channel_sync_test.dart`
  - Invariant : le channel constant `'app.gosl.mirkfall/boot_watchdog'` est défini dans `lib/infrastructure/boot_watchdog/boot_completed_watchdog.dart` ET mirror-é comme string literal dans `android/app/src/main/kotlin/.../BootCompletedReceiver.kt` ET dans `ios/Runner/AppDelegate.swift`.
  - Test : `Process.run('rg', [kBootWatchdogChannel.value, '-l', 'android/', 'ios/'])` ou équivalent pure-Dart File + regex, assert que les 2 fichiers contiennent la string exacte + fail si mismatch avec liste des diffs.
  - Inertness guard : avant `expect(...)`, une intermediate assertion que les 3 fichiers existent réellement sur disque (sinon le test est silent-inert lors d'un refactor de path).
  - Evidence §4 : commit hash du test ajouté, output `dart test` green.

- **Test #2 — Permission-denied cascade regression guard (permanent unit test)** :
  - Fichier : `test/application/permissions/location_permission_cascade_test.dart` (existant ou nouveau selon couverture)
  - Invariant : driving `requestLocationAlways` through denied → permanentlyDenied → restricted statuses at each stage returns the correct `LocationPermissionOutcome` AND routes to the correct UI (PermissionDeniedScreen vs OemGuidanceScreen vs settings).
  - Test : 4 scenarios avec PermissionRequester fake capturant chaque invocation + returning programmed statuses. Assert la séquence d'invocations (notification → whenInUse → always) + l'outcome final.
  - Inertness guard : avant d'asserter l'outcome final, intermediate expect que le fake a reçu N invocations (sinon un refactor qui skip un step serait silent-inert).
  - Evidence §4 : commit hash, output `dart test` green.

- **Test #3 — OemDetector ambiguous match regression guard (permanent unit test)** :
  - Fichier : `test/infrastructure/platform/oem_detector_ambiguous_test.dart`
  - Invariant : injecter un AndroidDeviceInfo fake avec des champs ambigus (ex : `manufacturer=aosp` + `brand=oneplus`, ou `manufacturer=xiaomi` + `brand=redmi` + buildId containing `miui`), assert `detect()` returns a deterministic OemFamily bucket (pas crash, pas silent fallthrough).
  - Test : 3-5 fixtures d'ambiguïté, assertion sur la priorité de résolution (ex : manufacturer prime sur brand, ou brand prime si manufacturer=aosp, etc. selon décision Phase 05).
  - Inertness guard : avant d'asserter le bucket, intermediate expect que le fake a été consommé (fake instrumenté avec un flag read).
  - Evidence §4 : commit hash, output `dart test` green.

- **Test #4 — Platform manifest drift regression guard (permanent unit test)** :
  - Fichier : `test/tooling/platform_manifests_test.dart`
  - Invariant : `android/app/src/main/AndroidManifest.xml` contains required uses-permission entries (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED) + BootCompletedReceiver declaration with BOOT_COMPLETED intent filter. `ios/Runner/Info.plist` contains required keys (NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, UIBackgroundModes with location + fetch).
  - Test : parse XML + plist via `package:xml` + `package:plist` (or pure-Dart regex if deps trop lourdes), assert all required entries present with correct values.
  - Inertness guard : avant d'asserter, intermediate expect que les 2 fichiers existent + parse OK (sinon refactor de path serait silent-inert).
  - Evidence §4 : commit hash, output `dart test` green.

- **Test #5 — Android BootCompletedReceiver contract test (permanent unit test)** :
  - Fichier : `test/infrastructure/boot_watchdog/android_boot_receiver_contract_test.dart`
  - Invariant : AndroidManifest.xml declares BootCompletedReceiver with correct intent-filter + correct Kotlin class path + the MethodChannel string literal in BootCompletedReceiver.kt matches the Dart constant (dédouble avec Test #1 mais scopé strictement Android).
  - Test : parse AndroidManifest.xml, grep BootCompletedReceiver.kt, assert consistency.
  - Inertness guard : same pattern as Test #1.
  - Evidence §4 : commit hash, output `dart test` green.
  - Note : complement à Test #1 (MethodChannel cross-platform) — ce test est Android-scope ; iOS equivalent futur Phase 15.

- **Nouveau garde-fou CI : `tool/check_platform_manifests.dart`** :
  - Script Dart standalone, même contract que check_domain_purity / check_licenses / check_headers : exit 0 (clean) / 1 (policy violation) / 2 (misconfiguration).
  - Parse AndroidManifest.xml + Info.plist, vérifie required entries, print violations to stderr, exit 1 si missing.
  - Ajouté au `.github/workflows/ci.yml` `gates` job alongside existing checks.
  - Pair le garde-fou script avec Test #4 unit test : script = CI gate ; test = dart test coverage + inertness guard.

- **Adversarial CI branch : `adversarial/06-manifest-drift`** :
  - Poison commit : retirer `ACCESS_BACKGROUND_LOCATION` de AndroidManifest.xml OU retirer `UIBackgroundModes location` de Info.plist.
  - Push → CI step `dart run tool/check_platform_manifests.dart` doit fail avec exit 1 et message identifiant le fichier + entry missing.
  - Evidence §4 : branch name, commit hash, run URL, exit code, stderr extrait listant le fichier + entry manquant.
  - Cleanup : branche supprimée local + remote post-archivage.
  - Pas de PR (évite notifications, conserve historique main propre).

- **Structure adversariale : simplifiée vs Phase 02 / 04** :
  - Pas de multi-branch ciblant des gates différents (Phases 02 + 04 poisoned 3 gates chacune). Phase 06 a 1 seul nouveau gate (platform-manifests) donc 1 seule adversarial branch.
  - Les 4 autres stress-tests sont permanent unit tests (pattern Phase 04 Test #3 élargi), pas throwaway branches.
  - Sequencing : unit tests #1-5 peuvent être écrits en parallèle (même wave planning) ; adversarial branch #1 peut être poisoner avant ou après (indépendant).

### POC evidence review (§1b) — no runtime walk

**Décision user 2026-04-20** : pas de runtime walk additionnel au-delà des POCs Phase 05 (rationale user : "already validated during POC, redundant"). §1b de 06-REVIEW.md devient "POC evidence review" au lieu de "Runtime walk" :

- Agent #4 (POC tooling lens) lit `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png` + tout autre artifact POC committed
- Extraits inline §1b : Pixel 4a walk summary (342 fixes / 28.6 min / cadence), iPhone 17 Pro walk summary (82 fixes / 13.5 min / cadence), battery deltas si présents dans les artifacts, store-review-rationale.md content snapshot, QUAL-03 compliance check
- Format : collapsible `<details>` markdown sections par device, inline summary tables pour cadence data

Ceci diverge explicitement de Phase 04 (où `tool/walk_db.dart` était un runtime observation fresh ; Phase 06 POC walks ARE the runtime observation).

### Ordering : strict user-first protocol Phase 02 + Phase 04

- User poste ses findings IDE en chat **AVANT** que Claude spawn quoi que ce soit
- Claude capture verbatim dans `06-REVIEW.md §1` (ou `'Aucune observation utilisateur'` marker si user n'en a aucune — précédent Phase 04)
- **ENSUITE** POC evidence review §1b par Agent #4 (pas un runtime walk fresh, lecture des POC artifacts committed)
- **ENSUITE** pre-class §2 des 8 handoff items connus
- **ENSUITE** spawn les 4 sub-agents en single tool-use message
- Si user flag un point, un agent peut être briefé explicitement à le creuser
- Parallèle (user tape pendant que agents tournent) explicitement rejeté — précédent Phases 02 + 04

### Output contract des sub-agents : même que Phases 02 + 04

- **Structured findings** (l'essentiel, alimente la présentation user) :
  ```
  [severity] Title — 1-line explanation — file:line
  ```
  Sévérités : `Blocker` / `Should` / `Could` / `Noted` (mêmes définitions que CONTEXT 02 §Findings artefact & triage).
- **Narrative appendix** : prose audit report archivé dans `06-REVIEW.md` section "Audit Notes" (pas montré à l'user dans la présentation initiale, consultable si question).
- gsd-verifier grep `^## [1-5]\.` pour confirmer les 5 sections présentes (pattern locked Phase 02 + 04).

### Agent type : all 4 general-purpose

Phase 02 + 04 ont locked la règle "all 4 general-purpose for wave consistency even when one is read-only". Phase 06 respecte le précédent malgré la tentation d'optimiser Agent #4 (CLAUDE.md sweep + POC review + tooling) en Explore pour économiser du compute. Prédictibilité cross-review-gates l'emporte.

### Fix workflow + gate-closed criteria : pattern Phases 02 + 04

- Commits atomiques `fix(06-rev): <title>` (ou `refactor(06-rev):` / `docs(06-rev):` / `test(06-rev):` / `chore(06-rev):` selon nature), un per finding
- Batched strategy permissible si user approuve explicitement au moment de Plan 06-05 (précédent Phase 04 Plan 04-05 : 10 batches × ~10 min CI gate au lieu de 31 atomic per-finding). Trade-off bisectability-batch vs wall-clock CI.
- Chaque commit passe la CI avant le suivant — feedback rapide + bisectable + revertable finding-par-finding (ou finding-batch si batched)
- **Gate-closed** :
  - Tous findings `Blocker` fixés (pas de waiver possible)
  - Tous findings `Should` soit fixés soit explicitement waiver avec rationale inline dans REVIEW.md §3
  - CI verte sur le commit final `main`
  - `06-REVIEW.md` complet, 5 sections remplies, §1b POC evidence review avec extracts inline, §2 8 pre-class items avec severity + rationale + SC#4 OEM workaround plan table, §4 evidence block adversarial branch CI + 5 commit hashes des unit tests, §5 CI-green confirmation
  - `tool/check_platform_manifests.dart` ajouté au CI gates job, confirmé green sur le commit final
  - `gsd-verifier` vérifie ces conditions pour marquer Phase 06 complete et débloquer Phase 07

### Claude's Discretion

- Choix exact du wave layout des plans Phase 06 (combien de plans, scaffold/POC-review/pre-class/agents/adversarial/fixes — à arbitrer en planning, mais le POC evidence review DOIT être un plan ou sub-step AVANT les agents, idem pre-class §2)
- Format exact de l'evidence inline du POC evidence review dans REVIEW.md §1b (collapsed `<details>` markdown par device vs liste plate vs tableau combiné)
- Ordre d'écriture des 5 unit tests adversariaux (parallèle vs séquentiel, single commit vs per-test commit — selon ce que le planner estime tractable)
- Choix exact du package parsing XML/plist pour Test #4 + `tool/check_platform_manifests.dart` (`package:xml` + `package:plist` si licences MirkFall-compatibles + audit DEPENDENCIES.md OK ; sinon pure-Dart regex)
- Stratégie de cleanup de la branche `adversarial/06-manifest-drift` (delete immédiat post-archivage vs delete batch en fin de Plan 06-XX)
- Format exact de la §2 OEM workaround plan table (markdown table 4 colonnes vs sections per-OemFamily vs hybride)
- Découpage interne d'Agent #4 (CLAUDE.md anti-patterns sweep + POC review + native bridges + tooling peut être un pass combiné ou divisé selon ce que l'agent estime tractable — priorité aux findings, pas au découpage)
- Re-scope d'un agent si user IDE findings flaggent un angle spécifique (ex : user flag un bug UI → Agent #3 briefé explicitement à creuser cet angle en priorité)
- Choix exact des fixtures OemDetector ambiguous test #3 (3 fixtures minimum, jusqu'à 5 selon les combinaisons OEM significatives Phase 05)
- Format du commit subject line des 5 unit tests adversariaux (`test(06-rev): add regression guard for X` vs `feat(06-rev): add regression test Y` selon convention)

</decisions>

<specifics>
## Specific Ideas

- **CI est l'autorité aussi pour l'adversarial Phase 06** — pas de `act` local, pas de simulation. On pousse réellement `adversarial/06-manifest-drift`, on observe la vraie CI, on archive le vrai run ID. Même précédent Phases 02 + 04 : si on ne fait pas confiance à la CI pour les tests adversariaux, on ne peut pas lui faire confiance pour la production.
- **POC evidence IS the runtime walk** — explicite user decision 2026-04-20 ("already validated during POC, redundant"). §1b devient lecture/extraction des artifacts POC committed, PAS un fresh `flutter run -d android` walk. Divergence délibérée vs Phases 02 + 04 où le walk était frais. Rationale : GPS-focused review gate où les artifacts POC SONT l'observation runtime définitive (30 min background walks sur vrais devices).
- **Pre-class 8 items avant spawn** — Phase 04 avait 3 pre-class. Phase 06 en a 8 parce que le handoff Phase 05 a plus de items décidés (iOS caveat, artifact location drift, battery waiver, OEM deferral, auto-resume deferral, store rationale deferral, flaky widget pattern watch, dart format drift watch). Libère les 4 agents pour chercher les angles morts adjacents au lieu de rediscover les connus.
- **Artifact location amendment est un Should, pas un Noted** — ROADMAP.md SC#1 est un contrat de phase. Le modifier sans commit éphémère + rationale serait silent-drift. Fix en boucle : 1 commit `docs(06-rev): amend ROADMAP.md SC#1 to match docs/ artifact location`.
- **MethodChannel drift regression guard est critique** — 3 sources de vérité (Kotlin + Swift + Dart) pour `'app.gosl.mirkfall/boot_watchdog'`. Aucun compilateur ne vérifie la cohérence cross-language. Un dev qui rename le channel côté Dart pour une raison X pourrait silencieusement casser BootCompletedReceiver.kt et/ou AppDelegate.swift sans CI failure, sans runtime failure (no-op silent sur les natives si le channel ne matche pas). Test #1 + Test #5 sont les garde-fous.
- **Adversarial structure est plus simple que Phases 02 + 04** — un seul nouveau CI gate (platform-manifests) vs 3 existants chacun Phases 02 + 04. Donc 1 seule throwaway branch `adversarial/06-manifest-drift`. Les 4 autres stress-tests sont permanent unit tests, plus maintenables et plus robustes à long terme que des branches jetables.
- **Solo-dev review sans PR, sans reviewer humain tiers** — l'audit Claude (4 sub-agents) + l'audit IDE de l'user + le POC evidence review sont les trois seuls moteurs de review. Le protocole `user first → POC review second → Claude agents third` n'est pas cosmétique : il force l'user à ne pas être biaisé par ce que Claude trouve, et la POC review à ne pas être biaisée par ce que les agents trouvent.
- **Les 4 sub-agents sont lancés en une seule tool-use message** (multi Agent tool calls en parallèle), pas en série. Sinon l'avantage wall-clock est perdu et on se retrouve avec un single thorough Explore déguisé. Même précédent Phases 02 + 04.
- **SC#4 OEM workaround plan table est un artefact §2** (pas §3), parce que c'est une classification pre-connue PRE-AGENT, pas une finding surfaced BY agent. §2 est le bon endroit pour cette scope baseline.
- **Inertness guard applied uniformly** — Phase 04 Test #3 a prouvé la valeur (mutation experiment DELETE WHERE 1=0 → test fail loudly). Phase 06 applique partout. Coût : 1-2 lignes par test, bénéfice : protection permanente contre refactor silent-neutralize.
- **Phase 06 est la dernière review gate avant le sprint UX lourd (Phases 07 carte + 09 fog + 11 markers + 13 import/export)**. Un bug GPS qui passe ici peut contaminer 4 phases de features. La discipline d'audit exhaustive n'est pas négociable même si Phase 05 est "seulement" GPS.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 02 + 04 + 05)

- **Pattern Phase 04 review-gate + pre-class + inertness guard complet** (`04-CONTEXT.md`, `04-REVIEW.md`, plans 04-01..04-05) — template directement réutilisable avec les divergences Phase 06 documentées ci-dessus (POC review au lieu de runtime walk, 8 pre-class au lieu de 3, 5 unit tests au lieu de 3 tests mixed format).
- **`tool/check_domain_purity.dart` + `tool/check_licenses.dart` + `tool/check_headers.dart` + `tool/check_dependencies_md.dart`** — référence pattern pour `tool/check_platform_manifests.dart` (exit 0/1/2 contract, CI gates job integration, unit test for the tool itself).
- **`drift_schemas/drift_schema_v{1,2,3}.json` + CI guard** — pattern frozen-vs-rolling à ne pas toucher Phase 06 (Phase 05 a déjà shipped V3).
- **`OemGuidanceScreen`** (`lib/presentation/screens/oem_guidance_screen.dart`) — point de départ pour la §2 OEM workaround plan table. Utilise `share_plus` (audit Phase 01) pour le link dontkillmyapp.com.
- **`OemDetector`** (`lib/infrastructure/platform/oem_detector.dart`) — central pour Test #3 ambiguous match. Injection `isIosOverride`/`isAndroidOverride` permet test déterministe.
- **`location_permission_flow.dart`** (`lib/application/permissions/`) — `PermissionRequester` typedef seam central pour Test #2 permission cascade.
- **`BootCompletedWatchdog`** (`lib/infrastructure/boot_watchdog/boot_completed_watchdog.dart`) — 4 existing unit tests (active/none/idempotent/error-swallow) ; Test #5 ajoute le 5e contract test Android-scope.
- **Channel constant `'app.gosl.mirkfall/boot_watchdog'`** — triple source Kotlin + Swift + Dart, central pour Test #1 + Test #5.
- **`GeolocatorLocationStream` + `LocationSettingsFactory`** (`lib/infrastructure/gps/`) — audité par Agent #1, distanceFilter int typing regression locked Phase 05.
- **`SessionNotificationService` + `FlutterLocalNotificationsAdapter` + `LocalNotificationsPort`** (`lib/infrastructure/notifications/`) — audité par Agent #1, seam en place.
- **`ActiveSessionController` + sealed `ActiveSessionState`** (`lib/application/controllers/`) — central Agent #2, pattern Riverpod 3.x AsyncValue.value.
- **`SessionListScreen` + `SessionDetailScreen` + `SettingsScreen` + `PermissionRationaleScreen` + `PermissionDeniedScreen` + `OemGuidanceScreen` + active session banner** (`lib/presentation/screens/` + `lib/presentation/widgets/`) — audités par Agent #3.
- **`tool/plot_session_fixes.py` + `tool/requirements.txt` + `docs/store-review-rationale.md` + `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png`** — audités par Agent #4 + source du §1b POC evidence review.
- **`02-REVIEW.md` + `04-REVIEW.md`** — exemplars concrets du format final attendu pour `06-REVIEW.md`. Réutilisation du template 5 sections + sous-section narrative Audit Notes.
- **GitHub Actions CI** (`.github/workflows/ci.yml`) — la `gates` job inclut Phase 01-04 : `check_headers`, `check_licenses`, `check_dependencies_md`, `check_domain_purity`, `drift_schema_current guard`, `dart test test/domain/ test/infrastructure/`, `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos --fatal-warnings`. Phase 06 ajoute `dart run tool/check_platform_manifests.dart`. Adversarial `adversarial/06-manifest-drift` attend exit 1 avec message identifiant le fichier + entry missing.
- **`.github/workflows/ci.yml` on.push.branches += 'adversarial/**'** (précédent Phase 02) — pattern trigger expansion inline sur chaque throwaway branch pour que la CI tourne sur `adversarial/06-manifest-drift` sans modifier main trigger.

### Established Patterns (from Phases 02 + 04)

- **5-section REVIEW.md artifact contract** locked Phases 02 + 04 (`02-CONTEXT §Findings artefact & triage`). gsd-verifier greps `^## [1-5]\.` to confirm 5 headings. Reusable across all even-numbered phases incl. Phase 06.
- **4-parallel-sub-agent audit wave template validated** Phases 02 + 04 (54 + 86 findings in single wall-clock slot each). Single tool-use message spawning 4 concern-sliced `general-purpose` agents. Phase 06 reuses pattern + adapts slicing layer-based.
- **All 4 audit agents `general-purpose`** for wave consistency — Phase 06 garde la règle.
- **User-first ordering strict** locked Phases 02 + 04. Phase 06 ajoute POC evidence review §1b AVANT spawn agents : `user IDE → POC review → 4 agents`.
- **Severity tiers Blocker / Should / Could / Noted** + définitions conservées.
- **Atomic commits `fix(02-rev): <title>` / `fix(04-rev): <title>`** → Phase 06 utilise `fix(06-rev): <title>`.
- **Adversarial branches throwaway `adversarial/02-*` / `adversarial/04-*`** deleted local + remote post-archivage → Phase 06 utilise `adversarial/06-manifest-drift` même discipline.
- **CI exit code contract `0=clean / 1=policy violation / 2=misconfiguration`** des gate scripts s'applique à `tool/check_platform_manifests.dart` — adversarial Phase 06 attend exit 1 avec message identifiant la violation.
- **Pre-class §2 before agent spawn** — Phase 04 inaugural pattern, Phase 06 étend à 8 items (vs 3 Phase 04).
- **`'Aucune observation utilisateur'` valid §1 marker** (Phase 04 precedent) — si user n'a pas de findings IDE, commit le marker explicite au lieu du silence ou du placeholder.
- **Inertness-guarded permanent unit tests** (Phase 04 Test #3 precedent) — Phase 06 applique à tous les 5 unit tests adversariaux.
- **Batched fix-loop permissible** (Phase 04 Plan 04-05 precedent) — Phase 06 permettra si user approuve au moment de Plan 06-XX.
- **Severity-disagreement cross-lens preservation** (Phase 04 convention) — un finding surfaced par 2 agents avec severities différentes est préservé sous les 2 lens avec cross-reference, pas dedupliqué.

### Integration Points

- **`.planning/phases/06-review-gate-gps/06-REVIEW.md`** — artefact persistant produit par Phase 06, consulté par `gsd-verifier` pour vérifier la gate-closed condition (5 sections + POC evidence review §1b + 8 pre-class §2 + SC#4 OEM workaround plan table + adversarial CI evidence + 5 unit tests commit hashes + CI-green confirmation)
- **`.planning/STATE.md`** — mis à jour après chaque commit atomique (current_plan incrémenté, progress percent recalculé) ; nouvelle entrée Accumulated Decisions pour la structure adversariale Phase 06 et les 8 pre-class items
- **`.planning/ROADMAP.md`** — amendé : SC#1 Phase 06 `".planning/pocs/phase-05/"` → `"docs/qual-01-02-poc.md + docs/poc-artifacts/"` (Should fix in loop). Gate-closed status Phase 06 → `[x] completed 2026-04-XX` avec `Plans: N/N`.
- **`.planning/phases/05-gps-session-lifecycle/05-{01..06}-SUMMARY.md`** — lus pour identifier les déviations auto-documentées de Phase 05 qui méritent lecture de confirmation (pas ré-audit complet) : distanceFilter int typing, device_info_plus 12.4.0 pin, FlutterImplicitEngineDelegate stripped Xcode 26, POC PASS-with-caveat acceptance
- **GitHub Actions CI** (repository `GOSL-MirkFall`) — `adversarial/06-manifest-drift` branch y tourne, run ID devient l'evidence trail §4. `tool/check_platform_manifests.dart` ajouté au `gates` job.
- **`DEPENDENCIES.md`** — audit + entries pour `package:xml` + `package:plist` si choisies pour Test #4 + tool (sinon notation inline que pure-Dart regex a été choisi)
- **`tool/check_platform_manifests.dart`** — nouveau script Dart standalone, CI gates job, unit test `test/tooling/check_platform_manifests_test.dart` (couvre exit codes 0/1/2)
- **5 nouveaux test files** : `test/infrastructure/boot_watchdog/method_channel_sync_test.dart`, `test/application/permissions/location_permission_cascade_test.dart`, `test/infrastructure/platform/oem_detector_ambiguous_test.dart`, `test/tooling/platform_manifests_test.dart`, `test/infrastructure/boot_watchdog/android_boot_receiver_contract_test.dart` (et `test/tooling/check_platform_manifests_test.dart` pour le script CI gate)

</code_context>

<deferred>
## Deferred Ideas

- **Second iOS POC walk étendu à 30 min** — Phase 15 release-confidence optionnel selon user. 13.5 min PASS-with-caveat accepté Phase 06 avec rationale convergent same-day Android evidence.
- **"Tracking interrompu on next launch" banner** — Phase 15 SC#4 recovery flow (session active en DB au launch → bannière "reprendre ?"). Phase 06 ne touche pas.
- **Native per-OEM battery-settings intent deep-links** (MIUI Security, Huawei PhoneManager, Samsung DeviceCare, OnePlus Battery) — Phase 15 polish si release testing surface friction. dontkillmyapp.com link suffice V1.0.
- **Full dumpsys battery_stats instrumentation + Python parser** — Phase 15 release-confidence si user veut proof formel de SC#2. Phase 06 accepte fix cadence proxy.
- **Xiaomi / Samsung / Huawei / OnePlus device coverage testing** — Phase 15 release testing. Pixel 4a PASS + iPhone PASS-caveat suffice POC validation Phase 06.
- **iOS auto-resume-post-kill full validation** — Phase 15 quand FlutterImplicitEngineDelegate sera rewiré après stabilisation Apple scene-based API. BootCompletedWatchdog Android validé Phase 05.
- **Store rationale English copy finalisation** — Phase 15 polish. French copy defended-by-reviewer-quality suffice Phase 06.
- **Pre-commit hooks (lefthook ou autre)** — rejeté Phase 01, reste rejeté Phases 02 + 04 + 06. CI reste l'autorité unique.
- **Persistent adversarial matrix dans `ci.yml`** (matrix job ré-exécutant les 6 known-bad tests adversariaux à chaque push) — considéré, non retenu Phases 02 + 04 + 06. Si les garde-fous doivent être re-stressés à chaque phase de code, justifie une phase dédiée plus tard (peut-être Phase 16 release audit). En V1.0, 1 stress par review-gate suffit.
- **Audit exhaustif `pubspec.lock` paquet par paquet (180+ entries)** — remplacé par spot-check des deltas Phase 05 dans Agent #4. Ré-audit exhaustif = jours de travail pour signal minimal additionnel.
- **Automatisation du fix des Could / Noted** — pas dans Phase 06. Les Could peuvent être triagés `defer-to-phase-15-polish`, les Noted alimentent `deferred` de phases futures.
- **Rapport de stress-test comme artefact permanent séparé** (`docs/guardrail-stress-tests.md`) — non retenu Phases 02 + 04 + 06. Les evidences vivent dans les `XX-REVIEW.md` review-gate-par-review-gate, pas agrégé.
- **MPL-unreachable heuristic fix dans `tool/check_licenses.dart`** — Phase 02 backlog (4ème Blocker non couvert par adversarial Phase 02). Pas mélangé avec Phase 06. Reste à faire dans une hot-fix Phase 02 résiduelle ou en Phase 16.
- **Second iOS AppDelegate.swift path via FlutterImplicitEngineDelegate rewire** — Phase 15. Stripped Xcode 26 move, BootCompletedWatchdog iOS significant change cold-start path à valider là.
- **ProviderScope + GoRouter navigation test for OEM deep-link UX** — Phase 11 ou Phase 15 (nécessite real device ou Patrol/integration_test). Phase 06 audite uniquement widget tests + unit tests.
- **Remplacer `permission_handler` par implémentation native** — overkill V1.0. Pas réouvert Phase 06.
- **Profiling GPS battery sur fixture synthetic 30-min mock** — overkill V1.0. POC real-device suffit. Phase 15 si user veut.

</deferred>

---

*Phase: 06-review-gate-gps*
*Context gathered: 2026-04-20*
