// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'style_layer_order.dart';

/// Loads `assets/maps/style.json` and compiles it into a [vtr.Theme] via
/// `ThemeReader`, exactly once per [MapTheme].
///
/// Building a `Theme` on every widget build is the POC's anti-pattern
/// n°1 (rebuild churn dominates at z15), so the compiled theme is
/// memoised per theme for the loader's lifetime. Replaces the Phase 07
/// style rewriter: there is no URI rewriting any more — the PMTiles
/// path goes straight to the tile provider, the style is static.
///
/// Validation runs BEFORE `ThemeReader`: layer order + per-layer shape
/// (`assertStyleLayerOrder` / `assertStyleLayerValidity`) surface a
/// corrupted asset as [MapStyleCorruptException] instead of letting the
/// renderer silently drop layers.
class MapThemeLoader {
  MapThemeLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static final Logger _log = Logger('infrastructure.map.theme');

  final AssetBundle _bundle;

  /// Memoised compile per theme, keyed by [MapTheme.toJsonString] so a
  /// non-const `MapThemeStandard()` instance hits the same entry as the
  /// canonical const one.
  final Map<String, Future<vtr.Theme>> _themeFutureByThemeKey = <String, Future<vtr.Theme>>{};

  /// Asset path backing [theme]. `rpgParchment` points at the standard
  /// style until Phase 13 ships the second JSON — `setTheme` has no
  /// caller today (09.1-RESEARCH Open Question 7).
  static String assetPathFor(MapTheme theme) => switch (theme) {
    MapThemeStandard() => kStyleJsonAssetPath,
    MapThemeRpgParchment() => kStyleJsonAssetPath,
  };

  /// Returns the compiled theme for [theme], loading it on first call.
  /// A failed load is evicted so a later call retries the bundle.
  Future<vtr.Theme> load(MapTheme theme) {
    final String key = theme.toJsonString();
    return _themeFutureByThemeKey.putIfAbsent(key, () => _loadUncached(theme, key));
  }

  Future<vtr.Theme> _loadUncached(MapTheme theme, String cacheKey) async {
    try {
      final String raw = await _bundle.loadString(assetPathFor(theme));
      assertStyleLayerOrder(raw);
      assertStyleLayerValidity(raw);
      // `dynamic` justified: boundary with the third-party
      // `ThemeReader.read(Map<String, dynamic>)` — `jsonDecode` returns
      // `dynamic` and the renderer requires that exact map type (Pitfall 11).
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      final vtr.Theme compiled = vtr.ThemeReader().read(json);
      _log.info('MapThemeLoader.load(${theme.toJsonString()}): theme "${compiled.id}" compiled, ${compiled.layers.length} layer(s)');
      return compiled;
    } on MapStyleCorruptException catch (e, st) {
      _themeFutureByThemeKey.remove(cacheKey);
      _log.severe('MapThemeLoader.load(${theme.toJsonString()}): style corrupt — ${e.reason}', e, st);
      rethrow;
    } on Object {
      _themeFutureByThemeKey.remove(cacheKey);
      rethrow;
    }
  }
}
