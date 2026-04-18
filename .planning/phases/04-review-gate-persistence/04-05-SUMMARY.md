---
phase: 04-review-gate-persistence
plan: 05
subsystem: review-gate
tags: [drift, sqlite, session-store, mergeMask, backup-rotation, custom-lint, dependency-audit, review-gate, fix-loop]

# Dependency graph
requires:
  - phase: 03-persistence-domain-models
    provides: AppDatabase + 5 Drift stores + SchemaSanityChecker + DbBackupService + domain entities that Plan 04-05 fixes harden
  - phase: 04-review-gate-persistence/04-03
    provides: Triaged §3 table (31 fix-marked rows) + 4-agent audit findings
  - phase: 04-review-gate-persistence/04-04
    provides: Adversarial evidence in §4 (3 tests) + permanent SchemaSanityChecker regression guard + surprise-finding chore(format) item

provides:
  - All 31 §3 fix-triaged findings landed as atomic commits on main
  - P4 Zone mismatch resolved at boot (option-b pivot after option-a failed user walk)
  - DbBackup rotation deterministic (filename-ISO sort, no mtime dependence)
  - cat_default sentinel seeded onCreate (closes latent FK contract)
  - Session store error signaling complete (SessionNotFoundException on state transitions, SqliteException 2067 wrap at all 3 write sites)
  - mergeMask cold-start race guarded (INSERT OR IGNORE + SELECT-retry)
  - Domain @Assert invariants for off-range/negative values
  - DB CHECK constraints on status/offsets/bitmap
  - UTC offset bounds extracted to constants
  - parentZoom magic replaced with kRevealedTileParentZoom
  - Typed DSL for MarkerCategory reassign (survives table rename)
  - Marker listing DESC (most-recent-first UX)
  - Tooling guards (migration tag, pubspec overrides scan, SQL block comment strip, check_domain_purity drift_flutter arm)
  - compute_reveal_mask no-callers guard (Phase 09 scope invariant)
  - walk_db.dart pragma probe via live Drift connection (closes walk-tooling gap)
  - custom_lint silent-degrade formally accepted in DEPENDENCIES.md + STATE.md (Phase 04 Noted P2)
  - 04-REVIEW.md status=closed + Phase 04 ROADMAP tick + Phase 05 unblocked

affects:
  - phase-05-gps-session-lifecycle
  - phase-09-fog-rendering  # compute_reveal_mask no-callers guard + marker DESC ordering
  - phase-11-markers-categories  # cat_default seed + MarkerCategory typed DSL + Marker ordering
  - phase-15-polish  # custom_lint re-verify at latest

# Tech tracking
tech-stack:
  added: []  # No new dependencies — all fixes are internal hardening of Phase 03 code
  patterns:
    - "INSERT OR IGNORE + SELECT-retry for cold-start race recovery (reusable for any composite-unique-key write path)"
    - "Converter-only status strings in store layer (raw 'active'/'stopped' replaced with _statusConv.toSql(enum) at every site)"
    - "Filename-embedded ISO timestamp sort (immune to filesystem mtime precision)"
    - "Allowlist carve-out for known-intentional caret overrides in pubspec_pinned_test"
    - "Source-scanning no-callers guard as a Phase-N-scope invariant (anti-pattern documented per CLAUDE.md §Workarounds)"
    - "Batched fix-loop strategy (10 batches × CI gate) as a user-approved alternative to per-finding protocol"

