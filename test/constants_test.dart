// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';

/// Guards the FOUND-07 requirement: the 5 canonical Phase 01 constants exist
/// in `lib/config/constants.dart` with the expected values and types.
void main() {
  test('kAppName is the MirkFall display name', () {
    expect(kAppName, equals('MirkFall'));
  });

  test('kBundleId matches Android + iOS bundle identifier', () {
    expect(kBundleId, equals('app.gosl.mirkfall'));
  });

  test('kMaxLogsDirBytes caps logs directory at 10 MB', () {
    expect(kMaxLogsDirBytes, equals(10 * 1024 * 1024));
  });

  test('kAboutTapsToTriggerDebugMenu is 7', () {
    expect(kAboutTapsToTriggerDebugMenu, equals(7));
  });

  test('kAboutTapWindowMilliseconds is 3000', () {
    expect(kAboutTapWindowMilliseconds, equals(3000));
  });

  // Logging reliability constants (kFileLoggerFlushEveryNRecords +
  // kFileLoggerFlushPeriodSeconds) were removed 2026-04-26 with the
  // FileLogger rewrite to RandomAccessFile + per-record flushSync (real
  // fsync). The hybrid threshold + periodic timer existed solely to
  // amortise an IOSink's userspace flush — no longer applicable.
  // No replacement constants are needed.

  // Phase 07 (Map Integration) — every new Phase 07 slot gets a value +
  // type guard here so a silent rename/retype is caught at test time.
  group('Phase 07 constants', () {
    test('kHttpTimeout is 30_000 ms (lowered at Phase 07-07 device-smoke — CDN edges close around 30-45 s)', () {
      expect(kHttpTimeout, equals(30000));
      expect(kHttpTimeout, isA<int>());
    });

    test('kMapCatalogAssetPath is assets/maps/catalog.json', () {
      expect(kMapCatalogAssetPath, equals('assets/maps/catalog.json'));
      expect(kMapCatalogAssetPath, isA<String>());
    });

    test('kWorldPmtilesAssetPath is assets/maps/world.pmtiles', () {
      expect(kWorldPmtilesAssetPath, equals('assets/maps/world.pmtiles'));
    });

    test('kWorldPmtilesInternalPath is maps/world.pmtiles (relative to <app_support>)', () {
      expect(kWorldPmtilesInternalPath, equals('maps/world.pmtiles'));
    });

    test('kCountriesDir is maps/countries', () {
      expect(kCountriesDir, equals('maps/countries'));
    });

    test('kStagingDir is maps/staging', () {
      expect(kStagingDir, equals('maps/staging'));
    });

    test('kInstalledManifestPath is maps/installed.json', () {
      expect(kInstalledManifestPath, equals('maps/installed.json'));
    });

    test('kCountryPolygonsAssetPath is assets/maps/polygons', () {
      expect(kCountryPolygonsAssetPath, equals('assets/maps/polygons'));
    });

    test('kStyleJsonAssetPath is assets/maps/style.json', () {
      expect(kStyleJsonAssetPath, equals('assets/maps/style.json'));
    });

    test('kInitialSessionMapZoom is 15 (close enough for atmospheric noise to resolve)', () {
      expect(kInitialSessionMapZoom, equals(15));
      expect(kInitialSessionMapZoom, isA<int>());
    });

    test('kInitialRevealRadiusMeters is 20', () {
      expect(kInitialRevealRadiusMeters, equals(20));
      expect(kInitialRevealRadiusMeters, isA<int>());
    });

    test('kDiskSpaceSafetyMarginMultiplier is 1.1', () {
      expect(kDiskSpaceSafetyMarginMultiplier, equals(1.1));
      expect(kDiskSpaceSafetyMarginMultiplier, isA<double>());
    });

    test('kDownloadRetryAttempts is 3', () {
      expect(kDownloadRetryAttempts, equals(3));
      expect(kDownloadRetryAttempts, isA<int>());
    });

    test('kDownloadRetryBaseDelayMs is 1000', () {
      expect(kDownloadRetryBaseDelayMs, equals(1000));
      expect(kDownloadRetryBaseDelayMs, isA<int>());
    });
  });

  // Phase 09 (Fog Rendering) — value + type guards on every Phase 09
  // tunable so a silent rename or accidental retype is caught at test
  // time. `kRevealedTileParentZoom` is asserted here as a Phase 09
  // consumer of the Phase 03-declared symbol (no duplicate constant —
  // see lib/config/constants.dart line ~75).
  group('Phase 09 constants', () {
    test('kDefaultRevealRadiusMeters is 25.0', () {
      expect(kDefaultRevealRadiusMeters, equals(25.0));
      expect(kDefaultRevealRadiusMeters, isA<double>());
    });

    test('kRevealFlushIntervalSeconds is 2', () {
      expect(kRevealFlushIntervalSeconds, equals(2));
      expect(kRevealFlushIntervalSeconds, isA<int>());
    });

    test('kRevealFlushMaxFixes is 20', () {
      expect(kRevealFlushMaxFixes, equals(20));
      expect(kRevealFlushMaxFixes, isA<int>());
    });

    test('kDefaultMirkBaselineAlpha is 0.99', () {
      expect(kDefaultMirkBaselineAlpha, equals(0.99));
      expect(kDefaultMirkBaselineAlpha, isA<double>());
    });

    test('kInitialRevealFadeInMs is 500', () {
      expect(kInitialRevealFadeInMs, equals(500));
      expect(kInitialRevealFadeInMs, isA<int>());
    });

    test('kFeatherRadiusFraction is 0.1', () {
      expect(kFeatherRadiusFraction, equals(0.1));
      expect(kFeatherRadiusFraction, isA<double>());
    });

    test('kMirkNoiseScaleDefault is 0.5', () {
      expect(kMirkNoiseScaleDefault, equals(0.5));
      expect(kMirkNoiseScaleDefault, isA<double>());
    });

    test('kMirkNoiseSpeedDefault is 0.05', () {
      expect(kMirkNoiseSpeedDefault, equals(0.05));
      expect(kMirkNoiseSpeedDefault, isA<double>());
    });

    test('kMirkDriftDirectionDegDefault is 0.0', () {
      expect(kMirkDriftDirectionDegDefault, equals(0.0));
      expect(kMirkDriftDirectionDegDefault, isA<double>());
    });

    test('kMirkCandlelightCenterColorArgb is 0xFFFF8F6A', () {
      expect(kMirkCandlelightCenterColorArgb, equals(0xFFFF8F6A));
      expect(kMirkCandlelightCenterColorArgb, isA<int>());
    });

    test('kMirkCandlelightPeripheryColorArgb is 0xFFC2542E', () {
      expect(kMirkCandlelightPeripheryColorArgb, equals(0xFFC2542E));
      expect(kMirkCandlelightPeripheryColorArgb, isA<int>());
    });

    test('kMirkCandlelightNoiseScale is 0.8', () {
      expect(kMirkCandlelightNoiseScale, equals(0.8));
      expect(kMirkCandlelightNoiseScale, isA<double>());
    });

    test('kMirkCandlelightNoiseSpeed is 0.1', () {
      expect(kMirkCandlelightNoiseSpeed, equals(0.1));
      expect(kMirkCandlelightNoiseSpeed, isA<double>());
    });

    test('kMirkCandlelightBaselineAlpha is 0.85', () {
      expect(kMirkCandlelightBaselineAlpha, equals(0.85));
      expect(kMirkCandlelightBaselineAlpha, isA<double>());
    });

    test('kMirkHeavenlyCloudsColorArgb is 0xFFE8E8EE', () {
      expect(kMirkHeavenlyCloudsColorArgb, equals(0xFFE8E8EE));
      expect(kMirkHeavenlyCloudsColorArgb, isA<int>());
    });

    test('kMirkHeavenlyCloudsNoiseScale is 0.3', () {
      expect(kMirkHeavenlyCloudsNoiseScale, equals(0.3));
      expect(kMirkHeavenlyCloudsNoiseScale, isA<double>());
    });

    test('kMirkHeavenlyCloudsNoiseSpeed is 0.08', () {
      expect(kMirkHeavenlyCloudsNoiseSpeed, equals(0.08));
      expect(kMirkHeavenlyCloudsNoiseSpeed, isA<double>());
    });

    test('kMirkHeavenlyCloudsDriftDirectionDeg is 45.0', () {
      expect(kMirkHeavenlyCloudsDriftDirectionDeg, equals(45.0));
      expect(kMirkHeavenlyCloudsDriftDirectionDeg, isA<double>());
    });

    test('kMirkHeavenlyCloudsBaselineAlpha is 0.80', () {
      expect(kMirkHeavenlyCloudsBaselineAlpha, equals(0.80));
      expect(kMirkHeavenlyCloudsBaselineAlpha, isA<double>());
    });

    test('kMirkHeavenlyCloudsCpuNoiseCyclesPerTilePerUnitScale × default noiseScale matches the shader mid scale (09.1-06)', () {
      expect(kMirkHeavenlyCloudsCpuNoiseCyclesPerTilePerUnitScale, equals(6.0));
      expect(kMirkHeavenlyCloudsCpuNoiseCyclesPerTilePerUnitScale * kMirkHeavenlyCloudsNoiseScale, closeTo(kMirkFogHeavenlyScaleMid, 1e-9));
    });

    test('kMirkHeavenlyCloudsCpuNoiseOverlayAlpha is 0.35 (09.1-06)', () {
      expect(kMirkHeavenlyCloudsCpuNoiseOverlayAlpha, equals(0.35));
      expect(kMirkHeavenlyCloudsCpuNoiseOverlayAlpha, inInclusiveRange(0.0, 1.0));
    });

    test('kMirkSolidColorArgb is 0xFF1A1A1A', () {
      expect(kMirkSolidColorArgb, equals(0xFF1A1A1A));
      expect(kMirkSolidColorArgb, isA<int>());
    });

    // Cross-phase guard: Phase 03 D3 declared kRevealedTileParentZoom = 14.
    // Phase 09 reuses (does NOT duplicate) — this assertion is the regression
    // anchor that the symbol still exists with the expected value when
    // Phase 09 renderers and reveal streaming compile against it.
    test('kRevealedTileParentZoom is 14 (Phase 03 D3, reused by Phase 09)', () {
      expect(kRevealedTileParentZoom, equals(14));
      expect(kRevealedTileParentZoom, isA<int>());
    });
  });

  // Phase 09 BUG-009 (TIER 2 fog visual) — every fog tunable carries a
  // value + type guard so a future debug-menu wrap (slider-driven config
  // service) sees a stable surface. Naming convention: `kMirkFogXxx`.
  group('Phase 09 BUG-009 fog (TIER 2) constants', () {
    test('atmospheric palette ARGB triple (indigo)', () {
      expect(kMirkFogAtmosphericBaseColorArgb, equals(0xFF3A4358));
      expect(kMirkFogAtmosphericHighlightColorArgb, equals(0xFF7C8AA3));
      expect(kMirkFogAtmosphericShadowColorArgb, equals(0xFF1E2536));
      expect(kMirkFogAtmosphericBaseColorArgb, isA<int>());
    });

    test('heavenly palette ARGB triple (dawn)', () {
      expect(kMirkFogHeavenlyBaseColorArgb, equals(0xFFA8B5C4));
      expect(kMirkFogHeavenlyHighlightColorArgb, equals(0xFFE8DCC8));
      expect(kMirkFogHeavenlyShadowColorArgb, equals(0xFF5D6878));
    });

    test('atmospheric drift Z speeds are positive and finite', () {
      // Structural test — exact values are tuning knobs revised on UAT
      // walks (most recently 2026-04-26 from the live tuner export). The
      // strict ladder ordering (far < mid < near) was relaxed after the
      // baking pass because the user landed on an "all octaves drift at
      // similar pace" sweet spot. Only the positivity and finiteness
      // contract the shader assumes is checked here.
      expect(kMirkFogAtmosphericDriftZFar, greaterThan(0));
      expect(kMirkFogAtmosphericDriftZMid, greaterThan(0));
      expect(kMirkFogAtmosphericDriftZNear, greaterThan(0));
      expect(kMirkFogAtmosphericDriftZFar.isFinite, isTrue);
      expect(kMirkFogAtmosphericDriftZMid.isFinite, isTrue);
      expect(kMirkFogAtmosphericDriftZNear.isFinite, isTrue);
    });

    test('heavenly drift Z speeds form a 3-tier ladder (far < mid < near)', () {
      // Heavenly stayed at defaults during the 2026-04-26 baking pass —
      // the cross-palette comparison with atmospheric was dropped because
      // the user explicitly tuned only atmospheric, so the relative
      // "heavenly faster than atmospheric" invariant no longer holds.
      expect(kMirkFogHeavenlyDriftZFar, lessThan(kMirkFogHeavenlyDriftZMid));
      expect(kMirkFogHeavenlyDriftZMid, lessThan(kMirkFogHeavenlyDriftZNear));
    });

    test('atmospheric scale ladder (far < mid < near)', () {
      // Exact values are tuning knobs (last revised 2026-04-26 from the
      // live tuner export). Only the ladder ordering — which the shader
      // assumes for parallax depth — is asserted.
      expect(kMirkFogAtmosphericScaleFar, greaterThan(0));
      expect(kMirkFogAtmosphericScaleFar, lessThan(kMirkFogAtmosphericScaleMid));
      expect(kMirkFogAtmosphericScaleMid, lessThan(kMirkFogAtmosphericScaleNear));
    });

    test('heavenly scale ladder (far < mid < near)', () {
      expect(kMirkFogHeavenlyScaleFar, greaterThan(0));
      expect(kMirkFogHeavenlyScaleFar, lessThan(kMirkFogHeavenlyScaleMid));
      expect(kMirkFogHeavenlyScaleMid, lessThan(kMirkFogHeavenlyScaleNear));
    });

    test('opacity weights are non-negative and finite', () {
      // The 2026-04-26 baking pass landed on equal-octave opacities (all
      // 0.58) — the user-facing density slider then drives all three
      // simultaneously. The "sum to ~1.0" + "far > mid > near" invariants
      // from the original 3-octave parallax design no longer apply.
      expect(kMirkFogOpacityFar, greaterThan(0));
      expect(kMirkFogOpacityMid, greaterThan(0));
      expect(kMirkFogOpacityNear, greaterThan(0));
      expect(kMirkFogOpacityFar.isFinite, isTrue);
      expect(kMirkFogOpacityMid.isFinite, isTrue);
      expect(kMirkFogOpacityNear.isFinite, isTrue);
    });

    test('curl noise tunables are positive and finite', () {
      // Amplitude + scale are tuning knobs revised on UAT walks; only
      // positivity is contractual.
      expect(kMirkFogCurlAmplitude, greaterThan(0));
      expect(kMirkFogCurlScale, greaterThan(0));
      expect(kMirkFogCurlAmplitude.isFinite, isTrue);
      expect(kMirkFogCurlScale.isFinite, isTrue);
    });

    test('faux-shading tunables are within sane shader-input ranges', () {
      // Direction is in [-π, π] (full radians sweep around the unit
      // circle). Offset and strength are positive — the 2026-04-26 walk
      // pushed strength past 1.0, intentionally (see constants.dart
      // comment).
      expect(kMirkFogLightDirRadians, greaterThanOrEqualTo(-3.14159));
      expect(kMirkFogLightDirRadians, lessThanOrEqualTo(3.14159));
      expect(kMirkFogLightOffset, greaterThan(0));
      expect(kMirkFogLightStrength, greaterThan(0));
    });

    test('hue variation tunables are non-negative and finite', () {
      expect(kMirkFogHueNoiseScale, greaterThan(0));
      expect(kMirkFogHueStrength, greaterThanOrEqualTo(0));
      expect(kMirkFogHueNoiseScale.isFinite, isTrue);
      expect(kMirkFogHueStrength.isFinite, isTrue);
    });

    test('two-stop watercolour boundary distances are non-negative', () {
      // 2026-04-26 baking pass: the user dialed bleed to 0 (sharp-only
      // boundary, no trailing fade), so the original "bleed > sharp"
      // invariant no longer holds. Only non-negativity is checked.
      expect(kMirkFogBoundarySharpDistance, greaterThanOrEqualTo(0));
      expect(kMirkFogBoundaryBleedDistance, greaterThanOrEqualTo(0));
    });

    test('boundary curl edge band is positive and finite', () {
      expect(kMirkFogBoundaryEdgeBand, greaterThan(0.0));
      expect(kMirkFogBoundaryEdgeBand.isFinite, isTrue);
    });

    test('SDF resolution is a positive power of two-ish (256)', () {
      expect(kMirkFogSdfResolution, equals(256));
      expect(kMirkFogSdfResolution, isA<int>());
    });

    test('wisp particle tunables', () {
      expect(kMirkFogWispMaxCount, equals(200));
      // BUG-010 Option B Commit 5: per-cell wisp count retired in favour
      // of metres-per-wisp perimeter spacing. 8 m at 25 m radius
      // ≈ 20 wisps per emergence — comparable density to the pre-Commit-5
      // cell-diff cadence (3-5 cells × 2 wisps/cell ≈ 6-10).
      expect(kMirkFogMetersPerWisp, equals(8.0));
      expect(kMirkFogMetersPerWisp, isA<double>());
      expect(kMirkFogWispLifeSeconds, equals(2.5));
      expect(kMirkFogWispBirthRadiusPx, equals(6.0));
      expect(kMirkFogWispDeathRadiusPx, equals(22.0));
      // Death radius > birth radius — wisps grow as they fade (puff
      // dispersing), not the reverse.
      expect(kMirkFogWispDeathRadiusPx, greaterThan(kMirkFogWispBirthRadiusPx));
      expect(kMirkFogWispPeakAlpha, equals(0.35));
      expect(kMirkFogWispPeakAlpha, lessThan(1.0));
    });

    // Diagnostic toggle for raw density visualisation in the fog shader.
    // Default false = production colour output. The matching GLSL
    // `#define MIRK_FOG_DEBUG_OUTPUT_DENSITY` lives in
    // `assets/shaders/atmospheric_fog.frag` and must be flipped in
    // lockstep — the Dart constant is documentation + test surface, the
    // GLSL `#define` is what actually changes shader output.
    test('kMirkFogDebugOutputDensity defaults to false (production output)', () {
      expect(kMirkFogDebugOutputDensity, isFalse);
      expect(kMirkFogDebugOutputDensity, isA<bool>());
    });
  });

  // Phase 09.1 (port-back same-canvas fog on flutter_map) — value + type
  // guards on every constant introduced by plan 09.1-01. Downstream plans
  // (09.1-02 adapter, 09.1-03 seam + shader ABI, 09.1-04 FogLayer, 09.1-05
  // wisps) compile against these symbols; a silent rename or retype is
  // caught here before it reaches a device walk. The `.frag` lockstep for
  // `kMirkFogNoiseTilePx` is NOT tested here — 09.1-03 Task 2 creates it in
  // `test/infrastructure/mirk/shader/fog_shader_uniforms_test.dart` once
  // the POC shader is ported (no `skip` placeholder by design).
  group('Phase 09.1 — same-canvas fog constants', () {
    test('kMirkFogReferenceZoom is 13.0 and kMirkFogNoiseTilePx is 384.0 (shader ABI, PORTBACK §5 n°8)', () {
      expect(kMirkFogReferenceZoom, equals(13.0));
      expect(kMirkFogReferenceZoom, isA<double>());
      expect(kMirkFogNoiseTilePx, equals(384.0));
      expect(kMirkFogNoiseTilePx, isA<double>());
    });

    test('wisp world-coordinate tunables (metres basis, replaces the px/s basis)', () {
      expect(kMirkWispDriftMetersPerSecond, equals(1.5));
      expect(kMirkWispDriftMetersPerSecond, isA<double>());
      expect(kMirkWispCurlAccelMetersPerSecondSquared, equals(0.5));
      expect(kMirkWispCurlAccelMetersPerSecondSquared, isA<double>());
      expect(kMirkWispDragPerSecond, equals(0.30));
      expect(kMirkWispDragPerSecond, isA<double>());
      expect(kMirkWispMaxDtSeconds, equals(0.1));
      expect(kMirkWispMaxDtSeconds, isA<double>());
      expect(kMirkWispCurlInputScale, equals(50.0));
      expect(kMirkWispCurlInputScale, isA<double>());
    });

    test('wisp tints per palette (atmospheric / heavenly)', () {
      expect(kMirkWispTintAtmosphericArgb, equals(0xFFE0E6F0));
      expect(kMirkWispTintAtmosphericArgb, isA<int>());
      expect(kMirkWispTintHeavenlyArgb, equals(0xFFF8F0E2));
      expect(kMirkWispTintHeavenlyArgb, isA<int>());
    });

    test('map zoom envelope: min 2.0, max 20.0, world overview 2.0, session zoom 15 unchanged and inside the envelope', () {
      expect(kMapMinZoom, equals(2.0));
      expect(kMapMinZoom, isA<double>());
      expect(kMapMaxZoom, equals(20.0));
      expect(kMapMaxZoom, isA<double>());
      expect(kMapWorldOverviewZoom, equals(2.0));
      expect(kMapWorldOverviewZoom, isA<double>());
      expect(kMapMinZoom, lessThanOrEqualTo(kMapWorldOverviewZoom));
      expect(kInitialSessionMapZoom, equals(15));
      expect(kMapMaxZoom, greaterThanOrEqualTo(kInitialSessionMapZoom));
    });

    test('kMapStyleSourceKey is mirkfall_map and equals the single `sources` key of assets/maps/style.json', () {
      expect(kMapStyleSourceKey, equals('mirkfall_map'));
      final File styleFile = File('assets/maps/style.json');
      expect(styleFile.existsSync(), isTrue, reason: 'assets/maps/style.json missing — Phase 07-01 asset not in repo');
      final Map<String, Object?> style = Map<String, Object?>.from(jsonDecode(styleFile.readAsStringSync()) as Map);
      final Map<String, Object?> sourceByKey = Map<String, Object?>.from(style['sources'] as Map);
      expect(sourceByKey.keys, equals(<String>[kMapStyleSourceKey]), reason: 'TileProviders key MUST equal the style sources key (vector_map_tiles contract)');
    });

    test('kMapBackgroundColorArgb is 0xFFF5F1E8 and matches the style background layer paint', () {
      expect(kMapBackgroundColorArgb, equals(0xFFF5F1E8));
      expect(kMapBackgroundColorArgb, isA<int>());
      final Map<String, Object?> style = Map<String, Object?>.from(jsonDecode(File('assets/maps/style.json').readAsStringSync()) as Map);
      final List<Object?> layers = style['layers'] as List<Object?>;
      final Map<String, Object?> backgroundLayer = Map<String, Object?>.from(
        layers.cast<Map<Object?, Object?>>().firstWhere((Map<Object?, Object?> layer) => layer['id'] == 'background'),
      );
      final Map<String, Object?> paint = Map<String, Object?>.from(backgroundLayer['paint'] as Map);
      final String hexRgb = (paint['background-color'] as String).substring(1);
      const int opaqueAlphaShift = 24;
      final int expectedArgb = (0xFF << opaqueAlphaShift) | int.parse(hexRgb, radix: 16);
      expect(kMapBackgroundColorArgb, equals(expectedArgb));
    });

    test('kMapVectorTileCacheDirName is .vector_map', () {
      expect(kMapVectorTileCacheDirName, equals('.vector_map'));
      expect(kMapVectorTileCacheDirName, isA<String>());
    });

    test('kPmtilesArchiveOpenTimeout is 10 s (CLAUDE.md §Timeouts)', () {
      expect(kPmtilesArchiveOpenTimeout, equals(const Duration(seconds: 10)));
      expect(kPmtilesArchiveOpenTimeout, isA<Duration>());
    });

    test('user-location puck: 7 px blue disc with a 2 px white stroke (Phase 07 circle-layer values hoisted for CircleMarker)', () {
      expect(kMapUserPuckRadiusPx, equals(7.0));
      expect(kMapUserPuckRadiusPx, isA<double>());
      expect(kMapUserPuckColorArgb, equals(0xFF2B7CD6));
      expect(kMapUserPuckColorArgb, isA<int>());
      expect(kMapUserPuckBorderWidthPx, equals(2.0));
      expect(kMapUserPuckBorderWidthPx, isA<double>());
      expect(kMapUserPuckBorderColorArgb, equals(0xFFFFFFFF));
      expect(kMapUserPuckBorderColorArgb, isA<int>());
    });

    test('kMirkFogDiscQueryPaddingFactor is 0.5', () {
      expect(kMirkFogDiscQueryPaddingFactor, equals(0.5));
      expect(kMirkFogDiscQueryPaddingFactor, isA<double>());
    });

    test('verbose-only diagnostics carry the POC values (rollup 1 s, 240-sample buffers, frame-delta thresholds, smooth-coordinate delta)', () {
      expect(kMirkFogDiagRollupSeconds, equals(1));
      expect(kMirkFogDiagRollupSeconds, isA<int>());
      expect(kMirkFogDiagFrameDeltaBufferMaxSamples, equals(240));
      expect(kMirkFogDiagFogTransformBufferMaxSamples, equals(240));
      expect(kMirkFogDiagWispTransformBufferMaxSamples, equals(240));
      expect(kMirkFogDiagFrameDeltaMedianGreenMicros, equals(16000));
      expect(kMirkFogDiagFrameDeltaMedianYellowMicros, equals(24000));
      expect(kMirkFogDiagFrameDeltaP95GreenMicros, equals(32000));
      expect(kMirkFogDiagFrameDeltaP95YellowMicros, equals(48000));
      expect(kMirkFogDiagFrameDeltaMaxGreenMicros, equals(48000));
      expect(kMirkFogDiagFrameDeltaMaxYellowMicros, equals(72000));
      // Ladder ordering the probe overlay assumes: green < yellow on every axis, axes widen median < p95 < max.
      expect(kMirkFogDiagFrameDeltaMedianGreenMicros, lessThan(kMirkFogDiagFrameDeltaMedianYellowMicros));
      expect(kMirkFogDiagFrameDeltaP95GreenMicros, lessThan(kMirkFogDiagFrameDeltaP95YellowMicros));
      expect(kMirkFogDiagFrameDeltaMaxGreenMicros, lessThan(kMirkFogDiagFrameDeltaMaxYellowMicros));
      expect(kMirkFogDiagFrameDeltaMedianGreenMicros, lessThan(kMirkFogDiagFrameDeltaP95GreenMicros));
      expect(kMirkFogDiagFrameDeltaP95GreenMicros, lessThan(kMirkFogDiagFrameDeltaMaxGreenMicros));
      expect(kMirkFogDiagSmoothCoordinateMaxDelta, equals(2000.0));
      expect(kMirkFogDiagSmoothCoordinateMaxDelta, isA<double>());
      // A wrap regression would show up as a delta of one noise tile — the threshold must sit well above it.
      expect(kMirkFogDiagSmoothCoordinateMaxDelta, greaterThan(kMirkFogNoiseTilePx));
    });

    test('09.1-05 — the px/s wisp basis is gone and the world-basis kMirkWisp* constants are consumed by wisp_particle_system.dart', () {
      final String constantsSource = File('lib/config/constants.dart').readAsStringSync();
      expect(constantsSource, isNot(contains('kMirkFogWispInitialSpeedPx')), reason: 'BUG-014 trap: no screen-px wisp speed');
      final String systemSource = File('lib/infrastructure/mirk/wisp/wisp_particle_system.dart').readAsStringSync();
      for (final String symbol in <String>[
        'kMirkWispDriftMetersPerSecond',
        'kMirkWispCurlAccelMetersPerSecondSquared',
        'kMirkWispDragPerSecond',
        'kMirkWispMaxDtSeconds',
        'kMirkWispCurlInputScale',
        'kMirkFogWispWarmUpSeconds',
        'kMirkFogMetersPerWisp',
      ]) {
        expect(systemSource, contains(symbol), reason: '$symbol must drive the wisp system');
      }
    });

    test('pre-existing wisp + SDF constants inherited by the POC are UNCHANGED', () {
      expect(kMirkFogWispMaxCount, equals(200));
      expect(kMirkFogWispLifeSeconds, equals(2.5));
      expect(kMirkFogMetersPerWisp, equals(8.0));
      expect(kMirkFogWispWarmUpSeconds, equals(5.0));
      expect(kMirkFogWispPeakAlpha, equals(0.35));
      expect(kMirkFogWispBirthRadiusPx, equals(6.0));
      expect(kMirkFogWispDeathRadiusPx, equals(22.0));
    });
  });
}
