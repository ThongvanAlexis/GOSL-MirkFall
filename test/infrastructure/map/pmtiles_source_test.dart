// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:test/test.dart';

import '../../fakes/fake_installed_manifest_repository.dart';

void main() {
  group('localPmtilesUri — scheme rules', () {
    test('POSIX path gets the pmtiles://file:/// prefix', () {
      expect(localPmtilesUri('/var/mobile/maps/world.pmtiles'), 'pmtiles://file:///var/mobile/maps/world.pmtiles');
    });

    test('Windows path with drive letter gains the extra leading slash', () {
      expect(localPmtilesUri(r'C:\Users\dev\maps\fra.pmtiles'), 'pmtiles://file:///C:/Users/dev/maps/fra.pmtiles');
    });

    test('Windows path with mixed separators normalises to forward slashes', () {
      expect(localPmtilesUri(r'C:/Users\dev/maps\fra.pmtiles'), 'pmtiles://file:///C:/Users/dev/maps/fra.pmtiles');
    });

    test('Path containing spaces is preserved (no URL-encoding)', () {
      expect(localPmtilesUri('/with spaces/bar.pmtiles'), 'pmtiles://file:///with spaces/bar.pmtiles');
    });

    test('Every produced URI starts with pmtiles://file:///', () {
      final List<String> inputs = <String>['/a.pmtiles', r'C:\a.pmtiles', '/nested/dir/with/deep/path.pmtiles'];
      for (final String path in inputs) {
        expect(localPmtilesUri(path), startsWith('pmtiles://file:///'));
      }
    });

    test('No produced URI contains pmtiles://http', () {
      final List<String> inputs = <String>['/a.pmtiles', r'C:\a.pmtiles'];
      for (final String path in inputs) {
        expect(localPmtilesUri(path).toLowerCase(), isNot(contains('pmtiles://http')));
      }
    });
  });

  group('PmtilesSource — resolver contract', () {
    late FakeInstalledManifestRepository manifestPort;
    late PmtilesSource source;

    setUp(() {
      manifestPort = FakeInstalledManifestRepository();
      source = PmtilesSource(installedManifestPort: manifestPort, appSupportDir: '/app_support');
    });

    tearDown(() async {
      await manifestPort.close();
    });

    test('forCountry(null) returns the world bundle URI', () async {
      expect(await source.forCountry(null), 'pmtiles://file:///app_support/maps/world.pmtiles');
    });

    test('forCountry(CountryCode.world) returns the world bundle URI', () async {
      expect(await source.forCountry(CountryCode.world), 'pmtiles://file:///app_support/maps/world.pmtiles');
    });

    test('forCountry(uninstalled) falls back to the world bundle', () async {
      final CountryCode fra = CountryCode.parse('fra');
      // Manifest starts empty — fra is not installed.
      expect(await source.forCountry(fra), 'pmtiles://file:///app_support/maps/world.pmtiles');
    });

    test('forCountry(installed) returns the per-country URI', () async {
      final CountryCode fra = CountryCode.parse('fra');
      manifestPort.seedWith(
        InstalledManifest(
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
        ),
      );

      expect(await source.forCountry(fra), 'pmtiles://file:///app_support/maps/countries/fra.pmtiles');
    });

    test('forCountryOrWorld synchronous variant matches async output', () async {
      final CountryCode fra = CountryCode.parse('fra');
      final InstalledManifest snapshot = InstalledManifest(
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
      manifestPort.seedWith(snapshot);

      expect(source.forCountryOrWorld(fra, snapshot), await source.forCountry(fra));
      expect(source.forCountryOrWorld(null, snapshot), await source.forCountry(null));
    });

    test('PmtilesSource always emits local-only URIs (never http)', () async {
      final CountryCode fra = CountryCode.parse('fra');
      manifestPort.seedWith(
        InstalledManifest(
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
        ),
      );

      final String uriCountry = await source.forCountry(fra);
      final String uriWorld = await source.forCountry(null);
      for (final String u in <String>[uriCountry, uriWorld]) {
        expect(u.toLowerCase(), isNot(contains('pmtiles://http')));
        expect(u, startsWith('pmtiles://file:///'));
      }
    });
  });
}