key-files:
  created:
    - test/domain/compute_reveal_mask_no_callers_test.dart
  modified:
    - lib/infrastructure/db/app_database.dart  # cat_default onCreate seed + docstrings + dead import removed
    - lib/infrastructure/db/backup.dart  # filename-ISO sort, mtime dep removed
    - lib/infrastructure/stores/drift_session_store.dart  # error signaling + converter + IdGenerator dropped
    - lib/infrastructure/stores/drift_revealed_tile_store.dart  # INSERT OR IGNORE race guard + RevealedTileId.prefix
    - lib/infrastructure/stores/drift_marker_category_store.dart  # typed DSL for reassign
    - lib/infrastructure/stores/drift_marker_store.dart  # DESC ordering
    - lib/domain/markers/marker_store.dart  # port docstring DESC
    - lib/domain/ids/default_ids.dart  # docstring aligned with onCreate seed
    - lib/application/providers/session_store_provider.dart  # IdGenerator dropped
    - lib/main.dart  # P4 Zone mismatch option-b
    - tool/walk_db.dart  # pragma probe via live Drift connection
    - tool/check_domain_purity.dart  # drift_flutter arm
    - test/infrastructure/db/backup_test.dart  # filename-ISO + orphan + deterministic clock
    - test/infrastructure/db/v1_identity_fixture_test.dart  # @Tags migration + block comment strip
    - test/infrastructure/db/migration_v1_to_v2_test.dart  # block comment strip
    - test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart  # block comment strip
    - test/infrastructure/db/schema_sanity_test.dart  # cat_default seeded expectation
    - test/infrastructure/db/app_database_schema_test.dart  # cat_default seeded expectation
    - test/infrastructure/stores/marker_category_store_cascade_test.dart  # regression guards + seeded expectation
    - test/infrastructure/stores/drift_session_store_cascade_test.dart  # constructor + cat_default seeded
    - test/infrastructure/stores/session_store_exclusivity_test.dart  # constructor + insert/update/activate coverage
    - test/infrastructure/stores/session_store_error_mapping_test.dart  # constructor
    - test/infrastructure/stores/revealed_tile_store_concurrent_test.dart  # cold-start race regression
    - test/pubspec_pinned_test.dart  # dependency_overrides scan + allowlist
    - test/fixtures/README.md  # repo-root drift_schemas path
    - tool/test/check_domain_purity_test.dart  # drift_flutter case
    - .planning/phases/04-review-gate-persistence/04-REVIEW.md  # 31 row-markers + §5 closure + status=closed
    - DEPENDENCIES.md  # custom_lint silent-degrade Status marker
    - .planning/STATE.md  # Phase 04 closure + strategy deviation + P4 pivot decisions + custom_lint acceptance
    - .planning/ROADMAP.md  # Phase 04 5/5 Complete

key-decisions:
  - "User selected BATCHED fix-loop strategy over per-finding protocol — 10 × 10-min CI gates instead of 31, with batch-granularity bisectability"
  - "P4 Zone mismatch option-b pivot after option-a user-walk failure — binding init + runApp BOTH inside runZonedGuarded is the canonical Flutter 3.41+ pattern"
  - "Paired-fix collapses documented: P1↔#1↔#35 (backup sort), #5↔#13 (parentZoom), #7↔#11 (UTC offset), #20↔#32 (mergeMask race), #25↔#3 (session state signaling)"
  - "IdGenerator dropped from DriftSessionStore — never used; provider + 3 test constructors updated; re-inject if insert-without-id path emerges"
  - "cat_default seeded onCreate (2026-04-18 timestamp, offset 0 UTC — stable sentinel, no wall-clock dependency)"
  - "INSERT OR IGNORE + re-SELECT pattern over explicit SERIALIZABLE transaction for mergeMask cold-start race — simpler, same guarantees"
  - "custom_lint silent-degrade formally accepted at Phase 04 review-gate — no operational impact under analyzer-10 stack; re-verify at each deps bump"

patterns-established:
  - "Batched fix loop with CI gate between batches (reusable for Phase 06/08/10/12/14/16 review gates)"
  - "Row-marker commit protocol (docs commit after each fix commit marking the §3 rows done)"
  - "Mandatory pragma probe via live Drift connection in any future runtime walk (sqlite3 CLI cannot observe per-connection pragmas)"
  - "No-callers source-scanning guard as a Phase-N-scope invariant, documented as a WORKAROUND with explicit removal condition"

requirements-completed:
  - SC#1  # Migration framework validated — SchemaSanityChecker carries row-loss guard from 04-04
  - SC#2  # Domain purity + polymorphism verified by 4-agent audit + no-callers guard
  - SC#4  # Review protocol applied, fixes landed, tests green

# Metrics
duration: ~3h
completed: 2026-04-19
---

# Phase 04 Plan 05: Review Loop Closure Summary

**Closed Phase 04 review gate after landing 15 atomic fix commits (10 batches) covering all 31 §3 fix-triaged findings, including the P4 Zone mismatch pivot, CI green on 26f3d99; Phase 05 GPS background POC now unblocked.**

## Performance

- **Duration:** ~3 h (execution across multiple sessions including user walk verification for P4)
- **Started:** 2026-04-18 (Batch pre-A / UTC offsets)
- **Completed:** 2026-04-19
- **Tasks:** 2 (Task 1 — fix loop; Task 2 — closure checkpoint + STATE/ROADMAP update)
- **Files modified:** 30+ across lib/, test/, tool/, .planning/, docs

