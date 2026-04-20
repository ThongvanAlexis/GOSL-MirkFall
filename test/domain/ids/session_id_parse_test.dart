// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:test/test.dart';

void main() {
  group('SessionId.parse', () {
    test('acceptsCanonicalPrefixedValue', () {
      // 26-char Crockford ULID body — matches isValid's length contract
      // (26 chars total: 01HR + 22 zeros).
      const raw = 'sess_01HR0000000000000000000000';
      final id = SessionId.parse(raw);
      expect(id.value, raw);
      expect(id.isValid, isTrue);
    });

    test('throwsArgumentErrorOnMissingPrefix', () {
      expect(() => SessionId.parse('01HR0000000000000000000A'), throwsA(isA<ArgumentError>()));
    });

    test('throwsArgumentErrorOnWrongPrefix', () {
      // Phase 06 Should #8 regression guard — mirrors FixId.parse.
      // A fix_<ulid> accidentally fed into a SessionId resume path must
      // fail LOUDLY rather than construct a silently-malformed SessionId.
      expect(() => SessionId.parse('fix_01HR0000000000000000000A'), throwsA(isA<ArgumentError>()));
    });
  });
}
