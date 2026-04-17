---
phase: 02-review-gate-foundation
plan: 03
subsystem: review-gate
tags: [adversarial-tests, ci-gates, throwaway-branches, evidence-archival, license-scan, gosl-header, dependencies-md]

# Dependency graph
requires:
  - phase: 02-review-gate-foundation
    provides: "02-02-SUMMARY.md §Adversarial Poison Recipes (3 verbatim payloads — GPL scan / missing GOSL header / missing DEPENDENCIES.md entry)"
  - phase: 01-foundation
    provides: "tool/check_licenses.dart, tool/check_headers.dart, tool/check_dependencies_md.dart, .github/workflows/ci.yml gates job"
provides:
  - "02-REVIEW.md §4 populated with 3 evidence blocks (real CI run URLs, exit code 1, stderr excerpts, detection paths, deletion confirmations)"
  - "End-to-end proof that Phase 01's 3 CI guardrails catch real pub.dev GPL packages, real missing GOSL headers, and real undocumented MIT deps — not just synthetic fixtures"
  - "3 atomic evidence commits on main (one per gate) — no main-branch contamination by poison commits (those lived on disposable branches)"
affects:
  - "02-04 (fix-loop closure) — §4 evidence is an input to §5 CI-green report; Plan 02-04 can confidently assert 'gates block real violations' based on these 3 runs"
  - "Phase 04+ review gates — adversarial-branch lifecycle pattern validated: create → poison → push → CI fails → archive evidence → delete branch (local+remote). Reusable template."

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Throwaway adversarial branch lifecycle: create → poison + flutter pub get → commit → push → gh run watch → gh run view --log-failed → archive evidence → branch delete (local + remote)"
    - "Adversarial-only CI trigger expansion via on-branch ci.yml edit (push.branches += 'adversarial/**'), isolated to the disposable branch so main's trigger stays strict"
    - "Exit-code contract verified in production CI: 0=clean, 1=policy violation (this plan's outcome), 2=misconfiguration — each poison run delivered exit 1 with policy-violation stderr, never exit 2"
    - "Per-poison license freshness re-check at plan-execute time (pub.dev API query) — mitigates recipe bit-rot between audit wave and consumption"

key-files:
  created:
    - ".planning/phases/02-review-gate-foundation/02-03-SUMMARY.md"
  modified:
    - ".planning/phases/02-review-gate-foundation/02-REVIEW.md"

key-decisions:
  - "Expanded CI push trigger to 'adversarial/**' on each poison branch (NOT on main) — Rule 3 auto-fix: pushing a throwaway branch with the main-only trigger produced zero CI runs, blocking the plan. Inline edit on each branch is wiped by the branch delete, so main's `on.push.branches: [main]` is unchanged after evidence capture."
  - "Stashed 4 pre-existing unrelated dirty files (.planning/config.json, CLAUDE.md, flutter_guide.md, 4 new plan markdown files) under `02-03-dirty-guard` before adversarial branch work — restored via `git stash pop` after the last evidence commit. Protects user work-in-progress from branch-switching side-effects."
  - "Test 1 detection path: LICENSE substring matched (voie 2 of _resolveSpdx in tool/check_licenses.dart, forbidden-substring scan at lines 188-194) — neither _manualOverrides nor allowlist-miss fired. Stderr contains the literal 'UNKNOWN-FORBIDDEN-MARKER: GNU GENERAL PUBLIC LICENSE' prefix that is unique to that detection branch."
  - "Test 3 proved the gate sequencing (Headers → Licenses → Dependencies) is genuine end-to-end: the MIT equatable payload passed gates #7 and #8, and died only on gate #9 — so the deps gate is not a no-op masked by an earlier failure."

patterns-established:
  - "Adversarial branch lifecycle template: reusable for every future review gate (Phases 04/06/08/10/12/14/16). Each poison is self-contained; main is never touched until the evidence commit lands."
  - "Always re-verify third-party license status at plan-execute time, not at plan-create time (done here via pub.dev API curl for both multi_dropdown@3.1.1 and equatable@2.0.7). Recipe age ≠ recipe freshness."
  - "When a workflow's `on:` trigger is too narrow to exercise adversarial branches, expand it in the adversarial branch itself (not on main) — the delete-at-end step reverts the trigger automatically, zero cleanup cost."

