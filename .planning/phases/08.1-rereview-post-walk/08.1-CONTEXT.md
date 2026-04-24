# Phase 08: Review Gate — Map - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Audit exhaustif de Phase 07 (Map Integration — 6 plans Code livrés + device-smoke Android Pixel 4a PASS + iOS iPhone 17 Pro PASS-with-fix-landed, Plan 07-07 integration-verification absorbé dans Phase 08) avant que Phase 09 Fog Rendering ne vienne peindre par-dessus la base vector+download. Un bug carte rattrapé ici coûte un sprint ; rattrapé en Phase 13 import/export il coûte la V1.0.

Phase 08 réutilise et étend les patterns Phases 02 (Review Gate Foundation) + 04 (Review Gate Persistence) + 06 (Review Gate GPS) : 5-section REVIEW.md, 4 sub-agents `general-purpose` parallèles single-tool-use-message, sévérité Blocker/Should/Could/Noted, user-first protocol strict, atomic commits CI-vert avant le suivant, pre-classification §2 avant spawn, inertness-guarded permanent unit tests, adversarial branches throwaway (CI authority, pas d'`act` local). Divergences Phase 08 : hybrid layer+risk sub-agent slicing (Phase 06 layer-strict surchargerait Agent #1 sur ~150+ fichiers map), absorption Plan 07-07 (4 integration tests deviennent adversarial wave Phase 08 au lieu d'un Plan 07-07 séparé), cross-cutting smell-heuristics brief (nouveau pattern CLAUDE.md §En review faire attention à — code alambiqué par empilement de fix + state machine tirée par les cheveux).

**Dans le scope Phase 08 :**
- Audit exhaustif fichier-par-fichier de tous les artefacts Phase 07 Code :
  - `lib/domain/map/` (MapView interface domain-level, CountryCode extension type, MapTheme sealed, CountryCatalog Freezed, MapErrors 7+4 exceptions, 5 fakes)
  - `lib/infrastructure/map/` (MaplibreMapView seul consumer maplibre_gl 0.25.0, PmtilesSource seam local-only, StyleRewriter + 2 validators, `style_layer_order` + regression test, CountryResolver + point_in_polygon, FirstLaunchWorldCopier MAP-07 idempotent + sha256 auto-heal, NoopMirkRenderer stub, DiskSpaceChecker + IosBackupExcluder platform channels)
  - `lib/infrastructure/downloads/` (Sha256Verifier streamed, BinaryConcatenator IOSink cleanup-on-failure, AtomicRenamer EXDEV cross-volume fallback, JsonFileInstalledManifestRepository tempfile+rename mutex+broadcast, DownloadQueueStore, HttpChunkDownloader Range/200/302, PmtilesDownloadController 7-step atomic protocol, CountryDeleteService world sentinel guard)
  - `lib/application/` map-related providers + 4 controllers (`map_providers.dart` DI graph ~10 providers, MapCameraController follow-me + manual-pan, CountryResolverController viewport debounced 500ms + hot-swap, DownloadQueueController UI wrapper + aggregate progress, InstalledMapsController updates-available derivation, FirstLaunchBootstrap pre-init in `main.dart`)
  - `lib/presentation/screens/` (MapScreen, MapsDownloadScreen, MapsManageScreen, `style_import_placeholder_screen.dart`, `style_export_placeholder_screen.dart`)
  - `lib/presentation/widgets/` (MapFollowMeFab, MapAttributionIcon, MapCountryBanner, MapDownloadProgressChip, SessionBurgerMenu drawer 75 %/40 % responsive)
  - `lib/application/routing/router.dart` deltas (5 new routes)
  - `.github/workflows/ci.yml` deltas Phase 07 (2 nouveaux lints live : `check_avoid_maplibre_leak` + `check_avoid_remote_pmtiles`)
  - `assets/maps/` (world.pmtiles low-zoom + catalog.json + style.json + glyphs + sprites + polygons)
  - `tool/generate_tiny_pmtiles.dart`, `tool/generate_world_sha256.dart`, `tool/prepare_style.dart`, `tool/simplify_polygons.dart`, `tool/check_avoid_maplibre_leak.dart`, `tool/check_avoid_remote_pmtiles.dart` + paired tests
  - Native bridges : Android INTERNET manifest + `DiskSpaceChecker` + `IosBackupExcluder` platform channels (Kotlin + Swift)
  - `DEPENDENCIES.md` deltas Phase 07 (maplibre_gl 0.25.0 BSD-3, crypto, shelf — confirm télémétrie zero, licence conforme, deps transitives rescanned)
  - Tests Phase 07 : ~85+ nouveaux test files + 6 soak scenarios @Tags(['soak']) Plan 07-04
