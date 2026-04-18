---
phase: 04
slug: review-gate-persistence
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-18
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Phase 04 is a review-gate phase (no REQ-IDs) — validation maps to the 4 ROADMAP Success Criteria + CONTEXT gate-closed conditions. Full detail in `04-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `test` 1.25.2 (pure-Dart) + `flutter_test` (widgets, Phase 01 subset only) |
| **Config file** | `dart_test.yaml` at repo root (Phase 03 Plan 03-01; defines `migration` tag) |
| **Quick run command** | `dart test test/domain/ test/infrastructure/` |
| **Full suite command** | `flutter test && dart test test/domain/ test/infrastructure/` |
| **Estimated runtime** | ~35 s quick / ~70 s full (Phase 03 baseline, wall-clock Windows) |
| **Adversarial CI gate observation** | `gh run list --branch adversarial/04-<name> --limit 1 --json databaseId,status,conclusion` then `gh run view $RUN_ID --log-failed` |
| **Runtime walk capture** | `sqlite3 <db_path>` CLI outputs copied verbatim into §1b |

---

## Sampling Rate

- **After every task commit (Plan 04-05 fix loop):** run `flutter analyze --fatal-infos --fatal-warnings` + `dart format --line-length 160 --set-exit-if-changed .` + quick suite + 4 guard scripts (`check_headers`, `check_licenses`, `check_dependencies_md`, `check_domain_purity`). All exit 0 required before push.
- **After every plan wave (plan boundary):** wait for `gh run watch --exit-status <run-id>` green on `main` before starting the next plan.
- **Before `/gsd:verify-work`:** full suite green on `main` final commit; all 5 REVIEW.md sections filled; `**Status:** closed`; no `adversarial/04-*` branches local or remote; `.fixes-expected` scratch file deleted.
- **Max feedback latency:** ~70 s (full suite wall-clock) + ~90 s CI gates job.

---

## Per-Concern Verification Map

Phase 04 has no REQ-IDs (review gate). Validation maps to the 4 ROADMAP Success Criteria + CONTEXT gate-closed criteria.

| Concern | Plan | Wave | Source SC / Criterion | Test Type | Automated Command | File Exists | Status |
|---------|------|------|------------------------|-----------|-------------------|-------------|--------|
| 5-section REVIEW.md scaffold + §1 user capture | 04-01 | 1 | CONTEXT §Fix workflow & gate-closed criteria | file content | `grep -c '^## [1-5]\\.' .planning/phases/04-review-gate-persistence/04-REVIEW.md` must return `5` | ❌ W1 creates | ⬜ pending |
| Runtime walk §1b (6 PRAGMA + `.schema` + `.indexes`) | 04-02 | 2 | CONTEXT §Runtime walk Windows | file content | `grep -q '^### 1b\\. Runtime walk Windows' 04-REVIEW.md` + manual presence of 6 PRAGMA outputs | ❌ W2 creates | ⬜ pending |
| Pre-class 3 VERIFICATION candidates into §2 | 04-03 | 3 | CONTEXT §Triage 3 candidats | file content | `grep -q 'Pre-known from VERIFICATION' 04-REVIEW.md` + 3 entries (flaky/custom_lint/computeRevealMask) | ❌ W3 creates | ⬜ pending |
| 4-parallel sub-agent audit (schema/domain/stores/tests+tooling) | 04-03 | 3 | CONTEXT §Sub-agent slicing | process-verification | 4 agent return messages captured in `04-03-SUMMARY.md`; §2 populated with findings | ❌ W3 creates | ⬜ pending |
| §3 triage complete (user-driven) | 04-03 | 3 | SC#3 review protocol + CONTEXT §Fix workflow | file content | every §3 row filled: each Blocker = `fix`, each Should = `fix` or `waive` with rationale; zero `(pending)` | ❌ W3 creates | ⬜ pending |
| SC#1: V1→V2 migration framework validated | 04-04 | 4 | ROADMAP SC#1 | integration | `dart test test/infrastructure/db/migration_v1_to_v2_test.dart` green (exists from Phase 03 Plan 03-04) | ✅ Phase 03 | ⬜ pending |
| SC#1 extension: row-loss regression guard (Test #3) | 04-04 | 4 | ROADMAP SC#1 + CONTEXT §Adversarial #3 | unit (permanent) | `dart test test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` green | ❌ W4 Task 3 creates | ⬜ pending |
| Adversarial Test #1 evidence (domain-purity double violation) | 04-04 | 4 | CONTEXT §Adversarial #1 | CI policy violation | `gh run view $RUN_ID_1 --log-failed` contains 2 domain-purity violations; exit 1 | — (CI run URL archived §4) | ⬜ pending |
| Adversarial Test #2 evidence (drift schema dump stale) | 04-04 | 4 | CONTEXT §Adversarial #2 | CI policy violation | `gh run view $RUN_ID_2 --log-failed` contains `drift_schemas/drift_schema_current.json` diff; exit 1 | — (CI run URL archived §4) | ⬜ pending |
| Adversarial branch cleanup (local + remote) | 04-04 | 4 | CONTEXT §Adversarial structure | git | `! git branch -a --list 'adversarial/04-*' | grep .` exits 0 | — | ⬜ pending |
| SC#2: no `is`-chains / `dynamic` / singletons in domain | 04-03 → 04-05 | 3 → 5 | ROADMAP SC#2 | manual (Agent #2) + automated | `dart run tool/check_domain_purity.dart` exit 0 + Agent #2 finding log | ✅ tool exists | ⬜ pending |
| SC#2 extension: `computeRevealMask` no-callers guard | 04-05 | 5 | CONTEXT §Pre-class Should #3 | unit (permanent) | `dart test test/domain/compute_reveal_mask_no_callers_test.dart` green | ❌ W5 fix creates | ⬜ pending |
| `DEPENDENCIES.md` documents custom_lint silently-degraded | 04-05 | 5 | CONTEXT §Pre-class Noted #2 | file content | `grep -q 'silently-degraded' DEPENDENCIES.md` | — (edit) | ⬜ pending |
| `STATE.md` Accumulated Decisions entry for custom_lint + Phase 04 complete | 04-05 | 5 | CONTEXT §Integration points | file content | new line in `## Accumulated Decisions`; Phase 04 row flipped | — (edit) | ⬜ pending |
| SC#3: review protocol applied (user-first commit order) | 04-01 → 04-03 | 1 → 3 | ROADMAP SC#3 | process-verification | `git log --oneline -- .planning/phases/04-review-gate-persistence/` shows `docs(04-rev): scaffold` → `docs(04-rev): capture user-observed findings` → runtime walk commits → pre-class before agent audit commits | — | ⬜ pending |
| SC#4: fixes integrated + tests green before Phase 05 | 04-05 | 5 | ROADMAP SC#4 | CI-verified | `gh run list --branch main --limit 1 --json conclusion --jq '.[0].conclusion'` returns `"success"` on the closure commit | — | ⬜ pending |
| §5 CI-green closure + status flip | 04-05 | 5 | CONTEXT §Fix workflow & gate-closed | file content | `grep -q '\\*\\*Status:\\*\\* closed' 04-REVIEW.md` + final commit hash + run URL in §5 | — (edit) | ⬜ pending |
| `.fixes-expected` scratch file deleted | 04-05 | 5 | CONTEXT §Fix workflow | file absence | `! test -f .planning/phases/04-review-gate-persistence/.fixes-expected` | — (creates + deletes) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

