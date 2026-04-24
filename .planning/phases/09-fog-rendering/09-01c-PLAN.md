---
phase: 09
plan: 01c
type: execute
wave: 1
depends_on: []
files_modified:
  - tool/fixtures/build_50k_tiles.dart
  - tool/check_mirk_fixture_fresh.dart
  - tool/check_mirk_variant_file_count.dart
  - tool/test/check_mirk_fixture_fresh_test.dart
  - tool/test/check_mirk_variant_file_count_test.dart
  - test/domain/revealed/reveal_calculator_test.dart
  - test/domain/revealed/reveal_calculator_parent_boundary_test.dart
  - test/infrastructure/mirk/noise/simplex_noise_2d_test.dart
  - test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart
  - test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart
  - test/infrastructure/mirk/candlelight_mirk_renderer_test.dart
  - test/infrastructure/mirk/heavenly_clouds_mirk_renderer_test.dart
  - test/infrastructure/mirk/mirk_renderer_factory_test.dart
  - test/infrastructure/mirk/builtin_renderers_smoke_test.dart
  - test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart
  - test/application/controllers/reveal_streaming_controller_test.dart
  - test/application/controllers/active_session_controller_initial_reveal_test.dart
  - test/application/controllers/mirk_style_session_controller_test.dart
  - test/presentation/widgets/session_burger_menu_style_selector_test.dart
  - test/presentation/widgets/mirk_overlay_feather_test.dart
  - test/presentation/widgets/mirk_overlay_swap_test.dart
  - test/presentation/widgets/mirk_overlay_composition_test.dart
  - test/presentation/map_screen_repaint_boundary_test.dart
  - test/presentation/map_screen_viewport_filtering_test.dart
  - test/performance/fog_50k_tiles_perf_test.dart
  - test/fixtures/mirk/builtin_styles.json
  - test/fixtures/mirk/imported_style_valid.json
  - test/fixtures/mirk/imported_style_unknown_type.json
  - test/fakes/fake_mirk_renderer.dart
  - test/fakes/fake_reveal_streaming_controller.dart
  - test/fakes/fake_mirk_style_session_controller.dart
  - .github/workflows/ci.yml
autonomous: true
requirements: [MIRK-01, MIRK-04, MIRK-05, MIRK-06, MIRK-07]

must_haves:
  truths:
    - "Every test file listed in 09-VALIDATION.md §Wave 0 Requirements exists with at least one `test(...)` block (initially `skip: 'Wave N — plan 09-NN'` placeholders)"
    - "`tool/check_mirk_variant_file_count.dart` exits 0 on the current repo state (6 renderer files present) and its paired test validates mutation branches"
    - "`tool/check_mirk_fixture_fresh.dart` Wave 0 scaffold exits 0 inertly"
    - "CI gate steps added to `.github/workflows/ci.yml` for both tool scripts"
    - "Three JSON fixtures parse as valid JSON"
    - "Three fakes are observable + minimal, zero dependencies on Wave 2+ types"
    - "`flutter test` full suite green (scaffolds all `skip:`-guarded; tool paired tests green)"
  artifacts:
    - path: "tool/fixtures/build_50k_tiles.dart"
      provides: "Deterministic fixture generator entrypoint (Wave 7 fills body)"
      contains: "main"
    - path: "tool/check_mirk_fixture_fresh.dart"
      provides: "CI gate — committed fixture SQL matches builder output (Wave 7 wires real diff)"
      contains: "main"
    - path: "tool/check_mirk_variant_file_count.dart"
      provides: "CI gate — structural enforcement 1 file per builtin variant"
      contains: "main"
    - path: "test/fixtures/mirk/builtin_styles.json"
      provides: "Round-trip cross-check fixture for the 4 builtins"
      contains: "atmospheric"
  key_links:
    - from: "all *_test.dart scaffolds"
      to: "dart_test / flutter_test runner"
      via: "top-level main() + test() blocks (skip-guarded)"
      pattern: "void main\\(\\)"
    - from: "tool/test/check_mirk_fixture_fresh_test.dart"
      to: "tool/check_mirk_fixture_fresh.dart"
      via: "Process.run + exit-code assertions"
      pattern: "Process\\.run"
    - from: ".github/workflows/ci.yml gates job"
      to: "tool/check_mirk_*.dart scripts"
      via: "CI `run:` steps"
      pattern: "check_mirk_"
