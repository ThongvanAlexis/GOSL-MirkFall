---
phase: 09
plan: 01b
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/domain/mirk/mirk_viewport_bbox.dart
  - lib/domain/mirk/visible_mirk_tile.dart
  - lib/infrastructure/mirk/atmospheric_mirk_renderer.dart
  - lib/infrastructure/mirk/solid_fill_mirk_renderer.dart
  - lib/infrastructure/mirk/candlelight_mirk_renderer.dart
  - lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart
  - lib/infrastructure/mirk/shader_mirk_renderer.dart
  - lib/infrastructure/mirk/mirk_renderer_factory.dart
  - lib/infrastructure/mirk/builtin_mirk_styles.dart
  - lib/infrastructure/mirk/noise/simplex_noise_2d.dart
  - lib/application/controllers/reveal_streaming_controller.dart
  - lib/application/controllers/mirk_style_session_controller.dart
  - lib/application/providers/mirk_renderer_factory_provider.dart
  - lib/application/providers/active_mirk_renderer_provider.dart
  - lib/application/providers/reveal_streaming_controller_provider.dart
  - lib/application/providers/builtin_mirk_styles_provider.dart
  - lib/application/providers/visible_mirk_tiles_provider.dart
  - lib/application/providers/map_viewport_provider.dart
  - lib/presentation/widgets/mirk_overlay.dart
  - lib/presentation/widgets/mirk_style_picker_sheet.dart
  - lib/presentation/widgets/mirk_initial_reveal_fade.dart
autonomous: true
requirements: [MIRK-01, MIRK-04, MIRK-05, MIRK-06, MIRK-07]

must_haves:
  truths:
    - "Every lib/ source file Phase 09 will fill in exists as a compiling stub (class declared, methods throw UnimplementedError)"
    - "Domain-layer scaffolds stay MapLibre-free (import check via check_avoid_maplibre_leak.dart)"
    - "`dart analyze lib` returns zero warnings / errors"
    - "GOSL header present on every new file (check_headers.dart green)"
    - "No `.freezed.dart` or `.g.dart` regeneration yet — Wave 2 (plan 09-02) owns Freezed codegen; Wave 4 (plan 09-05) owns Riverpod codegen"
  artifacts:
    - path: "lib/domain/mirk/mirk_viewport_bbox.dart"
      provides: "Placeholder class (Wave 2 rewrites as @freezed)"
      contains: "class MirkViewportBbox"
    - path: "lib/domain/mirk/visible_mirk_tile.dart"
      provides: "Placeholder class (Wave 2 rewrites as @freezed)"
      contains: "class VisibleMirkTile"
    - path: "lib/infrastructure/mirk/atmospheric_mirk_renderer.dart"
      provides: "AtmosphericMirkRenderer scaffold class"
      contains: "class AtmosphericMirkRenderer"
    - path: "lib/infrastructure/mirk/solid_fill_mirk_renderer.dart"
      provides: "SolidFillMirkRenderer scaffold"
      contains: "class SolidFillMirkRenderer"
    - path: "lib/infrastructure/mirk/candlelight_mirk_renderer.dart"
      provides: "CandlelightMirkRenderer scaffold"
      contains: "class CandlelightMirkRenderer"
    - path: "lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart"
      provides: "HeavenlyCloudsMirkRenderer scaffold"
      contains: "class HeavenlyCloudsMirkRenderer"
    - path: "lib/infrastructure/mirk/shader_mirk_renderer.dart"
      provides: "ShaderMirkRenderer stub (Phase 13 body)"
      contains: "class ShaderMirkRenderer"
    - path: "lib/infrastructure/mirk/mirk_renderer_factory.dart"
      provides: "MirkRendererFactory scaffold (sealed-switch skeleton)"
      contains: "class MirkRendererFactory"
    - path: "lib/infrastructure/mirk/builtin_mirk_styles.dart"
      provides: "kBuiltinMirkStyles registry constant scaffold"
      contains: "kBuiltinMirkStyles"
    - path: "lib/infrastructure/mirk/noise/simplex_noise_2d.dart"
      provides: "SimplexNoise2D scaffold"
      contains: "class SimplexNoise2D"
  key_links:
    - from: "lib/application/controllers/* scaffolds"
      to: "lib/application/providers/* scaffolds"
      via: "future Riverpod codegen (Wave 4 plan 09-05)"
      pattern: "TODO\\(09-05\\)"
    - from: "lib/infrastructure/mirk/*_mirk_renderer.dart scaffolds"
      to: "lib/domain/mirk/mirk_renderer.dart (frozen)"
      via: "implements MirkRenderer"
      pattern: "implements MirkRenderer"
