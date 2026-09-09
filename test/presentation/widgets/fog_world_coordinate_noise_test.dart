// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_world_coordinate_noise_test.dart — invariant FOG-17 (numerical harness)

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';

/// FOG-17 — world-coordinate noise sampling: ZERO fract-style wrap events at
/// every pixelOrigin magnitude regime.
///
/// Synthetic smooth-pan trajectory at three magnitudes (1.064 M ≈ Walk #3b
/// zoom 13, 4.26 M ≈ Walk #2 zoom 16, 17.04 M ≈ extrapolated zoom 19), the
/// MirkFall forward path applied (raw `camera.pixelOrigin` → iOS platform
/// corrections → `uPixelOrigin`), then the shader formulation
/// `noiseUv = (fragUv * uResolution + uPixelOrigin) / kNoiseTilePx`. A
/// backwards delta between consecutive paints is a wrap discontinuity.
void main() {
  group('FOG-17 — world-coordinate noise sampling: ZERO wrap events', () {
    test('Walk #3b regime (pixelOriginX ≈ 1.064 M) — ZERO fract-wraps over a 1500-px sweep', () {
      final wrapCount = _countFractWrapEvents(startMagnitude: 1064000.0);
      expect(wrapCount, equals(0), reason: 'the B-3 fract formulation produced ~40 wraps over this window; the world-coordinate one produces none');
    });

    test('Walk #2 regime (pixelOriginX ≈ 4.26 M) — ZERO fract-wraps over a 1500-px sweep', () {
      expect(_countFractWrapEvents(startMagnitude: 4260000.0), equals(0));
    });

    test('Extrapolated zoom-19 regime (pixelOriginX ≈ 17.04 M) — ZERO fract-wraps over a 1500-px sweep', () {
      expect(_countFractWrapEvents(startMagnitude: 17040000.0), equals(0));
    });

    test('Historical reference: the pre-FOG-18 integer-wrap boundary shifted the noise-grid input by exactly 4 grid units', () {
      // 1536 raw px (= 4 × kMirkFogNoiseTilePx) per wrap event under the
      // deleted FOG-17a design; kept as documentation of why the wrap was
      // visible (the FBM-rotated octaves are not continuous across it).
      const historicalWrapPeriodPx = 1536.0;
      const expectedShiftGridUnits = historicalWrapPeriodPx / kMirkFogNoiseTilePx;
      expect(expectedShiftGridUnits, equals(4.0));
      const farShift = 4.0 * kMirkFogAtmosphericScaleFar;
      const midShift = 4.0 * kMirkFogAtmosphericScaleMid;
      const nearShift = 4.0 * kMirkFogAtmosphericScaleNear;
      expect(farShift, closeTo(11.6, 1e-9));
      expect(midShift, closeTo(20.4, 1e-9));
      expect(nearShift, closeTo(42.0, 1e-9));
    });
  });
}

/// Applies the MirkFall forward path and the shader formulation over a
/// 1500-px sweep; returns the number of backwards `noiseUv` deltas (wrap
/// discontinuities). Under the world-coordinate formulation `noiseUv` grows by
/// `5 / 384 ≈ 0.013` per paint — strictly positive; a fract regression would
/// produce ~-0.97 deltas at every wrap event.
int _countFractWrapEvents({required double startMagnitude}) {
  const paintCount = 300;
  const deltaXPerPaint = 5.0;
  const viewportWidth = 390.0;

  // Mid-viewport reference fragment (fragUv ≈ 0.5).
  const fragXPx = viewportWidth * 0.5;

  var wrapCount = 0;
  double? previousNoiseUv;
  for (var i = 0; i < paintCount; i++) {
    final pixelOriginX = startMagnitude + i * deltaXPerPaint;
    // MirkFall forward path: the painter applies the platform corrections once on the raw value.
    final forwardedPxX = applyPlatformShaderCorrections(pixelOrigin: (x: pixelOriginX, y: 0.0), isAndroid: false).pixelOrigin.x;
    // atmospheric_fog.frag: worldPx = fragUv * uResolution + uPixelOrigin; noiseUv = worldPx / kNoiseTilePx (uZoomScale 1).
    final worldPxX = fragXPx + forwardedPxX;
    final noiseUvX = worldPxX / kMirkFogNoiseTilePx;
    if (previousNoiseUv != null && noiseUvX - previousNoiseUv < 0) {
      wrapCount += 1;
    }
    previousNoiseUv = noiseUvX;
  }
  return wrapCount;
}
