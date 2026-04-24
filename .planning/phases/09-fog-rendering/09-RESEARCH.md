# Phase 09: Fog Rendering - Research

**Researched:** 2026-04-24
**Domain:** 2D real-time fog-of-war rendering over MapLibre + streaming reveal pipeline backed by Drift
**Confidence:** HIGH (rendering strategy, algorithm, registration) / MEDIUM (noise function specifics, shader portability) / LOW (frame-budget numbers on real Android mid-range before measurement)

## Summary

Phase 09 delivers the product's visual identity — a living, non-distracting black fog that dissipates around the user in real time — while proving the `MirkRenderer` seam (3 frozen methods) supports 4 heterogeneous variants and while extending the reveal streaming pipeline end-to-end (GPS fix → 64×64 bitmap merge → paint). The research closes the 14 Claude's-Discretion gaps from CONTEXT.md and frames the remaining risk surface.

**Primary recommendation:** Ship **Flutter-level `CustomPainter` overlay wrapped in `RepaintBoundary`, positioned above the `MapView` widget** (NOT a MapLibre `fill`-with-client-tuiled-GeoJSON layer). Use hand-rolled procedural noise at the start (zero new dep, tunable, deterministic), keeping FragmentShader as an optimization target for the `shader` variant already declared in the sealed union (Phase 13 authored). Use **`mask bitmap non-binaire post-blur`** for feather (binary DB bitmap + per-frame Gaussian-blur on a scratch mask keeps MIRK-03 monotone-OR invariant while delivering feather). Implement `computeRevealMask` via **bbox-first + per-cell geometric intersect** against the 25 m circle. Register the 4 built-ins via a **constant registry list + factory provider**, making "ajouter un style = 1 fichier, 0 core mod" structurally enforced. Fixture 50 k tiles as **deterministic Dart builder** producing a `.sql` file checked into `test/fixtures/mirk/`.

**Why overlay beats MapLibre layer:** the `maplibre_gl 0.25.0` Dart API surface does not expose per-frame source updates at the 60 Hz cadence we need for subtle noise drift without a full `setStyle` round-trip; pushing a GeoJSON source update from Dart is O(source_rebuild) on every viewport move, and the `kStyleLayerOrder` contract would have to flex (layer type change from `background` → `fill` requires a matching source in `sources`, currently none). A Flutter overlay sidesteps both constraints, aligns with Phase 11 marker composite-trick (MapLibre annotation manager paints marker symbols at native alpha < 1.0 *underneath* the Flutter `RepaintBoundary` that carries the fog), and keeps the `mirk_fog` layer in `style.json` as a 0-opacity sentinel (zero change to `kStyleLayerOrder`).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Identité visuelle du style atmospheric (défaut)**
- Feel : "brouillard mouvant noir" (verbatim user) — plus générique que la référence RTS Warcraft 3, moins médiéval. Cohérent avec un futur style parchemin V2 mais ne le suppose pas.
- Palette : noir / gris profond monochrome. Maximum contraste avec la carte révélée, neutre sur basemap Protomaps, portable sur parchemin V2.
- Densité : dense mais variable via noise fn au-dessus d'un baseline opaque. Le noise module l'alpha autour du baseline pour "nuage varié" sans jamais laisser passer complètement la carte.
- **Baseline alpha : 99% configurable** via `kDefaultMirkBaselineAlpha` dans `lib/config/constants.dart`. Le user ajustera en dev — 1 % de basemap transparaît, ce qui facilite le composite-trick Phase 11 (markers à 30 % alpha sous mirk).
- Animation : drift lent subtil — période ~10–20 s, mouvement d'une noise fn simplex/perlin. Vivant sans être distrayant. Pas de swirling marqué, pas de statique.

**Géométrie du reveal**
- **Rayon par défaut : 25 m**, stocké dans `kDefaultRevealRadiusMeters` (`lib/config/constants.dart`). Cohérent avec `kInitialRevealRadiusMeters = 20` déjà existant (Phase 07) — les deux constantes restent distinctes volontairement (initial 20 m session-open + ongoing 25 m par fix).
- Bord : **feather** (dégradé doux) — 100 % opaque → 0 % sur ~10 % du rayon (≈ 2,5 m à 25 m). Le stockage bitmap reste binaire (MIRK-03 monotone OR intact), le feather est une propriété de rendu.
- **Cells flip : toutes les cellules 64×64 touchées par le cercle 25 m sont flippées à 1** (intersection géométrique, pas centre-inside). Zone révélée légèrement plus large qu'exactement 25 m (~1 m de marge par demi-cellule). Évite les micro-trous sur traces zigzag.
- **Cadence flush DB : 2 s ou 20 fixes** (premier déclencheur). Configurable via `kRevealFlushIntervalSeconds` et `kRevealFlushMaxFixes` dans `lib/config/constants.dart`.
- Animation apparition reveal initial 20 m : fade-in doux sur ~500 ms à session-open.

**Variants built-in**
- **4 variants** ship en Phase 09 : `atmospheric` (défaut) + `solid` + `candlelight` + `heavenly_clouds`.
- **Chaque variant = une classe renderer distincte** dans `lib/infrastructure/mirk/` (pas juste des instances à params différents). Prouve SC#2 trois fois.
- Pas de fallback perf auto — si atmospheric ne tient pas 16 ms, on corrige, on ne switch pas.
- Sélection utilisateur : burger menu "Changer le style" (stub ListTile Phase 07) activé avec les 4 builtins. Persistence via `t_sessions.mirk_style_id` existant.

**Under-mirk visibility + initial reveal**
- Baseline alpha 99 % → basemap toujours très légèrement devinable. Cohérent design markers alpha 30 % sous mirk Phase 11.
- **Phase 11 markers composite-trick : préférer ajouter un nouveau layer marker au-dessus de `mirk_fog` (append, pas reorder) dans `kStyleLayerOrder`.**
- **Initial reveal 20 m au session start** : écrit en DB dès que la session démarre (`ActiveSessionController.startSession()` → write bitmap 20 m autour de la dernière position connue). Fallback : si aucune position disponible, attendre le premier fix et écrire le 20 m autour de lui.
- **`computeRevealMask` finalisée** Phase 09 (body change sur signature frozen Phase 03) — tant pour le 20 m initial que pour les 25 m streaming.

