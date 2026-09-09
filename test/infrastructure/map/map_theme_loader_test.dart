// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:mirkfall/infrastructure/map/map_theme_loader.dart';
import 'package:mirkfall/infrastructure/map/style_layer_order.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

/// Asset bundle that serves the repository's real `assets/maps/style.json`
/// straight from disk (same idiom as `map_style_layer_order_test.dart`:
/// the JSON ships verbatim under the repo, no `rootBundle` needed).
class _FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final Uint8List bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

/// Asset bundle that serves a caller-provided string for every key —
/// used to inject a corrupted style without touching the real asset.
class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this._content);

  final String _content;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(utf8.encode(_content)));
}

/// The real style with its LAST layer dropped (5 layers instead of 6) —
/// the drift `assertStyleLayerOrder` must reject before `ThemeReader`.
String _styleWithLastLayerDropped() {
  final String raw = File(kStyleJsonAssetPath).readAsStringSync();
  final Map<String, Object?> parsed = Map<String, Object?>.from(jsonDecode(raw) as Map);
  final List<Object?> layers = List<Object?>.from(parsed['layers']! as List);
  layers.removeLast();
  parsed['layers'] = layers;
  return jsonEncode(parsed);
}

void main() {
  group('MapThemeLoader — real assets/maps/style.json', () {
    late MapThemeLoader loader;

    setUp(() {
      loader = MapThemeLoader(bundle: _FileAssetBundle());
    });

    test('load(MapThemeStandard) returns a Theme whose id, tileSources and layer count match the style contract', () async {
      final vtr.Theme theme = await loader.load(const MapThemeStandard());
      expect(theme.id, equals('mirkfall-standard'));
      expect(theme.tileSources, equals(<String>{kMapStyleSourceKey}), reason: 'TileProviders key MUST equal the single theme tile source');
      expect(theme.layers.length, equals(kStyleLayerOrder.length));
    });

    test('loaded layers carry no mirk_fog and follow kStyleLayerOrder exactly (C7: fog is a FlutterMap child, not a style layer)', () async {
      final vtr.Theme theme = await loader.load(const MapThemeStandard());
      final List<String> ids = <String>[for (final vtr.ThemeLayer layer in theme.layers) layer.id];
      expect(ids, isNot(contains('mirk_fog')));
      expect(ids, equals(kStyleLayerOrder));
    });

    test('load() twice for the same MapTheme returns the identical cached Future and the identical Theme', () async {
      final Future<vtr.Theme> first = loader.load(const MapThemeStandard());
      final Future<vtr.Theme> second = loader.load(const MapThemeStandard());
      expect(identical(first, second), isTrue, reason: 'the Future is memoised per MapTheme — building a Theme per build is the POC anti-pattern n°1');
      expect(identical(await first, await second), isTrue);
    });

    test('load(MapThemeRpgParchment) is PROVISIONALLY the standard style (Phase 13 ships the second JSON)', () async {
      final vtr.Theme theme = await loader.load(const MapThemeRpgParchment());
      expect(theme.id, equals('mirkfall-standard'));
      expect(theme.layers.length, equals(kStyleLayerOrder.length));
    });

    test('assetPathFor maps both themes onto kStyleJsonAssetPath today', () {
      expect(MapThemeLoader.assetPathFor(const MapThemeStandard()), equals(kStyleJsonAssetPath));
      expect(MapThemeLoader.assetPathFor(const MapThemeRpgParchment()), equals(kStyleJsonAssetPath));
    });
  });

  group('MapThemeLoader — corrupted style', () {
    test('a style whose layers drift from kStyleLayerOrder throws MapStyleCorruptException before ThemeReader runs', () async {
      final MapThemeLoader loader = MapThemeLoader(bundle: _StringAssetBundle(_styleWithLastLayerDropped()));
      await expectLater(loader.load(const MapThemeStandard()), throwsA(isA<MapStyleCorruptException>()));
    });

    test('a failed load is NOT cached — the next load() retries the bundle', () async {
      final MapThemeLoader loader = MapThemeLoader(bundle: _StringAssetBundle(_styleWithLastLayerDropped()));
      final Future<vtr.Theme> first = loader.load(const MapThemeStandard());
      await expectLater(first, throwsA(isA<MapStyleCorruptException>()));
      final Future<vtr.Theme> second = loader.load(const MapThemeStandard());
      expect(identical(first, second), isFalse);
      await expectLater(second, throwsA(isA<MapStyleCorruptException>()));
    });
  });

  group('kStyleLayerOrder — Phase 09.1 shape', () {
    test('declares the 6 frozen layers, background first, pois last, no mirk_fog', () {
      expect(kStyleLayerOrder, equals(<String>['background', 'landcover', 'water', 'boundaries', 'roads', 'pois']));
    });
  });
}
