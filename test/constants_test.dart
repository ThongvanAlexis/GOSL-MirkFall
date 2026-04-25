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

  // Phase 07 (Map Integration) — every new Phase 07 slot gets a value +
  // type guard here so a silent rename/retype is caught at test time.
  group('Phase 07 constants', () {
    test(
      'kHttpTimeout is 30_000 ms (lowered at Phase 07-07 device-smoke — CDN edges close around 30-45 s)',
      () {
        expect(kHttpTimeout, equals(30000));
        expect(kHttpTimeout, isA<int>());
      },
    );

    test('kMapCatalogAssetPath is assets/maps/catalog.json', () {
      expect(kMapCatalogAssetPath, equals('assets/maps/catalog.json'));
      expect(kMapCatalogAssetPath, isA<String>());
    });

    test('kWorldPmtilesAssetPath is assets/maps/world.pmtiles', () {
      expect(kWorldPmtilesAssetPath, equals('assets/maps/world.pmtiles'));
    });

    test(
      'kWorldPmtilesInternalPath is maps/world.pmtiles (relative to <app_support>)',
      () {
        expect(kWorldPmtilesInternalPath, equals('maps/world.pmtiles'));
      },
    );

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

    test(
      'kInitialSessionMapZoom is 13 (neighborhood/city view showing 20m reveal)',
      () {
        expect(kInitialSessionMapZoom, equals(13));
        expect(kInitialSessionMapZoom, isA<int>());
      },
    );

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
}
