---
phase: 08-review-gate-map
plan: 04
subsystem: testing
tags: [integration-tests, soak-tests, adversarial-ci, ci-gate, inertness-guard, mutation-experiment, go_router, style-json]

# Dependency graph
requires:
  - phase: 08-review-gate-map
    provides: "§3 triage blanket decision (.fixes-expected=49) + §2 synthesis + §1b POC evidence — Plan 08-03 prerequisite"
  - phase: 07-map-integration
    provides: "3 integration tests under test/phase_07_integration/ + 6 soak scenarios + JsonFileInstalledManifestRepository + PmtilesDownloadController + world.pmtiles + style.json + kWorldBundleSha256"
provides:
  - "integration_test/ top-level directory — 4 integration tests (3 moved + 1 new) — @Tags(['integration'])"
  - "3 permanent unit tests — world-bundle-sha256 + manifest-atomicity-contract + no-httpclient-scan"
  - "tool/check_style_no_external_url.dart CI gate + paired 8-scenario test"
  - "2 new soak scenarios appended to download_soak_test.dart (total 8)"
  - "§4 Adversarial evidence — 10 evidence blocks populated with commit hashes + CI run URL + stderr + mutation experiments"
  - "Throwaway-branch adversarial CI evidence proving the new gate catches external-URL injection in style.json (CI red at step Tool-scripts-unit-tests OR Check-style-no-external-URL)"
affects: [08-05-fix-loop, 09-fog-rendering, 10-review-gate-fog]

# Tech tracking
tech-stack:
  added: []  # No new packages — uses existing crypto + test + flutter_test + go_router + integration_test
  patterns:
    - "integration_test/ directory at repo root (Flutter convention)"
    - "@Tags(['integration']) opt-out discipline for CI unit fast-path"
    - "Inertness guard canonical pattern replicated 7 times (Phase 04 Test #3 + Phase 06 Tests #1-5 idiom)"
    - "Mutation experiment (author-time) documented inline per test (break precondition → verify LOUD failure → restore → green)"
    - "CI gate script + paired tool/test/ unit test + exit 0/1/2 contract (replicated from check_avoid_remote_pmtiles)"
    - "Throwaway adversarial branch + inline on.push.branches expansion (this-branch-only) + deletion post-archive"

key-files:
  created:
    - "integration_test/phase_07_navigation_test.dart"
    - "test/infrastructure/assets/world_bundle_sha256_test.dart"
    - "test/infrastructure/downloads/manifest_atomicity_contract_test.dart"
    - "test/infrastructure/network/no_httpclient_in_unit_tests_test.dart"
    - "tool/check_style_no_external_url.dart"
    - "tool/test/check_style_no_external_url_test.dart"
    - ".planning/phases/08-review-gate-map/08-04-SUMMARY.md"
  modified:
    - "integration_test/airplane_mode_test.dart (MOVED from test/phase_07_integration/ via git mv)"
    - "integration_test/first_launch_world_copy_test.dart (MOVED)"
    - "integration_test/map_end_to_end_test.dart (MOVED)"
    - "test/infrastructure/downloads/download_soak_test.dart (+2 soak scenarios)"
    - ".github/workflows/ci.yml (+Check style no external URL step)"
    - "dart_test.yaml (+integration tag registration)"
    - ".planning/phases/08-review-gate-map/08-REVIEW.md (§4 populated with 10 evidence blocks)"

key-decisions:
  - "router.go instead of router.push for phase_07_navigation_test — go_router's push routes through RouteInformationProvider + platform channels that do not deterministically flush under integration_test binding. The production router discipline `context.canPop() ? pop : go('/')` is still verified via `canPop` + `go` primitives."
  - "Test #6 manifest_atomicity exercises real tempdir I/O instead of an FS-injection seam — CLAUDE.md §Wrappers forbids pure-delegation wrappers, so the repo deliberately has no mock FS interface. The test captures atomicity via canonical-path snapshots + stale .tmp sibling simulation + concurrent-write mutex verification."
  - "Soak scenario 9 staging assertion aligned with `pmtiles_download_controller.dart:378` reality: 'Keep staging intact for a future resume'. Plan spec said 'staging cleaned' but the controller preserves staging for retry — spirit of plan (atomic install or absent at canonical level) preserved; reassembled file in staging may exist with mismatched bytes but rename never runs, so canonical countries/ target stays absent."
  - "Adversarial CI triggered failure at step #12 `Tool scripts unit tests` before step #17 `Check style no external URL` — because the paired test's scenario 1 runs against the real production style.json and expected exit 0, got exit 1. Stronger evidence: same gate logic caught the drift twice in one run (scanner direct + paired-test scenario 1)."

