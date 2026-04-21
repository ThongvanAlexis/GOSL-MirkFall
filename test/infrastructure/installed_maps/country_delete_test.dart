// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/infrastructure/installed_maps/country_delete_service.dart';
import 'package:path/path.dart' as p;

import '../../fakes/fake_installed_manifest_repository.dart';

InstalledCountry _makeCountry(String alpha3Raw) {
  return InstalledCountry(
    alpha3: CountryCode.parse(alpha3Raw),
    installedAtUtc: DateTime.utc(2026, 4, 21, 12),
    fileSize: 1024,
    pmtilesVersion: 'v20260419',
    sha256: '0' * 64,
    filePath: 'maps/countries/$alpha3Raw.pmtiles',
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_country_delete_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CountryDeleteService — happy delete', () {
    test('removes the .pmtiles file AND the manifest entry', () async {
      // Seed disk + manifest.
      final File file = File(p.join(tempDir.path, 'maps', 'countries', 'fra.pmtiles'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(<int>[0x00, 0x01, 0x02]);

      final FakeInstalledManifestRepository repo = FakeInstalledManifestRepository(initial: InstalledManifest.empty().copyWithInsert(_makeCountry('fra')));
      addTearDown(repo.close);

      final CountryDeleteService service = CountryDeleteService(manifestRepository: repo, appSupportDir: tempDir.path);
      await service.deleteCountry(CountryCode.parse('fra'));

      expect(file.existsSync(), isFalse);
      expect((await repo.read()).installed.containsKey('fra'), isFalse);
    });

    test('no-op when alpha3 is absent from manifest (idempotent)', () async {
      final FakeInstalledManifestRepository repo = FakeInstalledManifestRepository();
      addTearDown(repo.close);

      final CountryDeleteService service = CountryDeleteService(manifestRepository: repo, appSupportDir: tempDir.path);
      // Does not throw, does not write to the manifest.
      await service.deleteCountry(CountryCode.parse('fra'));
      expect(repo.writesObserved, 0);
    });
  });

  group('CountryDeleteService — world-bundle guard', () {
    test('CountryCode.world sentinel is rejected with CannotDeleteWorldBundleException', () async {
      final FakeInstalledManifestRepository repo = FakeInstalledManifestRepository();
      addTearDown(repo.close);

      final CountryDeleteService service = CountryDeleteService(manifestRepository: repo, appSupportDir: tempDir.path);
      await expectLater(service.deleteCountry(CountryCode.world), throwsA(isA<CannotDeleteWorldBundleException>()));
    });

    test('CountryCode.parse("wld") — parse path — is ALSO rejected (sentinel equality proof)', () async {
      final FakeInstalledManifestRepository repo = FakeInstalledManifestRepository();
      addTearDown(repo.close);

      final CountryDeleteService service = CountryDeleteService(manifestRepository: repo, appSupportDir: tempDir.path);
      // Prove the comparison uses equality against the domain sentinel,
      // not a raw string literal — the reservation contract documented on
      // CountryCode must hold: parse('wld') == CountryCode.world.
      final CountryCode parsedWorld = CountryCode.parse('wld');
      expect(parsedWorld, CountryCode.world);

      await expectLater(service.deleteCountry(parsedWorld), throwsA(isA<CannotDeleteWorldBundleException>()));
    });
  });
}
