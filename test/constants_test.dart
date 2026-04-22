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

    test('kInitialSessionMapZoom is 13 (neighborhood/city view showing 20m reveal)', () {
      expect(kInitialSessionMapZoom, equals(13));
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
}
