// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/revealed_tile_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/revealed_tile.dart';
import 'package:test/test.dart';

void main() {
  RevealedTile buildRevealedTile({int parentX = 8299, int parentY = 5635, int parentZoom = kRevealedTileParentZoom, Uint8List? bitmap, int setBitCount = 0}) =>
      RevealedTile(
        id: const RevealedTileId('rvt_01HRTILEFIXTUREAAAAAAAAAAAA'),
        sessionId: const SessionId('sess_01HRSESSIONFIXTUREAAAAAAAA'),
        parentX: parentX,
        parentY: parentY,
        parentZoom: parentZoom,
        bitmap: bitmap ?? Uint8List(kRevealedTileBitmapBytes),
        setBitCount: setBitCount,
        updatedAtUtc: DateTime.utc(2026, 4, 1, 8),
      );

  group('RevealedTile @Assert invariants', () {
    test('happy path constructs without throwing', () {
      final t = buildRevealedTile();
      expect(t.parentX, 8299);
      expect(t.parentZoom, kRevealedTileParentZoom);
      expect(t.bitmap.length, kRevealedTileBitmapBytes);
    });

    test('negative parentX throws AssertionError', () {
      expect(() => buildRevealedTile(parentX: -1), throwsA(isA<AssertionError>()));
    });

    test('negative parentY throws AssertionError', () {
      expect(() => buildRevealedTile(parentY: -1), throwsA(isA<AssertionError>()));
    });

    test('parentZoom != 14 throws AssertionError', () {
      expect(() => buildRevealedTile(parentZoom: 13), throwsA(isA<AssertionError>()));
      expect(() => buildRevealedTile(parentZoom: 15), throwsA(isA<AssertionError>()));
    });

    test('bitmap shorter than 512 bytes throws AssertionError', () {
      expect(() => buildRevealedTile(bitmap: Uint8List(256)), throwsA(isA<AssertionError>()));
    });

    test('bitmap longer than 512 bytes throws AssertionError', () {
      expect(() => buildRevealedTile(bitmap: Uint8List(1024)), throwsA(isA<AssertionError>()));
    });

    test('setBitCount < 0 throws AssertionError', () {
      expect(() => buildRevealedTile(setBitCount: -1), throwsA(isA<AssertionError>()));
    });

    test('setBitCount > 4096 throws AssertionError', () {
      expect(() => buildRevealedTile(setBitCount: 4097), throwsA(isA<AssertionError>()));
    });

    test('boundary setBitCount values (0 and 4096) construct successfully', () {
      // ignore: avoid_redundant_argument_values — explicit boundary assertion
      expect(buildRevealedTile(setBitCount: 0).setBitCount, 0);
      expect(buildRevealedTile(setBitCount: 4096).setBitCount, 4096);
    });
  });
}
