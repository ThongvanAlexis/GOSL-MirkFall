// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-03 Task 2 — FOG-21 + FOG-23 as a pure function,
// testable on Windows without a device (C1).

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';

import '../../../_helpers/mirk_paint_context_builder.dart';

void main() {
  const ({double x, double y}) rawPixelOrigin = (x: 100.0, y: 200.0);

  group('09.1-06 — rawPixelOriginOf (CPU renderers read the camera value, not the GPU-corrected one)', () {
    test('iOS context (identity sdfRect): pixelOrigin unchanged', () {
      final MirkPaintContext context = buildTestMirkPaintContext(pixelOrigin: rawPixelOrigin);
      expect(rawPixelOriginOf(context), rawPixelOrigin);
    });

    test('Android context (sdfRect (0, 1, 1, -1), negative y): y re-positivised to the raw camera value', () {
      final MirkPaintContext context = buildTestMirkPaintContext(pixelOrigin: (x: 100.0, y: -200.0), sdfRect: kFogSdfRectAndroidVFlip);
      expect(rawPixelOriginOf(context), rawPixelOrigin);
    });

    test('round trip: applyPlatformShaderCorrections → context → rawPixelOriginOf gives the raw value on both platforms', () {
      const ({double x, double y}) highZoomOrigin = (x: 4255934.927218, y: 1234567.890123);
      for (final bool isAndroid in <bool>[false, true]) {
        final PlatformShaderCorrections corrected = applyPlatformShaderCorrections(pixelOrigin: highZoomOrigin, isAndroid: isAndroid);
        final MirkPaintContext context = buildTestMirkPaintContext(pixelOrigin: corrected.pixelOrigin, sdfRect: corrected.sdfRect);
        expect(rawPixelOriginOf(context), highZoomOrigin, reason: 'isAndroid=$isAndroid');
      }
    });

    test('the Android sdfRect is the marker: a raw-looking positive y under the V-flip rect is still flipped back (coupling documented)', () {
      final MirkPaintContext context = buildTestMirkPaintContext(pixelOrigin: (x: 1.0, y: 5.0), sdfRect: kFogSdfRectAndroidVFlip);
      expect(rawPixelOriginOf(context), (x: 1.0, y: -5.0));
    });
  });

  group('09.1-03 — applyPlatformShaderCorrections', () {
    test('iOS: pixelOrigin unchanged, sdfRect identity (0, 0, 1, 1)', () {
      final PlatformShaderCorrections result = applyPlatformShaderCorrections(pixelOrigin: rawPixelOrigin, isAndroid: false);
      expect(result.pixelOrigin, (x: 100.0, y: 200.0));
      expect(result.sdfRect, (0.0, 0.0, 1.0, 1.0));
      expect(result.sdfRect, kFogSdfRectIdentity);
    });

    test('Android: pixelOrigin.y sign-flipped (FOG-23), sdfRect V-flip (0, 1, 1, -1) (FOG-21)', () {
      final PlatformShaderCorrections result = applyPlatformShaderCorrections(pixelOrigin: rawPixelOrigin, isAndroid: true);
      expect(result.pixelOrigin, (x: 100.0, y: -200.0));
      expect(result.sdfRect, (0.0, 1.0, 1.0, -1.0));
      expect(result.sdfRect, kFogSdfRectAndroidVFlip);
    });

    test('full-precision world-pixel magnitudes pass through verbatim (FOG-18: no Dart-side modulo)', () {
      const ({double x, double y}) highZoomOrigin = (x: 4255934.927218, y: 1234567.890123);
      final PlatformShaderCorrections ios = applyPlatformShaderCorrections(pixelOrigin: highZoomOrigin, isAndroid: false);
      final PlatformShaderCorrections android = applyPlatformShaderCorrections(pixelOrigin: highZoomOrigin, isAndroid: true);
      expect(ios.pixelOrigin.x, 4255934.927218);
      expect(ios.pixelOrigin.y, 1234567.890123);
      expect(android.pixelOrigin.x, 4255934.927218);
      expect(android.pixelOrigin.y, -1234567.890123);
    });

    test('is NOT idempotent on Android — the sign re-flips, so it must be applied ONCE per paint on the raw camera.pixelOrigin', () {
      final PlatformShaderCorrections once = applyPlatformShaderCorrections(pixelOrigin: rawPixelOrigin, isAndroid: true);
      final PlatformShaderCorrections twice = applyPlatformShaderCorrections(pixelOrigin: once.pixelOrigin, isAndroid: true);
      expect(once.pixelOrigin.y, -200.0);
      expect(twice.pixelOrigin.y, 200.0, reason: 'documentary: a second application undoes FOG-23');
      expect(twice.pixelOrigin, rawPixelOrigin);
      // sdfRect is platform-static, so it IS stable across applications.
      expect(twice.sdfRect, once.sdfRect);
    });

    test('is a pure function: same inputs → equal outputs, input record untouched', () {
      final PlatformShaderCorrections a = applyPlatformShaderCorrections(pixelOrigin: rawPixelOrigin, isAndroid: true);
      final PlatformShaderCorrections b = applyPlatformShaderCorrections(pixelOrigin: rawPixelOrigin, isAndroid: true);
      expect(a, b);
      expect(rawPixelOrigin, (x: 100.0, y: 200.0));
    });
  });
}
