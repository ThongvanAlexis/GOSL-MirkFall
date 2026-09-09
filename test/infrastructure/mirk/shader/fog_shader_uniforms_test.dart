// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-03 Task 2 — 42-slot shader ABI gate (port of the POC
// `fog_shader_uniforms_test.dart`, `mirk-poc-debug` @ 90c9321).
//
// `ui.FragmentShader` is declared `base` in `dart:ui` (sky_engine painting.dart),
// so it CANNOT be implemented or faked from outside its library — "a recording
// fake FragmentShader that observes setFloat(3, …)" is not expressible. The
// achievable equivalents, both used here:
//
//   1. Source reflection over `fog_shader_uniforms.dart`: every `setFloat(N, …)`
//      call is extracted and the slot set must be exactly {0..41}, with the
//      named slots (3-4 pixelOrigin, 37-40 sdfRect, 41 zoomScale, sampler 0)
//      bound to the expected argument.
//   2. The `FogShaderRenderer` seam (`RecordingFogShaderRenderer`) proves the
//      values flow through the interface verbatim (no Dart-side modulo).
//
// Plus the Dart ↔ GLSL lockstep test for `kNoiseTilePx` — a `const float` that
// is constant-folded in the shader (NOT a uniform, so it does not occupy a
// slot); a divergence from `kMirkFogNoiseTilePx` would silently break the
// FOG-19 anchoring. It lives here, next to the ABI tests, because
// `test/constants_test.dart` is owned by plan 09.1-02 in Wave 2.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_uniforms.dart';

/// Repo-relative paths — `flutter test` runs with the package root as cwd
/// (same idiom as `test/presentation/map_style_layer_order_test.dart`).
const String _fragPath = 'assets/shaders/atmospheric_fog.frag';
const String _uniformsPath = 'lib/infrastructure/mirk/shader/fog_shader_uniforms.dart';

/// `shader.setFloat(<slot>, <argument>)` — captures slot index and argument text.
final RegExp _setFloatPattern = RegExp(r'shader\.setFloat\((\d+),\s*([^)]+)\)');

void main() {
  group('09.1-03 — FogShaderUniforms 42-slot ABI', () {
    test('totalFloatSlots == 42 (FOG-19 added uZoomScale at slot 41)', () {
      expect(
        FogShaderUniforms.totalFloatSlots,
        42,
        reason:
            'FOG-19 added `uniform float uZoomScale` at slot 41 to atmospheric_fog.frag. The Dart-side total must match, '
            'otherwise Impeller fails at uniform-binding time.',
      );
    });

    test('setAll binds exactly the 42 slots {0..41}, each once', () {
      final String source = File(_uniformsPath).readAsStringSync();
      final List<int> slots = _setFloatPattern.allMatches(source).map((RegExpMatch m) => int.parse(m.group(1)!)).toList();
      expect(slots, hasLength(42), reason: 'one setFloat per slot');
      expect(slots.toSet(), List<int>.generate(42, (int i) => i).toSet());
      expect(source, contains('shader.setImageSampler(0, sdfImage)'));
    });

    test('slots 3-4 carry pixelOrigin.x / .y, slots 37-40 carry sdfRect, slot 41 carries zoomScale', () {
      final String source = File(_uniformsPath).readAsStringSync();
      final Map<int, String> argumentBySlot = <int, String>{
        for (final RegExpMatch m in _setFloatPattern.allMatches(source)) int.parse(m.group(1)!): m.group(2)!.trim(),
      };
      expect(argumentBySlot[3], 'pixelOrigin.x');
      expect(argumentBySlot[4], 'pixelOrigin.y');
      expect(argumentBySlot[37], r'sdfRect.$1');
      expect(argumentBySlot[38], r'sdfRect.$2');
      expect(argumentBySlot[39], r'sdfRect.$3');
      expect(argumentBySlot[40], r'sdfRect.$4');
      expect(argumentBySlot[41], 'zoomScale');
    });
  });

  group('09.1-03 — atmospheric_fog.frag ABI (POC verbatim)', () {
    test('declares uPixelOrigin (vec2) and uZoomScale (float), never the pre-09.1 uOffset', () {
      final String frag = File(_fragPath).readAsStringSync();
      expect(frag, contains('uniform vec2  uPixelOrigin;'));
      expect(frag, contains('uniform float uZoomScale;'));
      expect(frag, isNot(contains('uniform vec2  uOffset;')));
    });

    test('uZoomScale is declared AFTER uSdfRectSizeY and BEFORE sampler2D uSdf (sampler last — BUG-014 it. 1)', () {
      final String frag = File(_fragPath).readAsStringSync();
      final int sizeY = frag.indexOf('uniform float uSdfRectSizeY;');
      final int zoomScale = frag.indexOf('uniform float uZoomScale;');
      final int sampler = frag.indexOf('uniform sampler2D uSdf;');
      expect(sizeY, greaterThanOrEqualTo(0));
      expect(zoomScale, greaterThan(sizeY));
      expect(sampler, greaterThan(zoomScale));
    });

    test('samples noise in world pixels: worldPx = fragUv * uResolution + uPixelOrigin; noiseUv = worldPx / (kNoiseTilePx * uZoomScale)', () {
      final String frag = File(_fragPath).readAsStringSync();
      expect(frag, contains('vec2 worldPx = fragUv * uResolution + uPixelOrigin;'));
      expect(frag, contains('vec2 noiseUv = worldPx / (kNoiseTilePx * uZoomScale);'));
    });

    test('kNoiseTilePx (constant-folded GLSL const) is in lockstep with kMirkFogNoiseTilePx', () {
      final String frag = File(_fragPath).readAsStringSync();
      final RegExpMatch? match = RegExp(r'kNoiseTilePx\s*=\s*([0-9.]+)').firstMatch(frag);
      expect(match, isNotNull, reason: 'atmospheric_fog.frag must declare `const float kNoiseTilePx = <value>;`');
      final double glslValue = double.parse(match!.group(1)!);
      expect(
        glslValue,
        kMirkFogNoiseTilePx,
        reason:
            'kNoiseTilePx is a GLSL const (not a uniform — it occupies no slot). It MUST equal '
            'kMirkFogNoiseTilePx; a divergence silently breaks the FOG-19 world-pixel anchoring.',
      );
    });

    test('keeps the OpenGLES fragUv flip and the density debug toggle', () {
      final String frag = File(_fragPath).readAsStringSync();
      expect(frag, contains('#ifdef IMPELLER_TARGET_OPENGLES'));
      expect(frag, contains('fragUv.y = 1.0 - fragUv.y;'));
      expect(frag, contains('MIRK_FOG_DEBUG_OUTPUT_DENSITY'));
    });
  });
}
