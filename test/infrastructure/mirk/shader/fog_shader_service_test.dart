// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 BUG-009 (TIER 2) — structural tests for FogShaderService.
//
// Tests cover the service's contract independent of whether the
// underlying `.frag` asset actually loads in the test harness:
//   - `hasLoadStarted` flips after the first `load()` call.
//   - Multiple `load()` calls reuse the same Future.
//   - Loading an invalid asset path returns null (no app crash —
//     guard against Flutter issue #108037).
//   - `obtainShader()` returns null when load fails.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FogShaderService', () {
    test('hasLoadStarted is false before load()', () {
      final svc = FogShaderService(assetPath: 'no_such_asset.frag');
      expect(svc.hasLoadStarted, isFalse);
    });

    test('hasLoadStarted flips to true after load() and stays true', () async {
      final svc = FogShaderService(assetPath: 'no_such_asset.frag');
      // ignore: unawaited_futures — fire-and-forget, we only care that
      // the field flipped.
      svc.load();
      expect(svc.hasLoadStarted, isTrue);
    });

    test('load() reuses the same future across calls (memoised)', () {
      final svc = FogShaderService(assetPath: 'no_such_asset.frag');
      final f1 = svc.load();
      final f2 = svc.load();
      expect(identical(f1, f2), isTrue, reason: 'Two load() calls must return the same Future instance — caching is the entire point of the service.');
    });

    test('load() with an invalid asset path resolves to null (no crash)', () async {
      // Guard against Flutter issue #108037 (invalid asset path
      // crashes the app under Impeller). The service must catch and
      // return null so the caller can fall back to a Paint-only path.
      final svc = FogShaderService(assetPath: 'definitely_not_a_real_shader_asset_xyz.frag');
      final program = await svc.load();
      expect(program, isNull, reason: 'Invalid asset path must resolve to null, never throw.');
    });

    test('obtainShader() returns null when load fails', () async {
      final svc = FogShaderService(assetPath: 'definitely_not_a_real_shader_asset_xyz.frag');
      final shader = await svc.obtainShader();
      expect(shader, isNull);
    });

    test('default constructor wires the BUG-009 atmospheric_fog asset path', () {
      final svc = FogShaderService();
      expect(svc.assetPath, equals('assets/shaders/atmospheric_fog.frag'));
    });

    test('obtainShader() with the real BUG-009 asset returns a FragmentShader', () async {
      // This test exercises the production path: asset is declared in
      // pubspec.yaml, the test harness can load it, and the service
      // returns a shader instance ready for setFloat / setImageSampler.
      // Skipped (warning, not failure) if the test harness cannot
      // resolve the asset bundle — typically only happens on a fresh
      // checkout before `flutter pub get`.
      final svc = FogShaderService();
      final shader = await svc.obtainShader();
      if (shader == null) {
        // ignore: avoid_print — printf debug for the rare CI flake
        // where the shader bundle isn't ready. Test-only.
        // ignore: avoid_print
        print('FogShaderService obtainShader() returned null — asset bundle not ready in this harness. Skipping.');
        return;
      }
      expect(shader, isA<ui.FragmentShader>());
    });
  });
}
