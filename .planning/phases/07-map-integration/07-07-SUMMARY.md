# Plan 07-07 Summary — Integration Verification (scope reduced)

**Date:** 2026-04-23
**Status:** scope reduced — partial delivery + absorption
**Phase 08 cross-reference:** Plan 08-04 (adversarial wave) implements the deferred integration tests.

## What landed under Plan 07-07 (original scope)

- **Physical device smoke walks** — Android Pixel 4a PASS 2026-04-21 + iOS iPhone 17 Pro PASS-with-caveat 2026-04-21 (docs/phase-07-smoke.md)
- **iOS animateCamera crash fix** — investigated, bisected, and resolved 2026-04-22 via commits `81d30c7` + `ab497ab` + `40b49d5` (docs/phase-07-ios-animate-camera-crash.md)

## What was absorbed into Phase 08 Plan 08-04 (adversarial wave)

The four integration tests originally scoped in 07-07-integration-verification-PLAN.md are no longer written in Phase 07. They are delivered in Phase 08 Plan 08-04 as permanent regression guards with inertness guards (Phase 04 + 06 precedent pattern), all under `integration_test/` (new directory, Flutter convention), tagged `@Tags(['integration'])` for on-demand CI job split.

Three of them already exist on disk at `test/phase_07_integration/` and will be `git mv`-ed by Plan 08-04 Task 1 (preserves file history); the fourth is brand new.

| File (final location) | Source | Covers |
|----------------------|--------|--------|
| `integration_test/airplane_mode_test.dart` | MOVE from `test/phase_07_integration/airplane_mode_test.dart` | MAP-01 + QUAL-05 subset (airplane mode zero tile HTTP) |
| `integration_test/first_launch_world_copy_test.dart` | MOVE from `test/phase_07_integration/first_launch_world_copy_test.dart` | MAP-07 (first-launch world copy + sha256 auto-heal, scenarios A/B/C) |
| `integration_test/map_end_to_end_test.dart` | MOVE from `test/phase_07_integration/map_end_to_end_test.dart` | MAP-08/09/10 (full user journey: download + display + delete + world fallback) |
| `integration_test/phase_07_navigation_test.dart` | NEW — Plan 08-04 Task 2 | Router 5 new routes + back-navigation + deep-links |

Plan 08-04 also adds 3 new permanent unit tests (world_bundle_sha256 / manifest_atomicity_contract / no_httpclient_in_unit_tests), 1 new CI gate (`tool/check_style_no_external_url.dart`), 1 adversarial branch (`adversarial/08-style-external-url`), and 2 new soak edge cases.

## Rationale for scope reduction

Per 08-CONTEXT.md §Plan 07-07 absorption (user-locked at CONTEXT time):
1. The 4 integration tests are classic review-gate adversarial artefacts (regression guards against map regressions) — they belong in a review gate, not in code-shipping Phase 07.
2. Writing them in Phase 07 would bias the Phase 08 audit (the auditor would inherit the tests it should be auditing).
3. The `integration_test/` directory did not exist in Phase 07 ; creating it as part of review-gate adversarial wave is architecturally cleaner.
4. Plan 07-07 scope reduces to the part that genuinely could not wait : the physical smoke + iOS fix (both done 2026-04-21/22).

## Related amendments (same commit batch as this SUMMARY)

- `.planning/ROADMAP.md` — Phase 07 progress row flipped to `7/7 Complete` ; Plan 07-07 line annotated `scope reduced (smoke + iOS fix only), integration tests absorbed into Phase 08 Plan 08-04`
- `.planning/REQUIREMENTS.md` — MAP-05 / MAP-06 / MAP-07 / MAP-08 / MAP-10 Traceability rows flipped from `In Progress` to `Complete`
- `.planning/phases/07-map-integration/07-07-integration-verification-PLAN.md` — header annotation explaining the scope reduction ; body kept verbatim below for git-trace preservation

## Files touched by the original Plan 07-07 (kept)

- `docs/phase-07-smoke.md` (created Plan 07-07)
- `docs/phase-07-ios-animate-camera-crash.md` (created 2026-04-22 during fix)
- `docs/phase-07-smoke-screenshots/` (7 PNGs, committed Plan 07-07)
- commits `81d30c7` / `ab497ab` / `40b49d5` (iOS animateCamera fix on `lib/application/controllers/map_camera_controller.dart` + related test files)

---
*Written: 2026-04-23 by Plan 08-01 Task 3 as part of Phase 07 structural closure.*
