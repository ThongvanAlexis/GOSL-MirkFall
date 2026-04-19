---
phase: 06
slug: review-gate-gps
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-20
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dart `test` 1.25.x + Flutter `flutter_test` (already installed Phases 01-05) |
| **Config file** | `dart_test.yaml` (none currently — only `analysis_options.yaml`) |
| **Quick run command** | `dart test tool/test/ && flutter test test/infrastructure/platform/ test/application/permissions/ test/tooling/` |
| **Full suite command** | `flutter test && dart test tool/test/ && flutter analyze --fatal-infos --fatal-warnings && dart format --set-exit-if-changed lib/ test/ tool/` |
| **Estimated runtime** | ~25s (quick) / ~90s (full) on Windows dev machine |

---

## Sampling Rate

- **After every task commit:** Run quick command (scoped to the touched test directory)
- **After every plan wave:** Run full suite command locally + push and watch GitHub Actions `gates` job (CI is the authority for review-gate phases per CONTEXT 06)
- **Before `/gsd:verify-work`:** Full suite must be green on `main` HEAD + `06-REVIEW.md` 5 sections grep-passing + `tool/check_platform_manifests.dart` exit 0 on `main` AND exit 1 on `adversarial/06-manifest-drift` archived run
- **Max feedback latency:** 25s local quick / ~6 min CI gates job

---

## Per-Task Verification Map

Phase 06 is a review-gate phase: most tasks produce **artifacts** (REVIEW.md sections, ROADMAP amendment, evidence blocks) rather than runtime code. Validation maps SC#1-4 + implicit gate-closed conditions to test/artifact/CI evidence.