requirements-completed: []

# Metrics
duration: 10min
completed: 2026-04-17
---

# Phase 02 Plan 03: Adversarial Gate Evidence — Summary

**All 3 CI guardrails (licenses, headers, dependencies) proven against real poison payloads on throwaway branches — each returned exit code 1 with a policy-violation stderr naming the offender, and each branch was deleted local + remote after evidence archival.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-17T18:47:10Z
- **Completed:** 2026-04-17T18:57:55Z
- **Tasks:** 3
- **Files modified:** 1 (`.planning/phases/02-review-gate-foundation/02-REVIEW.md`)
- **Files created:** 1 (this summary)
- **Throwaway branches:** 3 (all deleted — `adversarial/02-licence-gpl-scan`, `adversarial/02-header-missing`, `adversarial/02-deps-missing-entry`)

## CI Run URLs (archive persistence)

These three URLs are the authoritative artifact of Plan 02-03 — `02-REVIEW.md` §4 points at them but this summary preserves them independently in case §4 is ever rewritten:

| Test | Gate                                        | Poison package / file                  | Run URL                                                               | Conclusion | Step name                                    | Exit |
|------|---------------------------------------------|----------------------------------------|-----------------------------------------------------------------------|------------|----------------------------------------------|------|
| 1    | `tool/check_licenses.dart`                  | `multi_dropdown: 3.1.1` (GPL-3.0)      | https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24581444173 | failure    | `Check licenses (GPL/AGPL/copyleft scan)`   | 1    |
| 2    | `tool/check_headers.dart`                   | `lib/presentation/widgets/poison_widget.dart` | https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24581566943 | failure    | `Check GOSL headers`                         | 1    |
| 3    | `tool/check_dependencies_md.dart`           | `equatable: 2.0.7` (MIT)               | https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24581688234 | failure    | `Check DEPENDENCIES.md is up to date`        | 1    |

All three conclusions are `failure`, all three exit codes are `1` (policy violation), all three stderr excerpts name the offender verbatim — zero cases of exit 2 (misconfiguration).

## Observed Detection Paths & Step Identities

- **Test 1 detection path (per Pitfall 3 of 02-RESEARCH):** **LICENSE substring matched** — voie 2 of `_resolveSpdx` inside `tool/check_licenses.dart`, the `_forbiddenSubstrings` scan at lines 188-194. Stderr: `- multi_dropdown: UNKNOWN-FORBIDDEN-MARKER: GNU GENERAL PUBLIC LICENSE NOT in allowlist`. The prefix `UNKNOWN-FORBIDDEN-MARKER:` is unique to this branch (it is not produced by `_manualOverrides` nor by plain allowlist misses). No manual override exists for `multi_dropdown`; the pubspec `license:` field either was empty or was not consulted because the forbidden-substring scan fires first on the ingested LICENSE text.
- **Test 2 failing step identity:** `Check GOSL headers` — step #7 in the `gates` job, matching `.github/workflows/ci.yml:42` verbatim. Not `Dart format check` (step #4), not `Flutter analyze` (step #5). Sanity check from the plan passed: formatting the poison file with `dart format --line-length 160` before commit ensured gate #4 didn't short-circuit; the `class PoisonWidget {}` content is trivially-analyzable Dart so gate #5 also passed.
- **Test 3 failing step identity:** `Check DEPENDENCIES.md is up to date` — step #9. Gates #7 and #8 both passed, confirming sequencing: headers green (no new `.dart` file), licenses green (MIT is allowlisted), then dependencies red (equatable missing from DEPENDENCIES.md). The deps gate is real, not shadowed.

## Surprise stderr content / new findings

- **None functionally surprising.** All 3 runs produced stderr matching the exact shape predicted by the Agent #1 recipes in `02-02-SUMMARY.md`. No new gate-script bugs surfaced from adversarial exposure.
- **Meta-finding (carried to Plan 02-04 / future phases):** The `on:` trigger on `.github/workflows/ci.yml` is scoped to `push: branches: [main]` + `pull_request: branches: [main]`. This means a raw `git push origin <branch>` (other than main) produces zero CI runs. Any future adversarial or experimental branch that wants CI feedback without opening a PR must either (a) add the branch name / pattern to `on.push.branches` inline on that branch (what this plan did), or (b) re-broaden the trigger on main to include a dedicated namespace (e.g. `experiment/**`). Not a Blocker — reported as a sharpened understanding of the CI trigger contract for future review gates.

