// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

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

  // Logging reliability constants — lowered + added 2026-04-25 to fix
  // UAT-walk log truncation (records < threshold sat in buffer until
  // OS suspended the process). See lib/config/constants.dart docstrings
  // for the rationale.
  test('kFileLoggerFlushEveryNRecords is 5 (lowered from 20 — UAT-walk reliability fix)', () {
    expect(kFileLoggerFlushEveryNRecords, equals(5));
    expect(kFileLoggerFlushEveryNRecords, isA<int>());
  });

  test('kFileLoggerFlushPeriodSeconds is 2 (backstop timer interval)', () {
    expect(kFileLoggerFlushPeriodSeconds, equals(2));
    expect(kFileLoggerFlushPeriodSeconds, isA<int>());
  });

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

    test('atmospheric drift Z speeds form a 3-tier ladder (far < mid < near)', () {
      expect(kMirkFogAtmosphericDriftZFar, lessThan(kMirkFogAtmosphericDriftZMid));
      expect(kMirkFogAtmosphericDriftZMid, lessThan(kMirkFogAtmosphericDriftZNear));
      expect(kMirkFogAtmosphericDriftZFar, equals(0.018));
      expect(kMirkFogAtmosphericDriftZMid, equals(0.035));
      expect(kMirkFogAtmosphericDriftZNear, equals(0.075));
    });

    test('heavenly drift Z speeds form a 3-tier ladder (far < mid < near, all > atmospheric)', () {
      expect(kMirkFogHeavenlyDriftZFar, lessThan(kMirkFogHeavenlyDriftZMid));
      expect(kMirkFogHeavenlyDriftZMid, lessThan(kMirkFogHeavenlyDriftZNear));
      expect(kMirkFogHeavenlyDriftZFar, greaterThan(kMirkFogAtmosphericDriftZFar));
    });

    test('atmospheric scale ladder (far < mid < near)', () {
      expect(kMirkFogAtmosphericScaleFar, equals(0.6));
      expect(kMirkFogAtmosphericScaleMid, equals(1.4));
      expect(kMirkFogAtmosphericScaleNear, equals(3.0));
      expect(kMirkFogAtmosphericScaleFar, lessThan(kMirkFogAtmosphericScaleMid));
      expect(kMirkFogAtmosphericScaleMid, lessThan(kMirkFogAtmosphericScaleNear));
    });

    test('heavenly scale ladder (far < mid < near)', () {
      expect(kMirkFogHeavenlyScaleFar, equals(0.8));
      expect(kMirkFogHeavenlyScaleMid, equals(1.8));
      expect(kMirkFogHeavenlyScaleNear, equals(3.6));
    });

    test('opacity weights sum to ~1.0', () {
      final sum = kMirkFogOpacityFar + kMirkFogOpacityMid + kMirkFogOpacityNear;
      expect(sum, closeTo(1.0, 0.001));
      expect(kMirkFogOpacityFar, greaterThan(kMirkFogOpacityMid));
      expect(kMirkFogOpacityMid, greaterThan(kMirkFogOpacityNear));
    });

    test('curl noise tunables', () {
      // Amplitude bumped 2026-04-25 (BUG-009 follow-up) — initial 0.18
      // produced eddies too small to perceive. 0.45 is the new visible
      // baseline.
      expect(kMirkFogCurlAmplitude, equals(0.45));
      expect(kMirkFogCurlScale, equals(1.0));
    });

    test('faux-shading tunables', () {
      // Light offset + strength bumped 2026-04-25 (BUG-009 follow-up) —
      // 0.04 / 0.55 produced near-zero shading delta, so the fog read as
      // flat. 0.12 / 1.4 give clearly visible bright/dark sides.
      expect(kMirkFogLightDirRadians, closeTo(-0.785398, 0.0001));
      expect(kMirkFogLightOffset, equals(0.12));
      expect(kMirkFogLightStrength, equals(1.4));
    });

    test('hue variation tunables', () {
      // Hue strength bumped 2026-04-25 (BUG-009 follow-up) — 0.35 was
      // below screen-noise threshold. 0.7 gives a clear material-tint
      // shift without rainbowing.
      expect(kMirkFogHueNoiseScale, equals(0.45));
      expect(kMirkFogHueStrength, equals(0.7));
    });

    test('two-stop watercolour boundary distances', () {
      expect(kMirkFogBoundarySharpDistance, equals(0.025));
      expect(kMirkFogBoundaryBleedDistance, equals(0.085));
      // Bleed must be longer than sharp — this is the very definition of
      // "two stop": short crisp core + long trailing fade.
      expect(kMirkFogBoundaryBleedDistance, greaterThan(kMirkFogBoundarySharpDistance));
    });

    test('boundary curl edge band is positive and finite', () {
      expect(kMirkFogBoundaryEdgeBand, equals(0.07));
      expect(kMirkFogBoundaryEdgeBand, greaterThan(0.0));
    });

    test('SDF resolution is a positive power of two-ish (256)', () {
      expect(kMirkFogSdfResolution, equals(256));
      expect(kMirkFogSdfResolution, isA<int>());
    });

    test('wisp particle tunables', () {
      expect(kMirkFogWispMaxCount, equals(200));
      expect(kMirkFogWispSpawnPerCell, equals(2));
      expect(kMirkFogWispLifeSeconds, equals(2.5));
      expect(kMirkFogWispInitialSpeedPx, equals(18.0));
      expect(kMirkFogWispBirthRadiusPx, equals(6.0));
      expect(kMirkFogWispDeathRadiusPx, equals(22.0));
      // Death radius > birth radius — wisps grow as they fade (puff
      // dispersing), not the reverse.
      expect(kMirkFogWispDeathRadiusPx, greaterThan(kMirkFogWispBirthRadiusPx));
      expect(kMirkFogWispPeakAlpha, equals(0.35));
      expect(kMirkFogWispPeakAlpha, lessThan(1.0));
    });
  });
}
