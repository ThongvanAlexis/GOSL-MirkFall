// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/country_code.dart';

import 'geo/point_in_polygon.dart';

/// One ring of geographic coordinates (lat/lon tuples). Closed rings
/// (first == last) and implicitly-closed rings are both tolerated by
/// [pointInPolygon].
typedef CountryPolygonRing = List<({double lat, double lon})>;

/// Viewport-to-country resolver.
///
/// Given a viewport center (lat, lon) and zoom level, returns the alpha3
/// code of an installed country whose simplified polygon contains the
/// center, OR `null` when zoom is below [_kWorldFallbackZoomCutoff] or no
/// installed country matches (→ world-bundle fallback).
///
/// Inputs:
/// - `installedPolygons`: map from alpha3 → list of rings. Callers pass
///   the subset of per-country polygons corresponding to what is
///   currently installed on disk (the full `assets/maps/polygons/` set
///   has 249 rings and the viewport check would do 249 point-in-polygon
///   calls per update — wasteful when the user only has 3 countries).
/// - `viewport center + zoom`: the current `MapView.queryViewport()`
///   output.
///
/// Tie-breaking:
/// The Phase 07 Wave 0 polygon simplifier emits axis-aligned bounding
/// boxes (see 07-01 §Decisions). Neighbouring countries share boundary
/// longitudes — e.g. France + Germany overlap on the Rhine band. The
/// resolver iterates `installedPolygons` in insertion order and returns
/// the FIRST match. Callers that need deterministic iteration should
/// pass a `LinkedHashMap` seeded with the installed-order from the
/// manifest. Documented here because the behaviour is load-bearing for
/// UI consistency.
class CountryResolver {
  CountryResolver({required Map<CountryCode, List<CountryPolygonRing>> installedPolygons}) : _polygons = installedPolygons;

  final Map<CountryCode, List<CountryPolygonRing>> _polygons;

