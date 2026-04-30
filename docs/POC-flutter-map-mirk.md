# POC: flutter_map + fog-of-war shader — feasibility test

## Target platforms

**iOS is the PRIMARY target.** Android is secondary (convenience builds for quick iteration).

- iOS: sideloaded via SideStore (no Apple Developer account, no TestFlight). This is how the main MirkFall app is tested. All UAT walks happen on an iPhone.
- Android: debug APK on Pixel 4a for quick dev iteration + perf comparison. Secondary.
- CI must build BOTH: unsigned IPA (`flutter build ios --no-codesign`) + debug APK (`flutter build apk --debug`) so both artifacts are downloadable from GitHub Actions.

## Goal

Test whether `flutter_map` (pure-Flutter map renderer) can render our animated fog-of-war shader **in the same rendering pipeline** as the map tiles, eliminating the 1-3 frame camera-lag that's fundamental to the `maplibre_gl` platform-view architecture.

**Success criteria**: the fog-of-war moves with the map during pan/zoom/combined gestures with **zero visible displacement** on iOS. The fog must look like real fog on the map, not an effect painted on the camera screen. Target: 30+ fps on iOS device with fog shader active.

## Why this POC exists

BUG-014 proved that a Flutter `CustomPaint` overlay on top of MapLibre GL will always lag behind the map because they render in separate pipelines (native GL vs Flutter Canvas). Six iterations over multiple hours all failed to fix this. `flutter_map` renders everything in Flutter's own Canvas — custom layers paint in the **exact same frame** as the map tiles.

The unknown: `flutter_map` vector tile performance on mobile is reportedly poor. This POC determines whether it's acceptable for MirkFall's use case.

---

## Architecture

```
flutter_map (TileLayer)           ← renders PMTiles vector tiles
  └── CustomPainter layer         ← fog shader (atmospheric_fog.frag) paints HERE
       └── same Canvas, same frame, same pipeline → zero lag
```

---

## Packages to use

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| `flutter_map` | ^8.3.0 | BSD-3 | Map widget (pure Flutter Canvas) |
| `vector_map_tiles` | ^8.0.0 | Apache-2.0 | Vector tile rendering on flutter_map |
| `vector_map_tiles_pmtiles` | ^1.5.0 | MIT | PMTiles file loading |
| `geolocator` | 14.0.2 | MIT | GPS location |
| `permission_handler` | latest | MIT | Runtime permissions |
| `logging` | latest | BSD-3 | Logger |
| `path_provider` | latest | BSD-3 | App directories |
| `share_plus` | latest | BSD-3 | Email/share logs |

All GOSL-compatible (no GPL, no telemetry).

---

## Features to implement

### 1. Permission screen (launch gate)

Before showing the map, present a permission rationale screen:
- Request `Permission.locationWhenInUse` (required)
- On grant → navigate to map screen
- On deny → show "denied" screen with system settings link

Simplified from MirkFall's full flow (skip `locationAlways` and notification for the POC).

### 2. Map with bundled PMTiles

Bundle a France/Melun-area PMTiles file in `assets/maps/`:
- Use the existing `fra.pmtiles` from the MirkFall countries-pmtiles releases, OR generate a Melun-area extract
- Load via `vector_map_tiles_pmtiles`:
```dart
PmTilesVectorTileProvider.fromSource('asset:///assets/maps/fra.pmtiles')
// or from file path after copying to app support dir
```

**Style**: replicate MirkFall's neutral basemap colors:
- Background: `#f5f1e8`
- Landcover: `#e8e2d0` at 85% opacity
- Water: `#a6c9df`
- Boundaries: `#8a8377`, 0.6px dashed
- Roads: `#bfb8a6`, zoom-interpolated width 0.4–3.0px

`vector_map_tiles` uses a `Theme` object for styling — map MirkFall's layer colors into that theme system.