**Architecture import/export mirk styles (anticipation Phase 13)**
- Scope import utilisateur : parameter-based + shader GLSL.
- Paramètres exposés sur atmospheric (Freezed-extensible d'entrée de jeu Phase 09) : `baseColorArgb`, `secondaryColorArgb`, `noiseScale`, `noiseSpeed`, `driftDirectionDeg`, `densityBaselineAlpha`, `featherRadiusFraction`, `edgeSoftness`.
- Les 4 variants built-in n'utilisent qu'un sous-ensemble, mais le Freezed est conçu d'emblée pour tous. Ajouter un param Phase 13+ = `@Default` sur le Freezed, zéro breaking change.
- Validation : strict à l'import Phase 13 + `UnknownConfig` runtime fallback (déjà en place Phase 03) = deux couches de défense.
- **Sealed union cible : 6 variants** `{atmospheric, solid, candlelight, heavenly, shader, unknown}`.
- `shader` variant reste déclaré mais renderer non implémenté (stub `NoopMirkRenderer`-like jusqu'à Phase 13). Phase 09 prouve juste que le seam supporte son existence.

**Performance + viewport filtering**
- **Viewport filtering (SC#5)** : seuls les parent-tiles (z=14) intersectant la viewport courante `MapView` sont peints. `MirkPaintContext` étendu Phase 09 pour porter : viewport bbox + current fix + frame time.
- **RepaintBoundary isolation (SC#4)** : widget porteur du `CustomPainter` entouré d'un `RepaintBoundary`. Autres layers ne rebuild pas quand la noise fn tick. DevTools valide.
- Fixture 50 k sub-tiles : test dédié qui charge DB de test avec 50 k rows `t_revealed_tiles`. Pass = 16 ms max sur emulator milieu de gamme.
- Pas d'auto-fallback perf.

### Claude's Discretion

(The sections below — §Rendering Strategy Decision through §Validation Architecture — are written against these discretion areas. Each Claude's-Discretion item from CONTEXT.md maps to a section in this document.)

- Stratégie de rendu : MapLibre layer vs Flutter overlay → **§Rendering Strategy Decision**
- Feather edge implementation → **§Feather Edge Approach**
- Noise fn exacte → **§Noise Function Choice**
- Paramètres visuels candlelight + heavenly + solid → **§Built-in Variant Specifications**
- Algorithme `computeRevealMask` → **§computeRevealMask Algorithm Specification**
- Format fixture 50 k-tiles → **§Fixture 50k Strategy + Format**
- Naming renderer classes → **§Registration Pattern Choice**
- Registration pattern des 4 builtins → **§Registration Pattern Choice**
- FragmentShader vs CustomPainter → **§Rendering Strategy Decision** + **§FragmentShader Portability**
- Stratégie changement `session.mirk_style_id` in-session → **§In-Session Style Swap Lifecycle**
- Signature extended `MirkPaintContext` → **§MirkPaintContext Extension Spec**
- Copy UI burger menu ListTile → **§In-Session Style Swap Lifecycle** (UI subsection)
- Test strategy pour 50 k tiles → **§Validation Architecture**

### Deferred Ideas (OUT OF SCOPE Phase 09)

**Reportées en Phase 13 (Import/Export + Styles UI)**
- Sélecteur de style dans l'écran options global (OPT-03)
- Gestion des styles de mirk importés (OPT-04, MIRK-09)
- Import d'un style JSON utilisateur (MIRK-08, PORT-08)
- Renderer GLSL shader complet (`MirkStyleConfig.shader` non implémenté Phase 09)
- Slider UI rayon de révélation (OPT-02) — Phase 09 a la constante, Phase 13 a l'UI

**Reportées en Phase 11 (Markers)**
- Markers visibles sous mirk en transparence 30 % (MARK-07) — architecture Phase 09 anticipe, Phase 11 livre

**Reportées en Phase 15 (Polish) ou plus tard**
- Tap-to-reveal manuel d'urgence
- Ripple / ondulation expansive à l'apparition du reveal
- Auto-bascule sur solid si frame budget dépasse 16 ms — rejeté

**V2 Backlog**
- Style parchemin RPG V2 (basemap, pas style mirk)

**Hors scope global / jamais**
- UI settings pour cadence flush DB — constants.dart uniquement
- Multi-language — V1.x I18N
- Achievements / gamification / stats — V2
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MIRK-01 | Rayon de révélation circulaire effacé autour position actuelle au fil du déplacement | §computeRevealMask Algorithm Specification + §Reveal Streaming Controller |
| MIRK-02 | Rayon configurable (défaut 25-50 m) dans options globales (UI en Phase 13, constante en Phase 09) | §User Constraints — `kDefaultRevealRadiusMeters = 25` in constants.dart ; UI slider OPT-02 is Phase 13 (deferred) |
| MIRK-04 | Mirk vivant / atmosphérique (nuageux, mouvant, animé) — pas aplat noir | §Rendering Strategy Decision + §Noise Function Choice + §Built-in Variant Specifications (atmospheric) |
| MIRK-05 | Architecture MirkRenderer : ajouter un style = nouveau fichier, zéro modification cœur | §Registration Pattern Choice — registry constant + factory provider structurally prevents core edits |
| MIRK-06 | 4 styles built-in (atmospheric défaut + solid + candlelight + heavenly_clouds), chacun classe renderer distincte | §Built-in Variant Specifications — concrete param lists + filenames + Freezed config extensions |
| MIRK-07 | Sélecteur burger menu in-session → choix style actif pour session courante, changement immédiat | §In-Session Style Swap Lifecycle |
</phase_requirements>

## Standard Stack

### Core (no new runtime deps)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter `CustomPainter` + `RepaintBoundary` | SDK | Per-frame paint of fog overlay, isolated repaint | Native Flutter primitive for pixel-level 2D rendering; `RepaintBoundary` is the canonical way to enforce dirty-region isolation (SC#4). Zero dep cost. |
| `dart:ui` `Canvas` / `Paint` / `Picture` | SDK | Drawing primitives (fillPath, drawRect, drawRSuperellipse) | Already imported by `lib/domain/mirk/mirk_renderer.dart` — no additional surface needed. |
| `dart:ui` `FragmentShader` / `FragmentProgram` | SDK (Flutter 3.10+) | GLSL-backed shader for future `ShaderConfig` variant + optional noise uniform sampling | Supported on Android / iOS / Windows / macOS / Linux with Impeller (default since Flutter 3.10). Declared via `pubspec.yaml` `flutter.shaders:` entry. Zero dep. |
| `Ticker` (from `flutter/scheduler.dart`) | SDK | Drives the `update(Duration)` → setState invalidation loop at vsync | Native Flutter animation clock; integrates with `SchedulerBinding` so `update()` is called in sync with paint pass. |
| `riverpod_annotation` | 4.0.2 (pinned) | `@Riverpod(keepAlive: true)` provider for registry + active renderer + reveal streaming controller | Already in stack; no change. |
| `freezed_annotation` | 3.1.0 (pinned) | Extend `MirkPaintContext` + `MirkStyleConfig` sealed union with 3 new variants | Already in stack. Compile-time friction on contract change is load-bearing. |

### Supporting (dev-only, no runtime ship)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `drift` + `drift_dev` | 2.32.1 (pinned) | DB for `t_revealed_tiles` reads / writes during reveal streaming | Already in stack. `mergeMask` is ready — Phase 09 consumes in-state. |
| `shelf` | 1.4.2 (pinned dev) | Only if integration tests need to mock tile fetch — unlikely for Phase 09 | Already promoted direct dev in Phase 07. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff | Decision |
|------------|-----------|----------|----------|
| `CustomPainter` overlay | MapLibre `fill` layer with client-tuiled GeoJSON | MapLibre-native, would render at z-index per `kStyleLayerOrder`. But per-frame animation requires re-pushing the `fill` source from Dart, which `maplibre_gl 0.25.0` does via full `setStyle` (slow path) — profiled in Phase 07 as ~250 ms. Kills 16 ms budget. Also forces the sealed `mirk_fog` layer from `background` → `fill` requiring a new `sources[mirkfall_mirk]` entry, which touches the frozen style.json structure. | **Rejected.** |
| Hand-rolled noise (pure Dart) | `fast_noise` 2.0.0 (Apache-2.0) | Proven port of Jordan Peck's fast noise (simplex/perlin/cellular). `fixnum ^1.1.0` transitive. Published ~2 years ago — stale but functional. Adds dep audit burden (DEPENDENCIES.md row + telemetry confirm). | **Preferred: hand-rolled.** Rationale: the noise surface MirkFall needs is 2D simplex + time drift, ~60 lines of pure-Dart code, patent-free algorithm (Ken Perlin's 2001 simplex). Keeping it in-repo ⇒ zero audit burden, deterministic seed (for tests), trivially tuneable per variant. `fast_noise` inclusion is a fallback if hand-roll underperforms — reassess at Phase 09 mid-implementation. |
| Hand-rolled noise | `open_simplex_noise` 2.3.1 (BSD-3-Clause) | Kurt Spencer's patent-free alternative, pure Dart, BSD-3 compatible. Published ~4 years ago — stale. | Same verdict as `fast_noise`; hand-roll is preferred. `open_simplex_noise` is the most license-compatible fallback if hand-roll fails. |
| In-Dart FragmentShader noise (atmospheric) | Same but via GLSL `.frag` asset | Moves noise math to GPU, frees the CPU-side `update()` pass. But requires one `.frag` asset per variant, widens the test seam (mock FragmentProgram + real paint invocation), and raises platform-portability questions (Impeller + GLES Y-flip, etc.). | **Deferred.** Phase 09 atmospheric ships CPU-side noise sampled into `Paint.color`/`Paint.shader` via `ImageShader`. FragmentShader is reserved for Phase 13's real `ShaderConfig` renderer. |

**No installation required.** Zero new runtime dependencies.

**Optional installation (only if hand-roll fails profiling):**
```bash
# Fallback — not default
flutter pub add fast_noise:2.0.0
```
→ then add DEPENDENCIES.md row with Apache-2.0 license + `fixnum` transitive + telemetry audit (pure Dart, no network). Trigger: only if per-variant profiling shows hand-rolled 2D simplex exceeds ~0.5 ms per frame budget for noise evaluation across 50 k tiles.

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── config/
│   └── constants.dart        # + Phase 09 constants (see CONTEXT.md list)
├── domain/
│   ├── mirk/
│   │   ├── mirk_renderer.dart          # FROZEN — no edits
│   │   ├── mirk_paint_context.dart     # EXTENDED — viewport bbox + fix + frame time
│   │   ├── mirk_style.dart             # unchanged
│   │   ├── mirk_style_config.dart      # EXTENDED — 3 new variants
│   │   └── mirk_style_store.dart       # unchanged
│   └── revealed/
│       ├── reveal_calculator.dart      # computeRevealMask body implemented
│       ├── revealed_tile.dart          # unchanged
│       └── revealed_tile_store.dart    # unchanged
├── infrastructure/
│   ├── mirk/
│   │   ├── noop_mirk_renderer.dart               # kept (test fixture)
│   │   ├── atmospheric_mirk_renderer.dart        # NEW — default, noise-animated black fog
│   │   ├── solid_fill_mirk_renderer.dart         # NEW — minimalist proof-of-seam
│   │   ├── candlelight_mirk_renderer.dart        # NEW — warm orange fog + radial glow
│   │   ├── heavenly_clouds_mirk_renderer.dart    # NEW — light drifting clouds
│   │   ├── shader_mirk_renderer.dart             # NEW stub — throws UnimplementedError, satisfies seam for sealed variant existence
│   │   ├── mirk_renderer_factory.dart            # NEW — MirkStyleConfig → MirkRenderer
│   │   ├── builtin_mirk_styles.dart              # NEW — registry constant of 4 builtins
│   │   └── noise/
│   │       └── simplex_noise_2d.dart             # NEW — hand-rolled 2D simplex, pure Dart
├── application/
│   ├── controllers/
│   │   ├── active_session_controller.dart        # EXTENDED — startSession() triggers initial 20m reveal
│   │   ├── reveal_streaming_controller.dart      # NEW — buffers fixes + flush batch DB
│   │   └── mirk_style_session_controller.dart    # NEW — writes session.mirk_style_id + notifies swap
│   └── providers/
│       ├── mirk_renderer_factory_provider.dart   # NEW
│       ├── active_mirk_renderer_provider.dart    # NEW (keepAlive) — resolves MirkRenderer of active session
│       ├── reveal_streaming_controller_provider.dart  # NEW
│       └── builtin_mirk_styles_provider.dart     # NEW
└── presentation/
    ├── screens/
    │   └── map_screen.dart                        # EXTENDED — MirkOverlay under RepaintBoundary
    └── widgets/
        ├── session_burger_menu.dart               # EXTENDED — "Changer le style" live
        ├── mirk_style_picker_sheet.dart           # NEW — bottom-sheet with 4 builtins
        └── mirk_overlay.dart                      # NEW — CustomPainter + RepaintBoundary host
```

### Pattern 1: RepaintBoundary-Isolated Overlay Above MapView

**What:** The Flutter widget tree places the fog overlay as a **sibling** of `MapLibreMapViewWidget`, inside a `Stack`, wrapped in a `RepaintBoundary`. The overlay renders its own `CustomPainter` which ticks via a `Ticker`. This is the Flutter-idiomatic way to isolate repaints from the underlying native platform view.

**When to use:** Always. This is the recommended rendering strategy (§Rendering Strategy Decision).

**Example:**
```dart
// Source: Flutter docs (https://docs.flutter.dev/ui/performance/rendering-performance)
// + widget-layout pattern already in map_screen.dart
Stack(
  children: [
    MapLibreMapViewWidget(styleRewriter: ..., onReady: ...),  // Phase 07
    RepaintBoundary(
      child: MirkOverlay(renderer: activeRenderer, ctx: paintContext),
    ),
    // Phase 11 marker layer sits ABOVE the RepaintBoundary.
    // MapLibre's built-in annotation manager paints markers as part of the
    // MapLibreMap widget layer — but the VISIBLE marker layer (Phase 11)
    // lives here, on top of the fog, at alpha 1.0 inside its own widget.
    // The "30% alpha under mirk" effect is delivered by Phase 11 via a
    // SECOND, fainter marker rendering wired to ui.BlendMode.srcOver
    // underneath the mirk (i.e. rendered by MapLibre's native annotations).
  ],
)
```

### Pattern 2: Ticker-Driven `update(Duration)` → `setState` Loop

**What:** The `MirkOverlay` widget owns a `Ticker` (via `SingleTickerProviderStateMixin`) that fires every vsync. On each tick it calls `renderer.update(elapsed)` and then invalidates via `setState`, which triggers `CustomPainter.paint()` → calls `renderer.paint(canvas, size, ctx)`.

**When to use:** For every animated variant (atmospheric + candlelight + heavenly_clouds). The `solid` variant can have a no-op `update` and only invalidates when viewport/reveal changes (explicit trigger).

**Example:**
```dart
// Source: Flutter Ticker pattern, docs.flutter.dev
class _MirkOverlayState extends State<MirkOverlay> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    widget.renderer.update(delta);
    setState(() {});  // triggers CustomPainter.paint in next frame
  }

  @override
  void dispose() { _ticker.dispose(); super.dispose(); }
  // ...
}
```

### Pattern 3: Viewport-Culled Tile Iteration

**What:** Before iterating over every `RevealedTile` in the DB, compute the set of `(parentX, parentY)` at zoom-14 that overlap the current viewport. Only the overlapping tiles are fetched from the store (in-memory cache of current session's tiles) and painted. At zoom 14 a typical phone viewport (~500×1000 px at pixelRatio 3) spans **≤ 4 parent tiles** on axis → ≤16 parent tiles on screen at once. At zoom 17 (aggressive zoom), ≤1 parent tile. The 50k fixture exercises the worst case (large session in dense area, many parent tiles but most outside viewport).

**When to use:** Every `paint()` call.

**Example:**
```dart
// Source: MapLibre Web Mercator tile math (OSM slippy-map convention)
// + lib/domain/revealed/tile_math.dart (existing Phase 03 implementation)
Iterable<({int x, int y})> visibleParentTilesAtZ14(LatLngBounds viewportBbox) sync* {
  final nw = TileMath.latLonToTile(lat: viewportBbox.north, lon: viewportBbox.west, zoom: 14);
  final se = TileMath.latLonToTile(lat: viewportBbox.south, lon: viewportBbox.east, zoom: 14);
  for (int y = nw.y; y <= se.y; y++) {
    for (int x = nw.x; x <= se.x; x++) {
      yield (x: x, y: y);
    }
  }
}
```

### Anti-Patterns to Avoid

- **Don't push per-frame source updates to MapLibre.** `setStyle` is ~250 ms; fill-layer source updates via `MapLibreMapController.setGeoJsonSource` are faster but still not 60 Hz-compatible and mutate state outside Dart's repaint scheduling.
- **Don't rebuild `CustomPainter` on every frame.** Construct the `MirkPainter(renderer: ..., ctx: ...)` at widget build time; within `paint()` do not allocate. Reuse `Paint` objects. Allocating a single `Paint` per frame at 60 fps ⇒ 60 allocations/s, within GC budget; allocating per-tile ⇒ 50k allocations/frame, guaranteed jank.
- **Don't write to the DB inside the render hot path.** `RevealStreamingController` batches fix arrivals in-memory and flushes async every 2 s / 20 fixes; the paint pass reads an in-memory `Uint8List` mirror of the current session's tiles (watched via Riverpod stream).
- **Don't store feather / noise state in the bitmap.** Bitmap is binary, canonical, MIRK-03 monotone. Feather + noise are render-time transformations.
- **Don't assume `mirk_style_id` nullability handling trickles up.** A session without `mirk_style_id` (fresh install, or deleted style) falls back to atmospheric (the default), NOT `UnknownConfig`. `UnknownConfig` is reserved for JSON-authored styles with unrecognized `rendererType`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Slippy-map tile math | Custom Mercator projection | `TileMath.latLonToTile` (Phase 03) | Already tested, handles polar clamp + floor-rounding defensively. `parentZoom` = 14 is a constant. |
| Bitmap OR merge | Manual byte-wise OR | `mergeBitmap` in `reveal_calculator.dart` | Shipped Phase 03 with commutativity + monotonicity tests. |
| Popcount | SWAR by hand (easy to mis-implement) | `popcount` in `reveal_calculator.dart` | Shipped. |
| Drift row reads | Raw SQL | `RevealedTileStore.listBySession` / `findByParent` | Shipped, transactional. |
| Viewport bbox from MapLibre | Parse LatLngBounds from controller manually | `MapView.viewportUpdates` stream (Phase 07) → feed into `MirkPaintContext.viewportBbox` | Already exposed as domain-port surface in `lib/domain/map/map_view.dart`. Phase 09 reads from it. |
| Ticker / frame loop | `Timer.periodic(16 ms)` | Flutter `Ticker` via `SingleTickerProviderStateMixin` | `Ticker` syncs with vsync; `Timer.periodic` does not and can tear. |
| GLSL shader compile | Manual asset pipeline | `rootBundle.load('<asset.frag>')` + `ui.FragmentProgram.fromAsset(...)` | Flutter builds and ships `.frag` through its own build pipeline. |
| Session-scoped in-memory bitmap cache | Map<parentKey, Uint8List> with manual invalidation | Riverpod `@Riverpod(keepAlive: true)` provider watching `RevealedTileStore.watchSession(id)` | Standard pattern — invalidation on session change is Riverpod's job. |

**Key insight:** `reveal_calculator.dart` + `tile_math.dart` + `revealed_tile_store.dart` are Phase 03 / 06 investments. Phase 09 implements only the *missing* body (`computeRevealMask`) and the rendering / streaming layers. The algebra is untouched.

## Common Pitfalls

### Pitfall 1: `setState` storms from noise ticker rebuilding the whole MapScreen

**What goes wrong:** Putting `Ticker` in `_MapScreenState` instead of `_MirkOverlayState` means every tick rebuilds the entire screen including the `MapLibreMapViewWidget`, collapsing the `RepaintBoundary` isolation.

**Why it happens:** Convenience — the tick source is often added at the outermost widget.

**How to avoid:** Isolate the `Ticker` inside `_MirkOverlayState`. The `setState` call only invalidates the overlay subtree. DevTools "Highlight Repaints" confirms.

**Warning signs:** In DevTools, the attribution bar or follow-me FAB also flashes on every frame.

### Pitfall 2: Losing `RepaintBoundary` isolation by positioning overlay as child of MapLibre widget

**What goes wrong:** If `MirkOverlay` is a child of `MapLibreMapViewWidget` (inside its Stack), the platform view's own dirty region encompasses the overlay and it still triggers native redraws.

**Why it happens:** `MapLibreMapViewWidget` uses a platform view for the map surface; platform views have their own compositing semantics.

**How to avoid:** Keep `MapLibreMapViewWidget` and the `RepaintBoundary`-wrapped `MirkOverlay` as **siblings** in a `Stack`, not parent-child. Overlay sits on top, not inside.

**Warning signs:** Frame time > 16 ms even with a no-op `solid` variant on a modern phone.

### Pitfall 3: `computeRevealMask` edge-cell off-by-one near parent-tile boundary

**What goes wrong:** When a 25 m reveal circle straddles two parent tiles, the geometric intersection check must be run TWICE (once per parent tile, each restricted to its own 64×64 grid). A single-pass implementation that computes the mask only for the "home" parent tile leaves a diagonal seam at the boundary.

**Why it happens:** The natural first implementation computes the parent tile from `(centerLat, centerLon)` and restricts the mask to that tile. A reveal circle of 25 m at a parent-tile boundary spans both tiles.

**How to avoid:** `computeRevealMask` body iterates over *all* parent tiles intersected by the bounding box of the 25 m circle (typically 1, rarely 2, never more than 4 in worst-case pole cases). Returns a `Map<TilePosition, Uint8List>` not a single bitmap. See §computeRevealMask Algorithm Specification.

**Warning signs:** Tests with a fix near a tile boundary show a visible "row of lit cells" gap.

### Pitfall 4: Accumulating time-drift in `sessionElapsed`

**What goes wrong:** If `MirkPaintContext.sessionElapsed` is computed by summing `update(Duration elapsed)` deltas, micro-drift over hours → animation "slows down" visibly.

**Why it happens:** Each `elapsed` is a `Duration` derived from `Ticker`'s monotonic clock but the sum across millions of `+=` invocations accumulates float-to-int conversion error.

**How to avoid:** Keep `sessionElapsed` derived from `_startedAtTicker - _currentTicker` — NEVER accumulate. `Ticker` emits absolute elapsed time from start, not delta. Delta is a convenience for `update()` callers that need frame-rate-independent integration (e.g. drift direction).

**Warning signs:** Variable noise speed over long sessions.

### Pitfall 5: Bitmap feather stored in DB → MIRK-03 monotone invariant broken

**What goes wrong:** Storing 8-bit per-pixel alpha mask (256 values) in `bitmap` field instead of 1-bit presence → MIRK-03 monotonicity "once a bit is 1 it never returns to 0" is broken because blur operations produce floating intermediates that on merge can be *less* than the previous value.

**Why it happens:** Someone confuses "feather edge rendering" with "soft bitmap storage".

**How to avoid:** Bitmap remains binary (512 bytes, 4096 bits, kRevealedTileBitmapBytes). Feather is a render-time transform — see §Feather Edge Approach.

**Warning signs:** Phase 03 tests on `mergeBitmap` start failing.

### Pitfall 6: Frame pump on integration test timing races

**What goes wrong:** Widget tests that use `pumpAndSettle` lock forever because the Ticker never settles.

**Why it happens:** `pumpAndSettle` waits for all pending animations to finish; a `Ticker` running indefinitely is a pending animation.

**How to avoid:** Inject a `TickerProvider` stub in tests (or use `tester.pump(Duration(...))` bounded). Existing precedent: `session_burger_menu.dart` `_ChronoRow` tests in Phase 07 use bounded `pump(Duration)` for the same reason.

**Warning signs:** Tests time out in CI.

### Pitfall 7: `MapView.viewportUpdates` back-pressure

**What goes wrong:** Using `viewportUpdates` stream directly to drive every paint is wrong — the paint pass should sample the latest viewport, not react to every single camera event (pan gestures fire at 60-120 Hz).

**Why it happens:** Reactive programming default.

**How to avoid:** `MirkPaintContext.viewportBbox` is pulled from a `ValueNotifier<LatLngBounds>` (debounced 50 ms or read lazily at each `paint()` entry via `ref.read`). Viewport-update stream is consumed by `mirk_style_session_controller` for the bbox cache, not by the paint pass.

**Warning signs:** Dropped frames while panning.

### Pitfall 8: Phase 11 marker composite-trick architecturally blocked by Phase 09 choice

**What goes wrong:** If Phase 09 renders fog as a MapLibre `fill` layer, Phase 11 markers must go into another MapLibre layer; MapLibre painters lay out in `kStyleLayerOrder`. The "30% alpha under mirk" trick needs a marker layer *below* `mirk_fog` AND a normal marker layer *above*. Two `markers_*` entries → two positions in `kStyleLayerOrder` → the "frozen order" contract is violated.

**How to avoid:** Keeping fog as Flutter overlay (Phase 09 decision) means Phase 11 has two paths:
1. **Native MapLibre annotation** (under mirk) — these paint at their own alpha (30 %), attached to MapLibre's `addCircle`/`addSymbol` annotation manager, not a `kStyleLayerOrder` layer. Already used for user-location (see `style_layer_order.dart` comment).
2. **Flutter overlay** (above mirk) — markers rendered by a `CustomPainter` above the `RepaintBoundary`, at full alpha.
The only `kStyleLayerOrder` change Phase 11 might need is **append** (new layer ID at end, e.g. `markers_highlighted`). No reorder. **Confirm in planning:** Phase 09 adds a docstring comment to `style_layer_order.dart` locking this architecture.

**Warning signs:** Phase 11 planning discussions about reordering layers.

## Code Examples

Verified patterns (ready to adapt for planning):

### Example 1: `MirkPaintContext` Freezed extension

```dart
// Source: current lib/domain/mirk/mirk_paint_context.dart (Phase 07) + Freezed 3.x docs
@freezed
abstract class MirkPaintContext with _$MirkPaintContext {
  @Assert('zoomLevel >= 0.0', 'MirkPaintContext.zoomLevel must be >= 0')
  @Assert('pixelRatio > 0.0', 'MirkPaintContext.pixelRatio must be > 0')
  factory MirkPaintContext({
    required double zoomLevel,
    required double pixelRatio,
    required Duration sessionElapsed,
    // Phase 09 additions:
    required MirkViewportBbox viewportBbox,
    required Duration frameElapsed,  // absolute elapsed since session start (drives animation time)
    Fix? currentFix,                  // last accepted GPS fix — nullable pre-first-fix
  }) = _MirkPaintContext;
}

/// Freezed view of a lat/lon bbox decoupled from MapLibre types.
///
/// Represented as four doubles — NOT `LatLngBounds` — so `MirkPaintContext`
/// stays MapLibre-type-free per MAP-06 seam discipline.
@freezed
abstract class MirkViewportBbox with _$MirkViewportBbox {
  @Assert('south <= north', 'south must be <= north')
  @Assert('west <= east || (west > 0 && east < 0)', 'east < west only allowed on antimeridian wrap')
  factory MirkViewportBbox({
    required double south,
    required double west,
    required double north,
    required double east,
  }) = _MirkViewportBbox;
}
```

### Example 2: Hand-rolled 2D simplex noise

```dart
// Source: Ken Perlin's 2001 simplex noise public-domain reference implementation,
// adapted to Dart. See https://web.archive.org/web/20230612223611/https://www.csee.umbc.edu/~olano/s2002c36/ch02.pdf
// License: public domain (algorithm), GOSL (our Dart port)
class SimplexNoise2D {
  // 256 random permutation table, seeded deterministically
  final Uint8List _perm;

  factory SimplexNoise2D({int seed = 0}) {
    final p = Uint8List(512);
    final random = math.Random(seed);
    final base = List<int>.generate(256, (i) => i);
    base.shuffle(random);
    for (int i = 0; i < 512; i++) {
      p[i] = base[i & 255];
    }
    return SimplexNoise2D._(p);
  }

  SimplexNoise2D._(this._perm);

  /// Returns noise value in approximate range [-1, 1].
  double noise2(double xin, double yin) {
    // Skew, floor, un-skew, determine simplex, compute contributions
    // ~40 lines of standard simplex code. Implementation body omitted here
    // for brevity — the canonical reference is ~60 lines total.
    // ...
    return 0.0;  // placeholder
  }
}
```

### Example 3: RepaintBoundary-wrapped overlay widget

```dart
// Source: standard Flutter Ticker + CustomPainter pattern
class MirkOverlay extends StatefulWidget {
  const MirkOverlay({super.key, required this.renderer, required this.ctxBuilder});
  final MirkRenderer renderer;
  final MirkPaintContext Function() ctxBuilder;  // pulled fresh per frame

  @override
  State<MirkOverlay> createState() => _MirkOverlayState();
}

class _MirkOverlayState extends State<MirkOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final delta = elapsed - _lastTick;
      _lastTick = elapsed;
      widget.renderer.update(delta);
      if (mounted) setState(() {});  // next frame repaints the CustomPainter
    })..start();
  }

  @override
  void dispose() async {
    _ticker.dispose();
    await widget.renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MirkPainter(widget.renderer, widget.ctxBuilder()),
        size: Size.infinite,
      ),
    );
  }
}