---

<objective>
Wave 0 — scaffold **Part 2 of 3**. Creates every `lib/` source file that later Phase 09 waves will fill in. All bodies are `UnimplementedError` stubs or trivial inert widgets so downstream plans encounter ZERO "file does not exist" friction.

Purpose: forward-declare classes, providers, widgets. Without this scaffold, Wave 2's domain extensions would block every downstream plan because the factory / renderers / controllers haven't been named yet.

Output: 21 compiling `lib/` placeholder files. Zero production behaviour. `dart analyze` green.

**CRITICAL: this plan MUST NOT implement production logic.** Bodies are `throw UnimplementedError('Wave N — plan 09-NN')` with a plan reference, OR trivial widget stubs (e.g., `SizedBox.shrink()`). The goal is structural, not behavioural.

**Independence from 09-01a and 09-01c:** this plan consumes NOTHING from plan 09-01 (it does not import any Phase 09 constant — scaffolds throw `UnimplementedError` before reading config). Plan 09-01c's test stubs reference these class NAMES but do NOT require their bodies. Therefore all three 09-01* plans run in parallel (same Wave 1).
</objective>

<execution_context>
@C:/Users/oliver/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/oliver/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/09-fog-rendering/09-CONTEXT.md
@.planning/phases/09-fog-rendering/09-RESEARCH.md
@CLAUDE.md
@lib/domain/mirk/mirk_renderer.dart
@lib/domain/mirk/mirk_paint_context.dart
@lib/domain/mirk/mirk_style_config.dart
@lib/infrastructure/mirk/noop_mirk_renderer.dart

<interfaces>
<!-- Existing surface Wave 0 MUST preserve. -->

From lib/domain/mirk/mirk_renderer.dart (FROZEN — DO NOT MODIFY):
```dart
abstract class MirkRenderer {
  void paint(Canvas canvas, Size size, MirkPaintContext context);
  void update(Duration elapsed);
  Future<void> dispose();
}
```

From lib/domain/mirk/mirk_paint_context.dart (Phase 07 shape — Wave 2 plan 09-02 extends):
```dart
factory MirkPaintContext({
  required double zoomLevel,
  required double pixelRatio,
  required Duration sessionElapsed,
}) = _MirkPaintContext;
```
Wave 2 adds `viewportBbox`, `currentFix`, and `visibleTiles` (consolidated into plan 09-02 per B3 resolution). `sessionElapsed` stays — no `frameElapsed` rename.

From lib/domain/mirk/mirk_style_config.dart (Phase 03 — Wave 2 plan 09-02 extends to 6 variants):
```dart
@Freezed(unionKey: 'rendererType', fallbackUnion: 'unknown')
sealed class MirkStyleConfig { ... }
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Domain scaffolds — MirkViewportBbox + VisibleMirkTile (plain classes; Wave 2 rewrites as @freezed)</name>
  <files>lib/domain/mirk/mirk_viewport_bbox.dart, lib/domain/mirk/visible_mirk_tile.dart</files>
  <action>
Create two placeholder classes under `lib/domain/mirk/`. Wave 2 plan 09-02 will rewrite BOTH as Freezed types. Wave 0 emits plain stub classes so downstream scaffolds can import the type names.

**1. `lib/domain/mirk/mirk_viewport_bbox.dart`** — plain class placeholder:

```dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Bounding box of the current map viewport, expressed in lat/lon.
///
/// Phase 09 introduces this type to keep [MirkPaintContext] free of
/// MapLibre types (`LatLngBounds`) per the MAP-06 seam discipline. The
/// real Freezed declaration lands in plan 09-02; Wave 0 emits this
/// placeholder so downstream scaffolds can import the type name.
///
/// TODO(09-02): replace with `@freezed abstract class MirkViewportBbox`.
class MirkViewportBbox {
  const MirkViewportBbox({required this.south, required this.west, required this.north, required this.east});
  final double south;
  final double west;
  final double north;
  final double east;
}
```

**2. `lib/domain/mirk/visible_mirk_tile.dart`** — plain class placeholder. Per B3 resolution, Wave 2 plan 09-02 owns the Freezed rewrite + the addition of `visibleTiles: List<VisibleMirkTile>` to `MirkPaintContext`. Wave 0 scaffold:

```dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