**Initial camera**: Melun, France → lat: 48.5397, lon: 2.6553, zoom: 13

### 3. Blue dot (user location)

Render the user's GPS position as a blue circle on the map:
- Use a `MarkerLayer` or a custom `CircleMarker` in flutter_map
- Blue: `#2b7cd6`, radius 7px, white stroke 2px
- Update on each GPS fix

### 4. Fog-of-war with atmospheric shader

This is the critical test. Implement the fog as a flutter_map custom layer:

**a) Copy the shader file**: `assets/shaders/atmospheric_fog.frag`
- Same GLSL 460 core shader (436 lines)
- 41 float uniforms + 1 sampler (SDF texture)

**b) SDF builder**: port `RevealedSdfBuilder.buildFromDiscs`
- Input: list of `(lat, lon, radiusMeters)` discs + viewport bbox
- Output: 256×256 `ui.Image` (R-channel midpoint-128 SDF)
- Key: compute distance in **metres** (not pixels) for correct circles at all latitudes

**c) Fog custom layer**: implement as a flutter_map layer widget
- On each frame, the layer receives the map's current camera state (center, zoom, bounds)
- Compute the clip path (world rect minus disc circles in screen coords)
- Set shader uniforms (41 floats + SDF sampler)
- `canvas.clipPath(fogPath); canvas.drawRect(viewport, Paint()..shader = shader);`

**CRITICAL**: because flutter_map is pure Flutter Canvas, this `paint()` call happens in the **same frame** as the map tile rendering. The fog naturally tracks the map — no compensation needed.

**d) Shader uniforms** — all atmospheric defaults:

| Uniform | Slots | Default value |
|---------|-------|---------------|
| uResolution | 0-1 | canvas size |
| uTime | 2 | elapsed seconds + seed*0.137 |
| uOffset | 3-4 | centreLon*0.05, -centreLat*0.05 |
| uBase | 5-8 | #3A4358 ARGB, alpha 0.95 |
| uHighlight | 9-12 | #7C8AA3 |
| uShadow | 13-16 | #1E2536 |
| uDriftZFar/Mid/Near | 17-19 | 0.23, 0.24, 0.23 |
| uScaleFar/Mid/Near | 20-22 | 2.9, 5.1, 10.5 |
| uOpacityFar/Mid/Near | 23-25 | 0.58, 0.58, 0.58 |
| uCurlAmplitude | 26 | 1.0 |
| uCurlScale | 27 | animated triangle wave 0↔4 over 40s |
| uLightDirRadians | 28 | -1.11 |
| uLightOffset | 29 | 0.46 |
| uLightStrength | 30 | 1.67 |
| uHueNoiseScale | 31 | 1.6 |
| uHueStrength | 32 | 0.44 |
| uBoundarySharpDistance | 33 | 0.04 |
| uBoundaryBleedDistance | 34 | 0.12 |
| uBoundaryEdgeBand | 35 | 0.17 |
| uBoundaryDensityBoost | 36 | 0.15 |
| uSdfRectOriginX/Y | 37-38 | 0.0, 0.0 (always identity — same pipeline) |
| uSdfRectSizeX/Y | 39-40 | 1.0, 1.0 |
| sampler uSdf | sampler 0 | 256×256 SDF image |

**e) Reveal discs**: on each GPS fix, create a disc at `(lat, lon, 25m)`. Store in memory (no database needed for POC). Rebuild SDF when disc list changes.

### 5. Recenter button

A floating action button that animates the camera back to the user's last known position + zoom 15.

### 6. Logger + email sharing

- Use Dart `logging` package
- Write logs to `<app_docs>/logs/yyyymmdd_hhmmss_logs.txt`
- Log level: ALL (verbose for POC)
- Add a button (e.g. in an app bar or floating menu) that uses `share_plus` to share the log file via email/messaging

### 7. Wisp particles (optional, nice-to-have)