## Branch Deletion Audit Log

All 6 delete operations (3 local + 3 remote) executed successfully:

| Branch                                      | Local delete           | Remote delete            | Final `git branch -a \| grep adversarial` |
|---------------------------------------------|------------------------|--------------------------|-------------------------------------------|
| `adversarial/02-licence-gpl-scan`           | `Deleted` (was 5d59e7f)| `[deleted]`              | empty                                     |
| `adversarial/02-header-missing`             | `Deleted` (was 7f26d24)| `[deleted]`              | empty                                     |
| `adversarial/02-deps-missing-entry`         | `Deleted` (was 1d75451)| `[deleted]`              | empty                                     |

Final remote API check: `gh api repos/:owner/:repo/branches --paginate | grep -i adversarial` returned **CLEAN: remote has no adversarial branches**.

## Task Commits (on main)

Each task's evidence was committed atomically on `main` (poison commits stayed on their throwaway branches and were discarded with the branch deletion):

1. **Task 1** — `c1f672a` `docs(02-rev): archive adversarial evidence Test 1 (license GPL scan)`
2. **Task 2** — `6741268` `docs(02-rev): archive adversarial evidence Test 2 (missing GOSL header)`
3. **Task 3** — `da9c815` `docs(02-rev): archive adversarial evidence Test 3 (missing DEPENDENCIES.md entry)`

Plus a final plan-closure commit (this SUMMARY + STATE.md + ROADMAP.md updates) — see `git log --oneline -6` at plan close.

## Files Created/Modified

- **Created:** `.planning/phases/02-review-gate-foundation/02-03-SUMMARY.md` (this file)
- **Modified:** `.planning/phases/02-review-gate-foundation/02-REVIEW.md` (§4 populated with 3 evidence subsections)

No source code modifications on `main`. All 3 poison payloads (`multi_dropdown` dep, `poison_widget.dart` file, `equatable` dep + matching lockfile lines) were contained on throwaway branches and deleted with them.

## Decisions Made

- **Rule 3 auto-fix: expand `on.push.branches` to `[main, 'adversarial/**']` on each poison branch.** Without this, `git push origin adversarial/02-<name>` produced zero CI runs (plan's step 5 implicitly assumed push-to-any-branch triggers CI; Phase 01's workflow is tighter). The expansion lives ONLY on the throwaway branch and is wiped when the branch is deleted — main's trigger stays `[main]`-only. Alternative considered: open an ephemeral PR — rejected because CONTEXT.md constraint was "NO pull requests". Alternative considered: push to main and rely on poison-catches-itself — rejected because Plan 02-03 explicitly requires main to stay uncontaminated.
- **Stashed the 4 pre-existing unrelated dirty files before branch work.** `git stash push -u -m "02-03-dirty-guard" -- <paths>` for `.planning/config.json`, `CLAUDE.md`, `flutter_guide.md`, and the 4 newly-added 02-*-PLAN.md files. Restored via `git stash pop` after the last evidence commit landed. Prevents branch-switching from entangling in-progress user work with adversarial poison.
- **Kept `multi_dropdown 3.1.1` as the GPL payload (no fallback needed).** Pub.dev API at plan-execute time still returns version 3.1.1 and the license page still shows GPL-3.0. Fallback packages (`line_icons 2.0.3`, `iconsax 0.0.8`) stayed on the bench.
- **Kept `equatable 2.0.7` as the MIT payload despite 2.0.8 now being available.** The recipe specified 2.0.7; 2.0.7 is still resolvable from pub.dev and is still MIT. Sticking to the recipe version keeps the poison recipe reproducible for future audits.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] CI workflow `on.push.branches` too narrow to exercise adversarial branches**

