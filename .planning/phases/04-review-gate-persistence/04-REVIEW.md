# Phase 04: Review Gate — Persistence Review

**Opened:** 2026-04-18
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude's audit.*

(awaiting user input — Task 2 of this plan fills this section)

### 1b. Runtime walk Windows

*Filled by Plan 04-02 Task 3 after the user runs the walk script and pastes outputs.*

<details>
<summary>DB path + file sizes + PRAGMA + schema + index dumps</summary>
(pending — filled by Plan 04-02)
</details>

## 2. Claude audit findings

*Filled by Plan 04-03: first the 3 pre-classified VERIFICATION candidates, then the 4 parallel sub-agents in ONE tool-use message.*

Format: `[severity] Title — 1-line explanation — file:line`. Severities: Blocker / Should / Could / Noted.

### Pre-known from VERIFICATION

*Filled by Plan 04-03 Task 1 BEFORE spawning sub-agents. Source: 03-VERIFICATION.md §Outstanding minor items. Committed as `docs(04-rev): pre-class 3 VERIFICATION candidates into §2` before any Agent tool call.*

(pending — 3 entries: flaky `backup_test.dart::rotate` Blocker | `custom_lint` silently degraded Noted | `computeRevealMask` UnimplementedError Should)

### Agent #1 — Schema + migrations + backup
(pending)

### Agent #2 — Domain models + pureté
(pending)

### Agent #3 — Store layer + factory + providers
(pending)

### Agent #4 — Tests + fixtures + tooling + CLAUDE.md sweep
(pending)

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>
(pending)
</details>

## 3. Triage decisions

*Filled by Plan 04-03 Task 3 after user selects what to fix. Every Blocker MUST be `fix` (waiver forbidden per CONTEXT.md). Every Should MUST be either `fix` or `waived` with inline rationale.*

| # | Finding | Severity | Decision | Rationale |
|---|---------|----------|----------|-----------|
| (pending) | | | | |

## 4. Adversarial evidence

*Filled by Plan 04-04. Two CI-branch evidence blocks (Tests #1, #2) + one permanent unit-test evidence block (Test #3).*

### Test 1: Domain purity import violation (Flutter + Drift)
*Branch `adversarial/04-domain-import-flutter-and-drift`: one branch, TWO violations. CI step `Check domain purity (lib/domain/ imports)` must fail with exit 1 listing BOTH `lib/domain/sessions/session.dart` (Flutter import) AND `lib/domain/markers/marker.dart` (Drift import).*

(pending)

### Test 2: Drift schema dump stale
*Branch `adversarial/04-schema-drift-stale`: add a column to `t_sessions` in `app_database.dart`, run `build_runner build` (mandatory — otherwise `flutter analyze` fails first per RESEARCH Pitfall 1), do NOT run `drift_dev schema dump`. CI step `Check drift schema (current) is committed and fresh` must fail with `git diff --exit-code` showing stale `drift_schemas/drift_schema_current.json`.*

(pending)

### Test 3: SchemaSanityChecker row-loss detection (permanent unit test)
*NOT a throwaway branch. Permanent test `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` on `main`. Injects V1 fixture (70 rows), runs adversarial migration with `ALTER TABLE` + `DELETE FROM t_sessions WHERE rowid % 2 = 0`, asserts `SchemaSanityChecker.assertNoLoss` throws `MigrationFailureException` with exact row-count diff. Evidence = commit hash + green `dart test` output.*

(pending)

## 5. CI-green confirmation

*Filled by Plan 04-05 Task 2 after all Blocker + non-waived Should fixes are applied and CI is green.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending)
- **Date:** (pending)

---
_Phase 04 closed: (pending)_
_Phase 05 unblocked._
