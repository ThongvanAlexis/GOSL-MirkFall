// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:test/test.dart';

void main() {
  group('map exceptions implement Exception (not Error)', () {
    test('MapAssetMissingException', () {
      const Exception ex = MapAssetMissingException(assetPath: 'assets/maps/world.pmtiles');
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });

    test('PmtilesCorruptException', () {
      final String expected = 'a' * 64;
      final String actual = 'b' * 64;
      final Exception ex = PmtilesCorruptException(filePath: '/tmp/fra.pmtiles', expectedSha256: expected, actualSha256: actual);
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });

    test('CountryNotInstalledException', () {
      final Exception ex = CountryNotInstalledException(alpha3: CountryCode.parse('fra'));
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });

    test('SchemaValidationException', () {
      const Exception ex = SchemaValidationException(documentPath: 'assets/maps/catalog.json', reason: 'missing alpha3');
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });

    test('DiskSpaceInsufficientException', () {
      const Exception ex = DiskSpaceInsufficientException(neededBytes: 2000, freeBytes: 500);
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });

    test('MapStyleCorruptException', () {
      const Exception ex = MapStyleCorruptException(reason: 'missing mirk_fog layer');
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });

    test('CannotDeleteWorldBundleException', () {
      const Exception ex = CannotDeleteWorldBundleException();
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });
  });

  group('toString() inlines structured fields (for log inspection)', () {
    test('MapAssetMissingException with reason', () {
      const MapAssetMissingException ex = MapAssetMissingException(assetPath: 'assets/maps/world.pmtiles', reason: 'empty bytes');
      final String s = ex.toString();
      expect(s, contains('assets/maps/world.pmtiles'));
      expect(s, contains('empty bytes'));
    });

    test('MapAssetMissingException without reason omits it cleanly', () {
      const MapAssetMissingException ex = MapAssetMissingException(assetPath: 'assets/maps/world.pmtiles');
      final String s = ex.toString();
      expect(s, contains('assets/maps/world.pmtiles'));
      expect(s, isNot(contains('reason=')));
    });

    test('PmtilesCorruptException', () {
      final String expected = 'a' * 64;
      final String actual = 'b' * 64;
      final PmtilesCorruptException ex = PmtilesCorruptException(filePath: '/tmp/fra.pmtiles', expectedSha256: expected, actualSha256: actual);
      final String s = ex.toString();
      expect(s, contains('/tmp/fra.pmtiles'));
      expect(s, contains(expected));
      expect(s, contains(actual));
    });

    test('CountryNotInstalledException', () {
      final CountryNotInstalledException ex = CountryNotInstalledException(alpha3: CountryCode.parse('fra'));
      expect(ex.toString(), contains('fra'));
    });

    test('SchemaValidationException', () {
      const SchemaValidationException ex = SchemaValidationException(documentPath: 'doc.json', reason: 'bad field');
      final String s = ex.toString();
      expect(s, contains('doc.json'));
      expect(s, contains('bad field'));
    });

    test('DiskSpaceInsufficientException', () {
      const DiskSpaceInsufficientException ex = DiskSpaceInsufficientException(neededBytes: 5000, freeBytes: 1234);
      final String s = ex.toString();
      expect(s, contains('5000'));
      expect(s, contains('1234'));
    });

    test('MapStyleCorruptException', () {
      const MapStyleCorruptException ex = MapStyleCorruptException(reason: 'layer 7 renamed');
      expect(ex.toString(), contains('layer 7 renamed'));
    });

    test('CannotDeleteWorldBundleException without reason', () {
      const CannotDeleteWorldBundleException ex = CannotDeleteWorldBundleException();
      final String s = ex.toString();
      // Always names the sentinel explicitly so logs are self-describing
      // even when no reason is supplied.
      expect(s, contains('wld'));
      expect(s, isNot(contains('reason=')));
    });

    test('CannotDeleteWorldBundleException with reason', () {
      const CannotDeleteWorldBundleException ex = CannotDeleteWorldBundleException(reason: 'settings reset triggered');
      final String s = ex.toString();
      expect(s, contains('wld'));
      expect(s, contains('settings reset triggered'));
    });
  });
}