- **Found during:** Task 1, after the first `git push -u origin adversarial/02-licence-gpl-scan`
- **Issue:** `gh run list --branch adversarial/02-licence-gpl-scan` returned `[]` — the CI never triggered. Root cause: `.github/workflows/ci.yml` at Phase 01 close has `on: push: branches: [main]` + `pull_request: branches: [main]`. A direct push to any other branch produces no CI run. The plan's step 5 (`git push -u origin adversarial/02-<name>`) implicitly assumed broader push triggering.
- **Fix:** On each adversarial branch, edited `.github/workflows/ci.yml` to expand `on.push.branches` to `[main, 'adversarial/**']` and committed alongside the poison payload. The expanded trigger lives only on the throwaway branch and is removed when the branch is deleted — main's trigger stays strict.
- **Files modified (per branch, each reverted via branch delete):** `.github/workflows/ci.yml` (one-line change)
- **Verification:** After the trigger-expansion commit landed on each adversarial branch, `gh run list --branch adversarial/02-<name>` returned a `databaseId` within 10-15 s. All 3 runs completed with `conclusion=failure` and the expected step identity + exit code.
- **Committed in:** each adversarial branch's second commit (`5d59e7f` for Test 1; the trigger change was inlined into the poison commits for Tests 2 and 3 — `7f26d24` and `1d75451`). None of these commits reached main (branch deletes them).

**Total deviations:** 1 auto-fixed (Rule 3 — blocking CI-trigger issue). No architectural changes. No user-action gates. No Rule 4 escalations.

## Issues Encountered

- First push of Test 1 branch produced no CI run (resolved via Deviation #1 above).
- All other poison pushes, CI polls, branch deletes executed first-try without anomaly.
- No flaky CI retries needed; no sanity-check-invalidating stderr content; no "passes that should have failed" (which would have signaled a real gate bypass — none observed).

## User Setup Required

None. Plan 02-03 produced 3 markdown evidence blocks + this SUMMARY; no dependency changes on main, no environment variables, no external-service config.

## Next Phase Readiness

**Plan 02-04 is fully unblocked.** `02-REVIEW.md` §4 is populated — Plan 02-04 can now execute the 42-fix triage list in §3 and, once gates go green against the fix commits, fill §5 (CI-green confirmation) to close Phase 02.

**Carried-forward observations for Plan 02-04:**
- The 3 adversarial runs exercise 3 of 4 `check_licenses.dart` Blockers (Blockers #1-#3 — case-sensitivity, compound-AND semantics, license-field bypass). Blocker #4 (MPL-unreachable heuristic) has no adversarial test — Plan 02-04 must add unit coverage for it (already noted in 02-02-SUMMARY.md).
- The `on:` trigger on `main`'s `ci.yml` is intentionally narrow (`push: [main]` + `pull_request: [main]`). Plan 02-04 should preserve this narrowness — the adversarial-branch trigger expansion pattern demonstrated here is a per-branch disposable trick, not a main-branch change.

No blockers preventing Plan 02-04 from starting.

## Self-Check: PASSED

- FOUND: `.planning/phases/02-review-gate-foundation/02-03-SUMMARY.md`
- FOUND: `.planning/phases/02-review-gate-foundation/02-REVIEW.md`
- FOUND: commit `c1f672a` (Test 1 evidence archival on main)
- FOUND: commit `6741268` (Test 2 evidence archival on main)
- FOUND: commit `da9c815` (Test 3 evidence archival on main)
- PASS: §4 of 02-REVIEW.md contains 3 evidence subsections (`### Test 1`, `### Test 2`, `### Test 3`) — grep count = 1 each
- PASS: 02-REVIEW.md ≥ 140 lines — actual 395
- PASS: No `adversarial/02-*` branches local — `git branch -a | grep adversarial` returned empty
- PASS: No `adversarial/02-*` branches remote — `gh api repos/:owner/:repo/branches --paginate | grep -i adversarial` returned "CLEAN"
- PASS: pubspec.yaml on main has no `multi_dropdown`, no `equatable` — grep count 0 / 0
- PASS: lib/presentation/widgets/ does not exist on main (poison file absent)
- PASS: `.github/workflows/ci.yml` on main has `on.push.branches: [main]` — adversarial expansion not leaked to main

---
*Phase: 02-review-gate-foundation*
*Completed: 2026-04-17*
