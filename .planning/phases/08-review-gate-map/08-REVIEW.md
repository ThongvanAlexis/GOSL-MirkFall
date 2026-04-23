# Phase 08: Review Gate — Map Review

**Opened:** 2026-04-23
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude reads any POC artefact and BEFORE Claude spawns any audit sub-agent.*

*Aucune observation utilisateur — l'user n'a pas identifié de point à revoir dans son IDE.*

(User response 2026-04-23: "rien vu". Phase 04 + Phase 06 precedent applied : explicit no-findings marker committed before §1b / §2 / §3 / §4 / §5 unblock.)

### 1b. POC evidence review

*Filled by Plan 08-02 after extracting `docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots at `docs/phase-07-smoke-screenshots/`. Replaces the "Runtime walk" sub-heading from Phase 04 §1b — user decision 2026-04-23 (CONTEXT §POC / runtime evidence review §1b — no fresh walk): smoke 2026-04-21 + fix iOS 2026-04-22 convergent, re-smoke rejected.*

<details>
<summary>Android Pixel 4a — PASS 2026-04-21</summary>
(pending — filled by Plan 08-02)
</details>

<details>
<summary>iOS iPhone 17 Pro — PASS post-fix 2026-04-22</summary>
(pending — filled by Plan 08-02; MUST include commits 81d30c7 + ab497ab + 40b49d5 + stack .ips extract + bisection table)
</details>

**Airplane-mode evidence snapshot:** *(pending — filled by Plan 08-02 from docs/phase-07-smoke.md Android step 6 + iOS step 6)*

## 2. Claude audit findings

*Filled by Plan 08-03: first the 10 pre-classified CONTEXT handoff items + the Smell heuristics hot-spots table, then the 4 parallel sub-agents in ONE tool-use message (hybrid layer+risk slicing per CONTEXT).*

Format: `[severity] Title — 1-line explanation — file:line`. Severities: Blocker / Should / Could / Noted. Smell-tagged findings get an inline `[smell:fix-on-fix]` or `[smell:over-state-machine]` tag after severity.

### Pre-known from CONTEXT

*Filled by Plan 08-03 Task 1 BEFORE spawning sub-agents. Source: 08-CONTEXT.md §Implementation Decisions / §2 pre-class items (10 items). Committed as `docs(08-rev): pre-class 10 CONTEXT handoff items into §2` before any Agent tool call.*

(pending — 10 entries: water filter Noted | background V2 Noted | iOS animateCamera fix Noted | Plan 07-07 absorbed Should | pmtiles-heal Noted | smell category inline | ROADMAP+REQ sync Should | tool simplify/generate Could-or-Noted | CountryResolver edges Should-if-findings-else-Noted | DEPENDENCIES Noted)

### Smell heuristics hot-spots

*Filled by Plan 08-03 Task 1 alongside pre-class items. Source: 08-CONTEXT.md §Cross-cutting smell-heuristics from CLAUDE.md §En review faire attention à (2026-04-23 delta).*

| Component | File path | Primary Agent | Smell pattern to look for |
|-----------|-----------|---------------|---------------------------|
| (pending — 4 rows) | | | |

### Agent #1 — Map infra + seam purity
*Scope: `lib/domain/map/` + `lib/infrastructure/map/` + `tool/check_avoid_maplibre_leak.dart` + `tool/check_avoid_remote_pmtiles.dart` + paired tests. Hot-spot: StyleRewriter + 2 validators.*
(pending)

### Agent #2 — Download pipeline + atomicity
*Scope: `lib/infrastructure/downloads/` + 6 existing soak + shelf-backed FakeHttpServer. Hot-spot: PmtilesDownloadController 7-step sealed states.*
(pending)

### Agent #3 — Controllers + providers + presentation
*Scope: `lib/application/` map-related + `lib/presentation/` map screens/widgets + router deltas + Phase 05 ActiveSessionController legacy. Hot-spots: MapCameraController follow/pan/iOS-fix + ActiveSessionController.*
(pending)

### Agent #4 — Natives + assets + CI gates + DEPENDENCIES.md + CLAUDE.md sweep + smell transverses
*Scope: platform channels (Kotlin + Swift) + Android INTERNET + `assets/maps/` + 4 tool files + `DEPENDENCIES.md` deltas + CLAUDE.md anti-patterns sweep + transversal smell lens.*
(pending)

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>
(pending)
</details>

## 3. Triage decisions

*Filled by Plan 08-03 Task 5 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden per CONTEXT.md). Every Should MUST be either `fix` or `waived` with inline rationale. Smell-tagged findings get an explicit decision (fix / refactor / defer) visible in the table.*

| # | Finding | Severity | Smell tag | Decision | Rationale | Commit hash |
|---|---------|----------|-----------|----------|-----------|-------------|
| (pending) | | | | | | |

## 4. Adversarial evidence

*Filled by Plan 08-04. Seven permanent-test evidence blocks (Tests #1-#7: 4 integration tests MOVE+NEW + 3 permanent unit tests) + one adversarial CI evidence block (Test #8 — throwaway branch `adversarial/08-style-external-url` exercising `tool/check_style_no_external_url.dart`) + two soak edge case evidence blocks (Tests #9-#10 — corrupt chunk mid-stream + rename target already exists appended to existing `test/infrastructure/downloads/download_soak_test.dart`).*

### Test 1: integration_test/airplane_mode_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/airplane_mode_test.dart` → `integration_test/airplane_mode_test.dart`, add `@Tags(['integration'])`, add inertness guard (pre-assert `FakeMapView.showMapInvocations.isNotEmpty` before asserting `_FailAllHttpClient.invocationCount == 0`). Covers MAP-01 subset of QUAL-05.*