class _MirkPainter extends CustomPainter {
  _MirkPainter(this.renderer, this.ctx);
  final MirkRenderer renderer;
  final MirkPaintContext ctx;

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(canvas, size, ctx);

  @override
  bool shouldRepaint(_MirkPainter old) => true;  // Ticker decides repaints
}
```

### Example 4: Registration pattern (registry constant + factory)

```dart
// Source: this research. Pattern validated by Phase 03 @Freezed sealed union +
// Phase 07 MirkRenderer contract test (same "growth guard" idiom).

// builtin_mirk_styles.dart
const List<_BuiltinDescriptor> kBuiltinMirkStyles = <_BuiltinDescriptor>[
  _BuiltinDescriptor(
    id: 'builtin.atmospheric',
    displayName: 'Atmospheric (défaut)',
    configFactory: _atmosphericDefault,
  ),
  _BuiltinDescriptor(
    id: 'builtin.solid',
    displayName: 'Solid',
    configFactory: _solidDefault,
  ),
  _BuiltinDescriptor(
    id: 'builtin.candlelight',
    displayName: 'Candlelight',
    configFactory: _candlelightDefault,
  ),
  _BuiltinDescriptor(
    id: 'builtin.heavenly_clouds',
    displayName: 'Heavenly Clouds',
    configFactory: _heavenlyCloudsDefault,
  ),
];