  /// Returns the installed alpha3 whose polygon contains `(lat, lon)`,
  /// or `null` for world fallback (zoom < [`kWorldFallbackZoomCutoff`]
  /// OR no polygon contains the centre).
  CountryCode? resolve({required double latitude, required double longitude, required double zoom}) {
    if (zoom < kWorldFallbackZoomCutoff) return null;
    if (_polygons.isEmpty) return null;

    for (final MapEntry<CountryCode, List<CountryPolygonRing>> entry in _polygons.entries) {
      for (final CountryPolygonRing ring in entry.value) {
        if (pointInPolygon(lat: latitude, lon: longitude, ring: ring)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Stream variant: debounces viewport updates and emits the resolved
  /// alpha3 (or `null`) for each settled viewport. The 500 ms debounce
  /// keeps the resolver off the main-thread hot path during continuous
  /// gesture panning.
  Stream<CountryCode?> resolveForViewportUpdates(
    Stream<({double latitude, double longitude, double zoom})> viewportUpdates, {
    Duration debounce = const Duration(milliseconds: 500),
  }) {
    late final StreamController<CountryCode?> out;
    late final StreamSubscription<({double latitude, double longitude, double zoom})> sub;
    Timer? debounceTimer;

    void fire(({double latitude, double longitude, double zoom}) v) {
      out.add(resolve(latitude: v.latitude, longitude: v.longitude, zoom: v.zoom));
    }

    out = StreamController<CountryCode?>(
      onListen: () {
        sub = viewportUpdates.listen(
          (v) {
            debounceTimer?.cancel();
            debounceTimer = Timer(debounce, () => fire(v));
          },
          onError: out.addError,
          onDone: () async {
            debounceTimer?.cancel();
            await out.close();
          },
        );
      },
      onCancel: () async {
        debounceTimer?.cancel();
        await sub.cancel();
      },
    );

    return out.stream;
  }
}

/// Loads polygon rings from the bundled asset tree.
///
/// Keeps the full asset tree optional at call time — the
/// Phase 07 Plan 07-04 controllers wire this loader only for currently
/// installed countries, not the full 249-country set.
///
/// The bundled files under `assets/maps/polygons/<alpha3>.geo.json` are
/// the output of `tool/simplify_polygons.dart` (Plan 07-01). Each file
/// is a GeoJSON `FeatureCollection` containing a single `Polygon` or
/// `MultiPolygon` feature with an `alpha3` property. Missing files
/// degrade gracefully (skipped, not fatal) — an uninstalled-but-listed
/// country simply drops out of the resolver's map, which matches the
/// "world fallback on no match" contract.
class CountryPolygonLoader {
  CountryPolygonLoader({PolygonAssetLoader? assetLoader}) : _assetLoader = assetLoader ?? _defaultAssetLoader;

  final PolygonAssetLoader _assetLoader;

  /// Loads polygons for the given [alpha3s] set. Unknown alpha3 codes
  /// and unparseable files are silently skipped.
  Future<Map<CountryCode, List<CountryPolygonRing>>> loadPolygonsForInstalled(Iterable<CountryCode> alpha3s) async {
    final Map<CountryCode, List<CountryPolygonRing>> result = <CountryCode, List<CountryPolygonRing>>{};
    for (final CountryCode code in alpha3s) {
      final String assetPath = '$kCountryPolygonsAssetPath/${code.value}.geo.json';
      try {
        final String raw = await _assetLoader(assetPath);
        final List<CountryPolygonRing> rings = _parseRings(raw);
        if (rings.isNotEmpty) {
          result[code] = rings;
        }
      } on Object {
        // Missing polygon file (e.g. reserved code with no geometry) is
        // non-fatal; skip this entry. The resolver falls back to world
        // bundle when no installed polygon matches.
        continue;
      }
    }
    return result;
  }

  /// Parses a raw GeoJSON FeatureCollection string into the list of
  /// rings expected by [CountryResolver]. Supports `Polygon` and
  /// `MultiPolygon` geometry types — both collapse to a flat list of
  /// exterior rings (holes are ignored, matching the Phase 07 Wave 0
  /// "no holes" decision).
  List<CountryPolygonRing> _parseRings(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return const <CountryPolygonRing>[];
    final Object? features = decoded['features'];
    if (features is! List) return const <CountryPolygonRing>[];

    final List<CountryPolygonRing> rings = <CountryPolygonRing>[];
    for (final Object? f in features) {
      if (f is! Map) continue;
      final Object? geom = f['geometry'];
      if (geom is! Map) continue;
      final Object? type = geom['type'];
      final Object? coords = geom['coordinates'];
      if (type == 'Polygon' && coords is List) {
        // Polygon = [ [[lon,lat], ...], [hole], ... ] — take the exterior (first) ring.
        if (coords.isNotEmpty && coords.first is List) {
          final CountryPolygonRing? ring = _coordsToRing(coords.first as List);
          if (ring != null) rings.add(ring);
        }
      } else if (type == 'MultiPolygon' && coords is List) {
        // MultiPolygon = [ [[[lon,lat], ...], [hole], ...], ... ] — each polygon contributes its exterior.
        for (final Object? poly in coords) {
          if (poly is List && poly.isNotEmpty && poly.first is List) {
            final CountryPolygonRing? ring = _coordsToRing(poly.first as List);
            if (ring != null) rings.add(ring);
          }
        }
      }
    }
    return rings;
  }

  CountryPolygonRing? _coordsToRing(List<Object?> coords) {
    final CountryPolygonRing ring = <({double lat, double lon})>[];
    for (final Object? pt in coords) {
      if (pt is! List || pt.length < 2) return null;
      final Object? lon = pt[0];
      final Object? lat = pt[1];
      if (lon is! num || lat is! num) return null;
      ring.add((lat: lat.toDouble(), lon: lon.toDouble()));
    }
    return ring;
  }
}

typedef PolygonAssetLoader = Future<String> Function(String path);

Future<String> _defaultAssetLoader(String path) => rootBundle.loadString(path);

/// Test-facing hook for [CountryPolygonLoader]. Keeps the asset-loader
/// injection out of the production ctor surface.
extension CountryPolygonLoaderTestSeam on CountryPolygonLoader {
  static CountryPolygonLoader withAssetLoader(Future<String> Function(String path) loader) {
    return CountryPolygonLoader(assetLoader: loader);
  }
}
