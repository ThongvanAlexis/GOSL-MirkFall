---
phase: 08-review-gate-map
plan: 03
subsystem: review-gate
tags: [review-gate, audit, parallel-agents, triage, smell-heuristics, map]

# Dependency graph
requires:
  - phase: 08-review-gate-map
    provides: "§1 IDE observations (08-01) + §1b POC evidence snapshot (08-02) — audit inputs for parallel agents"
  - phase: 07-map-integration
    provides: "All Phase 07 code + 7 SUMMARYs (domain MapView + infra PmtilesSource + download pipeline + controllers + presentation + integration tests + smoke walks)"
provides:
  - "§2 fully populated: 10 pre-class CONTEXT rows + 4 smell heuristics hot-spots + 4 agent structured findings (75 total) + narrative appendix verbatim"
  - "§3 triage decisions table: 40 fix + 9 refactor + 0 waived + 10 defer-to-v2 + 16 accepted-as-is = 75 rows"
  - ".fixes-expected scratch file (integer 49) for Plan 08-05 tally verification"
  - "9 smell-tagged architectural refactor targets queued for Plan 08-05 (3 MapCameraController + 2 ActiveSession + 1 MapScreen-deactivate + 1 CountryResolver-duplication + 2 DownloadState-collapse)"
affects: [08-04-adversarial-wave, 08-05-fix-loop, 09-fog-rendering]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "4-parallel-sub-agent audit wave (Phase 02+04+06 precedent) validated FOURTH cycle — all 4 agents spawned in ONE single tool-use message, hybrid layer+risk slicing + smell-heuristics brief"
    - "Cross-cutting smell-heuristics review pattern (CLAUDE.md 2026-04-23 delta: fix-on-fix + over-state-machine) operationalized first cycle; smell-tag column visible in §3 triage table"
    - "Pre-class 10 CONTEXT items + 4 smell hot-spots committed BEFORE agent spawn to avoid redundant discovery (validated fourth cycle)"
    - "Blanket triage pattern (Phase 02/04/06 precedent) extended: 'do all Blocker+Should+Could, defer Noted minor items, accept-as-is positive confirmations' — one-pass user decision on 75 findings"
    - "Smell-triggered architectural refactor decision column distinct from standard `fix` — 9 rows routed to `refactor` based on smell tag"

key-files:
  created:
    - .planning/phases/08-review-gate-map/.fixes-expected
    - .planning/phases/08-review-gate-map/08-03-SUMMARY.md
  modified:
    - .planning/phases/08-review-gate-map/08-REVIEW.md

key-decisions:
  - "Blanket triage 2026-04-23 — user verbatim: 'do all the blocker, should, could, afterward I will do a full walk on both application and we will fix bugs then redo the same review' — applied mechanically: all Blocker/Should/Could to fix or refactor (smell-tagged architectural), Noted split into accepted-as-is (16 positive ✓) + defer-to-v2 (10 minor)"
  - "Smell-tagged architectural refactor decisions (9 total) separated from local fixes — Row 11/12 MapCameraController+CountryResolverController listener consolidation, Row 20/29 DownloadState field-name unification + 8-variant collapse, Row 35/36 MapCamera state+enum collapse, Row 37 ActiveSessionState/AsyncError consolidation, Row 38 ActiveSessionController reconcile-pattern redesign, Row 39 MapScreen deactivate microtask redesign"
  - "Phase 08 smell-tag column in §3 triage locked — visible to user at triage time per CONTEXT §Cross-cutting smell-heuristics / §3 triage tag requirement. First review-gate encoding of CLAUDE.md 2026-04-23 delta (fix-on-fix + over-state-machine); sets precedent for Phases 10/12/14/16"
  - "Cross-lens overlap preservation validated fourth cycle — 4 findings surfaced by 2 agents with divergent severity kept under BOTH lenses with `(also flagged by Agent #N)` cross-reference; collapsed in §3 under single global row via overlap note (rows 2, 15 for 8-layer drift; rows 20, 29 for DownloadState collapse; row 27 for simplify_polygons test absence; row 13 linking Agent #1 concerns)"
  - "Surprise findings — 1 Blocker not anticipated in CONTEXT pre-class: pause busy-spin in `_processQueue` (Agent #2 #1). Masked by over-state-machine confusion; `_processJob` returns instead of breaks on pause → outer `while (_queue.isNotEmpty)` tight-spins. No Rule 4 architectural decision required — Plan 08-05 local fix (change `return` to proper loop exit)"
  - "UNPINNED Phase 07 placeholders surfaced — `prepare_style.dart:78` `_kPinnedCommitSha = 'UNPINNED'` + placeholder `assets/maps/glyphs/` + `assets/maps/sprites/` directories. Was deferred from Plan 07-01; routed to fix (Row 18) for Plan 08-05 — blocks Phase 09 real rendering"

