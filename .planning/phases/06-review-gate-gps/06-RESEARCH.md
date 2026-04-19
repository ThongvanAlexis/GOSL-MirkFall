# Phase 06: Review Gate — GPS - Research

**Researched:** 2026-04-20
**Domain:** Solo-dev review-gate audit of Phase 05 GPS & Session Lifecycle artefacts (4-agent layer-sliced parallel audit + 5 permanent unit tests + 1 new CI gate + 1 throwaway adversarial branch + POC evidence review replacing fresh runtime walk)
**Confidence:** HIGH (CONTEXT.md is exceptionally detailed; Phase 02 + 04 templates locked; all referenced files verified on disk; package:xml + plist_parser licenses verified MIT on pub.dev; ci.yml current state read line-by-line)

## Summary

Phase 06 is the **third application** of the locked review-gate template (Phases 02 + 04 → 06), with three deliberate divergences captured by `06-CONTEXT.md`:

1. **POC evidence review (§1b) REPLACES the fresh runtime walk.** User decision 2026-04-20: the Phase 05 Pixel 4a 28.6 min walk + iPhone 17 Pro 13.5 min walk in `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png` ARE the runtime observation. No `flutter run -d windows` walk this gate. Agent #4 reads those artefacts and inlines extracts into §1b.
2. **8 pre-class items in §2 (vs 3 in Phase 04, 0 in Phase 02).** The Phase 05 handoff is dense: iOS PASS-with-caveat, artefact-location drift, battery waiver, OEM/Xiaomi/Huawei/Samsung/OnePlus deferral, auto-resume-iOS deferral, store-rationale-EN deferral, flaky-pumpAndSettle watch, dart-format-drift watch.
3. **5 permanent unit tests + 1 new CI gate script + 1 throwaway adversarial branch (vs Phase 02's 3 throwaway, Phase 04's 2 throwaway + 1 unit).** Phase 06 leans hard on permanent regression guards because the Phase 05 surface is largely runtime code (MethodChannel triple-source, OEM detection regex, permission cascade, BootCompletedReceiver contract, platform manifest entries) that benefits more from in-repo permanent tests than throwaway poison branches.

The 4 sub-agents are sliced by **layer** (not by concern as Phase 02): Agent #1 GPS infra + notifications + Drift V3 + permissions/manifest, Agent #2 controller + permissions Dart + Riverpod state, Agent #3 UI + routing + banner widget, Agent #4 boot watchdog + native bridges Kotlin/Swift + POC tooling + CLAUDE.md sweep. All 4 are `general-purpose` per locked rule. Spawned in **one** tool-use message after user IDE input + POC evidence review + 8 pre-class items committed to §2.

