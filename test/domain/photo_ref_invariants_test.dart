// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/marker_id.dart';
import 'package:mirkfall/domain/ids/photo_ref_id.dart';
import 'package:mirkfall/domain/photos/photo_ref.dart';
import 'package:test/test.dart';

void main() {
  PhotoRef buildPhotoRef({int widthPx = 800, int heightPx = 600, int fileSizeBytes = 102400, int createdAtOffsetMinutes = 120}) => PhotoRef(
    id: const PhotoRefId('pho_01HRPHOTOFIXTUREAAAAAAAAAAA'),
    markerId: const MarkerId('mkr_01HRMARKERFIXTUREAAAAAAAAAA'),
    relativeBasename: 'photo_01.jpg',
    widthPx: widthPx,
    heightPx: heightPx,
    fileSizeBytes: fileSizeBytes,
    createdAtUtc: DateTime.utc(2026, 4, 1, 8),
    createdAtOffsetMinutes: createdAtOffsetMinutes,
  );

  group('PhotoRef @Assert invariants', () {
    test('happy path constructs without throwing', () {
      final p = buildPhotoRef();
      expect(p.widthPx, 800);
      expect(p.heightPx, 600);
      expect(p.fileSizeBytes, 102400);
    });

    test('widthPx 0 throws AssertionError', () {
      expect(() => buildPhotoRef(widthPx: 0), throwsA(isA<AssertionError>()));
    });

    test('negative widthPx throws AssertionError', () {
      expect(() => buildPhotoRef(widthPx: -1), throwsA(isA<AssertionError>()));
    });

    test('heightPx 0 throws AssertionError', () {
      expect(() => buildPhotoRef(heightPx: 0), throwsA(isA<AssertionError>()));
    });

    test('negative heightPx throws AssertionError', () {
      expect(() => buildPhotoRef(heightPx: -1), throwsA(isA<AssertionError>()));
    });

    test('fileSizeBytes 0 throws AssertionError', () {
      expect(() => buildPhotoRef(fileSizeBytes: 0), throwsA(isA<AssertionError>()));
    });

    test('negative fileSizeBytes throws AssertionError', () {
      expect(() => buildPhotoRef(fileSizeBytes: -1), throwsA(isA<AssertionError>()));
    });

    test('createdAtOffsetMinutes below kMinUtcOffsetMinutes throws AssertionError', () {
      expect(() => buildPhotoRef(createdAtOffsetMinutes: kMinUtcOffsetMinutes - 1), throwsA(isA<AssertionError>()));
    });

    test('createdAtOffsetMinutes above kMaxUtcOffsetMinutes throws AssertionError', () {
      expect(() => buildPhotoRef(createdAtOffsetMinutes: kMaxUtcOffsetMinutes + 1), throwsA(isA<AssertionError>()));
    });
  });
}
