# Phase 09 — Deferred Items

## Out-of-scope discoveries (logged, NOT fixed by 09-01b)

### `test/infrastructure/mirk/*_test.dart` — `skip:` parameter type mismatch

**Discovered during:** plan 09-01b execution (Task 3 verification — `flutter analyze --fatal-warnings --fatal-infos`)

**Files:**
- `test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart`
- `test/infrastructure/mirk/candlelight_mirk_renderer_test.dart`
- `test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart`
- (also potentially `test/infrastructure/mirk/noise/simplex_noise_2d_test.dart`)

**Issue:** `testWidgets(..., skip: 'Wave 3 — plan 09-04')` fails analysis because the `flutter_test` `testWidgets` function expects `bool?` for the `skip` parameter, not `String?`. The correct API is `testWidgets(..., skip: true)` (with the reason in a comment) or `test(..., skip: 'reason string')` — `test` accepts a String/bool union, `testWidgets` only `bool?`.

**Why deferred:** these test files are untracked working-tree artifacts produced by the parallel-running plan 09-01c (Wave 1 runs 09-01, 09-01b, 09-01c concurrently). They are not part of plan 09-01b's `<files_modified>` declaration and were not created by 09-01b. Plan 09-01b's scope explicitly says it consumes NOTHING from 09-01c (and vice-versa). Fixing these tests in 09-01b would breach scope and step on 09-01c's commit.

**Owner:** plan 09-01c (or whichever plan ultimately commits these test scaffolds).

**Validation:** `flutter analyze lib/` (lib-only) is green, confirming 09-01b's lib scaffolds compile cleanly. The errors live entirely under `test/infrastructure/mirk/`.

---

### Plan 09-01 close (2026-04-25) — same issue still surfaces, scope unchanged

**Status at Plan 09-01 verification:** `flutter analyze --fatal-warnings --fatal-infos` returns 6 errors in
`test/infrastructure/mirk/{solid_fill,heavenly_clouds,candlelight,atmospheric}_mirk_renderer_test.dart`
(the same `argument_type_not_assignable` `skip:` parameter symptom logged above).

**Why still deferred:** Plan 09-01's `<files_modified>` is strictly
`lib/config/constants.dart`, `dart_test.yaml`,
`lib/infrastructure/map/style_layer_order.dart`,
`test/constants_test.dart`. None of the failing files are in scope. Per
GSD SCOPE BOUNDARY rule, only auto-fix issues directly caused by the
current task — these errors pre-existed on the prior commits (`68cfd54`
`4d19408`) and are independent of Plan 09-01's diff.

**Plan 09-01-only verification (in scope):** `flutter analyze` on the 3
modified Dart files returns *No issues found! (ran in 1.1s)*. All Plan
09-01 acceptance criteria (constants in place, mirk-perf tag registered,
docstring updated, regression test green) are met.

**Owner suggestion:** Plan 09-02 (`AtmosphericMirkRenderer` impl) — natural
integration point to align test signatures with the real renderer API.