## Accomplishments

- All 31 §3 fix-triaged findings landed as atomic commits, CI gated between each
- Pre-class P1 + P4 + P5 resolved; P2 accepted as Noted in DEPENDENCIES.md + STATE.md; P3 protected by no-callers guard
- Session store hardening: SessionNotFoundException signaling + SqliteException 2067 wrap at insert/update/activate + converter-only status strings + IdGenerator dropped
- DbBackup rotation refactored to filename-ISO sort — fixes the P1 flake at the architectural level and removes the mtime fragility that would have affected production
- mergeMask cold-start race guarded with INSERT OR IGNORE + SELECT-retry (future-proofs against NativeDatabase.createInBackground swap)
- cat_default seeded onCreate — closes the latent FK contract that would have broken MarkerCategory.delete on a fresh DB
- Tooling guards tightened: migration tag restored, pubspec overrides scanned, SQL block comments stripped, check_domain_purity covers drift_flutter, walk_db.dart pragma probe added
- 04-REVIEW.md §5 populated with per-batch evidence table + P4 user-walk confirmation + final main HEAD + CI URL

## Task Commits

### Batch pre-A — UTC offsets (#7, #11)
- `74f1bb2` fix(04-rev): extract UTC offset bounds to constants.dart
- `571ffd7` docs(04-rev): mark findings #7 #11 as fixed

