---
phase: 04-review-gate-persistence
plan: 03
subsystem: review-gate
tags: [audit, review-artefact, parallel-sub-agents, triage, adversarial-poison-verification, drift, domain-purity, schema-migrations, custom-lint, unimplementederror]

# Dependency graph
requires:
  - phase: 04-review-gate-persistence
    provides: 04-REVIEW.md §1 user-first + §1b runtime walk Windows committed (04-01 + 04-02 outputs); 03-VERIFICATION.md Outstanding minor items (3 entries pre-class input)
  - phase: 03-persistence-domain-models
    provides: 6 Drift tables + Freezed domain entities + 5 stores + JsonMigrator framework + DbBackupService + 64 unit tests — all under audit in this wave
provides:
  - §2 Claude audit findings populated with pre-class (5 entries — 3 VERIFICATION + 2 runtime walk) + 4 sub-agent sub-sections (86 findings total across Agent #1 Schema/migrations/backup + #2 Domain/pureté + #3 Stores/factory/providers + #4 Tests/tooling/CLAUDE.md sweep)
  - §3 triage table populated with user decisions on all 91 findings (blanket-approve — fix all Blockers + Shoulds; defer all Coulds; Noteds stay observations)
  - Adversarial poison verifications block (Plan 04-04 input) — Test #1 (domain-import-flutter-and-drift) + Test #2 (drift-schema-dump-stale) poison recipes verified still applicable to Phase 03 code as-is
  - Triage summary (Plan 04-05 input) — 35 fix targets (with 4 duplicate rows referencing existing targets) + 22 defer + 33 noted + 0 waived + 0 won't-fix
  - Escalation signals for Plan 04-05: P1 confirmed architectural (not test-only) — production `DbBackupService.rotate` mtime-dependent; paired with flaky test as single fix; P2 confirmed unchanged; P4 runtime walk Blocker (Zone mismatch) confirmed needs fix
affects: [04-04, 04-05, 05-gps-session-lifecycle, 06-review-gate-gps, 08-review-gate-map, 10-review-gate-fog, 12-review-gate-markers, 14-review-gate-import-export, 16-review-gate-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-classification BEFORE agent spawn — 5 pre-class entries (3 VERIFICATION + 2 runtime walk deviations) committed first, saving ~2-4 redundant finding instances per agent; pattern reusable for every review gate"
    - "4-sub-agent parallel audit pattern validated on second review gate — single tool-use message with 4 `general-purpose` Agent calls yielded 86 agent findings in one wall-clock slot; pattern stable across Phase 02 + Phase 04"
    - "Severity disagreement preservation across lenses — 2 findings (#5 parentZoom, #7 UTC offset) had 2-3 different severities from different agent lenses; preserved all severities with explicit attribution, collapsed to `fix` under blanket approval"
    - "Paired finding collapse — when test-side and runtime-side findings share a single architectural fix (P1 ↔ #1 backup rotate; #20 ↔ #32 mergeMask race), triage tracks both but fix loop applies single edit"
    - "Cross-lens finding overlap handling convention reused from Phase 02 — same file:line found by multiple agents preserved under both with `Cross-ref` annotation rather than deduplicated"
    - "Adversarial poison re-verification at audit time — Agent #1 re-verifies CI-poison recipes still apply to actual code (file paths, line numbers, grep patterns) rather than relying on CONTEXT's design-time description; prevents drift"
    - "Titles-only presentation to user — CLAUDE.md §Code Review Phases contract respected (no diffs, no code blocks, no file contents); user triaged blanket-approve in one sentence"

key-files:
  created:
    - .planning/phases/04-review-gate-persistence/04-03-SUMMARY.md
  modified:
    - .planning/phases/04-review-gate-persistence/04-REVIEW.md

key-decisions:
  - "4 sub-agents all set to `general-purpose` — reuse of Phase 02 Accumulated Decision for wave consistency; even read-only code sweep could have been `Explore` but kept general-purpose for rule clarity"
  - "Pre-class table committed BEFORE agent spawn (hard ordering gate) — `docs(04-rev): pre-class VERIFICATION candidates into §2` commit 495bcf7 landed before any Agent tool call"
  - "Cross-lens finding overlap convention (preserve both with cross-ref) reused from Phase 02 — 6 overlaps preserved: P1↔Agent#1#1 (backup mtime), #5 (parentZoom 2 severities), #7 (UTC offset 3 severities), #10 (t_sessions.status CHECK), #20↔#32 (mergeMask race), #71↔#77 (Marker.photos allocation)"
  - "Severity disagreements collapse to `fix` under blanket-approve — #5 (Agent #1 Should vs Agent #4 Blocker) and #7 (Agent #1 Should vs Agent #2 Noted vs Agent #4 Blocker) both collapse to `fix` target because Shoulds also fixed; higher-severity lens prevails in rationale but action identical"
  - "P1 escalation CONFIRMED — Agent #1 verified `DbBackupService.rotate` production code uses `File.statSync().modified` at backup.dart:89-90; flaky test is a symptom, production architecture is the cause; paired with flaky test as single filename-ISO lex-sort fix"
  - "P2 status unchanged — Agent #2 re-ran `dart run custom_lint` at audit time and confirmed identical failure class (Element2/Annotatable/ErrorCode/libraryElement2/resolveFile2 unresolved against analyzer-10.0.1); no promotion to Could, stays Noted"
  - "Additional UnimplementedError scan — Agent #4 confirmed ZERO additional placeholders beyond P3 (reveal_calculator.dart:69); P3 no-callers-guard is sufficient coverage"
  - "Blanket-approve triage pattern reused from Phase 02 — user responded `let's fix blocker and should`; interpretation rule: Blockers+Shoulds → fix, Coulds → defer (NOT fix unless user says so explicitly), Noteds → observation (never flip to fix under blanket)"
  - "Coulds → defer (not fix) because user scoped approval to `blocker and should` explicitly — Phase 02 user-blanket was `fix tous` which included Coulds; Phase 04 explicit scope must be respected"

patterns-established:
  - "Review-gate Wave 3 plan template (pre-class + 4-agent audit + triage) validated on second cycle — Phase 02 Plan 02-02 implicitly pre-classed via agent scopes; Phase 04 Plan 04-03 makes it explicit as a dedicated Task 1 commit"
  - "Runtime-walk deviations from an earlier plan (04-02 §1b) feed into audit pre-class table as P4+ entries — preserves traceability from runtime evidence to audit pre-class to triage decision"
  - "Paired architectural fix recognition — when test-side flakiness points to production-side fragility (P1 ↔ #1), a single production fix resolves both; audit wave confirms the pairing rather than re-designing"
  - "Severity disagreement is a signal, not noise — 2 findings had 2-3 different severities across lenses; disagreement itself merits its own Noted entry (#87) with explicit attribution"

requirements-completed:
  - SC#2
  - SC#3

# Metrics
duration: 30 min
completed: 2026-04-18
---

# Phase 04 Plan 03: Pre-class + 4-Agent Audit + Triage Summary

**91 audit findings consolidated (5 pre-class + 86 agent) across 4 parallel `general-purpose` sub-agents covering schema+migrations+backup / domain+pureté / stores+factory+providers / tests+fixtures+tooling+CLAUDE.md sweep — blanket-approved by user for all 9 Blockers + 27 Shoulds to be fixed in Plan 04-05; 22 Coulds deferred; 33 Noteds stay as observations; P1 escalation confirmed (backup rotate architecturally mtime-dependent, not just test-side flaky).**

## Performance

- **Duration:** ~30 min (pre-class edit + 4-agent parallel wave + consolidation + user triage + §3 write)
- **Tasks:** 4 (Task 1 pre-class / Task 2 4-agent spawn / Task 3 user triage / Task 4 SUMMARY)
- **Files modified:** 2 (04-REVIEW.md modified across Tasks 1-3; 04-03-SUMMARY.md created in Task 4)

### Agent type selection + wall-clock

All 4 sub-agents set to `agent_type="general-purpose"` per STATE.md Phase 02 Accumulated Decision (locked for review-gate wave consistency; minor efficiency loss on read-only code-sweep Agent #4 outweighed by predictable rule).

- **Agent #1 (Schema + migrations + backup):** ~5 min wall-clock — scoped to `lib/infrastructure/db/**` (9 files) + `drift_schemas/**` (3 files) + `test/infrastructure/db/**` (~13 files) + pragma wiring. Returned 19 structured findings + adversarial poison verification block.
- **Agent #2 (Domain + pureté):** ~4 min wall-clock — scoped to `lib/domain/**` (7 entities + 6 ID extension types + ULID + Envelope + JsonMigrator + errors + ports) + `test/domain/**` (~10 test files) + `dart run custom_lint` re-execution. Returned 21 structured findings (5 Should + 6 Could + 10 Noted including 2 cross-lens flags).
- **Agent #3 (Stores + factory + providers):** ~4.3 min wall-clock — scoped to `lib/infrastructure/stores/**` (5 stores) + `lib/application/providers/*_store_provider.dart` (7 providers) + `lib/infrastructure/ids/**` + `test/infrastructure/stores/**` (~6 tests) + `test/infrastructure/ids/**` (3 tests). Returned 22 structured findings.
- **Agent #4 (Tests + fixtures + tooling + CLAUDE.md sweep):** ~9.7 min wall-clock (widest scope — cross-cutting concerns) — scoped to all Phase 03 tests + `test/fixtures/**` + `tool/check_domain_purity.dart` + `tool/check_dependencies_md.dart` + `pubspec.yaml` pinning discipline + `analysis_options.yaml` + `lib/config/constants.dart` + `DEPENDENCIES.md` + CLAUDE.md anti-pattern sweep + additional investigation (UnimplementedError scan + Windows-flaky test candidates + analyzer-plugin analogues). Returned 24 structured findings.

**Total parallel wave duration:** ~10 min wall-clock (bounded by slowest agent — Agent #4). Phase 02's 4-agent wave on smaller codebase ran ~25 min per STATE.md; Phase 04 faster because (a) 5 pre-class entries removed redundant discovery paths, (b) agent scopes more surgical.

## Accomplishments

- **Pre-class 5 entries committed BEFORE agent spawn** (hard ordering gate `495bcf7`): P1 flaky backup rotate + P2 custom_lint silent-degrade + P3 computeRevealMask UnimplementedError + P4 runtime walk Zone mismatch + P5 runtime walk sqlite3 CLI pragma gap. Saved ~2-4 redundant finding instances per agent on the 3 VERIFICATION items + 2 walk deviations.
- **4 parallel sub-agents spawned in a single tool-use message** (Phase 02 precedent preserved — not 4 serial messages). 86 agent findings + 4 narrative appendices + Agent #1 adversarial poison verification block returned in one wall-clock slot.
- **§2 structured findings populated** — grep count for `[Blocker|Should|Could|Noted]` severity markers comfortably exceeds the realistic floor (`>5`); actual count is 86 across agent sub-sections.
- **Cross-lens overlaps preserved with explicit attribution** — 6 overlap pairs kept (P1↔#1 backup rotate / #5 parentZoom 2-way severity / #7 UTC offset 3-way severity / #10 t_sessions.status CHECK cross-ref / #20↔#32 mergeMask race / #71↔#77 Marker.photos allocation) per Phase 02 "Cross-lens finding overlap handling convention".
- **User triaged 91 findings in one sentence** via blanket-approve (`let's fix blocker and should`). §3 table populated with 35 `fix` + 22 `defer` + 33 `noted` + 0 waived + 0 won't-fix.
- **Adversarial poison verification block saved at end of Agent #1 sub-section** (Plan 04-04 reads this for Test #1 + Test #2 execution).
- **3 escalation signals surfaced** for Plan 04-05 visibility (see Escalations section below).
- **No scope overflow** — each agent stayed within its declared scope; cross-concern findings annotated as cross-lens rather than re-owned.

## Task Commits

1. **Task 1 (pre-class VERIFICATION into §2):** `495bcf7` — docs commit. Replaced `(pending — 3 entries: flaky... | custom_lint... | computeRevealMask...)` placeholder with 3-entry VERIFICATION pre-class table + 2-entry runtime walk pre-class sub-section (sourced from 04-02 §2 escalation).
2. **Task 2 (record audit findings from 4 parallel sub-agents):** `a4f9f07` — docs commit. 86 structured findings consolidated across 4 sub-sections + narrative appendices inlined in `<details><summary>Audit Notes</summary>` block + adversarial poison verifications saved at end of Agent #1 sub-section.
3. **Task 3 (record triage decisions for 91 findings):** `8184b9f` — docs commit. §3 populated with 4 sub-tables (Blockers / Shoulds / Coulds / Noted) + triage totals summary. Pre-class P# labels preserved.
4. **Task 4 (this SUMMARY + closure):** _(pending — final plan-closure commit covering this SUMMARY + STATE.md + ROADMAP.md updates)_

## Files Created/Modified

- **`.planning/phases/04-review-gate-persistence/04-REVIEW.md`** — §2 populated across Tasks 1-2 (5 pre-class entries + 86 agent findings + 4 narrative appendices + adversarial poison verification block); §3 populated in Task 3 (91-row triage table with totals).
- **`.planning/phases/04-review-gate-persistence/04-03-SUMMARY.md`** (created, this file) — carries adversarial poison verifications forward to Plan 04-04 + triage summary forward to Plan 04-05 + 3 escalation signals.

## Adversarial poison verifications (Plan 04-04 input)

Copied VERBATIM from `04-REVIEW.md` §2 Agent #1 sub-section trailing block. Plan 04-04 Task 1 + Task 2 read this directly.

**Test #1 `adversarial/04-domain-import-flutter-and-drift`:**
- `lib/domain/sessions/session.dart` exists: YES (1512 bytes, GOSL header present)
- `lib/domain/markers/marker.dart` exists: YES (GOSL header present)
- Imports section stable at top: YES — GOSL header (1-3), `// ignore_for_file` (5-7), imports from line 9. Zero `package:flutter/` or `package:drift` imports across `lib/domain/**`. Grep `-E "^import 'package:(flutter|drift)"` anchored to `lib/domain/` would catch a poison injection at line 9.

**Test #2 `adversarial/04-schema-drift-stale`:**
- `lib/infrastructure/db/app_database.dart` still has `t_sessions`: YES — line 36 `class Sessions extends Table` with `tableName => 't_sessions'` at line 38.
- Column-addition stress point stable: YES — `Sessions` class body spans lines 36-66; clean insertion point at line 63 (before `@override primaryKey` on line 65). The `fixed_sql` block in `drift_schema_v2.json:759` would need regeneration; CI gate fails diff.
- Drift from CONTEXT: no material drift. Minor callout: partial unique index is declared at `app_database.dart:31-35` via `@TableIndex.sql` (multi-line triple-quoted with indentation and trailing `;`). Grep for `idx_t_sessions_status_active` OR `CREATE UNIQUE INDEX idx_t_sessions_status_active` both hit. No adversarial-guardrail impact.

**Verdict:** Both poison recipes from CONTEXT.md apply to Phase 03 code as-designed. Plan 04-04 can proceed with its branch-and-CI workflow without poison-recipe adjustment.

## Triage summary (Plan 04-05 input)

### Finding counts by severity (across pre-class + 4 agents)

| Severity | Pre-class | Agent #1 | Agent #2 | Agent #3 | Agent #4 | Cross-lens synthesis | Total |
| -------- | --------- | -------- | -------- | -------- | -------- | -------------------- | ----- |
| Blocker  | 2 (P1,P4) | 2        | 0        | 2        | 3        | 0                    | 9     |
| Should   | 2 (P3,P5) | 7        | 5        | 8        | 6        | 0                    | 28 (#11, #13 dup-ref #7, #5; #29 stabilizes via #1; #32 ref #20 — net ~24 unique targets) |
| Could    | 0         | 4        | 6        | 6        | 5        | 0                    | 21    |
| Noted    | 1 (P2)    | 6        | 10       | 6        | 10       | 1                    | 34    |
| **Row total** | **5** | **19** | **21** | **22** | **24** | **1** | **92** |

Note: 92 raw rows consolidate to 91 distinct triage entries — the cross-lens synthesis row (#87) is a meta-observation on the 2 severity-disagreement findings, not a new finding.

### Triage decisions summary (all 91 findings)

| Decision   | Count | Notes                                                                                                          |
| ---------- | ----- | -------------------------------------------------------------------------------------------------------------- |
| fix        | 35    | 9 Blockers + 27 Shoulds. Includes 4 rows that reference existing fix targets (#11→#7, #13→#5, #29→#1, #32→#20) — net ~31 unique fix edits, plus 2 architectural fixes each collapsing a paired finding (P1↔#1 single filename-ISO fix, #20↔#32 single transaction fix). |
| defer      | 22    | All Coulds. Blanket-defer rationale: user scoped approval to Blockers + Shoulds explicitly; Coulds revisit at Phase 15 polish at latest. Exception: Could #35 (backup filename `Z` trailing position) is promoted INTO the #1 production fix because #1's filename-ISO lex-sort requires it.                     |
| noted      | 33    | All Noteds + P2 (custom_lint silent degrade) + cross-lens synthesis row #87. No action; transparency signals only.            |
| waived     | 0     | Zero Shoulds waived under blanket-approve.                                                                     |
| won't-fix  | 0     | Zero findings declined.                                                                                        |
| **Total**  | **91** | Matches row count in §3.                                                                                      |

### Cross-lens overlap count

**6 preserved cross-lens overlaps** (same file:line flagged by 2+ agents, preserved under both with `Cross-ref` annotation per Phase 02 convention):

1. **P1 (pre-class) ↔ Agent #1 Blocker #1** — backup `File.statSync().modified` mtime ordering. Test-side flakiness + runtime-side fragility. Single architectural fix (filename-ISO lex-sort) covers both.
2. **Agent #1 Should #5 ↔ Agent #4 Blocker** — `parentZoom=14` magic number duplication. Severity disagreement (Should vs Blocker); collapsed to `fix` under blanket Blockers+Shoulds.
3. **Agent #1 Should #7 ↔ Agent #2 Noted ↔ Agent #4 Blocker** — UTC-offset `-720/840` duplication. 3-way severity disagreement (Should vs Noted compile-time-carveout vs Blocker); collapsed to `fix`. Agent #2's compile-time concern partially valid but mitigable.
4. **Agent #1 Should #10 ↔ Agent #3 Noted** — `t_sessions.status` no CHECK constraint. Both lenses agree on fix; severity varies by concern.
5. **Agent #3 Should #20 ↔ Agent #4 Should #32** — `mergeMask` race. Cold-start INSERT race (Agent #3 lens) + `createInBackground` isolate-swap race (Agent #4 lens). Single fix (serialize or INSERT OR IGNORE) covers both.
6. **Agent #2 cross-lens Noted for Agent #3 ↔ Agent #3 Noted #77** — `Marker.photos` `@Default(const <PhotoRef>[])` allocation (constructor not const because `displayName.trim()` assert forces bare `factory`). Agent #2 flagged it looking at domain; Agent #3 confirmed it looking at stores/hydration.

## Escalation flags

### P1 escalation: CONFIRMED (test-side symptom → production-side architectural fix)

Agent #1 verified that `lib/infrastructure/db/backup.dart:89-90` calls `File.statSync().modified` on each `.db` file in the backup directory and sorts by that mtime. This means the flaky test (`backup_test.dart::rotate keeps the 3 newest when 4 exist`, from 03-VERIFICATION.md) is NOT a test-harness quirk — it's a symptom of a production architectural fragility. Windows NTFS mtime resolution (15ms–1s) + antivirus/indexer side effects + parallel-run interleave make this sort non-deterministic.

**Action:** Pair P1 and Agent #1 Blocker #1 as a single architectural fix target in §3 triage (both → `fix`). Single fix: replace mtime-sort with filename-embedded ISO timestamp sort (`DbBackupService.rotate` reads filenames, strips non-timestamp prefix/suffix, sorts lex — requires Could #35 fix baked in so `Z` trailing position is lex-stable). Test stabilizes as a side effect of the production fix.

### P2 re-verification: CONFIRMED unchanged

Agent #2 ran `dart run custom_lint` at the repo root at audit time (bypassing `flutter analyze` which is green via the analyzer-10 stack). The plugin failed with the same unresolved-element error class as documented in 03-VERIFICATION.md: `Element2`, `Annotatable`, `ErrorCode`, `ErrorType`, `ErrorSeverity`, `ElementKind`, `ElementAnnotation`, `libraryElement2`, `resolveFile2` all unresolved across `type_checker.dart`, `lint_codes.dart`, `assist.dart`, `fixes.dart` in `custom_lint_core 0.8.1`.

**Action:** P2 stays Noted. No promotion. Re-verify at next `pubspec.yaml` deps bump and at Phase 15 latest. `custom_lint.log` (29KB) noted in working tree as evidence.

### Additional UnimplementedError scan: CONFIRMED zero additional

Agent #4 ran a `lib/**` scan for `UnimplementedError` throws. Result: only site is `reveal_calculator.dart:69` (= P3). No additional placeholders lurking in Phase 03 code.

**Action:** P3's no-callers test guard (`test/domain/compute_reveal_mask_no_callers_test.dart`) is sufficient coverage. Plan 04-05 implements just this one guard.

### P4 runtime walk Blocker: CONFIRMED needs fix in 04-05

Zone mismatch crash at `runApp` on `flutter run -d windows` was surfaced by 04-02 runtime walk and pre-classed into §2 as P4. Audit wave did not re-investigate (out of scope for agents — they focused on Phase 03 code, not `main.dart`), but the pre-class entry stands and user blanket-approved it to `fix`.

**Action:** Plan 04-05 fix is small — edit `lib/main.dart:34,36,71` so `WidgetsFlutterBinding.ensureInitialized()` runs inside the `runZonedGuarded` zone (as the first statement inside the callback) instead of in the root zone before it. Re-walk via `flutter run -d windows` in Plan 04-05 to verify boot is clean. Phase 01 RESEARCH line 349-354 pitfall workaround is recalibrated — Flutter 3.41.7's `debugCheckZone` disagrees with the pre-3.10 pattern in practice.

### Severity-disagreement pattern surfaced (2 findings)

Two findings had 2-3 different severities across lenses:

- **#5 (parentZoom=14 magic):** Agent #1 Should (schema default is isolated) vs Agent #4 Blocker (two-site duplication with third-party constants.dart violates CLAUDE.md §Magic numbers strictly)
- **#7 (UTC offset -720/840):** Agent #1 Should vs Agent #2 Noted (compile-time `@Assert` carve-out can't reference `const int`) vs Agent #4 Blocker (lib/config/constants.dart DOES allow top-level const via plain Dart reference; carve-out argument weak)

**Action:** Both collapse to `fix` under blanket Blockers+Shoulds approval — higher-severity lens prevails in rationale but the action target is identical. Agent #2's compile-time concern on #7 is partially valid: `@Assert` string body can't interpolate const — mitigate by a 2-step pattern (asserting against the numeric bounds in @Assert string AND adding a separate test-level guard referencing `kMin/MaxUtcOffsetMinutes` from constants.dart). Pattern logged as Accumulated Decision for future review gates.

## Decisions Made

Key decisions are in the frontmatter `key-decisions` array. Summary:

- **Blanket-approve interpretation rule locked for Phase 04:** `let's fix blocker and should` → Blockers + Shoulds = fix; Coulds = defer (NOT fix); Noteds = observation. This differs from Phase 02's `fix tous` (which included Coulds) — explicit scope must be respected each time.
- **Paired fix collapse:** P1 ↔ #1 and #20 ↔ #32 each collapse to single architectural fix in Plan 04-05. Fix loop tracks them as 1 edit with 2 triage rows satisfied.
- **Could #35 promotion into #1 production fix:** Backup filename `Z` trailing position is normally Could/polish, but #1's filename-ISO lex-sort fix REQUIRES it — so it's baked in, not deferred.
- **Coulds defer scope:** 22 findings deferred to "next natural stopping point — Phase 15 polish at latest." Not to a specific phase. User did not say which phase.
- **Cross-lens overlap preservation:** 6 overlaps preserved per Phase 02 convention. Severity-disagreement subset (#5 + #7) preserved as its own meta-observation row (#87) for transparency.

## Scope overflow / surprise observations

**Zone mismatch (P4)** surfaced during Plan 04-02 runtime walk was the highest-impact runtime-only finding of this review gate. Build was green, CI was green, unit tests were green — but the app crashed immediately on `runApp` on Windows desktop. Validates the Phase 02 precedent that a Runtime Walk dedicated plan is load-bearing, not decorative. Without Plan 04-02, this would have slipped silently into Phase 05 where ProviderScope consumers make it blocking.

**Architectural vs test-side finding pairing (P1 + #1)** demonstrates that a test-side VERIFICATION item can mask a production-side architectural fragility. The flaky test was documented in 03-VERIFICATION.md as "mtime-ordering fragility" on the test side; the audit wave discovered the SAME fragility in production code. Pre-classing the test-side item + having Agent #1 explicitly re-verify the production side (plan's `<interfaces>` instruction: "SPECIFICALLY re-verify that `DbBackupService.rotate` does NOT depend on `File.lastModifiedSync()` mtime") was what surfaced the pairing — generic audit scope might have listed both as separate findings without connecting them.

**Severity disagreement as signal** — when 2-3 agent lenses score the same finding differently, the disagreement itself is meaningful: it reflects that the finding's impact varies by concern-slice. Preserving the disagreement (as row #87) rather than averaging it exposes the judgement to future reviewers.

## Issues Encountered

None during this plan's execution. Audit surfaced 86 findings on Phase 03 code; that's the point of a review gate and doesn't constitute an issue for Plan 04-03 itself.

## User Setup Required

None — all audit activity was local (file inspection + in-repo grep + re-running `dart run custom_lint`). No external services, no credentials.

## Next Phase Readiness

### Unblocked

- **Plan 04-04 (adversarial wave):** Adversarial poison verification block is committed on `main` at the end of Agent #1 sub-section in §2. Plan 04-04 Tasks 1-2 read this directly. Both recipes (Test #1 domain-import-flutter-and-drift + Test #2 drift-schema-dump-stale) verified still applicable to Phase 03 code as-designed — no drift, no recipe adjustment needed. Plan 04-04 can proceed to its branch-and-CI workflow.
- **Plan 04-05 (fix loop):** §3 triage table is committed. Fix loop has a clean 35-row `fix` target list + 2 paired-fix collapses + Could #35 promotion baked into #1 + 4 duplicate-ref rows that self-satisfy. Plan 04-05 also has 3 pre-class fixes explicitly called out (P1 backup determinism / P2 custom_lint documentation / P3 no-callers guard) as per ROADMAP Phase 04 `Plans` column. Plus P4 zone mismatch fix. Plus P5 walk-tooling pragma fix. Full scope visible.

### Blockers / concerns for downstream

- **35 fix targets is a large scope for a single fix loop plan.** Plan 04-05 may need to sequence them by subsystem (schema/migrations first, then domain invariants, then stores, then tests + tooling) to keep commits atomic and CI green between each. Alternative: group fixes by file (minimize re-touch) rather than by concern-slice. Decision belongs to Plan 04-05's task breakdown.
- **P4 zone mismatch fix requires re-walk to verify** — Plan 04-05 must include a `flutter run -d windows` sanity check as part of the fix loop or checkpoint gate. Cannot slip silently; CI doesn't catch this (CI does `flutter build`, not `flutter run`).
- **Could #35 (`Z` trailing position) promoted into Blocker #1** — minor complexity signal: a triage row labelled `defer` (#35) is actually touched in Plan 04-05 as part of the #1 fix. Plan 04-05 fix loop should annotate this explicitly (e.g. "#1 fix also closes Could #35") for traceability.

## Self-Check: PASSED

Must-haves verification against `04-03-PLAN.md` `must_haves.truths`:

- [x] **Truth 1: Pre-class §2 sub-section committed BEFORE any Agent tool call** — commit `495bcf7` on `main` predates commit `a4f9f07` (agent findings). Gate satisfied.
- [x] **Truth 2: 4 sub-agents spawned in a single tool-use message (all `general-purpose`)** — per orchestrator transcript, single message with 4 parallel Agent calls. Wall-clock bounded by slowest agent (~10 min), not by sequential sum.
- [x] **Truth 3: Each sub-agent scope matches CONTEXT §Sub-agent slicing verbatim** — Agent #1 Schema+migrations+backup / Agent #2 Domain+pureté / Agent #3 Stores+factory+providers / Agent #4 Tests+fixtures+tooling+CLAUDE.md sweep. Agent scopes not silently expanded (cross-concern findings annotated as cross-lens, not re-owned).
- [x] **Truth 4: Each sub-agent returned structured findings list + narrative appendix** — 4 structured lists (`[severity] Title — 1-line — file:line`) + 4 narrative appendices inlined in `<details><summary>Audit Notes</summary>` block.
- [x] **Truth 5: Cross-lens overlaps preserved with explicit cross-reference** — 6 overlap pairs preserved per Phase 02 convention (see Cross-lens overlap count section above).
- [x] **Truth 6: §2 populated; user presented findings as TITLES + 1-line explanations only** — per orchestrator, user saw titles + explanations without diffs or code blocks; responded `let's fix blocker and should`.
- [x] **Truth 7: §3 triage table populated** — every Blocker = `fix`, every Should = `fix` (0 waived), every Could = `defer`, every Noted = `noted`. No placeholder `(pending)` rows remain in §3.
- [x] **Truth 8: 04-03-SUMMARY.md carries adversarial poison verifications forward** — this file's "Adversarial poison verifications" section is verbatim copy of §2 Agent #1 block. Plan 04-04 input ready.

Artifact checks:

- [x] `.planning/phases/04-review-gate-persistence/04-REVIEW.md` exists with `### Agent #1 — Schema + migrations + backup` heading — FOUND (line 170).
- [x] `.planning/phases/04-review-gate-persistence/04-REVIEW.md` ≥ 200 lines — FOUND (600+ lines after §3 expansion).
- [x] `.planning/phases/04-review-gate-persistence/04-03-SUMMARY.md` exists — THIS FILE.
- [x] `.planning/phases/04-review-gate-persistence/04-03-SUMMARY.md` contains `Adversarial poison verifications` — FOUND in this file.
- [x] `.planning/phases/04-review-gate-persistence/04-03-SUMMARY.md` ≥ 40 lines — FOUND (200+ lines).

Key-links checks:

- [x] Plan 04-03 Task 1 commit `docs(04-rev): pre-class VERIFICATION candidates into §2` precedes Task 2 commit `docs(04-rev): record audit findings from 4 parallel sub-agents` — confirmed via `git log --oneline`: `495bcf7` (pre-class) → `a4f9f07` (agents) → `8184b9f` (triage).
- [x] Structured finding pattern `[(Blocker|Should|Could|Noted)]` present in §2 — grep count 86+ across agent sub-sections.
- [x] Triage table patterns `| fix |` / `| defer |` / `| noted |` present in §3 — all three patterns confirmed.

**Overall: Self-Check PASSED.** All 8 `must_haves.truths` met, all artifacts present, all key-links verified.

---
*Phase: 04-review-gate-persistence*
*Plan: 03*
*Completed: 2026-04-18*
