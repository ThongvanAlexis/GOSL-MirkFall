// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';

import 'package:mirkfall/domain/map/map_errors.dart';

/// Frozen layer order for `assets/maps/style.json` (Plan 07-01).
///
/// Every layer ID appears in this list in the same order as on disk.
/// Phase 09 (mirk rendering) and Phase 11 (POI icons) may tune paint
/// properties of existing layers but MUST NOT reorder the list — the
/// z-index contract downstream renderers (MirkRenderer) depends on is
/// defined HERE.
///
/// The paired helpers [assertStyleLayerOrder] + [assertStyleLayerValidity]
/// enforce the shape at style-load time. Unit tests (Plan 07-03
/// `test/infrastructure/map/style_layer_order_test.dart`) drive the real
/// asset through them to guard against silent drift between shipped
/// style.json and this constant.
///
/// Phase 07-07 device-smoke (2026-04-22) — removed the `user_location`
/// circle layer. The blue dot is rendered via maplibre_gl's built-in
/// `addCircle` annotation manager (see `MapView.setUserLocation` in the
/// domain port + the adapter at
/// `lib/infrastructure/map/maplibre_map_view.dart`), NOT via a style
/// layer. The removed layer declared `source-layer: user_location`
/// against the Protomaps PMTiles source, which does NOT carry that
/// source-layer — a silently-missing vector source-layer that was
/// suspected of triggering a C++ throw in MapLibre Native iOS 6.14.0
/// during first query after style load (same frame address as the
/// `Runner-2026-04-22-*.ips` crash). Probe commit: if the iOS crash
/// disappears, the `user_location` layer was the root cause.
const List<String> kStyleLayerOrder = <String>['background', 'landcover', 'water', 'boundaries', 'roads', 'pois', 'mirk_fog'];

/// Validates that [styleJson] declares exactly the layers in
/// [kStyleLayerOrder], in the same order.
///
/// Throws [MapStyleCorruptException] with a structured reason on any
/// mismatch — missing layer, extra layer, reordered list. The reason
/// embeds the expected + actual sequences so the log line is actionable.
///
/// Pure-Dart implementation — consumes the raw style JSON string (as
/// MapLibre styles are passed to `setStyle`) rather than a parsed map
/// so the helper can be reused from any caller (production style loader,
/// unit tests, tooling scripts).
void assertStyleLayerOrder(String styleJson) {
  final List<String> actualIds = <String>[for (final _LayerRef ref in _iterateStyleLayers(styleJson)) ref.id];

  if (actualIds.length != kStyleLayerOrder.length) {
    throw MapStyleCorruptException(
      reason: 'style.layers count mismatch: expected=${kStyleLayerOrder.length}, actual=${actualIds.length} — expected=$kStyleLayerOrder actual=$actualIds',
    );
  }
  for (int i = 0; i < kStyleLayerOrder.length; i++) {
    if (actualIds[i] != kStyleLayerOrder[i]) {
      throw MapStyleCorruptException(
        reason: 'style.layers[$i] id mismatch: expected="${kStyleLayerOrder[i]}", actual="${actualIds[i]}" — full expected=$kStyleLayerOrder actual=$actualIds',
      );
    }
  }
}