patterns-established:
  - "Pattern: Smell-heuristics brief verbatim in agent prompts — all 4 agents received CLAUDE.md §En review faire attention à (2026-04-23 delta) as Part 5 of prompt template. Prompt-level primer yielded 9 smell-tagged findings across 3 agents (no false negatives in Agent #4 transversal sweep)"
  - "Pattern: `refactor` decision semantics — smell-tagged findings whose fix requires architectural rewrite (listener consolidation, sealed-state collapse, reconcile-pattern redesign) routed to `refactor` column; smell-tagged findings whose fix is local (busy-spin `return`→`break`) routed to `fix`. Reusable rule for Phases 10/12/14/16"
  - "Pattern: Noted-tier decision sub-distinction — `accepted-as-is` (positive ✓ confirmations, no action) vs `defer-to-v2` (minor items acknowledged, punted to future milestone). Both are Noted-tier but track different semantics"

requirements-completed: []

# Metrics
duration: ~37 min (pre-class 20:09:20Z → triage commit 20:46:53Z, wall-clock bounded by parallel agent execution + user triage decision latency)
completed: 2026-04-23
---

# Phase 8 Plan 3: 4-Parallel-Agent Audit Wave + Blanket Triage Summary

**75 structured findings (1 Blocker + 19 Should + 29 Could + 26 Noted) collected via 4 parallel `general-purpose` sub-agents in ONE tool-use message with CLAUDE.md smell-heuristics brief, triaged in one pass via user blanket decision into 40 fix + 9 refactor + 0 waived + 10 defer-to-v2 + 16 accepted-as-is, 49 fixes queued for Plan 08-05.**

## Performance

- **Duration:** ~37 min (pre-class 4aff041 at 20:09:20 CEST → triage commit 2d77d8a at 20:46:53 CEST)
- **Started:** 2026-04-23T18:09:20Z (UTC, pre-class commit)
- **Completed:** 2026-04-23T18:46:53Z (UTC, triage commit)
- **Tasks:** 4 (pre-class / agent spawn / synthesis / triage)
- **Files modified:** 2 (`08-REVIEW.md` + `.fixes-expected` created)

## Accomplishments

- **Pre-class committed BEFORE agent spawn** (commit `4aff041`) — 10 CONTEXT handoff items (water filter / background V2 / iOS fix / Plan 07-07 absorb / pmtiles-heal / smell hot-spots anchor / ROADMAP sync / tool audits / CountryResolver edge cases / DEPENDENCIES deltas) + 4 smell heuristics hot-spots (PmtilesDownloadController 7-step / MapCameraController fix-on-fix / StyleRewriter+2 validators dispatcher / ActiveSessionController Phase 05 legacy) populated in §2 so agents arrived briefed, preventing redundant rediscovery
- **4 `general-purpose` sub-agents spawned in ONE single tool-use message** (structural constraint honoured fourth cycle — Phase 02/04/06/08) with hybrid layer+risk slicing + CLAUDE.md §En review faire attention à (2026-04-23 delta) verbatim brief + assigned smell hot-spot:
  - Agent #1 — Map infra + seam purity — 12 findings (3 Should / 7 Could / 2 Noted)
  - Agent #2 — Download pipeline + atomicity — 19 findings (1 Blocker / 6 Should / 7 Could / 5 Noted)
  - Agent #3 — Controllers + providers + presentation — 25 findings (4 Should / 7 Could / 14 Noted)
  - Agent #4 — Natives + assets + CI + DEPENDENCIES + CLAUDE.md sweep — 19 findings (6 Should / 8 Could / 5 Noted)
