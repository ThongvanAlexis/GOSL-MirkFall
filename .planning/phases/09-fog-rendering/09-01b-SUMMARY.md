---
phase: 09-fog-rendering
plan: 01b
subsystem: rendering
tags: [flutter, dart, mirk, fog-of-war, scaffold, riverpod, freezed]

# Dependency graph
requires:
  - phase: 07-map-integration
    provides: MirkRenderer port (frozen 3-method surface), MirkPaintContext (Freezed), AtmosphericConfig + ShaderConfig + UnknownConfig sealed variants, NoopMirkRenderer
provides:
  - Domain placeholder types MirkViewportBbox + VisibleMirkTile (plain classes; Wave 2 plan 09-02 rewrites as @freezed)
  - 4 concrete mirk renderer scaffolds (atmospheric / solid_fill / candlelight / heavenly_clouds) implementing MirkRenderer with UnimplementedError stubs
  - ShaderMirkRenderer scaffold (Phase 13 body — registers type for sealed exhaustiveness only)
  - MirkRendererFactory.create() scaffold — Wave 4 plan 09-05 supplies the sealed-switch
  - SimplexNoise2D({seed}) scaffold — Wave 2 supplies the Ken Perlin 2001 body
  - builtin_mirk_styles.dart placeholder — Wave 4 plan 09-05 fills with kBuiltinMirkStyles registry
  - 2 application controllers (RevealStreamingController, MirkStyleSessionController) — Wave 5 plan 09-06 fills bodies
  - 6 provider stubs (mirkRendererFactory / activeMirkRenderer / revealStreamingController / builtinMirkStyles / visibleMirkTiles / mapViewport) — Wave 4 plan 09-05 promotes to @riverpod targets
  - 3 widget scaffolds (MirkOverlay, MirkStylePickerSheet, MirkInitialRevealFade) — plan 09-07 fills bodies
affects: [09-02, 09-03, 09-04, 09-05, 09-06, 09-07, 09-08, 13-shader-fog]

# Tech tracking
tech-stack:
  added: []  # No new dependencies — pure scaffolding plan
  patterns:
    - "Wave 0 forward-declaration discipline: every downstream plan-target file exists as a compiling stub before any wave needs to reference it"
    - "UnimplementedError('Wave N — plan 09-NN') body marker for unimplemented scaffold methods, with TODO(NN-NN) comment for class-level open work"
    - "Provider scaffolding as plain Dart `void f() => throw UnimplementedError(...)` until @riverpod codegen lands in Wave 4"
    - "Empty placeholder file pattern: header + // TODO(...) comment only, when the type the file will export is itself a Wave-N type (avoids importing not-yet-existing symbols)"
    - "MAP-06 seam preserved at scaffold time: domain types use lat/lon doubles + dart:typed_data, no MapLibre imports"

key-files:
  created:
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
  modified: []

key-decisions:
  - "builtin_mirk_styles.dart kept as comment-only placeholder (no symbol exported in Wave 0) because BuiltinMirkStyleDescriptor is itself a Wave 4 type — exporting a stub of an unknown type would force premature design"
  - "Provider stubs declared as plain `void f() => throw UnimplementedError(...)` rather than dummy Riverpod `Provider`s — keeps Wave 4 free to choose the @riverpod annotation shape (KeepAlive vs scoped, AsyncNotifier vs Provider) without retrofit"
  - "AtmosphericMirkRenderer accepts AtmosphericConfig in constructor (Phase 03 type already exists), but SolidFillMirkRenderer / CandlelightMirkRenderer / HeavenlyCloudsMirkRenderer take no config arg — their *Config sealed variants don't exist until Wave 2 plan 09-02 extends MirkStyleConfig"
  - "VisibleMirkTile uses Uint8List (dart:typed_data, stdlib) — check_domain_purity green, no need to fall back to List<int>"
  - "Used // (line) comments instead of /// (doc) comments in builtin_mirk_styles.dart placeholder to dodge the analyzer's `dangling_library_doc_comments` info — files with no declarations cannot host /// without a `library` directive"

patterns-established:
  - "Wave 0 forward-declaration: every file Wave N+ will write to exists as a compiling, GOSL-headed stub at Wave 0 close — eliminates 'file does not exist' friction across the whole phase"
  - "Cross-wave deferral comments: every stub method body uses `throw UnimplementedError('Wave N — plan 09-NN')` and class-level work uses `TODO(09-NN)` so a casual grep `git grep 'Wave [0-9]'` enumerates the open scaffolding"
  - "Three parallel Wave 1 plans (09-01, 09-01b, 09-01c) consume nothing from each other — verified by 09-01b's lib-only flutter analyze staying green even when 09-01c's untracked test scaffolds carry their own analyzer issue"

requirements-completed: [MIRK-01, MIRK-04, MIRK-05, MIRK-06, MIRK-07]

