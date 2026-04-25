// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-02 Task 2 RED test suite:
//
// Drives the extension of [MirkStyleConfig] sealed union from 3 variants
// (Phase 03: atmospheric / shader / unknown) to 6 variants
// (Phase 09: + solid / candlelight / heavenly).
//
// Tests are written BEFORE the production rewrite — initial run fails
// (the new factories don't exist), turns green once the Freezed regen
// lands. Uses `package:test` (pure Dart) — sealed-union JSON round-trip
// has no Flutter dependency.

import 'dart:convert';
import 'dart:io';

import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('09-02 — MirkStyleConfig.atmospheric (extended params)', () {
    test('legacy 2-param call still constructs (Phase 03 caller compatibility)', () {
      const cfg = AtmosphericConfig(baseColorArgb: 0xFF112233, noiseScale: 0.4);
      expect(cfg.baseColorArgb, 0xFF112233);
      expect(cfg.noiseScale, 0.4);
    });

    test('extended params have sensible defaults', () {
      const cfg = AtmosphericConfig();
      expect(cfg.baseColorArgb, 0xFF000000);
      expect(cfg.noiseScale, closeTo(0.5, 1e-9));
      expect(cfg.noiseSpeed, closeTo(0.05, 1e-9));
      expect(cfg.driftDirectionDeg, 0.0);
      expect(cfg.densityBaselineAlpha, closeTo(0.99, 1e-9));
      expect(cfg.featherRadiusFraction, closeTo(0.1, 1e-9));
      expect(cfg.edgeSoftness, closeTo(0.5, 1e-9));
      expect(cfg.secondaryColorArgb, isNull);
    });

    test('atmospheric round-trips fromJson(toJson())', () {
      const original = AtmosphericConfig(baseColorArgb: 0xFF445566, noiseScale: 0.7, noiseSpeed: 0.12, driftDirectionDeg: 45.0, secondaryColorArgb: 0xFFAABBCC);
      final json = original.toJson();
      final restored = MirkStyleConfig.fromJson(json);
      expect(restored, original);
    });
  });

  group('09-02 — MirkStyleConfig.solid (new variant)', () {
    test('constructs with defaults', () {
      const cfg = SolidConfig();
      expect(cfg.colorArgb, 0xFF1A1A1A);
      expect(cfg.baselineAlpha, closeTo(0.99, 1e-9));
    });

    test('round-trips fromJson(toJson())', () {
      const original = SolidConfig(colorArgb: 0xFF334455, baselineAlpha: 0.85);
      final json = original.toJson();
      final restored = MirkStyleConfig.fromJson(json);
      expect(restored, isA<SolidConfig>());
      expect(restored, original);
    });

    test('JSON discriminator is "solid"', () {
      const original = SolidConfig();
      final json = original.toJson();
      expect(json['rendererType'], 'solid');
    });
  });

  group('09-02 — MirkStyleConfig.candlelight (new variant)', () {
    test('constructs with defaults', () {
      const cfg = CandlelightConfig();
      expect(cfg.centerColorArgb, 0xFFFF8F6A);
      expect(cfg.peripheryColorArgb, 0xFFC2542E);
      expect(cfg.noiseScale, closeTo(0.8, 1e-9));
      expect(cfg.noiseSpeed, closeTo(0.1, 1e-9));
      expect(cfg.baselineAlpha, closeTo(0.85, 1e-9));
      expect(cfg.featherRadiusFraction, closeTo(0.1, 1e-9));
    });

    test('round-trips fromJson(toJson())', () {
      const original = CandlelightConfig(centerColorArgb: 0xFFFF0000, peripheryColorArgb: 0xFF880000, noiseScale: 0.9);
      final json = original.toJson();
      final restored = MirkStyleConfig.fromJson(json);
      expect(restored, isA<CandlelightConfig>());
      expect(restored, original);
    });

    test('JSON discriminator is "candlelight"', () {
      const original = CandlelightConfig();
      final json = original.toJson();
      expect(json['rendererType'], 'candlelight');
    });
  });

  group('09-02 — MirkStyleConfig.heavenly (new variant)', () {
    test('constructs with defaults', () {
      const cfg = HeavenlyCloudsConfig();
      expect(cfg.colorArgb, 0xFFE8E8EE);
      expect(cfg.noiseScale, closeTo(0.3, 1e-9));
      expect(cfg.noiseSpeed, closeTo(0.08, 1e-9));
      expect(cfg.driftDirectionDeg, closeTo(45.0, 1e-9));
      expect(cfg.baselineAlpha, closeTo(0.80, 1e-9));
    });

    test('round-trips fromJson(toJson())', () {
      const original = HeavenlyCloudsConfig(colorArgb: 0xFFAABBCC, noiseScale: 0.4, driftDirectionDeg: 90.0);
      final json = original.toJson();
      final restored = MirkStyleConfig.fromJson(json);
      expect(restored, isA<HeavenlyCloudsConfig>());
      expect(restored, original);
    });

    test('JSON discriminator is "heavenly" (NOT "heavenly_clouds")', () {
      const original = HeavenlyCloudsConfig();
      final json = original.toJson();
      expect(json['rendererType'], 'heavenly');
    });
  });

  group('09-02 — Phase 03 variants unchanged', () {
    test('shader still constructs and round-trips', () {
      const original = ShaderConfig(shaderAssetPath: 'assets/shaders/fog.frag');
      final json = original.toJson();
      final restored = MirkStyleConfig.fromJson(json);
      expect(restored, isA<ShaderConfig>());
      expect(restored, original);
    });

    test('unknown rendererType still falls back to UnknownConfig', () {
      final cfg = MirkStyleConfig.fromJson(<String, Object?>{'rendererType': 'totally-made-up-future-renderer-v99', 'foo': 'bar'});
      expect(cfg, isA<UnknownConfig>());
      final raw = (cfg as UnknownConfig).raw;
      expect(raw['rendererType'], 'totally-made-up-future-renderer-v99');
      expect(raw['foo'], 'bar');
    });
  });

  group('09-02 — exhaustive sealed switch over 6 variants', () {
    test('switch on AtmosphericConfig yields "atmospheric"', () {
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

    test('switch on each new variant yields its label', () {
      const Map<MirkStyleConfig, String> casePairs = <MirkStyleConfig, String>{
        SolidConfig(): 'solid',
        CandlelightConfig(): 'candlelight',
        HeavenlyCloudsConfig(): 'heavenly',
      };
      for (final MapEntry<MirkStyleConfig, String> entry in casePairs.entries) {
        final String label = switch (entry.key) {
          AtmosphericConfig() => 'atmospheric',
          SolidConfig() => 'solid',
          CandlelightConfig() => 'candlelight',
          HeavenlyCloudsConfig() => 'heavenly',
          ShaderConfig() => 'shader',
          UnknownConfig() => 'unknown',
        };
        expect(label, entry.value, reason: 'Variant ${entry.key.runtimeType} → expected ${entry.value}');
      }
    });
  });

  group('09-02 — fixture-driven JSON parsing', () {
    test('builtin_styles.json: all 4 entries parse to concrete (non-Unknown) variants', () {
      final filename = p.join(Directory.current.path, 'test', 'fixtures', 'mirk', 'builtin_styles.json');
      final raw = jsonDecode(File(filename).readAsStringSync()) as List<Object?>;
      expect(raw.length, 4);

      final List<MirkStyleConfig> parsed = raw.map((entry) {
        final entryMap = entry as Map<String, Object?>;
        final config = entryMap['config'] as Map<String, Object?>;
        return MirkStyleConfig.fromJson(config);
      }).toList(growable: false);

      // Every entry MUST be its concrete variant — no UnknownConfig fallbacks.
      expect(parsed[0], isA<AtmosphericConfig>());
      expect(parsed[1], isA<SolidConfig>());
      expect(parsed[2], isA<CandlelightConfig>());
      expect(parsed[3], isA<HeavenlyCloudsConfig>());
    });

    test('imported_style_valid.json parses to AtmosphericConfig', () {
      final filename = p.join(Directory.current.path, 'test', 'fixtures', 'mirk', 'imported_style_valid.json');
      final raw = jsonDecode(File(filename).readAsStringSync()) as Map<String, Object?>;
      final config = raw['config'] as Map<String, Object?>;
      final parsed = MirkStyleConfig.fromJson(config);
      expect(parsed, isA<AtmosphericConfig>());
    });

    test('imported_style_unknown_type.json parses to UnknownConfig with raw preserved', () {
      final filename = p.join(Directory.current.path, 'test', 'fixtures', 'mirk', 'imported_style_unknown_type.json');
      final raw = jsonDecode(File(filename).readAsStringSync()) as Map<String, Object?>;
      final config = raw['config'] as Map<String, Object?>;
      final parsed = MirkStyleConfig.fromJson(config);
      expect(parsed, isA<UnknownConfig>());
      final preserved = (parsed as UnknownConfig).raw;
      expect(preserved['rendererType'], 'ray_marched_volumetric');
      expect(preserved['fancyParam'], 42);
    });
  });
}