/// One parent tile's data, pre-projected for the current frame.
///
/// Phase 09 Wave 2 (plan 09-02) rewrites this as `@freezed` and folds it
/// into `MirkPaintContext.visibleTiles`. Wave 0 placeholder — downstream
/// renderer scaffolds (plan 09-04) import the type name.
///
/// TODO(09-02): replace with `@freezed abstract class VisibleMirkTile`.
class VisibleMirkTile {
  const VisibleMirkTile({
    required this.parentX,
    required this.parentY,
    required this.bitmap,
    required this.tileNorthLat,
    required this.tileWestLon,
    required this.tileSouthLat,
    required this.tileEastLon,
  });
  final int parentX;
  final int parentY;
  final Uint8List bitmap;
  final double tileNorthLat;
  final double tileWestLon;
  final double tileSouthLat;
  final double tileEastLon;
}
```

Apply GOSL headers. `dart format`. `flutter analyze` zero-issue. Confirm `check_domain_purity.dart` stays green — `Uint8List` is in `dart:typed_data` (stdlib) and should be allowed; if the gate rejects, temporarily switch to `List<int>` and document in SUMMARY.
  </action>
  <verify>
    <automated>dart format --set-exit-if-changed lib/domain/mirk/mirk_viewport_bbox.dart lib/domain/mirk/visible_mirk_tile.dart && flutter analyze --fatal-warnings --fatal-infos && dart run tool/check_headers.dart && dart run tool/check_domain_purity.dart</automated>
  </verify>
  <done>
- Both domain scaffold files exist with GOSL headers
- `MirkViewportBbox` + `VisibleMirkTile` classes declared (plain, not Freezed yet)
- `check_domain_purity.dart` green
- `flutter analyze` green
  </done>
</task>

<task type="auto">
  <name>Task 2: Infrastructure mirk/ scaffolds — 4 concrete renderers + shader stub + factory + registry + noise</name>
  <files>lib/infrastructure/mirk/atmospheric_mirk_renderer.dart, lib/infrastructure/mirk/solid_fill_mirk_renderer.dart, lib/infrastructure/mirk/candlelight_mirk_renderer.dart, lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart, lib/infrastructure/mirk/shader_mirk_renderer.dart, lib/infrastructure/mirk/mirk_renderer_factory.dart, lib/infrastructure/mirk/builtin_mirk_styles.dart, lib/infrastructure/mirk/noise/simplex_noise_2d.dart</files>
  <action>
Create 8 scaffold files under `lib/infrastructure/mirk/`. Every file has:
- GOSL v1.0 header
- `dart format`-clean source
- Dartdoc on public classes/methods
- Bodies that throw `UnimplementedError('Wave N — plan 09-NN')` with a plan reference

**Do NOT regenerate Freezed artefacts and do NOT add `@Riverpod` annotations that would need `build_runner`** — that happens in Waves 2 and 4.

**1. Four concrete renderers** (`atmospheric_mirk_renderer.dart`, `solid_fill_mirk_renderer.dart`, `candlelight_mirk_renderer.dart`, `heavenly_clouds_mirk_renderer.dart`) — each `implements MirkRenderer` with three UnimplementedError bodies. Example (all 4 follow this pattern with different class names):

```dart
import 'dart:ui' show Canvas, Size;
import '../../domain/mirk/mirk_paint_context.dart';
import '../../domain/mirk/mirk_renderer.dart';
import '../../domain/mirk/mirk_style_config.dart';