// mirk_renderer_factory.dart
class MirkRendererFactory {
  MirkRenderer create(MirkStyleConfig config) {
    return switch (config) {
      AtmosphericConfig() => AtmosphericMirkRenderer(config),
      SolidConfig() => SolidFillMirkRenderer(config),
      CandlelightConfig() => CandlelightMirkRenderer(config),
      HeavenlyCloudsConfig() => HeavenlyCloudsMirkRenderer(config),
      ShaderConfig() => const NoopMirkRenderer(),  // Phase 13 body
      UnknownConfig() => AtmosphericMirkRenderer(_atmosphericDefault()),  // fallback
    };
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Skia renderer with runtime SKSL compilation | Impeller renderer with AOT-compiled FLSL (GLSL subset) | Flutter 3.10 (2023) | Fragment shaders ship in an AOT-compiled form; no first-paint shader-compile jank. Phase 13 `ShaderConfig` renderer benefits; Phase 09 does not use shaders yet. |
| `gl_FragCoord` direct use | `FlutterFragCoord()` macro | Impeller introduction | Phase 13 shader authoring must use this macro to avoid surprises on Impeller-on-GLES targets. Phase 09 documents it in `ShaderConfig` stub docstring for Phase 13's benefit. |
| `package:flame` noise utilities | Ken Perlin 2001 simplex (hand-roll) or `fast_noise 2.0.0` (Apache-2.0) | Ongoing | Flame drags the full Flame engine — unacceptable dep bloat for a noise utility. Hand-rolled simplex is a well-understood ~60 LOC port. |

**Deprecated/outdated:**

- `maplibre_gl` per-frame source updates — not designed for 60 Hz cadence. Fine for pan-triggered events at ~2-10 Hz max. We avoid this entirely.
- `SkSL shader pre-compilation cache` — no longer needed post-Impeller. Phase 13 can omit it entirely.

## Rendering Strategy Decision

**Decision: Flutter `CustomPainter` overlay wrapped in `RepaintBoundary`, sibling of `MapLibreMapViewWidget` in a `Stack`.**

### Rationale (perf + architectural)

| Dimension | MapLibre `fill` layer with client-tuiled GeoJSON | Flutter `CustomPainter` overlay | Winner |
|-----------|--------------------------------------------------|---------------------------------|--------|
| Per-frame animation feasibility (60 Hz noise drift) | Requires `setStyle` or `setGeoJsonSource` per frame — ~10-250 ms measured in Phase 07. **Blocks 16 ms budget.** | Pure Dart paint pass; runs in Flutter frame pipeline; zero round-trip to native. Frame time scales with pixel count + per-tile paint cost. | **CustomPainter** |
| Compositing with Phase 11 markers (MARK-07 alpha 30 % under mirk) | Would require two marker layers in `kStyleLayerOrder` (one below `mirk_fog`, one above) → reorder / duplicate layer. | MapLibre annotations (user_location + markers) render at native alpha INSIDE MapLibre; Flutter mirk overlay composites over the whole MapLibre surface; Flutter markers overlay render above mirk. Zero `kStyleLayerOrder` change required. | **CustomPainter** |
| Integration with `MapView` domain port | Requires new `MapView` methods to push source data (e.g. `updateMirkGeometry(geojson)`) — leaks GeoJSON type into domain. MAP-06 seam risk. | Zero new `MapView` methods. The overlay reads `viewportUpdates` via existing seam. | **CustomPainter** |
| MapLibre `style.json` `kStyleLayerOrder` contract | Requires `mirk_fog` layer type change from `background` → `fill` + new `sources[mirkfall_mirk]`. Test `map_style_layer_order_test.dart` must be re-taught. | `mirk_fog` stays as `background` opacity 0 sentinel. Zero `style.json` edit. | **CustomPainter** |
| Frame isolation from base map (SC#4 RepaintBoundary) | MapLibre layer repaints trigger native redraws; Flutter-side `RepaintBoundary` not applicable to native platform view layers. | `RepaintBoundary` is canonical Flutter mechanism; isolates overlay repaints from the base `MapLibreMapViewWidget` platform view. DevTools validates. | **CustomPainter** |
| Viewport filtering (SC#5) ease | MapLibre handles viewport clipping natively — "free". But you lose per-tile control. | Explicit loop: iterate visible parent tiles via `TileMath.latLonToTile` on viewport bbox. Full control on per-tile paint cost. | **CustomPainter** (more code but more predictable) |
| Test surface | Requires real MapLibre or heavy fake — expensive. | `CustomPainter.paint` called on a `PictureRecorder` in `flutter_test`. Existing `mirk_renderer_contract_test` pattern (Phase 07). | **CustomPainter** |

### Risks of the CustomPainter approach (see §Risk Register)

- 50 k tile fixture paint cost — needs viewport culling + per-tile cheap paint. **Mitigated** by culling to ~16 visible parent tiles.
- Pixel-ratio scaling on 3× devices (Pixel 4a, iPhone) — more fragments to shade. **Mitigated** by per-tile `drawRect` / `drawPath` approach (bitmap-to-path → draw once per tile, not per pixel).

## Feather Edge Approach

**Decision: approach (a) — non-binary scratch mask bitmap generated at paint time + post-blur via `MaskFilter.blur`.**

### Why not (b) or (c)?

| Approach | How | Pros | Cons | Verdict |
|----------|-----|------|------|---------|
| (a) Scratch mask bitmap + `MaskFilter.blur` | Paint binary bitmap per tile into a per-frame scratch `ui.Image` (or Path); apply `Paint().maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)` when drawing the fog. | Binary DB bitmap unchanged → MIRK-03 invariant safe. `MaskFilter.blur` is GPU-accelerated on Impeller. Straightforward to implement. | Slight overdraw at tile edges because blur sigma extends beyond the 64×64 cell. Easily controlled via `kFeatherRadiusFraction = 0.1`. | **Chosen.** |
| (b) Composite runtime blur (two-pass render-to-offscreen-texture) | Render binary fog to offscreen `ui.Image`, blur with `ImageFilter.blur`, composite. | Single-pass efficient, full control. | Adds an extra GPU allocation per frame (offscreen texture of viewport size); 1080p × 3 devices = 3240×6480 = ~21 MB. Forbidden per Flutter docs: "allocating a new offscreen per frame is a perf killer". | Rejected. |
| (c) Shader-driven `smoothstep` | Write a fragment shader that takes the binary mask as a sampler2D uniform and uses `smoothstep(d - feather, d + feather, dist)` per pixel. | Fastest in theory; minimal overdraw. | Requires FragmentShader; couples atmospheric variant to shader pipeline which is Phase 13's target; makes test-time mocking non-trivial. Breaks "no shader variant in Phase 09". | Rejected for Phase 09. Reserved for Phase 13 `ShaderConfig`. |

**Implementation sketch for (a):**
- Per tile, from the 64×64 bitmap, build a `Path` of UN-revealed cells via `addRect()` per unrevealed cell.
- Paint = `Paint()..color = atmosphericFog..maskFilter = MaskFilter.blur(BlurStyle.inner, featherSigmaInPixels)`.
- `featherSigmaInPixels` = cell-size × `kFeatherRadiusFraction`, scaled by `pixelRatio` and zoom level.

**MIRK-03 invariant preservation:** the DB bitmap stores {0, 1}. The render-time transformation is in pixel space, not in stored-data space. `mergeMask` sees the same 512-byte `Uint8List` in and out.

## Noise Function Choice

**Decision: hand-rolled 2D simplex noise, pure Dart, in `lib/infrastructure/mirk/noise/simplex_noise_2d.dart`. No new runtime dependency. Ken Perlin's 2001 algorithm (public domain, patent-expired).**

### Rationale

- **License:** Perlin's 2001 simplex noise algorithm has been in the public domain since inception; patent (on the *simplex improvement over 3D perlin*, not on the 2D case) expired 2022. Our own Dart implementation = GOSL-licensed. Zero DEPENDENCIES.md audit burden.
- **Determinism:** seed-able. Tests can assert pixel-stable output. Fixtures are byte-reproducible.
- **LOC:** ~60 lines of Dart. Small enough to audit in the review gate.
- **Performance:** 2D simplex is ~20-30 ns per sample on mobile ARM. At 50 k tiles × 10 samples/tile (per-frame representative noise lookup) = 500 k samples × 25 ns = 12.5 ms — **above budget**. Mitigation: noise is NOT sampled per-tile per-frame. It's sampled per-tile with a low-freq cadence (every 5th frame) or per-viewport with a shared texture. See §Performance at 50k Tiles.
- **Fallback:** if the hand-rolled implementation underperforms at mid-phase profiling, swap for `fast_noise 2.0.0` (Apache-2.0, pure Dart, fixnum transitive). Audit row draft below.

### Per-variant noise parameters

Based on user decision "atmospheric + solid + candlelight + heavenly_clouds":

| Variant | Scale | Speed | Amplitude | Drift deg | Period | Visual intent |
|---------|-------|-------|-----------|-----------|--------|---------------|
| `atmospheric` (default) | 0.5 (coarse cells ≈ 50 m at z=14) | 0.05 (slow) | modulates alpha by ±3 % around `kDefaultMirkBaselineAlpha = 0.99` | 0 (north) | ~20 s full drift across viewport | "brouillard mouvant noir" — dense, dark, barely varying but alive |
| `solid` | N/A (no noise) | 0 | 0 | N/A | static | Proof of seam — literal aplat `Color(0xFF1A1A1A)` at opacity 0.99 |
| `candlelight` | 0.8 (finer) | 0.1 (faster flicker) | ±7 % around 0.85 baseline | N/A (radial, not drift) | sub-second flicker | Warm orange #FF8F6A center + darker #C2542E periphery, radial falloff modulated by high-freq noise |
| `heavenly_clouds` | 0.3 (very coarse) | 0.08 | ±10 % around 0.80 baseline (lighter than atmospheric) | 45° (NE) | ~30 s | Light `#E8E8EE` fog with visible "cloud blob" motion; feels airy/explorer |

(Numbers are starting tunes; user will tune in dev via constants.)

### DEPENDENCIES.md entry draft (ONLY IF hand-roll falls back)

```markdown
| fast_noise | 2.0.0 | Apache-2.0 | https://pub.dev/packages/fast_noise | Phase 09 plan 09-XX — **fallback for hand-rolled SimplexNoise2D if mid-phase profiling shows noise evaluation exceeds the per-frame budget**. Audit 2026-XX-XX: source github.com/JordanPeck/fast_noise inspected (Dart port of public-domain C++ noise algorithms by Jordan Peck) — pure Dart 2D+3D simplex/perlin/cellular/cubic/value implementations, zero HTTP, zero platform channels, zero SDKs. License preamble in pub cache: Apache-2.0. Transitive: `fixnum ^1.1.0` (BSD-3-Clause, already-audited Phase 01). Publisher: `b.dev`. Maintenance: last release 2024, stale but functional — algorithm is standard. | 2026-XX-XX |
```

## computeRevealMask Algorithm Specification

**Decision: bbox-first + per-cell geometric intersect (ellipse-in-rect test per cell), returning `Map<TilePosition, Uint8List>` to handle the multi-parent-tile case.**

### Signature (changes from Phase 03)

The Phase 03 signature returns `Uint8List` (one bitmap). Phase 09 MUST handle reveals spanning parent-tile boundaries. Two options:

**Option A: Signature change**
```dart
/// Returns one mask per parent tile touched by the circle.
Map<TilePosition, Uint8List> computeRevealMask({
  required double centerLat,
  required double centerLon,
  required double radiusMeters,
});
```

**Option B: Signature preserved, caller loops over parent tiles**
```dart
/// Returns the mask for the given parent tile (may return all-zero mask).
Uint8List computeRevealMask({
  required double centerLat,
  required double centerLon,
  required double radiusMeters,
  required int parentX,
  required int parentY,
  required int parentZoom,
});
```

**Recommendation: Option B** — preserves the Phase 03 signature (no caller churn — none right now, but the signature is the contract). The `RevealStreamingController` (new in Phase 09) wraps the loop:

```dart
// Phase 09 caller (reveal_streaming_controller.dart):
final bbox = _expandBbox(centerLat, centerLon, radiusMeters);
final touchedTiles = _visibleParentTiles(bbox, zoom: kRevealedTileParentZoom);
for (final tile in touchedTiles) {
  final mask = computeRevealMask(
    centerLat: centerLat,
    centerLon: centerLon,
    radiusMeters: radiusMeters,
    parentX: tile.x,
    parentY: tile.y,
    parentZoom: kRevealedTileParentZoom,
  );
  if (_hasAnyBits(mask)) {
    await revealedTileStore.mergeMask(
      sessionId: sessionId, parentX: tile.x, parentY: tile.y, mask: mask,
    );
  }
}
```

Each call to `computeRevealMask` is **self-contained**: "given the circle + this one parent tile, return its 512-byte mask." All-zero return is valid (circle doesn't touch this tile).

### Algorithm (per parent tile, O(64²) worst case)

```dart
// Pseudocode
Uint8List computeRevealMask({...}) {
  final mask = Uint8List(kRevealedTileBitmapBytes); // 512 bytes, all 0

  // 1. Convert center (lat, lon) to Mercator meters, derive cell pixel size
  //    at z=14 + sub-grid 64×64 = cells of ~38 m/side at equator
  //    (at lat 45°, ~27 m/side).
  //    Per-cell size depends on latitude (Mercator non-isotropic).
  final parentNw = TileMath.tileToLatLon(x: parentX, y: parentY, zoom: parentZoom);
  final parentSe = TileMath.tileToLatLon(x: parentX + 1, y: parentY + 1, zoom: parentZoom);

  // 2. Project circle's bbox to cell indices (bbox-first prune).
  final circleBbox = _circleBbox(centerLat, centerLon, radiusMeters);
  if (!_bboxIntersects(circleBbox, parentBbox)) return mask;  // early exit

  final cellLatSpan = (parentNw.lat - parentSe.lat) / 64.0;
  final cellLonSpan = (parentSe.lon - parentNw.lon) / 64.0;

  final cellJStart = max(0, ((parentNw.lat - circleBbox.north) / cellLatSpan).floor());
  final cellJEnd   = min(63, ((parentNw.lat - circleBbox.south) / cellLatSpan).ceil());
  final cellIStart = max(0, ((circleBbox.west - parentNw.lon) / cellLonSpan).floor());
  final cellIEnd   = min(63, ((circleBbox.east - parentNw.lon) / cellLonSpan).ceil());

  // 3. Per-cell intersection test (meters-accurate Haversine, not lat/lon
  //    Euclidean which underestimates longitude at high latitudes).
  for (int j = cellJStart; j <= cellJEnd; j++) {
    for (int i = cellIStart; i <= cellIEnd; i++) {
      final cellCenterLat = parentNw.lat - (j + 0.5) * cellLatSpan;
      final cellCenterLon = parentNw.lon + (i + 0.5) * cellLonSpan;
      // Closest point on the cell rectangle to the circle center (clamp)
      final closestLat = _clamp(centerLat, parentNw.lat - (j+1)*cellLatSpan, parentNw.lat - j*cellLatSpan);
      final closestLon = _clamp(centerLon, parentNw.lon + i*cellLonSpan, parentNw.lon + (i+1)*cellLonSpan);
      final d = _haversineMeters(centerLat, centerLon, closestLat, closestLon);
      if (d <= radiusMeters) {
        // Cell intersects circle. Flip the bit.
        final bitIndex = j * 64 + i;  // row-major
        final byteIndex = bitIndex >> 3;
        final bitOffset = bitIndex & 7;
        mask[byteIndex] |= (1 << bitOffset);
      }
    }
  }
  return mask;
}
```

### Complexity analysis at 25 m radius

- At 45° latitude, z=14: cell size ≈ 27 m × 27 m. A 25 m radius circle touches ~1-4 cells in each axis → maximum ~16 cells to test per parent tile. Typical case: 4-9 cells.
- Parent-tile boundary case: circle spans 2 parent tiles → two calls, each ≤16 cells checked.
- Per-cell cost: 1 clamp, 1 Haversine (~50 ns), 1 bitset (~5 ns). Total per call: 25 × 60 ns = 1.5 μs typical, 10 μs worst case. At the target rate of one fix every 5 seconds (distanceFilter = 5 m, walking ~1.4 m/s = one fix every 3.5 s), compute cost is **imperceptible**.

### Edge cases handled

- **Antimeridian wrap (Alaska/Siberia):** `_circleBbox` produces a non-wrap bbox because 25 m never crosses ±180°. Not relevant at 25 m radius.
- **Pole clamp (|lat| > 85.05°):** `TileMath.latLonToTile` already clamps (Phase 03). The outer loop never delivers poles because GPS doesn't fire there in practice for MirkFall users.
- **Fix outside basemap coverage:** `RevealStreamingController` checks `CountryResolver.viewportCountry` — if the fix is in an uninstalled country, the reveal still goes into DB (the basemap isn't required for reveal tracking). Consistent with Phase 07 "fall back to world bundle" UX.

## MirkPaintContext Extension Spec

**Decision: extend with `viewportBbox: MirkViewportBbox` (Freezed) + `frameElapsed: Duration` + `currentFix: Fix?` (nullable).**

### Rationale

- **`viewportBbox` as a dedicated Freezed class `MirkViewportBbox{south, west, north, east: double}`**, NOT `LatLngBounds` (MapLibre type) and NOT `Rect` of tile coords (couples to tile math).
  - Four doubles = 32 bytes. Trivial to allocate per frame.
  - MapLibre-type-free (satisfies MAP-06 `avoid_maplibre_leak` lint).
  - The overlay builder (`mirk_overlay.dart`) converts the `MapView.viewportUpdates` stream's domain-level bbox into `MirkViewportBbox` once per viewport change (debounced 50 ms). Not per frame.

- **`currentFix: Fix?` (nullable)**. Nullable because:
  - At session start before first fix, there's no position.
  - `candlelight` variant needs the position to center the radial glow.
  - Atmospheric doesn't use it.
  - Nullable is clearer than sentinel-zero; renderers that need it explicit-null-check.

- **`frameElapsed: Duration`**. Absolute elapsed from `sessionStarted`. NOT a per-frame delta. The Ticker emits absolute elapsed; renderers derive their own phase from it. `update(Duration elapsed)` (the delta, per MirkRenderer contract) is passed to the renderer's `update` separately by the Ticker.

- **`sessionElapsed` (already present)** — kept for backward compat, unchanged semantics. Possibly deprecated in favor of `frameElapsed` at Phase 10 review — research flags for consolidation.

### Freezed friction — a feature

Extending `MirkPaintContext` triggers a Freezed codegen bump which forces every consumer to re-compile. This is the intended "force a call-site review" pattern per the Phase 07 docstring. Phase 09 planning must budget:

1. One wave for `mirk_paint_context.dart` extension + `.freezed.dart` regen.
2. One wave for every renderer's `paint()` to read the new fields (or not — unused fields are free).
3. One wave for `mirk_overlay.dart` to populate them.

## Registration Pattern Choice

**Decision: constant registry list in `builtin_mirk_styles.dart` + factory class in `mirk_renderer_factory.dart`, both wired through Riverpod providers.**

### Why not Riverpod `multiProvider` / family?

- Riverpod `family` provider per style_id is a red herring — we don't want N providers, we want ONE provider that resolves the active style's config. `family` fits when the provider *is* parameterized externally (e.g. marker by id). Here the active style is application-scoped, not list-scoped.

### Why not pure factory pattern without registry?

- A factory without a registry means the list of builtins is implicit (must scan `lib/infrastructure/mirk/` to enumerate). The burger-menu UI needs to list "4 builtins"; it needs a registry.

### The "ajouter un style = 1 fichier" proof

With this pattern, adding a 5th builtin requires:

1. **NEW file:** `lib/infrastructure/mirk/new_variant_mirk_renderer.dart` implementing `MirkRenderer`.
2. **EDIT `mirk_style_config.dart`:** add a new sealed variant (required by the Dart sealed-class exhaustive-switch — compile-time enforcement that the factory handles it).
3. **EDIT `builtin_mirk_styles.dart`:** add an entry to `kBuiltinMirkStyles` registry.
4. **EDIT `mirk_renderer_factory.dart`:** add one case to the switch.

Files edited in the core: **3** (config, registry, factory). This is the irreducible minimum given the type system. Compare with a hypothetical "pure file drop": the sealed union + factory switch forces compile-time enforcement of registration — a good thing.

**To achieve true "1 file, 0 core mod" zero-edit proof, Phase 13 wires JSON-imported styles through a *different* path** — the `MirkStyleStore` (Drift-backed) accumulates user-imported styles as rows; the factory resolves them via `UnknownConfig` parameter bag + a runtime-interpreted parameter-based renderer OR (Phase 13) a GLSL shader loader. Either way the Phase 09 switch stays at 4 variants + `ShaderConfig` + `UnknownConfig`.

**Code review verification (SC#2):** The reviewer walks the git log of Phase 09 plans to confirm that each of the 4 renderer additions is a single-file addition + minimal config/registry/factory extension. No cross-cutting core changes.

### UI-visible naming

| File | Class | Registry ID | UI label (FR) |
|------|-------|-------------|---------------|
| `atmospheric_mirk_renderer.dart` | `AtmosphericMirkRenderer` | `builtin.atmospheric` | `Atmospheric (défaut)` |
| `solid_fill_mirk_renderer.dart` | `SolidFillMirkRenderer` | `builtin.solid` | `Solid` |
| `candlelight_mirk_renderer.dart` | `CandlelightMirkRenderer` | `builtin.candlelight` | `Lueur de bougie` |
| `heavenly_clouds_mirk_renderer.dart` | `HeavenlyCloudsMirkRenderer` | `builtin.heavenly_clouds` | `Nuages célestes` |
| `shader_mirk_renderer.dart` (stub) | `ShaderMirkRenderer` | `builtin.shader` (not exposed) | — (Phase 13) |

## Fixture 50k Strategy + Format

**Decision: deterministic Dart builder that generates a `.sql` file committed to `test/fixtures/mirk/fifty_k_tiles_seed.sql`. Seed SQL loaded by `executor.customStatement(file.readAsStringSync())`.**

### Why SQL + builder (not JSONL or pure programmatic)?

| Format | Load time on fresh Drift DB | Git-friendliness | Determinism | Size |
|--------|-----------------------------|------------------|-------------|------|
| `.sql` (seed SQL, committed) | ~1.5 s for 50k rows via single `executor.batch([...])` | Excellent: text-diffable, small repo size (~3 MB compressed in git LFS if needed; likely ~50 MB raw text — acceptable) | High (byte-stable SQL) | ~50 MB raw, ~3 MB git-LFS / gzip'd |
| `.jsonl` (one row per line) | ~2 s with JSON parse overhead | Good: text-diffable | High | ~40 MB |
| Pure Dart builder (no committed artifact) | ~2-5 s regenerating 50k random bitmaps per test run | Perfect (code-only) | High (seed-able) | 0 MB |

**Recommendation:** **hybrid.** The Dart builder script `tool/fixtures/build_50k_tiles.dart` is the source of truth (deterministic, seeded). It produces the `.sql` file at `test/fixtures/mirk/fifty_k_tiles_seed.sql` committed to the repo (small with git LFS or gzip). CI verifies the committed file matches what the builder produces via a diff check (`tool/check_mirk_fixture_fresh.dart`).

### Actual content: 50k sub-tiles

Per the convention `50k sub-tiles` means 50k *revealed cells* across N parent tiles. Closer reading of CONTEXT.md line 24 "50k sub-tiles + test de perf" and the ROADMAP SC#4 "50k-tile fixture" → the fixture is **50k rows in `t_revealed_tiles`**, each row being a parent tile with its 512-byte bitmap. At ~64 avg cells set per tile × 50k tiles = 3.2M cells revealed — a very dense session (equivalent to a 300+ km walk in a city).

**Builder output:**
- 50,000 rows in `t_revealed_tiles`.
- Parent tile coordinates: grid pattern 500×100 starting at (parentX = 8400, parentY = 5500) — arbitrary Europe region.
- Each bitmap: pseudo-random seeded pattern with ~25% bit density (1024 of 4096 bits set). Mimics "sparse walk through a city grid".
- Session: one row in `t_sessions` with known `id = 'sess_01FIFTYKTEST' + suffix`, status stopped, known timestamps.

```sql
-- Excerpt — 50,000 similar rows total
INSERT INTO t_revealed_tiles (id, session_id, parent_x, parent_y, parent_zoom, bitmap, set_bit_count, updated_at_utc)
VALUES
  ('rtil_01FIFTY00001', 'sess_01FIFTYKTEST', 8400, 5500, 14, X'FF0A...512bytes...', 1024, '2026-01-01T00:00:00Z'),
  ...;
```

### dart_test.yaml tag

Register new tag `mirk-perf`:
```yaml
tags:
  mirk-perf:
    timeout: 10x
```
Fixture load + paint pass test runs under `dart test --tags mirk-perf` only, not in the default suite. Matches the `soak` / `migration` idiom already in the repo.

## In-Session Style Swap Lifecycle

**Decision: immediate swap via Riverpod provider invalidation. Burger menu tap → `MirkStyleSessionController.select(styleId)` → write `sessions.mirk_style_id` → invalidate `activeMirkRendererProvider`. Next frame sees new renderer. Old renderer's `dispose()` is awaited by Riverpod's `ref.onDispose`.**

### Sequence

1. User opens burger menu, taps "Changer le style".
2. `MirkStylePickerSheet` shows 4 ListTile entries.
3. User taps one.
4. `MirkStyleSessionController.select(MirkStyleId)` is called.
5. Controller: `await sessionStore.updateMirkStyle(sessionId, styleId)` — persists to `t_sessions`.
6. Controller: `ref.invalidate(activeMirkRendererProvider)`.
7. `activeMirkRendererProvider.build()` re-runs: reads new `MirkStyle` from `MirkStyleStore` → resolves via `MirkRendererFactory.create(config)` → returns new renderer.
8. `MirkOverlay` (ConsumerStatefulWidget, watches `activeMirkRendererProvider`) rebuilds. In `didChangeDependencies` / `didUpdateWidget`:
   - `oldWidget.renderer.dispose()` is awaited (previous provider instance's `ref.onDispose` triggers via Riverpod lifecycle).
   - Ticker continues running; next frame paints with new renderer.

### Immediate vs next-frame

Immediate (same frame) would require synchronous dispose + synchronous re-creation. `MirkRenderer.dispose()` returns `Future<void>` (frozen signature). Therefore next-frame is the required semantic.

### Race conditions

- **User double-taps different styles within 1 frame:** Riverpod invalidation debouncing handles it — the last `invalidate` wins, intermediate providers are disposed without ever being read.
- **User selects a style then immediately stops the session:** `ActiveSessionController.stop()` already short-circuits if `_isStopping`; the in-flight style update is observable via `t_sessions.mirk_style_id` after stop (session is stopped but remembers its last style — UX: "when you restart the session, it'll be on the style you last picked").
- **New fresh session (no `mirk_style_id` set yet):** resolver falls back to the atmospheric default. When the user opens the style picker, the current selection is "Atmospheric (défaut)".

### Burger menu UI copy

Replace the stub in `lib/presentation/widgets/session_burger_menu.dart` (line 58-62):

```dart
ListTile(
  leading: const Icon(Icons.palette_outlined),
  title: const Text('Changer le style'),
  subtitle: Text(currentStyleDisplayName),  // pulled from active style provider
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Scaffold.of(context).closeDrawer();
    showModalBottomSheet(
      context: context,
      builder: (_) => const MirkStylePickerSheet(),
    );
  },
),
```

## Built-in Variant Specifications

### atmospheric (default)

- `AtmosphericConfig`: `baseColorArgb: 0xFF000000`, `noiseScale: 0.5`, `noiseSpeed: 0.05`, `driftDirectionDeg: 0.0`, `densityBaselineAlpha: 0.99`, `featherRadiusFraction: 0.1`, `edgeSoftness: 0.5`.
- Paint: for each visible parent tile, walk its 4096 cells; for each **unrevealed** cell (`bit == 0`), draw a filled rectangle at the cell's lat/lon → screen coords → fill color modulated by 2D simplex noise at `(screenX * 0.5, screenY * 0.5 + frameElapsed * 0.05)`. The modulation is alpha-only (`baseColor` stays black; alpha varies ±3 % around 0.99).
- Feather: on the cell's rectangle, `Paint.maskFilter = MaskFilter.blur(BlurStyle.inner, 2.0 * pixelRatio * featherRadiusFraction)`.

### solid

- `SolidConfig`: `colorArgb: 0xF51A1A1A` (near-black, opacity 0.96 of alpha = 0xF5, tuned to feel flat but not absolute zero).
- Paint: one `canvas.drawRect(viewportRect, paint)` where `paint.color = config.colorArgb`. No noise, no animation. The revealed cells are cut out via the binary mask as a clip path: `canvas.clipPath(revealedPath)` then `drawRect` the unrevealed inverse.
- Simpler: draw per-cell for unrevealed, same as atmospheric but without the noise modulation step.
- `update()` is a no-op; only paints when viewport/reveal changes (explicit invalidation via Ticker heartbeat still runs but paint output is identical).

### candlelight

- `CandlelightConfig`: `baseColorArgb: 0xFF2A1810` (dark warm brown), `secondaryColorArgb: 0xFFFF8F6A` (warm orange center), `noiseScale: 0.8`, `noiseSpeed: 0.1`, `densityBaselineAlpha: 0.85`, `flickerAmplitude: 0.07`, `glowRadiusMeters: 40.0`.
- Paint: for unrevealed cells, color = `lerp(secondaryColor, baseColor, distanceFromCurrentFix / glowRadiusMeters)`. Then modulate alpha by noise at higher frequency (`flickerAmplitude`) for the "candle flicker" feel.
- Requires `currentFix` from `MirkPaintContext`. If null (pre-first-fix), degrades gracefully to atmospheric behavior.

### heavenly_clouds

- `HeavenlyCloudsConfig`: `baseColorArgb: 0xFFE8E8EE` (very light blue-gray), `secondaryColorArgb: 0xFFFFFFFF` (white), `noiseScale: 0.3` (very coarse = large blobs), `noiseSpeed: 0.08`, `driftDirectionDeg: 45.0` (NE), `densityBaselineAlpha: 0.80`, `cloudContrast: 0.3`.
- Paint: like atmospheric but with `baseColorArgb` = light, noise amplitude larger (`±10 %`), and an additional noise lookup at `2×` frequency added to create "blob" feel. Resulting color = `lerp(base, secondary, noise2(x*0.3, y*0.3) * 0.5 + noise2(x*0.6, y*0.6) * 0.5)`.
- Drift: `frameElapsed * noiseSpeed` is applied to noise coords scaled by `cos(driftDirectionDeg)` / `sin(driftDirectionDeg)`.

## Performance at 50k Tiles

**50k rows in `t_revealed_tiles` does NOT mean 50k visible tiles. Viewport culling is the primary perf lever.**

### Expected tile count on screen

| Zoom | Viewport span | Parent tiles (z=14) visible | Cells paint-worthy (unrevealed in viewport) |
|------|---------------|-----------------------------|---------------------------------------------|
| z=14 | ~7 km (mid-phone width) | ~4×2 = 8 parent tiles | ~32k cells max (8 tiles × 4096) |
| z=15 | ~3.5 km | ~2×1 = 2 parent tiles | ~8k cells |
| z=16 | ~1.7 km | 1 parent tile | ~4k cells |
| z=17 | ~800 m | 1 parent tile (partial) | ~1k-4k cells |
| z=13 | ~15 km | ~16×8 = 128 parent tiles | ~500k cells — **out of budget** |

### Budget analysis (target 16 ms / frame on Pixel 4a / mid-range)

- `RevealedTileStore.listBySession(sessionId)`: ONE call per viewport change, cached for the session. **~1 ms.**
- **Paint pass per frame:**
  - 8 parent tiles × 4096 cells = 32k cells
  - Per cell: 1 bounds check (cell visible? no-op for off-viewport), 1 rect paint if unrevealed
  - Per cell paint: ~0.1 μs × 32k = 3.2 ms
  - Noise modulation: 1 sample per cell × 32k × 25 ns = 0.8 ms
  - Blur filter cost: maskFilter is a single Paint config, costs negligible per call
  - **Total: ~4 ms** on mid-range phone at z=14. **Well under 16 ms budget.**
- **Scale-out to z=13:** 500k cells × 0.1 μs = 50 ms — **blown budget**. Mitigation: at zooms below kViewportMinRenderZoom (e.g. 13), switch to coarser rendering (per-parent-tile color = average of cells, not per-cell). Ship Phase 09 with this floor; revisit at Phase 10 review if the product demands fog at z<13.

### Dirty-region tracking

Not needed for Phase 09. `CustomPainter.shouldRepaint` returns `true` (Ticker-driven). The `RepaintBoundary` gives us per-frame isolation; per-tile dirty tracking is premature optimization.

### pixelRatio scaling

At 3× pixelRatio (most modern phones), per-cell paint cost scales ~9× due to fragment count. However, Flutter's `drawRect` with `MaskFilter.blur` is GPU-accelerated and scales ~linearly with rasterized area. Budget headroom at 3× is ~15 ms on phones with Mali-G68 / Adreno 620+ class GPUs. Measure on Pixel 4a (real device, Phase 10 review) before declaring victory.

## FragmentShader Portability

Phase 09 does NOT ship a FragmentShader (atmospheric uses `MaskFilter.blur` + CPU noise). But the `ShaderConfig` sealed variant exists, a stub `ShaderMirkRenderer` ships, and Phase 13 will implement shaders. Document portability:

| Platform | FragmentShader support | Caveats |
|----------|-----------------------|---------|
| Android | ✅ full (Impeller since Flutter 3.10, default since 3.14) | `FlutterFragCoord()` macro required; don't use `gl_FragCoord`. |
| iOS | ✅ full (Impeller default since Flutter 3.11) | Same macro rule. |
| Windows | ✅ (Impeller-Vulkan since Flutter 3.22) | Works. Flutter team docs explicitly list Windows as supported. |
| macOS | ✅ (Impeller-Metal) | Works. |
| Linux | ⚠️ (Impeller opt-in) | Probably fine; not a Phase 09 / V1.0 ship target. |
| Web | ❌ limited | Not a ship target. |

**Asset declaration (for Phase 13's benefit):**

```yaml
# pubspec.yaml
flutter:
  shaders:
    - assets/shaders/atmospheric.frag
```

**Hot reload:** shader code edits require a full app restart (not hot reload). Flutter team is working on this but no ETA as of 2026-01.

**Debug tooling:** `flutter run --trace-startup` shows shader compile time; `FragmentProgram.fromAsset` is async, document the one-time compile at first use.

## Validation Architecture

> nyquist_validation = true (verified in .planning/config.json). This section is REQUIRED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Dual: `dart test 1.30.0` for pure-Dart units + `flutter_test` (SDK) for widget + render tests |
| Config file | `dart_test.yaml` at repo root (existing; add new `mirk-perf` tag) |
| Quick run command | `dart test test/domain/mirk test/domain/revealed && flutter test test/infrastructure/mirk test/application/controllers` |
| Full suite command | `flutter test && dart test` (union of all) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIRK-01 | GPS fix → reveal mask written within flush interval | integration | `flutter test test/application/controllers/reveal_streaming_controller_test.dart -x` | ❌ Wave 0 |
| MIRK-01 | `computeRevealMask` bbox-first intersect correctness | unit (Dart) | `dart test test/domain/revealed/reveal_calculator_test.dart -x` | ⚠️ partial (Phase 03 has algebra tests; Phase 09 adds body tests) |
| MIRK-01 | Parent-tile boundary split produces two masks | unit (Dart) | `dart test test/domain/revealed/reveal_calculator_parent_boundary_test.dart -x` | ❌ Wave 0 |
| MIRK-01 | Feather renders at ~10% of radius | widget+golden | `flutter test test/presentation/widgets/mirk_overlay_feather_test.dart` | ❌ Wave 0 |
| MIRK-01 | Initial 20 m reveal at session start (with + without fix) | controller | `flutter test test/application/controllers/active_session_controller_initial_reveal_test.dart` | ❌ Wave 0 (extends existing file) |
| MIRK-02 | `kDefaultRevealRadiusMeters = 25` + flush constants consumed | unit | `dart test test/constants_test.dart` | ⚠️ existing file extended |
| MIRK-04 | Atmospheric is animated (paint output differs across frames) | widget | `flutter test test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart` | ❌ Wave 0 |
| MIRK-04 | Noise is deterministic under seed | unit | `dart test test/infrastructure/mirk/noise/simplex_noise_2d_test.dart` | ❌ Wave 0 |
| MIRK-05 | `MirkRenderer` contract frozen at 3 methods | contract (compile+run) | `flutter test test/domain/mirk/mirk_renderer_contract_test.dart` | ✅ existing (Phase 07) |
| MIRK-05 | Factory dispatches 6 variants exhaustively | unit | `flutter test test/infrastructure/mirk/mirk_renderer_factory_test.dart` | ❌ Wave 0 |
| MIRK-05 | Sealed union dispatch is exhaustive (compile-time proof) | contract | `flutter analyze --fatal-warnings` (picks up unhandled sealed variant) | ✅ existing CI gate |
| MIRK-06 | All 4 builtin renderers instantiate without throw | unit | `flutter test test/infrastructure/mirk/builtin_renderers_smoke_test.dart` | ❌ Wave 0 |
| MIRK-06 | Each builtin has a distinct paint output (no accidental dup) | widget+golden | `flutter test test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart` | ❌ Wave 0 |
| MIRK-06 | Each builtin lives in its own file (structural) | unit | `dart test tool/test/check_mirk_variant_file_count_test.dart` (enforces 1 file/variant) | ❌ Wave 0 (new tool script + test) |
| MIRK-07 | Burger menu picker shows 4 options + selects | widget | `flutter test test/presentation/widgets/session_burger_menu_style_selector_test.dart` | ❌ Wave 0 |
| MIRK-07 | Swap persists to `t_sessions.mirk_style_id` | controller | `flutter test test/application/controllers/mirk_style_session_controller_test.dart` | ❌ Wave 0 |
| MIRK-07 | Renderer swaps next-frame, no flash | widget+integration | `flutter test test/presentation/widgets/mirk_overlay_swap_test.dart` | ❌ Wave 0 |
| SC#3 (`MirkRenderer` surface) | `paint/update/dispose` only, no ui.Image forced | contract | `mirk_renderer_contract_test.dart` (existing) | ✅ existing |
| SC#4 (RepaintBoundary + ≤16 ms) | 50k fixture paint pass stays under budget | perf | `flutter test --tags mirk-perf test/performance/fog_50k_tiles_perf_test.dart` | ❌ Wave 0 |
| SC#4 (RepaintBoundary) | No rebuild cascades to other widgets | widget | `flutter test test/presentation/map_screen_repaint_boundary_test.dart` | ❌ Wave 0 |
| SC#5 (viewport filtering) | Only viewport-intersecting tiles painted | widget | `flutter test test/presentation/map_screen_viewport_filtering_test.dart` | ❌ Wave 0 |
| `kStyleLayerOrder` unchanged | mirk_fog position intact | regression | `flutter test test/presentation/map_style_layer_order_test.dart` | ✅ existing |
| MAP-04 conformance (overlay natively wired) | `MirkOverlay` composites correctly with base map | widget | `flutter test test/presentation/mirk_overlay_composition_test.dart` | ❌ Wave 0 |

### Dimensional coverage (unit / widget / integration / perf / contract / regression)

| Dimension | Coverage | Count |
|-----------|----------|-------|
| unit (pure Dart) | `computeRevealMask`, `SimplexNoise2D`, constants, `MirkRendererFactory`, variant file count tool | 5 |
| widget (flutter_test) | 4 variant renderers, `MirkOverlay` feather, `MirkOverlay` swap, `MapScreen` RepaintBoundary, viewport filter, burger menu, picker sheet | ≥8 |
| integration | reveal streaming end-to-end, `ActiveSessionController` initial reveal, swap + persist + re-read | 3 |
| perf | 50k tiles frame budget, ≤16 ms | 1 (tagged `mirk-perf`) |
| contract | `MirkRenderer` 3-method surface, factory exhaustive dispatch, `kStyleLayerOrder` frozen | 3 |
| regression (inertness-guarded) | style-order regression (existing), `kDefaultRevealRadiusMeters` consumed, variant file-count | 3 |

### Sampling Rate

- **Per task commit:** `flutter test test/domain/mirk test/domain/revealed test/infrastructure/mirk` (quick; excludes `mirk-perf` + `soak` + integration tags; ~15 s on CI mid-range)
- **Per wave merge:** `flutter test` + `dart test` (full default suite; ~2 min; no perf)
- **Phase gate:** above + `flutter test --tags mirk-perf` + `flutter test integration_test/` + `/gsd:verify-work` review

### Wave 0 Gaps

New test files and fixtures that Phase 09 Wave 0 must scaffold:

- [ ] `test/domain/revealed/reveal_calculator_test.dart` — extend (Phase 03 has algebra only)
- [ ] `test/domain/revealed/reveal_calculator_parent_boundary_test.dart` — new
- [ ] `test/infrastructure/mirk/noise/simplex_noise_2d_test.dart` — new
- [ ] `test/infrastructure/mirk/atmospheric_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/solid_fill_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/candlelight_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/heavenly_clouds_mirk_renderer_test.dart` — new
- [ ] `test/infrastructure/mirk/mirk_renderer_factory_test.dart` — new
- [ ] `test/infrastructure/mirk/builtin_renderers_smoke_test.dart` — new
- [ ] `test/infrastructure/mirk/builtin_renderers_visual_distinct_test.dart` — new
- [ ] `test/application/controllers/reveal_streaming_controller_test.dart` — new
- [ ] `test/application/controllers/active_session_controller_initial_reveal_test.dart` — extend existing (add group)
- [ ] `test/application/controllers/mirk_style_session_controller_test.dart` — new
- [ ] `test/presentation/widgets/session_burger_menu_style_selector_test.dart` — new
- [ ] `test/presentation/widgets/mirk_overlay_feather_test.dart` — new
- [ ] `test/presentation/widgets/mirk_overlay_swap_test.dart` — new
- [ ] `test/presentation/widgets/mirk_overlay_composition_test.dart` — new
- [ ] `test/presentation/map_screen_repaint_boundary_test.dart` — new
- [ ] `test/presentation/map_screen_viewport_filtering_test.dart` — new
- [ ] `test/performance/fog_50k_tiles_perf_test.dart` — new (tagged `mirk-perf`)
- [ ] `test/fixtures/mirk/fifty_k_tiles_seed.sql` — new (generated by builder)
- [ ] `test/fixtures/mirk/builtin_styles.json` — new (round-trip cross-check)
- [ ] `test/fixtures/mirk/imported_style_valid.json` — new (Phase 13 prep)
- [ ] `test/fixtures/mirk/imported_style_unknown_type.json` — new (Phase 13 prep)
- [ ] `test/fakes/fake_mirk_renderer.dart` — new
- [ ] `test/fakes/fake_reveal_streaming_controller.dart` — new
- [ ] `test/fakes/fake_mirk_style_session_controller.dart` — new
- [ ] `tool/fixtures/build_50k_tiles.dart` — new (fixture generator)
- [ ] `tool/check_mirk_fixture_fresh.dart` — new (CI gate: committed SQL matches builder output)
- [ ] `tool/test/check_mirk_fixture_fresh_test.dart` — new (paired test)
- [ ] `tool/check_mirk_variant_file_count.dart` — new (CI gate: structural enforcement of "1 file per variant")
- [ ] `tool/test/check_mirk_variant_file_count_test.dart` — new (paired test)
- [ ] `dart_test.yaml` — extend with `mirk-perf` tag

Framework install: none needed; all infrastructure exists.

## Risk Register

What could bust the 16 ms budget / 5 Success Criteria?

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| R1 | Hand-rolled simplex noise too slow on Pixel 4a mid-range | Medium | Blocks SC#4 | Profile at mid-phase; fall back to `fast_noise` 2.0.0; or sub-sample noise (per-tile, not per-cell) |
| R2 | `MaskFilter.blur` at pixelRatio=3 exceeds GPU budget | Medium | Blocks SC#4 on atmospheric | Reduce `featherRadiusFraction`; pre-rasterize feather into per-tile `ui.Image` cached |
| R3 | `computeRevealMask` Haversine is 50 ns too slow at high fix rate | Low | Breaks 2s flush target | Profile; swap to fast approximations (equirectangular at local scale) |
| R4 | Viewport update stream fires faster than debounce can absorb | Medium | Causes setState storm during pan | Debounce via `ValueNotifier` + `Ticker`-sampled reads, NOT stream subscriber |
| R5 | Renderer swap race with Ticker tick emitting on old renderer | Low | Visual glitch on swap | Ticker reads renderer via provider watch; Riverpod enforces atomic swap |
| R6 | 50k SQL fixture load time causes CI timeout on slow runners | Medium | Test flakes | Cap fixture at 50k, verify <10 s load; tag `mirk-perf` with `10x` timeout (existing pattern) |
| R7 | `RepaintBoundary` fails to isolate on Android platform view compositing | Low | Breaks SC#4 proof | Validate with DevTools "Highlight Repaints" on real device in Phase 10 review |
| R8 | Phase 11 composite-trick needs layer reorder (breaks `kStyleLayerOrder` contract) | Medium | Breaks Phase 07 frozen contract | Document Phase 11 uses MapLibre annotations (below fog) + Flutter overlay (above), no reorder. Confirmed architecturally in §Pitfall 8. |
| R9 | Initial 20 m reveal race — `startSession()` returns before `computeRevealMask` + `mergeMask` finish | Low | First fix missed at ring boundary | Await reveal write before `state = Tracking(...)`; document semantic |
| R10 | In-memory reveal mirror diverges from DB after flush failure | Medium | Stale UI / missed reveal | Flush is atomic per-tile via `mergeMask` transaction; on flush error, roll back in-memory mirror |
| R11 | `MirkStyleConfig` Freezed regeneration breaks JSON parsing for Phase 03 imports | Low | Phase 13 import-from-v1 fails | `UnknownConfig` fallback catches anything Phase 03 → Phase 09 mismatch; verified by `test/fixtures/mirk/imported_style_valid.json` round-trip |
| R12 | `user_location` puck paints above mirk, not below, breaking the dissolving-puck feel | Low | Visual polish miss | MapLibre annotation manager paints user_location in the base map layer; mirk overlay sits above. Confirm in Phase 10 review; if wrong, add a second Flutter puck widget above mirk. |

## Open Questions

1. **FragmentShader noise GPU offload (Phase 13 question, not Phase 09)**
   - What we know: FragmentShader works on Android+iOS+Windows per Flutter docs (2025).
   - What's unclear: on Pixel 4a with Impeller+GLES, exact frame budget impact of a `.frag` that samples simplex noise at 60 Hz. Could be 0.5 ms or 5 ms.
   - Recommendation: defer to Phase 13. Phase 09 hand-rolls noise on CPU and proves 16 ms budget. Phase 13 can optionally migrate atmospheric to FragmentShader for perf headroom.

2. **`user_location` annotation z-order interaction with Flutter overlay**
   - What we know: `user_location` is a MapLibre annotation (see `style_layer_order.dart` docstring). It paints inside the MapLibre base layer.
   - What's unclear: does MapLibre annotation layer composite *below* or *above* the platform-view boundary that Flutter overlay sits on?
   - Recommendation: Phase 10 review hands-on verification on real device. Probable answer: below (puck dissolves under mirk at session start, becomes visible as user reveals around it). Desired UX.

3. **Per-cell vs per-tile paint trade-off for 32k-cell paint budget**
   - What we know: per-cell `drawRect` + blur = ~3.2 ms at 32k cells on mid-range.
   - What's unclear: is there measurable gain from batching cells into a single `Path` per parent tile?
   - Recommendation: start per-cell (clearest), profile; switch to per-tile `Path` if measurements demand.

4. **Initial 20 m reveal fade-in animation (500 ms) — tick source**
   - What we know: user wants a 500 ms fade-in.
   - What's unclear: does the fade-in happen in the `MirkOverlay` ticker (absorbing into global animation state) or in a dedicated `AnimationController`?
   - Recommendation: dedicated `AnimationController` inside `MirkOverlay` keyed by `Fix?` change → simpler to reason about, decoupled from ongoing noise tick.

5. **`MirkPaintContext.sessionElapsed` vs `frameElapsed` — which wins after dust settles?**
   - What we know: `sessionElapsed` is the existing Phase 07 name.
   - What's unclear: `frameElapsed` in this research is the same thing. Two names confuse.
   - Recommendation: Phase 09 plan consolidates — keep `sessionElapsed`, drop `frameElapsed`. Commented here so the planner knows not to add both.

## Sources

### Primary (HIGH confidence)

- `lib/domain/mirk/mirk_renderer.dart` — frozen interface (Phase 07)
- `lib/domain/mirk/mirk_paint_context.dart` — Freezed class to extend
- `lib/domain/mirk/mirk_style_config.dart` — sealed union to extend
- `lib/domain/revealed/reveal_calculator.dart` — signature frozen, body to implement
- `lib/domain/revealed/tile_math.dart` — slippy-map math (re-usable)
- `lib/domain/revealed/revealed_tile.dart` — bitmap entity
- `lib/domain/revealed/revealed_tile_store.dart` — port contract
- `lib/infrastructure/stores/drift_revealed_tile_store.dart` — impl (Phase 06)
- `lib/infrastructure/map/style_layer_order.dart` — frozen layer order + validator
- `assets/maps/style.json` — `mirk_fog` layer as `background` opacity 0 sentinel
- `lib/config/constants.dart` — existing constants + where new ones land
- `lib/presentation/widgets/session_burger_menu.dart` — stub ListTile to wire
- `lib/application/controllers/active_session_controller.dart` — fix stream consumer
- `lib/infrastructure/mirk/noop_mirk_renderer.dart` — Phase 07 stub (kept for tests)
- `.planning/phases/09-fog-rendering/09-CONTEXT.md` — authoritative user decisions
- `.planning/REQUIREMENTS.md` — MIRK-01..07 amended versions
- `.planning/ROADMAP.md` — Phase 09 SC#1/SC#2 amended
- Flutter docs: [Writing and using fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders) — FragmentShader platform support matrix + Impeller caveats
- Ken Perlin's 2001 simplex noise paper — public-domain algorithm reference

### Secondary (MEDIUM confidence)

- [Practical Fragment Shaders in Flutter](https://www.thedroidsonroids.com/blog/fragment-shaders-in-flutter-app-development) — community guide on FragmentShader asset pipeline
- [Shady Flutter: Using GLSL Shaders in Flutter](https://blog.codemagic.io/shady-flutter/) — hot-reload limitation confirmed
- [Mastering Impeller Custom Shaders for 120fps Flutter Apps](https://dev.to/devin-rosario/mastering-impeller-custom-shaders-for-120fps-flutter-apps-2020) — budget measurements on various devices
- [pub.dev fast_noise 2.0.0](https://pub.dev/packages/fast_noise) — fallback noise library
- [pub.dev open_simplex_noise 2.3.1](https://pub.dev/packages/open_simplex_noise) — alternative fallback

### Tertiary (LOW confidence — VERIFY in Phase 09 mid-phase profiling)

- 2D simplex noise sample cost at 25 ns on mobile ARM — measured on desktop, mobile may be 1.5-3× slower
- Pixel 4a paint cost per cell at `MaskFilter.blur` with 3× pixelRatio — unmeasured; Phase 10 review measures on real device

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all primary tooling already in project; no new deps required.
- Rendering strategy (CustomPainter + RepaintBoundary): HIGH — textbook Flutter pattern + Phase 07 empirical evidence against per-frame `setStyle`.
- `computeRevealMask` algorithm: HIGH — bbox-first + per-cell is textbook. Tile math already hardened in Phase 03.
- Feather implementation (approach a): MEDIUM — `MaskFilter.blur` is standard but precise GPU cost on Pixel 4a not yet measured.
- Noise function hand-roll: MEDIUM — algorithm is public-domain and Dart-portable, but performance on target devices not measured.
- Built-in variant visual parameters: LOW — user will tune; starting values are educated guesses.
- Registration pattern: HIGH — Dart sealed + switch exhaustiveness is compile-time proof.
- Fixture 50k strategy: HIGH — SQL + Dart builder is standard; `mirk-perf` tag parallels existing `soak` / `migration` pattern.
- In-session swap lifecycle: HIGH — Riverpod `ref.invalidate` + `ref.onDispose` is textbook.
- `MirkPaintContext` extension: HIGH — Freezed extension is straightforward.
- 50k tile perf on Pixel 4a: LOW — theoretical analysis; real-device measurement is Phase 10 review's job.
- Phase 11 compositing plausibility: HIGH — documented via MapLibre annotations below + Flutter overlay above; no `kStyleLayerOrder` reorder needed.

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (30 days — Flutter SDK stable, no major API churn expected, re-check if Flutter 3.42+ lands within the window)

---

## RESEARCH COMPLETE

**Phase:** 09 - Fog Rendering
**Confidence:** HIGH (core decisions) / MEDIUM (noise perf, GPU cost on real device) / LOW (exact visual tuning for candlelight + heavenly_clouds — user will tune in dev)

### Key Findings

- **Flutter `CustomPainter` + `RepaintBoundary` overlay wins over MapLibre `fill` layer** on perf, testability, Phase 11 composability, and `kStyleLayerOrder` contract preservation. `mirk_fog` stays in `style.json` as 0-opacity sentinel.
- **Hand-rolled 2D simplex noise in pure Dart** — no new dep, ~60 LOC, public-domain algorithm, deterministic under seed. Fallback: `fast_noise 2.0.0` (Apache-2.0). DEPENDENCIES.md entry drafted conditionally.
- **`computeRevealMask` stays at current signature** (per parent tile) — caller `RevealStreamingController` loops over bbox-touched tiles. Algorithm is bbox-first prune + per-cell Haversine intersect. ~10 μs worst case per parent tile per fix.
- **4 built-in renderers as 4 distinct files in `lib/infrastructure/mirk/`** — registry constant + factory provider pattern. Sealed union exhaustiveness is compile-time proof. SC#2 structurally enforced.
- **Feather via `MaskFilter.blur`** — binary bitmap in DB (MIRK-03 invariant safe), per-frame inner blur at render time. Non-binary mask + post-blur = approach (a) per research.
- **50k tiles fixture = deterministic Dart builder writing `test/fixtures/mirk/fifty_k_tiles_seed.sql`**, paired with CI gate verifying committed file matches builder output. `mirk-perf` new `dart_test.yaml` tag.
- **In-session style swap = Riverpod `ref.invalidate(activeMirkRendererProvider)`**, next-frame pickup. Ticker continues; `CustomPainter` sees new renderer on next paint.
- **Phase 11 composite-trick** (markers at 30 % under mirk) is architecturally clean with this design: MapLibre annotations (below fog, native alpha) + Flutter overlay (above fog, full alpha). Zero `kStyleLayerOrder` reorder.

### File Created
`C:/claude_checkouts/GOSL-MirkFall/.planning/phases/09-fog-rendering/09-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Rendering strategy | HIGH | Flutter-idiomatic pattern; Phase 07 empirical rejection of per-frame MapLibre path |
| `computeRevealMask` algorithm | HIGH | Textbook bbox-prune + Haversine; Phase 03 algebra proven |
| Registration pattern | HIGH | Compile-time sealed-dispatch enforcement |
| Validation architecture | HIGH | Built on existing Phase 03/05/07 patterns; `mirk-perf` tag mirrors `soak`/`migration` |
| Noise function performance on Pixel 4a | MEDIUM | Algorithm is well-understood; real-device timing unverified |
| `MaskFilter.blur` GPU cost at 3× pixelRatio | MEDIUM | Impeller-accelerated but exact budget impact unmeasured |
| Visual parameters for candlelight + heavenly_clouds | LOW | Starting values are informed guesses; user tunes in dev |

### Open Questions (left for planning discretion)

1. FragmentShader noise GPU offload — deferred to Phase 13.
2. `user_location` annotation z-order with Flutter overlay — verify in Phase 10 review.
3. Per-cell vs per-tile paint batching — profile-driven choice during Phase 09 implementation.
4. Initial 20 m reveal fade-in tick source — planner recommends dedicated `AnimationController`.
5. `MirkPaintContext.sessionElapsed` vs `frameElapsed` dedup — planner consolidates to existing name.

### Ready for Planning

Research complete. Planner can now create PLAN.md files for Phase 09 with:
- 4 renderer classes, one file each.
- `computeRevealMask` body.
- `MirkPaintContext` + `MirkStyleConfig` extensions.
- `MirkOverlay` widget with Ticker + `RepaintBoundary` + `CustomPainter`.
- `RevealStreamingController` (2s / 20 fixes batch flush).
- `MirkStyleSessionController` (persist + invalidate).
- `ActiveSessionController.startSession()` initial 20 m reveal hook with fallback semantics.
- Burger menu wire-up + bottom sheet picker.
- 50k fixture + builder + CI gate.
- 22+ new test files (unit, widget, integration, perf, contract, regression).

No dependencies need to be added. No upstream amendments required (the 3 mandatory amendments from CONTEXT.md §amendments have already landed per additional_context).
