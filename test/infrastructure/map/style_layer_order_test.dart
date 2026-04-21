// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/infrastructure/map/style_layer_order.dart';
import 'package:test/test.dart';

void main() {
  group('kStyleLayerOrder — constant invariants', () {
    test('declares exactly 8 layer IDs', () {
      expect(kStyleLayerOrder.length, 8);
    });

    test('first layer is background, last is user_location', () {
      expect(kStyleLayerOrder.first, 'background');
      expect(kStyleLayerOrder.last, 'user_location');
    });

    test('mirk_fog is at the z-index immediately below user_location', () {
      final int mirkIdx = kStyleLayerOrder.indexOf('mirk_fog');
      final int userIdx = kStyleLayerOrder.indexOf('user_location');
      expect(mirkIdx, isNonNegative);
      expect(userIdx, mirkIdx + 1);
    });
  });

  group('assertStyleLayerOrder — real asset', () {
    test('assets/maps/style.json matches kStyleLayerOrder exactly', () {
      final String styleJson = File('assets/maps/style.json').readAsStringSync();
      expect(() => assertStyleLayerOrder(styleJson), returnsNormally);
    });
  });

  group('assertStyleLayerOrder — seeded violations', () {
    test('throws when a layer is missing', () {
      final Map<String, Object?> style = <String, Object?>{
        'version': 8,
        'sources': <String, Object?>{},
        'layers': <Map<String, Object?>>[
          for (final String id in kStyleLayerOrder.take(7)) <String, Object?>{'id': id, 'type': 'background'},
        ],
      };
      expect(() => assertStyleLayerOrder(jsonEncode(style)), throwsA(isA<MapStyleCorruptException>()));
    });

    test('throws when a layer is extra', () {
      final Map<String, Object?> style = <String, Object?>{
        'version': 8,
        'sources': <String, Object?>{},
        'layers': <Map<String, Object?>>[
          for (final String id in kStyleLayerOrder) <String, Object?>{'id': id, 'type': 'background'},
          <String, Object?>{'id': 'ghost', 'type': 'background'},
        ],
      };
      expect(() => assertStyleLayerOrder(jsonEncode(style)), throwsA(isA<MapStyleCorruptException>()));
    });

    test('throws when layer order is wrong', () {
      final List<String> reordered = List<String>.from(kStyleLayerOrder);
      final String tmp = reordered[0];
      reordered[0] = reordered[1];
      reordered[1] = tmp;
      final Map<String, Object?> style = <String, Object?>{
        'version': 8,
        'sources': <String, Object?>{},
        'layers': <Map<String, Object?>>[
          for (final String id in reordered) <String, Object?>{'id': id, 'type': 'background'},
        ],
      };
      expect(() => assertStyleLayerOrder(jsonEncode(style)), throwsA(isA<MapStyleCorruptException>()));
    });

    test('throws on invalid JSON', () {
      expect(() => assertStyleLayerOrder('not json'), throwsA(isA<MapStyleCorruptException>()));
    });

    test('throws when root is not an object', () {
      expect(() => assertStyleLayerOrder('[]'), throwsA(isA<MapStyleCorruptException>()));
    });
  });

  group('assertStyleLayerValidity — real asset', () {
    test('assets/maps/style.json passes the per-layer validity check', () {
      final String styleJson = File('assets/maps/style.json').readAsStringSync();
      expect(() => assertStyleLayerValidity(styleJson), returnsNormally);
    });
  });

  group('assertStyleLayerValidity — seeded violations', () {
    String buildStyleWithLayers(List<Map<String, Object?>> layers) {
      return jsonEncode(<String, Object?>{
        'version': 8,
        'sources': <String, Object?>{
          'mirkfall_map': <String, Object?>{'type': 'vector', 'url': 'pmtiles://file:///test.pmtiles'},
        },
        'layers': layers,
      });
    }

    test('fill layer without source throws', () {
      final String styleJson = buildStyleWithLayers(<Map<String, Object?>>[
        <String, Object?>{'id': 'naughty', 'type': 'fill'}, // missing source
      ]);
      expect(() => assertStyleLayerValidity(styleJson), throwsA(isA<MapStyleCorruptException>()));
    });

    test('fill layer with source but no source-layer on a vector source throws', () {
      final String styleJson = buildStyleWithLayers(<Map<String, Object?>>[
        <String, Object?>{'id': 'naughty', 'type': 'fill', 'source': 'mirkfall_map'}, // missing source-layer
      ]);
      expect(() => assertStyleLayerValidity(styleJson), throwsA(isA<MapStyleCorruptException>()));
    });

    test('background layer with stray source throws', () {
      final String styleJson = buildStyleWithLayers(<Map<String, Object?>>[
        <String, Object?>{'id': 'naughty', 'type': 'background', 'source': 'mirkfall_map'},
      ]);
      expect(() => assertStyleLayerValidity(styleJson), throwsA(isA<MapStyleCorruptException>()));
    });

    test('layer referring to an undeclared source throws', () {
      final String styleJson = jsonEncode(<String, Object?>{
        'version': 8,
        'sources': <String, Object?>{
          'mirkfall_map': <String, Object?>{'type': 'vector', 'url': 'pmtiles://file:///test.pmtiles'},
        },
        'layers': <Map<String, Object?>>[
          <String, Object?>{'id': 'naughty', 'type': 'fill', 'source': 'does_not_exist', 'source-layer': 'landcover'},
        ],
      });
      expect(() => assertStyleLayerValidity(styleJson), throwsA(isA<MapStyleCorruptException>()));
    });

    test('valid background-only layer passes', () {
      final String styleJson = buildStyleWithLayers(<Map<String, Object?>>[
        <String, Object?>{'id': 'ok', 'type': 'background'},
      ]);
      expect(() => assertStyleLayerValidity(styleJson), returnsNormally);
    });

    test('valid fill layer with source + source-layer passes', () {
      final String styleJson = buildStyleWithLayers(<Map<String, Object?>>[
        <String, Object?>{'id': 'ok', 'type': 'fill', 'source': 'mirkfall_map', 'source-layer': 'landcover'},
      ]);
      expect(() => assertStyleLayerValidity(styleJson), returnsNormally);
    });
  });
}
