// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/infrastructure/ids/random_id_generator.dart';
import 'package:test/test.dart';

void main() {
  group('RandomIdGenerator', () {
    test('10k newIds are unique (collision probability negligible with ULID entropy)', () {
      final gen = RandomIdGenerator();
      final idSet = <String>{};
      for (var i = 0; i < 10000; i++) {
        idSet.add(gen.newId('rvt_'));
      }
      expect(idSet.length, 10000);
    });

    test('newId prefix and length invariants', () {
      final gen = RandomIdGenerator();
      final id = gen.newId('mst_');
      expect(id.startsWith('mst_'), isTrue);
      expect(id.length, 30);
    });

    test('different prefixes round-trip cleanly', () {
      final gen = RandomIdGenerator();
      expect(gen.newId('sess_').startsWith('sess_'), isTrue);
      expect(gen.newId('mrk_').startsWith('mrk_'), isTrue);
      expect(gen.newId('cat_').startsWith('cat_'), isTrue);
      expect(gen.newId('phr_').startsWith('phr_'), isTrue);
    });
  });
}