patterns-established:
  - "Inertness guard: per-test precondition assertion with 'test inert' reason, positioned BEFORE the main assertion. Refactor that silently neutralises setup fails loudly on precondition before the main assert can succeed on a false negative."
  - "Mutation experiment documentation: 3-step inline comment block at file header (intent → observed failure → restore). Ensures future maintainers know the test is not a placebo."
  - "CI gate exit 0/1/2 contract replication: `runCheck({stylePath})` library function + paired tool/test/ test using `Process.run` OR direct library invocation. Matches Phase 06 `check_platform_manifests` + Phase 07 `check_avoid_remote_pmtiles` precedents."
  - "Adversarial branch lifecycle: create → poison commit → inline on.push.branches expansion (this-branch-only) → push → observe CI red → archive stderr + run URL + commit SHAs → delete local + remote → verify main ci.yml trigger unchanged."

requirements-completed: []  # Plan 08-04 frontmatter has `requirements: []` — review-gate plans do not own REQ-IDs

# Metrics
duration: ~2h 45m  # including CI wait times
completed: 2026-04-23
---

# Phase 08 Plan 04: Adversarial Wave Summary

**7 inertness-guarded tests (4 integration + 3 permanent unit) + 1 CI gate + paired test + throwaway adversarial branch proving external-URL injection in style.json is caught at policy layer + 2 soak edge cases extending the 6-baseline to 8 total — all 10 §4 evidence blocks populated with real commit hashes + mutation experiments.**

## Performance

- **Duration:** ~2h 45m (spans 3 full CI wait cycles)
- **Started:** 2026-04-23T17:50Z
- **Completed:** 2026-04-23T19:48Z
- **Tasks:** 9 executed
- **Files created:** 7
- **Files modified:** 7
- **Commits on main:** 8 atomic + 2 throwaway-branch-only (deleted post-archive)

## Accomplishments

- 4 integration tests live under `integration_test/` (Flutter convention) with `@Tags(['integration'])` — 3 moved via `git mv` (history preserved) + 1 brand-new navigation test covering all 5 Phase 07 routes + back-nav + deep-links
- 3 permanent unit tests permanently guard against silent drift:
  - `world_bundle_sha256_test.dart` catches `world.pmtiles` drift from `kWorldBundleSha256` constant (loops auto-heal if missed)
  - `manifest_atomicity_contract_test.dart` catches `JsonFileInstalledManifestRepository.write` atomicity regressions
  - `no_httpclient_in_unit_tests_test.dart` catches unit tests silently acquiring real network (complements airplane_mode_test runtime isolation)
- `tool/check_style_no_external_url.dart` + paired 8-scenario test + wired into `.github/workflows/ci.yml` `gates` job — blocks external http[s]:// URLs in style.json at CI time
- Adversarial branch `adversarial/08-style-external-url` proved the gate works on real CI (run 24855188920, exit 1 with actionable stderr), deleted clean from local + remote, main trigger unchanged
- 2 new soak scenarios extend the 6-baseline to 8 total, verified via `flutter test --tags soak` locally
- §4 Adversarial evidence block fully populated with commit hashes + mutation-experiment docs per test

## Task Commits

Each task was committed atomically on `main`:

1. **Task 1: Move 3 integration tests + inertness guards** — `46c84e0` (test)
2. **Task 2: NEW integration_test/phase_07_navigation_test.dart** — `8103312` (test)
3. **Task 3: 3 permanent unit tests** — `b28e25d` (test)
4. **Task 4: tool/check_style_no_external_url.dart CI gate** — `b1fdcf0` (feat)
5. **Task 5: paired tool unit test** — `a9345f7` (test)
6. **Task 6: .github/workflows/ci.yml amendment** — `43868f6` (ci)
7. **Task 7: adversarial branch** — 2 commits on throwaway branch (deleted): poison `5a4610d` + CI-expansion `06b19e5` — archived in §4 Test 8
8. **Task 8: 2 soak edges + dart format normalization** — `33f8692` (test)
9. **Task 9: §4 populated with 10 evidence blocks** — `54f0a4e` (docs)

**Plan metadata:** `54f0a4e` (same as Task 9 — docs commit combines §4 population)

## Files Created/Modified