---

<objective>
Wave 0 — scaffold **Part 3 of 3**. Creates every `test/`, `tool/`, and `test/fixtures/` artefact the downstream Phase 09 plans will reference. All test scaffolds are `skip:`-guarded with `'Wave N — plan 09-NN'` markers — they compile, report as skipped, and downstream plans drop the markers in their own waves.

Purpose: forward-declare test files + CI gates. Phase 09's continuous Nyquist-sampling strategy depends on these skeletons — without them, downstream plans would create test files from scratch under time pressure and risk uneven coverage.

Output: 22 test scaffolds + 3 JSON fixtures + 3 fakes + 3 tool scripts + 2 paired tool tests + CI gate wiring. All compile. Full suite green (skips expected).

**CRITICAL: this plan MUST NOT implement production logic** in the tool scripts beyond the variant-file-count gate which is load-bearing Wave 0 structural enforcement. The fixture builder + fixture-fresh gate stay inert placeholders until plan 09-08.

**Independence from 09-01 and 09-01b:** test scaffolds reference class NAMES from 09-01b scaffolds but do NOT call methods beyond trivial instantiation (which is `skip:`-guarded anyway). Fakes do NOT import Wave 2+ Freezed types. Therefore all three 09-01* plans run in parallel (same Wave 1).
</objective>

<execution_context>
@C:/Users/oliver/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/oliver/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/09-fog-rendering/09-CONTEXT.md
@.planning/phases/09-fog-rendering/09-RESEARCH.md
@.planning/phases/09-fog-rendering/09-VALIDATION.md
@CLAUDE.md
@.github/workflows/ci.yml
@lib/domain/mirk/mirk_renderer.dart
@lib/domain/mirk/mirk_paint_context.dart
@lib/infrastructure/mirk/noop_mirk_renderer.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: CI gate tools + paired tool tests + CI workflow wiring</name>
  <files>tool/fixtures/build_50k_tiles.dart, tool/check_mirk_fixture_fresh.dart, tool/check_mirk_variant_file_count.dart, tool/test/check_mirk_fixture_fresh_test.dart, tool/test/check_mirk_variant_file_count_test.dart, .github/workflows/ci.yml</files>
  <action>
Create three tool scripts + two paired tests + extend the CI workflow.

**`tool/fixtures/build_50k_tiles.dart`** — deterministic fixture builder. Wave 0 scaffold: `main()` that throws `UnimplementedError('Wave 7 — plan 09-08')` with a dartdoc documenting the Wave 7 responsibility.

```dart
/// Builds the deterministic 50k-row fixture at
/// `test/fixtures/mirk/fifty_k_tiles_seed.sql` for the Phase 09 perf probe.
///
/// Wave 0 scaffold — body lands in plan 09-08. See 09-RESEARCH §Fixture 50k
/// Strategy + Format for the seed + layout spec.
void main(List<String> args) {
  throw UnimplementedError('Wave 7 — plan 09-08');
}
```

**`tool/check_mirk_fixture_fresh.dart`** — CI gate; Wave 0 inert scaffold returning 0. Wave 7 replaces with real diff logic.

```dart
/// CI gate: ensures `test/fixtures/mirk/fifty_k_tiles_seed.sql` matches
/// what `tool/fixtures/build_50k_tiles.dart` produces.
///
/// Wave 0 scaffold: exits 0 (inert until Wave 7 wires the real diff).
int main(List<String> args) {
  print('check_mirk_fixture_fresh: Wave 0 scaffold — inert');
  return 0;
}
```

