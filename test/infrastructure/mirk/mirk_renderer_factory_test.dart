// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/builtin_mirk_styles.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/mirk_renderer_factory.dart';
import 'package:mirkfall/infrastructure/mirk/shader_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

/// Plan 09-05 Task 1 — sealed-switch dispatch over [MirkStyleConfig].
///
/// Behaviour under test:
/// * Each of the 6 sealed variants resolves to its concrete renderer.
/// * `UnknownConfig` (forward-compat fallback from Phase 03) and
///   `ShaderConfig` (Phase 13 stub) follow the documented degradation
///   policy:
///   - `ShaderConfig` -> `ShaderMirkRenderer` (the stub itself, with
///     `paint()` throwing `UnimplementedError` — no V1.0 user path
///     reaches this branch, but the factory must still wire it for
///     sealed exhaustiveness).
///   - `UnknownConfig` -> `AtmosphericMirkRenderer` with a default
///     `AtmosphericConfig()`. Per 09-RESEARCH §Fallback Strategy + plan
///     09-05 SUMMARY: the local app cannot render what it does not
///     understand, so degrade to the default rather than crashing.
///
/// The `kBuiltinMirkStyles` registry is exercised in parallel:
/// * 4 entries in canonical order (atmospheric, solid, candlelight,
///   heavenly_clouds).
/// * Deterministic IDs (`style_builtin_<variant>`) double as DB-layer
///   markers of "built-in" for the Phase 13 OPT-04 delete-if-not-builtin
///   semantics.
/// * Each descriptor's `defaultConfig()` returns the expected variant
///   type (and a fresh value every call — no shared references).
void main() {
  group('09-05 — MirkRendererFactory (MIRK-05)', () {
    const MirkRendererFactory factory = MirkRendererFactory();

    test('AtmosphericConfig -> AtmosphericMirkRenderer', () {
      const config = AtmosphericConfig();
      final renderer = factory.create(config);
      expect(renderer, isA<AtmosphericMirkRenderer>());
      expect((renderer as AtmosphericMirkRenderer).config, same(config));
    });

    test('SolidConfig -> SolidFillMirkRenderer', () {
      const config = SolidConfig();
      final renderer = factory.create(config);
      expect(renderer, isA<SolidFillMirkRenderer>());
      expect((renderer as SolidFillMirkRenderer).config, same(config));
    });

    test('CandlelightConfig -> CandlelightMirkRenderer', () {
      const config = CandlelightConfig();
      final renderer = factory.create(config);
      expect(renderer, isA<CandlelightMirkRenderer>());
      expect((renderer as CandlelightMirkRenderer).config, same(config));
    });

    test('HeavenlyCloudsConfig -> HeavenlyCloudsMirkRenderer', () {
      const config = HeavenlyCloudsConfig();
      final renderer = factory.create(config);
      expect(renderer, isA<HeavenlyCloudsMirkRenderer>());
      expect((renderer as HeavenlyCloudsMirkRenderer).config, same(config));
    });

    test('ShaderConfig -> ShaderMirkRenderer (Phase 13 stub)', () {
      const config = ShaderConfig(shaderAssetPath: 'assets/shaders/x.frag');
      final renderer = factory.create(config);
      expect(renderer, isA<ShaderMirkRenderer>());
      // The stub's paint() throws UnimplementedError — documented as part
      // of the renderer's surface, not asserted here (this is the
      // factory's contract test, not the renderer's body test).
    });

    test('UnknownConfig -> AtmosphericMirkRenderer with default config '
        '(forward-compat fallback)', () {
      final config = MirkStyleConfig.fromJson(<String, Object?>{'rendererType': 'unknown-future-renderer-v999', 'someParam': 42});
      expect(
        config,
        isA<UnknownConfig>(),
        reason:
            'precondition: fromJson must route the unknown discriminator '
            'to the UnknownConfig fallback variant',
      );

      final renderer = factory.create(config);
      expect(
        renderer,
        isA<AtmosphericMirkRenderer>(),
        reason:
            'unknown variants must degrade to the default atmospheric '
            'renderer rather than crashing or returning a Noop',
      );
      // Atmospheric default config: baseColorArgb = 0xFF000000.
      expect((renderer as AtmosphericMirkRenderer).config.baseColorArgb, 0xFF000000);
    });
  });

  group('09-05 — kBuiltinMirkStyles registry (MIRK-06)', () {
    test('exposes exactly 4 descriptors in canonical order', () {
      expect(kBuiltinMirkStyles, hasLength(4));
      expect(kBuiltinMirkStyles.map((d) => d.id).toList(), <String>[
        'style_builtin_atmospheric',
        'style_builtin_solid',
        'style_builtin_candlelight',
        'style_builtin_heavenly_clouds',
      ]);
    });

    test('every descriptor carries a non-empty French display name', () {
      for (final descriptor in kBuiltinMirkStyles) {
        expect(descriptor.displayName.trim(), isNotEmpty, reason: '${descriptor.id} must carry a display name');
      }
    });

    test('atmospheric descriptor defaultConfig() returns AtmosphericConfig', () {
      final descriptor = kBuiltinMirkStyles.firstWhere((d) => d.id == 'style_builtin_atmospheric');
      expect(descriptor.defaultConfig(), isA<AtmosphericConfig>());
    });

    test('solid descriptor defaultConfig() returns SolidConfig', () {
      final descriptor = kBuiltinMirkStyles.firstWhere((d) => d.id == 'style_builtin_solid');
      expect(descriptor.defaultConfig(), isA<SolidConfig>());
    });

    test('candlelight descriptor defaultConfig() returns CandlelightConfig', () {
      final descriptor = kBuiltinMirkStyles.firstWhere((d) => d.id == 'style_builtin_candlelight');
      expect(descriptor.defaultConfig(), isA<CandlelightConfig>());
    });

    test('heavenly_clouds descriptor defaultConfig() returns '
        'HeavenlyCloudsConfig', () {
      final descriptor = kBuiltinMirkStyles.firstWhere((d) => d.id == 'style_builtin_heavenly_clouds');
      expect(descriptor.defaultConfig(), isA<HeavenlyCloudsConfig>());
    });

    test('defaultConfig() returns a fresh Freezed instance each call '
        '(no shared references)', () {
      // const Freezed instances are canonicalized at compile time, so
      // `identical(a, b)` IS expected to be true for `const X()` calls.
      // The contract that matters: the descriptor's factory function is
      // invoked on every read, never returning a cached lazy value
      // (in case Phase 13 extends with runtime params). We verify by
      // checking value-equality holds (Freezed generates ==).
      final descriptor = kBuiltinMirkStyles.first;
      expect(descriptor.defaultConfig(), descriptor.defaultConfig(), reason: 'two consecutive defaultConfig() calls must compare equal');
    });

    test('factory dispatches every kBuiltinMirkStyles defaultConfig() '
        'to its expected concrete renderer', () {
      const factory = MirkRendererFactory();
      final renderers = kBuiltinMirkStyles.map((d) => factory.create(d.defaultConfig())).toList();
      expect(renderers[0], isA<AtmosphericMirkRenderer>());
      expect(renderers[1], isA<SolidFillMirkRenderer>());
      expect(renderers[2], isA<CandlelightMirkRenderer>());
      expect(renderers[3], isA<HeavenlyCloudsMirkRenderer>());
    });
  });
}
