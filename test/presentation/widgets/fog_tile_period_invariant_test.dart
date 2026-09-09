// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_tile_period_invariant_test.dart — invariants FOG-17 + FOG-19 (shader-side)

import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';

/// FOG-17 + FOG-19 — world-coordinate noise sampling engineering invariant.
///
/// The noise period is NOT derived on the Dart side any more: the painter
/// forwards `uPixelOrigin` raw and `uZoomScale`; the shader samples each
/// fragment at its own world position, `worldPx = fragUv * uResolution +
/// uPixelOrigin`, divided by `kNoiseTilePx * uZoomScale`. The POC debug-spiral
/// shader is not part of MirkFall (its continuity test is out of this plan's scope).
void main() {
  /// Strips `//` line comments so prose may mention the historical formulations.
  String activeCode(String source) => source
      .split('\n')
      .map((line) {
        final commentIdx = line.indexOf('//');
        return commentIdx >= 0 ? line.substring(0, commentIdx) : line;
      })
      .join('\n');

  group('FOG-17 — world-coordinate noise sampling', () {
    test('production shader contains the FOG-17 world-coordinate formulation with the FOG-19 divisor', () {
      final source = File('assets/shaders/atmospheric_fog.frag').readAsStringSync();
      expect(source, contains('const float kNoiseTilePx = 384.0;'), reason: 'constant-folded, NOT a uniform; lockstep with kMirkFogNoiseTilePx');
      expect(source, contains('vec2 worldPx = fragUv * uResolution + uPixelOrigin;'), reason: 'per-fragment world position');
      expect(source, contains('vec2 noiseUv = worldPx / (kNoiseTilePx * uZoomScale);'), reason: 'FOG-17 sampling + FOG-19 zoom-invariant divisor');
      expect(source, contains('uniform float uZoomScale;'));
    });

    test('shader kNoiseTilePx stays in lockstep with kMirkFogNoiseTilePx', () {
      final source = File('assets/shaders/atmospheric_fog.frag').readAsStringSync();
      final match = RegExp(r'const float kNoiseTilePx = ([0-9.]+);').firstMatch(source);
      expect(match, isNotNull);
      expect(double.parse(match!.group(1)!), equals(kMirkFogNoiseTilePx));
    });

    test('production shader active code does NOT contain a fract()-based pixelOrigin formulation', () {
      final code = activeCode(File('assets/shaders/atmospheric_fog.frag').readAsStringSync());
      expect(code, isNot(contains('fract(uPixelOrigin / tilePeriodPixels)')), reason: 'pre-03.1-10 B-3 formulation must stay out of active code');
      expect(code, isNot(contains('fract(uPixelOrigin / uResolution)')), reason: '03.1-04 viewport-width formulation must stay out of active code');
    });

    test('the painter derives NO period on the Dart side — pixelOrigin is forwarded raw', () {
      final source = File('lib/presentation/widgets/fog_layer.dart').readAsStringSync();
      expect(source, isNot(contains('kMirkFogNoiseTilePx')), reason: 'the tile period is a shader constant, never a painter input');
      expect(activeCode(source), isNot(contains('%')));
      expect(activeCode(source), contains('pixelOrigin: corrections.pixelOrigin'), reason: 'the context carries the corrected raw value');
    });

    test('FogShaderUniforms.totalFloatSlots == 42 — FOG-19 added uZoomScale at slot 41', () {
      final source = File('lib/infrastructure/mirk/shader/fog_shader_uniforms.dart').readAsStringSync();
      expect(source, contains('static const int totalFloatSlots = 42;'), reason: 'kNoiseTilePx is constant-folded, uZoomScale is the 42nd float');
    });
  });
}
