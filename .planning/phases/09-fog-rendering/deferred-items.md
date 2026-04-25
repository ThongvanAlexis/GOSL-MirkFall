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

---

### Plan 09-05 close (2026-04-25) — `atomic_renamer_test.dart::overwrites an existing target file` flaky under full-suite parallel execution

**Status at Plan 09-05 verification:** `flutter test` (full suite) shows 1 failure in
`test/infrastructure/downloads/atomic_renamer_test.dart::AtomicRenamer — happy paths overwrites an existing target file`.

**Why deferred:** Plan 09-05 touches NONE of the download / filesystem
infrastructure. Running the test file in isolation (`flutter test
test/infrastructure/downloads/atomic_renamer_test.dart`) produces 9/9
green. The failure only materialises under the full-suite parallel
runner — a classic concurrent-tempfile flake. Per GSD SCOPE BOUNDARY,
this is a pre-existing issue independent of Plan 09-05's diff
(introduced before the V4 schema work).

**Plan 09-05-only verification (in scope):**
- `flutter analyze --fatal-warnings --fatal-infos` zero issues across the
  whole project.
- `flutter test test/infrastructure/db/ test/infrastructure/stores/
  test/application/providers/ test/infrastructure/mirk/`: all green.
- `flutter test test/infrastructure/downloads/atomic_renamer_test.dart`
  in isolation: 9/9 green.

**Owner suggestion:** Phase 10 review gate or follow-up `chore(test)`
commit — the test likely needs a unique-temp-dir per case to survive
parallel execution.

---

### Plan 09-03 close (2026-04-25) — pre-existing format drift in `lib/domain/revealed/`

**Status at Plan 09-03 verification:** `dart format --set-exit-if-changed lib/domain/revealed test/domain/revealed` reports 3 files changed (none authored by Plan 09-03):

- `lib/domain/revealed/revealed_tile.dart`
- `lib/domain/revealed/revealed_tile_store.dart`
- `lib/domain/revealed/tile_math.dart`

**Why deferred:** Plan 09-03's `<files_modified>` is strictly
`lib/domain/revealed/reveal_calculator.dart`,
`test/domain/revealed/reveal_calculator_test.dart`,
`test/domain/revealed/reveal_calculator_parent_boundary_test.dart` (plus the
out-of-band Phase 03 placeholder-test retirement in
`test/domain/reveal_calculator_test.dart`). The 3 files surfaced by `dart format`
are pre-existing drift on commits prior to Plan 09-03. Per the GSD SCOPE BOUNDARY
rule, fixing them here would breach scope and risk colliding with the
concurrent Plan 09-02 wave that is also touching `lib/domain/`.

**Plan 09-03-only verification (in scope):**
`dart format --set-exit-if-changed lib/domain/revealed/reveal_calculator.dart test/domain/revealed/`
→ 3 files (0 changed), exit 0.

**Owner suggestion:** Phase 10 review gate or a follow-up `chore(format)` commit
once Wave 2 of Phase 09 is complete and the working tree is quiescent.

---

### Plan 09-06 close (2026-04-25) — `backup_test.dart::rotate keeps the 3 newest` + `download_soak_test.dart::soak: rename_target_already_exists` flaky under full-suite parallel execution

**Status at Plan 09-06 verification:** `flutter test` (full suite) shows 2 failures:
- `test/infrastructure/db/backup_test.dart::rotate keeps the 3 newest by filename-embedded ISO timestamp when 4 exist`
- `test/infrastructure/downloads/download_soak_test.dart::soak: rename_target_already_exists (Plan 08-04 Task 8) retry on already-installed pays overwrites cleanly + manifest holds one entry per alpha3 + zero leak`

**Why deferred:** Plan 09-06 touches NONE of the backup, download, or filesystem
infrastructure. Both files run cleanly in isolation:
- `flutter test test/infrastructure/db/backup_test.dart` → 7/7 green.
- `flutter test test/infrastructure/downloads/download_soak_test.dart` → 9/9 green.

The failures only materialise under the full-suite parallel runner — same
classic concurrent-tempfile / concurrent-DB-file flake pattern as the
`atomic_renamer_test.dart` issue logged at Plan 09-05 close above. Per GSD
SCOPE BOUNDARY, these are pre-existing issues independent of Plan 09-06's
diff (no plan task touches backup rotation or download retry logic).

**Plan 09-06-only verification (in scope):**
- `flutter analyze --fatal-warnings --fatal-infos` zero issues across the
  whole project.
- `flutter test test/application/controllers/` (all controller tests
  including the new RevealStreamingController, MirkStyleSessionController,
  and ActiveSessionController initial-reveal suites): all green.
- `flutter test test/infrastructure/stores/` (SessionStore extension):
  all green.
- `flutter test test/infrastructure/gps/` (LocationStream port extension):
  all green.

**Owner suggestion:** Phase 10 review gate. Both flaky tests likely need
unique-temp-dir per test case to survive parallel execution — same
pattern as the atomic_renamer_test fix that was already noted.
