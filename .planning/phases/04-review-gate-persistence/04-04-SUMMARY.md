---
phase: 04-review-gate-persistence
plan: 04
subsystem: review-gate
tags: [adversarial, ci-poison, drift-schema-guard, check-domain-purity, schema-sanity, regression-guard, review-artefact, dart-format-drift]

# Dependency graph
requires:
  - phase: 04-review-gate-persistence
    provides: 04-03-SUMMARY.md §Adversarial poison verifications (Plan 04-04 input — poison recipes re-verified against Phase 03 code)
  - phase: 03-persistence-domain-models
    provides: check_domain_purity.dart (tool/, Phase 03 SC#4 guardrail) + drift schema dump guard (ci.yml step `Check drift schema (current) is committed and fresh`, Phase 03 schema fixture discipline) + SchemaSanityChecker + MigrationFailureException (lib/infrastructure/db/schema_sanity.dart + lib/domain/errors/migration_errors.dart)
  - phase: 02-review-gate-foundation
    provides: inline `on.push.branches: += 'adversarial/**'` trigger expansion pattern (Option B, Phase 02 02-03 precedent)
provides:
  - §4 adversarial evidence populated with 3 evidence blocks (Test #1 domain purity double violation / Test #2 drift schema dump stale / Test #3 permanent row-loss regression guard)
  - test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart — permanent regression guard on main; caught by `dart test -t migration`
  - deferred-items.md item #1 — pre-existing dart format drift on main (SURPRISE BLOCKER discovered during this plan, not caused by any poison) — handoff to Plan 04-05 fix loop
affects: [04-05, 05-gps-session-lifecycle, 06-review-gate-gps]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Adversarial branch-and-CI workflow reused from Phase 02 02-03 — push poisoned branch with inline `on.push.branches` trigger expansion, observe failing CI, archive evidence (branch + poison commit + run URL + gate step + stderr excerpt + exit code), delete branch local + remote. Pattern stable across both review gates."
    - "False-positive guard on permanent adversarial unit tests — assert an intermediate invariant (DELETE actually removed rows) BEFORE the main `throwsA` expectation, so a future SQL/fixture refactor that neutralises the adversary fails loudly rather than silently passing. Validated by mutation experiment (DELETE WHERE 1=0 → `test would be inert`)."
    - "Scope boundary for pre-existing drift — adversarial branches only fix enough to reach the target gate; unrelated drift logged to `deferred-items.md` for the fix loop plan (Plan 04-05). Keeps adversarial commits focused on the poison semantics."
    - "build_runner prerequisite discipline for Test #2 (drift schema dump stale) — running `dart run build_runner build --delete-conflicting-outputs` locally before commit is mandatory, otherwise CI's `flutter analyze` (step 6) fails first on stale `.g.dart` and evidence lands on the wrong gate (RESEARCH Pitfall 1). Confirmed practically on Test #2."

key-files:
  created:
    - .planning/phases/04-review-gate-persistence/04-04-SUMMARY.md
    - .planning/phases/04-review-gate-persistence/deferred-items.md
    - test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart
  modified:
    - .planning/phases/04-review-gate-persistence/04-REVIEW.md

key-decisions:
  - "Scope-boundary application: pre-existing 61-file dart format drift is NOT in scope of Plan 04-04 (adversarial observation) — logged to deferred-items.md #1 for Plan 04-05. Adversarial branches DID include the format reflow as a prerequisite-for-CI-reach-target-gate fix, deleted with the branches; main's drift is untouched."
  - "Inline inertness guard baked into Test #3 permanent regression — the expect-less-than assertion BEFORE `throwsA` means future SQL/fixture refactors can't silently neutralise the adversary. Proven by mutation experiment (DELETE WHERE 1=0 → fails loudly)."
  - "Test #2 amended-commit flow rejected in favour of a clean single poison commit with prerequisites pre-run — `build_runner build` + format fix were done BEFORE the first `git commit` on the Test #2 branch, so no `--force-with-lease` re-push was needed for Test #2 (unlike Test #1 where the format drift discovery forced one amend)."
  - "Option B (poison + trigger in same commit) reused from Phase 02 02-03 for both Test #1 and Test #2 — no separate `test(adversarial): enable CI on adversarial/** branches` commit, which matches Phase 02 precedent and keeps the branch single-commit for easier cleanup/audit."
  - "Drift `hide JsonKey` clause on Test #1 poison import — needed because `package:drift/drift.dart` re-exports `JsonKey` which collides with `package:freezed_annotation/freezed_annotation.dart`'s `JsonKey` used throughout `marker.dart`; without `hide` the file has ambiguous_import errors that make flutter analyze fail before check_domain_purity runs. The check_domain_purity regex is anchored on `package:drift(?:/|['\"])` and matches regardless of show/hide clauses — confirmed in the CI log."

patterns-established:
  - "3-branch evidence archive structure — Tests 1-2 use {Branch + Poison commit + CI-trigger commit + Run URL + Job + Gate step + Exit code + stderr excerpt + Confirms + Surprise-finding annotation}; Test 3 permanent-test uses {Type + File + Commit + Tags + Test result + Behavior proven + False-positive guard + Confirms}. Both formats stable and re-applicable to future review-gate adversarial waves (Phases 06, 08, 10, 12, 14, 16)."
  - "Pre-existing drift surfaced during adversarial wave is a transparent finding, not hidden — deferred-items.md co-located with phase plans + referenced from §4 Test 1 'Surprise finding during execution' and Test 2 'Note on branch format scope'. Keeps triage discipline honest (no silent clean-ups)."

requirements-completed:
  - SC#1
  - SC#2

# Metrics
duration: 15 min
completed: 2026-04-18
---

# Phase 04 Plan 04: Adversarial Evidence + Permanent Regression Guard Summary

**Both Phase 03 new CI guardrails (domain purity + drift schema dump) proven to fire on real violations — Test #1 + Test #2 branches pushed, CI observed red on target gates with correct exit 1, branches deleted (local + remote). Permanent regression test `migration_v1_to_v2_data_loss_test.dart` committed on main as forever-guard against SchemaSanityChecker bypass. Surprise finding: pre-existing 61-file dart format drift on main, unrelated to poisons, logged to deferred-items.md for Plan 04-05 fix loop.**

## Performance

- **Duration:** ~15 min wall-clock (plan total from init to final summary commit)
- **Tasks:** 4 (Task 1 Test #1 / Task 2 Test #2 / Task 3 Test #3 / Task 4 summary)
- **Files created:** 3 (04-04-SUMMARY.md, deferred-items.md, migration_v1_to_v2_data_loss_test.dart)
- **Files modified:** 1 on main (04-REVIEW.md — 3 section edits, each as its own atomic commit)

### Per-task wall-clock

| Task | What                                              | Duration | Notes                                                                                      |
|------|---------------------------------------------------|----------|--------------------------------------------------------------------------------------------|
| 1    | Test #1 domain-purity double violation            | 7m 43s   | Includes 1 `--force-with-lease` re-push after discovering pre-existing format drift on main |
| 2    | Test #2 drift schema dump stale                   | 4m 12s   | Clean single-poison-commit flow (no re-push)                                               |
| 3    | Test #3 permanent row-loss regression guard       | ~3 min   | Includes inline mutation experiment to validate the inertness guard                        |
| 4    | Final sweep + 04-04-SUMMARY.md                    | —        | Shared with post-Task-3 work                                                               |

## 3 Evidence Run URLs / Commit Hashes

**Archive persistence — in case §4 is ever regenerated from scratch, the canonical evidence lives here:**

- **Test #1 CI run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24611059783 (conclusion=failure on `Check domain purity (lib/domain/ imports)`, exit 1)
- **Test #2 CI run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24611132558 (conclusion=failure on `Check drift schema (current) is committed and fresh`, exit 1)
- **Test #3 commit hash:** `9c32eb1` on `main` — `test(04-rev): add SchemaSanityChecker row-loss regression guard` (local `dart test ...` → `All tests passed!`)

Earlier Test #1 run that failed on the wrong step (pre-existing format drift surfaced): https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24611006850 — kept as a reference for the deferred-items.md #1 discovery.

## Target Step Observed per CI Test

| Test | Expected target step                                   | Observed target step                                   | Match? |
|------|--------------------------------------------------------|--------------------------------------------------------|--------|
| #1   | `Check domain purity (lib/domain/ imports)`            | `Check domain purity (lib/domain/ imports)` — exit 1   | YES    |
| #2   | `Check drift schema (current) is committed and fresh`  | `Check drift schema (current) is committed and fresh` — exit 1 | YES |
| #3   | N/A (permanent unit test, not a CI-branch adversary)   | `dart test` green locally with inertness guard active  | YES    |

Both CI tests reached the intended gate with correct exit code 1 (policy violation, NOT exit 2 / misconfiguration). All prior gates passed cleanly on the adversarial branches (after the pre-existing format drift reflow was included in each poison commit).

## Adversarial Poison Recipe Deltas (vs 04-03-SUMMARY.md §Adversarial poison verifications)

- **Test #1 (session.dart + marker.dart):** Agent #1 verification was accurate — both files exist, GOSL headers present, import block stable at the top. Two **deltas** encountered during execution, neither affecting the recipe's validity:
  1. `package:flutter/material.dart` triggered `unnecessary_import` info-level analyze hit because Flutter re-exports some freezed_annotation symbols. Fixed by promoting `unused_import, unnecessary_import` to the existing `ignore_for_file` block on `session.dart`.
  2. `package:drift/drift.dart` triggered `ambiguous_import` on `JsonKey` (drift vs freezed_annotation re-exports). Fixed by `hide JsonKey` on the drift import. Neither delta weakens the poison — check_domain_purity regex catches the import regardless of `hide` clause.
- **Test #2 (notesExtra column):** Agent #1 verification was accurate — `t_sessions` declared at `app_database.dart:36`, insertion point between `notes` and `primaryKey` override. Zero deltas during execution. `dart run build_runner build` regenerated `app_database.g.dart` in 18 s; `drift_dev schema dump` DELIBERATELY NOT RUN. `flutter analyze` stayed green.

Agent #1's "Verdict: Both poison recipes apply to Phase 03 code as-designed" holds — Plan 04-04 did not need to adjust poison file paths, column names, or grep patterns.

## Branch Deletion Audit Log

| Branch                                               | Local deletion          | Remote deletion                                         | Status |
|------------------------------------------------------|-------------------------|---------------------------------------------------------|--------|
| `adversarial/04-domain-import-flutter-and-drift`     | `git branch -D` → OK    | `git push origin --delete` → `- [deleted]` confirmed    | GONE   |
| `adversarial/04-schema-drift-stale`                  | `git branch -D` → OK    | `git push origin --delete` → `- [deleted]` confirmed    | GONE   |

Final verification (post-Task-4 integrity sweep):
- `git branch --list 'adversarial/04-*'` → 0 matches
- `git branch -r --list 'origin/adversarial/04-*'` → 0 matches
- `gh api repos/:owner/:repo/branches --paginate --jq '.[].name' | grep -c '^adversarial/04-'` → 0

All three channels confirm clean. No `adversarial/04-*` leftovers anywhere.

## ci.yml Revert Confirmation

Main's `.github/workflows/ci.yml` `on.push.branches` is back to `[main]` (line 5) — the inline `adversarial/**` expansion existed only on the two throwaway branches and was deleted together with them. No permanent pollution of main's trigger config.

`pull_request.branches` also stays `[main]`-only. Nothing on main references `adversarial/**`.

## Test #3 False-Positive Check

**Result: no RED phase needed + inertness guard explicitly validated.**

The test passed `dart test ...` on its first run (green first-try). To prove it wasn't silently inert, I ran a **mutation experiment**: temporarily replaced `DELETE FROM t_sessions WHERE rowid % 2 = 0` with `DELETE FROM t_sessions WHERE 1=0` (zero rows deleted). The test then failed loudly with:

```
adversarial DELETE did not remove any session row — test would be inert.
before=10 after=10
```

Restored the original adversarial DELETE → green again. The inline `expect(after['t_sessions']! < before['t_sessions']!, isTrue)` assertion is the forever-guard against accidental neutralisation by a future refactor. Permanent test is demonstrably adversarial, not a tautology.

## Surprise Findings

### 1. Pre-existing dart format drift on main (BLOCKER, unrelated to poisons)

**Discovered:** First Test #1 CI run (24611006850) failed on `Dart format check` — an earlier step than the target `Check domain purity`. Investigation showed the same step also fails on main itself (CI run 24610968531 from today's 61-commit docs-only push).

**Scope:** 61 files reformat between developer machines and CI's Flutter 3.41.5 `dart format` rendering. Mix of `.g.dart` generated files (regenerated under slightly different dart SDK patch versions between Phase 03 and now) and hand-written Phase 03 sources.

**Scope boundary applied:** Not caused by adversarial poisons. Not in scope of Plan 04-04 (which is about adversarial observation of Phase 03 NEW guardrails, not maintenance of earlier guardrails). Full detail + recommended fix in `.planning/phases/04-review-gate-persistence/deferred-items.md` item #1.

**Handoff to Plan 04-05:** Fix loop should include a `chore(format): align with CI dart format` commit on main — run `dart format --line-length 160 .` once, commit the 61-file reformat, investigate Dart patch-version drift in CI. This also stabilises CI for all future pushes.

**Impact on adversarial wave:** Both Test #1 and Test #2 branches included the 61-file format reflow alongside the poison so CI could reach the target step. Since branches were deleted, this reflow does NOT pollute main — main's drift is identical before and after Plan 04-04.

### 2. CI main has been red since today's 61-commit push (same root cause)

Before Plan 04-04 started, CI run 24610968531 on main (today's docs-only push of the 61 local Phase 04 commits) completed with `conclusion=failure` on `Dart format check`. Docs-only commits don't touch `.dart` files, so the docs commits didn't cause the breakage — they just happened to be the first push after the format drift became detectable by CI.

This means main's CI has been silently pre-broken ever since Phase 03 was merged without CI exercising it (Phase 03 & 04 were docs-heavy plans). The adversarial wave is what actually surfaced the breakage. A useful meta-observation: **review gates catch CI-pipeline hygiene issues that normal feature phases don't** — another Phase 02 Accumulated Decision validated on second cycle.

### 3. Check_domain_purity detects imports through `hide` clauses (confirmation, not bug)

When Test #1 needed `import 'package:drift/drift.dart' hide JsonKey;` to sidestep freezed_annotation's symbol collision, I was briefly concerned the `hide` clause would confuse the scanner. CI log confirmed the opposite: `check_domain_purity` correctly listed `marker.dart:13: import 'package:drift/drift.dart' hide JsonKey;` as a violation. The tool's regex anchors on the `package:drift(?:/|['"])` prefix and ignores show/hide suffixes — which is correct behavior (forbidden imports don't become permitted via `hide`). Robustness signal, not a bug.

## Issues Encountered

**Issue 1:** First Test #1 push failed on wrong CI step (format, not domain purity). Resolution: incorporated format reflow into the poison commit via `--force-with-lease`. Documented as deferred-items.md #1.

**Issue 2:** Initial poison imports triggered `ambiguous_import` (drift vs freezed_annotation both re-export `JsonKey`) and `unnecessary_import` (flutter re-exports material symbols already in freezed_annotation). Resolution: `hide JsonKey` on drift import + promoted `unused_import, unnecessary_import` into the existing `ignore_for_file` block at file top. Both adjustments are mechanically local to the poisoned files and go away when the throwaway branches are deleted.

## User Setup Required

None. All adversarial activity was:
- `git push` + `gh run watch` (CLI, no UI)
- `git push origin --delete` (CLI cleanup)
- `dart test` local run (no network, no external services)

No credentials, API keys, or user interaction required. Plan was truly autonomous.

## Next Phase Readiness

### Unblocked

- **Plan 04-05 (fix loop):** §4 is fully populated with 3 evidence blocks. Plan 04-05 can read §4 + 04-04-SUMMARY.md to frame the fix loop scope, especially:
  - 35 fix targets from §3 triage (inherited from Plan 04-03)
  - deferred-items.md item #1 (pre-existing format drift, 61 files) — **should be addressed early in 04-05** since every docs commit afterwards will otherwise be red on CI
  - The permanent regression guard `migration_v1_to_v2_data_loss_test.dart` is already green locally; once 04-05 fixes the format drift, it will also run green in CI's `Plain-Dart domain + infra tests` step (currently the step is skipped since CI fails earlier)

### Blockers / concerns for downstream

- **04-05 has to deal with the format drift FIRST**. If the fix loop starts touching other files before running `dart format .` + committing the alignment, every subsequent commit will also be format-red on CI. Recommended order: (a) format-align commit FIRST, (b) then the 35 fix targets grouped by subsystem/file.
- **Phase 05 dependency:** None new from Plan 04-04. Phase 05 waits on Plan 04-05 CI-green confirmation (§5 of 04-REVIEW.md).

## Self-Check: PASSED

Must-haves verification against `04-04-PLAN.md` `must_haves.truths`:

- [x] **Truth 1: Test #1 branch pushed with TWO poison imports, CI failed on `Check domain purity`, listed BOTH violations** — CI run 24611059783, stderr excerpt in §4 Test 1 shows `check_domain_purity: 2 forbidden import(s) under lib/domain/:` followed by both session.dart + marker.dart file:line lines. Exit code 1. Branch deleted.
- [x] **Truth 2: Test #2 branch pushed with notesExtra column + build_runner ran + drift_dev schema dump NOT run, CI failed on `Check drift schema (current) is committed and fresh`** — CI run 24611132558, stderr excerpt in §4 Test 2 shows `::error::drift_schemas/drift_schema_current.json is stale.` and the `git diff --exit-code` output listing the diverged JSON hashes. Exit code 1. Branch deleted.
- [x] **Truth 3: Test #3 permanent test on main exercises assertNoLoss, throws MigrationFailureException, message contains t_sessions + decreased** — commit `9c32eb1` on main, local `dart test ...` output `All tests passed!`. Test file has `expect(() => sanity.assertNoLoss(before, after), throwsA(isA<MigrationFailureException>()...contains('t_sessions')...anyOf(contains('decreased'), contains('lost'))))`. Mutation experiment validated inertness guard.
- [x] **Truth 4: All adversarial CI test stderr excerpts prove exit code 1, not exit 2** — §4 Test 1 and Test 2 evidence blocks both explicitly state "exit code 1 (policy violation, NOT exit 2 / misconfiguration)". Confirmed against CI run logs directly.
- [x] **Truth 5: Both `adversarial/04-*` branches deleted locally AND on remote** — Task 4 integrity sweep confirmed: `local=0 remote_refs=0 gh_remote=0`.
- [x] **Truth 6: Test #3 test file stays on main forever as permanent regression guard** — `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` committed via `9c32eb1`, file path exact, `@Tags(<String>['migration'])` directive present on line 18.
- [x] **Truth 7: No poison commits made it to main** — `git log --oneline` on main shows only `test(04-rev):` + `docs(04-rev):` commits from this plan. Zero `test(adversarial):` commits on main.

Artifact checks:

- [x] `.planning/phases/04-review-gate-persistence/04-REVIEW.md` contains `### Test 1: Domain purity import violation` heading — FOUND (line ~573).
- [x] `04-REVIEW.md` contains `lib/domain/sessions/session.dart` AND `lib/domain/markers/marker.dart` — grep count 11 across §4 evidence block.
- [x] `04-REVIEW.md` contains `drift_schema_current` — grep count 15.
- [x] `04-REVIEW.md` contains `### Test 3: SchemaSanityChecker row-loss detection` — FOUND.
- [x] `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` exists with `@Tags` + `MigrationFailureException` + `throwsA` — ALL confirmed.
- [x] `04-REVIEW.md` ≥ 240 lines for §4 content — file grew by ~80 lines across 3 evidence commits, totals >650 lines.
- [x] Permanent test file ≥ 70 lines — 121 lines including GOSL header + docstring + inertness guard.

Key-links checks:

- [x] `git push origin --delete adversarial/04-*` for both branches → confirmed in git command output.
- [x] `gh run view --log-failed` output for Tests #1 and #2 extracted into §4 stderr blocks — verified against original run logs.
- [x] Test #3 commit `test(04-rev): add SchemaSanityChecker row-loss regression guard` matches the key-link pattern `test\(04-rev\): add SchemaSanityChecker row-loss regression guard`.

**Overall: Self-Check PASSED.** All 7 `must_haves.truths` met, all artifacts present, all key-links verified. `deferred-items.md` explicitly carries the surprise finding forward.

---
*Phase: 04-review-gate-persistence*
*Plan: 04*
*Completed: 2026-04-18*
