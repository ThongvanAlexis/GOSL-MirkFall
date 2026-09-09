// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

/// Loads `assets/maps/style.json` and compiles it into a [vtr.Theme].
///
/// RED skeleton (09.1-02 Task 1): compiles so `flutter analyze` stays
/// green, fails every behaviour test at runtime. Replaced by the real
/// implementation in the GREEN commit.
class MapThemeLoader {
  MapThemeLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Asset path backing [theme].
  static String assetPathFor(MapTheme theme) => kStyleJsonAssetPath;

  /// Compiles the style for [theme].
  Future<vtr.Theme> load(MapTheme theme) async {
    await _bundle.loadString(assetPathFor(theme));
    throw UnimplementedError('MapThemeLoader.load — implemented in the GREEN step of 09.1-02 Task 1');
  }
}