### Chore — dart format align
- `35152e5` chore(format): align with CI dart format (resolves deferred-items #1 from 04-04)

### Batch A — domain @Assert invariants (#15, #16, #17, #18, #19)
- `e307ace` fix(04-rev): add entity @Assert invariants for off-range/negative values
- `82a0ee7` fix(04-rev): address CI regression on Batch A — redundant-argument info
- `a155e79` docs(04-rev): mark findings #15-19 as fixed

### Batch B — DB-level CHECK constraints (#10, #12, #14)
- `b042a1c` fix(04-rev): add DB CHECK constraints for status/offsets/bitmap
- `c47575b` docs(04-rev): mark findings #10 #12 #14 as fixed

### Batch C — parentZoom magic (#5, #13)
- `54313ce` refactor(04-rev): replace parentZoom magic 14 with kRevealedTileParentZoom
- `82b59e7` docs(04-rev): mark findings #5 #13 as fixed

### Batch D — P4 Zone mismatch (pre-class walk finding)
- `56b164f` fix(04-rev): move runApp to root zone to fix Zone mismatch crash  *(option a — FAILED user walk)*
- `e45339f` fix(04-rev): move binding init inside runZonedGuarded zone (P4 option b)  *(option b — user-walk clean)*
- No explicit docs marker — P4 is a pre-class row; marked `fix (done ...)` inline

### Adversarial wave carry-over (from 04-04)
- `9c32eb1` test(04-rev): add SchemaSanityChecker row-loss regression guard

### Batch E — backup filename-ISO sort (#1, #29, #35, P1)
- `72da162` fix(04-rev): sort backups by filename ISO timestamp for determinism
- `88904b0` docs(04-rev): mark findings #1 #29 #35 P1 as fixed

### Batch F — cat_default seed + docstrings (#2, #8)
- `2e528df` fix(04-rev): seed cat_default sentinel onCreate + align docstrings
- `6069951` docs(04-rev): mark findings #2 #8 as fixed

### Batch G — session store hardening (#3, #4, #9, #21, #22, #24, #25, #26)
- `6425889` fix(04-rev): tighten session store error signaling + converter usage + cleanup
- `c4d72f7` docs(04-rev): mark findings #3 #4 #9 #21 #22 #24 #25 #26 as fixed

### Batch H — mergeMask cold-start race (#20, #32)
- `daed232` fix(04-rev): atomic mergeMask under cold-start race and createInBackground
- `ea14978` docs(04-rev): mark findings #20 #32 as fixed

### Batch I — typed DSL + marker DESC ordering (#23, #27)
- `5ee9838` fix(04-rev): typed DSL for category reassign + marker DESC ordering
- `3862a31` docs(04-rev): mark findings #23 #27 as fixed

### Batch J — tooling guards + P3 + P5 (#6, #28, #30, #31, #33, P3, P5)
- `676bcb8` fix(04-rev): tighten tooling guards + add P3 no-callers + P5 pragma probe
- `b7d6b6f` docs(04-rev): mark findings #6 #28 #30 #31 #33 P3 P5 as fixed

### Batch K — P2 custom_lint documentation (2 docs commits, NOT in fix tally)
- `4e1cb3c` docs(04-rev): document custom_lint silent-degrade in STATE.md
- `26f3d99` docs(04-rev): mark custom_lint silent-degrade in DEPENDENCIES.md

### Closure
- `1ed9583` docs(04-rev): close Phase 04 Review Gate — CI green on 26f3d99
- (this plan summary + STATE.md + ROADMAP.md update + `.fixes-expected` deletion — final commit covers all three)

**Fix-tally commit count:** 15 (`fix|refactor|test`(04-rev): ...) — reconciled against the `.fixes-expected=31` snapshot via user-approved batched-granularity strategy (see Deviations).

**Final main HEAD at closure:** `26f3d99`
**Final CI run:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24616052442 — all 3 jobs green (gates / android / ios)

## Decisions Made

- **Strategy deviation: batched fix loop** (user-approved during execution). 10 × 10-min CI batches instead of 31 × 10-min per-finding cycles. Batch-granularity bisectability: `git bisect` locates the batch, not the individual finding. Acceptable trade-off against wall-clock parallelism.
- **P4 option-b pivot** after option-a user walk failed. Option-a (ensureInitialized + runApp in root zone, runZonedGuarded wraps logger body only) still tripped `debugCheckZone` on Flutter 3.41.7's `_runWidget`. Option-b (both inside runZonedGuarded) is the canonical pattern and works. Comment block in `main.dart` preserves the reasoning for future maintainers.
- **Paired-fix collapses** documented in §3 and this summary: one architectural fix covers multiple findings when the root cause is shared (P1↔#1↔#35 backup sort; #5↔#13 parentZoom; #7↔#11 UTC offset; #20↔#32 mergeMask race; #25↔#3 session state signaling).
- **IdGenerator dropped from DriftSessionStore** — never used, per `// ignore: unused_field` suppression. Provider + 3 test constructors updated. Re-inject if a future insert-without-id path emerges.
- **cat_default seeded onCreate** (deterministic 2026-04-18 timestamp, offset 0 UTC). Docstrings in `app_database.dart` + `default_ids.dart` aligned to the new single source of truth.
- **INSERT OR IGNORE + re-SELECT** for the mergeMask cold-start race. Simpler than an explicit SERIALIZABLE transaction boundary and gives the same guarantees under both NativeDatabase and NativeDatabase.createInBackground.
- **custom_lint silent-degrade formally accepted** at Phase 04 review-gate level (was Phase 03 STATE.md decision only). Documented in DEPENDENCIES.md + STATE.md; re-verify at each deps bump and Phase 15 latest.

## Deviations from Plan

### 1. Strategy: BATCHED fix loop (user-approved)

- **Plan said:** One finding = one `fix(04-rev):` commit, CI green before next.
- **Execution:** 10 atomic batches grouped by architectural theme (domain asserts / DB checks / session hardening / etc.), each followed by a `docs(04-rev):` row-marker commit.
- **Rationale:** User explicitly approved `batched` strategy after Batch A; trade-off is batch-granularity bisectability against wall-clock efficiency. 15 fix commits + 11 docs markers total vs 31 × 2 = 62 commits under the strict protocol.
- **Verify assertion impact:** `.fixes-expected=31` snapshot preserved as historical record. The `Task 1 <automated>` check (commits >= snapshot) would fail at 15 < 31; this is a DOCUMENTED acceptance. The integrity of the review-gate contract (every fix-triaged row has `fix (done <hash>)` marker + corresponding commit on main) is maintained through the §3 row markers.

### 2. P4 Zone mismatch — two-attempt resolution (architectural lesson)

- **Finding:** Pre-class P4 (Zone mismatch at runApp during `flutter run -d windows`, §1b runtime walk).
- **First attempt (Batch D option-a, commit 56b164f):** Move runApp + ensureInitialized to the root zone, wrap only the logger/handler body in runZonedGuarded. Matched the Phase 01 RESEARCH pitfall interpretation.
- **User walk result:** STILL crashed with Zone mismatch on re-run. `debugCheckZone` fires at `_runWidget` regardless of the exact ordering if the zone boundary crosses between bindings and runApp.
- **Second attempt (Batch D option-b, commit e45339f):** Move BOTH binding init AND runApp INSIDE the guarded zone. Canonical Flutter 3.41+ pattern per `runZonedGuarded` recipe.
- **User walk result:** Clean boot, no exception. P4 resolved.
- **Lesson preserved in main.dart comments:** The "canonical pattern" is to wrap the entire bootstrap (binding init + handlers + runApp) in one guarded zone, contra the Phase 01 RESEARCH document's stricter reading. Future maintainers MUST NOT move binding init back to the root zone without retesting `flutter run -d windows`.

### 3. CI regression on Batch A — follow-up commit (Rule 3 blocking)

- **Finding:** During Batch A execution, the initial fix (`e307ace`) surfaced a `prefer_redundant_argument` info-level analyze warning on the @Assert bodies.
- **Fix:** Added a follow-up commit `82a0ee7` to address the info-level CI regression. No separate plan deviation — handled as Rule 3 (blocking issue: CI red blocks batch progression).

### 4. Test suite updates beyond the plan text

- **Finding:** Batch F (cat_default seed) surfaced 6 failing tests that explicitly re-inserted `cat_default` manually — post-seed those INSERTs became PK-collisions.
- **Fix:** Simplified those tests (dropped the manual re-insert; updated row-count expectations). Not in the plan's scope-of-change enumeration but necessary for the seed to land CI-green.
- **Files touched:** `test/infrastructure/db/app_database_schema_test.dart`, `test/infrastructure/db/schema_sanity_test.dart`, `test/infrastructure/stores/drift_session_store_cascade_test.dart`, `test/infrastructure/stores/marker_category_store_cascade_test.dart`. All adjacent to the fix path.

### 5. IdGenerator drop cascade (finding #21)

- **Plan said:** "Drop the field + constructor param in `drift_session_store.dart:31-35`."
- **Execution:** Also updated 1 production provider (`session_store_provider.dart`), 3 test constructors (`session_store_exclusivity_test.dart`, `session_store_error_mapping_test.dart`, `drift_session_store_cascade_test.dart`). All callers of the removed constructor param.
- **Rationale:** Can't land #21 without fixing the callers; scope creep is mechanical.

**Total deviations:** 5 documented. Zero scope creep beyond making the landed fixes actually work. No architectural changes beyond what the plan triage already blessed.

## Issues Encountered

- **P4 option-a regression.** Burned one commit + one user-walk before pivoting to option-b. Cost: ~20 min + commit history noise; benefit: architectural lesson captured in `main.dart` comments + STATE.md decision log.
- **6 tests regressed after cat_default seed.** Caught by the CI-gated batch protocol — no test reached `main` in a broken state. ~15 min to fix.
- **`driftRuntimeOptions` import clarity.** Batch F regression tests needed `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` to silence a multi-instance warning. Import works via `package:drift/drift.dart` (the same re-export used elsewhere), no private-path import needed.

## User Setup Required

None — every fix is a pure code/test change. No secrets, no new env vars, no external services touched.

## Next Phase Readiness

- **Phase 04 CLOSED** — 04-REVIEW.md status=closed, §5 populated, `.fixes-expected` deleted, STATE + ROADMAP updated.
- **Phase 05 unblocked** — can open `/gsd:plan-phase 05` to start the GPS background POC.
- **Carry-forward concerns for Phase 05:**
  - MergeMask is now `createInBackground`-safe. If Phase 05 profiles the open-path and decides to swap the Drift executor, the `INSERT OR IGNORE` path is the stress-test that must stay green.
  - Session store's SessionNotFoundException signaling is now a hard contract. Phase 05's ActiveSessionController MUST NOT catch-and-swallow it (would hide a bug class).
  - `deferred-items.md` item #1 is resolved (commit 35152e5); item #2 was the same root cause; file can be left as historic reference or deleted.

---
*Phase: 04-review-gate-persistence*
*Plan: 05*
*Completed: 2026-04-19*

## Self-Check: PASSED

- `.planning/phases/04-review-gate-persistence/04-05-SUMMARY.md` — FOUND
- `test/domain/compute_reveal_mask_no_callers_test.dart` — FOUND
- Key commits verified (all present on main): 26f3d99 (final HEAD), 1ed9583 (closure), 4e1cb3c (STATE custom_lint), 676bcb8 (Batch J), 5ee9838 (Batch I), daed232 (Batch H), 6425889 (Batch G), 2e528df (Batch F), 72da162 (Batch E), e45339f (P4 option b), 9c32eb1 (Test #3 guard)
- `.fixes-expected` snapshot file DELETED (Phase 02 precedent lifecycle honored)
- CI on final HEAD 26f3d99: all 3 jobs green (run 24616052442)
