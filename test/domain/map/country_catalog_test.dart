// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';

void main() {
  // rootBundle requires the test binding to be initialised. Safe to call
  // here — `flutter test` invokes this file through the test runner which
  // already sets the binding up under the hood.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CountryCatalog parses the synthetic mini_catalog.json', () {
    late Map<String, Object?> mini;

    setUpAll(() {
      // Load the fixture from disk (Phase 07-01 committed it). Going via
      // File keeps the assertion independent of pubspec.yaml `assets:`
      // declaration (the fixture is NOT shipped in the APK — it is a
      // test-only artifact).
      final File f = File('test/fixtures/catalogs/mini_catalog.json');
      mini = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    });

    test('has 6 countries with the expected alpha3s', () {
      final CountryCatalog catalog = CountryCatalog.fromJson(mini);
      expect(catalog.countries.length, equals(6));
      expect(catalog.countries.map((CountryEntry c) => c.alpha3.value).toSet(), equals(<String>{'aru', 'esp', 'deu', 'gbr', 'fra', 'usa'}));
    });

    test('chunk counts match fixture shape (1/1/2/1/3/4)', () {
      final CountryCatalog catalog = CountryCatalog.fromJson(mini);
      final Map<String, int> byCode = <String, int>{for (final CountryEntry c in catalog.countries) c.alpha3.value: c.parts.length};
      expect(byCode['aru'], equals(1));
      expect(byCode['esp'], equals(1));
      expect(byCode['deu'], equals(2));
      expect(byCode['gbr'], equals(1));
      expect(byCode['fra'], equals(3));
      expect(byCode['usa'], equals(4));
    });

    test('every chunk carries a 64-char hex sha256 and positive size', () {
      final CountryCatalog catalog = CountryCatalog.fromJson(mini);
      for (final CountryEntry c in catalog.countries) {
        for (final ChunkPart p in c.parts) {
          expect(p.sha256.length, equals(64), reason: 'chunk sha256 length for ${c.alpha3.value}');
          expect(p.size, greaterThan(0));
        }
      }
    });

    test('CountryEntry.totalBytes equals reassembled.size for well-formed entries', () {
      final CountryCatalog catalog = CountryCatalog.fromJson(mini);
      for (final CountryEntry c in catalog.countries) {
        expect(c.totalBytes, equals(c.reassembled.size), reason: 'totalBytes mismatch for ${c.alpha3.value}');
      }
    });

    test('round-trip: fromJson(jsonDecode(jsonEncode(toJson))) equals original', () {
      // Nested Freezed entities serialize through `dynamic.toJson` at
      // jsonEncode time (json_serializable's default `explicitToJson:
      // false` mode emits raw nested instances in the parent `toJson`).
      // The realistic round-trip is therefore through
      // jsonEncode → jsonDecode, which matches the export/import path.
      final CountryCatalog original = CountryCatalog.fromJson(mini);
      final String encoded = jsonEncode(original.toJson());
      final CountryCatalog decoded = CountryCatalog.fromJson(jsonDecode(encoded) as Map<String, Object?>);
      expect(decoded, equals(original));
    });
  });

  group('CountryCatalog schema validation', () {
    test('missing alpha3 throws (json_serializable default)', () {
      final Map<String, Object?> bad = <String, Object?>{
        'countries': <Map<String, Object?>>[
          <String, Object?>{
            // 'alpha3': missing
            'name': 'Broken',
            'parts': <Map<String, Object?>>[
              <String, Object?>{'sha256': 'a' * 64, 'size': 1024, 'url': 'https://example.test/b.part01'},
            ],
            'reassembled': <String, Object?>{'sha256': 'a' * 64, 'size': 1024},
          },
        ],
      };
      expect(() => CountryCatalog.fromJson(bad), throwsA(anything));
    });

    test('empty countries list fails the @Assert', () {
      final Map<String, Object?> bad = <String, Object?>{'countries': <Map<String, Object?>>[]};
      expect(() => CountryCatalog.fromJson(bad), throwsA(isA<AssertionError>()));
    });
  });

  group('CountryCatalog.catalogVersion (real asset)', () {
    test('assets/maps/catalog.json parses and catalogVersion is "v20260419"', () async {
      final String raw = await rootBundle.loadString('assets/maps/catalog.json');
      final CountryCatalog catalog = CountryCatalog.fromJson(jsonDecode(raw) as Map<String, Object?>);
      expect(catalog.countries.length, greaterThan(200), reason: 'real catalog has 249 countries (Phase 07-01)');
      expect(catalog.catalogVersion, equals('v20260419'));
    });
  });

  group('CountryCatalog.catalogVersion error handling', () {
    test('URL not matching /releases/download/<tag>/ throws FormatException', () {
      final Map<String, Object?> bad = <String, Object?>{
        'countries': <Map<String, Object?>>[
          <String, Object?>{
            'alpha3': 'xxx',
            'name': 'Nowhere',
            'parts': <Map<String, Object?>>[
              <String, Object?>{'sha256': 'a' * 64, 'size': 1024, 'url': 'https://example.test/no-tag-here.part01'},
            ],
            'reassembled': <String, Object?>{'sha256': 'a' * 64, 'size': 1024},
          },
        ],
      };
      final CountryCatalog catalog = CountryCatalog.fromJson(bad);
      expect(() => catalog.catalogVersion, throwsFormatException);
    });
  });
}
