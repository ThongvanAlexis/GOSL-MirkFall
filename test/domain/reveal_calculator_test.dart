// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/revealed/reveal_calculator.dart';
import 'package:test/test.dart';

void main() {
  group('mergeBitmap (MIRK-03 algebra)', () {
    test('bytewise OR of known inputs', () {
      final a = Uint8List.fromList([0x0F, 0xF0]);
      final b = Uint8List.fromList([0xF0, 0x0F]);
      expect(mergeBitmap(a, b), Uint8List.fromList([0xFF, 0xFF]));
    });

    test('length mismatch throws ArgumentError', () {
      expect(
        () => mergeBitmap(Uint8List(2), Uint8List(3)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'idempotent: mergeBitmap(mergeBitmap(a, b), a) == mergeBitmap(a, b)',
      () {
        final a = Uint8List.fromList(List.generate(16, (i) => i * 7 & 0xFF));
        final b = Uint8List.fromList(List.generate(16, (i) => i * 13 & 0xFF));
        final ab = mergeBitmap(a, b);
        final aba = mergeBitmap(ab, a);
        expect(aba, ab);
      },
    );

    test('commutative: mergeBitmap(a, b) == mergeBitmap(b, a)', () {
      final a = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
      final b = Uint8List.fromList([0x87, 0x65, 0x43, 0x21]);
      expect(mergeBitmap(a, b), mergeBitmap(b, a));
    });

    test('monotone at the bit level: no bit ever turns off', () {
      final a = Uint8List.fromList(List.generate(32, (i) => i * 3 & 0xFF));
      final b = Uint8List.fromList(List.generate(32, (i) => i * 5 & 0xFF));
      final merged = mergeBitmap(a, b);
      for (var i = 0; i < merged.length; i++) {
        expect(
          merged[i] | a[i],
          merged[i],
          reason:
              'byte $i: merged=${merged[i].toRadixString(16)} a=${a[i].toRadixString(16)}',
        );
        expect(merged[i] | b[i], merged[i]);
      }
    });

    test('does not mutate the input arrays', () {
      final a = Uint8List.fromList([0x0F, 0xF0]);
      final b = Uint8List.fromList([0xF0, 0x0F]);
      mergeBitmap(a, b);
      expect(a, Uint8List.fromList([0x0F, 0xF0]));
      expect(b, Uint8List.fromList([0xF0, 0x0F]));
    });

    test('works at the real Phase 03 bitmap size (512 bytes)', () {
      final a = Uint8List(kRevealedTileBitmapBytes);
      final b = Uint8List(kRevealedTileBitmapBytes);
      for (var i = 0; i < a.length; i++) {
        a[i] = (i * 7) & 0xFF;
        b[i] = (i * 11) & 0xFF;
      }
      final merged = mergeBitmap(a, b);
      expect(merged.length, 512);
      for (var i = 0; i < merged.length; i++) {
        expect(merged[i], a[i] | b[i]);
      }
    });
  });

  group('popcount', () {
    test('empty input returns 0', () {
      expect(popcount(Uint8List(0)), 0);
    });

    test('[0xFF, 0x00] returns 8', () {
      expect(popcount(Uint8List.fromList([0xFF, 0x00])), 8);
    });

    test('[0x0F, 0xF0] returns 8', () {
      expect(popcount(Uint8List.fromList([0x0F, 0xF0])), 8);
    });

    test('[0xFF, 0xFF] returns 16', () {
      expect(popcount(Uint8List.fromList([0xFF, 0xFF])), 16);
    });

    test('512 bytes of 0x00 returns 0', () {
      expect(popcount(Uint8List(512)), 0);
    });

    test('512 bytes of 0xFF returns 4096', () {
      final full = Uint8List(512);
      for (var i = 0; i < 512; i++) {
        full[i] = 0xFF;
      }
      expect(popcount(full), 4096);
    });

    test('[0x01, 0x02, 0x04, 0x08] returns 4 (one bit per byte)', () {
      expect(popcount(Uint8List.fromList([0x01, 0x02, 0x04, 0x08])), 4);
    });
  });

  // computeRevealMask kernel correctness is exercised in
  // test/domain/revealed/reveal_calculator_test.dart and
  // test/domain/revealed/reveal_calculator_parent_boundary_test.dart
  // (Phase 09 plan 09-03). The Phase 03 `throws UnimplementedError`
  // placeholder test was retired when the body landed in 09-03.
}
