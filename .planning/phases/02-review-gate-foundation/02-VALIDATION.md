---
phase: 02
slug: review-gate-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dart tooling (`flutter analyze`, `dart format`, `flutter test`) + custom guard scripts (`tool/check_licenses.dart`, `tool/check_headers.dart`, `tool/check_dependencies_md.dart`) |
| **Config file** | `analysis_options.yaml` (analyze rules), `.github/workflows/ci.yml` (CI fan-out) |
| **Quick run command** | `dart run tool/check_licenses.dart && dart run tool/check_headers.dart && dart run tool/check_dependencies_md.dart` |
| **Full suite command** | `flutter analyze && dart format --set-exit-if-changed . && flutter test && dart run tool/check_licenses.dart && dart run tool/check_headers.dart && dart run tool/check_dependencies_md.dart` |
| **Estimated runtime** | ~60–90 seconds locally, ~4–6 minutes CI (Linux + macOS fan-out) |

---

## Sampling Rate

- **After every task commit:** Run `dart run tool/check_licenses.dart && dart run tool/check_headers.dart && dart run tool/check_dependencies_md.dart`
- **After every plan wave:** Run full suite (analyze + format + test + guards)
- **Before `/gsd:verify-work`:** Full suite must be green + adversarial branch CI must have failed as expected (evidence captured in `02-REVIEW.md`)
- **Max feedback latency:** ~90 seconds locally for guard scripts

---

## Per-Task Verification Map

> Phase 02 is a Review Gate — it verifies Phase 01 deliverables rather than introducing new REQ-IDs.
> Verification is evidence-based (documented in `02-REVIEW.md`) combined with adversarial CI runs.

| Task ID | Plan | Wave | Target | Test Type | Automated Command | File Exists | Status |
|---------|------|------|--------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | Protocol step 1 — solicit user first | manual | N/A (conversational) | ⚠️ manual | ⬜ pending |
| 02-01-02 | 01 | 1 | Protocol step 2 — findings as titles | manual | N/A (review artifact) | ⚠️ manual | ⬜ pending |
| 02-02-01 | 02 | 2 | Audit #1 — CI gates + adversarial design (parallel sub-agent) | agent-report | N/A (sub-agent output) | ⚠️ agent | ⬜ pending |
| 02-02-02 | 02 | 2 | Audit #2 — bootstrap + Windows visual walk (parallel sub-agent) | agent-report | `flutter run -d windows` | ⚠️ manual | ⬜ pending |
| 02-02-03 | 02 | 2 | Audit #3 — code quality sweep (parallel sub-agent) | agent-report | `flutter analyze && dart format --set-exit-if-changed .` | ✅ | ⬜ pending |
| 02-02-04 | 02 | 2 | Audit #4 — tests + tooling + CI (parallel sub-agent) | agent-report | `flutter test` | ✅ | ⬜ pending |
| 02-03-01 | 03 | 3 | Adversarial branch: GPL dep (`multi_dropdown`) triggers license failure | ci-run | `dart run tool/check_licenses.dart` (must exit 1) | ✅ | ⬜ pending |
| 02-03-02 | 03 | 3 | Adversarial branch: missing license header triggers `check_headers` failure | ci-run | `dart run tool/check_headers.dart` (must exit 1) | ✅ | ⬜ pending |
| 02-03-03 | 03 | 3 | Adversarial branch: undocumented dep triggers `check_dependencies_md` failure | ci-run | `dart run tool/check_dependencies_md.dart` (must exit 1) | ✅ | ⬜ pending |
| 02-03-04 | 03 | 3 | Adversarial branches deleted (local + remote) after archival | manual | `git branch -a` (no `review-gate/*` leftovers) | ⚠️ manual | ⬜ pending |
| 02-04-01 | 04 | 4 | Apply user-selected fixes, CI back to green on main | ci-run | Full suite | ✅ | ⬜ pending |
| 02-04-02 | 04 | 4 | `02-REVIEW.md` with 5 sections (scope, findings, adversarial evidence, decisions, unblock) | file-check | `test -f .planning/phases/02-review-gate-foundation/02-REVIEW.md` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky/manual*

---

## Wave 0 Requirements

- [ ] `.planning/phases/02-review-gate-foundation/02-REVIEW.md` — 5-section review artifact (scaffold in Wave 0, fill during Waves 1–4)
- [ ] No new test framework to install — `flutter test` + custom guards already present from Phase 01

*Wave 0 is lightweight for this phase: the audit infrastructure already exists.*

---

## Manual-Only Verifications

| Behavior | Target | Why Manual | Test Instructions |
|----------|--------|------------|-------------------|
| User solicited first ("qu'as-tu vu ?") before Claude presents findings | Success Criterion #1 | Conversational protocol — no automation possible | Verify transcript/review log in `02-REVIEW.md` shows user prompt before Claude's audit output |
| Findings presented as titles + short explanation, not diffs | Success Criterion #2 | Review artifact format — judgment-based | Open `02-REVIEW.md` §Findings, confirm each is title + ≤2 lines explanation, not code blocks |
| Windows desktop visual walk — app boots, logs file created, about screen shows GOSL v1.0 | Phase 01 bootstrap re-verification | Requires human eye on rendered UI | Run `flutter run -d windows`, click through launch → main → about, confirm log file in `%APPDATA%/.../logs/` |
| Adversarial CI run stderr shows `license violation` (not `pub get` misconfig) | Success Criterion #3 + research pitfall | Exit code 2 vs 1 distinction matters | `gh run view <id> --log-failed`, grep for license-violation message |

---

## Validation Sign-Off

- [ ] All tasks map to audit sub-agent or adversarial CI run (no orphan tasks)
- [ ] Sampling continuity: every audit task followed by quick-run guards before next commit
- [ ] Wave 0 covers `02-REVIEW.md` scaffold
- [ ] No watch-mode flags (`--watch`, `-w`) in any command
- [ ] Feedback latency < 90 seconds for local guards; CI fan-out < 6 minutes
- [ ] `nyquist_compliant: true` set in frontmatter after sign-off

**Approval:** pending