| Task ID | Plan | Wave | Maps To | Test Type | Automated Command | File Exists | Status |
|---------|------|------|---------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | SC#3 (review protocol applied) | artifact-grep | `grep -E "^## [1-5]\." .planning/phases/06-review-gate-gps/06-REVIEW.md \| wc -l` (must be 5) | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | SC#3 + user-first ordering | artifact-presence | `test -s .planning/phases/06-review-gate-gps/06-REVIEW.md && grep -q "## 1\." .planning/phases/06-review-gate-gps/06-REVIEW.md` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 1 | SC#1 (POC artifacts archived) + SC#2 (battery measurement) | artifact-evidence | `grep -q "## 1b\." .planning/phases/06-review-gate-gps/06-REVIEW.md && grep -q "qual-01-02-poc.md" .planning/phases/06-review-gate-gps/06-REVIEW.md` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 2 | SC#3 (pre-class §2 protocol) | artifact-grep | `grep -c "^- \[" .planning/phases/06-review-gate-gps/06-REVIEW.md` (must be ≥ 8 in §2) | ❌ W0 | ⬜ pending |
| 06-03-02 | 03 | 2 | SC#4 (OEM workaround documented) | artifact-evidence | `grep -q "OemFamily" .planning/phases/06-review-gate-gps/06-REVIEW.md && grep -q "dontkillmyapp.com" .planning/phases/06-review-gate-gps/06-REVIEW.md` | ❌ W0 | ⬜ pending |
| 06-03-03 | 03 | 2 | SC#3 (4 audit agents wave) | artifact-evidence | `grep -E "Agent #[1-4]" .planning/phases/06-review-gate-gps/06-REVIEW.md \| wc -l` (must be ≥ 4) | ❌ W0 | ⬜ pending |
| 06-04-01 | 04 | 3 | gate-closed: MethodChannel sync | unit | `flutter test test/infrastructure/platform/method_channel_sync_test.dart` | ❌ W0 | ⬜ pending |
| 06-04-02 | 04 | 3 | gate-closed: permission cascade | unit | `flutter test test/application/permissions/location_permission_cascade_test.dart` | ❌ W0 | ⬜ pending |
| 06-04-03 | 04 | 3 | gate-closed: OemDetector ambiguous | unit | `flutter test test/infrastructure/platform/oem_detector_ambiguous_test.dart` | ❌ W0 | ⬜ pending |
| 06-04-04 | 04 | 3 | gate-closed: platform manifests parsed | unit | `dart test test/tooling/platform_manifests_test.dart` | ❌ W0 | ⬜ pending |
| 06-04-05 | 04 | 3 | gate-closed: Android boot receiver contract | unit | `dart test test/infrastructure/platform/android_boot_receiver_contract_test.dart` | ❌ W0 | ⬜ pending |
| 06-04-06 | 04 | 3 | gate-closed: new CI gate script behaves | unit | `dart test tool/test/check_platform_manifests_test.dart` | ❌ W0 | ⬜ pending |
| 06-04-07 | 04 | 3 | gate-closed: new CI gate script clean exit on main | static-gate | `dart run tool/check_platform_manifests.dart` (exit 0) | ❌ W0 | ⬜ pending |
| 06-04-08 | 04 | 3 | gate-closed: adversarial branch surfaces violation | CI-run | push `adversarial/06-manifest-drift`, observe `gh run view` exit-1 + stderr identifying missing entry; archive run ID into §4 | ❌ W0 | ⬜ pending |
| 06-05-01 | 05 | 4 | SC#1 (artifacts location aligned with reality) | artifact-amendment | `grep -q "docs/qual-01-02-poc.md" .planning/ROADMAP.md && ! grep -q ".planning/pocs/phase-05/" .planning/ROADMAP.md` | ✅ (existing path) | ⬜ pending |
| 06-05-02 | 05 | 4 | gate-closed: every Blocker fixed | artifact-evidence | `! grep -E "^- \[ \] \[Blocker\]" .planning/phases/06-review-gate-gps/06-REVIEW.md` (no unchecked Blocker) | ❌ W0 | ⬜ pending |
| 06-05-03 | 05 | 4 | gate-closed: every Should fixed OR explicitly waived | artifact-evidence | manual review of §3 Should rows: each must show `✓ fixed in <commit>` OR `⚠ waived: <rationale>` | n/a (manual check on §3) | ⬜ pending |
| 06-05-04 | 05 | 4 | gate-closed: CI green on final main commit | CI-run | `gh run list --branch main --limit 1 --json conclusion --jq '.[0].conclusion'` (must be `success`) | ✅ (existing CI) | ⬜ pending |
| 06-05-05 | 05 | 4 | SC#3 (final REVIEW.md complete) | artifact-grep | `grep -E "^## [1-5]\." .planning/phases/06-review-gate-gps/06-REVIEW.md \| wc -l` (must remain 5) + `grep -q "Status: closed" .planning/phases/06-review-gate-gps/06-REVIEW.md` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> **Path correction (revision 2026-04-20):** rows 06-04-01, 06-04-05, 06-04-06 — earlier draft used stale paths (`test/infrastructure/boot_watchdog/`, `test/tooling/check_platform_manifests_test.dart`). The directory `lib/infrastructure/boot_watchdog/` was renamed to `lib/infrastructure/platform/` during Phase 05 (verified on disk: `ls lib/infrastructure/` shows `platform/`, not `boot_watchdog/`); test mirror lives at `test/infrastructure/platform/`. The paired tool unit test for `tool/check_platform_manifests.dart` lives at `tool/test/check_platform_manifests_test.dart` to match the existing Phase 02 convention (verified: `ci.yml` line 76–77 step `Tool scripts unit tests` runs `dart test tool/test/`, picking up the new test automatically — no ci.yml amendment needed for that test). Rows 06-04-01 / 06-04-02 / 06-04-03 use `flutter test` (require Flutter binding — `permission_handler.PermissionStatus`, `device_info_plus` types); rows 06-04-04 / 06-04-05 / 06-04-06 use `dart test` (pure-Dart file scan / regex parsing).

---

## Wave 0 Requirements

Phase 06 has no scaffolded test stubs because the 5 adversarial unit tests + 1 tool unit test must be **hand-authored at audit time** with concrete assertions tied to the actual files on disk. Phase 06 ships them in Plan 06-04 (Wave 3), not as Wave 0 stubs. The artifact targets (REVIEW.md sections) are likewise authored progressively across Plans 06-01..06-05.