If time permits, add the wisp particle system along disc perimeters on emergence. Parameters:
- Max 200 wisps, 8m spacing, 2.5s life, 18px/s initial speed
- Birth radius 6px → death radius 22px, peak alpha 0.35
- 5s warm-up phase on app open

---

## What to measure

UAT walk on **iOS device** (primary). Pixel 4a Android as secondary comparison.

1. **Fog-map sync**: Does the fog stay locked to the map during pan/zoom/combined gestures? This is the PRIMARY success criterion. Test on iOS.
2. **FPS during gestures on iOS**: Target: 30+ fps during pan with fog active.
3. **FPS static on iOS**: When the map is idle and the fog animates (curl breathing). Target: 50+ fps.
4. **Map tile rendering quality**: Do vector tiles look acceptable compared to MapLibre on iOS?
5. **SDF rebuild latency**: How long does `buildFromDiscs` take? Should be <16ms for <100 discs.
6. **Memory usage**: Profile with DevTools. The 256×256 SDF + shader shouldn't add significant overhead.
7. **Android comparison**: Same tests on Pixel 4a for cross-platform sanity check.

---

## Files to copy from MirkFall

These can be copied verbatim or with minimal adaptation:

| Source file | What it provides |
|-------------|-----------------|
| `assets/shaders/atmospheric_fog.frag` | The fog shader (copy as-is) |
| `lib/infrastructure/mirk/sdf/revealed_sdf_builder.dart` | SDF texture builder |
| `lib/domain/revealed/reveal_disc.dart` | RevealDisc domain type |
| `lib/domain/mirk/mirk_viewport_bbox.dart` | Viewport bbox type |
| `lib/infrastructure/mirk/tile_cell_iteration.dart` | `buildViewportFogClipPathFromDiscs` |
| `lib/infrastructure/mirk/mirk_projection.dart` | lat/lon ↔ screen projection |
| `lib/infrastructure/mirk/shader/fog_shader_uniforms.dart` | Uniform slot layout |
| `lib/infrastructure/mirk/animation_helpers.dart` | `triangleWave` for curl animation |
| `lib/infrastructure/mirk/wisp/wisp_particle_system.dart` | Wisp particles (optional) |
| `lib/config/constants.dart` | All `kMirkFog*` + `kMetersPerDegreeLat` + `kEarthRadiusMeters` |

---

## CI

Copy MirkFall's CI structure from `.github/workflows/ci.yml`. Both build targets are REQUIRED (not "if available"):

**Jobs:**
1. **Lint** (ubuntu-latest): `flutter analyze`, `dart format --line-length 160 --set-exit-if-changed`, `flutter test`
2. **Build iOS** (macos-latest): `flutter build ios --no-codesign` → upload unsigned IPA as artifact (for sideloading via SideStore)
3. **Build Android** (ubuntu-latest): `flutter build apk --debug` → upload APK as artifact

Both iOS and Android artifacts must be downloadable from the GitHub Actions run page. iOS is the primary artifact (used for real UAT walks). Android is a convenience build.

---

## What this POC does NOT need

- Database / Drift / migrations
- Session management
- Offline compaction
- Multiple mirk styles (atmospheric only)
- Burger menu / settings
- Country switching / download infrastructure
- Live tuner sheet
- MirkInitialRevealFade
- The MapView domain abstraction (just use flutter_map directly)

---

## Decision after POC

Based on **iOS UAT walk results**:

- **If fog tracks the map perfectly at 30+ fps on iOS**: migrate MirkFall from `maplibre_gl` to `flutter_map`. The animated fog is the product — correct behavior is non-negotiable.
- **If FPS is unacceptable (<20 fps during gestures on iOS)**: stay on `maplibre_gl` with the current iterations 1+2 state. Document BUG-014 combined zoom+pan displacement as a known limitation. Revisit when `flutter_gpu` ships to stable or `maplibre` FFI package gains custom layer support.
