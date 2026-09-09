# infrastructure/map/

flutter_map-bound map infrastructure. **The ONLY directory allowed to import the map engine** (`flutter_map`, `latlong2`, `vector_map_tiles`, `vector_map_tiles_pmtiles`, `vector_tile_renderer`, `pmtiles`) — plus the three allow-listed presentation files of the FogLayer boundary. Enforced by `tool/check_avoid_flutter_map_leak.dart` (MAP-06 CI gate, Phase 09.1).

Every other `lib/` module consumes the [`MapView`](../../domain/map/map_view.dart) port (plain MirkFall vocabulary, zero engine types). If you need anything from the engine outside this directory, you need a new method on `MapView` instead.

## Contents

| File | Role |
|------|------|
| `flutter_map_map_view.dart` | `FlutterMapMapViewWidget` + the private `_FlutterMapMapViewAdapter` (concrete `MapView`). The sole place instantiating `FlutterMap` / `MapController` / `MapOptions` / `VectorTileLayer`. Publishes the adapter from `MapOptions.onMapReady`; hot-swaps the PMTiles archive on `showMap`; renders the user puck as a `CircleLayer`; mounts caller-provided `fogLayers` between tiles and puck (same canvas — plan 09.1-07). |
| `map_theme_loader.dart` | `assets/maps/style.json` → `vector_tile_renderer` `Theme`, compiled once per `MapTheme` after `assertStyleLayerOrder` / `assertStyleLayerValidity`. |
| `pmtiles_source.dart` | `CountryCode?` → absolute archive path (`p.join`). Never emits a URL (MAP-05); `pmtiles 1.2.0` opens any non-`http(s)` source with a local `FileAt` reader. |
| `style_layer_order.dart` | Frozen 6-layer constant + two validators (`assertStyleLayerOrder`, `assertStyleLayerValidity`). Pure Dart. |
| `country_resolver.dart` | Viewport-center → alpha3 lookup via point-in-polygon + `CountryPolygonLoader` for the bundled GeoJSONs. |
| `first_launch_world_copier.dart` | MAP-07 non-deletable floor: copies `assets/maps/world.pmtiles` → `<app_support>/maps/world.pmtiles` with sha256 verify + auto-heal. |
| `geo/point_in_polygon.dart` | Hand-rolled Rosetta-style ray-cast primitive. |

## Fog on the same canvas (Phase 09.1)

The fog of war is NOT a style layer (the Phase 07 `mirk_fog` background layer is gone — `ThemeReader` ignores `background-opacity` and would paint the map black). Plan 09.1-07 mounts the `FogLayer` widget through `FlutterMapMapViewWidget.fogLayers`, i.e. as a child of the SAME `FlutterMap` as the `VectorTileLayer`: it reads the same `MapCamera` snapshot as the tiles, which is the BUG-014 fix. Do NOT wrap the fog in a `RepaintBoundary` inside the map: it would isolate it from the tile repaint signal and reintroduce a one-frame lag.

## Hot-swap + cache isolation

`showMap(country)` resolves the archive path, opens a new `PmTilesVectorTileProvider`, re-keys the `VectorTileLayer` (`ValueKey('<archive>/<theme id>')`) and closes the previous archive only after the new layer is mounted (post-frame). The vector_map_tiles file cache lives in one sub-directory per archive under `<temp>/.vector_map/` because its tile key does not carry the archive identity.

## Why PMTiles access always stays local

MirkFall's V1.0 promise is zero network for map tiles, ever. `PmtilesSource` only ever returns `p.join(appSupportDir, …)` paths, and the adapter hands them to `PmTilesVectorTileProvider.fromSource(path)`. The `tool/check_avoid_remote_pmtiles.dart` CI gate scans `lib/`, `test/`, and `assets/` for `pmtiles://http[s]`, `PmTilesArchive.fromUri(` and `fromSource('http…')` on every push.