- [ ] `.planning/phases/06-review-gate-gps/06-REVIEW.md` — created with 5-section skeleton in Plan 06-01
- [ ] `test/infrastructure/platform/method_channel_sync_test.dart` — created in Plan 06-04 (Test #1)
- [ ] `test/application/permissions/location_permission_cascade_test.dart` — created in Plan 06-04 (Test #2)
- [ ] `test/infrastructure/platform/oem_detector_ambiguous_test.dart` — created in Plan 06-04 (Test #3)
- [ ] `test/tooling/platform_manifests_test.dart` — created in Plan 06-04 (Test #4)
- [ ] `test/infrastructure/platform/android_boot_receiver_contract_test.dart` — created in Plan 06-04 (Test #5)
- [ ] `tool/test/check_platform_manifests_test.dart` — created in Plan 06-04 (paired tool test, runs under existing `Tool scripts unit tests` CI step)
- [ ] `tool/check_platform_manifests.dart` — created in Plan 06-04 (new CI gate script)
- [ ] `.github/workflows/ci.yml` — amended in Plan 06-04 (new gate step + adversarial trigger expansion on the throwaway branch only)

*Framework already installed (Dart `test` 1.25.x + `flutter_test`); no install command needed.*

---

## Manual-Only Verifications

| Behavior | Maps To | Why Manual | Test Instructions |
|----------|---------|------------|-------------------|
| User IDE findings posted into §1 BEFORE Claude spawns agents | SC#3 (review protocol applied — strict user-first ordering) | The protocol is a procedural invariant on the human side; no automated check can prove the user looked at the IDE before agents ran. | Plan 06-01 commits `06-REVIEW.md` §1 with verbatim user findings (or the explicit marker `Aucune observation utilisateur` per Phase 04 precedent) BEFORE Plan 06-03 spawns the 4-agent wave. Reviewer reads the commit timestamp ordering. |
| §3 user-driven triage of Should/Could findings | SC#3 (review protocol applied) | Severity reclassification is a human judgment call that synthesizes user IDE context + agent findings + project priorities. | Plan 06-05 commits §3 with each Should-or-above row marked `✓ fixed in <hash>` or `⚠ waived: <rationale>`. Reviewer confirms no row is left ambiguous. |
| POC evidence acceptance (PASS-with-caveat iOS 13.5 min vs SC#2 30 min target) | SC#1 + SC#2 | Acceptance is a user decision recorded in CONTEXT.md (2026-04-20) — automated tests cannot validate "the user agrees this is good enough". | Plan 06-02 commits §1b with the inline rationale verbatim from CONTEXT.md `<decisions>` POC evidence acceptance subsection. Reviewer cross-checks rationale text matches CONTEXT.md. |
| Batched-vs-atomic fix-loop strategy decision | gate-closed | User approves at Plan 06-05 fix-time per Phase 04 precedent. No prior automation can decide this. | Plan 06-05 prompts the user; STATE.md `Accumulated Decisions` records the chosen strategy with rationale. |
| Cleanup of `adversarial/06-manifest-drift` branch (local + remote) | gate-closed (hygiene) | Branch deletion is destructive; user confirms after evidence archival. | Plan 06-04 ends with `git branch -D adversarial/06-manifest-drift` + `git push origin --delete adversarial/06-manifest-drift` only after §4 commit lands on main. Reviewer confirms `git branch -a` shows no `adversarial/06-*` ref. |

---

## Validation Sign-Off

- [ ] All Plan 06-04 tasks have `<automated>` verify (`dart test <path>` or `flutter test <path>`) — gate-closed unit-test conditions covered
- [ ] All Plan 06-01..03 tasks have artifact-presence verify (`grep` over `06-REVIEW.md`) — review-protocol conditions covered
- [ ] All Plan 06-05 tasks have artifact-amendment OR CI-run verify (`gh run` for CI green, `grep` for ROADMAP amendment) — gate-closure conditions covered
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (full suite required between plan waves)
- [ ] Wave 0 entries above each map to a Plan 06-04 task that creates the file
- [ ] No watch-mode flags (this is review-gate work, not iterative dev)
- [ ] Feedback latency < 25s local quick / ~6 min CI gates job — acceptable for review-gate cadence
- [ ] Manual-only verifications above each have a procedural commit/ordering invariant that a future reader can audit
- [ ] `nyquist_compliant: true` set in frontmatter — *will be set when Plan 06-04 + 06-05 complete and verifier confirms every row in the Per-Task Verification Map shows ✅*

**Approval:** pending