/// Default atmospheric fog — dark noise-modulated overlay.
///
/// Implementation lands in plan 09-04 (Wave 3).
class AtmosphericMirkRenderer implements MirkRenderer {
  AtmosphericMirkRenderer(this.config);
  final AtmosphericConfig config;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) =>
      throw UnimplementedError('Wave 3 — plan 09-04');

  @override
  void update(Duration elapsed) =>
      throw UnimplementedError('Wave 3 — plan 09-04');

  @override
  Future<void> dispose() async =>
      throw UnimplementedError('Wave 3 — plan 09-04');
}
```

**CRITICAL for Wave 0:** `SolidConfig`, `CandlelightConfig`, `HeavenlyCloudsConfig` don't exist yet (Wave 2 plan 09-02 adds them). For those 3 NEW variants, scaffold renderers must NOT reference the not-yet-existing types by name in Wave 0. Use this pattern:

```dart
class SolidFillMirkRenderer implements MirkRenderer {
  // TODO(09-04): accept `SolidConfig config` once plan 09-02 adds the
  // sealed variant. For Wave 0, no config parameter.
  SolidFillMirkRenderer();

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) =>
      throw UnimplementedError('Wave 3 — plan 09-04');
  @override
  void update(Duration elapsed) =>
      throw UnimplementedError('Wave 3 — plan 09-04');
  @override
  Future<void> dispose() async =>
      throw UnimplementedError('Wave 3 — plan 09-04');
}
```

`AtmosphericConfig` already exists (Phase 03) — `AtmosphericMirkRenderer` CAN accept it in Wave 0.

**2. `shader_mirk_renderer.dart`** — stub that stays `UnimplementedError` past Phase 09 (Phase 13 body). Document in dartdoc: "Phase 13 implementation. Phase 09 registers the type so the sealed union exhaustiveness compiles." Factory (Wave 4) will dispatch `ShaderConfig` here, but Wave 3's plan 09-04 may choose to wrap in a try/catch. Wave 0 scaffold: `UnimplementedError('Phase 13 — ShaderConfig body')`. Constructor signature: `ShaderMirkRenderer()` (no config param until Wave 4 promotes to `ShaderMirkRenderer(ShaderConfig config)`).

**3. `mirk_renderer_factory.dart`** — skeleton class with a single method `create(MirkStyleConfig config)` that throws `UnimplementedError('Wave 4 — plan 09-05')`. Wave 4 rewrites this with the sealed switch.

**4. `builtin_mirk_styles.dart`** — scaffold:
```dart
/// Registry of built-in mirk styles. Populated in plan 09-05.
///
/// Wave 0 emits an empty placeholder; Wave 4 adds the 4 descriptors.
// TODO(09-05): const List<BuiltinMirkStyleDescriptor> kBuiltinMirkStyles.
```

Wave 0 does NOT need `BuiltinMirkStyleDescriptor` — that's a Wave 4 type. The file just needs to exist with the header + the TODO comment.

**5. `noise/simplex_noise_2d.dart`** — class scaffold with `UnimplementedError` in `noise2(double x, double y)`. Wave 2 fills the body (Ken Perlin 2001 simplex, ~60 LOC). Constructor signature `SimplexNoise2D({int seed = 0})`.

Every file gets:
- GOSL header
- `dart format`-clean
- NO `package:maplibre_gl/*` imports (would trip `check_avoid_maplibre_leak.dart`)

After creating all files, run `dart format .` and `flutter analyze`. Zero warnings allowed. If analyzer complains about "unused import" on scaffold files, remove the offending unused imports. If it complains about `UnimplementedError` unreachability after the `throw`, add `// ignore: dead_code — Wave 3+ replaces this body; scaffold intentionally unreachable`.

**DO NOT run `dart run build_runner build`** — that's Wave 2's responsibility.
  </action>
  <verify>
    <automated>dart format --set-exit-if-changed lib/infrastructure/mirk/atmospheric_mirk_renderer.dart lib/infrastructure/mirk/solid_fill_mirk_renderer.dart lib/infrastructure/mirk/candlelight_mirk_renderer.dart lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart lib/infrastructure/mirk/shader_mirk_renderer.dart lib/infrastructure/mirk/mirk_renderer_factory.dart lib/infrastructure/mirk/builtin_mirk_styles.dart lib/infrastructure/mirk/noise/simplex_noise_2d.dart && flutter analyze --fatal-warnings --fatal-infos && dart run tool/check_headers.dart && dart run tool/check_avoid_maplibre_leak.dart</automated>
  </verify>
  <done>
- All 8 infrastructure scaffold files exist with GOSL headers
- Every scaffold class throws `UnimplementedError` with a plan reference
- `flutter analyze`, `check_headers.dart`, `check_avoid_maplibre_leak.dart` all pass
- No `.freezed.dart` / `.g.dart` regeneration triggered
- Phase 07 `mirk_renderer_contract_test` still green (interface frozen)
  </done>
</task>

<task type="auto">
  <name>Task 3: Application + presentation scaffolds — controllers, providers, widgets (incl. initial-reveal-fade widget)</name>
  <files>lib/application/controllers/reveal_streaming_controller.dart, lib/application/controllers/mirk_style_session_controller.dart, lib/application/providers/mirk_renderer_factory_provider.dart, lib/application/providers/active_mirk_renderer_provider.dart, lib/application/providers/reveal_streaming_controller_provider.dart, lib/application/providers/builtin_mirk_styles_provider.dart, lib/application/providers/visible_mirk_tiles_provider.dart, lib/application/providers/map_viewport_provider.dart, lib/presentation/widgets/mirk_overlay.dart, lib/presentation/widgets/mirk_style_picker_sheet.dart, lib/presentation/widgets/mirk_initial_reveal_fade.dart</files>
  <action>
Create 11 scaffold files across `lib/application/` and `lib/presentation/`. Every file:
- GOSL header
- `dart format`-clean
- Bodies throw `UnimplementedError` or return inert widgets (`SizedBox.shrink()`)

**1. Two controllers** (`reveal_streaming_controller.dart`, `mirk_style_session_controller.dart`) — class scaffolds with UnimplementedError method stubs matching the method surface in 09-RESEARCH §Reveal Streaming Controller and §In-Session Style Swap Lifecycle. Example:

```dart
class RevealStreamingController {
  // TODO(09-06): constructor accepts RevealedTileStore + flush settings.
  RevealStreamingController();

  /// Consumes a GPS fix and schedules the reveal mask merge.
  Future<void> onFix(/* Fix fix */) async =>
      throw UnimplementedError('Wave 5 — plan 09-06');

  /// Flushes any buffered reveals (time-bound or count-bound trigger).
  Future<void> flush() async =>
      throw UnimplementedError('Wave 5 — plan 09-06');

  /// Writes the initial 20 m reveal around [fix].
  Future<void> revealInitial(/* Fix fix */) async =>
      throw UnimplementedError('Wave 5 — plan 09-06');

  Future<void> dispose() async =>
      throw UnimplementedError('Wave 5 — plan 09-06');
}
```

`MirkStyleSessionController` mirror pattern with `select(/* MirkStyleId styleId */)` method.

**2. Six providers** — plain Dart stubs (NOT `@Riverpod`-generated yet). Wave 4 (plan 09-05) promotes each to a `@riverpod`-annotated function. Each file:

```dart
// TODO(09-05): rewrite as @Riverpod(keepAlive: true) generator target.
//
// Wave 0 emits this non-Riverpod stub so downstream scaffolds can
// reference `mirkRendererFactoryProvider` as a compiling symbol. Wave 4
// replaces this file with a @riverpod-annotated function + regenerated
// `.g.dart`.

