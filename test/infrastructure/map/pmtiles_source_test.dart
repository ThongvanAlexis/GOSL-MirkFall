// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../fakes/fake_installed_manifest_repository.dart';

/// Absolute support directory shaped for the host OS so `p.isAbsolute`
/// holds on both POSIX and Windows dev hosts.
final String _appSupportDir = p.isAbsolute('/app_support') ? '/app_support' : r'C:\app_support';

InstalledManifest _manifestWithFra(CountryCode fra) => InstalledManifest(
  schemaVersion: 1,
  catalogVersion: 'v20260419',
  installed: <String, InstalledCountry>{
    'fra': InstalledCountry(
      alpha3: fra,
      installedAtUtc: DateTime.utc(2026, 4, 20),
      fileSize: 1024,
      pmtilesVersion: 'v20260419',
      sha256: 'a' * 64,
      filePath: 'maps/countries/fra.pmtiles',
    ),
  },
);

void main() {
  group('PmtilesSource — absolute path resolver (Phase 09.1: path, never a URI)', () {
    late FakeInstalledManifestRepository manifestPort;
    late PmtilesSource source;
    late String worldFilename;

    setUp(() {
      manifestPort = FakeInstalledManifestRepository();
      source = PmtilesSource(installedManifestPort: manifestPort, appSupportDir: _appSupportDir);
      worldFilename = p.join(_appSupportDir, kWorldPmtilesInternalPath);
    });

    tearDown(() async {
      await manifestPort.close();
    });

    test('forCountryOrWorld(null, snapshot) returns p.join(appSupportDir, kWorldPmtilesInternalPath)', () {
      expect(source.forCountryOrWorld(null, InstalledManifest.empty()), equals(worldFilename));
    });

    test('forCountryOrWorld(CountryCode.world, snapshot) returns the world path', () {
      expect(source.forCountryOrWorld(CountryCode.world, InstalledManifest.empty()), equals(worldFilename));
    });

    test('forCountryOrWorld(fra, snapshotWithFra) returns p.join(appSupportDir, entry.filePath)', () {
      final CountryCode fra = CountryCode.parse('fra');
      expect(source.forCountryOrWorld(fra, _manifestWithFra(fra)), equals(p.join(_appSupportDir, 'maps/countries/fra.pmtiles')));
    });

    test('forCountryOrWorld(uninstalled country) falls back to the world path', () {
      expect(source.forCountryOrWorld(CountryCode.parse('deu'), InstalledManifest.empty()), equals(worldFilename));
    });

    test('forCountry (async) delegates to forCountryOrWorld with a fresh manifest read', () async {
      final CountryCode fra = CountryCode.parse('fra');
      expect(await source.forCountry(fra), equals(worldFilename), reason: 'empty manifest → world');
      manifestPort.seedWith(_manifestWithFra(fra));
      expect(await source.forCountry(fra), equals(source.forCountryOrWorld(fra, _manifestWithFra(fra))));
      expect(await source.forCountry(null), equals(worldFilename));
    });

    test('every result is an absolute filesystem path that never starts with http or pmtiles:// (MAP-05)', () async {
      final CountryCode fra = CountryCode.parse('fra');
      manifestPort.seedWith(_manifestWithFra(fra));
      final List<String> results = <String>[
        await source.forCountry(fra),
        await source.forCountry(null),
        await source.forCountry(CountryCode.world),
        source.forCountryOrWorld(CountryCode.parse('deu'), InstalledManifest.empty()),
      ];
      for (final String path in results) {
        expect(p.isAbsolute(path), isTrue, reason: '$path must be absolute — PmTilesVectorTileProvider.fromSource routes it to FileAt');
        expect(path.toLowerCase(), isNot(startsWith('http')), reason: 'an http(s) prefix would make pmtiles open an HttpAt reader');
        expect(path.toLowerCase(), isNot(startsWith('pmtiles://')), reason: 'the pmtiles:// URI scheme was a MapLibre protocol-handler artefact');
        expect(path, endsWith('.pmtiles'));
      }
    });
  });
}
