// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';

import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:test/test.dart';

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
  group('InstalledManifest.empty', () {
    test('has schemaVersion 1, empty catalogVersion, zero entries', () {
      final InstalledManifest m = InstalledManifest.empty();
      expect(m.schemaVersion, equals(1));
      expect(m.catalogVersion, isEmpty);
      expect(m.installed, isEmpty);
      expect(m.totalSizeBytes, equals(0));
    });
  });

  group('copyWithInsert', () {
    test('inserts a new country entry', () {
      final InstalledManifest m0 = InstalledManifest.empty();
      final InstalledCountry fra = _mk('fra', 1000);
      final InstalledManifest m1 = m0.copyWithInsert(fra);
      expect(m1.installed, hasLength(1));
      expect(m1.installed['fra'], equals(fra));
      // Original manifest is not mutated.
      expect(m0.installed, isEmpty);
    });

    test('replaces an existing country entry (same alpha3)', () {
      final InstalledManifest m0 = InstalledManifest.empty().copyWithInsert(_mk('fra', 1000));
      final InstalledCountry updated = _mk('fra', 2000);
      final InstalledManifest m1 = m0.copyWithInsert(updated);
      expect(m1.installed, hasLength(1));
      expect(m1.installed['fra']!.fileSize, equals(2000));
    });

    test('returns a new instance (not the receiver)', () {
      final InstalledManifest m0 = InstalledManifest.empty();
      final InstalledManifest m1 = m0.copyWithInsert(_mk('fra', 1000));
      expect(identical(m0, m1), isFalse);
    });
  });

  group('copyWithRemove', () {
    test('removes an existing entry', () {
      final InstalledManifest m0 = InstalledManifest.empty().copyWithInsert(_mk('fra', 1000)).copyWithInsert(_mk('deu', 2000));
      final InstalledManifest m1 = m0.copyWithRemove(CountryCode.parse('fra'));
      expect(m1.installed.keys, equals(<String>{'deu'}));
    });

    test('no-op when the key is absent', () {
      final InstalledManifest m0 = InstalledManifest.empty().copyWithInsert(_mk('fra', 1000));
      final InstalledManifest m1 = m0.copyWithRemove(CountryCode.parse('deu'));
      // Identity-preserving no-op so widget tests can skip diff work.
      expect(identical(m0, m1), isTrue);
    });
  });

  group('totalSizeBytes', () {
    test('sums over all entries', () {
      final InstalledManifest m = InstalledManifest.empty().copyWithInsert(_mk('fra', 1000)).copyWithInsert(_mk('deu', 2500)).copyWithInsert(_mk('esp', 500));
      expect(m.totalSizeBytes, equals(4000));
    });
  });

  group('JSON round-trip', () {
    test('empty manifest round-trip', () {
      final InstalledManifest m0 = InstalledManifest.empty();
      final String encoded = jsonEncode(m0.toJson());
      final InstalledManifest m1 = InstalledManifest.fromJson(jsonDecode(encoded) as Map<String, Object?>);
      expect(m1, equals(m0));
    });

    test('populated manifest round-trip over 3 countries', () {
      final InstalledManifest m0 = InstalledManifest(
        schemaVersion: 1,
        catalogVersion: 'v20260419',
        installed: <String, InstalledCountry>{'fra': _mk('fra', 1000), 'deu': _mk('deu', 2000), 'esp': _mk('esp', 500)},
      );
      final String encoded = jsonEncode(m0.toJson());
      final InstalledManifest m1 = InstalledManifest.fromJson(jsonDecode(encoded) as Map<String, Object?>);
      expect(m1, equals(m0));
      expect(m1.totalSizeBytes, equals(3500));
    });
  });

  group('@Assert schemaVersion', () {
    test('rejects schemaVersion != 1', () {
      expect(
        () => InstalledManifest(schemaVersion: 2, catalogVersion: '', installed: const <String, InstalledCountry>{}),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('InstalledCountry @Assert invariants', () {
    test('rejects zero fileSize', () {
      expect(
        () => InstalledCountry(
          alpha3: CountryCode.parse('fra'),
          installedAtUtc: DateTime.utc(2026, 4, 21),
          fileSize: 0,
          pmtilesVersion: 'v20260419',
          sha256: 'a' * 64,
          filePath: 'maps/countries/fra.pmtiles',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects wrong-length sha256', () {
      expect(
        () => InstalledCountry(
          alpha3: CountryCode.parse('fra'),
          installedAtUtc: DateTime.utc(2026, 4, 21),
          fileSize: 1000,
          pmtilesVersion: 'v20260419',
          sha256: 'a' * 32,
          filePath: 'maps/countries/fra.pmtiles',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects empty filePath', () {
      expect(
        () => InstalledCountry(
          alpha3: CountryCode.parse('fra'),
          installedAtUtc: DateTime.utc(2026, 4, 21),
          fileSize: 1000,
          pmtilesVersion: 'v20260419',
          sha256: 'a' * 64,
          filePath: '',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