- `integration_test/airplane_mode_test.dart` — MOVED + inertness guard (FakeMapView.showMapInvocations.isNotEmpty)
- `integration_test/first_launch_world_copy_test.dart` — MOVED + inertness guards labelled (tempdir-clean + byte-flip-actually-corrupts)
- `integration_test/map_end_to_end_test.dart` — MOVED + 4 inertness guards at journey steps
- `integration_test/phase_07_navigation_test.dart` — NEW: 5 forward + 1 back-nav + 2 deep-link scenarios, `router.go` discipline documented inline
- `test/infrastructure/assets/world_bundle_sha256_test.dart` — NEW: streamed sha256 vs constant
- `test/infrastructure/downloads/manifest_atomicity_contract_test.dart` — NEW: 4 scenarios real-I/O atomicity
- `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` — NEW: meta-scan of test/ for forbidden network APIs
- `test/infrastructure/downloads/download_soak_test.dart` — +2 scenarios (corrupt chunk / rename target exists)
- `tool/check_style_no_external_url.dart` — NEW: walks style.json URL fields, exit 0/1/2 contract
- `tool/test/check_style_no_external_url_test.dart` — NEW: 8 scenarios paired test
- `.github/workflows/ci.yml` — +`Check style no external URL` step after `Check avoid_remote_pmtiles`
- `dart_test.yaml` — +`integration` tag registration (silences dart_test runner warning)
- `.planning/phases/08-review-gate-map/08-REVIEW.md` — §4 populated with 10 evidence blocks

## Decisions Made

- **`router.go` > `router.push` in navigation test** (documented inline): go_router's async `push` routes through RouteInformationProvider + platform channels that do not deterministically flush under the integration_test binding. The production discipline `context.canPop() ? pop : go('/')` is still verified via `canPop` + `go` primitives.
- **Real-I/O manifest atomicity test, no FS-injection seam**: CLAUDE.md §Wrappers forbids pure-delegation wrappers. The repo has no mock FS because wrapping `dart:io.File` would add zero logic. The test captures atomicity via tempdir snapshots + stale `.tmp` simulation + concurrent-write mutex verification.
- **Soak scenario 9 staging assertion aligned with controller reality**: plan spec said "staging cleaned" but `pmtiles_download_controller.dart:378` preserves staging for future resume. The test was adapted to match the actual invariant ("Keep staging intact"); the spirit of the plan — "atomic install or absent at canonical level" — is preserved via the `countries/afg.pmtiles` absent assertion.
- **Scenario 1 of paired test invokes the REAL asset path**: the adversarial branch caught the drift at step #12 `Tool scripts unit tests` (scenario 1 expected exit 0, got 1) BEFORE step #17 `Check style no external URL` could run. This is stronger evidence — the same gate logic caught the drift twice in one run (scanner direct + paired-test scenario 1).
- **`test/infrastructure/downloads/` + `test/infrastructure/assets/` + `test/infrastructure/network/` left out of the CI `Plain-Dart domain + infra tests` step allowlist**: all 3 run under `flutter test` (default CI step), so defensive coverage via `dart test` is not required. Matches the existing pattern for `test/infrastructure/downloads/` (soak).

## Deviations from Plan

### Spec-vs-reality alignment (Task 8 scenario 9)

**1. [Rule 1 — Alignment with design] Soak scenario 9 staging assertion**
- **Found during:** Task 8 (soak edge case implementation)
- **Issue:** Plan specified "staging cleaned" on sha256-mismatch failure, but `pmtiles_download_controller.dart:378` preserves staging for retry ("Keep staging intact for a future resume"). Test would assert against reality.
- **Fix:** Adapted the assertion to `expect(staging.existsSync(), isTrue, reason: 'staging/afg was removed — retry path broken')` + retained the canonical-path-target-absent assertion (the spirit of the plan). Documented the alignment in the test's comment block + this summary.
- **Files modified:** `test/infrastructure/downloads/download_soak_test.dart`
- **Verification:** `flutter test --tags soak test/infrastructure/downloads/download_soak_test.dart` → 8/8 pass
- **Committed in:** `33f8692`

### CI normalization (Task 8)

**2. [Rule 3 — Blocking] CI dart format drift caught on push**
- **Found during:** Task 6 push (Task 8 commit bundle)
- **Issue:** First post-Tasks-1-5 push to main failed `Dart format check` step. `dart format --line-length 160 .` identified 6 prior-task files with formatting drift (Dart formatter auto-reformatted new-line-heavy constructs into 160-char-fitting calls).
- **Fix:** Ran `dart format --line-length 160 .` locally, reviewed the 6 auto-changes (collapsed multi-line `RegExp([])` + `Directory([])` lists into single-line when fit), bundled the normalization into the Task 8 commit.
- **Files modified:** `integration_test/map_end_to_end_test.dart`, `integration_test/phase_07_navigation_test.dart`, `test/infrastructure/assets/world_bundle_sha256_test.dart`, `test/infrastructure/downloads/download_soak_test.dart`, `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart`, `tool/test/check_style_no_external_url_test.dart`
- **Verification:** Next push (commit `33f8692`) had green Dart format check step
- **Committed in:** `33f8692`