**`tool/check_mirk_variant_file_count.dart`** — CI gate that structurally enforces MIRK-05/06 "1 file per variant". Wave 0 implements the real check (simple enough — file counting). Load-bearing: this gate is consumed by 09-01b Task 2's scaffolds landing 6 renderer files.

```dart
/// CI gate: structurally enforces MIRK-05/06 "1 file per variant".
///
/// Counts `lib/infrastructure/mirk/*_mirk_renderer.dart` files and
/// asserts: (a) exactly 6 present (4 builtins + noop + shader), and
/// (b) each of the 4 builtin renderer filenames is present by string
/// match, plus `noop_mirk_renderer.dart` and `shader_mirk_renderer.dart`.
///
/// "1 file per variant" is a seam invariant: if this gate drifts, either
/// two variants accidentally share a file (smell — bad) or a variant is
/// missing (likely). See 09-RESEARCH §Registration Pattern Choice.
///
/// Exit codes: 0 clean · 1 policy violation · 2 misconfiguration.
int main(List<String> args) {
  const expectedRenderers = <String>{
    'atmospheric_mirk_renderer.dart',
    'solid_fill_mirk_renderer.dart',
    'candlelight_mirk_renderer.dart',
    'heavenly_clouds_mirk_renderer.dart',
    'noop_mirk_renderer.dart',
    'shader_mirk_renderer.dart',
  };
  // Walk lib/infrastructure/mirk/, collect *_mirk_renderer.dart filenames,
  // intersect against expectedRenderers. Missing or extra → exit 1 with diff.
  // ~30 LOC using Directory + File from dart:io.
  // (Implementation body written during Wave 0 execution.)
  return 0;
}
```

**Paired tests** in `tool/test/`:

`check_mirk_variant_file_count_test.dart` — three tests:
1. "green on current repo state" — invoke tool on current layout, expect exit 0.
2. "reports missing file" — copy lib/infrastructure/mirk to tmp, delete one renderer, invoke tool on tmp layout (via env-var override or argv), expect exit 1.
3. "reports extra file" — copy to tmp, add a dummy `phantom_mirk_renderer.dart`, invoke tool, expect exit 1.

`check_mirk_fixture_fresh_test.dart` — one test: "exits 0 on current repo state" (Wave 0 trivial since the tool is inert; Wave 7 extends with "exits 1 on tampering").

**Extend `.github/workflows/ci.yml`** gates job with two new `run` steps following the existing CI gate step pattern (see Phase 01's `check_headers`, Phase 07's `check_style_no_external_url`):

```yaml
- name: check_mirk_variant_file_count
  run: dart run tool/check_mirk_variant_file_count.dart

- name: check_mirk_fixture_fresh
  run: dart run tool/check_mirk_fixture_fresh.dart
```

**NOTE about test isolation**: `check_mirk_variant_file_count.dart` hard-codes `lib/infrastructure/mirk/` as the walk root in Wave 0. The paired test's "missing file" / "extra file" branches require parameterisation — suggested shape: accept an optional `--root=<path>` argv. Implement now so tests can target tmp dirs.

Apply GOSL headers. `dart format`. `flutter analyze` zero-issue.
  </action>
  <verify>
    <automated>dart format --set-exit-if-changed tool/fixtures/build_50k_tiles.dart tool/check_mirk_fixture_fresh.dart tool/check_mirk_variant_file_count.dart tool/test/check_mirk_fixture_fresh_test.dart tool/test/check_mirk_variant_file_count_test.dart .github/workflows/ci.yml && flutter analyze --fatal-warnings --fatal-infos && dart run tool/check_headers.dart && dart run tool/check_mirk_variant_file_count.dart && dart run tool/check_mirk_fixture_fresh.dart && dart test tool/test/check_mirk_variant_file_count_test.dart tool/test/check_mirk_fixture_fresh_test.dart</automated>
  </verify>
  <done>
- All 5 tool files exist with GOSL headers
- `check_mirk_variant_file_count.dart` implemented (real logic, not stub) and exits 0 on current repo
- `check_mirk_fixture_fresh.dart` is an inert Wave 0 scaffold (exit 0)
- Paired tests exercise mutation branches for the file-count gate
- `.github/workflows/ci.yml` gates job runs both scripts
  </done>
</task>

<task type="auto">
  <name>Task 2: Test scaffolds under test/domain, test/infrastructure, test/application, test/presentation, test/performance</name>
  <files>test/domain/revealed/reveal_calculator_test.dart, test/domain/revealed/reveal_calculator_parent_boundary_test.dart, test/infrastructure/mirk/noise/simplex_noise_2d_test.dart, test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart, test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart, test/infrastructure/mirk/candlelight_mirk_renderer_test.dart, test/infrastructure/mirk/heavenly_clouds_mirk_renderer_test.dart, test/infrastructure/mirk/mirk_renderer_factory_test.dart, test/infrastructure/mirk/builtin_renderers_smoke_test.dart, test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart, test/application/controllers/reveal_streaming_controller_test.dart, test/application/controllers/active_session_controller_initial_reveal_test.dart, test/application/controllers/mirk_style_session_controller_test.dart, test/presentation/widgets/session_burger_menu_style_selector_test.dart, test/presentation/widgets/mirk_overlay_feather_test.dart, test/presentation/widgets/mirk_overlay_swap_test.dart, test/presentation/widgets/mirk_overlay_composition_test.dart, test/presentation/map_screen_repaint_boundary_test.dart, test/presentation/map_screen_viewport_filtering_test.dart, test/performance/fog_50k_tiles_perf_test.dart</files>
  <action>
For every test file listed in 09-VALIDATION.md §Wave 0 Requirements, create a scaffold with:
- GOSL header
- Correct imports (`package:flutter_test/flutter_test.dart` for widget/render tests, `package:test/test.dart` for pure-Dart unit tests)
- A `void main() { group('<plan-id> — <topic>', () { ... }) }` scaffold
- Inside the group, AT LEAST one `test('<behaviour>', () { ... }, skip: 'Wave N — plan 09-NN');` placeholder per behaviour listed in 09-VALIDATION.md

Example for `test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart`:

```dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('09-04 — AtmosphericMirkRenderer (MIRK-04)', () {
    test('paint() output differs across frames (animation proof)', () {
      // Wave 3 body: render two frames via PictureRecorder, assert
      // picture bytes differ. Golden-compatible tolerance.
    }, skip: 'Wave 3 — plan 09-04');

    test('noise respects kMirkNoiseScaleDefault by default', () {
    }, skip: 'Wave 3 — plan 09-04');

    test('dispose() is idempotent', () {
    }, skip: 'Wave 3 — plan 09-04');
  });
}
```

The `skip: 'Wave N — plan 09-NN'` marker is load-bearing: (1) tests run green in Wave 0 without bodies, (2) downstream executors search for their plan ID, (3) `flutter test` reports skipped tests which a later VERIFICATION step counts down.

Apply this pattern to every test file in files_modified. **For `test/application/controllers/active_session_controller_initial_reveal_test.dart`**: create this NEW file (not modify the existing `active_session_controller_test.dart`) so the initial-reveal group is isolated.

**For `test/presentation/map_screen_repaint_boundary_test.dart` + `map_screen_viewport_filtering_test.dart`**: these are widget tests — use `testWidgets(...)` signature.

**For `test/performance/fog_50k_tiles_perf_test.dart`**: tag with `@Tags(['mirk-perf'])` via library-level annotation per the Phase 07 `soak_test` precedent:

```dart
@Tags(['mirk-perf'])
library mirkfall.test.performance.fog_50k_tiles;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('09-08 — 50k tiles perf (SC#4)', () {
    testWidgets('paint pass ≤ 16 ms on 50k fixture', (tester) async {
    }, skip: 'Wave 7 — plan 09-08');
  });
}
```

Apply GOSL headers + format + analyze.
  </action>
  <verify>
    <automated>dart format --set-exit-if-changed test/domain/revealed test/infrastructure/mirk test/application/controllers test/presentation/widgets test/presentation/map_screen_repaint_boundary_test.dart test/presentation/map_screen_viewport_filtering_test.dart test/performance/fog_50k_tiles_perf_test.dart && flutter analyze --fatal-warnings --fatal-infos && flutter test test/domain/revealed test/infrastructure/mirk test/application/controllers/reveal_streaming_controller_test.dart test/application/controllers/mirk_style_session_controller_test.dart test/application/controllers/active_session_controller_initial_reveal_test.dart test/presentation/widgets/session_burger_menu_style_selector_test.dart test/presentation/widgets/mirk_overlay_feather_test.dart test/presentation/widgets/mirk_overlay_swap_test.dart test/presentation/widgets/mirk_overlay_composition_test.dart test/presentation/map_screen_repaint_boundary_test.dart test/presentation/map_screen_viewport_filtering_test.dart</automated>
  </verify>
  <done>
- All 20 test scaffold files exist with GOSL headers
- Every scaffold has at least one `test(...)` or `testWidgets(...)` block, all `skip:`-guarded with `'Wave N — plan 09-NN'` markers
- Perf test tagged `@Tags(['mirk-perf'])` via library annotation
- `flutter test` full suite green (skips expected, no new failures)
- `dart format` + `flutter analyze` zero issues
  </done>
</task>

<task type="auto">
  <name>Task 3: JSON fixtures + Dart fakes</name>
  <files>test/fixtures/mirk/builtin_styles.json, test/fixtures/mirk/imported_style_valid.json, test/fixtures/mirk/imported_style_unknown_type.json, test/fakes/fake_mirk_renderer.dart, test/fakes/fake_reveal_streaming_controller.dart, test/fakes/fake_mirk_style_session_controller.dart</files>
  <action>
### JSON fixtures

**`test/fixtures/mirk/builtin_styles.json`** — well-formed JSON array with 4 entries, one per builtin. Each entry has `{id, displayName, config: {rendererType, ...}}`. Example:

```json
[
  {
    "id": "builtin.atmospheric",
    "displayName": "Atmospheric (défaut)",
    "config": {
      "rendererType": "atmospheric",
      "baseColorArgb": 4278190080,
      "noiseScale": 0.5
    }
  },
  { "id": "builtin.solid", "displayName": "Solid",
    "config": { "rendererType": "solid", "colorArgb": 4279900698 } },
  { "id": "builtin.candlelight", "displayName": "Lueur de bougie",
    "config": { "rendererType": "candlelight",
                "centerColorArgb": 4294676330,
                "peripheryColorArgb": 4290917934,
                "noiseScale": 0.8, "noiseSpeed": 0.1,
                "baselineAlpha": 0.85 } },
  { "id": "builtin.heavenly_clouds", "displayName": "Nuages célestes",
    "config": { "rendererType": "heavenly",
                "colorArgb": 4293256942, "noiseScale": 0.3,
                "noiseSpeed": 0.08, "driftDirectionDeg": 45.0,
                "baselineAlpha": 0.80 } }
]
```

Exact field names must align with Wave 2's Freezed extensions (plan 09-02). If any differ after 09-02 lands, plan 09-02 Task 2 adjusts the JSON — Wave 0 commits the best-guess shape.

**`test/fixtures/mirk/imported_style_valid.json`** — single atmospheric-variant JSON authored "by a user" for Phase 13 prep:
```json
{
  "id": "user.night_sky",
  "displayName": "Night sky (user import)",
  "config": {
    "rendererType": "atmospheric",
    "baseColorArgb": 4278224707,
    "noiseScale": 0.6
  }
}
```

**`test/fixtures/mirk/imported_style_unknown_type.json`** — deliberately-unknown `rendererType` so UnknownConfig fallback tests can consume it:
```json
{
  "id": "user.mystery",
  "displayName": "Mystery renderer",
  "config": {
    "rendererType": "ray_marched_volumetric",
    "fancyParam": 42
  }
}
```

### Fakes

**Three fakes in `test/fakes/`** — minimal observable implementations, zero dependencies on Wave 2+ types. Each fake exposes:
- observable counters (paint calls, update calls, dispose calls)
- optional throw-on-call flag for error-path tests
- reset helper

`fake_mirk_renderer.dart`:
```dart
class FakeMirkRenderer implements MirkRenderer {
  int paintCallCount = 0;
  int updateCallCount = 0;
  int disposeCallCount = 0;
  final List<MirkPaintContext> paintContexts = [];

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    paintCallCount++;
    paintContexts.add(context);
  }
  @override
  void update(Duration elapsed) => updateCallCount++;
  @override
  Future<void> dispose() async { disposeCallCount++; }
}
```

`fake_reveal_streaming_controller.dart` — exposes `onFixCalls`, `revealInitialCalls`, `flushCallCount`, `disposeCallCount`. Wave 5 plan 09-06 extends as needed.

`fake_mirk_style_session_controller.dart` — exposes `selectCalls` (list of `{sessionId, styleId}` records). Wave 6 plan 09-07 consumes in burger-menu tests.

Apply GOSL headers on `.dart` files (JSON files don't take headers). `dart format .` at end. `flutter test` full suite green (fakes compile but aren't exercised Wave 0).
  </action>
  <verify>
    <automated>dart format --set-exit-if-changed test/fakes/fake_mirk_renderer.dart test/fakes/fake_reveal_streaming_controller.dart test/fakes/fake_mirk_style_session_controller.dart && flutter analyze --fatal-warnings --fatal-infos && dart run tool/check_headers.dart && dart test --plain-name 'JSON fixture parse sanity' test/fixtures/ 2>&1 || echo 'Expected: no tests in fixtures dir — validate via dart:convert jsonDecode inline'</automated>
  </verify>
  <done>
- Three JSON fixtures parse as valid JSON (consumers verify in later plans)
- Three fake Dart files exist with GOSL headers, observable counters, minimal surface
- Fakes do NOT import Wave 2+ Freezed types (no `SolidConfig`, no `VisibleMirkTile` field access)
- `flutter analyze` green
  </done>
</task>

</tasks>

<verification>
At plan close:
1. `dart format --set-exit-if-changed test tool .github/workflows` — clean
2. `flutter analyze --fatal-warnings --fatal-infos` — zero issues
3. `dart run tool/check_headers.dart` — green
4. `dart run tool/check_mirk_variant_file_count.dart` — exit 0
5. `dart run tool/check_mirk_fixture_fresh.dart` — exit 0 (inert Wave 0)
6. `dart test tool/test/check_mirk_variant_file_count_test.dart tool/test/check_mirk_fixture_fresh_test.dart` — green
7. `flutter test` — full suite green (new scaffolds all `skip:`-guarded)
</verification>

<success_criteria>
Plan 09-01c closed when:
1. All 22 test scaffolds + 3 JSON fixtures + 3 fakes + 3 tool scripts + 2 paired tests + CI gate wiring exist
2. `check_mirk_variant_file_count.dart` implemented (real logic); paired test green
3. `check_mirk_fixture_fresh.dart` inert (exit 0); paired test asserts current-state green
4. CI gates job runs both scripts
5. Every test scaffold is `skip:`-guarded with a `'Wave N — plan 09-NN'` marker
6. Full test suite green + all gate tools exit 0
</success_criteria>

<output>
After completion, create `.planning/phases/09-fog-rendering/09-01c-SUMMARY.md`:
- Counts: 22 test files / 3 fixtures / 3 fakes / 5 tool files / 1 CI workflow edit
- Key deviation notes (e.g., JSON field names if they don't survive Wave 2 Freezed extension)
- Handoff: Wave 2 plans 09-02 and 09-03 drop `skip:` markers on their respective test files. Waves 3-7 follow the same pattern.
</output>
</content>
</invoke>