- **Absorption Plan 07-07** : 4 integration tests écrits en adversarial wave Phase 08 (absent du Plan 07-07 original), ROADMAP + REQUIREMENTS amendés
- Pre-classification §2 des handoff items Phase 07 AVANT spawn des 4 sub-agents (voir §Implementation Decisions)
- §1b runtime evidence review via `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots — pas de fresh walk (précédent Phase 06, iOS fix déjà landed 2026-04-22 commits `81d30c7` + `ab497ab` + `40b49d5`)
- Adversarial wave : 4 integration tests absorbés + 3 permanent unit tests nouveaux + 1 CI gate script nouveau (`check_style_no_external_url.dart`) + 1 adversarial branch (`adversarial/08-style-external-url`)
- SC#3 soak acceptance : 6 scenarios Plan 07-04 acceptés + 2 edge cases additionnels (corrupt chunk mid-stream, rename target already exists)
- Application des fixes choisis, commits atomiques `fix(08-rev): <title>` / `refactor(08-rev):` / `docs(08-rev):` / `test(08-rev):` / `chore(08-rev):` selon nature, CI verte avant clearance, batched strategy permissible si user approuve (précédent Phase 04 Plan 04-05)
- Artefact persistant `08-REVIEW.md` (5 sections : User-observed / POC evidence review §1b / Claude audit §2 + pre-class / Triage §3 + smell tag / Adversarial §4 / CI-green §5)
- Amendements ROADMAP.md (Plan 07-07 scope-reduced + Phase 07 → 7/7 Complete) + REQUIREMENTS.md (MAP-05/06/07/08/10 → Complete)
- `07-07-SUMMARY.md` rédigé Phase 08 Plan 08-01 scaffold capturant scope-reduction + integration tests delta vers Phase 08

**Hors scope (autres phases) :**
- Toute ligne de code Fog, Markers, Import/Export, Mirk Styles — Phases 09+
- V1.x map enrichment (rivers-as-LineString visible + buildings + POIs catégorisés + labels street + relief) — phase dédiée à créer post-V1.0 (déféré water-as-Polygon filter Phase 07)
- Background downloads (Android Foreground Service + iOS URLSession.backgroundConfiguration) — V2 backlog
- iOS FlutterImplicitEngineDelegate rewire — Phase 15 polish (non lié map, GPS Phase 05 concern)
- Xiaomi / Samsung / Huawei / OnePlus OEM device coverage testing — Phase 15 release testing (même décision Phase 06)
- MPL-unreachable heuristic fix dans `tool/check_licenses.dart` — Phase 16 release audit (backlog Phase 02, même décision Phase 06)
- Second iOS POC walk étendu à 30 min (GPS Phase 05 concern) — Phase 15 release-confidence optionnel
- Physical re-smoke device Phase 08 — rejeté (smoke/fix iOS convergent 2026-04-21/22)
- Store rationale English copy finalisation — Phase 15 polish

</domain>

<decisions>
## Implementation Decisions

### Plan 07-07 absorption

- **Plan 07-07 scope reduced** : limité à smoke-walk + iOS animateCamera fix (déjà fait 2026-04-21/22). Les 4 integration tests originalement planifiés en Plan 07-07 (airplane_mode_test, first_launch_world_copy_test, map_end_to_end_test, phase_07_navigation_test) + la checkpoint:human-verify physical smoke sont absorbés par Phase 08 adversarial wave.
- **Fermeture Phase 07** : Phase 08 Plan 08-01 scaffold amend ROADMAP.md (Plan 07-07 → scope-reduced done + Phase 07 → 7/7 Complete) et crée `07-07-SUMMARY.md` capturant le scope-reduction rationale + cross-reference vers Plan 08-XX qui écrit les 4 tests. Aucun fichier orphelin : `07-07-integration-verification-PLAN.md` reste sur disque avec annotation "scope reduced — integration tests absorbed into Phase 08".
- **Integration tests location** : `integration_test/` directory (norme Flutter, actuellement inexistant). Job CI séparé `integration-tests` dans `.github/workflows/ci.yml`, opt-in via `@Tags(['integration'])` pour ne pas bloquer la CI unit fast-path. Run on-demand localement via `flutter test integration_test/`.
- **Wave structure** : les 4 integration tests deviennent permanent unit tests Phase 06-style avec inertness guards (pattern Phase 04 Test #3 + Phase 06 Tests #1-5 précédent). Écrits en adversarial wave dédiée Phase 08.

### Sub-agent slicing : hybrid layer + risk (4 agents general-purpose)

Divergence vs Phase 06 layer-strict : Phase 07 scope (~150+ fichiers + 2 platform channels + 6 assets + 4 tool files) surchargerait Agent #1 en layer-pur. Hybrid re-balance les concerns par risk proximity.

- **Agent #1 — Map infra + seam purity** :
  - `lib/domain/map/*` (MapView interface, CountryCode, MapTheme, CountryCatalog Freezed, MapErrors, 5 fakes)
  - `lib/infrastructure/map/*` (MaplibreMapView seul consumer maplibre_gl, PmtilesSource seam local-only, StyleRewriter + 2 validators, `style_layer_order` + regression test, CountryResolver + point_in_polygon, FirstLaunchWorldCopier MAP-07 idempotent + sha256 auto-heal, NoopMirkRenderer)
  - `tool/check_avoid_maplibre_leak.dart` + `tool/check_avoid_remote_pmtiles.dart` + paired tests — verrous lint live
  - `test/domain/map/**` + `test/infrastructure/map/**`
  - Vérifie : MapView interface ne fuit aucun type MapLibre, PmtilesSource URI local-only uniquement, `avoid_maplibre_leak` + `avoid_remote_pmtiles` bloquent effectivement, StyleRewriter reject correctement les URL externes, CountryResolver edge cases (frontier 2 pays / viewport pays-non-installé → fallback world / zoom world-only / polygon simplification lossy)
  - **Smell-heuristics lens prioritaire** : StyleRewriter + 2 validators (dispatcher duplication selon validator type)

- **Agent #2 — Download pipeline + atomicity** :
  - `lib/infrastructure/downloads/*` (Sha256Verifier streamed sha256.bind, BinaryConcatenator IOSink cleanup-on-failure, AtomicRenamer EXDEV cross-volume fallback, JsonFileInstalledManifestRepository tempfile+rename mutex+broadcast, DownloadQueueStore, HttpChunkDownloader Range/200/302, PmtilesDownloadController 7-step atomic protocol plain-Dart non-Riverpod, CountryDeleteService world sentinel guard)
  - `test/infrastructure/downloads/**` + 6 soak scenarios `@Tags(['soak'])` + shelf-backed FakeHttpServer (6 sealed behaviours)
  - Vérifie : 7-step atomic protocol absent-or-fully-installed invariant, sha256 per-chunk + global, staging cleanup, Range resume sur 206 + 200 restart fallback + 302 redirect, EXDEV cross-volume rename fallback, world sentinel protect
  - **Smell-heuristics lens prioritaire** : PmtilesDownloadController 7-step sealed states (enum candidat "state machine tirée par les cheveux" — états intermédiaires sync-only, dispatcher géant par step, transitions quasi-toutes-vers-toutes si échec)

- **Agent #3 — Controllers + providers + presentation** :
  - `lib/application/` map-related : `map_providers.dart` DI graph (~10 providers), MapCameraController, CountryResolverController, DownloadQueueController, InstalledMapsController, FirstLaunchBootstrap (pre-init dans `main.dart`)
  - `lib/presentation/screens/` (MapScreen, MapsDownloadScreen, MapsManageScreen, 2 placeholders style import/export)
  - `lib/presentation/widgets/` (SessionBurgerMenu drawer responsive, MapFollowMeFab, MapAttributionIcon, MapCountryBanner, MapDownloadProgressChip)
  - `lib/application/routing/router.dart` deltas (5 new routes)
  - `test/presentation/**` map-related + `test/application/controllers/**` map-related
  - Vérifie : router pop/go discipline, context.mounted post-await, AsyncValue.value Riverpod 3.x pattern, ProviderScope overrides inline, MapScreen accepte `mapViewBuilderForTest` typedef seam (Plan 07-06), aucune fuite maplibre_gl au-dessus de `lib/infrastructure/map/`, SessionBurgerMenu 3 unwired Phase 11/13 tiles + 3 live-data rows cohérents, UI download progress chip ne promet PAS "background download" (copy alignée avec background-deferred-V2)
  - **Smell-heuristics lens prioritaire** : MapCameraController follow/pan/iOS-animateCamera-post-fix (flags booléens accumulés : isFollowing / hasBeenInitialized / _pendingCamera, early returns post-fix iOS crash) + ActiveSessionController + ActiveSessionState Phase 05 legacy touché par 07-05 controllers wiring (sealed states qui auraient accumulé intermediate-sync-only)

- **Agent #4 — Natives + assets + CI gates + DEPENDENCIES.md + CLAUDE.md sweep + smell heuristics transverses** :
  - Platform channels : `DiskSpaceChecker` (Kotlin + Swift) + `IosBackupExcluder` (Swift)
  - Android `INTERNET` permission manifest delta
  - Assets : `assets/maps/world.pmtiles` + `catalog.json` + `style.json` + glyphs + sprites + polygons (intégrité + sha256 + licences amont + attribution OSM/Protomaps présente)
  - `tool/generate_tiny_pmtiles.dart`, `tool/generate_world_sha256.dart`, `tool/prepare_style.dart`, `tool/simplify_polygons.dart` (licences deps, output déterministe, documentation README, paired tests)
  - `DEPENDENCIES.md` deltas Phase 07 (maplibre_gl 0.25.0 BSD-3, crypto, shelf — confirm télémétrie zero, deps transitives rescanned)
  - CLAUDE.md anti-patterns sweep sur tout le code Phase 07 : magic numbers hors `lib/config/constants.dart`, naming conventions (`xxxFilename` vs `xxxFileName` vs `xxxBasename` vs `xxxDir`, `valueByKey` Maps, `xxxSet` Sets, `xxxs` Lists), DTOs sans sémantique distincte, wrappers de delegation, commentaires narrant le quoi, magic de path sans `p.join`, const constructors widgets
  - **Smell-heuristics transversal** : pass cross-cutting sur l'ensemble Phase 07 pour patterns CLAUDE.md qui auraient échappé aux agents #1-3 dans leur layer
  - Vérifie : triple-source-of-truth platform channels (Kotlin + Swift + Dart strings match), DEPENDENCIES.md entries Phase 07 complètes, assets ne contiennent PAS de payload réseau externe (style.json scrutiny manuelle en complément du nouveau `check_style_no_external_url` CI gate)

### Cross-cutting smell-heuristics from CLAUDE.md §En review faire attention à

Nouveaux patterns CLAUDE.md 2026-04-23 ajoutés au §Code Review Phases → §En review faire attention à :

1. **Code alambiqué par empilement de fix** — defensive null chains (`if x != null && x.ready && !x.cancelled && x.state != FOO`), flags booléens accumulés au fil de l'eau (`isInitialized`, `hasBeenProcessed`, `shouldSkip`), early returns multiples avec commentaires `// fix for edge case when…`, wrappers-de-wrappers (`doXReally()`, `handleXFinal()`), try/catch rattrapant des exceptions qu'un design correct aurait rendues impossibles
2. **State machine tirée par les cheveux** — enum d'états dont plusieurs valeurs ne diffèrent que par 1-2 champs, transitions pas-vraiment-un-graphe (tout le monde va partout), états "intermédiaires" qui n'existent que le temps d'un appel synchrone, dispatcher géant (switch/if-else) dupliquant la logique entre branches

**Anchoring Phase 08** (décision user "Cross-cutting brief + §2 pre-class category + §3 triage tag") :
- **Brief explicite** à chaque sub-agent : "en plus de ton layer, tu cherches fix-on-fix et over-state-machine. Quand tu détectes ces patterns, demande-toi si une fonction pure, un pattern strategy, ou juste des données mieux structurées feraient le même boulot. Propose l'alternative, quitte à ce que ça remette en cause l'architecture produite aux phases précédentes."
- **§2 pre-class category "Smell heuristics hot-spots"** avec 4 composants pré-listés (Agent #2 PmtilesDownloadController 7-step, Agent #3 MapCameraController follow/pan iOS-fix, Agent #1 StyleRewriter + 2 validators, Agent #3 ActiveSessionController + ActiveSessionState Phase 05 legacy touché 07-05) — les agents arrivent déjà briefés sur ces spots
- **§3 triage tag `smell`** pour flagger les findings de ce type — décision fix-vs-refactor-architectural visible dans triage (peut justifier un Blocker "refactor avant de shipper" ou rester Could "cleanup futur")

### Audit depth : exhaustif fichier-par-fichier

- Mêmes règles Phases 02 + 04 + 06 :
  - Chaque `.dart` sous `lib/` modifié ou créé Phase 07 audité ligne à ligne
  - Chaque `test/**` Phase 07 audité (assertions réelles vs placebo, `@Tags(['soak'])` / `@Tags(['integration'])` discipline, mock correctness via fakes au lieu de mockito)
  - Chaque `.kt` / `.swift` / `.plist` / `.xml` native audité
  - Chaque fixture committée vérifiée (JSON catalog parseable, style.json conforme, world.pmtiles sha256 match constant, polygons simplification lossless-enough)
  - Aucune exclusion silencieuse (`.g.dart` / `.freezed.dart` pas audités comme code humain mais leur génération validée par les tests)
- ~150+ fichiers `.dart` Phase 07 + ~85+ test files + 2 platform channels + 6 assets + 4 tool files + 2 existing CI lint tools + paired tests. **Charge supérieure à Phase 06** (qui avait ~90-120 Dart + ~50-70 tests + 3 natives + 2 POC docs + 1 Python tool).

### §2 pre-class items (10 items)

Pre-classification AVANT spawn agents, pour libérer les 4 agents de rediscover les connus et orienter leurs lens prioritaires.

1. **Water filter Polygon/MultiPolygon only** (rivers-as-LineString invisibles → V1.x enrichment phase) — **Noted**, user-decided 2026-04-21 post-device-smoke. Rationale inline : water encodé en LineString dans source-layer Protomaps n'est pas rendered ; enrichissement complet reporté à phase V1.x dédiée. Référence `07-06-SUMMARY.md §Post-ship amendments` + `07-CONTEXT.md §<deferred>`.
2. **Background downloads → V2 backlog** (Android FGS + iOS URLSession.background) — **Noted**, user-decided 2026-04-21 post-device-smoke. Rationale inline : download suspendu au screen-lock sur V1.0 (resume Range-based au foreground), vrai background download est V2 per PROJECT.md §V2 Backlog. Agent #3 vérifie que MapDownloadProgressChip + MapsDownloadScreen copy UX ne promettent pas "background continues".
3. **iOS animateCamera crash RÉSOLU** 2026-04-22 via commits `81d30c7` + `ab497ab` + `40b49d5` — **Noted**, avec référence au doc `docs/phase-07-ios-animate-camera-crash.md` (bisection inline + stack .ips + TL;DR RÉSOLU). Agent #3 vérifie que la fix tient et qu'aucun commentaire `// fix for edge case` n'est introduit en contre-partie.
4. **Plan 07-07 absorbed** → ROADMAP.md + REQUIREMENTS.md sync — **Should** (fix in loop, Phase 08 Plan 08-01 scaffold amend). ROADMAP : Plan 07-07 scope-reduced + Phase 07 → 7/7 Complete. REQUIREMENTS : MAP-05/06/07/08/10 status "In Progress (Plan 07-XX pending…)" → "Complete".
5. **pmtiles-heal path in FirstLaunchBootstrap** (mid-rename kill recovery invariant shipped Plan 07-04) — **Noted** reference. Agent #1 + Agent #2 vérifient que le heal path est cohérent avec l'atomic rename invariant + que la soak scenario #6 (mid-rename kill heal) en est la couverture test.
6. **Smell heuristics hot-spots** (4 composants) — **category inline §2, pas un finding unique**. Voir §Cross-cutting smell-heuristics ci-dessus.
7. **ROADMAP/REQUIREMENTS sync obligatoire** — dupliqué avec item #4 mais explicité comme **Should** fix-loop. Agent #4 lens flag + fix en §5 closure.
8. **`tool/simplify_polygons.dart` + `tool/generate_tiny_pmtiles.dart` audit** — **Could/Noted** selon finding. Agent #4 lens : licences deps (argparse / geometry libs Python si applicable, mais probablement tout pure-Dart), output déterministe (reproducible rebuild du world bundle), tests.
9. **CountryResolver edge cases (SC#2)** — **Should si findings, sinon Noted**. Agent #1 lens : frontier entre 2 pays installés, viewport au-delà d'un pays installé → fallback world bundle transparent, zoom world-only sans country match, polygon simplification lossy (`simplify_polygons.dart` output).
10. **DEPENDENCIES.md audit deltas Phase 07** (maplibre_gl 0.25.0 BSD-3, crypto, shelf) — **Noted** reference. Agent #4 re-scan : licence amont confirm, télémétrie zero confirm, deps transitives rescanned pour GPL/AGPL contamination, version pinning strict match `pubspec.yaml`.

### POC / runtime evidence review §1b — no fresh walk

**Précédent Phase 06** : pas de fresh runtime walk, extraction des artifacts committed.

- Agent #4 (natives + CLAUDE.md sweep + tooling lens) lit :
  - `docs/phase-07-smoke.md` (Android Pixel 4a PASS + iOS PASS-with-caveat / fix-landed)
  - `docs/phase-07-ios-animate-camera-crash.md` (investigation + bisection + TL;DR RÉSOLU + stack .ips inline)
  - 7 screenshots : `android-01-map-screen.png`, `android-02-airplane-mode.png`, `android-03-download-progress.png`, `android-04-manage-installed.png`, `android-05-post-delete.png`, `ios-01-map-screen.png`, `ios-02-download-complete.png`
- **Format §1b** (précédent Phase 06) : per-device collapsed `<details>` sections.
  - `<details><summary>Android Pixel 4a — PASS 2026-04-21</summary>` : 5 screenshots inline + cadence/observations table + airplane mode evidence `</details>`
  - `<details><summary>iOS iPhone 17 Pro — PASS post-fix 2026-04-22</summary>` : 2 screenshots inline + rappel commits fix (`81d30c7` + `ab497ab` + `40b49d5`) + stack .ips extrait + bisection probes table `</details>`
- Rationale : smoke du 2026-04-21 + fix iOS 2026-04-22 sont convergents. Re-smoke coûterait ~2-3h sans signal additionnel. Si user change d'avis post-audit, re-smoke est un fix-loop task isolé.

### Adversarial wave design

**Structure Phase 08** : 1 CI gate script nouveau (avec adversarial branch) + 3 permanent unit tests nouveaux (inertness-guarded, pas de branche) + 4 integration tests absorbés de Plan 07-07 (inertness-guarded, pas de branche).

Le ratio **1 adversarial branch per CI-gate-script** est locked (Phase 06 précédent : 1 branche pour `check_platform_manifests`).

#### 4 integration tests absorbés (Plan 07-07 → Phase 08)

Tous dans `integration_test/` (nouveau directory), `@Tags(['integration'])`, job CI `integration-tests` on-demand, Full Phase 06 inertness pattern.

1. **`integration_test/airplane_mode_test.dart`** (MAP-01 + QUAL-05 subset) :
   - Invariant : pan / zoom / changement de pays affiché en mode airplane (NetworkImage throws, HttpClient redirect-to-throw) = trafic réseau zero pour les tuiles. Seules les requêtes download explicitement user-déclenchées sont autorisées (le catalog est asset-bundled, pas fetché).
   - Mécanisme : override `HttpOverrides` avec un `HttpClient` qui throw `SocketException` sur tout. Pump MapScreen avec FakeMapView + PmtilesSource hitting local file. Pan+zoom+country-swap. Assert 0 `HttpClient.getUrl` invocations vers un hôte remote.
   - Inertness : pre-assert que FakeMapView a reçu `showMap()` + que PmtilesSource a émis des URI `pmtiles:///` — sans ça, le test passerait green sur un setup inerte.

2. **`integration_test/first_launch_world_copy_test.dart`** (MAP-07 auto-heal) :
   - Invariant : premier lancement → `assets/maps/world.pmtiles` copié vers `<app_support>/maps/world.pmtiles`, sha256 vérifié contre `kWorldBundleSha256`. Si sha mismatch (file corrupt) → auto-heal recopie depuis bundle.
   - Scenario A : fresh app, assert copy happens + sha matches constant.
   - Scenario B : corrupt destination file pré-existant, assert auto-heal recopie + sha matches.
   - Scenario C : idempotent re-run, assert no-op si sha matches.
   - Inertness : pre-assert que `FirstLaunchBootstrap` a été `init()` + que le FileSystem fake a reçu des writes.

3. **`integration_test/map_end_to_end_test.dart`** (MockHTTP + full user journey) :
   - Invariant : user journey complet — launch app (world copied) → /map (world map affiché) → /maps-download (catalog lu, liste pays) → download pays X (7-step atomic, shelf FakeHttpServer) → carte affichée avec country X → /maps-manage → delete country X → world fallback.
   - Mécanisme : shelf-backed FakeHttpServer (ré-utilisable de Plan 07-04 tests) sert les chunks. Real FileSystem (tmp dir), real AppDatabase (in-memory). FakeMapView renvoie les callbacks onStyleLoaded.
   - Inertness : pre-assert à chaque étape qu'au moins 1 event clé a été émis (download queued, chunk fetched, concat done, rename done, country listed, country deleted).

4. **`integration_test/phase_07_navigation_test.dart`** (router + 5 new screens) :
   - Invariant : router 5 new routes (/map, /maps-download, /maps-manage, /style-import, /style-export) résolvent vers leur screen attendu, back-navigation cohérente (context.canPop() ? pop : go('/')), deep-links pas-crash.
   - Scenarios : navigate forward/back sur chaque route + deep-link direct + back depuis une route profonde.
   - Inertness : pre-assert que GoRouter a reçu des `push/go` events + que les screens ont émis un `build()`.

#### 3 permanent unit tests nouveaux (inertness-guarded, pas de branche)

1. **`test/infrastructure/assets/world_bundle_sha256_test.dart`** (world-bundle-sha256 regression) :
   - Invariant : sha256 de `assets/maps/world.pmtiles` = constant `kWorldBundleSha256`. Si l'asset change sans update du constant → FirstLaunchWorldCopier auto-heal boucle. Silent drift impossible.
   - Test : lit `assets/maps/world.pmtiles` via `rootBundle.load()` (ou File path directement côté test runner), recompute sha256 streamed, `expect(actual, equals(kWorldBundleSha256))`.
   - Inertness : pre-assert que le fichier existe + taille > 0 (refactor qui rename l'asset sans update path serait silent-green).

2. **`test/infrastructure/downloads/manifest_atomicity_contract_test.dart`** (JsonFileInstalledManifestRepository contract) :
   - Invariant : `JsonFileInstalledManifestRepository.write()` est atomique : kill-mid-write laisse le fichier soit intact (pre-write state) soit complet (tempfile+rename done). Jamais partial.
   - Mécanisme : injection d'un FS fake qui throw à différents points (before tempfile, during tempfile write, after tempfile write, during rename). Assert qu'après chaque throw : le fichier cible est soit inchangé soit totalement updated. Complémente les 6 soak scenarios Plan 07-04 avec un focus narrow sur le contract repository.
   - Inertness : pre-assert que le fake FS a reçu au moins 1 write avant le throw.

3. **`test/infrastructure/network/no_httpclient_in_unit_tests_test.dart`** (scanning regression) :
   - Invariant : aucun fichier sous `test/` (hors `test/integration/` et les tests qui ont explicitement `@Tags(['integration'])`) n'instancie directement un `HttpClient()` / `http.Client()` / `Dio()` sans fake injection. Détection statique silent-real-network.
   - Mécanisme : pure-Dart scan du répertoire `test/`, grep patterns `HttpClient()`, `http.Client()`, `Dio()` (adjusted pour exclure imports de fakes). Complémente l'airplane_mode_test runtime-level.
   - Inertness : pre-assert que le scan a visité ≥ N fichiers (sinon le scan serait silent-green sur un refactor de path).

#### 1 CI gate script nouveau

**`tool/check_style_no_external_url.dart`** :
- Même contract que `check_domain_purity` / `check_licenses` / `check_headers` / `check_avoid_maplibre_leak` / `check_avoid_remote_pmtiles` : exit 0 (clean) / 1 (policy violation) / 2 (misconfiguration).
- Parse `assets/maps/style.json` (JSON pure-Dart `jsonDecode`, pas de `package:yaml` requis — style.json EST JSON), walk toutes les URLs (sources, glyphs, sprite, tiles), reject toute URL qui ne matche pas `pmtiles:///` / local file / asset bundle path.
- Print violations à stderr avec file path + JSON path (ex : `sources.openmaptiles.url`) + offending URL.
- Ajouté au `.github/workflows/ci.yml` `gates` job alongside existing gates.
- Paired unit test `test/tooling/check_style_no_external_url_test.dart` (exit codes 0/1/2, 4+ fixtures dont la style.json production actuelle).

#### 1 adversarial branch

**`adversarial/08-style-external-url`** :
- Poison commit : inject `"url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"` dans `assets/maps/style.json`.
- Push → CI step `dart run tool/check_style_no_external_url.dart` doit fail exit 1 avec stderr identifiant le file path + JSON path + offending URL.
- Evidence §4 : branch name, commit hash, run URL, exit code, stderr extrait.
- Cleanup : branche supprimée local + remote post-archivage.
- Pas de PR (évite notifications, historique main propre).
- CI trigger expansion pattern Phase 02 : `on.push.branches += 'adversarial/**'` inline sur la branche.

#### 2 edge cases soak additionnels (SC#3)

Acceptance des 6 scenarios Plan 07-04 `@Tags(['soak'])` (happy / multi-part / 206 resume / 200 restart / disk insufficient / mid-rename kill heal) comme coverage baseline. **Add 2 nouveaux scenarios** en Phase 08 wave :

1. **Corrupt chunk mid-stream** : download un pays en 5 chunks, le chunk #3 retourne un payload avec sha256 mismatch vs catalog. Assert : staging nettoyé, download reportable (state = failed-with-retry), `.pmtiles` cible absent.
2. **Rename target already exists** : simuler retry d'un download sur un pays déjà partial-installed (le `.pmtiles` cible existe déjà suite à un crash pré-rename). Assert : AtomicRenamer gère correctement (overwrite ou reject per specified contract), pas de fuite manifest.

Agent #2 lens vérifie l'ajout + que les 8 scenarios tournent green en CI `soak` job.

### Ordering : strict user-first protocol (locked Phases 02+04+06)

- **User poste ses findings IDE en chat AVANT** que Claude spawn quoi que ce soit
- Claude capture verbatim dans `08-REVIEW.md §1` (ou `'Aucune observation utilisateur'` marker si user n'en a aucune — précédent Phase 04/06)
- **ENSUITE §1b runtime evidence review** via Agent #4 (pas fresh walk — extraction artifacts `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots, per-device collapsed `<details>` sections)
- **ENSUITE pre-class §2** des 10 items handoff Phase 07
- **ENSUITE spawn 4 sub-agents** en single tool-use message (multi Agent tool calls parallèles)
- Si user flag un point, un agent peut être briefé explicitement à le creuser (re-scope dynamique)
- Parallèle (user tape pendant que agents tournent) explicitement rejeté — précédent Phases 02+04+06

### Output contract des sub-agents : same as Phases 02+04+06

- **Structured findings** (l'essentiel, alimente la présentation user) :
  ```
  [severity] Title — 1-line explanation — file:line
  ```
  Sévérités : `Blocker` / `Should` / `Could` / `Noted` (définitions inchangées Phase 02).
- **Narrative appendix** : prose audit report archivé dans `08-REVIEW.md §Audit Notes Agent #N` (pas montré à l'user dans la présentation initiale, consultable si question).
- **Synthesis single + per-agent appendix** (précédent Phase 04/06) : 4 listes fusionnées en §2 Claude audit pour triage user §3, appendix per-agent en fin de document pour trace d'audit.
- **Cross-lens overlap preservation** (précédent Phase 02) : un finding surfaced par 2 agents avec severities différentes est préservé sous les 2 lens avec cross-reference, pas dedupliqué.
- **§3 triage tag `smell`** pour findings fix-on-fix ou over-state-machine — visibilité explicite de la décision fix-vs-refactor architectural.
- `gsd-verifier` grep `^## [1-5]\.` pour confirmer les 5 sections présentes (locked Phase 02+04+06).

### Agent type & count : all 4 general-purpose (locked Phase 02+04+06)

- 4 agents `general-purpose` en single tool-use message (parallel)
- **Agent #5 dédié smell-lens REJETÉ** — pattern cross-cutting brief + §2 pre-class category + §3 triage tag suffit. Maintient la règle locked "4 agents all general-purpose" + évite duplication de findings avec layer-agents.

### Fix workflow + gate-closed criteria : pattern Phases 02+04+06

- Commits atomiques `fix(08-rev): <title>` / `refactor(08-rev):` / `docs(08-rev):` / `test(08-rev):` / `chore(08-rev):` selon nature, un par finding
- **Batched strategy permissible** si user approuve explicitement au moment de Plan 08-XX (précédent Phase 04 Plan 04-05 : 10 batches × ~10 min CI gate au lieu de 31 atomic per-finding)
- Chaque commit (ou batch) passe la CI avant le suivant — feedback rapide + bisectable + revertable finding-par-finding
- **Gate-closed** :
  - Tous findings `Blocker` fixés (pas de waiver possible)
  - Tous findings `Should` soit fixés soit explicitement waiver avec rationale inline dans REVIEW.md §3
  - Findings `smell`-tagged triage explicite (fix / refactor / defer) documenté
  - CI verte sur le commit final `main`
  - `08-REVIEW.md` 5 sections remplies, §1b evidence review avec extracts inline, §2 10 pre-class items avec severity + rationale + smell-heuristics hot-spots table, §4 evidence block adversarial branch CI + 4 integration tests + 3 permanent unit tests commit hashes, §5 CI-green confirmation
  - `tool/check_style_no_external_url.dart` ajouté au CI gates job, confirmé green sur le commit final
  - ROADMAP.md amendé (Plan 07-07 scope-reduced + Phase 07 → 7/7 Complete + Phase 08 → completed 2026-04-XX)
  - REQUIREMENTS.md amendé (MAP-05/06/07/08/10 → Complete)
  - `07-07-SUMMARY.md` créé capturant scope-reduction rationale
  - `gsd-verifier` vérifie ces conditions pour marquer Phase 08 complete et débloquer Phase 09

### Claude's Discretion

- Wave layout exact des plans Phase 08 (combien de plans, scaffold / evidence-review / pre-class / agents / adversarial / fixes — arbitrer en planning, mais §1b evidence + §2 pre-class DOIVENT être AVANT agents, idem sequencing Phase 06)
- Format exact markdown §1b (structure interne des `<details>` sections, tables cadence, inline vs file-linked screenshots selon rendering md)
- Ordering d'écriture des 4 integration tests + 3 permanent unit tests (parallèle vs séquentiel, single commit vs per-test commit)
- Choix exact du mécanisme parsing pour `check_style_no_external_url.dart` (pure-Dart `jsonDecode` vs `package:yaml` si style.json devient YAML plus tard — currently JSON, `jsonDecode` sufficient ; audit DEPENDENCIES.md si nouvelle dep)
- Stratégie de cleanup de la branche `adversarial/08-style-external-url` (delete immédiat post-archivage vs delete batch en fin de Plan 08-XX)
- Format exact des 4 integration test file names + 3 permanent unit test file names (convention test naming selon layer directory)
- Découpage interne Agent #4 (assets + tooling + natives + DEPENDENCIES.md + CLAUDE.md sweep + smell-heuristics transverses peut être un pass combiné ou divisé selon ce que l'agent estime tractable — priorité aux findings, pas au découpage)
- Re-scope d'un agent si user IDE findings flaggent un angle spécifique (ex : user flag un bug MapCameraController post-iOS-fix → Agent #3 briefé explicitement à creuser cet angle en priorité)
- Choix exact des 2 edge cases soak additionnels (définitions précises des scenarios "corrupt chunk mid-stream" + "rename target already exists" — chunk index exact, timing de la failure, expected post-state — arbitrer en Plan 08-XX)
- Format du commit subject line des 3 permanent unit tests + 4 integration tests (`test(08-rev): add regression guard for X` vs `feat(08-rev): add integration test Y` selon convention)
- Severity exacte de chaque pre-class item au moment du planning (confirmation des propositions : Water filter Noted / Background V2 Noted / iOS fix Noted / ROADMAP+REQ sync Should / pmtiles-heal Noted / smell category non-finding / tool simplify/generate Could-or-Noted / CountryResolver edges Should-if-findings-else-Noted / DEPENDENCIES Noted)

</decisions>

<specifics>
## Specific Ideas

- **CI est l'autorité pour l'adversarial Phase 08** — pas d'`act` local, pas de simulation. On pousse réellement `adversarial/08-style-external-url`, on observe la vraie CI, on archive le vrai run ID. Même précédent Phases 02+04+06 : si on ne fait pas confiance à la CI pour les tests adversariaux, on ne peut pas lui faire confiance pour la production.
- **Physical smoke déjà fait + iOS fix déjà landed** — Phase 08 lit les artifacts `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots comme evidence `§1b`, pas de re-smoke même post-fix. Rationale user : smoke du 2026-04-21 + fix iOS 2026-04-22 sont convergents, re-smoke coûterait ~2-3h sans signal additionnel. Si user change d'avis post-audit, re-smoke est un fix-loop task isolé.
- **Plan 07-07 absorption est structural** — Phase 07 fermée formellement via ROADMAP amend + `07-07-SUMMARY.md` écrit en Phase 08 Plan 08-01 scaffold, pas en deferred. La trace cross-phase est explicite (Plan 07-07 scope reduced, 4 integration tests written in Phase 08 Plan 08-XX adversarial wave). Le fichier `07-07-integration-verification-PLAN.md` reste sur disque avec annotation "scope reduced — integration tests absorbed into Phase 08 Plan 08-XX".
- **Smell-heuristics hot-spots pré-listés orientent le scope agent** — PmtilesDownloadController 7-step → Agent #2 ; MapCameraController follow/pan iOS-fix → Agent #3 ; StyleRewriter + 2 validators → Agent #1 ; ActiveSessionController + ActiveSessionState Phase 05 legacy touché par 07-05 → Agent #3. Chaque agent reçoit le spot dans son brief prioritaire + le cross-cutting brief générique ("en plus, tu cherches ces patterns dans tout ton scope").
- **Pre-class §2 catégorise aussi ROADMAP/REQUIREMENTS sync** comme Should fix-in-loop — MAP-05/06/07/08/10 status obsolète à corriger avant Phase 08 close, sinon trace Phase 07 reste perpétuellement "In Progress" même quand le Phase 08 gate est fermé. Amendement explicite en `fix(08-rev): amend ROADMAP + REQUIREMENTS to reflect Phase 07 complete`.
- **3 permanent unit tests ajoutés vs 5 Phase 06** — Phase 06 avait 5 (MethodChannel sync / permission cascade / OEM ambiguous / platform manifests / Android boot receiver contract). Phase 08 en ajoute 3 (world-bundle-sha256 / manifest-atomicity / No-HttpClient-in-unit-tests) + 4 integration tests absorbés du Plan 07-07. Total **7 nouveaux tests Phase 08**.
- **1 CI gate nouveau + 1 adversarial branch** — Phase 06 avait 1 gate (`check_platform_manifests`) + 1 branche. Phase 08 même ratio : 1 gate (`check_style_no_external_url`) + 1 branche. Proportion locked : 1 adversarial branch per CI-gate-script. Les permanent unit tests ont inertness guards, pas de branche.
- **Solo-dev review protocol user-first est le point d'ordre** — user IDE finds + §1b evidence review + Claude 4-agent audit sont les trois seuls moteurs de review. Le protocole `user first → §1b evidence → pre-class §2 → 4 agents` est intangible même si Phase 07 a été exceptionnellement gros (~150+ fichiers).
- **SC#4 OEM workaround plan table exigé Phase 06 ne s'applique PAS Phase 08** — rien d'OEM-spécifique dans Phase 07 map. La table OEM est Phase 06-only.
- **CLAUDE.md §En review faire attention à est un delta 2026-04-23** — 2 nouveaux patterns (code alambiqué par empilement de fix + state machine tirée par les cheveux) ajoutés au §Code Review Phases. Phase 08 est la **première** review gate où ces patterns sont encodés au processus. Précédent pour Phases 10 / 12 / 14 / 16 : même pattern brief + §2 + §3 tag.
- **Inertness guard applied uniformly** — Phase 04 Test #3 mutation experiment a prouvé la valeur. Phase 08 applique aux 7 nouveaux tests (4 integration + 3 permanent unit). Coût : 1-2 lignes par test, bénéfice : protection permanente contre refactor silent-neutralize.
- **Phase 08 est la review-gate intermédiaire avant le sprint critique UX** (Phases 09 fog + 11 markers + 13 import/export/options). Un bug carte qui passe ici peut contaminer toutes les phases visuelles suivantes. Discipline d'audit exhaustive non-négociable malgré Phase 07 "seulement" map.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 02 + 04 + 06 + 07)

- **Pattern Phase 06 review-gate complet** (`06-CONTEXT.md`, `06-REVIEW.md`, Plans 06-01..06-05) — template directement réutilisable avec les divergences Phase 08 documentées ci-dessus (hybrid layer+risk slicing au lieu de layer-strict, 4 integration tests absorbés Plan 07-07, 1 CI gate + 1 adversarial branch, cross-cutting smell-heuristics brief + §2 category + §3 tag, 10 pre-class items vs 8 Phase 06).
- **`tool/check_domain_purity.dart` + `check_licenses.dart` + `check_headers.dart` + `check_dependencies_md.dart` + `check_platform_manifests.dart` + `check_avoid_maplibre_leak.dart` + `check_avoid_remote_pmtiles.dart`** — pattern pour `tool/check_style_no_external_url.dart` (exit 0/1/2 contract, CI gates job integration, paired unit test `test/tooling/`).
- **`tool/check_platform_manifests.dart` Phase 06 precedent** — pattern parsing XML/JSON + regex violations + stderr identification du file + offending entry + exit 1.
- **Existing lints live `avoid_maplibre_leak` + `avoid_remote_pmtiles`** — forment la base de la protection seam purity Phase 07. Agent #1 vérifie qu'ils bloquent effectivement (paired tests archived + CI run history).
- **`FakeMapView`** (Plan 07-02 domain-interfaces) + **`FakeCountryCatalog`** + **`FakeCountryResolver`** + **shelf-backed `FakeHttpServer`** (Plan 07-04 download-pipeline, 6 sealed behaviours) — réutilisables par les 4 integration tests absorbés Phase 08 + par le `manifest_atomicity_contract_test`.
- **`MapScreen` `mapViewBuilderForTest` typedef seam** (Plan 07-06) — permet aux widget tests d'injecter `FakeMapView` sans dragger MapLibre dans le test runner. Utilisé par `phase_07_navigation_test.dart`.
- **`tool/generate_world_sha256.dart`** (Plan 07-01) — source du constant `kWorldBundleSha256`. Le nouveau `world_bundle_sha256_test.dart` recompute via `crypto sha256.bind` + compare à ce constant.
- **`FirstLaunchBootstrap` pmtiles-heal path** (Plan 07-04, mid-rename kill recovery) — source du MAP-07 auto-heal invariant validé par le nouveau `first_launch_world_copy_test.dart` (scenarios A/B/C).
- **`PmtilesDownloadController` 7-step atomic protocol** (Plan 07-04) — cible prioritaire smell-heuristics Agent #2 lens + base du `manifest_atomicity_contract_test.dart`.
- **6 soak scenarios Plan 07-04** (`@Tags(['soak'])` : happy / multi-part / 206 resume / 200 restart / disk insufficient / mid-rename kill heal) — base de coverage Phase 08 accepte + étend avec 2 edge cases (corrupt chunk mid-stream + rename target already exists).
- **`docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots** (`docs/phase-07-smoke-screenshots/android-{01..05}*.png` + `ios-{01,02}*.png`) — evidence primaire §1b, lus par Agent #4.
- **`02-REVIEW.md` + `04-REVIEW.md` + `06-REVIEW.md`** — exemplars concrets du format final attendu pour `08-REVIEW.md`. Réutilisation du template 5 sections + sous-section narrative Audit Notes.
- **GitHub Actions CI (`.github/workflows/ci.yml`)** — `gates` job déjà inclut Phases 01-07 : `check_headers` / `check_licenses` / `check_dependencies_md` / `check_domain_purity` / drift-schema guard / `check_platform_manifests` / `check_avoid_maplibre_leak` / `check_avoid_remote_pmtiles` / `dart format --set-exit-if-changed` / `flutter analyze --fatal-infos --fatal-warnings` / `dart test test/domain/ test/infrastructure/`. Phase 08 ajoute : `check_style_no_external_url` dans `gates` + éventuellement job separate `integration-tests` pour les 4 tests absorbés.
- **`.github/workflows/ci.yml on.push.branches += 'adversarial/**'`** (précédent Phases 02+04+06) — pattern trigger expansion inline sur chaque throwaway branche pour que la CI tourne sur `adversarial/08-style-external-url` sans modifier main trigger.
- **DiskSpaceChecker + IosBackupExcluder platform channels** (Plan 07-03) — cibles potentielles d'un futur MethodChannel sync test pattern Phase 06 si Agent #4 trouve un drift risk. Pas de nouveau test exigé Phase 08 par défaut.
- **Phase 04 Test #3 inertness-guard pattern** (mutation experiment proven) — repliqué sur les 7 nouveaux tests Phase 08.

### Established Patterns (from Phases 02 + 04 + 06)

- **5-section REVIEW.md artifact contract** locked Phases 02+04+06. `gsd-verifier` greps `^## [1-5]\.` to confirm 5 headings. Reusable across all even-numbered phases including Phase 08.
- **4-parallel-sub-agent audit wave template** validated Phases 02+04+06. Single tool-use message spawning 4 concern-sliced `general-purpose` agents. Phase 08 reuse + adapt slicing hybrid layer+risk.
- **All 4 audit agents `general-purpose`** for wave consistency — Phase 08 garde la règle. Agent #5 dédié smell-lens rejeté.
- **User-first ordering strict** locked Phases 02+04+06. Phase 08 : user IDE → §1b evidence review → §2 pre-class → 4 agents.
- **Severity tiers Blocker / Should / Could / Noted** définitions conservées.
- **Atomic commits `fix(02-rev): <title>` / `fix(04-rev)` / `fix(06-rev)`** → Phase 08 utilise `fix(08-rev): <title>` (et variants refactor/docs/test/chore selon nature).
- **Adversarial branches throwaway `adversarial/02-*` / `adversarial/04-*` / `adversarial/06-*`** deleted local+remote post-archivage → Phase 08 utilise `adversarial/08-style-external-url` même discipline.
- **CI exit code contract `0=clean / 1=policy violation / 2=misconfiguration`** des gate scripts s'applique à `tool/check_style_no_external_url.dart` — adversarial Phase 08 attend exit 1 avec message identifiant file path + JSON path + offending URL.
- **Pre-class §2 before agent spawn** — Phase 04 inaugural pattern, Phase 06 étendu à 8 items, Phase 08 étend à 10.
- **`'Aucune observation utilisateur'` valid §1 marker** (Phase 04 + 06 precedent) — si user n'a pas de findings IDE, commit le marker explicite au lieu du silence.
- **Inertness-guarded permanent unit tests** (Phase 04 Test #3 + Phase 06 Tests #1-5 precedent) — Phase 08 applique aux 7 nouveaux tests (4 integration + 3 permanent unit).
- **Batched fix-loop permissible** (Phase 04 Plan 04-05 precedent) — Phase 08 permettra si user approuve au moment de Plan 08-XX.
- **Severity-disagreement cross-lens preservation** (Phase 02+06 convention) — finding surfaced par 2 agents avec severities différentes préservé sous les 2 lens avec cross-reference, pas dedupliqué.
- **POC/evidence review §1b au lieu de fresh walk** (Phase 06 precedent) — Phase 08 : extraction `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots. Per-device collapsed `<details>` sections format.

### Integration Points

- **`.planning/phases/08-review-gate-map/08-REVIEW.md`** — artefact persistant produit par Phase 08, consulté par `gsd-verifier` pour vérifier la gate-closed condition (5 sections + §1b evidence review per-device + 10 pre-class §2 items + smell-heuristics hot-spots table + adversarial CI evidence + 7 test commit hashes + CI-green confirmation)
- **`.planning/STATE.md`** — mis à jour après chaque commit atomique (current_plan incrémenté, progress percent recalculé) ; nouvelle entrée Accumulated Decisions pour Plan 07-07 absorption + smell-heuristics processing + 4 integration tests absorbés + 3 new permanent unit tests
- **`.planning/ROADMAP.md`** — amendé : Plan 07-07 `07-map-integration/07-07-integration-verification-PLAN.md` → `scope reduced (smoke + iOS fix only), integration tests absorbed into Phase 08 Plan 08-XX`. Progress table : Phase 07 → 7/7 Complete, Phase 08 → completed 2026-04-XX avec Plans: N/N. Success Criteria Phase 08 consolidated with post-ship inventory.
- **`.planning/REQUIREMENTS.md`** — amendé : MAP-05 / MAP-06 / MAP-07 / MAP-08 / MAP-10 Traceability row status "In Progress (Plan 07-XX pending)" → "Complete". Coverage footer reflète complétion.
- **`.planning/phases/07-map-integration/07-07-SUMMARY.md`** — nouveau fichier créé Phase 08 Plan 08-01 scaffold, capture scope-reduction rationale + liste des 4 integration tests delta vers Phase 08 avec cross-reference file path.
- **GitHub Actions CI** (repository `GOSL-MirkFall`) — `adversarial/08-style-external-url` branch y tourne, run ID = evidence trail §4. `tool/check_style_no_external_url.dart` ajouté au `gates` job. Éventuellement nouveau job `integration-tests` ou stage dans job existant pour les 4 tests `@Tags(['integration'])` run on-demand.
- **`DEPENDENCIES.md`** — audit + confirmation pour `maplibre_gl 0.25.0` + `crypto` + `shelf` deltas Phase 07 (déjà entries, re-scan Phase 08 pour télémétrie-zero confirm + deps transitives rescan) + éventuellement nouvelles entries si `package:xml`/`package:yaml` requis pour Tests (pure-Dart `jsonDecode` + regex suffit probablement = no new dep).
- **`tool/check_style_no_external_url.dart`** — nouveau script Dart standalone, CI gates job, paired unit test `test/tooling/check_style_no_external_url_test.dart` (exit codes 0/1/2, 4+ fixtures dont la style.json production actuelle).
- **`integration_test/` directory** (NOUVEAU) — 4 fichiers Phase 08 absorbés du Plan 07-07 : `airplane_mode_test.dart`, `first_launch_world_copy_test.dart`, `map_end_to_end_test.dart`, `phase_07_navigation_test.dart`. Tous `@Tags(['integration'])`, CI job dédié on-demand.
- **3 nouveaux permanent unit test files** : `test/infrastructure/assets/world_bundle_sha256_test.dart`, `test/infrastructure/downloads/manifest_atomicity_contract_test.dart`, `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart`.
- **2 nouveaux soak scenarios** : à ajouter dans le fichier soak existant Plan 07-04 (`test/infrastructure/downloads/pmtiles_download_soak_test.dart` ou équivalent) — `@Tags(['soak'])` discipline maintenue.
- **`07-07-integration-verification-PLAN.md`** — annoté "scope reduced — integration tests absorbed into Phase 08 Plan 08-XX" dans l'en-tête du fichier (pas supprimé, pas renommé, pour préserver la trace git).

</code_context>

<deferred>
## Deferred Ideas

- **V1.x map enrichment phase dédiée** (rivers-as-LineString visible + buildings + POIs catégorisés + labels street + relief) — post-V1.0, conséquence directe du water filter Polygon-only shipped Phase 07 post-device-smoke 2026-04-21. À créer en roadmap V1.x.
- **Background downloads V2 backlog** (Android Foreground Service avec notification persistante + iOS `URLSession.backgroundConfiguration`) — PROJECT.md §V2 Backlog + `07-CONTEXT.md <deferred>` + `07-06-SUMMARY.md §Post-ship amendments` déjà captures ; Phase 08 n'y touche pas. Dépendance : Phase 08 Review Gate fermée, Phase 09+ complétées, stabilité pipeline Phase 07 confirmée.
- **iOS FlutterImplicitEngineDelegate rewire** — Phase 15 polish quand Apple stabilise scene-based API. GPS Phase 05 concern (auto-resume-post-kill iOS), pas Phase 07 map.
- **Xiaomi / Samsung / Huawei / OnePlus OEM device coverage testing** — Phase 15 release testing (même décision Phases 06 + 04 + 02).
- **MPL-unreachable heuristic fix dans `tool/check_licenses.dart`** — Phase 16 release audit (backlog Phase 02 depuis adversarial wave Phase 02 qui n'avait couvert que 3 des 4 Blockers). Même décision Phase 06 defer.
- **Agent #5 dédié smell-lens** — rejeté Phase 08 en faveur du pattern cross-cutting brief + §2 pre-class category + §3 triage tag. Maintient la règle locked "4 agents all general-purpose".
- **Re-smoke device Phase 08** — rejeté. Précédent Phase 06 + smoke/fix iOS convergent 2026-04-21/22. Si user change d'avis post-audit, re-smoke est un fix-loop task isolé non pré-engagé.
- **Soak matrix massive réingénierie (10+ scenarios)** — rejeté. Les 6 existants Plan 07-04 + 2 edge cases additionnels Phase 08 suffisent gate. Réingénierie = scope-creep Phase 08.
- **`package:yaml` / `package:xml` comme nouvelle dep pour `check_style_no_external_url`** — probablement évitable avec pure-Dart `jsonDecode` (style.json est JSON, pas YAML). Si Agent #4 audit recommande une dep spécifique, nouvelle entry DEPENDENCIES.md requise dans le fix-loop.
- **Persistent adversarial matrix dans `ci.yml`** (matrix job ré-exécutant les known-bad tests adversariaux à chaque push) — rejeté Phases 02+04+06, reste rejeté Phase 08. Si les garde-fous doivent être re-stressés à chaque phase de code, justifie une phase dédiée (Phase 16 release audit). En V1.0, 1 stress par review-gate suffit.
- **Audit exhaustif `pubspec.lock` paquet par paquet (200+ entries post Phase 07 additions)** — remplacé par spot-check des deltas Phase 07 par Agent #4. Ré-audit exhaustif = jours de travail pour signal minimal additionnel.
- **Automatisation du fix des Could / Noted** — pas dans Phase 08. Could peuvent être triagés `defer-to-phase-15-polish`, Noted alimentent `deferred` de phases futures.
- **Rapport de stress-test comme artefact permanent séparé** (`docs/guardrail-stress-tests.md`) — non retenu Phases 02+04+06, reste non retenu Phase 08. Les evidences vivent dans les `XX-REVIEW.md` review-gate-par-review-gate.
- **MethodChannel sync test pour DiskSpaceChecker + IosBackupExcluder** — pas pré-engagé Phase 08. Si Agent #4 trouve drift risk cross-Kotlin/Swift/Dart, peut être ajouté en fix-loop suivant pattern Phase 06 Test #1+5. Sinon Phase 15 release audit.
- **Pre-commit hooks (lefthook ou autre)** — rejeté Phase 01+02+04+06, reste rejeté Phase 08. CI reste l'autorité unique.
- **ProviderScope + GoRouter integration_test deep-link coverage au-delà des 4 absorbés** — Phase 11 Markers ou Phase 13 Import/Export pourra étendre la couverture integration_test sur leurs propres screens. Phase 08 ne pré-engage pas l'extension.
- **Replace `maplibre_gl 0.25.0` par implémentation custom ou autre renderer** — overkill V1.0, décision D7 lock PROJECT.md (fallback non implémenté sera envisagé uniquement si `maplibre_gl` est abandonné ou montre un bug bloquant). Pas ouvert Phase 08.
- **Tooling pour V1.x map enrichment** (rivers LineString pipeline, buildings extraction, street labels, POI categorization) — à sortir en roadmap V1.x dédiée. Phase 08 ne pré-engage pas le tooling.

</deferred>

---

*Phase: 08-review-gate-map*
*Context gathered: 2026-04-23*