**Total deviations:** 2 (both in scope, both essential for correctness — 1 design alignment, 1 blocking CI fix)
**Impact on plan:** Zero scope creep. Both deviations surfaced tighter alignment with the codebase reality.

## Issues Encountered

- **go_router `push` does not flush synchronously under integration_test binding** — verified via 3 iterations of the navigation test. `router.push('/route')` returns a Future that resolves only when the pushed route is popped, so awaiting it hangs. `unawaited(router.push(...))` + `pumpAndSettle` did not propagate the navigation event in time either. Switched to `router.go(...)` for the forward tests + documented the tradeoff in the test header.
- **Dart format `--line-length 160` drift** on the first push — fixed in one commit (Task 8 bundle).
- **Adversarial CI failed at `Tool scripts unit tests` step (#12) instead of `Check style no external URL` step (#17)** — caused by the paired test's scenario 1 running against the real production style.json (now poisoned). This is stronger evidence — same gate logic fired twice in one run. Documented inline in §4 Test 8 evidence block.

## User Setup Required

None — no external service configuration introduced.

## Next Phase Readiness

- **Plan 08-05 (fix loop) unblocked** — all adversarial prerequisites in place:
  - 7 permanent regression guards operational
  - 1 new CI gate live on main (`Check style no external URL`)
  - §4 fully populated with 10 evidence blocks
  - `.fixes-expected=49` snapshot untouched (Plan 08-03 triage output preserved)
  - Main CI green on commit `54f0a4e` (verified at [run 24855442109](https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24855442109))
- **Plan 08-05 handoff inputs:**
  - `08-REVIEW.md §3` triage table: 40 fix + 9 refactor + 0 waived + 10 defer-to-v2 + 16 accepted-as-is = 75 findings
  - `.fixes-expected` = 49 (40 fix + 9 refactor)
  - Adversarial wave evidence complete, no re-runs needed
- **Phase 09 Fog Rendering** will consume:
  - `MapView` interface purity (verified by Agent #1 in Plan 08-03 + `check_avoid_maplibre_leak` CI gate)
  - `style.json` offline-only contract (verified by new `check_style_no_external_url` CI gate)
  - Layer ordering contract (`mirk_fog` layer already positioned at stack index 7 in Phase 07 `style.json`)

## Self-Check: PASSED

Verified 2026-04-23 post-commit `54f0a4e`:

- **14 files present** (8 claimed-created + 6 claimed-modified — all `FOUND` via `test -f`):
  - `integration_test/airplane_mode_test.dart` (moved)
  - `integration_test/first_launch_world_copy_test.dart` (moved)
  - `integration_test/map_end_to_end_test.dart` (moved)
  - `integration_test/phase_07_navigation_test.dart` (new)
  - `test/infrastructure/assets/world_bundle_sha256_test.dart` (new)
  - `test/infrastructure/downloads/manifest_atomicity_contract_test.dart` (new)
  - `test/infrastructure/network/no_httpclient_in_unit_tests_test.dart` (new)
  - `test/infrastructure/downloads/download_soak_test.dart` (modified)
  - `tool/check_style_no_external_url.dart` (new)
  - `tool/test/check_style_no_external_url_test.dart` (new)
  - `.github/workflows/ci.yml` (modified)
  - `dart_test.yaml` (modified — integration tag added)
  - `.planning/phases/08-review-gate-map/08-REVIEW.md` (modified — §4 populated)
  - `.planning/phases/08-review-gate-map/08-04-SUMMARY.md` (this file)

- **8 main-branch commits present** (all `FOUND` via `git log --oneline --all | grep`):
  - `46c84e0` — Task 1 (move 3 integration tests)
  - `8103312` — Task 2 (navigation test)
  - `b28e25d` — Task 3 (3 permanent unit tests)
  - `b1fdcf0` — Task 4 (check_style_no_external_url.dart)
  - `a9345f7` — Task 5 (paired test)
  - `43868f6` — Task 6 (ci.yml gate wiring)
  - `33f8692` — Task 8 (soak edges + format normalization)
  - `54f0a4e` — Task 9 (§4 evidence population)

- **Adversarial branch SHAs** (Task 7, throwaway branch deleted post-archive, preserved in §4 Test 8):
  - `5a4610d` poison — only reachable via `git fsck` orphan-object inspection, documented in §4
  - `06b19e5` CI-expansion — same

- **.fixes-expected** still `49` (Plan 08-03 triage snapshot untouched — `cat .planning/phases/08-review-gate-map/.fixes-expected` → `49`)

- **Main CI green** post-final-commit: https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24855442109 (3/3 jobs success)

---
*Phase: 08-review-gate-map*
*Plan: 04 (Adversarial Wave)*
*Completed: 2026-04-23*
