// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/map/country_code.dart';
import 'package:test/test.dart';

void main() {
  group('CountryCode.parse', () {
    test('accepts uppercase input and lower-cases it', () {
      final CountryCode fra = CountryCode.parse('FRA');
      expect(fra.value, equals('fra'));
    });

    test('accepts mixed-case input and lower-cases it', () {
      final CountryCode deu = CountryCode.parse('DeU');
      expect(deu.value, equals('deu'));
    });

    test('accepts already-lowercase input', () {
      final CountryCode esp = CountryCode.parse('esp');
      expect(esp.value, equals('esp'));
    });

    test('rejects 2-char input', () {
      expect(() => CountryCode.parse('fr'), throwsFormatException);
    });

    test('rejects 4-char input', () {
      expect(() => CountryCode.parse('fra4'), throwsFormatException);
    });

    test('rejects empty input', () {
      expect(() => CountryCode.parse(''), throwsFormatException);
    });

    test('rejects digit-containing input', () {
      expect(() => CountryCode.parse('fr1'), throwsFormatException);
    });

    test('rejects non-ASCII input', () {
      expect(() => CountryCode.parse('fré'), throwsFormatException);
    });

    test('rejects punctuation', () {
      expect(() => CountryCode.parse('f-a'), throwsFormatException);
    });
  });

  group('CountryCode equality', () {
    test('two parses of the same raw are equal', () {
      final CountryCode a = CountryCode.parse('fra');
      final CountryCode b = CountryCode.parse('fra');
      expect(a, equals(b));
    });

    test('case-insensitive parses are equal', () {
      final CountryCode a = CountryCode.parse('FRA');
      final CountryCode b = CountryCode.parse('fra');
      expect(a, equals(b));
    });

    test('distinct codes are not equal', () {
      expect(CountryCode.parse('fra'), isNot(equals(CountryCode.parse('deu'))));
    });
  });

  group('CountryCode.world sentinel', () {
    test('exposes the reserved "wld" value', () {
      expect(CountryCode.world.value, equals('wld'));
    });

    test('parse("wld") equals CountryCode.world', () {
      // The sentinel IS a valid parsed code — callers that want to reject
      // the world bundle must compare against CountryCode.world, not the
      // string literal 'wld'. See the class docstring for the reservation
      // contract.
      expect(CountryCode.parse('wld'), equals(CountryCode.world));
    });

    test('parse("WLD") equals CountryCode.world (case-insensitive)', () {
      expect(CountryCode.parse('WLD'), equals(CountryCode.world));
    });
  });

  group('json converter functions', () {
    test('round-trip: fra', () {
      final CountryCode original = CountryCode.parse('fra');
      final String encoded = countryCodeToJson(original);
      expect(encoded, equals('fra'));
      final CountryCode decoded = countryCodeFromJson(encoded);
      expect(decoded, equals(original));
    });

    test('countryCodeFromJson rejects invalid input', () {
      expect(() => countryCodeFromJson('BAD!'), throwsFormatException);
    });
  });
}
