# lib/infrastructure/mirk/

MirkFall's fog-of-war rendering layer. Implements [`MirkRenderer`](../../domain/mirk/mirk_renderer.dart) — domain interface frozen at Phase 07 with exactly **3 methods** (`paint`, `update`, `dispose`). Adding a 4th method breaks the contract test in `test/domain/mirk/mirk_renderer_contract_test.dart` by design (Rule 4 architectural decision).

## Layout (Phase 09 close, amended Phase 09.1)

```
lib/infrastructure/mirk/
├── README.md                           (this file)
├── atmospheric_mirk_renderer.dart      MIRK-04 default — noise-animated dark fog
├── solid_fill_mirk_renderer.dart       Minimalist seam proof (no animation, single colour)
├── candlelight_mirk_renderer.dart      Warm radial-glow + flicker
├── heavenly_clouds_mirk_renderer.dart  Airy NE-drifting clouds
├── shader_mirk_renderer.dart           Phase 13 target (UnimplementedError stub)
├── noop_mirk_renderer.dart             Phase 07 — test fixture, paints nothing
├── mirk_renderer_factory.dart          Sealed-switch dispatch MirkStyleConfig → MirkRenderer
├── builtin_mirk_styles.dart            kBuiltinMirkStyles registry constant (4 entries)
├── mirk_projection.dart                Lat/lon → screen pixel helper (interim overlay + test fixtures only since Phase 09.1)
├── fog_clip_geometry.dart              Pure clip geometry: `buildFogClipPath` (rect − discs) + `buildFogHoleOutlinePath` (Phase 09.1)
├── fog_edge_feather.dart               Shared edge feather for CPU-painted fog bodies (Phase 09.1-06)
└── noise/
    ├── simplex_noise_2d.dart           Hand-rolled Ken Perlin 2001 simplex (public-domain port)
    └── noise_texture.dart              Pre-rasterised tileable simplex tile (heavenly CPU fallback)
```

The naming asymmetry between `heavenly_clouds_mirk_renderer.dart` (filename) and the JSON discriminator `'heavenly'` (sealed-union shape) is intentional — file names use the long form for clarity, the JSON discriminator matches the user-facing UI label. See plan 09-02 SUMMARY revision N2.

## MIRK-05/06 seam doctrine

Adding a new mirk style — JSON-imported (Phase 13) OR new built-in — requires edits to **exactly four files**:

1. `lib/domain/mirk/mirk_style_config.dart` — new sealed variant. Compile-time-enforced exhaustiveness via Dart 3 `switch` on a `sealed class`.
2. `lib/infrastructure/mirk/<new>_mirk_renderer.dart` — NEW file, implementing `MirkRenderer`.
3. `lib/infrastructure/mirk/mirk_renderer_factory.dart` — one new case in the dispatch switch.
4. `lib/infrastructure/mirk/builtin_mirk_styles.dart` — one new registry entry (built-ins only; user-imported styles flow through the persistence layer instead).

Phase 13 adds a 5th path — JSON-authored user styles enter through `UnknownConfig` + a runtime parameter-bag renderer — without editing any of the above. The factory's `UnknownConfig` arm degrades gracefully to `AtmosphericMirkRenderer` with a logged warning (plan 09-05 Task 1 forward-compat fallback).

## Structural guards

| Gate | Asserts | Enforced by |
|------|---------|-------------|
| `tool/check_mirk_variant_file_count.dart` (CI) | Exactly 6 `*_mirk_renderer.dart` files (4 builtins + noop + shader stub) | `.github/workflows/ci.yml` "Check mirk variant file count" step |
| `test/domain/mirk/mirk_renderer_contract_test.dart` | `MirkRenderer` surface stays at exactly 3 public methods | `flutter test` |
| `test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart` | No two built-ins produce identical pixel output | `flutter test` (plan 09-04) |
| `test/presentation/screens/map_screen_fog_composition_test.dart` | The `FogLayer` is a child of the `FlutterMap` (no `RepaintBoundary` / `IgnorePointer` around it), gestures reach the map, an in-session renderer swap repaints, the fog Ticker never rebuilds Stack siblings | `flutter test` (plan 09.1-07) |
| `test/presentation/map_screen_viewport_filtering_test.dart` | Only viewport-intersecting parent tiles are queried | `flutter test` (plan 09-08) |
| `test/performance/fog_50k_tiles_perf_test.dart` (`@Tags(['mirk-perf'])`) | 50k-fixture paint pass stays within widget-test budget | `flutter test --tags mirk-perf` (plan 09-08) |
| `tool/check_mirk_fixture_fresh.dart` (CI) | Committed `fifty_k_tiles_seed.sql.gz` matches the deterministic builder output | `.github/workflows/ci.yml` "Check mirk fixture fresh" step |

## Rendering strategy

Phase 09.1 (`09.1-RESEARCH.md`, port-back of the `mirk-poc-debug` POC): the mirk is painted by a **Flutter `CustomPainter` mounted as a child of the `FlutterMap`** (`FlutterMapMapViewWidget.fogLayers`, between the vector tile layer and the user puck), on the SAME canvas and in the SAME frame as the tiles, from ONE `MapCamera` snapshot per build (FOG-07). The Phase 09 shape — a screen-space overlay above a native platform view, one frame behind the camera — was BUG-014; it is gone. The `FogLayer` owns the single reveal clip per frame and hands the renderers a typed `MirkPaintContext` (projection closures, world-pixel origin, zoom scale); the renderers never see a `MapCamera`. See `lib/infrastructure/map/style_layer_order.dart` for the tile layer-order contract.

## References

- `.planning/phases/09-fog-rendering/` — full Phase 09 rationale (CONTEXT, RESEARCH, plan series 09-01 → 09-08).
- `09-RESEARCH §Noise Function Choice` — hand-rolled simplex chosen over `fast_noise` / `open_simplex_noise`; zero new dep.
- `09-RESEARCH §Registration Pattern Choice` — registry + factory + sealed exhaustiveness.
- `.planning/phases/09.1-port-back-same-canvas-fog-flutter-map-migration/` — same-canvas port-back (CONTEXT, RESEARCH, plans 09.1-01 → 09.1-08): why the fog is a `FlutterMap` child, the `MirkPaintContext` seam, the FOG-07 keystone.