(pending)

### Test 2: integration_test/first_launch_world_copy_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/first_launch_world_copy_test.dart` → `integration_test/first_launch_world_copy_test.dart`, add inertness guards per §4 Test #2 contract. Covers MAP-07 + auto-heal (scenarios A/B/C).*

(pending)

### Test 3: integration_test/map_end_to_end_test.dart (MOVE + inertness guards)
*`git mv` from `test/phase_07_integration/map_end_to_end_test.dart` → `integration_test/map_end_to_end_test.dart`, add inertness guards. Covers MAP-08/09/10 full user journey (download + display + delete + fallback).*

(pending)

### Test 4: integration_test/phase_07_navigation_test.dart (NEW)
*Brand-new file. Covers router 5 new routes + back-navigation + deep-links for Phase 07 screens (/map + /maps-download + /maps-manage + /style-import + /style-export). Inertness guard: pre-assert GoRouter received push/go events AND screens emitted a build().*

(pending)

### Test 5: test/infrastructure/assets/world_bundle_sha256_test.dart (NEW permanent unit test)
*Recompute sha256 of `assets/maps/world.pmtiles` via `crypto sha256.bind` streaming + assert equal to `kWorldBundleSha256` constant. Inertness guard: file exists + size > 0. Protects against asset-change-without-constant-update silent drift.*

(pending)

### Test 6: test/infrastructure/downloads/manifest_atomicity_contract_test.dart (NEW permanent unit test)
*Inject FS fake throwing at 4 points (before tempfile, during tempfile write, after tempfile write, during rename) + assert post-throw file state is either unchanged or totally updated. Inertness guard: fake FS received ≥ 1 write before throw. Complements the 6 soak scenarios with a narrow repo-level contract.*

(pending)

### Test 7: test/infrastructure/network/no_httpclient_in_unit_tests_test.dart (NEW permanent unit test)
*Pure-Dart scan `test/` (exclude `integration_test/` + files with `@Tags(['integration'])`) for `HttpClient()` / `http.Client()` / `Dio()` patterns. Inertness guard: scan visited ≥ N files. Protects against unit tests silently acquiring real network.*

(pending)

### Test 8: tool/check_style_no_external_url.dart adversarial CI run (throwaway branch adversarial/08-style-external-url)
*Branch `adversarial/08-style-external-url`: poison commit injects `"url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"` into `assets/maps/style.json`. CI step `Check style no external URL` (added to `.github/workflows/ci.yml` `gates` job in Plan 08-04) MUST fail with exit 1 and stderr identifying the file path + JSON path + offending URL. Branch deleted local + remote post-archivage; main `on.push.branches` stays `[main]`-only.*

(pending)

### Tests 9-10: 2 new soak edge cases (appended to existing download_soak_test.dart)
*Test #9: corrupt chunk mid-stream (chunk #3 of 5 returns sha256-mismatch payload — assert staging cleaned, state=failed-with-retry, `.pmtiles` cible absent). Test #10: rename target already exists (simulate retry where cible `.pmtiles` already present — assert AtomicRenamer gère correctement per contract, zero manifest leak). Both `@Tags(['soak'])`. Covers SC#3 extension beyond the 6 existing scenarios.*

(pending)

## 5. CI-green confirmation

*Filled by Plan 08-05 Task 3 after all Blocker + non-waived Should fixes are applied and CI is green.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending — all 3 jobs gates+android+ios green, optionally integration-tests)
- **Date:** (pending)

---
_Phase 08 closed: (pending)_
_Phase 09 unblocked._
