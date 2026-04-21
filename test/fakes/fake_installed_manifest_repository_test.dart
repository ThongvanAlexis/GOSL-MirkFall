// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:test/test.dart';

import 'fake_installed_manifest_repository.dart';

InstalledCountry _mk(String alpha3, int size) {
  return InstalledCountry(
    alpha3: CountryCode.parse(alpha3),
    installedAtUtc: DateTime.utc(2026, 4, 21),
    fileSize: size,
    pmtilesVersion: 'v20260419',
    sha256: 'a' * 64,
    filePath: 'maps/countries/$alpha3.pmtiles',
  );
}

void main() {
  group('FakeInstalledManifestRepository', () {
    late FakeInstalledManifestRepository repo;

    setUp(() {
      repo = FakeInstalledManifestRepository();
    });

    tearDown(() async {
      await repo.close();
    });

    test('default state is empty', () async {
      final InstalledManifest m = await repo.read();
      expect(m.installed, isEmpty);
      expect(m.schemaVersion, equals(1));
      expect(repo.writesObserved, equals(0));
    });

    test('seedWith replaces cached state without emitting', () async {
      final InstalledManifest seed = InstalledManifest.empty().copyWithInsert(_mk('fra', 1000));
      repo.seedWith(seed);

      final InstalledManifest actual = await repo.read();
      expect(actual.installed.containsKey('fra'), isTrue);
      // seedWith must NOT bump the write counter — it is a test-only
      // load-from-disk substitute.
      expect(repo.writesObserved, equals(0));
    });

    test('write updates the cached snapshot', () async {
      final InstalledManifest target = InstalledManifest.empty().copyWithInsert(_mk('deu', 2000));
      await repo.write(target);

      final InstalledManifest round = await repo.read();
      expect(round, equals(target));
      expect(repo.writesObserved, equals(1));
    });

    test('write emits on the updates stream', () async {
      final Future<InstalledManifest> next = repo.updates.first;
      final InstalledManifest target = InstalledManifest.empty().copyWithInsert(_mk('esp', 500));
      await repo.write(target);
      final InstalledManifest emitted = await next;
      expect(emitted, equals(target));
    });

    test('simulateWriteFailure: next write throws and resets the flag', () async {
      repo.simulateWriteFailure = true;
      final InstalledManifest target = InstalledManifest.empty().copyWithInsert(_mk('fra', 1000));
      expect(() => repo.write(target), throwsA(isA<Exception>()));

      // Pump the failure.
      try {
        await repo.write(target);
      } on Exception {
        /* expected */
      }

      // Flag auto-resets so the recovery write succeeds.
      await repo.write(target);
      final InstalledManifest round = await repo.read();
      expect(round.installed.containsKey('fra'), isTrue);
      // 3 write() calls total: 1 failing + 1 failing (try/catch) + 1 success.
      expect(repo.writesObserved, equals(3));
    });

    test('writesObserved counts every write, including failed ones', () async {
      await repo.write(InstalledManifest.empty());
      repo.simulateWriteFailure = true;
      try {
        await repo.write(InstalledManifest.empty());
      } on Exception {
        /* expected */
      }
      await repo.write(InstalledManifest.empty());
      expect(repo.writesObserved, equals(3));
    });
  });
}
