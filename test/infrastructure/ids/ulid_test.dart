// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math';

import 'package:mirkfall/infrastructure/ids/ulid.dart';
import 'package:test/test.dart';

void main() {
  group('Ulid.generate', () {
    test('produces exactly 26 chars', () {
      final id = Ulid.generate(now: DateTime(2026, 4, 18), rng: Random(1));
      expect(id.length, 26);
    });

    test('uses only Crockford base32 alphabet (no I/L/O/U)', () {
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final id = Ulid.generate(now: DateTime(2026, 4, 18), rng: Random(1));
      for (final char in id.split('')) {
        expect(alphabet.contains(char), isTrue, reason: 'char "$char" not in alphabet');
      }
      for (final forbidden in ['I', 'L', 'O', 'U']) {
        expect(id.contains(forbidden), isFalse, reason: 'forbidden char "$forbidden" present in $id');
      }
    });

    test('k-sortable: later timestamp produces lexically later string with fixed rng', () {
      final earlier = Ulid.generate(now: DateTime(2026, 4, 18), rng: Random(42));
      final later = Ulid.generate(now: DateTime(2026, 5, 18), rng: Random(42));
      // Time part = first 10 chars; random tail identical due to same seed.
      expect(earlier.compareTo(later), lessThan(0));
      expect(earlier.substring(10), later.substring(10), reason: 'random tail should be identical with fixed seed');
    });

    test('same seed and same timestamp produce identical IDs (reproducibility)', () {
      final id1 = Ulid.generate(now: DateTime(2026, 4, 18), rng: Random(7));
      final id2 = Ulid.generate(now: DateTime(2026, 4, 18), rng: Random(7));
      expect(id1, id2);
    });

    test('different timestamps differ in time part (first 10 chars)', () {
      final t1 = Ulid.generate(now: DateTime(2026, 4, 18), rng: Random(1));
      final t2 = Ulid.generate(now: DateTime(2026, 4, 19), rng: Random(1));
      expect(t1.substring(0, 10), isNot(t2.substring(0, 10)));
    });
  });
}