void mirkRendererFactoryProvider() =>
    // ignore: dead_code — Wave 4 replaces this body; scaffold intentionally unreachable
    throw UnimplementedError('Wave 4 — plan 09-05');
```

Apply same pattern to:
- `active_mirk_renderer_provider.dart`
- `reveal_streaming_controller_provider.dart`
- `builtin_mirk_styles_provider.dart`
- `visible_mirk_tiles_provider.dart` (new — plan 09-07 fills)
- `map_viewport_provider.dart` (new — plan 09-07 fills; see S2 resolution)

**3. `mirk_overlay.dart`** — `StatefulWidget` scaffold. Returns `SizedBox.shrink()` in `build`. Plan 09-07 rewrites with Ticker + CustomPainter.

```dart
class MirkOverlay extends StatefulWidget {
  const MirkOverlay({super.key});
  @override
  State<MirkOverlay> createState() => _MirkOverlayState();
}
class _MirkOverlayState extends State<MirkOverlay> {
  // TODO(09-07): SingleTickerProviderStateMixin + Ticker + CustomPainter.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**4. `mirk_style_picker_sheet.dart`** — `StatelessWidget` scaffold returning `SizedBox.shrink()`. Plan 09-07 rewrites as bottom sheet listing the 4 builtins.

**5. `mirk_initial_reveal_fade.dart`** — NEW WIDGET for B4 resolution (500 ms fade-in for initial 20 m reveal). Wave 0 scaffold:

```dart
// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';

/// Fades the initial 20 m reveal from opacity 0 to 1 over
/// `kInitialRevealFadeInMs` (500 ms) at session start.
///
/// Uses a dedicated `AnimationController`, decoupled from the main mirk
/// Ticker — the fade is a one-shot session-open animation, not part of
/// the noise tick frequency. Plan 09-07 Task 4 implements the body.
///
/// TODO(09-07): SingleTickerProviderStateMixin + AnimationController +
/// trigger on ActiveSessionController.startSession() resolving (or first
/// fix arriving if no lastKnownFix).
class MirkInitialRevealFade extends StatefulWidget {
  const MirkInitialRevealFade({super.key, required this.child});
  final Widget child;
  @override
  State<MirkInitialRevealFade> createState() => _MirkInitialRevealFadeState();
}

class _MirkInitialRevealFadeState extends State<MirkInitialRevealFade> {
  @override
  Widget build(BuildContext context) => widget.child;
}
```

Apply headers, format, analyze. No Riverpod codegen. No Flutter imports in the `lib/application/controllers/` files (controllers are pure Dart + domain ports).
  </action>
  <verify>
    <automated>dart format --set-exit-if-changed lib/application/controllers/reveal_streaming_controller.dart lib/application/controllers/mirk_style_session_controller.dart lib/application/providers/mirk_renderer_factory_provider.dart lib/application/providers/active_mirk_renderer_provider.dart lib/application/providers/reveal_streaming_controller_provider.dart lib/application/providers/builtin_mirk_styles_provider.dart lib/application/providers/visible_mirk_tiles_provider.dart lib/application/providers/map_viewport_provider.dart lib/presentation/widgets/mirk_overlay.dart lib/presentation/widgets/mirk_style_picker_sheet.dart lib/presentation/widgets/mirk_initial_reveal_fade.dart && flutter analyze --fatal-warnings --fatal-infos && dart run tool/check_headers.dart && dart run tool/check_avoid_maplibre_leak.dart</automated>
  </verify>
  <done>
- All 11 application + presentation scaffold files exist
- Every scaffold class + provider function has a TODO referencing the wave that fills it
- `flutter analyze` green; check gates green
- Phase 07 existing tests still green (no production behaviour changed)
  </done>
</task>

</tasks>

<verification>
At plan close:
1. `dart format --set-exit-if-changed .` — clean
2. `flutter analyze --fatal-warnings --fatal-infos` — zero issues
3. `dart run tool/check_headers.dart` — zero missing headers
4. `dart run tool/check_domain_purity.dart` — zero violations
5. `dart run tool/check_avoid_maplibre_leak.dart` — zero violations
6. `flutter test` — full suite green (no behaviour change, no new test scaffolds in THIS plan)
</verification>

<success_criteria>
Plan 09-01b closed when:
1. All 21 `lib/` scaffold files exist with GOSL headers
2. Every scaffold body is `UnimplementedError` or an inert widget stub
3. `flutter analyze` + all gate tools green
4. Downstream plans 09-02 through 09-08 can reference any scaffold class name without a "file does not exist" error
5. No Freezed / Riverpod codegen triggered (Wave 2 + Wave 4 own those)
</success_criteria>

<output>
After completion, create `.planning/phases/09-fog-rendering/09-01b-SUMMARY.md`:
- File count (21 files across 4 layers)
- Any deviation from the plan (e.g., if `Uint8List` import had to be adjusted)
- Handoff: Wave 2 plans 09-02 and 09-03 can now open any file they edit with `@path/to/file.dart` and find a compiling scaffold.
</output>
</content>
</invoke>