/// Validates per-layer structural shape (MapLibre-style "layer type
/// required fields" contract).
///
/// Guards against silent style-rejection at MapLibre runtime — MapLibre
/// Native will silently drop a malformed layer on some platforms rather
/// than crash, leaving the user with a partially-rendered map and no
/// user-visible error. This helper catches the common authoring mistakes
/// (forgotten `source`, stray `source-layer` on a background layer) at
/// style-load time so a corrupted style is surfaced as a
/// [MapStyleCorruptException] instead.
///
/// Rules enforced:
/// - Every layer MUST have a string `id` and a string `type`.
/// - `background` layers MUST NOT declare `source` or `source-layer`.
/// - `fill`, `fill-extrusion`, `line`, `symbol`, `circle`, `heatmap`
///   layers MUST declare a string `source`.
/// - `raster` layers MUST declare a string `source` (but NOT
///   `source-layer`; raster sources don't carry source layers).
/// - For layers declaring `source`: the source must exist in the
///   top-level `sources` dict. When that source's `type` is `vector`,
///   the layer MUST also declare a non-empty `source-layer` string.
void assertStyleLayerValidity(String styleJson) {
  final Map<String, Object?> parsed = _parseStyleOrThrow(styleJson);
  final Map<String, Object?> sources = _requireMap(parsed, 'sources', 'style.sources');

  for (final _LayerRef ref in _iterateStyleLayers(styleJson, parsed: parsed)) {
    final Map<Object?, Object?> raw = ref.raw;
    final String id = ref.id;
    final String type = _requireString(raw, 'type', 'style.layers[$id].type');

    switch (type) {
      case 'background':
        if (raw.containsKey('source')) {
          throw MapStyleCorruptException(
            reason: 'style.layers[$id] (type=background) MUST NOT declare "source" — background layers paint to the entire map surface',
          );
        }
        if (raw.containsKey('source-layer')) {
          throw MapStyleCorruptException(reason: 'style.layers[$id] (type=background) MUST NOT declare "source-layer"');
        }
        break;

      case 'fill':
      case 'fill-extrusion':
      case 'line':
      case 'symbol':
      case 'circle':
      case 'heatmap':
      case 'raster':
        final String sourceId = _requireString(raw, 'source', 'style.layers[$id] (type=$type).source');
        final Object? sourceDef = sources[sourceId];
        if (sourceDef == null) {
          throw MapStyleCorruptException(reason: 'style.layers[$id].source="$sourceId" does not exist in style.sources');
        }
        if (sourceDef is! Map) {
          throw MapStyleCorruptException(reason: 'style.sources["$sourceId"] is not a JSON object');
        }
        final Object? sourceType = sourceDef['type'];
        if (sourceType == 'vector' && type != 'raster') {
          // Raster layers on vector sources are a MapLibre edge case; we
          // only enforce source-layer for the vector-layer types we ship.
          final String sourceLayer = _requireString(raw, 'source-layer', 'style.layers[$id] (type=$type, source=vector).source-layer');
          if (sourceLayer.isEmpty) {
            throw MapStyleCorruptException(reason: 'style.layers[$id] (type=$type, source=vector).source-layer is empty');
          }
        }
        break;

      default:
        // Unknown layer type — MapLibre supports more types (sky,
        // hillshade, etc.) but we don't ship any in Phase 07. Tolerate
        // rather than fail, so the helper degrades gracefully if a later
        // phase introduces a new type.
        break;
    }
  }
}

/// A single style.layers[i] entry after basic shape validation —
/// guarantees the entry is a JSON object with a string `id`. Shared by
/// [assertStyleLayerOrder] (order check) and [assertStyleLayerValidity]
/// (per-type shape check) so the parse + iterate + shape-guard path
/// exists exactly once.
class _LayerRef {
  _LayerRef({required this.index, required this.id, required this.raw});

  final int index;
  final String id;
  final Map<Object?, Object?> raw;
}

/// Parses [styleJson] (or reuses an already-parsed [parsed] map) and
/// yields each `style.layers[i]` entry as a [_LayerRef]. Throws
/// [MapStyleCorruptException] for any malformed entry.
Iterable<_LayerRef> _iterateStyleLayers(String styleJson, {Map<String, Object?>? parsed}) sync* {
  final Map<String, Object?> root = parsed ?? _parseStyleOrThrow(styleJson);
  final Object? rawLayers = root['layers'];
  if (rawLayers is! List) {
    throw const MapStyleCorruptException(reason: 'style.layers must be an array');
  }
  for (int i = 0; i < rawLayers.length; i++) {
    final Object? raw = rawLayers[i];
    if (raw is! Map) {
      throw MapStyleCorruptException(reason: 'style.layers[$i] is not a JSON object');
    }
    final Object? id = raw['id'];
    if (id is! String) {
      throw MapStyleCorruptException(reason: 'style.layers[$i].id must be a string');
    }
    yield _LayerRef(index: i, id: id, raw: raw);
  }
}

Map<String, Object?> _parseStyleOrThrow(String styleJson) {
  Object? decoded;
  try {
    decoded = jsonDecode(styleJson);
  } on FormatException catch (e) {
    throw MapStyleCorruptException(reason: 'style.json is not valid JSON: ${e.message}');
  }
  if (decoded is! Map) {
    throw const MapStyleCorruptException(reason: 'style.json root must be a JSON object');
  }
  return Map<String, Object?>.from(decoded);
}

Map<String, Object?> _requireMap(Map<Object?, Object?> src, String key, String path) {
  final Object? v = src[key];
  if (v is! Map) {
    throw MapStyleCorruptException(reason: '$path must be a JSON object');
  }
  return Map<String, Object?>.from(v);
}

String _requireString(Map<Object?, Object?> src, String key, String path) {
  final Object? v = src[key];
  if (v is! String) {
    throw MapStyleCorruptException(reason: '$path must be a string');
  }
  return v;
}