# Metrics
duration: ~12min
completed: 2026-04-25
---

# Phase 09 Plan 01b: Wave 0 lib/ Scaffold (Part 2 of 3) Summary

**21 compiling lib/ placeholder files across domain / infrastructure / application / presentation — every Phase 09 downstream plan target now resolves at import-time without `dart analyze` complaining about missing symbols.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-25 (session start ~05:30 UTC)
- **Completed:** 2026-04-25 (session close ~05:50 UTC)
- **Tasks:** 3
- **Files created:** 21
- **Files modified:** 0

## Accomplishments

- Domain layer: MirkViewportBbox + VisibleMirkTile placeholder classes (Wave 2 will rewrite as @freezed; Uint8List on the latter is allowed by check_domain_purity since dart:typed_data is stdlib)
- Infrastructure layer: 4 concrete mirk renderers + 1 shader stub + factory skeleton + builtins-registry placeholder + simplex noise scaffold (8 files)
- Application layer: 2 controllers + 6 provider stubs (8 files)
- Presentation layer: 3 widget scaffolds, including the new MirkInitialRevealFade for the 500 ms session-open fade animation (3 files)
- Every file: GOSL v1.0 header, dart format clean (160-char width), zero analyzer issues lib-side, all Phase 07/08 CI gates remain green (check_headers, check_domain_purity, check_avoid_maplibre_leak)
- Zero Freezed / Riverpod codegen triggered — Wave 2 plan 09-02 owns the Freezed regeneration, Wave 4 plan 09-05 owns the Riverpod regeneration

## Task Commits

Each task was committed atomically:

1. **Task 1: Domain scaffolds — MirkViewportBbox + VisibleMirkTile** — `a3bf2bc` (feat)
2. **Task 2: Infrastructure mirk/ scaffolds — 4 renderers + shader stub + factory + registry + noise** — `68cfd54` (feat)
3. **Task 3: Application + presentation scaffolds — 2 controllers, 6 providers, 3 widgets** — `921d6ec` (feat)

**Plan metadata:** _filed via the closing commit on STATE / ROADMAP / REQUIREMENTS / SUMMARY (recorded below)._

## Files Created/Modified

### Domain (2 created)

- `lib/domain/mirk/mirk_viewport_bbox.dart` — MirkViewportBbox plain class with south/west/north/east doubles. Wave 2 plan 09-02 rewrites as @freezed.
- `lib/domain/mirk/visible_mirk_tile.dart` — VisibleMirkTile plain class with parentX/Y, Uint8List bitmap, tile-edge lat/lon. Wave 2 plan 09-02 rewrites as @freezed and folds into MirkPaintContext.visibleTiles.

### Infrastructure (8 created)

- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — AtmosphericMirkRenderer(AtmosphericConfig). 3 UnimplementedError stubs.
- `lib/infrastructure/mirk/solid_fill_mirk_renderer.dart` — SolidFillMirkRenderer(). No config arg until Wave 2 adds SolidConfig.
- `lib/infrastructure/mirk/candlelight_mirk_renderer.dart` — CandlelightMirkRenderer(). Same pattern as solid_fill.
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — HeavenlyCloudsMirkRenderer(). Same pattern as solid_fill.
- `lib/infrastructure/mirk/shader_mirk_renderer.dart` — ShaderMirkRenderer() stub for Phase 13. Throws `UnimplementedError('Phase 13 — ShaderConfig body')`.
- `lib/infrastructure/mirk/mirk_renderer_factory.dart` — `MirkRendererFactory.create(MirkStyleConfig)` skeleton, throws Wave 4 deferred.
- `lib/infrastructure/mirk/builtin_mirk_styles.dart` — Header + TODO(09-05) comment only. Wave 4 fills with kBuiltinMirkStyles.
- `lib/infrastructure/mirk/noise/simplex_noise_2d.dart` — `SimplexNoise2D({int seed = 0}).noise2(x, y)` stub.

### Application (8 created)

- `lib/application/controllers/reveal_streaming_controller.dart` — RevealStreamingController with onFix/flush/revealInitial/dispose stubs.
- `lib/application/controllers/mirk_style_session_controller.dart` — MirkStyleSessionController with select/dispose stubs.
- `lib/application/providers/mirk_renderer_factory_provider.dart` — provider stub.
- `lib/application/providers/active_mirk_renderer_provider.dart` — provider stub.
- `lib/application/providers/reveal_streaming_controller_provider.dart` — provider stub.
- `lib/application/providers/builtin_mirk_styles_provider.dart` — provider stub.
- `lib/application/providers/visible_mirk_tiles_provider.dart` — provider stub (plan 09-07 fills).
- `lib/application/providers/map_viewport_provider.dart` — provider stub (plan 09-07 fills).

### Presentation (3 created)