**Primary recommendation:** Plan Phase 06 as 4–5 plans following the Phase 04 wave layout (scaffold+§1 → POC review §1b → pre-class §2 → 4-agent audit + 5 unit tests + 1 CI gate script → adversarial CI run → fix loop + closure). Use `package:xml 6.6.1` (MIT) for AndroidManifest.xml parsing in Test #4 + `tool/check_platform_manifests.dart` (already audited indirectly via Phase 02's `check_*` script family pattern). Skip `package:plist_parser` (unverified-publisher MIT — risk: surface tiny enough that pure-Dart regex is preferable for 4 Info.plist string keys). Re-add `'adversarial/**'` to `.github/workflows/ci.yml` `on.push.branches` inline on the throwaway branch (Phase 02 + 04 precedent — currently `branches: [main]`-only).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Sub-agent slicing: 4 agents, layer-based** — Agent #1 GPS infra + notifications + Drift V3 + AndroidManifest + Info.plist + `lib/domain/gps/`; Agent #2 controller + permissions + Riverpod state; Agent #3 UI + routing + banner; Agent #4 boot watchdog + native bridges + POC tooling + CLAUDE.md sweep + pubspec deltas + DEPENDENCIES.md.
- **Audit depth: exhaustive file-by-file** on every Phase 05 artefact under `lib/domain/sessions/`, `lib/domain/gps/`, `lib/infrastructure/gps/`, `lib/infrastructure/notifications/`, `lib/infrastructure/platform/`, `lib/application/permissions/`, `lib/application/controllers/`, `lib/application/providers/`, `lib/presentation/screens/` Phase 05 screens, `lib/presentation/widgets/active_session_banner.dart`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/.../BootCompletedReceiver.kt`, `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`, `test/**` Phase 05 dirs, `tool/plot_session_fixes.py`, `tool/requirements.txt`, `docs/store-review-rationale.md`, `docs/qual-01-02-poc.md`, `docs/poc-artifacts/`, `pubspec.yaml` deltas Phase 05, `DEPENDENCIES.md` entries Phase 05. ~90–120 `.dart` + ~50–70 test files + 3 native bridges (Kotlin + Swift + Info.plist) + 2 POC docs + 1 Python tool. Charge supérieure à Phase 04.
- **POC evidence acceptance pre-class (§2 items 1–8)**:
  1. iOS walk 13.5 min vs 30 min target — **Noted** (PASS-with-caveat accepted; Phase 06 closes without re-walk; Phase 15 optional top-up if user wants).
  2. POC artefact-location drift (SC#1 says `.planning/pocs/phase-05/`, actual lives in `docs/qual-01-02-poc.md` + `docs/poc-artifacts/`) — **Should** (fix in loop: amend ROADMAP.md SC#1 via `docs(06-rev):` commit).
  3. SC#2 battery measurement < 15 %/h waiver — **Noted** (extract from POC if present, else inline waiver with fix-cadence proxy argument; full dumpsys → Phase 15).
  4. Xiaomi / Samsung / Huawei / OnePlus OEM coverage deferred — **Noted** (already accepted Phase 05 planning; ROADMAP SC#1 annotated "partial").
  5. Auto-resume-post-kill iOS unvalidated (FlutterImplicitEngineDelegate stripped Xcode 26) — **Noted** (Android covered by 4 BootCompletedWatchdog unit tests + Plan 05-05; iOS rewire Phase 15).
  6. Store rationale English copy final polish — **Noted** (French defended-by-reviewer-quality; English Phase 15 polish).
  7. Flaky widget-test pumpAndSettle races (if re-surface during audit) — **Should** (pre-flag known-pattern; agents may find more or confirm none).
  8. dart format drift regression watch — **Noted** (monitor; CI gate `--set-exit-if-changed` active since Plan 04-05; Agent #4 confirms zero drift; if drift found, becomes Should fix in loop).
- **SC#4 OEM workaround gate-closure**: `§2 OEM workaround plan` table in 06-REVIEW.md listing OemFamily variant → OemGuidanceScreen copy summary → dontkillmyapp.com URL → openLocationSettings reachability → pre-class severity. Linked to `docs/store-review-rationale.md` if content overlap. Self-contained future-maintainer baseline.
- **Adversarial wave: 4 permanent unit tests + 1 new CI gate + 1 adversarial throwaway branch**:
  - Test #1 — MethodChannel triple-source drift regression guard (`test/infrastructure/boot_watchdog/method_channel_sync_test.dart`, scans Kotlin + Swift + Dart for `'app.gosl.mirkfall/boot_watchdog'`, intermediate inertness assertion that all 3 files exist on disk).
  - Test #2 — Permission-denied cascade regression guard (`test/application/permissions/location_permission_cascade_test.dart`, 4 scenarios: denied → permanentlyDenied → restricted at each stage with `PermissionRequester` fake capturing invocations + intermediate expect on N invocations).
  - Test #3 — OemDetector ambiguous match regression guard (`test/infrastructure/platform/oem_detector_ambiguous_test.dart`, 3-5 fixtures of ambiguous `manufacturer`+`brand` pairs; assert deterministic OemFamily resolution; intermediate expect that the fake was consumed).
  - Test #4 — Platform manifest drift regression guard (`test/tooling/platform_manifests_test.dart`, parse XML + plist, assert all required entries present; intermediate expect that the 2 files exist + parse OK).
  - Test #5 — Android BootCompletedReceiver contract test (`test/infrastructure/boot_watchdog/android_boot_receiver_contract_test.dart`, parse AndroidManifest + grep BootCompletedReceiver.kt + assert MethodChannel literal matches Dart constant; complement to Test #1 scoped Android-only).
  - **`tool/check_platform_manifests.dart`** new CI gate script: same exit-code contract (0/1/2) as Phase 02's `check_*.dart` family; added to `.github/workflows/ci.yml` `gates` job; paired with own unit test `test/tooling/check_platform_manifests_test.dart` covering all 3 exit codes.
  - **Adversarial branch `adversarial/06-manifest-drift`** — single throwaway branch: poison commit removes `ACCESS_BACKGROUND_LOCATION` from AndroidManifest.xml OR removes `UIBackgroundModes location` from Info.plist; CI step `dart run tool/check_platform_manifests.dart` fails exit 1; evidence §4 (branch / commit / run URL / exit code / stderr extract); branch deleted local + remote post-archivage.
- **POC evidence review §1b — no fresh runtime walk** (user decision 2026-04-20): Agent #4 reads `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png` + any other POC artifact committed; extracts inline §1b: Pixel 4a walk summary (342 fixes / 28.6 min / cadence), iPhone 17 Pro walk summary (82 fixes / 13.5 min / cadence), battery deltas if present, store-rationale snapshot, QUAL-03 compliance check; format = collapsible `<details>` markdown sections per device + summary tables.
- **Strict user-first ordering**: user IDE findings → POC evidence review §1b → pre-class §2 → spawn 4 sub-agents in single tool-use message. Parallel-while-typing rejected.
- **Output contract sub-agents**: structured `[severity] Title — 1-line explanation — file:line` + narrative appendix in §"Audit Notes". Severities Blocker / Should / Could / Noted with Phase 02 definitions.
- **All 4 agents `general-purpose`** for wave consistency (locked rule).
- **Atomic commits `fix(06-rev): <title>`** (or `refactor(06-rev):` / `docs(06-rev):` / `test(06-rev):` / `chore(06-rev):`), CI green between each.
- **Batched fix-loop permissible** if user approves at fix-time (Phase 04 Plan 04-05 precedent; user trade-off bisectability-batch vs wall-clock CI).
- **Gate-closed criteria**: all Blockers fixed (no waiver), all Shoulds either fixed or explicitly waived inline §3, CI green on final main commit, 06-REVIEW.md complete with 5 sections, §1b POC extracts, §2 8 pre-class + SC#4 OEM table, §4 adversarial branch CI evidence + 5 unit-test commit hashes + new CI gate script commit, §5 CI-green confirmation. `tool/check_platform_manifests.dart` confirmed green on the final commit.

### Claude's Discretion

- Wave layout of plans Phase 06 (combien de plans, scaffold/POC-review/pre-class/agents/adversarial/fixes — but POC evidence review MUST be a plan or sub-step BEFORE agents; pre-class §2 MUST be committed before agent spawn).
- Format exact of POC evidence inline in REVIEW.md §1b (collapsed `<details>` markdown per device vs flat list vs combined table).
- Order of writing the 5 unit tests adversariaux (parallel vs sequential, single commit vs per-test commit).
- Choice of XML/plist parsing package for Test #4 + `tool/check_platform_manifests.dart` (`package:xml` + `package:plist_parser` if licenses MirkFall-compatible + DEPENDENCIES.md audit OK; else pure-Dart regex).
- Strategy of cleanup of `adversarial/06-manifest-drift` (delete immediate post-archivage vs delete batch end of plan).
- Format exact of §2 OEM workaround plan table (markdown 4-col table vs sections per OemFamily vs hybride).
- Découpage interne d'Agent #4 (CLAUDE.md sweep + POC review + native bridges + tooling — combined or split).
- Re-scope of an agent if user IDE findings flag a specific angle.
- Choice of ambiguous-match fixtures Test #3 (3 minimum, up to 5).
- Format of commit subject line for the 5 unit tests adversariaux (`test(06-rev): add regression guard for X` vs `feat(06-rev): add regression test Y`).

### Deferred Ideas (OUT OF SCOPE)

- **Second iOS POC walk extended to 30 min** — Phase 15 release-confidence optional.
- **"Tracking interrompu on next launch" banner** — Phase 15 SC#4 recovery flow.
- **Native per-OEM battery-settings intent deep-links** (MIUI Security, Huawei PhoneManager, Samsung DeviceCare, OnePlus Battery) — Phase 15 polish; dontkillmyapp.com link suffices V1.0.
- **Full dumpsys battery_stats instrumentation + Python parser** — Phase 15 release-confidence; Phase 06 accepts fix-cadence proxy.
- **Xiaomi / Samsung / Huawei / OnePlus device coverage testing** — Phase 15 release testing.
- **iOS auto-resume-post-kill full validation** — Phase 15 when FlutterImplicitEngineDelegate is rewired.
- **Store rationale English copy finalisation** — Phase 15 polish.
- **Pre-commit hooks (lefthook ou autre)** — rejected Phases 01 / 02 / 04 / 06.
- **Persistent adversarial matrix in `ci.yml`** — non-retained Phases 02 / 04 / 06; consider Phase 16 release audit.
- **Audit exhaustif `pubspec.lock` paquet par paquet (180+ entries)** — replaced by spot-check des deltas Phase 05 in Agent #4.
- **Automatisation du fix des Could / Noted** — pas dans Phase 06.
- **Rapport de stress-test comme artefact permanent séparé** (`docs/guardrail-stress-tests.md`) — non-retained.
- **MPL-unreachable heuristic fix dans `tool/check_licenses.dart`** — Phase 02 backlog résiduel ou Phase 16.
- **Second iOS AppDelegate.swift path via FlutterImplicitEngineDelegate rewire** — Phase 15.
- **ProviderScope + GoRouter navigation test for OEM deep-link UX** — Phase 11 ou 15 (nécessite real device ou Patrol/integration_test).
- **Replace `permission_handler` par implémentation native** — overkill V1.0.
- **GPS battery profiling sur fixture synthetic 30-min mock** — overkill V1.0.

</user_constraints>

<phase_requirements>
## Phase Requirements

Phase 06 is a **review gate** — no formal REQ-IDs (per ROADMAP.md convention "review gates ne possèdent pas de REQ-ID"). Instead, the audit gates the closure of Phase 05's REQ-IDs (SESS-01..05, SESS-07..09, GPS-01..08, QUAL-01..04). Phase 06's own success criteria from ROADMAP.md drive the work:

| ID | Description (from ROADMAP.md Phase 06 SC) | Research Support |
|----|-------------------------------------------|------------------|
| SC#1 | POC artefacts (vidéo ou log extrait) des sessions background 30 min sur Android OEM et iOS sont archivés dans `.planning/pocs/phase-05/` (NOTE: actual location is `docs/qual-01-02-poc.md` + `docs/poc-artifacts/` — Should fix in loop, see §2 pre-class item 2) | §1b POC evidence review extracts inline; §3 fix `docs(06-rev): amend ROADMAP.md SC#1 to match docs/ artifact location` (Should #2) |
| SC#2 | Consommation batterie POC < 15 %/h walking mode avec `distanceFilter` configuré, conforme à mesure référence geolocator | §2 pre-class item 3 (Noted — extract from POC if present, else waive with fix-cadence proxy + defer dumpsys to Phase 15) |
| SC#3 | Protocole review (user d'abord, titres + explications courtes) appliqué | Phase 02 + 04 template — strict user-first ordering, 4-sub-agent wave, single tool-use message, 5-section REVIEW.md §1 captures user IDE findings verbatim or `'Aucune observation utilisateur'` marker |
| SC#4 | Plan de contournement pour OEM les plus agressifs (Xiaomi / Huawei) documenté — deep-links settings, instructions utilisateur, bannière "tracking interrompu" sur prochain launch | §2 OEM workaround plan table (Xiaomi / Samsung / Huawei / OnePlus / OPPO + Other + iOS) sourced from existing `OemGuidanceScreen` + `OemDetector` + `dontkillmyapp.com` URLs + `permission_handler.openAppSettings` deep-link reachability; "tracking interrompu" banner explicitly DEFERRED to Phase 15 (Noted) per CONTEXT.md |
| SC (implicit gate-closed) | Adversarial CI red on platform-manifests-drift + 5 permanent unit tests green + new CI gate script committed + final main CI green + 5 sections complete | Adversarial branch `adversarial/06-manifest-drift` evidence in §4; 5 commit hashes for unit tests in §4; `tool/check_platform_manifests.dart` commit hash + green run; final main commit + run URL §5 |

</phase_requirements>

## Standard Stack

### Core (already in pubspec.yaml — Phase 06 audits / does not bump)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | 3.3.1 | DI + state for ActiveSessionController, providers | Locked Phase 01 D5; Riverpod 3.x AsyncValue.value pattern |
| go_router | 16.0.0 | Routing including ShellRoute + rootNavigatorKey for notification-tap navigation | Locked Phase 01 |
| drift | 2.32.1 | Persistence (V3 schema with t_fixes) | Locked Phase 03 |
| geolocator | 14.0.2 | LocationStream impl (foreground service Android + background iOS) | Locked Phase 05; rejected `flutter_background_geolocation` (paid licence) per STATE.md |
| flutter_local_notifications | 21.0.0 | SessionNotificationService persistent notification | Locked Phase 05; factory-singleton wrapped behind LocalNotificationsPort |
| permission_handler | 12.0.1 | Two-step Android 10+ permission flow + openAppSettings deep-link | Locked Phase 05 |
| device_info_plus | 12.4.0 | OemDetector AndroidDeviceInfo.manufacturer + brand | Locked Phase 05; pinned at 12.4.0 (NOT 13.0.0) due to win32 ^6 conflict with file_picker 11.0.2 |
| share_plus | 12.0.2 | OemGuidanceScreen dontkillmyapp.com link share | Locked Phase 01 |
| logging | 1.3.0 | FileLogger + Logger.root | Locked Phase 01 |

### Phase 06 NEW (audit-time additions for Test #4 + CI gate script)

| Library | Version | Purpose | License | Why Standard |
|---------|---------|---------|---------|--------------|
| xml | 6.6.1 | Parse AndroidManifest.xml for Test #4 + `tool/check_platform_manifests.dart` | MIT (verified pub.dev 2026-04-20, publisher lukas-renggli.ch verified) | Lightweight DOM-based + event-driven; no telemetry; widely-adopted Dart XML parser; depended on transitively by `plist_parser`, `freezed`, `build_runner` chain — already in lock graph |
| **OR pure-Dart regex** | — | Same surface, no new dep | — | Tiny surface (4 keys in Info.plist + ~10 lines in AndroidManifest.xml) — pure regex acceptable per Claude's Discretion |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `package:xml 6.6.1` | Pure-Dart regex on raw file | Regex avoids new dep entirely; XML adds ~50 KB to dev-tooling footprint but gives proper parser semantics. **Recommendation: use `package:xml` for AndroidManifest (already transitive via Drift + Freezed codegen so no new pubspec.lock entry); use pure-Dart regex for Info.plist** (tiny + plist XML edge cases like CDATA in usage descriptions are safe) — minimizes new direct deps |
| `package:plist_parser 0.2.7` | Pure-Dart regex | plist_parser is MIT but **unverified-publisher** (CLAUDE.md §Audit obligatoire requires extra scrutiny on unverified). For ~5 plist string keys (NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, UIBackgroundModes array contains "location") regex is safer. **Recommendation: pure-Dart regex.** |
| New CI gate via `dart run tool/check_platform_manifests.dart` | Inline grep step in `ci.yml` | Inline grep loses exit-code contract clarity (0/1/2) + loses ability to unit-test the gate logic + duplicates Phase 02 pattern. **Recommendation: build the standalone Dart script following Phase 02 family pattern** (same shape as `check_domain_purity.dart` / `check_licenses.dart`) |

**Installation guidance:**

```yaml
# pubspec.yaml — IF using package:xml directly (recommended for Test #4 AndroidManifest parsing)
dev_dependencies:
  xml: 6.6.1   # MIT, lukas-renggli.ch (verified publisher), already transitive — promotion to direct dev_dependency per CLAUDE.md §Pin policy
```

**DEPENDENCIES.md** entry skeleton:

```markdown
| xml | 6.6.1 | MIT | Test/tooling AndroidManifest.xml parser for Phase 06 platform-manifests CI gate. Verified publisher lukas-renggli.ch. Zero network calls. Dev_dependency only — never ships in binary. | 2026-04-20 |
```

If pure-Dart regex chosen, **no new pubspec.yaml or DEPENDENCIES.md entry** required (matches Phase 02 + 04 minimal-dep philosophy).

## Architecture Patterns

### Recommended Phase 06 Plan Layout

Following Phase 04 wave layout (refined from Phase 02's 4-plan template) with one extra plan to absorb the 5 unit tests + CI gate script work:

```
.planning/phases/06-review-gate-gps/
├── 06-CONTEXT.md          # Already exists (gathered 2026-04-20)
├── 06-RESEARCH.md         # This file
├── 06-VALIDATION.md       # Generated downstream by validator
├── 06-01-PLAN.md          # Wave 1: Scaffold 06-REVIEW.md 5-section skeleton + capture user IDE findings into §1
├── 06-02-PLAN.md          # Wave 2: POC evidence review §1b — Agent (or direct) extracts docs/qual-01-02-poc.md + docs/poc-artifacts/* + store-rationale snapshot inline
├── 06-03-PLAN.md          # Wave 3: Pre-class 8 items into §2 (committed BEFORE agent spawn) + spawn 4 parallel general-purpose audit agents in single tool-use message + synthesize findings + user triage into §3
├── 06-04-PLAN.md          # Wave 4: Build 5 permanent unit tests + tool/check_platform_manifests.dart + paired tool unit test + push adversarial/06-manifest-drift branch + observe CI red + archive evidence §4 + delete throwaway branch
├── 06-05-PLAN.md          # Wave 5: Apply atomic fix-loop (per-finding OR batched per user approval) + final main CI green + 06-REVIEW.md status=closed + STATE.md + ROADMAP.md update + Phase 07 unblocked
```

**Sequencing constraints:**
- Plan 06-01 BEFORE Plan 06-02 (skeleton must exist for §1b to write into).
- Plan 06-02 BEFORE Plan 06-03 (user-first → POC review → agent spawn).
- Plan 06-03 pre-class commit BEFORE agent spawn within same plan.
- Plan 06-04 5 unit tests + new CI gate can be written in parallel with adversarial branch poison (independent); CI gate script must land on main BEFORE adversarial branch poison fires (otherwise CI step doesn't exist to fail on the poison).
- Plan 06-05 strictly LAST.

### Pattern 1: 4-Parallel-Sub-Agent Audit Wave (Phase 02 + 04 locked)

**What:** Single tool-use message spawning 4 `general-purpose` Agent calls, each scoped to a layer-slice with concrete file lists + audit lens.
**When to use:** Every review gate. Phase 06 reuses without modification except for the layer-based slicing (Phase 02 was concern-based: CI / bootstrap / quality / tests).
**Source:** `02-CONTEXT.md §Audit methodology`, `04-CONTEXT.md §Sub-agent slicing`, `02-REVIEW.md §2` (concrete output), `04-REVIEW.md §2` (concrete output).

**Agent dispatch pattern (from 02-REVIEW.md / 04-REVIEW.md):**

```
Single message containing 4 Agent tool calls in parallel:
- Agent #1: GPS infra + notifications + permissions + manifest (lib/infrastructure/gps/, lib/infrastructure/notifications/, lib/domain/gps/, AndroidManifest.xml, lib/infrastructure/db/app_database.dart V2→V3 delta)
- Agent #2: Controller + permissions Dart + Riverpod state (lib/application/controllers/, lib/application/permissions/, lib/application/providers/, lib/application/settings/)
- Agent #3: UI + routing + banner widget (lib/presentation/screens/, lib/presentation/widgets/active_session_banner.dart, lib/application/routing/router.dart)
- Agent #4: Boot watchdog + native bridges + POC tooling + CLAUDE.md sweep (lib/infrastructure/platform/boot_completed_watchdog.dart, lib/infrastructure/platform/ios_significant_change_watchdog.dart, BootCompletedReceiver.kt, AppDelegate.swift, Info.plist, tool/plot_session_fixes.py, docs/store-review-rationale.md, docs/qual-01-02-poc.md, pubspec.yaml deltas, DEPENDENCIES.md)
```

Each agent returns:
1. **Structured findings list:** `[severity] Title — 1-line explanation — file:line` (severities: Blocker / Should / Could / Noted).
2. **Narrative appendix:** prose audit report archived in `06-REVIEW.md` `<details><summary>Audit Notes</summary>...</details>` collapsible section.

### Pattern 2: 5-Section REVIEW.md Artifact Contract (Phase 02 locked, gsd-verifier greps)

**What:** Five top-level `## N. Title` markdown headings; gsd-verifier greps `^## [1-5]\.` to confirm presence.
**When to use:** Every review gate.
**Source:** `02-CONTEXT.md §Findings artefact & triage`, `02-REVIEW.md` line headers verified, `04-REVIEW.md` line headers verified.

**Exact heading format (verified verbatim from `02-REVIEW.md` + `04-REVIEW.md` — Phase 06 MUST match):**

```markdown
# Phase 06: Review Gate — GPS Review

**Opened:** 2026-04-XX
**Status:** open|closed
**Closed:** 2026-04-XX

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude's audit.*

### 1b. POC evidence review

[Per Phase 06 — collapsible <details> sections per device + summary tables; replaces "Runtime walk Windows" subheading from Phase 04 §1b]

## 2. Claude audit findings

### Pre-known from CONTEXT (8 items)

[8 pre-class items committed BEFORE agent spawn]

### SC#4 OEM workaround plan

[Markdown table: OemFamily | OemGuidanceScreen copy summary | dontkillmyapp.com URL | openLocationSettings reachability | Pre-class severity]

### Agent #1 — GPS infra + notifications

[Findings list]

### Agent #2 — Controller + permissions + state

[Findings list]

### Agent #3 — UI + routing

[Findings list]

### Agent #4 — Boot watchdog + native bridges + POC tooling

[Findings list]

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>

#### Agent #1 Narrative
...
#### Agent #2 Narrative
...
#### Agent #3 Narrative
...
#### Agent #4 Narrative
...
</details>

## 3. Triage decisions

[Markdown table: # | Finding | Severity | Decision | Rationale | Commit hash]

## 4. Adversarial evidence

### Test 1: MethodChannel triple-source drift regression guard (permanent unit test)
[Test file path | Commit hash | dart test output verbatim | Behavior proven | Inertness guard quote]

### Test 2: Permission cascade regression guard (permanent unit test)
[same shape]

### Test 3: OemDetector ambiguous match regression guard (permanent unit test)
[same shape]

### Test 4: Platform manifest drift regression guard (permanent unit test)
[same shape]

### Test 5: Android BootCompletedReceiver contract test (permanent unit test)
[same shape]

### Test 6: tool/check_platform_manifests.dart adversarial CI run
[Branch name | Poison commit hash | CI-trigger commit hash | Run URL | Job | Gate step | Exit code | Error excerpt | Confirms | Branch deletion confirmation]

## 5. CI-green confirmation

- **Final commit on main:** `<hash>`
- **CI run URL:** https://github.com/.../actions/runs/...
- **Status:** All 3 jobs green (gates / android / ios)
- **Date:** 2026-04-XX

---
_Phase 06 closed: 2026-04-XX_
_Phase 07 unblocked._
```

**gsd-verifier grep:** `^## [1-5]\.` — five matches required (the §1b and Pre-known/Agent sub-headings use `### N`, not `## N`, so they don't false-positive the verifier).

### Pattern 3: Pre-Class §2 Before Agent Spawn (Phase 04 inaugural, Phase 06 extends to 8 items)

**What:** Commit pre-classified known items into REVIEW.md §2 sub-section "Pre-known from CONTEXT" BEFORE spawning the 4 audit agents.
**When to use:** Whenever the previous-phase handoff has explicit pre-known items to triage. Phase 04 had 3 (from VERIFICATION.md), Phase 06 has 8 (from CONTEXT.md).
**Why:** Frees agents to find adjacent angles instead of rediscovering known items; gives the user a clean triage surface in §3.

**Pre-class commit message:** `docs(06-rev): pre-class 8 CONTEXT handoff items into §2`

### Pattern 4: Permanent Unit Test with Inertness Guard (Phase 04 Test #3 inaugural)

**What:** Unit test that asserts a runtime invariant, with an intermediate assertion BEFORE the main assert that proves the test setup is real (not silently no-op).
**When to use:** Every Phase 06 unit test (5 of them). Validated by Phase 04 mutation experiment (`DELETE WHERE 1=0` → test fails loudly with "test would be inert").
**Source:** `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` lines 95–106 — verified verbatim.

**Reference idiom (verbatim from Phase 04 Test #3, lines 99–106):**

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

**Phase 06 application** — each of the 5 unit tests gets an inertness guard:

| Test | Inertness guard idiom |
|------|------------------------|
| #1 MethodChannel sync | `expect(File(kotlinPath).existsSync() && File(swiftPath).existsSync() && File(dartPath).existsSync(), isTrue, reason: 'one of the 3 channel-source files moved — test silently inert');` |
| #2 Permission cascade | `expect(fakeRequester.invocationCount, 3, reason: 'permission flow skipped at least one step — silent ignore regression returned, test silently inert');` |
| #3 OemDetector ambiguous | `expect(fakeDevicePlugin.androidInfoReadCount, 1, reason: 'OemDetector did not consume the device-info fixture — test would silently pass on detection short-circuit regression');` |
| #4 Platform manifests | `expect(File(androidManifestPath).existsSync() && File(infoPlistPath).existsSync(), isTrue, reason: '1 of 2 platform manifests moved — test silently inert');` + `expect(parsedManifest.findAllElements('uses-permission').isNotEmpty, isTrue, reason: 'manifest parsed but contained no uses-permission — test silently inert on regex regression');` |
| #5 Android BootReceiver contract | `expect(File(androidManifestPath).existsSync() && File(kotlinReceiverPath).existsSync(), isTrue, reason: 'manifest or Kotlin receiver moved — test silently inert');` |

### Pattern 5: Atomic Commit Convention (Phase 02 + 04 locked)

**What:** Every fix is `fix(06-rev): <title>` (or `refactor(06-rev):` / `docs(06-rev):` / `test(06-rev):` / `chore(06-rev):` per nature). One per finding, OR batched per user approval at fix-time (Phase 04 Plan 04-05 precedent — 10 batches × ~10 min CI gate).
**When to use:** Every fix.
**Source:** `02-REVIEW.md §3` (42 atomic commits visible), `04-REVIEW.md §5` (10 batched commits visible).

### Pattern 6: Adversarial Branch Inline CI Trigger Expansion (Phase 02 + 04 locked)

**What:** Throwaway branches expand `on.push.branches` inline on the branch only (NOT on main). Main keeps `[main]`-only trigger.
**When to use:** Every adversarial CI test (Phase 02 had 3, Phase 04 had 2, Phase 06 has 1).
**Source:** Verified in `.github/workflows/ci.yml` — lines 3–5 currently `on.push.branches: [main]`. Phase 02 + 04 evidence in their REVIEW.md §4 confirms inline expansion + branch deletion (CI-trigger commit on the throwaway branch only).

**Pattern (from Phase 02 + 04 evidence, must apply for `adversarial/06-manifest-drift`):**

```yaml
# In adversarial/06-manifest-drift branch's .github/workflows/ci.yml ONLY (deleted with branch):
on:
  push:
    branches: [main, 'adversarial/**']  # was: [main]
  pull_request:
    branches: [main]
```

After CI evidence is archived, branch deleted local + remote → `on.push.branches` on main stays `[main]`-only. Zero cleanup cost.

### Anti-Patterns to Avoid

- **Don't spawn agents serially** — single tool-use message with 4 parallel Agent calls. Phase 02 + 04 lockdown.
- **Don't dedupe cross-lens findings** — Phase 02 + 04 convention: same finding surfaced by 2 agents under different lenses is preserved under BOTH with cross-reference. Audit transparency over compression.
- **Don't run `flutter run -d windows` runtime walk** — explicit user decision 2026-04-20: POC evidence review §1b replaces it. Divergence from Phases 02 + 04.
- **Don't write bespoke XML/plist parsers** — use `package:xml` (transitive via Drift, license MIT verified) or pure-Dart regex per Claude's Discretion. Don't hand-roll a SAX parser.
- **Don't use `pumpAndSettle()` in widget tests touching `_ChronoCard`** — Phase 05 documented (lock): the `Stream.periodic(1s)` chrono blocks pumpAndSettle indefinitely. Bounded `pump(Duration)` only. Pre-class item 7 (Should — re-flag if any agent re-surfaces it).
- **Don't omit inertness guard** — Phase 04 mutation experiment proved the value. Costs 1–2 lines per test, prevents silent neutralization on future refactor.
- **Don't introduce new direct deps casually** — Phase 06 GOAL is audit, not feature work. Even `package:xml` / `package:plist_parser` should be evaluated against pure-Dart regex first per Claude's Discretion + CLAUDE.md §Audit obligatoire.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AndroidManifest.xml parsing | Custom SAX parser or naive XML splitter | `package:xml 6.6.1` (MIT, transitive already) OR pure-Dart regex anchored on `<uses-permission android:name=` | Surface tiny (~10 entries); regex is safe; if any complex query needed, `package:xml`'s findAllElements is battle-tested |
| Info.plist parsing | Custom XML+typed-value parser | Pure-Dart regex on raw plist text | 4 string keys + 1 array — regex captures `<key>NAME</key>\s*<string>VALUE</string>` and `<array>\s*<string>location</string>` cleanly. plist_parser unverified-publisher (MIT but flagged by CLAUDE.md §Audit obligatoire as needing extra scrutiny for unverified publishers) |
| MethodChannel string sync across Kotlin / Swift / Dart | Manual cross-language type system | File-grep test (`Process.run('rg', ...)` or pure-Dart File + RegExp) with intermediate inertness assertion | Three sources (Kotlin string literal, Swift string literal, Dart `MethodChannel('app.gosl.mirkfall/boot_watchdog')` constant). No compiler enforces. Verified on disk: `BootCompletedReceiver.kt:55`, `boot_completed_watchdog.dart:90`, `ios_significant_change_watchdog.dart:35`, `AppDelegate.swift` (must verify in audit). Test scans + asserts all 3 contain the string verbatim |
| OemDetector ambiguous-match resolution priority | Hand-coded `if/else` cascade in test | Inject 3-5 fixture `AndroidDeviceInfo` via `DeviceInfoPlugin` test seam (Phase 05 pattern), assert deterministic OemFamily | Existing `OemDetector` (verified `lib/infrastructure/platform/oem_detector.dart` lines 81–87) uses `'${manufacturer} ${brand}'.toLowerCase()` regex chain in fixed order Xiaomi → Samsung → Huawei → OnePlus → Oppo → Other. Test must pin this order with ambiguous fixtures (e.g. `manufacturer=aosp brand=oneplus`, `manufacturer=xiaomi brand=redmi build=miui`, `manufacturer=huawei brand=honor`) and assert resolution stays deterministic on regex-ordering refactor |
| Permission cascade regression test | Mock platform channels via PermissionHandlerPlatform | `PermissionRequester` typedef seam (already in `lib/application/permissions/location_permission_flow.dart`, Phase 05 lock) — `Future<PermissionStatus> Function(Permission)` | Phase 05 STATE.md decision (verified): `permission_handler.Permission.locationWhenInUse` is a `const PermissionWithService._(5)` — subclassing not possible. Typedef seam is the narrowest; tests inject closure that captures invocation order + returns programmed statuses |
| §2 OEM workaround table content | Reverse-engineer from screenshots | Read `lib/presentation/screens/oem_guidance_screen.dart` `_copyFor()` switch + extract per-OemFamily title / steps / learnMoreUrl directly | Verified file: 7 OemFamily variants (Xiaomi / Samsung / Huawei / OnePlus / Oppo / OtherOem / IosDevice) with dontkillmyapp.com URLs for the first 5; reachability of `openLocationSettings()` from `permission_handler` confirmed by Plan 05-04 wiring |

**Key insight:** Phase 06 is an **audit + regression-guard** phase. Every "don't hand-roll" item is about not duplicating effort the existing codebase already paid (OemDetector lookup table, PermissionRequester seam, MethodChannel constant). Tests scan and assert; they don't re-implement.

## Common Pitfalls

### Pitfall 1: ci.yml on.push.branches still `[main]`-only — adversarial branch won't trigger CI

**What goes wrong:** Adversarial branch `adversarial/06-manifest-drift` is pushed but CI never runs (no on.push trigger match), so the gate-failure evidence cannot be archived in §4.
**Why it happens:** Verified `.github/workflows/ci.yml` lines 3–7: currently `on.push.branches: [main]` and `pull_request.branches: [main]`. Phase 02 + 04 used inline trigger expansion on each throwaway branch (Phase 02: 3 branches × inline expansion; Phase 04: 2 branches × inline expansion). The expansion lives on the throwaway branch only — main stays clean.
**How to avoid:** Plan 06-04 must include a sub-step "amend ci.yml on the adversarial branch to add `'adversarial/**'` to on.push.branches BEFORE pushing the poison commit, or include the trigger expansion in the same commit as the poison" (Option B per Phase 04 precedent: poison + trigger in same commit).
**Warning signs:** `gh run list --branch adversarial/06-manifest-drift` returns empty after push.

### Pitfall 2: Forgetting to register the new CI gate step in ci.yml `gates` job

**What goes wrong:** `tool/check_platform_manifests.dart` is committed but `.github/workflows/ci.yml` is never amended to invoke it; adversarial CI passes accidentally.
**Why it happens:** Phase 02's 3 + Phase 03's 2 gate scripts each required a manual ci.yml amendment (verified line 60–98 in `.github/workflows/ci.yml`: `Check GOSL headers`, `Check licenses`, `Check DEPENDENCIES.md`, `Check domain purity`, `Tool scripts unit tests`, `Check drift schema (current) is committed and fresh`). Phase 06 needs a 4th: `Check platform manifests (Android + iOS)`.
**How to avoid:** Plan 06-04 commit MUST include both `tool/check_platform_manifests.dart` AND a `.github/workflows/ci.yml` amendment adding a `Check platform manifests` step in the `gates` job. CI step name: `Check platform manifests (Android + iOS)` for symmetry. Position: after `Check drift schema (current) is committed and fresh` (line ~98) and before `Flutter unit + widget tests` (line 100).
**Warning signs:** `tool/test/check_platform_manifests_test.dart` green locally but adversarial branch CI passes (no failure on the poisoned manifest).

### Pitfall 3: package:plist_parser unverified publisher — silent licence drift risk

**What goes wrong:** Adding plist_parser as direct dep without auditing transitive publishers; future maintainer assumes "audited Phase 06" without re-checking.
**Why it happens:** plist_parser 0.2.7 is MIT but uploaded by an "Unverified uploader" per pub.dev (verified 2026-04-20). CLAUDE.md §Audit obligatoire: "En cas de doute sur une licence (custom, double licence, dual-licensing avec option GPL), ne pas ajouter la dépendance et demander confirmation."
**How to avoid:** **Recommendation: pure-Dart regex for Info.plist** instead of plist_parser. The Info.plist surface is 4 string keys + 1 UIBackgroundModes array — regex `<key>NSLocationWhenInUseUsageDescription</key>\s*<string>([^<]+)</string>` is safer than introducing an unverified-publisher transitive. If pursued anyway, document audit explicitly in DEPENDENCIES.md.
**Warning signs:** Reviewer cannot quickly explain who maintains `plist_parser` and what their commit history looks like.

### Pitfall 4: device_info_plus 13.0.0 silently re-attempted by future bump

**What goes wrong:** A future deps bump pulls device_info_plus 13.0.0 unilaterally; Windows transitive `win32: ^6.0.0` conflicts with file_picker 11.0.2's `win32: ^5.9.0` pin; `flutter pub get` fails silently or with a confusing `dependency_overrides` error.
**Why it happens:** Phase 05 explicitly pinned 12.4.0 with rationale comment in pubspec.yaml lines 64–72 (verified). The pin is fragile to future "minor cleanup" bumps.
**How to avoid:** Audit step in Plan 06-03 (Agent #4): grep `device_info_plus` in pubspec.yaml; confirm the inline rationale comment is intact + STATE.md has the corresponding decision row (verified present, line ~178 of STATE.md). If audit Should fix arises, escalate as a Should §3.
**Warning signs:** A reviewer asks "why not 13.0.0?" and the answer is not in the pubspec.yaml comment chain.

### Pitfall 5: pumpAndSettle re-introduced in widget tests touching Tracking dashboard

**What goes wrong:** Widget test that includes the SessionDetailScreen with active session calls `await tester.pumpAndSettle()`; test hangs indefinitely; CI times out at 20-min budget for `gates` job.
**Why it happens:** Phase 05 STATE.md decision (line ~190 verified): "Widget tests must avoid pumpAndSettle when the live Tracking dashboard is rendered — `_ChronoCard` spins `Stream.periodic(1s)`; `pumpAndSettle()` blocks indefinitely. Pattern: assert on `IconButton.onPressed != null` (wiring) + rely on controller tests for full async stop() coverage. Bounded `pump(Duration)` for simple frame waits."
**How to avoid:** Pre-class §2 item 7 already flags this as Should. Agent #3 lens explicitly briefed to grep `pumpAndSettle` across `test/presentation/**` for Phase 05 widget tests; any hit not adjacent to bounded `pump(Duration)` is a Should fix in loop.
**Warning signs:** CI gates job times out; local `flutter test test/presentation/...` hangs > 30 s.

### Pitfall 6: Test #1 MethodChannel scan misses Swift file path

**What goes wrong:** Test #1 scans Kotlin + Dart for the channel literal but Swift `AppDelegate.swift` path drifted (e.g. moved into a sub-package or renamed); test passes silently because intermediate inertness check only verifies the 2 verified files exist.
**Why it happens:** Verified channel literal locations as of 2026-04-20:
- `android/app/src/main/kotlin/app/gosl/mirkfall/BootCompletedReceiver.kt:55` — `private const val CHANNEL = "app.gosl.mirkfall/boot_watchdog"`
- `lib/infrastructure/platform/boot_completed_watchdog.dart:90` — `const MethodChannel _bootWatchdogChannel = MethodChannel('app.gosl.mirkfall/boot_watchdog');`
- `lib/infrastructure/platform/ios_significant_change_watchdog.dart:35` — `static const MethodChannel _channel = MethodChannel('app.gosl.mirkfall/boot_watchdog');`
- `ios/Runner/AppDelegate.swift` — Phase 05 STATE.md note (line ~207): "iOS FlutterImplicitEngineDelegate bridge stripped after Xcode 26 move" — the channel may NOT be present in Swift any more (audit Agent #4).
**How to avoid:** Agent #4 grep `app.gosl.mirkfall/boot_watchdog` across `ios/` to verify the Swift literal exists. If stripped: Test #1 inertness guard must verify only the file paths that DO contain the literal; Test #5 (Android-scoped) covers the Android side cleanly. iOS coverage deferred Phase 15 per Noted item 5 ("FlutterImplicitEngineDelegate rewire").
**Warning signs:** `Grep app.gosl.mirkfall/boot_watchdog` on `ios/` returns 0 matches.

### Pitfall 7: ROADMAP.md SC#1 path drift fix not commit-tracked

**What goes wrong:** Pre-class §2 item 2 (Should) — amend ROADMAP.md SC#1 from `.planning/pocs/phase-05/` to `docs/qual-01-02-poc.md + docs/poc-artifacts/` — applied silently in §3 triage without an explicit `docs(06-rev):` commit. Future reviewer sees the drift and re-flags.
**Why it happens:** Conventionally bookkeeping-only edits get rolled into another commit. Phase 06 explicitly elevates this to its own commit in CONTEXT.md §SC#4 OEM workaround / fix workflow.
**How to avoid:** Plan 06-05 fix-loop MUST land 1 atomic commit `docs(06-rev): amend ROADMAP.md SC#1 to match docs/ artifact location` per CONTEXT.md mandate.
**Warning signs:** `git log --grep "06-rev.*ROADMAP"` returns 0 commits at gate-closure.

### Pitfall 8: dart format pre-existing drift surfaces mid-loop (Phase 04 surprise repeat)

**What goes wrong:** During Plan 06-04 adversarial run or Plan 06-05 fix loop, CI fails on `Dart format check` (line 52 of ci.yml) due to drift accumulated since Phase 05 close. Phase 04 saw this as a "surprise Blocker" in 04-04 evidence.
**Why it happens:** `dart format --line-length 160 --set-exit-if-changed .` gate (active since Plan 04-05) catches any unformatted code on push. Drift accumulates from any tool that auto-emits .dart without re-formatting (rare but happens with codegen + analyzer toolchain churn).
**How to avoid:** Pre-class §2 item 8 already monitors. Plan 06-05 first commit: `chore(06-rev): dart format align with CI gate` if drift detected at start of fix loop. Cheap insurance — same recipe as Phase 04 commit `35152e5`.
**Warning signs:** Local `dart format --line-length 160 --set-exit-if-changed .` returns non-zero before any Phase 06 work begins.

## Code Examples

Verified patterns from on-disk Phase 04 + Phase 05 sources.

### Example 1: Permanent Unit Test with Inertness Guard

Source: `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` lines 95–119 (verified verbatim).

```dart
// 4. Capture post-adversary counts.
final after = await sanity.captureRowCounts();

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

// 5. Expect MigrationFailureException with a message pointing at
//    t_sessions and mentioning the before→after decrease.
expect(
  () => sanity.assertNoLoss(before, after),
  throwsA(
    isA<MigrationFailureException>()
        .having((MigrationFailureException e) => e.reason, 'reason', contains('t_sessions'))
        .having((MigrationFailureException e) => e.reason, 'reason', anyOf(contains('decreased'), contains('lost'))),
  ),
);
```

### Example 2: Phase 06 Test #1 Sketch — MethodChannel triple-source drift

Sketch (NOT yet on disk; Plan 06-04 deliverable):

```dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Phase 06 Adversarial Test #1 — permanent regression guard.
///
/// Proves that the MethodChannel name 'app.gosl.mirkfall/boot_watchdog'
/// stays consistent across THREE source-of-truth files: Dart constant,
/// Kotlin string literal, Swift string literal. No compiler enforces
/// this cross-language; this test is the safety net.
import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('MethodChannel triple-source drift regression guard (Phase 06 Test #1)', () {
    const String channelLiteral = 'app.gosl.mirkfall/boot_watchdog';

    final Map<String, String> sourcePaths = <String, String>{
      'Dart (boot_completed_watchdog)': 'lib/infrastructure/platform/boot_completed_watchdog.dart',
      'Dart (ios_significant_change_watchdog)': 'lib/infrastructure/platform/ios_significant_change_watchdog.dart',
      'Kotlin (BootCompletedReceiver)': 'android/app/src/main/kotlin/app/gosl/mirkfall/BootCompletedReceiver.kt',
      // 'Swift (AppDelegate)': 'ios/Runner/AppDelegate.swift', // verify in audit; may be stripped post-Xcode-26
    };

    test('all source files exist and contain the channel literal verbatim', () {
      // Inertness guard: file existence first. If a file moved, this fails
      // loudly with the missing path; without this, the channel-content
      // assertion would silently report "0 matches" as a false-positive.
      for (final entry in sourcePaths.entries) {
        expect(
          File(entry.value).existsSync(),
          isTrue,
          reason: '${entry.key} path moved or deleted — test would be silently inert. Path: ${entry.value}',
        );
      }

      // Now the actual cross-language consistency assertion.
      final List<String> missing = <String>[];
      for (final entry in sourcePaths.entries) {
        final String contents = File(entry.value).readAsStringSync();
        if (!contents.contains(channelLiteral)) {
          missing.add('${entry.key} (${entry.value}) does not contain "$channelLiteral"');
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'MethodChannel name drifted across language sources:\n${missing.join('\n')}',
      );
    });
  });
}
```

### Example 3: Phase 06 tool/check_platform_manifests.dart Sketch

Sketch (NOT yet on disk; Plan 06-04 deliverable). Mirrors `tool/check_domain_purity.dart` structure verbatim (verified):

```dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

/// Platform-manifest gate for Phase 05 GPS contract.
///
/// AndroidManifest.xml MUST contain (Phase 05 GPS-01..08 + auto-resume):
///   - android.permission.ACCESS_FINE_LOCATION
///   - android.permission.ACCESS_COARSE_LOCATION
///   - android.permission.ACCESS_BACKGROUND_LOCATION
///   - android.permission.FOREGROUND_SERVICE
///   - android.permission.FOREGROUND_SERVICE_LOCATION
///   - android.permission.WAKE_LOCK
///   - android.permission.POST_NOTIFICATIONS
///   - android.permission.RECEIVE_BOOT_COMPLETED
///   - <receiver android:name=".BootCompletedReceiver" ...> with BOOT_COMPLETED intent-filter
///
/// Info.plist MUST contain (Phase 05 QUAL-04):
///   - NSLocationWhenInUseUsageDescription (non-empty, non-TODO)
///   - NSLocationAlwaysAndWhenInUseUsageDescription (non-empty, non-TODO)
///   - UIBackgroundModes array containing "location"
///
/// CLI contract (Phase 01 convention): exit 0 = clean, 1 = violations
/// found, 2 = misconfiguration (file missing, unreadable).

const String _androidManifestPath = 'android/app/src/main/AndroidManifest.xml';
const String _infoPlistPath = 'ios/Runner/Info.plist';

const List<String> _requiredAndroidPermissions = <String>[
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
  'android.permission.ACCESS_BACKGROUND_LOCATION',
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_LOCATION',
  'android.permission.WAKE_LOCK',
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.RECEIVE_BOOT_COMPLETED',
];

const List<String> _requiredInfoPlistKeys = <String>[
  'NSLocationWhenInUseUsageDescription',
  'NSLocationAlwaysAndWhenInUseUsageDescription',
];

Future<int> runCheck({String? androidManifestPath, String? infoPlistPath}) async {
  final String resolvedAndroid = androidManifestPath ?? _androidManifestPath;
  final String resolvedIos = infoPlistPath ?? _infoPlistPath;

  // Misconfiguration — exit 2 (Phase 01 convention)
  if (!File(resolvedAndroid).existsSync()) {
    stderr.writeln('check_platform_manifests: AndroidManifest.xml not found at $resolvedAndroid');
    return 2;
  }
  if (!File(resolvedIos).existsSync()) {
    stderr.writeln('check_platform_manifests: Info.plist not found at $resolvedIos');
    return 2;
  }

  final List<String> violations = <String>[];

  // AndroidManifest.xml — uses-permission entries (regex anchored on the attribute)
  final String androidContents = File(resolvedAndroid).readAsStringSync();
  for (final perm in _requiredAndroidPermissions) {
    final RegExp r = RegExp('<uses-permission\\s+android:name="${RegExp.escape(perm)}"');
    if (!r.hasMatch(androidContents)) {
      violations.add('AndroidManifest.xml missing required uses-permission: $perm');
    }
  }
  // BootCompletedReceiver declaration
  if (!RegExp(r'<receiver[^>]*android:name="\.BootCompletedReceiver"').hasMatch(androidContents)) {
    violations.add('AndroidManifest.xml missing <receiver android:name=".BootCompletedReceiver"> declaration');
  }
  if (!RegExp(r'<action\s+android:name="android\.intent\.action\.BOOT_COMPLETED"').hasMatch(androidContents)) {
    violations.add('AndroidManifest.xml BootCompletedReceiver missing BOOT_COMPLETED intent-filter action');
  }

  // Info.plist — required string keys (regex captures <key>NAME</key> followed by <string>VALUE</string>)
  final String infoPlistContents = File(resolvedIos).readAsStringSync();
  for (final key in _requiredInfoPlistKeys) {
    final RegExp r = RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>', dotAll: true);
    final RegExpMatch? m = r.firstMatch(infoPlistContents);
    if (m == null) {
      violations.add('Info.plist missing required key: $key');
    } else if (m.group(1)?.trim().isEmpty ?? true) {
      violations.add('Info.plist key $key has empty value');
    } else if (m.group(1)!.toUpperCase().contains('TODO')) {
      violations.add('Info.plist key $key still has TODO placeholder: "${m.group(1)}"');
    }
  }
  // UIBackgroundModes array containing "location"
  final RegExp bgModesRegex = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>', dotAll: true);
  final RegExpMatch? bgMatch = bgModesRegex.firstMatch(infoPlistContents);
  if (bgMatch == null) {
    violations.add('Info.plist missing UIBackgroundModes array');
  } else if (!bgMatch.group(1)!.contains('<string>location</string>')) {
    violations.add('Info.plist UIBackgroundModes array does not contain <string>location</string>');
  }

  if (violations.isEmpty) {
    stdout.writeln('check_platform_manifests: OK (Android + iOS manifests contain all required Phase 05 entries)');
    return 0;
  }

  stderr.writeln('check_platform_manifests: ${violations.length} violation(s):');
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  stderr.writeln();
  stderr.writeln('Rule: Phase 05 GPS contract requires the listed manifest entries on both platforms.');
  stderr.writeln('Restore the missing entries; see lib/infrastructure/gps/ + Phase 05 SUMMARY for context.');
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
```

### Example 4: §1b POC Evidence Collapsible Format

Pattern (NOT verbatim from disk; constructed for Phase 06 §1b per CONTEXT.md):

```markdown
### 1b. POC evidence review

*Captured by Plan 06-02. Replaces "Runtime walk Windows" subheading from Phase 04 §1b. User decision 2026-04-20: POC artifacts ARE the runtime observation; no fresh `flutter run` walk this gate. Source: `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png` + `docs/store-review-rationale.md`.*

**Summary table — convergent evidence Pixel 4a + iPhone 17 Pro:**

| Metric | Pixel 4a (Android 14) | iPhone 17 Pro (iOS 26) |
|--------|----------------------|------------------------|
| Session ID | sess_R5385AETFJ100000KMXZFK4S61 ("test2") | sess_Z6STJJSTFJ100000PNXZFK4S61 |
| Duration | 28.6 min (17:33:26Z → 18:02:00Z) | 13.5 min (23:11:33Z → 23:25:02Z) |
| Fixes recorded | 342 | 82 (84 received, 2 stationary-dedup, 0 accuracy-dropped) |
| Cadence | regular < 10 s; one 66.4 s satellite-geometry dip | steady ~6 s/fix throughout, no drift |
| Persistent notification | visible whole walk, dismissed on Stop | Dynamic Island GPS indicator visible whole walk |
| Verdict (Phase 05 close) | PASS | PASS-with-caveat (duration only; cadence stable) |

<details>
<summary>Pixel 4a walk extract — Plan 05-06 SUMMARY + qual-01-02-poc.md</summary>

[verbatim or near-verbatim extract from docs/qual-01-02-poc.md "Entry 1: Pixel 4a"]
</details>

<details>
<summary>iPhone 17 Pro walk extract — Plan 05-06 SUMMARY + qual-01-02-poc.md</summary>

[verbatim extract from docs/qual-01-02-poc.md "Entry 3: iPhone 17 Pro"]
</details>

<details>
<summary>POC plot — docs/poc-artifacts/test2-full.png</summary>

![Pixel 4a 342-fix walk plot](../../../docs/poc-artifacts/test2-full.png)
</details>

**Battery delta extraction:** *(from qual-01-02-poc.md — Agent #4 confirms presence/absence; if absent, inline waiver per pre-class item 3)*

**QUAL-03 store rationale snapshot:** *(from docs/store-review-rationale.md — 5-section count: Project description / Why Always location / Data handling / Source code accessibility / Contact; signed-off-as-defensible-by-reviewer at Phase 05 close)*

**Confirms:** POC evidence supports gate-closure under accepted PASS-with-caveat per CONTEXT.md.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 02: 3 throwaway adversarial branches × 3 CI gates (licence / headers / deps) | Phase 06: 1 throwaway branch + 5 permanent unit tests + 1 new CI gate | 2026-04-20 (CONTEXT.md) | Permanent unit tests are more maintainable than throwaway branches; Phase 06 surface (runtime code, not gate scripts) favors in-repo tests |
| Phase 04: Fresh `flutter run -d windows` runtime walk § 1b + `dart run tool/walk_db.dart` | Phase 06: POC evidence review (read `docs/qual-01-02-poc.md` + `docs/poc-artifacts/`) | User decision 2026-04-20 | GPS-focused gate where POC artifacts ARE the definitive runtime observation; saves wall-clock + avoids redundant walk |
| Phase 02: 0 pre-class §2 items (all findings discovered by agents) | Phase 04: 3 pre-class items from VERIFICATION.md | Phase 06: 8 pre-class items from CONTEXT.md | Frees agents to find adjacent angles; eliminates duplicate-discovery noise |
| Phase 02 + 04: per-finding atomic commit (`fix(02-rev): X`) | Phase 04 Plan 04-05: batched fix loop accepted (10 batches × ~10 min CI) | User decision 2026-04-19 | Trade-off bisectability-batch-granularity vs wall-clock CI; permissible Phase 06 if user re-approves |
| Manual `Override` import in widget tests | Inline `ProviderScope(overrides: [...], child: ...)` | Phase 05 (verified STATE.md) | `Override` not publicly exported by `flutter_riverpod 3.3.x` — helper functions with `List<Override>` param signatures fail to compile |
| `valueOrNull` for AsyncValue read | `AsyncValue.value` (nullable) | Phase 05 (verified STATE.md) | Riverpod 3.x removed valueOrNull |

**Deprecated/outdated:**
- iOS FlutterImplicitEngineDelegate bridge in AppDelegate.swift — stripped after Xcode 26 move (Phase 05 STATE.md). iOS auto-resume rewire deferred Phase 15. Swift channel literal MAY no longer be present; Test #1 inertness guard must verify.
- Phase 03 V1/V2 schema_v{1,2}.dart helpers diverge from frozen JSON dumps (CHECK constraints added Phase 04 not back-propagated to helpers). NOT in scope Phase 06; lives in `.planning/phases/04-review-gate-persistence/deferred-items.md`.

## Open Questions

1. **iOS Swift MethodChannel literal — present or stripped?**
   - What we know: Phase 05 STATE.md says "iOS FlutterImplicitEngineDelegate bridge stripped after Xcode 26 move". `lib/infrastructure/platform/ios_significant_change_watchdog.dart:35` still contains the channel literal (verified). But the AppDelegate.swift Swift-side mirror is unverified.
   - What's unclear: Does `ios/Runner/AppDelegate.swift` still contain `"app.gosl.mirkfall/boot_watchdog"` as a string literal, or was it deleted with the bridge strip?
   - Recommendation: Agent #4 grep `app.gosl.mirkfall/boot_watchdog` in `ios/Runner/AppDelegate.swift` at audit time. Test #1 file map must reflect reality (include or exclude Swift entry). If excluded, document inline in Test #1 docstring + cross-ref deferred Phase 15 rewire.

2. **Battery delta — present in POC artefacts?**
   - What we know: CONTEXT.md says "Agent #4 extracts opportunistic battery delta from `docs/qual-01-02-poc.md` if present; if absent, inline waiver §2 with the fix-cadence proxy argument."
   - What's unclear: First 30 lines of `docs/qual-01-02-poc.md` (verified read at research time) describe protocol but do not yet contain Pixel 4a or iPhone walk battery readings. Agent #4 must read the rest.
   - Recommendation: Plan 06-02 task — Agent #4 reads full `docs/qual-01-02-poc.md`; if battery delta present (e.g. "before: 87%, after: 84%, delta: -3% over 28.6 min = -6.3%/h"), inline §1b. If absent, inline waiver per pre-class item 3.

3. **Should `package:xml` be added as direct dev_dependency or stay transitive?**
   - What we know: `package:xml 6.6.1` is MIT (verified pub.dev 2026-04-20, publisher lukas-renggli.ch verified). Already pulled transitively via Drift + Freezed codegen (already in pubspec.lock).
   - What's unclear: CLAUDE.md §depend_on_referenced_packages requires direct declaration if test/script imports it. Phase 02 promoted `yaml + test` from transitive to direct dev_dependencies for this reason (verified STATE.md decision row).
   - Recommendation: If `tool/check_platform_manifests.dart` imports `package:xml`, promote to direct dev_dependency in pubspec.yaml + add DEPENDENCIES.md entry. If using pure-Dart regex, no change needed. **Researcher recommendation: pure-Dart regex** for this surface — minimizes new direct deps + matches Phase 02 + 04 minimal-dep philosophy.

4. **CI step name for `tool/check_platform_manifests.dart` — what convention?**
   - What we know: Existing CI step names follow pattern `Check <thing>` — `Check GOSL headers`, `Check licenses (GPL/AGPL/copyleft scan)`, `Check DEPENDENCIES.md is up to date`, `Check domain purity (lib/domain/ imports)`, `Check drift schema (current) is committed and fresh`.
   - What's unclear: Best name for the new step.
   - Recommendation: `Check platform manifests (Android + iOS)` for symmetry. Position: after line 98 (Check drift schema) and before line 100 (Flutter unit + widget tests).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `package:test` 1.30.0 (pure-Dart unit/integration) + `package:flutter_test` (widget tests, bundled with Flutter SDK 3.41.5) |
| Config files | `dart_test.yaml` (Phase 03 created — `@Tags(['migration'])` discipline); no extra config needed for Phase 06 |
| Quick run command (per task commit) | `flutter test test/infrastructure/boot_watchdog/ test/application/permissions/ test/infrastructure/platform/ test/tooling/` |
| Full suite command (per wave merge) | `flutter test` (widget + integration) AND `dart test test/domain/ test/infrastructure/db/ test/infrastructure/stores/ test/infrastructure/ids/ test/infrastructure/migration/` AND `dart test tool/test/` |
| Phase gate | Full suite green + `dart run tool/check_platform_manifests.dart` (new gate) green + all 5 unit tests green + adversarial branch CI red on the gate before being deleted + `gh run view <final-main-commit-hash>` all 3 jobs green |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SC#1 | POC artefacts archived (path drift to `docs/`) | artefact-evidence + ROADMAP amendment | `gh api ...` listing of `docs/qual-01-02-poc.md` + `docs/poc-artifacts/test2-full.png` + `git log --grep "06-rev.*ROADMAP"` | ✅ artefacts on disk (verified); ❌ ROADMAP amendment commit (will land Wave 5) |
| SC#2 | Battery measurement < 15 %/h walking | POC-evidence extract OR inline waiver with fix-cadence proxy | Agent #4 reads `docs/qual-01-02-poc.md` for battery delta entries | ✅ `docs/qual-01-02-poc.md` exists; ❓ battery section presence (Open Question 2) |
| SC#3 | Review protocol applied (user-first, titles+explanation, 5-section REVIEW.md) | REVIEW.md artifact contract | `grep -c '^## [1-5]\.' .planning/phases/06-review-gate-gps/06-REVIEW.md` returns 5 (gsd-verifier convention) | ❌ Wave 1 deliverable (Plan 06-01 scaffold) |
| SC#4 | OEM workaround documented (deep-links + instructions + tracking-interrompu banner DEFERRED) | REVIEW.md §2 OEM workaround plan table + linked screens | Manual review of §2 table cell contents against `lib/presentation/screens/oem_guidance_screen.dart::_copyFor` | ❌ Wave 2/3 deliverable (Plan 06-02 or 06-03) |
| Implicit gate-closed: 5 unit tests green | Permanent regression guards (MethodChannel sync / permission cascade / OEM ambiguous / platform manifest / Android boot receiver) | unit (pure-Dart + flutter_test mixed) | `dart test test/infrastructure/boot_watchdog/method_channel_sync_test.dart test/application/permissions/location_permission_cascade_test.dart test/infrastructure/platform/oem_detector_ambiguous_test.dart test/tooling/platform_manifests_test.dart test/infrastructure/boot_watchdog/android_boot_receiver_contract_test.dart` | ❌ All 5 — Wave 4 deliverables (Plan 06-04) |
| Implicit gate-closed: new CI gate | `tool/check_platform_manifests.dart` exit 0 on clean main + exit 1 on adversarial poison | static gate (CI run) | `dart run tool/check_platform_manifests.dart` (local + CI) + `dart test tool/test/check_platform_manifests_test.dart` (script unit test) | ❌ Wave 4 deliverable (Plan 06-04) |
| Implicit gate-closed: adversarial CI run | Branch `adversarial/06-manifest-drift` triggers CI fail with exit 1 + clear stderr identifying file + missing entry | CI-run evidence | `gh run view <run-id>` archived in §4 + branch deleted local + remote | ❌ Wave 4 deliverable (Plan 06-04) |
| Implicit gate-closed: final main CI green | All 3 jobs (gates / android / ios) green on the final main commit after fix-loop | CI-run evidence | `gh run view <final-commit>` archived in §5 | ❌ Wave 5 deliverable (Plan 06-05) |

### Sampling Rate

- **Per task commit:** `flutter test test/infrastructure/boot_watchdog/ test/application/permissions/ test/infrastructure/platform/ test/tooling/` (covers the 5 new unit tests + tool unit test)
- **Per wave merge:** `flutter test` + `dart test test/domain/ test/infrastructure/db/ test/infrastructure/stores/ test/infrastructure/ids/ test/infrastructure/migration/` + `dart test tool/test/` (full suite — same as ci.yml `gates` job invocations)
- **Phase gate:** Full suite green + `dart run tool/check_platform_manifests.dart` (exit 0 on main) + adversarial branch CI evidence archived (exit 1 on poisoned branch) + final main CI green (all 3 jobs gates / android / ios) before `/gsd:verify-work`.

### Wave 0 Gaps

These files do NOT yet exist on disk and MUST be created during Phase 06:

- [ ] `test/infrastructure/boot_watchdog/method_channel_sync_test.dart` — covers Test #1 (MethodChannel triple-source drift). NOTE: directory `test/infrastructure/boot_watchdog/` does not exist either (verified — Phase 05 BootCompletedWatchdog tests live in `test/infrastructure/platform/`). Either create new dir OR co-locate as `test/infrastructure/platform/method_channel_sync_test.dart` per existing convention.
- [ ] `test/application/permissions/location_permission_cascade_test.dart` — covers Test #2 (permission cascade). NOTE: directory `test/application/permissions/` exists (verified — has `location_permission_flow_test.dart`). New file.
- [ ] `test/infrastructure/platform/oem_detector_ambiguous_test.dart` — covers Test #3 (OemDetector ambiguous match). Directory exists (verified — has `oem_detector_test.dart` from Phase 05). New file (do not extend existing — keeps adversarial scope clear).
- [ ] `test/tooling/platform_manifests_test.dart` — covers Test #4 (platform manifest drift). NOTE: directory `test/tooling/` does not exist (verified). Create new dir.
- [ ] `test/infrastructure/boot_watchdog/android_boot_receiver_contract_test.dart` — covers Test #5 (Android BootCompletedReceiver contract). Same dir as Test #1 above (must align).
- [ ] `tool/check_platform_manifests.dart` — new CI gate script (pattern from `tool/check_domain_purity.dart` verified verbatim).
- [ ] `tool/test/check_platform_manifests_test.dart` — paired tool unit test covering exit codes 0/1/2 + at least 1 fixture per violation class. Directory `tool/test/` exists (verified — 6 existing tests).
- [ ] Adversarial branch `adversarial/06-manifest-drift` poison commit — temporary, deleted post-archive.
- [ ] `.github/workflows/ci.yml` amendment — new step `Check platform manifests (Android + iOS)` after `Check drift schema (current) is committed and fresh` (line ~98).
- [ ] `06-REVIEW.md` 5-section skeleton — Wave 1 (Plan 06-01) scaffold.
- [ ] If `package:xml` chosen for Test #4 / new CI gate: pubspec.yaml dev_dependency + DEPENDENCIES.md entry. If pure-Dart regex chosen: no new pubspec entries (recommended).
- [ ] ROADMAP.md SC#1 amendment (Plan 06-05 fix loop): change `.planning/pocs/phase-05/` → `docs/qual-01-02-poc.md + docs/poc-artifacts/`.

Framework install: not needed — `package:test`, `flutter_test`, and existing tooling all already in pubspec.lock and CI (verified).

## Sources

### Primary (HIGH confidence)

- `.planning/phases/06-review-gate-gps/06-CONTEXT.md` (gathered 2026-04-20) — locked decisions, 8 pre-class items, 4-agent slicing, 5 unit tests + 1 CI gate + 1 adversarial branch design.
- `.planning/phases/02-review-gate-foundation/02-CONTEXT.md` (gathered 2026-04-17) — original 5-section REVIEW.md template + 4-parallel-sub-agent pattern + adversarial branch discipline.
- `.planning/phases/04-review-gate-persistence/04-CONTEXT.md` (gathered 2026-04-18) — pre-class §2 inaugural pattern + permanent unit test with inertness guard pattern.
- `.planning/phases/02-review-gate-foundation/02-REVIEW.md` (closed 2026-04-18) — concrete exemplar of 5-section format + adversarial CI evidence block + 42-row triage table.
- `.planning/phases/04-review-gate-persistence/04-REVIEW.md` (closed 2026-04-19) — concrete exemplar of §1b runtime walk format (Phase 06 §1b POC review mirrors structure) + permanent unit test §4 evidence block + 91-row triage table + batched fix-loop §5.
- `.planning/STATE.md` — Phase 05 lock-in decisions (~50 entries verified): distanceFilter int typing, device_info_plus 12.4.0 pin, FlutterImplicitEngineDelegate stripped Xcode 26, MethodChannel triple-source, AsyncValue.value Riverpod 3.x, pumpAndSettle avoidance, Override non-export, Plan 04-05 batched fix loop precedent.
- `.planning/REQUIREMENTS.md` — Phase 05 requirements complete; Phase 06 review-gate has no formal REQ-IDs; SC drives.
- `.planning/ROADMAP.md` — Phase 06 SC#1..4 + execution order + Phase 07 dependency.
- `.planning/phases/05-gps-session-lifecycle/05-{01..06}-SUMMARY.md` — Phase 05 file inventories (frontmatter `key-files.created/modified`); deviation lists (auto-fixed Rule 1/3 issues); auto-documented decisions (8 + 8 + 10 + 9 + 12 + 7 keys = ~50 inline decisions).
- `.github/workflows/ci.yml` (verified 2026-04-20) — 360+ lines, gates job step list, on.push.branches `[main]`-only, 3 jobs (gates / android / ios). Lines 60–98 = existing gate scripts (Phase 06 inserts step after line 98).
- `lib/infrastructure/platform/oem_detector.dart` (verified) — sealed OemFamily 7 variants + regex resolution chain Xiaomi → Samsung → Huawei → OnePlus → Oppo → Other; isIosOverride/isAndroidOverride seam.
- `lib/presentation/screens/oem_guidance_screen.dart` (verified, 224 lines) — `_copyFor()` switch with title / intro / steps / learnMoreUrl per OemFamily; `share_plus` reuse for dontkillmyapp.com link.
- `lib/infrastructure/platform/boot_completed_watchdog.dart` line 90 (verified) — Dart channel constant.
- `lib/infrastructure/platform/ios_significant_change_watchdog.dart` line 35 (verified) — Dart channel constant mirror.
- `android/app/src/main/kotlin/app/gosl/mirkfall/BootCompletedReceiver.kt` line 55 (verified) — Kotlin channel literal `private const val CHANNEL = "app.gosl.mirkfall/boot_watchdog"`.
- `android/app/src/main/AndroidManifest.xml` (verified, 114 lines) — 8 permissions + BootCompletedReceiver declaration + intent-filter.
- `ios/Runner/Info.plist` (verified, 82 lines) — final QUAL-04 copy + UIBackgroundModes location array; NSCameraUsageDescription / NSPhotoLibraryUsageDescription still TODO Phase 11.
- `lib/main.dart` (verified, 180 lines) — runZonedGuarded option (b) post-Phase 04 P4 fix; rootNavigatorKey wiring; flutter_local_notifications init.
- `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` (verified, 126 lines) — Phase 04 Test #3 reference idiom for inertness guard pattern.
- `tool/check_domain_purity.dart` (verified, 94 lines) — Phase 03 reference pattern for `tool/check_platform_manifests.dart`.
- `pubspec.yaml` (verified, 152 lines) — Phase 05 deltas (geolocator 14.0.2, flutter_local_notifications 21.0.0, permission_handler 12.0.1, device_info_plus 12.4.0).

### Secondary (MEDIUM confidence)

- `docs/qual-01-02-poc.md` (head 30 lines verified) — POC protocol structure; full content read deferred to Plan 06-02 Agent #4.
- `docs/poc-artifacts/` listing (`test2-full.png`, `sess_R5385AETFJ100000KMXZFK4S61-20260419-200715.png`, `.gitkeep`) verified.
- `docs/store-review-rationale.md` — exists; not yet read in research (Plan 06-02 Agent #4 deliverable).

### Tertiary (LOW confidence — verified via WebFetch only)

- pub.dev `package:xml 6.6.1` license=MIT, publisher lukas-renggli.ch verified (verified 2026-04-20 via WebFetch). NO transitive license drift inspected — Agent #4 should confirm transitives clean if package adopted.
- pub.dev `package:plist_parser 0.2.7` license=MIT, publisher unverified, deps `meta ^1.7.0 + xml ^6.0.1` (verified 2026-04-20 via WebFetch). Recommendation: avoid (unverified publisher per CLAUDE.md §Audit obligatoire).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every Phase 05 dep verified in pubspec.yaml + STATE.md + DEPENDENCIES.md (Phase 02 + 04 already audited the originals).
- Architecture patterns: HIGH — 5-section REVIEW.md, 4-agent wave, pre-class §2, inertness guard, atomic commits all verified verbatim in 02-REVIEW.md + 04-REVIEW.md + lock-in STATE.md decisions.
- Don't hand-roll: HIGH — every "use instead" path verified on disk (OemDetector regex chain, PermissionRequester typedef, MethodChannel constants, OemGuidanceScreen `_copyFor` switch).
- Common pitfalls: HIGH — every pitfall sources back to a verified file/line or a documented Phase 02/04/05 decision.
- POC evidence (Open Question 2): MEDIUM — only first 30 lines of `docs/qual-01-02-poc.md` read at research time; battery delta presence/absence is a Plan 06-02 deliverable.
- Swift channel literal (Open Question 1): MEDIUM — Dart side verified but Swift side unverified (FlutterImplicitEngineDelegate stripped per STATE.md may have removed the Swift literal).
- package:xml + plist_parser license info: MEDIUM — verified via single WebFetch query each; transitive license trees unverified.

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (30 days — patterns are stable across review-gate phases; only the dep-version landscape could drift, and that is small surface)

---

*Phase: 06-review-gate-gps*
*Research conducted: 2026-04-20*
