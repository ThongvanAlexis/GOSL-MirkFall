// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/infrastructure/ids/seeded_id_generator.dart';
import 'package:test/test.dart';

void main() {
  group('SeededIdGenerator', () {
    test('same seed + same fixedNow produces same sequence across runs', () {
      final fixedNow = DateTime.utc(2026, 4, 18, 9);
      final gen1 = SeededIdGenerator(seed: 42, fixedNow: fixedNow);
      final gen2 = SeededIdGenerator(seed: 42, fixedNow: fixedNow);
      final seq1 = [for (var i = 0; i < 5; i++) gen1.newId('sess_')];
      final seq2 = [for (var i = 0; i < 5; i++) gen2.newId('sess_')];
      expect(seq1, seq2);
    });

    test('newId respects prefix', () {
      final gen = SeededIdGenerator(seed: 1, fixedNow: DateTime.utc(2026, 4, 18));
      expect(gen.newId('sess_').startsWith('sess_'), isTrue);
      expect(gen.newId('mrk_').startsWith('mrk_'), isTrue);
    });

    test('emits 31-char string for 5-char prefix', () {
      final gen = SeededIdGenerator(seed: 1, fixedNow: DateTime.utc(2026, 4, 18));
      expect(gen.newId('sess_').length, 31);
    });

    test('successive calls advance the RNG (different IDs with same prefix)', () {
      final gen = SeededIdGenerator(seed: 1, fixedNow: DateTime.utc(2026, 4, 18));
      final first = gen.newId('sess_');
      final second = gen.newId('sess_');
      expect(first, isNot(second));
    });

    test('without fixedNow falls back to wall-clock UTC', () {
      // Wall-clock fallback: just confirm the generator does not throw and
      // returns a well-formed prefixed ID.
      final gen = SeededIdGenerator(seed: 1);
      final id = gen.newId('rvt_');
      expect(id.startsWith('rvt_'), isTrue);
      expect(id.length, 30);
    });
  });
}
