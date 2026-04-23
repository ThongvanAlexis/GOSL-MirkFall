---
phase: 08
slug: review-gate-map
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `08-RESEARCH.md §Validation Architecture` (lines 992-1142).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter SDK test (3.41.5) + `integration_test` (SDK bundled) + `dart test` (package:test 1.30.0) |
| **Config file** | `dart_test.yaml` (2 tags declared: `migration` 2x timeout + `soak` 10x timeout ; Plan 08-04 may add `integration` tag or rely on inline `@Tags(['integration'])`) |
| **Quick run command** | `flutter test --exclude-tags=soak,integration` |
| **Full suite command** | `flutter test && dart test --tags soak test/infrastructure/downloads/download_soak_test.dart && flutter test integration_test/` |
| **Estimated runtime** | ~90s quick / ~6-8 min full (including soak) |

---

## Sampling Rate

- **After every task commit:** `flutter test --exclude-tags=soak,integration` (quick suite)
- **After every plan wave:** `flutter test && dart run tool/check_style_no_external_url.dart && dart run tool/check_avoid_maplibre_leak.dart && dart run tool/check_avoid_remote_pmtiles.dart`
- **After Plan 08-04 push:** Full suite + integration + soak (8 scenarios = 6 existing + 2 new)
- **Before `/gsd:verify-work` (Plan 08-05 closure):** Full suite green on final commit + CI `gates` + `android` + `ios` (+ `integration-tests` if split) all green + adversarial branch deleted local+remote + ROADMAP/REQUIREMENTS amended
- **Max feedback latency:** ~90s quick commit cycle ; CI green confirmation within ~12 min

---

## Per-Task Verification Map

Phase 08 has no `requirements:` field (`phase_req_ids = —`). The verification map is expressed against Phase 07 requirements being audited + Phase 08 meta-guards.

| Req / Target | Plan | Behavior | Test Type | Automated Command | File Status |
|--------------|------|----------|-----------|-------------------|-------------|
| MAP-01 (audited) | 08-04 | Airplane mode zero tile HTTP | integration | `flutter test integration_test/airplane_mode_test.dart` | ⚠️ MOVE from `test/phase_07_integration/` |
| MAP-05/06 (audited) | 08-03 | PmtilesSource local-only + seam purity lints | unit+CI | `flutter test test/infrastructure/map/pmtiles_source_test.dart && dart run tool/check_avoid_remote_pmtiles.dart && dart run tool/check_avoid_maplibre_leak.dart` | ✅ Existing (Plan 07-01/02/03) |
| MAP-07 (audited) | 08-04 | First-launch world copy + auto-heal | integration | `flutter test integration_test/first_launch_world_copy_test.dart` | ⚠️ MOVE |
| MAP-07 guard (new) | 08-04 | World bundle sha256 drift detection | unit | `flutter test test/infrastructure/assets/world_bundle_sha256_test.dart` | ❌ Wave 0 NEW |
| MAP-08/09/10 (audited) | 08-04 | Full user journey (download + display + delete) | integration | `flutter test integration_test/map_end_to_end_test.dart` | ⚠️ MOVE |
| MAP-09 soak (audited) | 08-04 | 7-step atomic protocol — 6 existing + 2 new edges | soak | `dart test --tags soak test/infrastructure/downloads/download_soak_test.dart` | ✅ 6 existing / ❌ 2 new edges Wave 0 |
| MAP-09 guard (new) | 08-04 | Manifest atomicity contract (FS fake injection) | unit | `flutter test test/infrastructure/downloads/manifest_atomicity_contract_test.dart` | ❌ Wave 0 NEW |
| Phase 07 routing | 08-04 | 5 new routes + back-nav + deep-links | integration | `flutter test integration_test/phase_07_navigation_test.dart` | ❌ Wave 0 NEW |
| Phase 08 meta | 08-04 | No `HttpClient()` in unit tests (scan) | unit | `flutter test test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` | ❌ Wave 0 NEW |
| Phase 08 meta | 08-04 | `assets/maps/style.json` has zero external URL | CI | `dart run tool/check_style_no_external_url.dart` | ❌ Wave 0 NEW |
| Phase 08 adversarial | 08-04 | Gate catches poisoned style.json | adversarial CI | `git push origin adversarial/08-style-external-url` → CI exit 1 | ❌ Wave 0 NEW |
| SC#4 (protocol) | 08-01/08-03 | User-first protocol applied (§1 captured before spawn) | structural | `git log --oneline -- 08-REVIEW.md` shows §1 commit before Plan 08-03 | Structural gate (not a test file) |
| SC#5 (closure) | 08-05 | All Blocker fixed + Should fixed-or-waived + CI green | aggregate | CI all 3 jobs green on final main commit | Gate-closed checklist |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Files/artefacts that MUST exist before Plan 08-04 (adversarial wave) can execute:

**Integration tests (MOVE + 1 new):**
- [ ] `integration_test/airplane_mode_test.dart` — `git mv` from `test/phase_07_integration/` + add inertness guards
- [ ] `integration_test/first_launch_world_copy_test.dart` — `git mv` + inertness guards
- [ ] `integration_test/map_end_to_end_test.dart` — `git mv` + inertness guards
- [ ] `integration_test/phase_07_navigation_test.dart` — **NEW** (absent du disque)

**Permanent unit tests (3 new, inertness-guarded):**
- [ ] `test/infrastructure/assets/world_bundle_sha256_test.dart` — directory `test/infrastructure/assets/` doesn't exist → create
- [ ] `test/infrastructure/downloads/manifest_atomicity_contract_test.dart` — directory exists
- [ ] `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` — directory `test/infrastructure/network/` doesn't exist → create

**CI gate + paired test (1 new):**
- [ ] `tool/check_style_no_external_url.dart` (~80 LoC, adaptation de `check_avoid_remote_pmtiles.dart`)
- [ ] `tool/test/check_style_no_external_url_test.dart` (7 scenarios : 6 fixtures + production style.json)
- [ ] `.github/workflows/ci.yml` step amendment (after `Check avoid_remote_pmtiles`)

**Adversarial branch (1):**
- [ ] `adversarial/08-style-external-url` — poison style.json + inline `on.push.branches` expansion → push → archive CI run URL + stderr → delete local+remote

**Soak edge cases (2, append to existing file):**
- [ ] `test/infrastructure/downloads/download_soak_test.dart` — add (a) corrupt chunk mid-stream + (b) rename target already exists

**Documentation (4 files, mostly Plan 08-01):**
- [ ] `.planning/phases/08-review-gate-map/08-REVIEW.md` — 5-section skeleton
- [ ] `.planning/phases/07-map-integration/07-07-SUMMARY.md` — scope-reduction rationale
- [ ] `.planning/phases/07-map-integration/07-07-integration-verification-PLAN.md` — header annotation (edit existing)
- [ ] `.planning/ROADMAP.md` + `.planning/REQUIREMENTS.md` — amendments (Phase 07 → Complete)

---

## Manual-Only Verifications

| Behavior | Audited Req | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| §1 User IDE findings captured verbatim | SC#4 | User input is the actual source of truth ; no automation can substitute | Plan 08-01 Task 2: copy user's chat message into §1 ; commit ; gate-check no further agent spawn until §1 non-empty |
| §1b POC evidence review (no fresh walk) | Phase 08 meta | Artifacts already exist (`docs/phase-07-smoke.md` + `docs/phase-07-ios-animate-camera-crash.md` + 7 screenshots) ; fresh smoke rejected by CONTEXT | Plan 08-02: Agent #4 extracts evidence into §1b `<details>` blocks per-device |
| User triage decisions §3 | SC#4 | Fix/waive/defer per-finding is user choice, not automatable | Plan 08-03 Task 5: present triage table to user ; capture decisions inline §3 |
| Adversarial branch archive + cleanup | SC#2 | Screenshot of CI run page + git branch deletion = human observation + action | Plan 08-04 Task 7: archive run URL + stderr into §4 ; `git push origin :adversarial/08-style-external-url` |

---

## Inertness Guard Pattern (Canonical Reference)

**Source:** `test/infrastructure/db/migration_v1_to_v2_data_loss_test.dart:95-106` (Phase 04 canonical, Phase 06 multiplied).

All 7 new tests (4 integration + 3 permanent unit) + 2 new soak edges MUST follow this pattern:

```dart
// Inertness guard: prove the adversary / setup actually ran.
// Without this, refactors silently neutralize the test.
expect(
  <pre-condition that only holds if the setup ran>,
  isTrue,
  reason: '<explanation why the test would be inert without this>',
);

// THEN the main assertion
expect(<actual behavior being guarded>, <expectation>);
```

**Mutation experiment at author-time (documented in §4 Test block):**
1. Write test + guard + main
2. Break the inertness precondition
3. Test MUST fail LOUDLY with `reason` message (NOT silently pass)
4. Restore — green
5. Document "Mutation experiment (author-time):" in §4 Test #N block

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies listed
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (9 files + 1 CI amendment + 1 branch + 4 docs)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s (quick) / < 12 min (CI full)
- [ ] SC#1-5 each map to at least 1 automated evidence + 1 inertness guard (per §Validation Architecture : Success Criteria → Evidence Mapping table in RESEARCH.md)
- [ ] `nyquist_compliant: true` set in frontmatter once Plan 08-04 verifies Wave 0 complete

**Approval:** pending
