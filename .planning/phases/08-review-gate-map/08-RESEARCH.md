# Phase 08: Review Gate — Map - Research

**Researched:** 2026-04-23
**Domain:** Review gate — audit exhaustif Phase 07 Map Integration (150+ Dart files + 2 platform channels + 6 assets + 4 tool files + 85+ tests + 6 soak scenarios) avant déblocage Phase 09 Fog Rendering
**Confidence:** HIGH (template Phase 02/04/06 directement réutilisable + CONTEXT.md extrêmement détaillé + toutes les décisions sont verrouillées upstream)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Plan 07-07 absorption (structural) :**
- Plan 07-07 scope reduced — limité à smoke-walk + iOS animateCamera fix (déjà fait 2026-04-21/22 via commits `81d30c7` + `ab497ab` + `40b49d5`). Les 4 integration tests originalement planifiés (airplane_mode / first_launch_world_copy / map_end_to_end / phase_07_navigation) + la checkpoint physical smoke sont **absorbés par Phase 08 adversarial wave**.
- Phase 08 Plan 08-01 scaffold amend ROADMAP.md (Plan 07-07 → scope-reduced done + Phase 07 → 7/7 Complete) et crée `07-07-SUMMARY.md` capturant scope-reduction rationale + cross-reference vers le plan Phase 08 qui écrit les 4 tests. Aucun fichier orphelin — `07-07-integration-verification-PLAN.md` reste sur disque avec annotation "scope reduced — integration tests absorbed into Phase 08".
- Integration tests location : `integration_test/` directory (norme Flutter, actuellement inexistant). Job CI séparé `integration-tests` dans `.github/workflows/ci.yml`, opt-in via `@Tags(['integration'])` pour ne pas bloquer la CI unit fast-path.
- Les 4 integration tests deviennent **permanent unit tests Phase 06-style avec inertness guards** (pattern Phase 04 Test #3 + Phase 06 Tests #1-5 précédent). Écrits en adversarial wave dédiée Phase 08.

**Sub-agent slicing : hybrid layer + risk (4 agents general-purpose) :**
- **Agent #1 — Map infra + seam purity** : `lib/domain/map/*` + `lib/infrastructure/map/*` + `tool/check_avoid_maplibre_leak.dart` + `tool/check_avoid_remote_pmtiles.dart` + paired tests + `test/domain/map/**` + `test/infrastructure/map/**`. Smell-heuristics lens prioritaire : StyleRewriter + 2 validators.
- **Agent #2 — Download pipeline + atomicity** : `lib/infrastructure/downloads/*` + `test/infrastructure/downloads/**` + 6 soak scenarios + shelf-backed FakeHttpServer. Smell-heuristics lens prioritaire : PmtilesDownloadController 7-step sealed states (enum candidat "state machine tirée par les cheveux").
- **Agent #3 — Controllers + providers + presentation** : `lib/application/` map-related (map_providers.dart + 4 controllers + FirstLaunchBootstrap pre-init dans `main.dart`) + `lib/presentation/screens/` + `lib/presentation/widgets/` + `lib/application/routing/router.dart` + `test/presentation/**` + `test/application/controllers/**`. Smell-heuristics lens prioritaire : MapCameraController follow/pan/iOS-animateCamera-post-fix + ActiveSessionController + ActiveSessionState Phase 05 legacy touché par 07-05.
- **Agent #4 — Natives + assets + CI gates + DEPENDENCIES.md + CLAUDE.md sweep + smell heuristics transverses** : platform channels (DiskSpaceChecker Kotlin+Swift + IosBackupExcluder Swift) + Android INTERNET manifest + `assets/maps/` (world + catalog + style + glyphs + sprites + polygons) + `tool/generate_tiny_pmtiles.dart` + `tool/generate_world_sha256.dart` + `tool/prepare_style.dart` + `tool/simplify_polygons.dart` + DEPENDENCIES.md deltas Phase 07 + CLAUDE.md anti-patterns transverses.
- **Agent #5 dédié smell-lens REJETÉ** — pattern cross-cutting brief + §2 pre-class category + §3 triage tag suffit. Maintient la règle locked "4 agents all general-purpose".

**Cross-cutting smell-heuristics (CLAUDE.md §En review faire attention à — delta 2026-04-23) :**
- Brief explicite à chaque sub-agent : "en plus de ton layer, tu cherches fix-on-fix et over-state-machine. Quand tu détectes ces patterns, demande-toi si une fonction pure, un pattern strategy, ou juste des données mieux structurées feraient le même boulot. Propose l'alternative, quitte à ce que ça remette en cause l'architecture produite aux phases précédentes."
- §2 pre-class category "Smell heuristics hot-spots" avec 4 composants pré-listés (Agent #2 PmtilesDownloadController 7-step / Agent #3 MapCameraController follow/pan iOS-fix / Agent #1 StyleRewriter + 2 validators / Agent #3 ActiveSessionController + ActiveSessionState Phase 05 legacy touché 07-05).
- §3 triage tag `smell` pour flagger les findings de ce type — décision fix-vs-refactor-architectural visible dans triage.

**§2 pre-class items (10 items, AVANT spawn agents) :**
1. Water filter Polygon/MultiPolygon only — **Noted** (V1.x enrichment).
2. Background downloads → V2 backlog — **Noted** (Agent #3 vérifie UX copy).
3. iOS animateCamera crash RÉSOLU 2026-04-22 via `81d30c7` + `ab497ab` + `40b49d5` — **Noted** (Agent #3 vérifie fix tient + aucun `// fix for edge case`).
4. Plan 07-07 absorbed → ROADMAP.md + REQUIREMENTS.md sync — **Should** (fix in loop, Plan 08-01 scaffold).
5. pmtiles-heal path in FirstLaunchBootstrap (mid-rename kill recovery shipped Plan 07-04) — **Noted** reference (Agents #1+#2 vérifient cohérence + soak scenario #6 couverture).
6. Smell heuristics hot-spots (4 composants) — **category inline §2, pas un finding unique**.
7. ROADMAP/REQUIREMENTS sync obligatoire — dupliqué avec #4 mais explicité comme **Should** fix-loop.
8. `tool/simplify_polygons.dart` + `tool/generate_tiny_pmtiles.dart` audit — **Could/Noted** selon finding (Agent #4).
9. CountryResolver edge cases (SC#2) — **Should si findings, sinon Noted** (Agent #1).
10. DEPENDENCIES.md audit deltas Phase 07 (maplibre_gl 0.25.0 BSD-3, crypto, shelf) — **Noted** reference (Agent #4 re-scan).

**POC / runtime evidence review §1b — no fresh walk :**
- Agent #4 lit `docs/phase-07-smoke.md` (Android Pixel 4a PASS + iOS PASS-with-caveat / fix-landed) + `docs/phase-07-ios-animate-camera-crash.md` (investigation + bisection + TL;DR RÉSOLU + stack .ips inline) + 7 screenshots (`android-01-map-screen.png` .. `android-05-post-delete.png` + `ios-01-map-screen.png` + `ios-02-download-complete.png`).
- Format §1b (précédent Phase 06) : per-device collapsed `<details>` sections.
- Rationale : smoke du 2026-04-21 + fix iOS 2026-04-22 sont convergents. Re-smoke coûterait ~2-3h sans signal additionnel.

**Adversarial wave design :**
- **Ratio 1 adversarial branch per CI-gate-script** (Phase 06 précédent locked).
- **4 integration tests absorbés (Plan 07-07 → Phase 08)** tous dans `integration_test/` (nouveau directory top-level), `@Tags(['integration'])`, job CI `integration-tests` on-demand, inertness guards Phase 06-style.
  - `integration_test/airplane_mode_test.dart` (MAP-01 + QUAL-05 subset) — HttpOverrides + SocketException fail-all — invocation count zero + inertness pre-assert FakeMapView a reçu `showMap()` + PmtilesSource émit URI `pmtiles:///`.
  - `integration_test/first_launch_world_copy_test.dart` (MAP-07 auto-heal) — 3 scenarios (A fresh, B corrupt destination, C idempotent no-op) — inertness pre-assert FirstLaunchBootstrap.init() invoqué + FS fake a reçu writes.
  - `integration_test/map_end_to_end_test.dart` — full user journey launch → /map → /maps-download → download pays X → /maps-manage → delete → world fallback — shelf FakeHttpServer + real FileSystem tmp + real AppDatabase in-memory + FakeMapView callbacks onStyleLoaded — inertness pre-assert chaque étape qu'au moins 1 event clé émis.
  - `integration_test/phase_07_navigation_test.dart` (router + 5 new screens) — /map + /maps-download + /maps-manage + /style-import + /style-export + back-navigation + deep-links — inertness pre-assert GoRouter a reçu push/go events + screens ont émis build().
- **3 permanent unit tests nouveaux (inertness-guarded, pas de branche) :**
  - `test/infrastructure/assets/world_bundle_sha256_test.dart` — recompute sha256 + assert = `kWorldBundleSha256` — inertness pre-assert fichier existe + size > 0.
  - `test/infrastructure/downloads/manifest_atomicity_contract_test.dart` — JsonFileInstalledManifestRepository.write() atomique (kill-mid-write = intact OR complet, jamais partial) — injection FS fake qui throw à 4 points — inertness pre-assert fake FS a reçu ≥ 1 write.
  - `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` — pure-Dart scan `test/` (hors `integration_test/` + `@Tags(['integration'])`) ne matche `HttpClient()` / `http.Client()` / `Dio()` sans fake injection — inertness pre-assert scan a visité ≥ N fichiers.
- **1 CI gate script nouveau : `tool/check_style_no_external_url.dart`** — contract exit 0/1/2 — parse `assets/maps/style.json` via pure-Dart `jsonDecode` (style.json EST JSON) — walk toutes URLs (sources, glyphs, sprite, tiles) — reject toute URL qui ne matche pas `pmtiles:///` / local file / asset bundle path — stderr avec file path + JSON path + offending URL — ajouté au `.github/workflows/ci.yml` `gates` job — paired unit test `test/tooling/check_style_no_external_url_test.dart` avec 4+ fixtures dont la style.json production actuelle.
- **1 adversarial branch : `adversarial/08-style-external-url`** — poison commit inject `"url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"` dans `assets/maps/style.json` — push → CI step `dart run tool/check_style_no_external_url.dart` doit fail exit 1 avec stderr identifiant file path + JSON path + offending URL — evidence §4 : branch name, commit hash, run URL, exit code, stderr extrait — cleanup branche supprimée local + remote — trigger expansion inline `on.push.branches += 'adversarial/**'`.
- **2 edge cases soak additionnels (SC#3) :** (a) corrupt chunk mid-stream (5 chunks, #3 sha256 mismatch → staging nettoyé + download reportable + `.pmtiles` cible absent) + (b) rename target already exists (retry sur pays déjà partial-installed → AtomicRenamer gère correctement, pas de fuite manifest). **Total soak : 8 scenarios** (6 existants Plan 07-04 + 2 nouveaux).

**Ordering : strict user-first protocol (locked Phases 02+04+06) :**
- User poste findings IDE en chat AVANT spawn
- Capture verbatim §1 (ou `'Aucune observation utilisateur'` marker)
- ENSUITE §1b evidence review (Agent #4, pas fresh walk)
- ENSUITE pre-class §2 des 10 items handoff
- ENSUITE spawn 4 sub-agents en single tool-use message
- Parallèle rejeté (user tape pendant que agents tournent)

**Output contract des sub-agents (Phases 02+04+06) :**
- Structured findings : `[severity] Title — 1-line explanation — file:line` — Sévérités : `Blocker` / `Should` / `Could` / `Noted`.
- Narrative appendix archivé dans `08-REVIEW.md §Audit Notes Agent #N`.
- Cross-lens overlap preservation : finding surfacé par 2 agents avec severities différentes préservé sous les 2 lens avec cross-reference, pas dedupliqué.
- §3 triage tag `smell` pour findings fix-on-fix ou over-state-machine.
- `gsd-verifier` grep `^## [1-5]\.` pour confirmer 5 sections.

**Fix workflow + gate-closed criteria :**
- Commits atomiques `fix(08-rev): <title>` / `refactor(08-rev):` / `docs(08-rev):` / `test(08-rev):` / `chore(08-rev):` selon nature.
- **Batched strategy permissible** si user approuve explicitement (précédent Phase 04 Plan 04-05).
- Chaque commit passe CI avant le suivant.
- **Gate-closed** :
  - Tous `Blocker` fixés (pas de waiver possible).
  - Tous `Should` soit fixés soit explicitement waiver avec rationale inline §3.
  - Findings `smell`-tagged triage explicite (fix / refactor / defer).
  - CI verte sur commit final `main`.
  - `08-REVIEW.md` 5 sections remplies.
  - `tool/check_style_no_external_url.dart` ajouté au CI gates job, confirmé green.
  - ROADMAP.md amendé (Plan 07-07 scope-reduced + Phase 07 → 7/7 Complete + Phase 08 → completed).
  - REQUIREMENTS.md amendé (MAP-05/06/07/08/10 → Complete).
  - `07-07-SUMMARY.md` créé.

### Claude's Discretion

- Wave layout exact des plans Phase 08 (combien de plans, scaffold / evidence-review / pre-class / agents / adversarial / fixes — arbitrer en planning, mais §1b evidence + §2 pre-class DOIVENT être AVANT agents, idem sequencing Phase 06).
- Format exact markdown §1b (structure interne des `<details>` sections, tables cadence, inline vs file-linked screenshots selon rendering md).
- Ordering d'écriture des 4 integration tests + 3 permanent unit tests (parallèle vs séquentiel, single commit vs per-test commit).
- Choix exact du mécanisme parsing pour `check_style_no_external_url.dart` (pure-Dart `jsonDecode` recommandé — style.json EST JSON, pas YAML — audit DEPENDENCIES.md si nouvelle dep).
- Stratégie de cleanup de la branche `adversarial/08-style-external-url` (delete immédiat post-archivage vs delete batch en fin de Plan 08-XX).
- Format exact des 4 integration test file names + 3 permanent unit test file names (convention test naming selon layer directory).
- Découpage interne Agent #4 (assets + tooling + natives + DEPENDENCIES.md + CLAUDE.md sweep + smell-heuristics transverses peut être un pass combiné ou divisé).
- Re-scope d'un agent si user IDE findings flaggent un angle spécifique (ex : user flag un bug MapCameraController post-iOS-fix → Agent #3 briefé explicitement à creuser).
- Choix exact des 2 edge cases soak additionnels (définitions précises — chunk index exact, timing, expected post-state).
- Format commit subject line des 3 permanent unit tests + 4 integration tests (`test(08-rev): add regression guard for X` vs `feat(08-rev): add integration test Y`).
- Severity exacte de chaque pre-class item (confirmation propositions ci-dessus).

### Deferred Ideas (OUT OF SCOPE)

- **V1.x map enrichment phase dédiée** (rivers-as-LineString visible + buildings + POIs catégorisés + labels street + relief) — post-V1.0.
- **Background downloads V2 backlog** (Android Foreground Service + iOS URLSession.backgroundConfiguration) — Phase 08 n'y touche pas.
- **iOS FlutterImplicitEngineDelegate rewire** — Phase 15 polish.
- **Xiaomi / Samsung / Huawei / OnePlus OEM device coverage testing** — Phase 15 release testing.
- **MPL-unreachable heuristic fix dans `tool/check_licenses.dart`** — Phase 16 release audit.
- **Agent #5 dédié smell-lens** — rejeté Phase 08.
- **Re-smoke device Phase 08** — rejeté (précédent Phase 06 + smoke/fix iOS convergent 2026-04-21/22).
- **Soak matrix massive réingénierie (10+ scenarios)** — rejeté (6 + 2 suffisent).
- **`package:yaml` / `package:xml` comme nouvelle dep** — probablement évitable avec pure-Dart `jsonDecode`.
- **Persistent adversarial matrix dans `ci.yml`** — rejeté Phases 02+04+06, reste rejeté.
- **Audit exhaustif `pubspec.lock` paquet par paquet (200+ entries)** — remplacé par spot-check des deltas par Agent #4.
- **Automatisation du fix des Could / Noted** — pas dans Phase 08.
- **Rapport de stress-test comme artefact permanent séparé** — les evidences vivent dans `XX-REVIEW.md`.
- **MethodChannel sync test pour DiskSpaceChecker + IosBackupExcluder** — pas pré-engagé (si Agent #4 trouve drift risk, ajouté en fix-loop).
- **Pre-commit hooks (lefthook ou autre)** — rejeté Phase 01+02+04+06, reste rejeté.
- **ProviderScope + GoRouter integration_test deep-link coverage au-delà des 4 absorbés** — Phase 11/13 pourra étendre.
- **Replace `maplibre_gl 0.25.0` par implémentation custom** — overkill V1.0.
- **Tooling pour V1.x map enrichment** — V1.x dédiée.
</user_constraints>

<phase_requirements>
## Phase Requirements

Pas de requirement IDs spécifiques à Phase 08 — un review gate ne possède pas de REQ-ID, il vérifie les REQ de la phase précédente. Phase 08 **amende** le statut des REQ Phase 07 de "In Progress" à "Complete" :

| ID | Description (abrégée) | Research Support |
|----|----------------------|------------------|
| MAP-05 | `PmtilesSource` local-only + `avoid_remote_pmtiles` lint | Agent #1 audit — status "In Progress (Plan 07-01 scaffolding done; PmtilesSource impl pending Plan 07-03)" → Complete. Plan 07-03 a shippé `lib/infrastructure/map/pmtiles_source.dart`. Agent #1 vérifie seam purity + Agent #2 vérifie download pipeline. CI gate `check_avoid_remote_pmtiles.dart` déjà live. |
| MAP-06 | `MapView` interface domain-level + `avoid_maplibre_leak` | Agent #1 audit — status "In Progress (Plan 07-01 scaffolding done; MapView interface pending Plan 07-02)" → Complete. Plan 07-02 a shippé `lib/domain/map/map_view.dart` + 5 fakes. CI gate `check_avoid_maplibre_leak.dart` déjà live. |
| MAP-07 | World bundle z0-2 bundlé + copy au premier lancement | Agent #1 audit FirstLaunchWorldCopier + Agent #4 audit asset `world.pmtiles`. Status "In Progress (first-launch copier pending Plan 07-03)" → Complete. Plan 07-03 + Plan 07-04 (pmtiles-heal path mid-rename kill recovery) shippés. Nouveau test `world_bundle_sha256_test.dart` + nouveau integration test `first_launch_world_copy_test.dart` verrouillent MAP-07 durablement. |
| MAP-08 | Écran download + catalog JSON bundlé asset + alpha3/name/parts/reassembled | Agent #3 audit MapsDownloadScreen + Agent #4 audit `catalog.json` asset. Status "In Progress (download screen pending Plan 07-06)" → Complete. Plan 07-06 MapsDownloadScreen shippé. Integration test `map_end_to_end_test.dart` exercise le flow. |
| MAP-10 | Écran manage + delete + world sentinel read-only | Agent #3 audit MapsManageScreen + Agent #2 audit CountryDeleteService world sentinel guard. Status "In Progress (management screen UI pending Plan 07-06)" → Complete. Plan 07-06 shippé. Integration test delete path verified. |

**Ces 5 REQ sont **In Progress** à l'ouverture de Phase 08 — Phase 08 Plan 08-01 scaffold les amend à Complete** (pre-class §2 item #7 "ROADMAP/REQUIREMENTS sync obligatoire" capture l'action, fix-loop confirme via `fix(08-rev): amend ROADMAP + REQUIREMENTS to reflect Phase 07 complete`).

REQ référencés mais déjà Complete (pas d'amendement) : MAP-01 / MAP-02 / MAP-03 / MAP-04 / MAP-09 / QUAL-05 (couvert subset via airplane_mode_test).
</phase_requirements>

## Summary

Phase 08 est la **review gate intermédiaire** entre Phase 07 Map Integration et le sprint UX critique Phases 09 Fog Rendering + 11 Markers + 13 Import/Export. Scope d'audit : ~150+ fichiers Dart + 85+ test files + 2 platform channels Kotlin/Swift + 6 assets + 4 tool files + 2 CI lint gates live (`check_avoid_maplibre_leak` + `check_avoid_remote_pmtiles`). Charge **supérieure à Phase 06** qui avait ~90-120 Dart + 50-70 tests + 3 natives.

Le template Phase 02/04/06 review-gate (5-section REVIEW.md + user-first protocol + 4 parallel sub-agents + pre-classification §2 + adversarial wave + fix loop + CI-green closure) est **directement réutilisable**. Phase 08 a **3 divergences locked** :

1. **Hybrid layer+risk sub-agent slicing** (pas pur-layer) — Phase 06 layer-strict surchargerait Agent #1 en Map Infrastructure avec ~150+ fichiers ; répartition par risk proximity est nécessaire.
2. **Absorption Plan 07-07** — 4 integration tests + checkpoint physical smoke absorbés (les tests deviennent permanent regression guards Phase 08 avec inertness guards ; smoke déjà fait Plan 07-07 reduced scope).
3. **Cross-cutting smell-heuristics brief** — nouveau pattern CLAUDE.md §En review faire attention à (delta 2026-04-23) : code alambiqué par empilement de fix + state machine tirée par les cheveux. Phase 08 est la **première** review gate à encoder ces patterns.

**Primary recommendation :** Réutiliser la structure en 5 plans de Phase 06 avec divergences documentées : Plan 08-01 scaffold + §1 user-first capture + ROADMAP/REQUIREMENTS amend ; Plan 08-02 §1b evidence review (extraction docs) ; Plan 08-03 §2 pre-class 10 items + smell-hot-spots table + 4 agents parallèles + §3 triage ; Plan 08-04 adversarial wave (4 integration tests + 3 permanent unit tests + 1 CI gate + 1 adversarial branch + 2 soak edge cases) ; Plan 08-05 fix-loop atomique CI-gated + §5 CI-green + closure.

## Standard Stack

### Core (already in pubspec.yaml — Phase 08 ne rajoute rien requis)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_test | SDK | Widget tests + inertness guards | Phases 02/04/06 template locked |
| integration_test | SDK (dev_dep) | Top-level `integration_test/` directory | Déjà dans pubspec.yaml ligne 93 — Flutter convention |
| test | 1.30.0 | Pure-Dart tests (tool/test/*) | Existing convention |
| shelf | 1.4.2 | Mock HTTP server (réutilisation FakeHttpServer Plan 07-04) | BSD-3-Clause, Dart-team, already direct dev_dep |
| crypto | 3.0.7 | sha256 compute pour `world_bundle_sha256_test` | Déjà direct dep Phase 07 |

### Supporting (existing repo infrastructure)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| path | 1.9.1 | `p.join()` pour FS paths (integration tests) | Always — CLAUDE.md §Naming de chemins |
| path_provider_platform_interface | 2.1.2 (dev) | Override AppSupportDir en integration_test | first_launch_world_copy_test |
| plugin_platform_interface | 2.1.8 (dev) | MockPlatformInterfaceMixin | Same |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `jsonDecode` pour check_style_no_external_url | `package:yaml` | **REJETÉ** — style.json EST JSON, pas YAML. `jsonDecode` est dans `dart:convert` (core lib, pas de nouvelle dep). yaml ajouterait surface d'audit GOSL sans bénéfice. |
| pure-Dart regex pour check_style_no_external_url | `package:xml` | **REJETÉ** — style.json n'est pas XML. Pas applicable. |
| Nouveau fake HttpClient pour `map_end_to_end_test` | Réutiliser `FakeHttpServer` Plan 07-04 (shelf-backed) | Réutilisation OK — 6 sealed behaviours déjà disponibles. |
| integration_test/ comme dir runnable | test/phase_07_integration/ (directory actuel) | **MOVE** vers `integration_test/` requis — CONTEXT locked. Le directory `test/phase_07_integration/` contient les 3 tests actuels (pas 4 — `phase_07_navigation_test.dart` absent) ; Plan 08-XX les MOVE vers `integration_test/` + AJOUTE le 4e. |

**Installation :**

Aucune nouvelle dépendance requise. Phase 08 consomme uniquement :
- Tests Flutter/Dart déjà disponibles
- Fakes réutilisables (`FakeMapView`, `FakeCountryCatalog`, `FakeCountryResolver`, `FakeHttpServer` shelf, `FakeInstalledManifestRepository`)
- `mapViewBuilderForTest` typedef seam MapScreen (Plan 07-06)

## Architecture Patterns

### Recommended Phase 08 Plan Structure (5 plans, adaptation Phase 06)

```
.planning/phases/08-review-gate-map/
├── 08-CONTEXT.md                             # Existing (input)
├── 08-RESEARCH.md                            # This file
├── 08-REVIEW.md                              # Created Plan 08-01, filled 08-02..08-05
├── 08-01-PLAN.md                             # Scaffold + §1 user capture + ROADMAP/REQ amend + 07-07-SUMMARY
├── 08-02-PLAN.md                             # §1b evidence review (Agent #4 extracts docs/phase-07-smoke.md + ios-crash)
├── 08-03-PLAN.md                             # §2 pre-class 10 items + smell-hot-spots + 4 agents parallel + §3 triage
├── 08-04-PLAN.md                             # Adversarial wave (4 integration + 3 permanent unit + 1 CI gate + 1 adversarial branch + 2 soak)
└── 08-05-PLAN.md                             # Fix-loop atomic (batched permissible) + §5 CI-green + closure + Phase 09 unblocked
```

### Pattern 1: 5-section REVIEW.md skeleton (locked Phase 02/04/06)

**What :** `08-REVIEW.md` avec 5 top-level sections, `gsd-verifier` grep `^## [1-5]\.` confirme 5.

**When to use :** Scaffold Plan 08-01, filled incrementally.

**Structure complete (adaptation Phase 06 sur concerns Phase 07 map/download/presentation/natives) :**

```markdown
# Phase 08: Review Gate — Map Review

**Opened:** 2026-04-23
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude reads any POC artefact and BEFORE Claude spawns any audit sub-agent.*

(awaiting user input — Plan 08-01 Task 2 fills this section)

### 1b. POC evidence review

*Filled by Plan 08-02. Source: `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots. User decision: no fresh walk (smoke+fix iOS convergent 2026-04-21/22).*

<details>
<summary>Android Pixel 4a — PASS 2026-04-23</summary>
(pending — filled by Plan 08-02)
</details>

<details>
<summary>iOS iPhone 17 Pro — PASS-with-caveat 2026-04-23</summary>
(pending — filled by Plan 08-02)
</details>

<details>
<summary>iOS animateCamera crash investigation + RÉSOLU 2026-04-22</summary>
(pending — filled by Plan 08-02)
</details>

## 2. Claude audit findings

### Pre-known from CONTEXT (10 items)

*Filled by Plan 08-03 Task 1 BEFORE spawning sub-agents.*

(pending — 10 entries: Water filter Noted | Background V2 Noted | iOS fix Noted | ROADMAP+REQ sync Should | pmtiles-heal Noted | Smell category / 4 hot-spots | ROADMAP/REQ sync dup Should | tool simplify/generate Could-or-Noted | CountryResolver edges Should-if-findings-else-Noted | DEPENDENCIES Noted)

### Smell heuristics hot-spots (4 components)

| Component | Agent | Concern | Smell category |
|-----------|-------|---------|---------------|
| (pending — 4 rows: PmtilesDownloadController 7-step / MapCameraController follow-pan iOS-fix / StyleRewriter + 2 validators / ActiveSessionController + ActiveSessionState Phase 05 touched by 07-05) | | | |

### Agent #1 — Map infra + seam purity
(pending)

### Agent #2 — Download pipeline + atomicity
(pending)

### Agent #3 — Controllers + providers + presentation
(pending)

### Agent #4 — Natives + assets + CI gates + DEPENDENCIES.md + CLAUDE.md sweep
(pending)

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>
(pending)
</details>

## 3. Triage decisions

*Filled by Plan 08-03 Task 4 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden). Every Should MUST be either `fix` or `waived` with inline rationale. Findings tagged `smell` triaged explicitly (fix / refactor / defer).*

| # | Finding | Severity | Decision | Rationale | Commit hash | Tag |
|---|---------|----------|----------|-----------|-------------|-----|
| (pending) | | | | | | |

## 4. Adversarial evidence

*Filled by Plan 08-04. 4 integration tests absorbed + 3 permanent unit tests + 1 CI gate + 1 adversarial branch + 2 soak edge cases.*

### Test 1: integration_test/airplane_mode_test.dart (MAP-01 + QUAL-05 subset)
(pending)

### Test 2: integration_test/first_launch_world_copy_test.dart (MAP-07 auto-heal)
(pending)

### Test 3: integration_test/map_end_to_end_test.dart (MockHTTP + full user journey)
(pending)

### Test 4: integration_test/phase_07_navigation_test.dart (router + 5 new screens)
(pending)

### Test 5: test/infrastructure/assets/world_bundle_sha256_test.dart (permanent unit test)
(pending)

### Test 6: test/infrastructure/downloads/manifest_atomicity_contract_test.dart (permanent unit test)
(pending)

### Test 7: test/infrastructure/network/no_httpclient_in_unit_tests_test.dart (permanent unit test)
(pending)

### Test 8: tool/check_style_no_external_url.dart adversarial CI run (adversarial/08-style-external-url)
(pending)

### Test 9-10: 2 new soak edge cases (corrupt chunk mid-stream / rename target already exists)
(pending)

## 5. CI-green confirmation

*Filled by Plan 08-05 Task 4 after all Blocker + non-waived Should fixes landed.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending)
- **Date:** (pending)

---
_Phase 08 closed: (pending)_
_Phase 09 unblocked._
```

### Pattern 2: Inertness-guarded permanent unit test (Phase 04 Test #3 + Phase 06 idiom verbatim)

**What :** Intermediate `expect` BEFORE the main assertion proves the adversary actually ran. Without it, future refactor silently neutralizes the test.

**When to use :** Chaque test Phase 08 (4 integration + 3 permanent unit + paired tool test).

**Example (extract `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart:95-106`, référence canonique Phase 04) :**

```dart
// Sanity: confirm the DELETE actually removed rows. If this
// ever passes without row loss, the test is silently inert —
// the rowid-parity DELETE MUST drop at least one session for
// the assertion below to be meaningful.
expect(
  after['t_sessions']! < before['t_sessions']!,
  isTrue,
  reason:
      'adversarial DELETE did not remove any session row — '
      'test would be inert. before=${before['t_sessions']} '
      'after=${after['t_sessions']}',
);

// THEN the main assert
expect(
  () => sanity.assertNoLoss(before, after),
  throwsA(isA<MigrationFailureException>()...),
);
```

**Example (Phase 06 Test #1 file-existence inertness guard verbatim) :**

```dart
for (final MapEntry<String, String> entry in sourcePaths.entries) {
  expect(
    File(entry.value).existsSync(),
    isTrue,
    reason: '${entry.key} path moved or deleted — test would be silently inert. Path: ${entry.value}',
  );
}
```

**Mutation experiment (validation value at author-time) :** renommer le fichier cible → assertion doit fail LOUDLY avec `reason` explicite, pas pass silently.

### Pattern 3: CI gate script exit-code contract (Phase 01 convention + `check_avoid_remote_pmtiles.dart` template verbatim)

**What :** CLI tool `tool/check_style_no_external_url.dart` respecte :
- exit 0 = clean (no external URL detected)
- exit 1 = policy violation (at least one URL non-`pmtiles:///` / local file / asset bundle)
- exit 2 = misconfiguration (scan root missing, asset file not found)

**When to use :** Nouveau CI gate ajouté au `.github/workflows/ci.yml` `gates` job.

**Template (adaptation `tool/check_avoid_remote_pmtiles.dart`) :**

```dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// CI gate enforcing that `assets/maps/style.json` contains zero external
/// URL. Only `pmtiles://file:///…` + local file path (`asset:///…` / file:)
/// are accepted in the style JSON's `sources[*].url` / `glyphs` / `sprite`
/// / tiles arrays.
///
/// Why this matters: MirkFall's V1.0 promise is "zero network for map
/// tiles, ever". A stray `"url": "https://tile.osm.org/…"` in style.json
/// would let MapLibre silently stream over HTTPS, breaking airplane mode.
/// The existing `check_avoid_remote_pmtiles` catches `pmtiles://http[s]`
/// URIs — this gate extends coverage to bare HTTP(S) URLs anywhere in the
/// style.json asset.
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : clean — no external URL in style.json URL fields
///   - exit 1 : violation — at least one `http://` or `https://` URL
///   - exit 2 : misconfiguration — style.json missing or unparseable

const String _stylePath = 'assets/maps/style.json';
final RegExp _externalUrlPattern = RegExp(r'^https?://', caseSensitive: false);

Future<int> runCheck({String? styleFilePath}) async {
  final String path = styleFilePath ?? _stylePath;
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('check_style_no_external_url: style.json not found at $path');
    return 2;
  }

  final String contents;
  final Map<String, dynamic> style;
  try {
    contents = await file.readAsString();
    style = jsonDecode(contents) as Map<String, dynamic>;
  } on Object catch (e) {
    stderr.writeln('check_style_no_external_url: failed to parse $path: $e');
    return 2;
  }

  final List<String> violations = <String>[];

  // Walk: sources[*].url + sources[*].tiles[] + glyphs + sprite
  final sources = style['sources'];
  if (sources is Map<String, dynamic>) {
    sources.forEach((String sourceId, dynamic source) {
      if (source is Map<String, dynamic>) {
        final url = source['url'];
        if (url is String && _externalUrlPattern.hasMatch(url)) {
          violations.add('sources.$sourceId.url: $url');
        }
        final tiles = source['tiles'];
        if (tiles is List) {
          for (var i = 0; i < tiles.length; i++) {
            final t = tiles[i];
            if (t is String && _externalUrlPattern.hasMatch(t)) {
              violations.add('sources.$sourceId.tiles[$i]: $t');
            }
          }
        }
      }
    });
  }
  final glyphs = style['glyphs'];
  if (glyphs is String && _externalUrlPattern.hasMatch(glyphs)) {
    violations.add('glyphs: $glyphs');
  }
  final sprite = style['sprite'];
  if (sprite is String && _externalUrlPattern.hasMatch(sprite)) {
    violations.add('sprite: $sprite');
  }

  if (violations.isEmpty) {
    stdout.writeln('check_style_no_external_url: OK (style.json has zero external URLs)');
    return 0;
  }

  stderr.writeln('check_style_no_external_url: ${violations.length} external URL(s) found in ${p.relative(path)}:');
  for (final String v in violations) {
    stderr.writeln('  - $v');
  }
  stderr.writeln();
  stderr.writeln('Rule: MirkFall is 100% offline. style.json URL fields MUST point to pmtiles://file:///… or asset:///… .');
  stderr.writeln('Replace the offending URL with a local path or asset bundle reference.');
  return 1;
}

Future<void> main(List<String> args) async {
  exitCode = await runCheck();
}
```

### Pattern 4: Adversarial branch lifecycle (Phase 02 Option B + Phase 06 precedent)

**What :** Throwaway branch `adversarial/08-style-external-url` avec poison + inline `on.push.branches += 'adversarial/**'` dans le même commit. Main trigger reste `[main]`-only après delete.

**When to use :** 1 branche par nouveau CI gate script. Phase 08 = 1 gate (`check_style_no_external_url`) = 1 branche.

**Workflow :**

```bash
# Setup adversarial branch
git checkout -b adversarial/08-style-external-url

# Poison 1: inject external URL dans style.json
# Modifier assets/maps/style.json - remplace:
#   "url": "pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER"
# par:
#   "url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

# Poison 2: inline CI trigger expansion (same commit as poison)
# Modifier .github/workflows/ci.yml ligne 3-7:
#   on:
#     push:
#       branches: [main, 'adversarial/**']
#     pull_request:
#       branches: [main]

# Stage + commit poison + trigger expansion
git add assets/maps/style.json .github/workflows/ci.yml
git commit -m "test(adversarial): inject external tile URL to exercise check_style_no_external_url gate"

# Push to trigger CI
git push -u origin adversarial/08-style-external-url

# Observe CI fail on gates job step "Check style no external URL" with exit 1
# Capture run URL + stderr excerpt into §4 Test 8

# Archive evidence in §4, then delete branch local+remote
git checkout main
git branch -D adversarial/08-style-external-url
git push origin --delete adversarial/08-style-external-url

# Verify cleanup
git branch -a | grep adversarial/08- || echo "local clean"
gh api "repos/:owner/:repo/branches" | jq -r '.[].name' | grep adversarial/08- || echo "remote clean"
```

**CI config amendment (main branch, post-archive) — add step to `gates` job after `Check avoid_remote_pmtiles` (line 100 of ci.yml) :**

```yaml
      - name: Check style no external URL
        run: dart run tool/check_style_no_external_url.dart
```

### Pattern 5: Integration test directory setup (Flutter convention)

**What :** Flutter's standard `integration_test/` top-level directory discovered by `flutter test integration_test/`. `integration_test: sdk: flutter` déjà dev_dependency (pubspec.yaml ligne 93).

**When to use :** Phase 08 Plan 08-04 MOVE les 3 tests existants `test/phase_07_integration/` → `integration_test/` + AJOUTE le 4e `phase_07_navigation_test.dart`.

**Structure finale :**

```
integration_test/
├── airplane_mode_test.dart            # MOVED depuis test/phase_07_integration/
├── first_launch_world_copy_test.dart  # MOVED depuis test/phase_07_integration/
├── map_end_to_end_test.dart           # MOVED depuis test/phase_07_integration/
└── phase_07_navigation_test.dart      # NEW (absent du current state)
```

**Test file boilerplate (Flutter integration_test convention) :**

```dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

@Tags(['integration'])
library;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('airplane mode: zero network for tiles', (tester) async {
    // Pre-assert inertness guard: FakeMapView exists + will receive showMap()
    final fakeMapView = FakeMapView();
    expect(fakeMapView.showMapInvocations, isEmpty, reason: 'pre-assert FakeMapView fresh');

    // Test body: HttpOverrides + pump
    final httpClient = _FailAllHttpClient();
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(...);
      // Exercise pan + zoom + country-swap
    }, createHttpClient: (_) => httpClient);

    // Inertness guard: prove FakeMapView was exercised (not silent-green)
    expect(
      fakeMapView.showMapInvocations, isNotEmpty,
      reason: 'FakeMapView never received showMap — test would be silently inert. '
              'invocations=${fakeMapView.showMapInvocations}',
    );

    // Main assertion: zero HTTP invocations
    expect(httpClient.invocationCount, 0, reason: 'airplane mode MUST block all HTTP');
  });
}
```

**CI job addition** (`.github/workflows/ci.yml`, additive — NEW job OR new step dans gates) :

```yaml
  integration-tests:
    name: Integration tests (@Tags integration, on-demand)
    needs: gates
    runs-on: ubuntu-latest
    # Opt-in — les integration tests absorbés Plan 07-07 tournent via flutter test
    # integration_test/ ; la Flutter test harness supporte ce directory sans
    # device si les widgets sous test utilisent FakeMapView override (pas de
    # vrai MapLibre platform view dans l'host test runner).
    if: github.event_name == 'workflow_dispatch' || contains(github.event.head_commit.message, '[integration]')
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Install Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: stable
          cache: true
      - name: Pub get
        run: flutter pub get
      - name: Run integration tests
        run: flutter test integration_test/ --tags integration
```

**Alternative simpler approach (recommended — tighter feedback loop) :** Run integration tests as a **step inside the existing `gates` job**, not a separate job:

```yaml
      - name: Integration tests (absorbed from Plan 07-07)
        run: flutter test integration_test/
```

Claude's discretion — integration job dédié vs step inline dans gates job (arbitrer Plan 08-04 selon wall-clock budget ; les 4 tests sous FakeMapView override devraient tourner en < 60s).

### Anti-Patterns to Avoid

- **Dedupliquer cross-lens findings** — même finding par 2 agents avec severities différentes MUST be preserved under both lenses with cross-reference (Phase 02+04+06 convention).
- **Bare `catch (_)`** — CLAUDE.md §Error handling violation. Au minimum log.fine + swallow avec rationale inline.
- **Fresh runtime walk Phase 08** — Phase 06 precedent explicite : POC artefacts ARE the runtime observation ; re-smoke coûte 2-3h sans signal additionnel. Rejected upstream dans CONTEXT.
- **Test sans inertness guard** — Phase 04 Test #3 mutation experiment a prouvé la valeur. 1-2 lignes par test, protection permanente.
- **Adversarial branch qui leak sur main** — le `on.push.branches += 'adversarial/**'` trigger expansion DOIT rester sur la throwaway branche uniquement. Main trigger `[main]`-only après delete.
- **Test adversarial avec exit 2 (misconfig) au lieu de exit 1 (policy violation)** — stderr du run CI DOIT prouver exit 1. Exit 2 = script broken, pas une vraie validation.
- **Test qui touche directement `MapLibreMapController`** dans `test/` sans passer par `MapView` abstract — c'est précisément ce que CI gate `avoid_maplibre_leak` bloque. Les tests Phase 08 utilisent `FakeMapView` via `mapViewBuilderForTest` typedef seam.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing pour `check_style_no_external_url` | Regex-based parser maison | `jsonDecode` de `dart:convert` (core lib) | style.json EST JSON. `jsonDecode` est déterministe, battle-tested, zéro surface d'audit supplémentaire. Regex fragiles sur structures imbriquées. |
| MockHTTPServer pour `map_end_to_end_test` | New mock HTTP implementation | Réutiliser `FakeHttpServer` shelf-backed Plan 07-04 (6 sealed behaviours) | Déjà audité, wire-level (Content-Length / Range / Accept-Ranges), mutable between requests, recordedRequests[] assertion surface. |
| Fake MapView pour integration tests | New in-memory MapView | Réutiliser `FakeMapView` Plan 07-02 | Implémente le surface complète du MapView domain interface. In-memory observable state (showMapInvocations, etc.). |
| Parser AndroidManifest.xml / Info.plist | `package:xml` nouvelle dep | Pure-Dart regex (précédent Phase 06 `check_platform_manifests.dart`) | Narrow enough — aucune structure imbriquée profonde à parser. Évite surface audit GOSL. |
| Fixture `world.pmtiles` pour `world_bundle_sha256_test` | Recompute + fixture snapshot | `rootBundle.load('assets/maps/world.pmtiles')` + compute sha256 streamed + assert = `kWorldBundleSha256` | Le constant est single source of truth — le test vérifie que l'asset n'a pas drifté sans mise à jour correspondante du constant. |
| Atomicité Write pour `manifest_atomicity_contract_test` | New atomic write lib | Exercise existing `JsonFileInstalledManifestRepository.write()` | Teste le contract existant (tempfile+rename), pas re-implémenter. Inject FS fake throwing à 4 points. |
| New pure-Dart HTTP scanner | Custom AST parser Dart | Pure-Dart regex scan sur `test/` file-by-file | Simple substring match `HttpClient()` / `http.Client()` / `Dio()`. AST overkill. |

**Key insight :** Phase 08 est un **audit** — le code à implémenter est minimal (1 CI gate + 4 tests + 3 permanent unit tests + 2 soak edge cases). Maximiser réutilisation des infrastructures Plan 07-02/04/06 ; tout nouveau code augmente surface d'audit + surface adversarial.

## Common Pitfalls

### Pitfall 1: Fresh runtime walk au lieu de POC evidence review §1b

**What goes wrong :** Claude décide de relancer `flutter run -d device` pour "re-valider" les smoke results Phase 07.

**Why it happens :** Réflexe d'audit fresh — mais CONTEXT locked `no fresh walk`.

**How to avoid :** Plan 08-02 lit UNIQUEMENT `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots committed. Format `<details>` per-device. 2-3h de walk épargnés.

**Warning signs :** Plan 08-02 mentionne "flutter run" / "run APK" / "sideload IPA" — STOP. CONTEXT.md ligne 47 : `Physical re-smoke device Phase 08 — rejeté (smoke/fix iOS convergent 2026-04-21/22)`.

### Pitfall 2: Spawn agents BEFORE §1 user capture + §1b evidence review + §2 pre-class

**What goes wrong :** 4 sub-agents spawnés en single tool-use message, mais §1 vide + §1b pas rempli + §2 pas classé.

**Why it happens :** Optimisation prématurée ("agents peuvent tourner pendant que user tape").

**How to avoid :** Strict sequencing CONTEXT locked :
1. Plan 08-01 scaffold + §1 user-first capture (blocking checkpoint `checkpoint:human-verify`)
2. Plan 08-02 §1b evidence extraction (Agent #4 seul, pas les 4)
3. Plan 08-03 §2 pre-class 10 items committed BEFORE agent spawn + smell-hot-spots table
4. THEN agents in single tool-use message

**Warning signs :** Plan 08-01 ou 08-02 tente `Task tool call` avec subagent_type `general-purpose` — STOP. CONTEXT.md ligne 232 : `Parallèle (user tape pendant que agents tournent) explicitement rejeté`.

### Pitfall 3: Over-engineered state machine smell trap (Agent #2 focus)

**What goes wrong :** Audit approve `PmtilesDownloadController` 7-step avec sealed states parce que "ça marche + test-proven" (Plan 07-04 shipped). Mais CLAUDE.md §En review faire attention à demande si plusieurs valeurs diffèrent d'1-2 champs, transitions quasi-tout-vers-tout, dispatcher géant.

**Why it happens :** Gap entre "fonctionne" et "bien conçu". Agent reach pour state machine dès qu'il y a > 2 comportements conditionnels.

**How to avoid :** Agent #2 brief explicite (CONTEXT) : "en plus de ton layer, tu cherches fix-on-fix et over-state-machine. Quand tu détectes ces patterns, demande-toi si une fonction pure, un pattern strategy, ou juste des données mieux structurées feraient le même boulot."

**Warning signs :** Agent #2 finding tag `smell` sur PmtilesDownloadController avec severity Should ou Blocker — pas automatiquement rejeté, même si Phase 07 a shippé. User triage §3 décide fix-vs-refactor-architectural.

### Pitfall 4: Fix-on-fix code alambiqué post-iOS-animateCamera-fix (Agent #3 focus)

**What goes wrong :** MapCameraController post-fix 2026-04-22 accumule flags (`_userLocationLayerInstalled`, `_pendingCamera`, etc.), early returns avec commentaires `// fix iOS 26.3.1 crash`, wrappers autour de wrappers (`jumpCameraTo` → `moveCamera` shim).

**Why it happens :** 4 tentatives de fix (Probe 1, Probe 2, Tentative 1-4). Chaque fix a laissé une trace. Tentative 4 (stateless point-in-polygon lookup, commit `40b49d5`) est la VRAIE fix ; les précédentes auraient dû être cleaned up.

**How to avoid :** Agent #3 lens explicite sur MapCameraController — lire le doc `docs/phase-07-ios-animate-camera-crash.md` pour comprendre le flow des tentatives + vérifier que seul le final state est dans le code, pas des strates de fix empilés.

**Warning signs :**
- `jumpCameraTo` API reste dans `MapView` interface mais n'est plus utilisé (Tentative 1 KO — garder dead code ?)
- Multiple flags `_pendingX` / `_hasBeenY` / `_shouldSkipZ` dans MapCameraController
- Commentaires `// post-iOS-fix` inline
- `openForSession` a un corps vide ou no-op suite aux probes

### Pitfall 5: Adversarial test exit code 2 au lieu de 1

**What goes wrong :** `adversarial/08-style-external-url` push poison, CI fail, mais stderr dit "style.json not found" (exit 2) au lieu de "external URL detected" (exit 1).

**Why it happens :** Poison qui break parsing au lieu de trigger violation (ex: invalid JSON instead of external URL).

**How to avoid :** Poison choisi TRÈS spécifiquement — inject un `"url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"` dans `sources.mirkfall_map.url` (remplace le placeholder existant `"pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER"`). JSON reste valide. Exit 1 garanti.

**Warning signs :** §4 Test 8 evidence stderr shows "failed to parse" / "file not found" — la gate script a détecté une misconfig, pas une vraie violation. Re-poison + re-push.

### Pitfall 6: Integration test qui ne passe pas CI (timeouts / flaky)

**What goes wrong :** `map_end_to_end_test.dart` avec shelf FakeHttpServer tourne 90+ seconds, CI timeout.

**Why it happens :** Real FileSystem + real Drift in-memory + shelf server + full user journey = slow.

**How to avoid :**
- Tag `@Tags(['integration'])` pour exclusion opt-in du fast-path unit tests
- Si job dédié `integration-tests` : timeout-minutes raisonnable (10 min)
- Si step inline dans `gates` job : budget serré, dev-friendly feedback
- MOVE existing tests `test/phase_07_integration/` → `integration_test/` + validation wall-clock actuel (les 3 tests tournent déjà aujourd'hui, donc baseline connu)

**Warning signs :** Plan 08-04 découvre qu'un test tourne > 60s — split en scenarios plus narrow ou batch-run en job séparé.

### Pitfall 7: ROADMAP/REQUIREMENTS sync manqué (pre-class item #4/#7)

**What goes wrong :** Phase 08 closes, CI green, §5 sign-off. Mais REQUIREMENTS.md dit encore `MAP-08 | Phase 07 | In Progress (Plan 07-01 + ... download screen pending Plan 07-06)`.

**Why it happens :** Bookkeeping manqué. Pre-class item #4 est l'action, item #7 est la duplication explicite — ne pas rejeter comme "already covered".

**How to avoid :** Plan 08-01 scaffold amend explicitly :
- ROADMAP.md : Plan 07-07 → `scope reduced (smoke + iOS fix only), integration tests absorbed into Phase 08`. Phase 07 progress → 7/7 Complete. Phase 08 progress → In Progress + completion date set in Plan 08-05 closure.
- REQUIREMENTS.md : MAP-05 / MAP-06 / MAP-07 / MAP-08 / MAP-10 → status "Complete".
- `07-07-SUMMARY.md` nouveau fichier capturant scope-reduction rationale + cross-reference vers Plan 08-04 qui écrit les 4 tests absorbés.
- `07-07-integration-verification-PLAN.md` annoté header "scope reduced — integration tests absorbed into Phase 08" (pas supprimé, pas renommé, pour préserver trace git).

**Warning signs :** Plan 08-01 est seulement scaffold + §1 capture + aucune action ROADMAP/REQ — manque item #4. Plan 08-01 doit aussi inclure amendments.

## Code Examples

Verified patterns from Phase 04/06 + Phase 07 existing code.

### Airplane mode HTTP interceptor (from `test/phase_07_integration/airplane_mode_test.dart` — already exists, Plan 08-04 MOVE + add inertness)

```dart
// Source: test/phase_07_integration/airplane_mode_test.dart:42-90 (existing code)
class _FailAllHttpClient implements HttpClient {
  _FailAllHttpClient();
  int invocationCount = 0;
  Never _fail(String method) {
    invocationCount++;
    throw const SocketException('airplane mode — network blocked');
  }
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _fail('getUrl');
  // ... (14 méthodes HTTP, toutes _fail)
}

// Test body (simplified):
await HttpOverrides.runZoned(() async {
  final fakeMapView = FakeMapView();  // Plan 07-02

  // Inertness pre-assert: FakeMapView n'a encore reçu aucun showMap
  expect(fakeMapView.showMapInvocations, isEmpty);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapViewProvider.overrideWith((_) => fakeMapView),
        // ... autres overrides
      ],
      child: MaterialApp(home: MapScreen(mapViewBuilderForTest: (_) => fakeMapView)),
    ),
  );
  // Exercise pan/zoom/country-swap
  await tester.pumpAndSettle();  // OR bounded pump(Duration) si stream.periodic

  // Inertness guard: FakeMapView DID receive showMap (pas silent-inert)
  expect(
    fakeMapView.showMapInvocations, isNotEmpty,
    reason: 'FakeMapView never received showMap — test would be silently inert.',
  );

  // Main assertion: zero HTTP
  expect(httpClient.invocationCount, 0, reason: 'zero HTTP in airplane mode');
}, createHttpClient: (_) => httpClient);
```

### World bundle sha256 regression guard (new — Plan 08-04)

```dart
// File: test/infrastructure/assets/world_bundle_sha256_test.dart
// Source: adapted from test/infrastructure/map/first_launch_world_copier_test.dart pattern

import 'dart:convert';  // utf8 (if needed)
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart' show kWorldBundleSha256;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assets/maps/world.pmtiles sha256 equals kWorldBundleSha256', () async {
    const String assetPath = 'assets/maps/world.pmtiles';

    // Inertness guard: verify file exists on disk + size > 0
    final File file = File(assetPath);
    expect(
      file.existsSync(), isTrue,
      reason: '$assetPath missing on disk — test would be silently inert. '
              'An asset rename without path update would make this test vacuously pass.',
    );
    final int sizeBytes = await file.length();
    expect(
      sizeBytes, greaterThan(0),
      reason: '$assetPath is zero bytes — test would be silently inert.',
    );

    // Main assertion: compute streamed sha256 + compare to constant
    final Digest digest = await sha256.bind(file.openRead()).first;
    final String actualHex = digest.toString();

    expect(
      actualHex,
      equals(kWorldBundleSha256),
      reason: 'world.pmtiles drifted without updating kWorldBundleSha256. '
              'FirstLaunchWorldCopier would auto-heal loop (corrupt detected → re-copy from asset → same corrupt). '
              'If the asset was intentionally updated, also bump kWorldBundleSha256 '
              '(run: dart run tool/generate_world_sha256.dart).',
    );
  });
}
```

### check_style_no_external_url.dart paired unit test (4+ fixtures)

```dart
// File: test/tooling/check_style_no_external_url_test.dart
// OR: tool/test/check_style_no_external_url_test.dart (convention paired — Phase 02)

import 'dart:io';
import 'package:test/test.dart';
import '../../tool/check_style_no_external_url.dart' show runCheck;

void main() {
  group('check_style_no_external_url', () {
    late Directory tempDir;
    setUp(() => tempDir = Directory.systemTemp.createTempSync('check_style_test_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('exit 0: clean fixture with pmtiles://file:/// URL', () async {
      final styleFile = File('${tempDir.path}/style.json');
      await styleFile.writeAsString(jsonEncode({
        'version': 8,
        'sources': {
          'mirkfall_map': {'type': 'vector', 'url': 'pmtiles://file:///world.pmtiles'}
        },
        'glyphs': 'asset:///glyphs/{fontstack}/{range}.pbf',
        'sprite': 'asset:///sprite',
        'layers': [],
      }));
      expect(await runCheck(styleFilePath: styleFile.path), 0);
    });

    test('exit 0: production style.json (integration check)', () async {
      expect(await runCheck(), 0);  // Uses default 'assets/maps/style.json'
    });

    test('exit 1: external URL in sources.*.url', () async {
      final styleFile = File('${tempDir.path}/style.json');
      await styleFile.writeAsString(jsonEncode({
        'version': 8,
        'sources': {'osm': {'type': 'raster', 'url': 'https://tile.openstreetmap.org/tiles.json'}},
      }));
      expect(await runCheck(styleFilePath: styleFile.path), 1);
    });

    test('exit 1: external URL in glyphs', () async {
      final styleFile = File('${tempDir.path}/style.json');
      await styleFile.writeAsString(jsonEncode({
        'version': 8,
        'glyphs': 'https://fonts.openmaptiles.org/{fontstack}/{range}.pbf',
        'sources': {},
      }));
      expect(await runCheck(styleFilePath: styleFile.path), 1);
    });

    test('exit 1: external URL in tiles[]', () async {
      final styleFile = File('${tempDir.path}/style.json');
      await styleFile.writeAsString(jsonEncode({
        'version': 8,
        'sources': {
          'raster': {
            'type': 'raster',
            'tiles': ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
          },
        },
      }));
      expect(await runCheck(styleFilePath: styleFile.path), 1);
    });

    test('exit 2: style.json missing', () async {
      expect(await runCheck(styleFilePath: '${tempDir.path}/nonexistent.json'), 2);
    });

    test('exit 2: unparseable JSON', () async {
      final styleFile = File('${tempDir.path}/style.json');
      await styleFile.writeAsString('{not valid json');
      expect(await runCheck(styleFilePath: styleFile.path), 2);
    });
  });
}
```

### Triage table §3 format (from 06-REVIEW.md)

```markdown
| # | Finding | Severity | Decision | Rationale | Commit hash | Tag |
|---|---------|----------|----------|-----------|-------------|-----|
| 1 | [Agent #2 #1] PmtilesDownloadController 7-step dispatcher duplicates error-cleanup between steps | Blocker | fix | Extract common cleanup into `_cleanupStaging(reason)` helper; simplifies 4 branches + removes code duplication. Smell: fix-on-fix traces from Plan 07-04 multi-iteration hardening. Cross-referenced by Agent #1 #3 (Should — same file smell). | `(pending)` | smell |
| 2 | [Agent #3 #4] MapCameraController accumulates `_pendingCamera` + `_userLocationLayerInstalled` + `_hasBeenInitialized` flags post iOS fix | Should | fix | Consolidate into single sealed `_CameraState` enum (Ready / PendingInitialCamera / Initialized); reduces implicit-invariant coupling. Smell: state machine tirée par les cheveux. | `(pending)` | smell |
| 3 | [Pre-class #4] ROADMAP Plan 07-07 + REQUIREMENTS MAP-05/06/07/08/10 sync to Complete | Should | fix | Plan 08-01 scaffold amend both files in one atomic `docs(08-rev): amend ROADMAP + REQUIREMENTS to reflect Phase 07 complete + Plan 07-07 scope-reduced`. | `(pending)` | — |
```

### Pre-class §2 entries format (from 06-REVIEW.md §2 `Pre-known from CONTEXT` — 10 entries for Phase 08)

```markdown
### Pre-known from CONTEXT

1. **[Noted] Water filter Polygon/MultiPolygon only** — rivers-as-LineString invisibles shipped Plan 07-06 post-device-smoke 2026-04-21. V1.x enrichment phase dédiée à créer post-V1.0. Reference `07-06-SUMMARY.md §Post-ship amendments` + `07-CONTEXT.md §<deferred>`.
2. **[Noted] Background downloads → V2 backlog** — Android FGS + iOS URLSession.background deferred V2 per PROJECT.md §V2 Backlog. Agent #3 vérifie MapDownloadProgressChip + MapsDownloadScreen copy UX ne promettent pas "background continues".
3. **[Noted] iOS animateCamera crash RÉSOLU 2026-04-22** — commits `81d30c7` (initialCameraPosition widget + pas de camera move dans openForSession) + `ab497ab` (GeoJSON puck bypass AnnotationManager) + `40b49d5` (stateless point-in-polygon lookup). Doc inline `docs/phase-07-ios-animate-camera-crash.md`. Agent #3 vérifie fix tient + aucun `// fix for edge case` introduit.
4. **[Should] Plan 07-07 absorbed → ROADMAP + REQUIREMENTS sync** — Plan 08-01 scaffold amend. ROADMAP: Plan 07-07 scope-reduced + Phase 07 → 7/7 Complete. REQUIREMENTS: MAP-05/06/07/08/10 "In Progress" → "Complete".
5. **[Noted] pmtiles-heal path in FirstLaunchBootstrap** — mid-rename kill recovery invariant shipped Plan 07-04. Agent #1 + Agent #2 vérifient cohérence avec atomic rename invariant + soak scenario #6 (mid-rename kill heal) en est la couverture test.
6. **[Smell category] Smell heuristics hot-spots** — 4 composants pré-listés ci-dessous (table). Pas un finding unique — catégorie inline §2 qui oriente les lens Agent #1-3 + §3 triage tag.
7. **[Should] ROADMAP/REQUIREMENTS sync obligatoire** — dupliqué avec #4 explicite comme Should fix-loop (pas "already covered, skip"). Commit line `fix(08-rev): amend ROADMAP + REQUIREMENTS to reflect Phase 07 complete`.
8. **[Could/Noted] `tool/simplify_polygons.dart` + `tool/generate_tiny_pmtiles.dart` audit** — licences deps (si Python, attention argparse/geometry ; si pure-Dart, moins de surface) + output déterministe (reproducible rebuild du world bundle) + tests. Agent #4 lens.
9. **[Should si findings / Noted sinon] CountryResolver edge cases (SC#2)** — frontier entre 2 pays installés / viewport au-delà d'un pays installé → fallback world bundle transparent / zoom world-only sans country match / polygon simplification lossy. Agent #1 lens.
10. **[Noted] DEPENDENCIES.md audit deltas Phase 07** — maplibre_gl 0.25.0 BSD-3, crypto, shelf. Agent #4 re-scan : licence amont confirm, télémétrie zero confirm, deps transitives rescanned pour GPL/AGPL, version pinning strict match `pubspec.yaml`.
```

## State of the Art

| Old Approach (Phase 02-04) | Current Approach (Phase 06-08) | When Changed | Impact |
|----------------------------|-------------------------------|--------------|--------|
| Pure layer slicing (4 agents strict-par-layer) | Hybrid layer+risk slicing | Phase 08 | Phase 07 scope ~150+ fichiers surchargerait un Agent #1 layer-pur. Hybrid re-balance par risk proximity. |
| §1b "Runtime walk Windows" | §1b "POC evidence review" (no fresh walk) | Phase 06 | POC artefacts ARE the runtime observation. Re-walk coûte 2-3h sans signal additionnel. |
| 3 adversarial branches per gate (Phase 02+04) | 1 branch per NEW gate script (Phase 06+08) | Phase 06 | 5 permanent unit tests remplacent 5 throwaway branches ; 1 branche reste pour le NOUVEAU CI gate. Maintainable + lean. |
| No smell-heuristics brief | Cross-cutting smell-heuristics brief + §2 category + §3 tag | Phase 08 | CLAUDE.md delta 2026-04-23 (code alambiqué par empilement de fix + state machine tirée par les cheveux). Phase 08 est la **première** review gate à encoder. Précédent pour Phases 10/12/14/16. |
| Full device re-smoke if iOS PASS-with-caveat | Extract artifacts + no re-smoke (Phase 06 precedent) | Phase 06 | Convergent Android evidence + stable iOS cadence = extrapolation suffisante. User peut opt-in top-up Phase 15 si besoin. |
| Per-finding atomic commit discipline strict | Batched strategy permissible si user approuve (Phase 04 precedent) | Phase 04 | 31 findings × 10 min CI gate = 5h wall-clock. 10 batches × 10 min = 100 min. User approves scope trade-off. |
| @Tags declaration per test | `@Tags(['soak'])` / `@Tags(['integration'])` discipline + `dart_test.yaml` | Phase 07 | Slow tests (10-60s soak) excluded from default `flutter test`. Opt-in via `dart test --tags soak`. Same for integration_test. |
| Test files in `test/phase_XX_integration/` | Files in `integration_test/` top-level | Phase 08 | Flutter convention. `flutter test integration_test/` discovers automatically. Plan 08-04 MOVE + renames. |

**Deprecated/outdated :**
- **Agent #5 dédié smell-lens** : REJECTED Phase 08. Cross-cutting brief suffit. Règle "4 agents all general-purpose" préservée.
- **Persistent adversarial matrix in ci.yml** : REJECTED Phase 02+04+06, reste REJECTED Phase 08.
- **Fresh device walk** : REJECTED Phase 06+08.
- **Test/phase_XX_integration/** : sera MOVED → `integration_test/` Plan 08-04.

## Open Questions

1. **Move path vs keep path pour les 3 integration tests existants `test/phase_07_integration/`**
   - What we know: Les 3 tests (`airplane_mode_test.dart`, `first_launch_world_copy_test.dart`, `map_end_to_end_test.dart`) existent déjà et fonctionnent. CONTEXT locked : `integration_test/` directory (norme Flutter).
   - What's unclear: Le 4e test `phase_07_navigation_test.dart` est absent. Les 3 existants doivent être **MOVED** (pas copiés) ou **COPIED + old versions deleted** ?
   - Recommendation: `git mv` les 3 existants → `integration_test/`, puis CREATE le 4e. Single commit `test(08-rev): absorb Plan 07-07 integration tests into integration_test/ directory`. Preserve git history via rename detection.

2. **CI job separate vs step inline dans gates**
   - What we know: CONTEXT mentionne `Job CI séparé integration-tests`. ci.yml actuel n'a que gates/android/ios.
   - What's unclear: Si step inline dans gates, budget wall-clock à surveiller. Si job séparé, need `needs: gates` + `if:` guard pour on-demand.
   - Recommendation: Plan 08-04 arbitrer selon wall-clock actuel des 3 tests existants. Si < 60s total, step inline dans gates (feedback rapide). Si > 60s, job séparé on-demand.

3. **Paired tool test path convention**
   - What we know: Phase 06 a `tool/test/check_platform_manifests_test.dart` (précédent Phase 02). Mais Phase 06 avait ALSO `test/tooling/platform_manifests_test.dart` (NOT a paired tool test — a regression guard for manifest entries).
   - What's unclear: Le CONTEXT.md ligne 204 dit `test/tooling/check_style_no_external_url_test.dart`. Mais Phase 02 convention = `tool/test/`.
   - Recommendation: Plan 08-04 respecte convention Phase 02 : `tool/test/check_style_no_external_url_test.dart` (auto-discovered par CI step `dart test tool/test/`). Mais si CONTEXT user explicit `test/tooling/`, respect that. Noter potentiel fix-loop item si divergence.

4. **Soak scenarios 7 + 8 file location**
   - What we know: CONTEXT : "2 edge cases additionnels ... à ajouter dans le fichier soak existant Plan 07-04 (`test/infrastructure/downloads/pmtiles_download_soak_test.dart` ou équivalent)". Le directory actuel a `test/infrastructure/downloads/download_soak_test.dart` (verified — ls shows it).
   - What's unclear: Ajouter dans le fichier existant vs nouveau fichier ?
   - Recommendation: Add to existing `test/infrastructure/downloads/download_soak_test.dart` (préserver 8 scenarios single-file). Same `@Tags(['soak'])` discipline. Plan 08-04 commit line `test(08-rev): add 2 soak edge cases (corrupt chunk mid-stream + rename target exists)`.

5. **7 screenshots actual file existence**
   - What we know: CONTEXT mentionne 7 screenshots : `android-01..05` + `ios-01, ios-02`.
   - What's unclear: Présence physique des fichiers dans `docs/phase-07-smoke-screenshots/` — CONTEXT assume existence mais Plan 08-02 doit verify.
   - Recommendation: Plan 08-02 Task 1 pre-check : `ls docs/phase-07-smoke-screenshots/*.png` ; si gap, commit `docs(08-rev): capture missing smoke screenshot` (but CONTEXT.md decision is "pas de fresh walk" — so if screenshots missing, user must provide or §1b degrades to "evidence-partial" with notation).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter SDK test (3.41.5) + integration_test (SDK bundled) + dart test (package:test 1.30.0) |
| Config file | `dart_test.yaml` (2 tags : `migration` 2x timeout + `soak` 10x timeout) |
| Quick run command | `flutter test --exclude-tags=soak,integration` (CI default) |
| Full suite command | `flutter test && dart test --tags soak test/infrastructure/downloads/download_soak_test.dart && flutter test integration_test/` |
| Phase gate | Full suite green before `/gsd:verify-work` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MAP-01 | Zero network for tiles (airplane mode) | integration | `flutter test integration_test/airplane_mode_test.dart` | ⚠️ Existing at `test/phase_07_integration/` — Plan 08-04 MOVE to `integration_test/` |
| MAP-02 | Map interactive sous le mirk (pan/zoom) | widget | `flutter test test/presentation/screens/map_screen_test.dart` | ✅ Existing (Plan 07-06) |
| MAP-03 | Attribution OSM + Protomaps visible | widget | `flutter test test/presentation/widgets/map_attribution_icon_test.dart` | ✅ Existing (Plan 07-06) |
| MAP-04 | Mirk overlay layer integrated (stub) | unit | `flutter test test/infrastructure/map/style_layer_order_test.dart` | ✅ Existing (Plan 07-01, 07-03) |
| MAP-05 | PmtilesSource local-only + lint | unit+CI | `flutter test test/infrastructure/map/pmtiles_source_test.dart && dart run tool/check_avoid_remote_pmtiles.dart` | ✅ Existing (Plan 07-01, 07-03) |
| MAP-06 | MapView domain-level + lint | unit+CI | `flutter test test/domain/map/map_view_test.dart && dart run tool/check_avoid_maplibre_leak.dart` | ✅ Existing (Plan 07-01, 07-02) |
| MAP-07 | World bundle copy + auto-heal | integration | `flutter test integration_test/first_launch_world_copy_test.dart` | ⚠️ Existing — MOVE per MAP-01 |
| MAP-07 (guard) | World bundle sha256 matches constant | unit (NEW) | `flutter test test/infrastructure/assets/world_bundle_sha256_test.dart` | ❌ Wave 0 (Plan 08-04) |
| MAP-08 | Download screen + catalog.json | widget+integration | `flutter test test/presentation/screens/maps_download_screen_test.dart integration_test/map_end_to_end_test.dart` | ✅/⚠️ screen test existing, integration MOVE |
| MAP-09 | 7-step atomic protocol (6 + 2 soak) | unit+soak | `flutter test test/infrastructure/downloads/ && dart test --tags soak test/infrastructure/downloads/download_soak_test.dart` | ✅/❌ 6 scenarios existing, 2 new Wave 0 |
| MAP-09 (guard) | Manifest atomicity contract | unit (NEW) | `flutter test test/infrastructure/downloads/manifest_atomicity_contract_test.dart` | ❌ Wave 0 (Plan 08-04) |
| MAP-10 | Manage maps + delete + world read-only | widget+integration | `flutter test test/presentation/screens/maps_manage_screen_test.dart integration_test/map_end_to_end_test.dart` | ✅/⚠️ screen test existing, integration MOVE |
| QUAL-05 (subset) | Airplane mode zero tile HTTP | integration | See MAP-01 | ⚠️ MOVE |
| Phase 08 meta | No HTTP in unit tests (regression scan) | unit (NEW) | `flutter test test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` | ❌ Wave 0 (Plan 08-04) |
| Phase 08 meta | style.json zero external URL | CI (NEW) | `dart run tool/check_style_no_external_url.dart` | ❌ Wave 0 (Plan 08-04) |
| Phase 08 meta | Adversarial style.json external URL caught by gate | adversarial CI | `git push origin adversarial/08-style-external-url` → CI red exit 1 | ❌ Wave 0 (Plan 08-04) |
| Phase 08 routing | Router 5 new routes + back-nav + deep-link | integration | `flutter test integration_test/phase_07_navigation_test.dart` | ❌ Wave 0 (Plan 08-04 NEW file) |

### Sampling Rate

- **Per task commit:** `flutter test test/... --exclude-tags=soak,integration` (quick suite)
- **Per wave merge:** `flutter test && dart run tool/check_style_no_external_url.dart && dart run tool/check_avoid_maplibre_leak.dart && dart run tool/check_avoid_remote_pmtiles.dart`
- **Per Plan 08-04 push:** Full suite + integration + soak (8 scenarios including 2 new)
- **Phase gate (Plan 08-05 closure):** Full suite green on final commit + ci.yml `gates` + `android` + `ios` all green + adversarial branch deleted local+remote + ROADMAP/REQUIREMENTS amended

### Wave 0 Gaps (files to create Plan 08-04)

**Integration tests (MOVE + 1 new) :**
- [ ] `integration_test/airplane_mode_test.dart` — git mv from `test/phase_07_integration/` + add inertness guards per §4 Test #1 contract
- [ ] `integration_test/first_launch_world_copy_test.dart` — git mv + inertness guards per §4 Test #2
- [ ] `integration_test/map_end_to_end_test.dart` — git mv + inertness guards per §4 Test #3
- [ ] `integration_test/phase_07_navigation_test.dart` — **NEW** per §4 Test #4 (absent du current disk — router 5 new routes + back-nav + deep-links)

**Permanent unit tests (3 new) :**
- [ ] `test/infrastructure/assets/world_bundle_sha256_test.dart` — recompute sha256 via `sha256.bind(file.openRead()).first` + assert = `kWorldBundleSha256` + inertness guard (file existe + size > 0). §4 Test #5. Directory `test/infrastructure/assets/` **doesn't exist** → create.
- [ ] `test/infrastructure/downloads/manifest_atomicity_contract_test.dart` — inject FS fake throwing at 4 points (before tempfile, during tempfile write, after tempfile write, during rename) + assert post-throw file state soit inchangé soit totalement updated. §4 Test #6. Directory `test/infrastructure/downloads/` existe.
- [ ] `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` — pure-Dart scan `test/` (hors `integration_test/` + `@Tags(['integration'])`) + regex `HttpClient()` / `http.Client()` / `Dio()` (exclude imports de fakes) + inertness pre-assert scan a visité ≥ N fichiers. §4 Test #7. Directory `test/infrastructure/network/` **doesn't exist** → create.

**CI gate + paired test (1 new) :**
- [ ] `tool/check_style_no_external_url.dart` — per Pattern 3 ci-dessus, ~80 LoC
- [ ] `tool/test/check_style_no_external_url_test.dart` — 7 scenarios (6 ci-dessus + 1 integration check sur production style.json)
- [ ] `.github/workflows/ci.yml` amendment — new step `Check style no external URL` après `Check avoid_remote_pmtiles`

**Adversarial branch (1) :**
- [ ] `adversarial/08-style-external-url` — poison style.json + inline on.push.branches expansion + push → observe CI red exit 1 → archive run URL + stderr → delete branch

**Soak edge cases (2) :**
- [ ] Add 2 scenarios to `test/infrastructure/downloads/download_soak_test.dart` : (a) corrupt chunk mid-stream + (b) rename target already exists. Each `@Tags(['soak'])`.

**Documentation (4 files) :**
- [ ] `.planning/phases/08-review-gate-map/08-REVIEW.md` — 5-section skeleton Plan 08-01
- [ ] `.planning/phases/07-map-integration/07-07-SUMMARY.md` — Plan 08-01 captures scope-reduction rationale
- [ ] `.planning/phases/07-map-integration/07-07-integration-verification-PLAN.md` — header annotation (edit, not create)
- [ ] `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md` — amendments (Plan 08-01)

**Existing test infrastructure (verified 2026-04-23) :**
- `test/` root: 85+ test files organized by layer (domain/ / infrastructure/{db,downloads,gps,ids,installed_maps,map,mirk,notifications,platform,stores} / application/{controllers,permissions,providers,settings} / presentation/{screens,widgets} / tooling / phase_07_integration / fakes)
- `tool/test/`: 9 paired tool tests — `check_platform_manifests_test.dart` precedent + existing Phase 07 `check_avoid_maplibre_leak_test.dart` + `check_avoid_remote_pmtiles_test.dart`
- `dart_test.yaml`: 2 tags (migration 2x + soak 10x). Plan 08-04 may ADD `integration` tag declaration or rely on `@Tags(['integration'])` inline.
- `integration_test: sdk: flutter` — already dev_dependency ligne 93

### Inertness Guard Pattern Canonical Example (Phase 04 Test #3 verbatim)

**Source :** `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart:95-106` (référence Phase 04, re-used Phase 06 Tests #1-5).

```dart
// Intermediate sanity expect BEFORE the main expect — proves the adversary actually ran.
// Without this guard, future refactors silently neutralize the test
// (e.g. changing DELETE WHERE 1=0 → passes vacuously).

// Inertness guard: confirm the DELETE actually removed rows
expect(
  after['t_sessions']! < before['t_sessions']!,
  isTrue,
  reason:
      'adversarial DELETE did not remove any session row — '
      'test would be inert. before=${before['t_sessions']} '
      'after=${after['t_sessions']}',
);

// THEN the main assert (regression guard)
expect(
  () => sanity.assertNoLoss(before, after),
  throwsA(isA<MigrationFailureException>()
    .having((e) => e.message, 'message', contains('row loss'))),
);
```

**Phase 06 variant (file-existence) :** see Pattern 2 ci-dessus.

**Mutation experiment protocol (validation at author-time) :**
1. Author writes test + inertness guard + main assertion
2. Author intentionally breaks the inertness precondition (e.g. make fake FS reject all writes ; rename a required source path ; comment out the adversary step)
3. Run test — MUST fail LOUDLY with inertness `reason` message, NOT silently pass
4. Restore — test green again
5. Document mutation experiment in §4 Test block ("Mutation experiment (author-time):")

This is the canonical Phase 06 + Phase 04 convention — Phase 08 applies to all 7 new tests (4 integration + 3 permanent unit).

### Validation Architecture : Success Criteria → Evidence Mapping

Phase 08 ROADMAP SC#1-5 (from ROADMAP.md Phase 08 Goal + SC#1-5) :

| SC | ROADMAP statement (abridged) | Evidence proving it | Sub-agent lens | Inertness guard | Fallback |
|----|------------------------------|---------------------|----------------|-----------------|----------|
| **SC#1 Airplane-mode zero tile network** | Test confirms zero HTTP for tiles (pan/zoom/country-swap) ; only download user-triggered allowed (catalog bundled asset) | (a) `integration_test/airplane_mode_test.dart` green ; (b) `tool/check_avoid_remote_pmtiles.dart` exit 0 on final commit ; (c) `tool/check_avoid_maplibre_leak.dart` exit 0 ; (d) §1b extraction `docs/phase-07-smoke.md` Android step 6 + iOS step 6 (airplane mode cold-start PASS) | Agent #1 (seam purity) + Agent #3 (UI no-promise-background) | `_FailAllHttpClient.invocationCount == 0` AFTER pre-assert `FakeMapView.showMapInvocations.isNotEmpty` (proves pump actually exercised showMap path, not just bail-early) | If ambiguous: `tool/check_style_no_external_url.dart` green on final (triple-lock: Dart import scan + pmtiles scheme scan + style.json URL scan) |
| **SC#2 PmtilesSource seam + CountryResolver edge cases** | No remote impl exists (`avoid_remote_pmtiles` blocks) ; resolver handles frontier / zoom world-only / untethered country → world fallback transparent | (a) `tool/check_avoid_remote_pmtiles.dart` exit 0 + adversarial branch `adversarial/08-style-external-url` CI red exit 1 (proves gate works) ; (b) `test/infrastructure/map/country_resolver_test.dart` covers edge cases (frontier / zoom world-only / uninstalled fallback / polygon simplification) ; (c) Agent #1 code review seam purity | Agent #1 (seam + resolver edge cases) ; pre-class item #9 Should-if-findings-else-Noted | `adversarial/08-style-external-url` CI run URL + stderr exit 1 (proves not exit 2 misconfig — real violation caught) | If CountryResolver edge cases gap surfaces: fix-loop Plan 08-05 adds missing tests + bumps severity to Should |
| **SC#3 Soak interruption at each step → coherent state** | Download kill à chaque étape (chunk N / concat / sha256 / rename) = complete OR absent, never partial ; staging nettoyé sur abandon explicite | (a) `dart test --tags soak test/infrastructure/downloads/download_soak_test.dart` all 8 scenarios green (6 existing Plan 07-04 + 2 new Plan 08-04: corrupt chunk mid-stream + rename target already exists) ; (b) `integration_test/map_end_to_end_test.dart` download happy path ; (c) `test/infrastructure/downloads/manifest_atomicity_contract_test.dart` contract-level FS-fake-injection | Agent #2 (download pipeline + atomicity) | 8 soak scenarios each with pre-assert "FakeHttpServer recordedRequests.isNotEmpty" + post-assert "country .pmtiles absent OR complete" ; manifest test has pre-assert "fake FS received ≥ 1 write before throw" | If soak scenario reveals partial state possible: **Blocker** fix-loop (can't ship atomic-rename violation). pmtiles-heal path in FirstLaunchBootstrap (pre-class #5) is the recovery mechanism — verify it covers new scenario. |
| **SC#4 User-first review protocol applied** | User d'abord + titres + explications courtes (CLAUDE.md §Code Review Phases) | (a) Plan 08-01 Task 2 checkpoint:human-verify gate — §1 captured verbatim BEFORE any agent spawn (commit hash on main pre-08-03) ; (b) 4 sub-agents spawned in ONE tool-use message (single Task tool call block Plan 08-03) ; (c) §3 triage table format respects "titles + 1-line explanation" — no diffs in findings surface, user chooses fix/waive/defer per row | Protocol enforced by Plan 08-01 + Plan 08-03 structure (not an Agent lens — structural gate) | `grep -q 'awaiting user input' 08-REVIEW.md` fails after Plan 08-01 Task 2 (§1 populated) ; `git log --oneline -- 08-REVIEW.md` shows capture commit BEFORE first Task tool call commit | N/A — protocol violation = Plan 08-01 revert + re-run |
| **SC#5 Fixes integrated before Phase 09 unblock** | All Blocker fixed + Should fixed-or-waived + CI green on final main commit | (a) Plan 08-05 fix-loop atomic commits (OR batched if user approves) each CI-green before next push ; (b) §5 populated with final commit hash + CI run URL + date + status "all jobs green" ; (c) `gsd-verifier` grep `^## [1-5]\.` returns 5 ; (d) ROADMAP Phase 07 → 7/7 Complete + Phase 08 → completed 2026-04-XX ; (e) REQUIREMENTS MAP-05/06/07/08/10 → Complete ; (f) `07-07-SUMMARY.md` exists ; (g) `tool/check_style_no_external_url.dart` live in CI gates job + green | Gate-closed checklist Plan 08-05 Task 4 | Final commit CI all 3 jobs green (gates + android + ios + integration-tests if added as separate job) ; throwaway branch deleted (`git branch -a \| grep adversarial/08-` empty + `gh api repos/:owner/:repo/branches` empty) | N/A — fail = gate not closed, Phase 09 blocked |

### Validation Architecture : Sub-Agent Lens Coverage Matrix

Map each agent to which SCs they primarily cover + what their smell-heuristics hot-spot is :

| Agent | Primary scope | SC coverage | Smell-heuristics hot-spot | Secondary lens |
|-------|---------------|-------------|---------------------------|----------------|
| **#1 Map infra + seam purity** | lib/domain/map/ + lib/infrastructure/map/ + 2 lint gates | SC#1 (seam) + SC#2 (resolver + PmtilesSource) | StyleRewriter + 2 validators (dispatcher duplication) | `avoid_maplibre_leak` + `avoid_remote_pmtiles` paired tests + style_layer_order regression |
| **#2 Download pipeline + atomicity** | lib/infrastructure/downloads/ + 8 soak + shelf FakeHttpServer | SC#3 (atomic protocol) | PmtilesDownloadController 7-step sealed states (enum candidate "state machine tirée par les cheveux") | 2 new soak edge cases + `manifest_atomicity_contract_test` |
| **#3 Controllers + providers + presentation** | lib/application/ map-related + lib/presentation/ + router + Phase 05 ActiveSessionController legacy | SC#1 (UI no-promise-background) + SC#2 (hot-swap wire) + protocol compliance | MapCameraController follow/pan/iOS-fix (flags booléens accumulés + early returns post-fix) + ActiveSessionController + ActiveSessionState Phase 05 legacy touché 07-05 | `mapViewBuilderForTest` typedef seam compliance + ProviderScope overrides inline + SessionBurgerMenu 3 unwired + 3 live-data rows |
| **#4 Natives + assets + CI gates + CLAUDE.md sweep + smell transverses** | Platform channels + Android INTERNET + assets/maps/ + 4 tool files + DEPENDENCIES.md + §1b POC evidence review | SC#5 (DEPENDENCIES) + §1b evidence + smell transversal | 4 components cross-checked (not a single hot-spot — transversal sweep) | Android BootCompletedReceiver contract (Phase 06 Test #5 precedent) + MethodChannel sync (Phase 06 Test #1 precedent) — may surface new Test #N if drift found |

### Validation Architecture : Adversarial Evidence Trail (§4)

6 evidence blocks in §4 Plan 08-04 :

1. **Test #1 integration_test/airplane_mode_test.dart** — type: permanent regression guard ; commit hash on main ; `flutter test integration_test/airplane_mode_test.dart` output ; behavior proven ; inertness guard quote ; mutation experiment ; confirms SC#1.
2. **Test #2 integration_test/first_launch_world_copy_test.dart** — idem for SC#MAP-07 (3 scenarios A/B/C).
3. **Test #3 integration_test/map_end_to_end_test.dart** — idem for SC#MAP-08/09/10 (full user journey + MockHTTPServer).
4. **Test #4 integration_test/phase_07_navigation_test.dart** — idem for router (5 new routes).
5. **Test #5 test/infrastructure/assets/world_bundle_sha256_test.dart** — idem for world bundle drift detection.
6. **Test #6 test/infrastructure/downloads/manifest_atomicity_contract_test.dart** — idem for SC#3 manifest atomicity.
7. **Test #7 test/infrastructure/network/no_httpclient_in_unit_tests_test.dart** — idem for Phase 08 meta-regression.
8. **Test #8 tool/check_style_no_external_url.dart adversarial CI** — type: throwaway branch ; branch name + poison commit hash + CI trigger commit + CI run URL + gate step name + exit code 1 + stderr excerpt + deletion confirmation local + remote.
9. **Tests #9-10 soak edge cases (corrupt chunk mid-stream + rename target exists)** — type: permanent regression guards ; each appended to existing `test/infrastructure/downloads/download_soak_test.dart` ; `dart test --tags soak` output ; behavior proven ; confirms SC#3 extension.

## Sources

### Primary (HIGH confidence)

- `.planning/phases/08-review-gate-map/08-CONTEXT.md` — primary decision source (384 lines, all sections locked by user)
- `.planning/phases/06-review-gate-gps/06-REVIEW.md` — template exemplar, direct reuse
- `.planning/phases/06-review-gate-gps/06-01-PLAN.md` + `06-04-PLAN.md` — plan structure template
- `.planning/phases/04-review-gate-persistence/04-REVIEW.md` — batched fix-loop precedent + inertness guard canonical
- `.planning/phases/02-review-gate-foundation/02-REVIEW.md` — 5-section contract origin
- `.planning/REQUIREMENTS.md` — MAP-05/06/07/08/10 status "In Progress" → Complete (Plan 08-01 amend target)
- `.planning/ROADMAP.md` — Phase 07 → 7/7 + Phase 08 section
- `CLAUDE.md` §Code Review Phases + §En review faire attention à — nouveaux patterns 2026-04-23
- `.planning/phases/07-map-integration/07-07-integration-verification-PLAN.md` — Plan 07-07 scope (absorbed)
- `docs/phase-07-smoke.md` — smoke evidence primary source §1b (Android PASS + iOS PASS-with-caveat)
- `docs/phase-07-ios-animate-camera-crash.md` — iOS fix evidence §1b (4 tentatives, Tentative 4 validated commit `40b49d5`)
- `tool/check_avoid_remote_pmtiles.dart` — template for `check_style_no_external_url.dart`
- `tool/check_platform_manifests.dart` — Phase 06 gate precedent
- `.github/workflows/ci.yml` — current gates job structure
- `test/phase_07_integration/airplane_mode_test.dart` + 2 autres — existing integration tests to MOVE
- `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart:95-106` — inertness guard canonical reference
- `pubspec.yaml` ligne 93 — `integration_test: sdk: flutter` already dev_dependency
- `dart_test.yaml` — `migration` + `soak` tags declared
- `lib/application/controllers/map_camera_controller.dart` — Agent #3 smell-heuristics hot-spot verified (file exists)
- `lib/infrastructure/downloads/pmtiles_download_controller.dart` — Agent #2 smell-heuristics hot-spot verified (file exists)
- `lib/infrastructure/map/style_rewriter.dart` — Agent #1 smell-heuristics hot-spot verified
- `assets/maps/style.json` — target of `check_style_no_external_url.dart` ; already uses `pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER` (clean baseline)

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` (L1-323) — Accumulated Decisions Phase 02/04/06/07 patterns, Key Decisions
- `.planning/phases/07-map-integration/07-07-integration-verification-PLAN.md` sc_task_crosswalk table — SC#1..SC#9 mapping
- Phase 07 code directory tree (`lib/domain/map/`, `lib/infrastructure/map/`, `lib/infrastructure/downloads/`, `lib/application/`, `lib/presentation/`, `tool/`, `assets/maps/`) — verified via ls

### Tertiary (LOW confidence — user clarification may be needed)

- **Exact wall-clock budget for integration_test/ job** — Plan 08-04 empirical measurement required
- **Screenshot file existence in `docs/phase-07-smoke-screenshots/`** — Plan 08-02 pre-check required
- **`tool/test/` vs `test/tooling/` path for paired tool test** — Plan 08-04 must decide + document

## Metadata

**Confidence breakdown:**
- Template reuse (5-section REVIEW.md + 4 agents + adversarial wave + fix loop + protocol): **HIGH** — Phase 02/04/06 precedent verified, zero unknowns
- Hybrid layer+risk slicing: **HIGH** — CONTEXT locked, agent scopes explicitly enumerated
- Cross-cutting smell-heuristics: **HIGH** — CLAUDE.md delta 2026-04-23 verified inline in file, CONTEXT locks the encoding mechanism
- §1b POC evidence review (no fresh walk): **HIGH** — Phase 06 precedent + smoke+fix convergent 2026-04-21/22 verified
- Integration test absorption from Plan 07-07: **HIGH** — 3 tests already exist at `test/phase_07_integration/`, MOVE is a straightforward git-rename operation
- `check_style_no_external_url.dart` contract: **HIGH** — `check_avoid_remote_pmtiles.dart` template is directly adaptable (same exit-code contract, same JSON-scanning pattern)
- Adversarial branch workflow: **HIGH** — Phase 02/04/06 precedent verified, specific poison target (style.json URL field) is trivially deterministic
- Inertness guard pattern: **HIGH** — Phase 04 Test #3 canonical + Phase 06 Tests #1-5 multiplied precedent
- CI job integration vs step inline: **MEDIUM** — Claude's discretion area, wall-clock budget arbitration needed
- Soak 2 new edge cases exact scenario definitions: **MEDIUM** — Claude's discretion area per CONTEXT

**Research date:** 2026-04-23
**Valid until:** 2026-05-23 (stable, no upstream dependency change expected in 30 days)

---

*Phase: 08-review-gate-map*
*Research written: 2026-04-23*
