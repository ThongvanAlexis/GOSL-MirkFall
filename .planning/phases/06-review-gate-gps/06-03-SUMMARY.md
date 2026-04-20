---
phase: 06-review-gate-gps
plan: 03
subsystem: review-gate
tags: [review-gate, gps, audit, triage, parallel-agents, claude-md-sweep, oem-workaround, adversarial-readiness]

requires:
  - phase: 06-review-gate-gps
    provides: "§1 user-first capture + §1b POC evidence review archived (Plans 06-01 + 06-02)"
  - phase: 05-gps-session-lifecycle
    provides: "Phase 05 GPS artefacts (controllers, ports, manifests, boot watchdog, POC evidence) — audit target"
provides:
  - "§2 fully populated: 8 pre-class CONTEXT items + SC#4 OEM workaround table (_copyFor() 7/7) + 4-agent findings (81 total) + narrative appendix + Adversarial readiness checklist"
  - "§3 triage table: 87 rows covering all 2 Blockers + 20 Shoulds + 20 Coulds + 45 Noteds with cross-lens preservation"
  - "Adversarial readiness checklist for Plan 06-04 (7 items, all pre-verified)"
  - "Handoff to Plan 06-04 (adversarial wave) and Plan 06-05 (fix loop) with batch strategy"
affects:
  - "Plan 06-04 (adversarial wave): 5 permanent unit tests + 1 throwaway CI branch — file map locked (Swift excluded) + fixtures sketched + manifest state snapshotted"
  - "Plan 06-05 (fix loop): 20 fix-target findings (2 Blockers + 18 Shoulds minus 1 waiver + 2 Coulds subsumed under grouped fixes) batched per Phase 04-05 precedent"

tech-stack:
  added: []
  patterns:
    - "4-agent parallel audit wave — single tool-use message spawning 4 general-purpose agents (third successful cycle after Phases 02 + 04)"
    - "Cross-lens finding preservation — same-file:line findings from different audit lenses get separate §3 rows with SAME commit-hash placeholder + explicit cross-references (Phase 04 convention)"
    - "Blanket triage decision per Phase 04 precedent — 'fix blocker and should' applied verbatim"
    - "_copyFor() sealed-exhaustiveness coverage check — pre-class baseline + Dart compile-time guard"

key-files:
  created:
    - .planning/phases/06-review-gate-gps/06-03-SUMMARY.md
  modified:
    - .planning/phases/06-review-gate-gps/06-REVIEW.md (§2 populated + §3 triage table — 87 rows)

key-decisions:
  - "Blanket user triage 'fix blocker and should' per Phase 04 precedent: all 2 Blockers fix, all 20 Shoulds fix OR waived (Agent #1 #2 iOS auto-resume waived — Phase 15 FlutterImplicitEngineDelegate rewire per Phase 05 STATE.md Xcode 26 strip decision)"
  - "Coulds split: Agent #4 #11 (kDefaultDistanceFilterMeters name correct as-is) + Agent #4 #13 (Python style one-liner) won't-fix; remaining 18 Coulds defer-to-phase-15 (6) or defer-to-phase-14 (3 l10n) or subsumed under grouped Shoulds (2)"
  - "Cross-lens duplicates convention confirmed: Agent #1 #3 + Agent #2 #6 + Agent #2 #12 (bare-catch at location_permission_flow.dart:58-60) collapse to ONE fix with 3 §3 rows; Agent #1 #2 + Agent #2 #15 + Agent #2 #18 (iOS watchdog) collapse to ONE waiver with 3 rows (1 Should waived + 2 Noted observations); Pre-class #7 + Agent #3 #2 (pumpAndSettle) ONE fix 2 rows"
  - "SC#4 OEM workaround table 7/7 OemFamily variants explicitly handled in _copyFor() — Dart sealed-exhaustiveness compile-time guard means no escalations possible (all rows Noted covered); Agent #4 triple-source-of-truth verification confirmed"
  - "Swift AppDelegate channel literal confirmed ABSENT post-Xcode 26 strip (grep returned 0 matches) — Plan 06-04 Test #1 file map EXCLUDES Swift; Test #5 covers Android cleanly"