- **Synthesis committed** (commit `e8908d0`) — §2 agent sub-sections filled with 75 structured findings in `[severity] Title — 1-line — file:line [smell-tag]` format + cross-lens overlap preserved (4 cross-references) + 4-agent narrative appendix archived verbatim in collapsed `<details>` block
- **Triage committed** (commit `2d77d8a`) — §3 populated with 75 rows per blanket user decision; smell-tag column visible; 9 rows routed to `refactor` (smell-triggered architecture change) distinct from 40 `fix`
- **`.fixes-expected` snapshot** — integer `49` (40 fix + 9 refactor) written for Plan 08-05 tally verification

## Commit Hashes

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Pre-class 10 CONTEXT + 4 smell hot-spots into §2 | `4aff041` |
| 2 | 4-agent parallel audit wave (orchestrator-actor, no commit) | — |
| 3 | Synthesis: agent findings + narrative appendix into §2 | `e8908d0` |
| 4 | Triage decisions into §3 + `.fixes-expected` = 49 | `2d77d8a` |

## Findings Count per Agent

| Agent | Scope | Blocker | Should | Could | Noted | Total |
|-------|-------|:-------:|:------:|:-----:|:-----:|:-----:|
| **#1** | Map infra + seam purity | 0 | 3 | 7 | 2 | **12** |
| **#2** | Download pipeline + atomicity | 1 | 6 | 7 | 5 | **19** |
| **#3** | Controllers + providers + presentation | 0 | 4 | 7 | 14 | **25** |
| **#4** | Natives + assets + CI + DEPENDENCIES + CLAUDE.md sweep | 0 | 6 | 8 | 5 | **19** |
| **Total** | | **1** | **19** | **29** | **26** | **75** |

## Triage Decision Breakdown

| Decision | Count | Rows |
|----------|:-----:|------|
| `fix` | 40 | 1 (Blocker) + rows 2-19 excl. 11/12 (16 Should) + rows 21-49 excl. 29/35/36/37/38/39 (23 Could) |
| `refactor` | 9 | 11, 12, 20 (Should smell-tagged) + 29, 35, 36, 37, 38, 39 (Could smell-tagged) |
| `waived` | 0 | — (user elected to fix all Should vs waive) |
| `defer-to-v2` | 10 | 50, 52, 53, 54, 55, 56, 57, 58, 59, 70 (Noted minor items) |
| `accepted-as-is` | 16 | 51, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 72, 73, 74, 75 (Noted positive ✓) |
| **Total** | **75** | **All findings classified** |

**`.fixes-expected` integer:** `49` (40 fix + 9 refactor)

## Cross-Lens Overlaps Surfaced

Findings flagged by 2+ agents with divergent severities — preserved under BOTH lenses with cross-reference per Phase 02+04+06 convention:

