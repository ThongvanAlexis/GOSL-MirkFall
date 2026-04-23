# infrastructure/map/

MapLibre-bound map infrastructure. **The ONLY directory allowed to `import 'package:maplibre_gl/...'`.** Enforced by `tool/check_avoid_maplibre_leak.dart` (MAP-06 CI gate).

Every other `lib/` module consumes the [`MapView`](../../domain/map/map_view.dart) port (plain MirkFall vocabulary, zero MapLibre types). If you need anything from `maplibre_gl` outside this directory, you need a new method on `MapView` instead.

## Contents

| File | Role |
|------|------|
| `maplibre_map_view.dart` | Concrete `MapView` adapter. The sole `import 'package:maplibre_gl/maplibre_gl.dart'` consumer. |
| `pmtiles_source.dart` | Runtime URI resolver: `CountryCode?` → `pmtiles://file:///<path>`. Never emits remote URIs (MAP-05). Includes the top-level `localPmtilesUri()` helper. |
| `style_rewriter.dart` | Loads `assets/maps/style.json`, substitutes `YOUR_PMTILES_PATH_PLACEHOLDER` with the resolved PMTiles URI. Returns raw JSON for `setStyle`. |
| `style_layer_order.dart` | Frozen 7-layer constant + two validators (`assertStyleLayerOrder`, `assertStyleLayerValidity`). Pure Dart. |
| `country_resolver.dart` | Viewport-center → alpha3 lookup via point-in-polygon + `CountryPolygonLoader` for the bundled GeoJSONs. |
| `first_launch_world_copier.dart` | MAP-07 non-deletable floor: copies `assets/maps/world.pmtiles` → `<app_support>/maps/world.pmtiles` with sha256 verify + auto-heal. |
| `geo/point_in_polygon.dart` | Hand-rolled Rosetta-style ray-cast primitive. |

## Phase 09 handoff note — `mirk_fog` + `RepaintBoundary`

Phase 07 ships `mirk_fog` as a transparent `background` layer in `assets/maps/style.json` — it paints nothing, so no Flutter-level `RepaintBoundary` is required around the map surface in this phase.

Phase 09 (mirk renderer) will:

1. Replace the `mirk_fog` layer with a real `fill`-from-GeoJSON layer wired to the MirkRenderer source, AND
2. Own the `RepaintBoundary` wrapping of the fog surface when the overlay actually paints.

The `MapLibreMapView` adapter **intentionally does NOT create a `RepaintBoundary` at the widget level** — that responsibility belongs to the Phase 09 owner of the fog render pass. Do not add one pre-emptively; it would mask a Phase 09 design decision.

## Why PMTiles URIs always stay local

MirkFall's V1.0 promise is zero network for map tiles, ever. Every URI produced by `PmtilesSource` flows through `localPmtilesUri()` which emits `pmtiles://file:///<abs path>` — never `pmtiles://http(s)`. The `tool/check_avoid_remote_pmtiles.dart` CI gate scans `lib/`, `test/`, and `assets/` for the forbidden `pmtiles://http` pattern on every push.