requirements-completed: []

duration: 5 min
completed: 2026-04-20
---

# Phase 06 Plan 03: Pre-class + 4-agent audit wave + user triage Summary

**8 CONTEXT pre-class items + SC#4 OEM workaround table (7/7 _copyFor() coverage) + 4-agent parallel audit (81 findings) + user blanket `fix blocker and should` triage captured as 87-row §3 table — zero scaffold `(pending)` markers remaining in §2 or §3.**

## Performance

- **Duration:** 5 min (Task 5 execution — §3 triage capture + SUMMARY + state updates)
- **Started:** 2026-04-20T07:36:42Z (Task 5 start; Tasks 1-3 executed separately by orchestrator in earlier sub-agents)
- **Completed:** 2026-04-20T07:41:38Z
- **Tasks:** 5 (Task 1 = `6c4bf39`; Task 2 = `45fbc8c`; Task 3 = `693181f` — 3a orchestrator-spawned sub-agents, 3b consolidation; Task 4 checkpoint-resumed; Task 5 = `7b2a491` + this summary's metadata commit)
- **Files modified:** 2 (`06-REVIEW.md` §3 table + this new SUMMARY)

## Agent dispatch — single tool-use message (Task 3a orchestrator-executed)

All 4 agents spawned in ONE tool-use message (parallel). Wall-clock timing for this wave was not recorded on disk (continuation agent no longer had access to the per-agent spawn artefacts); Phase 02 baseline ~10 min bounded-by-slowest, Phase 04 baseline ~9.7 min. Pattern validated third time.

| Agent | Type | Scope | Findings (B / S / C / N) |
|-------|------|-------|--------------------------|
| #1 | general-purpose | GPS infra + notifications + Drift V3 + manifest declarations | 0 / 4 / 4 / 10 |
| #2 | general-purpose | Controller + permissions + Riverpod state | 2 / 7 / 5 / 4 |
| #3 | general-purpose | UI + routing + banner widget | 0 / 7 / 7 / 9 |
| #4 | general-purpose | Boot watchdog + native bridges + POC tooling + CLAUDE.md sweep | 0 / 0 / 4 / 16 |
| **4-agent subtotal** | | | **2 / 18 / 20 / 39** |
| Pre-class §2 (8 items) | CONTEXT handoff | CONTEXT.md §POC evidence acceptance | 0 / 2 / 0 / 6 |
| SC#4 OEM table (7 rows) | Baseline scope | _copyFor() + dontkillmyapp.com + openAppSettings() | 0 / 0 / 0 / 7 (not in §3) |
| **TOTAL (§3 rows)** | | | **2 / 20 / 20 / 45 = 87** |

SC#4 OEM rows NOT reflected in §3 because all 7 variants are `Noted (covered)` baseline (no escalations — Dart sealed exhaustiveness guarantees compile-time coverage); per plan §3 format rule, SC#4 rows only enter §3 if escalated.

## SC#4 OEM workaround — _copyFor() coverage check

- **OemFamily variants in oem_detector.dart:** 7 (Xiaomi / Samsung / Huawei / OnePlus / Oppo / OtherOem / IosDevice)
- **_copyFor() switch coverage:** 7/7 explicit cases (Dart sealed exhaustiveness compile-time check enforces this)
- **Escalations:** none — all 7 variants explicitly handled, all rows baseline `Noted (covered)`

## Severity rollup

| Severity | Count | Decision breakdown |
|----------|-------|--------------------|
| Blocker | 2 | 2 fix (0 waived — CONTEXT.md forbids) |
| Should | 20 | 19 fix + 1 waived (Agent #1 #2 iOS auto-resume — Phase 15 deferral) |
| Could | 20 | 15 defer-to-phase-15 / 3 defer-to-phase-14 (l10n) / 2 won't-fix (Agent #4 #11 name-correct + Agent #4 #13 Python style) |
| Noted | 45 | 45 observation (audit transparency) |
| **TOTAL** | **87** | **21 fix-this-phase + 1 waived + 18 deferred + 2 won't-fix + 45 observation** |

Fix-this-phase count is 21 rather than 22 because 2 Could rows (Agent #3 #10 + Agent #3 #11) are "subsumed by row 16" (Agent #3 #1 Should — canPop discipline) — same navigation fix covers all three sites.

## Triage strategy

- **User chose:** blanket `fix blocker and should` per Phase 04 precedent (verbatim) — "All 2 Blockers → fix; All 20 Shoulds → fix (including overlaps — one fix commit covers cross-lens duplicates; §3 rows cite both references); All 20 Coulds → defer-to-phase-15 OR won't-fix (purely style items); All 45 Noteds → observation."
- **Default for ambiguity:** lean toward `fix` over `waive` (Phase 04 precedent: honesty and completeness over shortcuts)
- **Cross-lens preservations:** 4 groups preserved under 2+ rows with cross-references (no dedup, Phase 04 convention):
  1. Bare-catch at `location_permission_flow.dart:58-60` — rows 7 (Agent #1 #3 Should) + 12 (Agent #2 #6 Should) + 29 (Agent #2 #12 Could) = ONE fix, 3 §3 rows, same commit hash
  2. iOS auto-resume (Phase 15 deferral) — rows 6 (Agent #1 #2 Should waived) + 59 (Agent #2 #15 Noted) + 62 (Agent #2 #18 Noted) = ONE waiver, 3 rows
  3. pumpAndSettle banner tests — rows 4 (Pre-class #7 Should) + 17 (Agent #3 #2 Should) = ONE fix, 2 rows
  4. POC artefact path drift — rows 3 (Pre-class #2 Should) + 73 (Agent #4 #2 Noted) = ONE fix, 2 rows
  5. GpsError → ErrorState + dead-code consolidation — rows 2 (Agent #2 #2 Blocker) + 28 (Agent #2 #11 Could) = ONE fix, 2 rows
  6. Partial-activation leak + _currentSessionId ordering — rows 1 (Agent #2 #1 Blocker) + 9 (Agent #2 #3 Should) = ONE fix, 2 rows
  7. canPop/go navigation discipline — rows 16 (Agent #3 #1 Should) + 34 (Agent #3 #10 Could) + 35 (Agent #3 #11 Could) = ONE fix sweeping all 3 sites, 3 rows

## Atomic commits on main (Plan 06-03 trail)

| # | Hash | Message |
|---|------|---------|
| 1 | `6c4bf39` | docs(06-rev): pre-class 8 CONTEXT handoff items into §2 |
| 2 | `45fbc8c` | docs(06-rev): build SC#4 OEM workaround plan table in §2 |
| 3 | `693181f` | docs(06-rev): consolidate 4-agent audit findings into 06-REVIEW.md §2 |
| 4 | `7b2a491` | docs(06-rev): capture user triage decisions into 06-REVIEW.md §3 |
| 5 | (metadata commit — this SUMMARY + STATE.md + ROADMAP.md) | docs(06-03): complete pre-class + 4-agent audit + triage plan |

## Handoff to Plan 06-04 — Adversarial wave prerequisites (all verified)

Plan 06-04 authors 5 permanent unit tests + 1 throwaway CI branch. Every checkpoint below is pre-verified by Agent #4 in §2:

- [x] **Test #1 MethodChannel sync** — Swift channel literal in `ios/Runner/AppDelegate.swift` is **ABSENT** (grep → 0 matches; only prose comments about Xcode 26-stripped bridge). Test file map: Kotlin `BootCompletedReceiver.kt` + Dart `boot_completed_watchdog.dart` + Dart `ios_significant_change_watchdog.dart` only. Inertness guard + docstring cross-ref to Phase 15 FlutterImplicitEngineDelegate rewire for iOS side. **RESEARCH Open Question 1 CLOSED.**
- [x] **Test #3 OemDetector ambiguous fixtures** — 6 fixtures sketched by Agent #4 (each resolves deterministically per regex order Xiaomi → Samsung → Huawei → OnePlus → Oppo → Other):
  1. `manufacturer="Google" brand="aosp"` → no regex match → `OtherOem` (regression guard vs future aosp matchers)
  2. `manufacturer="Xiaomi" brand="Redmi"` + build MIUI → first regex `xiaomi|redmi|poco` → `XiaomiFamily` (order guard)
  3. `manufacturer="HUAWEI" brand="HONOR"` → `huawei|honor` → `HuaweiFamily` (parent + sub-brand present)
  4. `manufacturer="OPPO" brand="Realme"` → OnePlus miss, Oppo `oppo|realme` match → `OppoFamily` (OnePlus must not shadow Oppo)
  5. `manufacturer="OnePlus" brand="OnePlus"` → `oneplus` → `OnePlusFamily`
  6. `manufacturer="samsung" brand="xiaomi"` → Xiaomi regex wins over Samsung (Xiaomi ordered first) → `XiaomiFamily` (deterministic tie-break)
- [x] **Test #4 Platform manifests** — AndroidManifest required `uses-permission`: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` — all present. Info.plist required keys: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes[location]`, `NSCameraUsageDescription` (Phase 11 placeholder), `NSPhotoLibraryUsageDescription` (Phase 11 placeholder) — all present. **No drift.**
- [x] **Test #5 Android boot receiver contract** — class path `app.gosl.mirkfall.BootCompletedReceiver` matches Kotlin `package app.gosl.mirkfall` + class name. Kotlin channel literal `"app.gosl.mirkfall/boot_watchdog"` at `BootCompletedReceiver.kt:55`. Manifest `<receiver android:name=".BootCompletedReceiver">` at `AndroidManifest.xml:88` resolves via `applicationId`. Android entry-point name `runBootWatchdogEntryPoint` at `BootCompletedReceiver.kt:62` matches Dart `@pragma('vm:entry-point')` function at `boot_completed_watchdog.dart:108-109`. **All 4 sides aligned.**
- [x] **Test #6 Adversarial branch CI** — current `.github/workflows/ci.yml:3-7` = `on.push.branches: [main]` + `on.pull_request.branches: [main]`. No adversarial trigger exists yet. Plan 06-04 to inline-expand to `[main, 'adversarial/**']` on throwaway branch only; main stays `[main]`-only after branch deletion (Phase 04 precedent).
- [x] **ROADMAP SC#1 amendment text** — current `.planning/pocs/phase-05/` → should be `docs/qual-01-02-poc.md + docs/poc-artifacts/` (Android PASS at `docs/poc-artifacts/test2-full.png` 342 fixes / 28.6 min / PASS; iOS PASS-with-caveat 82 fixes / 13.5 min; OEM Xiaomi/Samsung/Huawei/OnePlus deferred Phase 15). Suggested commit: `docs(06-rev): amend ROADMAP.md SC#1 to match docs/ artifact location`.
- [x] **dart format drift watch** — `dart format --line-length 160 --set-exit-if-changed lib/ test/ tool/` → **exit 0** (208 files, 0 changed, 0.51 s). **No drift.**

## Handoff to Plan 06-05 — Fix loop batch strategy (Phase 04 precedent)

Plan 06-05 batches the 21 fix-this-phase findings (2 Blockers + 19 Shoulds + 0 uncovered Coulds — Could rows 28, 29, 34, 35 are subsumed under grouped Should fixes) per Phase 04-05 precedent (batched strategy over literal per-finding protocol).

**Proposed fix batches (cross-lens grouping respected):**

1. **Batch A — Controller correctness (§3 rows 1 + 2 + 9 + 28):** Blocker fixes (partial-activation leak + GpsError→ErrorState contract) + Agent #2 #3 (_currentSessionId ordering) + Agent #2 #11 (dead-code consolidation). ONE commit in `lib/application/controllers/active_session_controller.dart` + `lib/application/state/active_session_state.dart` (if docstring-side fix) + test updates.
2. **Batch B — Permission flow (§3 rows 7 + 12 + 29):** Bare-catch logging + Agent #2 #12 test coverage. ONE commit in `lib/application/permissions/location_permission_flow.dart` + `test/application/permissions/location_permission_flow_test.dart`.
3. **Batch C — Stop() idempotence + error handling (§3 rows 10 + 11 + 13):** Re-entrant protection + bare-catch logging + _onFix try/catch. ONE commit in `active_session_controller.dart`.
4. **Batch D — iOS Info.plist (§3 row 5):** Add UIBackgroundModes fetch. ONE commit in `ios/Runner/Info.plist`.
5. **Batch E — SessionId.parse (§3 row 8):** Defensive factory mirror. ONE commit in `lib/domain/ids/session_id.dart`.
6. **Batch F — Test suite additions (§3 rows 14 + 15 + 18 + 19):** Rename misnamed test + new `test/application/settings/**` directory + autoStart widget test + stronger pop(false) assertion. ONE commit per test file OR ONE batched.
7. **Batch G — UI polish (§3 rows 16 + 20 + 21 + 22):** canPop/go discipline sweep (covers rows 34 + 35 too) + ULID minting extraction + build() init side-effect + mounted guard.
8. **Batch H — Widget test hygiene (§3 rows 4 + 17):** pumpAndSettle → bounded pump sweep in banner tests.
9. **Batch I — ROADMAP SC#1 amendment (§3 row 3):** path fix + SC#1 wording update. ONE commit in `.planning/ROADMAP.md`.
10. **Batch J — Waiver documentation (§3 row 6):** inline waiver note in `lib/infrastructure/platform/ios_significant_change_watchdog.dart` docstring + `06-REVIEW.md` §5 CI-green block closure.

Batching granularity trades bisectability (git bisect locates the batch, not individual finding) for wall-clock parallelism (~21 CI rounds collapses to ~10 sequential commits). `.fixes-expected=21` snapshot can be preserved for the historic record per Phase 04 convention; Plan 06-05 should accept the verify assertion as deliberately looser at batch scope.

## Surprise findings (NOT in pre-class)

Surprise Blockers discovered by agent audit (not flagged by CONTEXT):

1. **Agent #2 #1 [Blocker] Partial activation leaks active DB row on start() failure** — NOT in CONTEXT pre-class; discovered by Agent #2 controller lens. Blocker #1 of Phase 06. Concrete fix path clear (move `_currentSessionId` assignment BEFORE activate; wrap activate→initialize→listen in try/catch that calls `sessionStore.deactivate(id)` on failure).
2. **Agent #2 #2 [Blocker] GpsError in start() does NOT transition to ErrorState contra documented contract** — NOT in CONTEXT pre-class; discovered by Agent #2 lens reading docstring + sealed state file. Blocker #2 of Phase 06. User triage confirms fix; Plan 06-05 Batch A resolves whether code or doc wins (UI Plan 05-04 pattern-matches `AsyncValue.error` today, suggesting doc update path; but user default-lean-to-fix may prefer code update to `AsyncData(ErrorState(e))`).

Both Blockers are corrections to controller lifecycle invariants — architecturally self-contained (no infra/UI changes), fixable in single Batch A commit per the handoff strategy above. No architectural Rule 4 decisions required.

## Task commits

Per-task commits (atomic, plan tags `06-rev` / `06-03`):

1. **Task 1 (Pre-class 8 CONTEXT items into §2)** — `6c4bf39` (docs, orchestrator sub-agent)
2. **Task 2 (SC#4 OEM workaround table into §2)** — `45fbc8c` (docs, orchestrator sub-agent)
3. **Task 3 (4-agent consolidation into §2)** — `693181f` (docs, orchestrator sub-agent — Task 3a spawned agents; Task 3b consolidation)
4. **Task 4 (checkpoint — user triage)** — no code commit (checkpoint task; user triage captured in §3 via Task 5)
5. **Task 5 (§3 triage table capture)** — `7b2a491` (docs — this continuation agent)

**Plan metadata commit:** (this summary + STATE.md + ROADMAP.md + REQUIREMENTS.md updates)

## Files Created/Modified

- `.planning/phases/06-review-gate-gps/06-REVIEW.md` — §3 populated (87 rows; §1 + §1b + §2 + §4 + §5 untouched — byte-verified via `grep -n "^## "`)
- `.planning/phases/06-review-gate-gps/06-03-SUMMARY.md` — this file
- `.planning/STATE.md` — advance current_plan 06-03 → 06-04; add decisions; record session
- `.planning/ROADMAP.md` — Phase 06 progress (3/5 plans complete)

## Decisions Made

See frontmatter `key-decisions` for the canonical list. Summary: blanket-fix per Phase 04 precedent, Agent #1 #2 waived (Phase 15 deferral), 2 won't-fix for style items (Agent #4 #11 name-correct, Agent #4 #13 Python one-liner), cross-lens preservation (7 groups), SC#4 OEM 7/7 coverage (sealed-exhaustiveness), Swift absence confirmed.

## Deviations from Plan

None — plan executed as specified. Task 3 was orchestrator-executed (parallel wave spawning is an orchestrator responsibility, not sub-agent); Task 4 checkpoint returned structured state for user triage which user responded to in-session; Task 5 continuation agent (this instance) executed §3 capture + SUMMARY + state updates verbatim per resume_instructions.

.audit-findings-scratch.md intentionally retained on disk for Plan 06-05 to reference raw agent output; Plan 06-05 will delete this scratch file per its own cleanup discipline.

## Issues Encountered

None. `gsd-tools.cjs commit` subcommand had a pathspec parsing quirk with the `§3` unicode character in the commit message on Windows — worked around by using direct `git add` + `git commit -m` which succeeded on first attempt. No impact on plan execution.

## User Setup Required

None — no external service configuration required (markdown-only changes + state updates).

## Next Phase Readiness

- **§3 triage table gate-closed per CONTEXT.md:** every Blocker = `fix`; every Should = `fix` OR `waived (rationale)` with non-empty Rationale column (Agent #1 #2 waiver rationale cites Phase 05 STATE.md Xcode 26 strip decision).
- **Plan 06-04 fully unblocked:** adversarial readiness checklist all pre-verified; file maps locked; fixtures sketched; CI trigger expansion strategy clear.
- **Plan 06-05 fully scoped:** 21 fix-this-phase findings organized into 10 batches per Phase 04-05 precedent; cross-lens groupings explicit; test coverage gaps enumerated.
- **Pattern locked for future review gates:** 4-parallel-agent audit + cross-lens preservation + pre-class baseline table + blanket triage — third successful cycle (02 → 04 → 06). Reusable template for Phases 08 / 10 / 12 / 14 / 16.

## Self-Check: PASSED

Verified claims on disk before state update:
- [x] `06-03-SUMMARY.md` exists
- [x] `06-REVIEW.md` exists
- [x] Commit `6c4bf39` (Task 1 pre-class 8) present in git log
- [x] Commit `45fbc8c` (Task 2 SC#4 OEM table) present in git log
- [x] Commit `693181f` (Task 3 4-agent consolidation) present in git log
- [x] Commit `7b2a491` (Task 5 §3 triage) present in git log
- [x] SUMMARY contains "Adversarial readiness checklist" heading
- [x] SUMMARY contains "Test #1 MethodChannel sync"
- [x] SUMMARY contains "ROADMAP SC#1 amendment text"
- [x] SUMMARY contains "_copyFor() coverage check"
- [x] §3 table counts: 2 Blocker + 20 Should + 20 Could + 45 Noted = 87 rows (verified via grep counts)
- [x] §3 Blockers with decision != fix: 0 (CONTEXT.md gate-closed)
- [x] §3 Shoulds waived with empty Rationale: 0 (CONTEXT.md gate-closed)
- [x] §1 / §1b / §2 / §4 / §5 untouched (section heading line numbers 7 / 114 / 284 / 380 / 414 verified)

---
*Phase: 06-review-gate-gps*
*Plan: 03 complete 2026-04-20*
*Next: Plan 06-04 (adversarial wave — 5 unit tests + 1 throwaway CI branch)*