1. **"8-layer" doc drift** — Row 2 (Should) at A1 #1 `(also flagged by Agent #4 — Should)` + Row 15 (Should) at A4 #1 `(also flagged by Agent #1 — Should)`. Same root cause (`user_location` removed in 07-07, docs not synced); triaged as two fixes (README+constants+map_errors lens vs style.json metadata lens). Could have collapsed to one; kept separate at user's blanket triage to preserve both lenses.
2. **DownloadState 8-variant collapse** — Row 20 (Should) at A4 #6 `(also flagged by Agent #2 — Could #9)` + Row 29 (Could) at A2 #9 `(also flagged by Agent #4 — Should)`. Same root pattern (sealed-state dispatcher duplication) but A4 sees transversal smell (10 copies across 4 files) and A2 sees local controller shape. Both routed to `refactor`; Plan 08-05 treats as one batched rewrite.
3. **simplify_polygons.dart paired test absence** — Row 27 (Could) at A1 #10 `(also flagged by Agent #4 — Should)`. A1 sees it as map-infra concern (Could); A4 sees it as cross-cutting tool-scripts discipline gap (Should). User blanket decision collapsed to fix at the Could severity (row 27) + the broader tool-scripts-missing-tests issue stays in row 16 (Should).
4. **InstalledMapsController bypass path** — Row 13 (Should) at A3 #3 `(may overlap Agent #1)`. Agent #3 flagged the distrust-of-provider-layer pattern; Agent #1 noted resolver-level consequences. Routed to `fix` under row 13 — Plan 08-05 fix should address both angles.

## Surprise Findings (Not Anticipated in CONTEXT Pre-class)