- `lib/presentation/widgets/mirk_overlay.dart` — MirkOverlay StatefulWidget returning SizedBox.shrink(). Plan 09-07 wires Ticker + CustomPainter.
- `lib/presentation/widgets/mirk_style_picker_sheet.dart` — MirkStylePickerSheet StatelessWidget returning SizedBox.shrink(). Plan 09-07 fills as bottom sheet.
- `lib/presentation/widgets/mirk_initial_reveal_fade.dart` — MirkInitialRevealFade StatefulWidget passing child through. Plan 09-07 Task 4 wires the 500 ms session-open fade.

## Decisions Made

See frontmatter `key-decisions`. Highlights:

- builtin_mirk_styles.dart is a comment-only placeholder. Exporting a stub of an unknown type (BuiltinMirkStyleDescriptor) would force a premature design choice; better to delay until Wave 4 owns it.
- Provider stubs are plain Dart functions, not pretend-Riverpod. Keeps Wave 4 free to pick the right @riverpod shape per provider.
- VisibleMirkTile uses Uint8List directly (dart:typed_data is stdlib, check_domain_purity allows it).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] `dangling_library_doc_comments` info on builtin_mirk_styles.dart**

- **Found during:** Task 2 verification (`dart analyze lib/infrastructure/mirk/`)
- **Issue:** The Wave 0 file has no Dart declarations — only a header + TODO. Using `///` (doc comments) on every line triggered 7 `dangling_library_doc_comments` infos because no declaration follows them and there's no `library` directive.
- **Fix:** Switched the post-header lines from `///` to `//` (regular line comments) — the documentation intent is identical, but the analyzer no longer flags them as orphan doc comments.
- **Files modified:** `lib/infrastructure/mirk/builtin_mirk_styles.dart`
- **Verification:** `dart analyze lib/infrastructure/mirk/` → No issues found. The plan's verify command passes.
- **Committed in:** `68cfd54` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — analyzer info chase).
**Impact on plan:** Cosmetic-only fix. The placeholder still carries the same human-readable explanation; only the comment marker changed.

## Issues Encountered

### Out-of-scope discovery: parallel-plan test files fail full `flutter analyze`

`flutter analyze --fatal-warnings --fatal-infos` (full project) reports 3+ errors in `test/infrastructure/mirk/{atmospheric,candlelight,solid_fill}_mirk_renderer_test.dart` (and likely `noise/simplex_noise_2d_test.dart`). These files are **untracked** at the time 09-01b commits — they belong to the parallel-running plan 09-01c and arrived in the working tree concurrent with 09-01b's task 3.

**Why not fixed in 09-01b:** Plan 09-01b's `<files_modified>` declaration covers only the 21 lib/ scaffolds; the test files are explicitly 09-01c's surface. Per GSD scope-boundary rules, I do NOT auto-fix issues in unrelated files. Logged in `.planning/phases/09-fog-rendering/deferred-items.md` (plan 09-01 already logged the same observation independently — confirms this is a Wave 1 cross-plan known item, not a 09-01b regression).

**Validation that 09-01b is clean:**
- `flutter analyze lib` → No issues found.
- `dart format --line-length 160 --set-exit-if-changed lib/{domain,infrastructure,application,presentation}/...` → 0 changed across 80 files.
- `dart run tool/check_headers.dart` → OK 341 files.
- `dart run tool/check_domain_purity.dart` → OK 59 files.
- `dart run tool/check_avoid_maplibre_leak.dart` → OK 170 files.

## User Setup Required

None — pure scaffolding plan, no external service / config / secret needed.

## Next Phase Readiness

- Wave 2 plans (09-02 Freezed extension, 09-03 reveal-mask + simplex body) can open any of the 21 scaffold files with `@path/to/file.dart` and find a compiling target. No "file does not exist" friction expected.
- Wave 3 plan 09-04 (renderer bodies) has all 5 renderer scaffolds + factory ready to flesh out.
- Wave 4 plan 09-05 (Riverpod codegen pass) has all 6 provider stubs + factory + registry + builtin-style descriptor type to author and codegen in one batched build_runner run.
- Wave 5 plan 09-06 (controllers) has both controller scaffolds (reveal-streaming + style-session) ready.
- Plan 09-07 (overlay + picker + fade widget) has all 3 widget scaffolds ready.
- Phase 13 has the ShaderMirkRenderer entry point preserved (factory will route ShaderConfig there).

## Self-Check: PASSED

All 21 scaffold files verified on disk:
- 2 domain files: FOUND
- 8 infrastructure files (incl. noise/): FOUND
- 8 application files (controllers + providers): FOUND
- 3 presentation widget files: FOUND

All 3 task commits present in `git log`:
- `a3bf2bc` (Task 1): FOUND
- `68cfd54` (Task 2): FOUND
- `921d6ec` (Task 3): FOUND

---
*Phase: 09-fog-rendering*
*Completed: 2026-04-25*