No Wave 0 gaps — test infrastructure is complete from Phase 03:

- `dart_test.yaml` exists (root)
- `test/generated_migrations/` has `schema.dart` + `schema_v1.dart` + `schema_v2.dart` (consumed by migration tests)
- `test/fixtures/` has `json/session_v{1,2}.json`, `json/markers_only_v1.json`, `json/mirk_style_unknown_renderer.json`, `db_seed/v1_baseline.sql`
- Both `dart test` (pure-Dart) and `flutter test` (Flutter widgets) runners operational

Phase 04 adds fresh test files during plan execution (not Wave 0, they are the deliverables):

- `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart` — Plan 04-04 Task 3 (permanent regression guard)
- `test/domain/compute_reveal_mask_no_callers_test.dart` — Plan 04-05 Should #3 fix
- `tool/walk_db.dart` — Plan 04-02 Task 1 (scratch utility; retention decided at plan checkpoint)

---

## Manual-Only Verifications

| Behavior | Source | Why Manual | Test Instructions |
|----------|--------|------------|-------------------|
| Runtime walk execution | CONTEXT §Runtime walk Windows | `flutter run -d windows` / `dart run tool/walk_db.dart` is user-driven; observations (DB file sizes, sqlite3 CLI output) must be pasted into chat by user | Plan 04-02 prompts user; user pastes `ls` sizes + `sqlite3 .schema` + 6 PRAGMA outputs + `.indexes t_sessions`. Claude archives verbatim into §1b. |
| User IDE findings capture (§1) | SC#3 + CONTEXT §Ordering strict | User audit with their IDE; Claude cannot auto-generate | Plan 04-01 Task 2 solicits user; user types findings in chat; Claude commits verbatim into §1 via `docs(04-rev): capture user-observed findings`. Must precede any agent spawn. |
| §3 triage decisions | SC#3 + CONTEXT §Output contract | Severity + disposition (fix / waive) is user judgment per finding | Plan 04-03 Task 4 presents titles + 1-line explanations; user picks disposition; Claude fills §3 rows. |
| Plan 04-02 utility retention decision | CONTEXT §Claude's Discretion | Keep `tool/walk_db.dart` as debug utility OR delete post-walk | Plan 04-02 final checkpoint asks user. |
| Test #2 adversarial column choice | CONTEXT §Claude's Discretion | `notesExtra` is suggested; any observable addition works | Plan 04-04 Task 2 may confirm with user or default to `notesExtra`. |

---

## Validation Sign-Off

- [ ] All 18 concerns in map have automated verify command OR Manual-Only entry
- [ ] Sampling continuity: 3 consecutive plans without automated verify does not occur (plans 04-01/02/03 have file-content greps; 04-04/05 have both unit tests and CI-verified)
- [ ] Wave 0 covers all MISSING references (no Wave 0 gaps — Phase 03 test infra complete)
- [ ] No watch-mode flags in suite commands
- [ ] Feedback latency < 70 s quick / < 90 s CI gates job
- [ ] `nyquist_compliant: true` set in frontmatter (after planner fills must-haves per plan)

**Approval:** pending