1. **Blocker: pause busy-spin in `_processQueue`** (A2 #1 / Row 1). CONTEXT pre-class item 6 pointed at PmtilesDownloadController as over-state-machine hot-spot (sealed states sync-only, dispatcher géant), but did not specifically predict the busy-spin bug. The smell-heuristics lens (Agent #2's primary hot-spot brief) surfaced it: `_processJob` returns on pause → `_processQueue`'s `while` re-invokes immediately → re-emits `DownloadPaused` → loops forever until `resume()` flips flag. No test covers this path. Local fix (change `return` to loop break), no architectural decision required — absorbed into Plan 08-05 Row 1 batch without Rule 4.
2. **UNPINNED Phase 07 placeholders** (A4 #4 / Row 18). Phase 07-01 summary documented "placeholder mode" but did not propagate to CONTEXT pre-class. Agent #4 surfaced `_kPinnedCommitSha = 'UNPINNED'` at `tool/prepare_style.dart:78` + missing `assets/maps/glyphs/` + `assets/maps/sprites/` real assets (README-only placeholders). Blocks Phase 09 real rendering; queued as fix Row 18 for Plan 08-05.
3. **`CountryDeleteService` heal path docstring drift** (A2 #5 / Row 8). Pre-class item 5 verified pmtiles-heal coherence with atomic rename; surprise finding is that the heal path `_healOrphanCountryFiles` only INSERTS missing entries, never REMOVES stale ones despite `CountryDeleteService` class docstring claiming otherwise. Invariant-gap, not test-gap. Routed to fix Row 8.
4. **`_accumulatedBytes` double-count on 200-OK restart fallback** (A2 #4 / Row 7). UX bug (progress numbers wrong) masked by `.clamp()` at UI level but counter bleeds into subsequent parts. Not predicted by any CONTEXT lens. Routed to fix Row 7.

## Smell-Tagged Findings Breakdown

**Total smell-tagged:** 11 findings across 75 (14.7%)

| Smell tag | Count | Decision routing |
|-----------|:-----:|------------------|
| `[smell:fix-on-fix]` | 7 | 1 Blocker→fix (Row 1 listed also-over-sm), 2 Should→refactor (rows 11, 12), 2 Should→fix (rows 5, 14 + row 15/19 tagged), 2 Could→refactor (rows 38, 39) |
| `[smell:over-state-machine]` | 6 | 1 Should→refactor (row 20), 4 Could→refactor (rows 29, 35, 36, 37), 1 Noted→defer (row 57) |

**Decision breakdown of smell-tagged rows:**
- `fix` (local patch sufficient): 4 findings — Row 1 (pause busy-spin local), Row 5 (permanent-failure loop), Row 14 (openForSession rename+inline), Row 15 (style.json metadata)
- `refactor` (architectural rewrite): 9 findings — Rows 11, 12, 20, 29, 35, 36, 37, 38, 39
- `defer-to-v2`: 1 finding — Row 57 (CountryResolverController if-return chain, Noted-tier)
- Note: Row 19 (catalogVersion duplicate `[smell:fix-on-fix]`) → fix (local dedupe)

The `refactor`-vs-`fix` smell decision rule (established Phase 08): smell-tagged findings whose fix requires architectural rewrite (listener consolidation, sealed-state collapse, reconcile-pattern redesign) → `refactor`; smell-tagged findings whose fix is local (rename, inline, dedupe) → `fix`.

## Files Created/Modified

- `.planning/phases/08-review-gate-map/08-REVIEW.md` — §2 pre-class + smell hot-spots + 4 agent sub-sections + narrative appendix + §3 triage table (522 lines total, up from 448 at plan start)
- `.planning/phases/08-review-gate-map/.fixes-expected` — NEW — single integer `49` for Plan 08-05 tally verification (Phase 02/04/06 scratch format)

## Decisions Made

See `key-decisions` in frontmatter + accumulated context:

1. Blanket triage applied mechanically per user verbatim (40/9/0/10/16)
2. Smell-tagged architectural rewrites separated from local fixes via distinct `refactor` decision (9 rows)
3. Noted-tier decision sub-distinction: `accepted-as-is` for 16 positive confirmations vs `defer-to-v2` for 10 minor items
4. Cross-lens overlaps preserved (4 cross-references) — not deduplicated per Phase 02+04+06 convention

## Deviations from Plan

None - plan executed exactly as written.

The plan anticipated both a single atomic commit for triage + `.fixes-expected` OR a follow-up `chore(08-rev): snapshot .fixes-expected` commit. We chose the single-commit path (plan-preferred) — both files staged and committed as `2d77d8a`.

## Authentication Gates

None - no external service authentication required for this plan.

## Issues Encountered

None — plan executed as continuation agent with state context provided verbatim by orchestrator (completed tasks 1-3, user triage decision for task 4). No verification failures, no analysis-paralysis situations, no blocking dependencies.

## User Unblock Signal

**Awaited after this plan closes:** User must respond `OK adversarial` (or equivalent `§3 validé, go 08-04`) to unblock Plan 08-04 (adversarial wave — 4 integration tests MOVE + 3 permanent unit tests NEW + 1 adversarial CI branch + 2 soak edge cases).

This SUMMARY signals that Plan 08-03 is complete and the user-unblock-signal is the gate to Plan 08-04.

## Next Phase Readiness

**Ready for Plan 08-04 (Adversarial Wave):**
- §1 + §1b + §2 + §3 of `08-REVIEW.md` all populated
- `.fixes-expected = 49` snapshot locked for Plan 08-05 tally
- 9 smell-tagged architectural refactor targets queued with explicit `refactor` decision — Plan 08-05 will batch these as architectural rewrite commits distinct from local fix commits
- No blockers or open questions to resolve before Plan 08-04

**Awaiting user unblock signal** (`OK adversarial` or `§3 validé, go 08-04`) per Plan 08-03 Task 4 `<resume-signal>`.

## Self-Check: PASSED

- `.planning/phases/08-review-gate-map/08-03-SUMMARY.md` exists
- `.planning/phases/08-review-gate-map/.fixes-expected` exists + contains integer `49`
- commit `4aff041` (pre-class) present in git log
- commit `e8908d0` (synthesis) present in git log
- commit `2d77d8a` (triage) present in git log
- §3 triage table contains 75 rows (grep confirmed 75 numbered rows in table format)
- Decision counts verified via grep: `| fix |` = 40, `| refactor |` = 9, `| defer-to-v2 |` = 10, `| accepted-as-is |` = 16, `| waived |` = 0

---
*Phase: 08-review-gate-map*
*Completed: 2026-04-23*
