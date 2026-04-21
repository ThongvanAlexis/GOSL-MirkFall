// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/map/style_layer_order.dart';

/// Regression guard: asserts that `assets/maps/style.json` declares the
/// 8 layers in the exact order frozen by Plan 07-01.
///
/// This test catches any silent drift in the shipped style before the
/// Phase 09 mirk renderer (which depends on the layer z-index contract)
/// lands. Consumes the raw asset via `File.readAsStringSync` — no need
/// for `rootBundle` because the JSON ships verbatim under the repo
/// filesystem.
void main() {
  test('assets/maps/style.json declares exactly the 8 frozen layers in order', () {
    final File styleFile = File('assets/maps/style.json');
    expect(styleFile.existsSync(), isTrue, reason: 'assets/maps/style.json missing — Phase 07-01 asset not in repo');
    final String raw = styleFile.readAsStringSync();

    // assertStyleLayerOrder throws MapStyleCorruptException on any
    // mismatch — wrap in a try/catch with a deliberate test-level
    // message so a drift failure points straight at this guard.
    expect(() => assertStyleLayerOrder(raw), returnsNormally);
  });

  test('kStyleLayerOrder matches the hand-defined Phase 07-01 order', () {
    expect(kStyleLayerOrder, equals(<String>['background', 'landcover', 'water', 'boundaries', 'roads', 'pois', 'mirk_fog', 'user_location']));
  });

  test('style.json + kStyleLayerOrder: same count + same IDs', () {
    final File styleFile = File('assets/maps/style.json');
    final Map<String, Object?> parsed = Map<String, Object?>.from(jsonDecode(styleFile.readAsStringSync()) as Map);
    final List<Object?> rawLayers = parsed['layers'] as List<Object?>;
    final List<String> actualIds = <String>[];
    for (final Object? raw in rawLayers) {
      final Map<Object?, Object?> layerMap = raw as Map<Object?, Object?>;
      actualIds.add(layerMap['id']! as String);
    }
    expect(actualIds, equals(kStyleLayerOrder));
  });
}
