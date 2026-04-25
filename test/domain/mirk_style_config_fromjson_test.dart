// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MirkStyleConfig.fromJson', () {
    test('rendererType="atmospheric" returns AtmosphericConfig', () {
      final cfg = MirkStyleConfig.fromJson(<String, Object?>{'rendererType': 'atmospheric', 'baseColorArgb': 0xFF123456, 'noiseScale': 0.75});
      expect(cfg, isA<AtmosphericConfig>());
      expect((cfg as AtmosphericConfig).baseColorArgb, 0xFF123456);
      expect(cfg.noiseScale, closeTo(0.75, 1e-9));
    });

    test('rendererType="shader" returns ShaderConfig', () {
      final cfg = MirkStyleConfig.fromJson(<String, Object?>{'rendererType': 'shader', 'shaderAssetPath': 'assets/shaders/fog.frag'});
      expect(cfg, isA<ShaderConfig>());
      expect((cfg as ShaderConfig).shaderAssetPath, 'assets/shaders/fog.frag');
    });

    test('unknown rendererType returns UnknownConfig with raw preserved', () {
      final cfg = MirkStyleConfig.fromJson(<String, Object?>{
        'rendererType': 'non-existent-future-renderer-v99',
        'foo': 'bar',
        'nested': <String, Object?>{'x': 1, 'y': 2},
      });
      expect(cfg, isA<UnknownConfig>());
      final raw = (cfg as UnknownConfig).raw;
      expect(raw['rendererType'], 'non-existent-future-renderer-v99');
      expect(raw['foo'], 'bar');
      expect(raw['nested'], <String, Object?>{'x': 1, 'y': 2});
    });

    test('missing rendererType returns UnknownConfig (fallback)', () {
      final cfg = MirkStyleConfig.fromJson(<String, Object?>{'someOtherField': 'value'});
      expect(cfg, isA<UnknownConfig>());
      final raw = (cfg as UnknownConfig).raw;
      expect(raw['someOtherField'], 'value');
    });

    test('from fixture payload (mirk_style_unknown_renderer.json) yields UnknownConfig', () {
      final filename = p.join(Directory.current.path, 'test', 'fixtures', 'json', 'mirk_style_unknown_renderer.json');
      final raw = jsonDecode(File(filename).readAsStringSync()) as Map<String, Object?>;
      // The fixture wraps the mirk style in an Envelope {schemaVersion,
      // type, payload}. At the payload level, `rendererType` sits at the
      // top and marks the unknown renderer.
      final payload = raw['payload'] as Map<String, Object?>;
      final cfg = MirkStyleConfig.fromJson(payload);
      expect(cfg, isA<UnknownConfig>());
      final preserved = (cfg as UnknownConfig).raw;
      expect(preserved['rendererType'], 'non-existent-future-renderer-v99');
      expect(preserved['displayName'], 'Unknown-renderer style');
    });

    test('exhaustive switch compiles on sealed union', () {
      // Phase 09 plan 09-02 extended the sealed union from 3 → 6 variants.
      // The exhaustive switch must now cover every variant; missing any one
      // produces a `non_exhaustive_switch` analyzer error at the call site.
      const MirkStyleConfig cfg = AtmosphericConfig();
      final String label = switch (cfg) {
        AtmosphericConfig() => 'atmospheric',
        SolidConfig() => 'solid',
        CandlelightConfig() => 'candlelight',
        HeavenlyCloudsConfig() => 'heavenly',
        ShaderConfig() => 'shader',
        UnknownConfig() => 'unknown',
      };
      expect(label, 'atmospheric');
    });

    test('round-trip: known config toJson fromJson is equal', () {
      const MirkStyleConfig original = AtmosphericConfig(baseColorArgb: 0xFFAABBCC, noiseScale: 0.33);
      final json = original.toJson();
      final restored = MirkStyleConfig.fromJson(json);
      expect(restored, original);
    });
  });
}
