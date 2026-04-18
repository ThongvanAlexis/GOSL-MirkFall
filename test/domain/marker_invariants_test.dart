// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/default_ids.dart';
import 'package:mirkfall/domain/ids/marker_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/markers/marker.dart';
import 'package:test/test.dart';

void main() {
  Marker buildMarker({String title = 'Café', double lat = 48.8566, double lon = 2.3522, int createdAtOffsetMinutes = 120}) => Marker(
    id: const MarkerId('mkr_01HRMARKERFIXTUREAAAAAAAAAA'),
    sessionId: const SessionId('sess_01HRSESSIONFIXTUREAAAAAAAA'),
    categoryId: kCategoryDefaultId,
    lat: lat,
    lon: lon,
    title: title,
    createdAtUtc: DateTime.utc(2026, 4, 1, 8),
    createdAtOffsetMinutes: createdAtOffsetMinutes,
  );

  group('Marker @Assert invariants', () {
    test('happy path constructs without throwing', () {
      final m = buildMarker();
      expect(m.lat, 48.8566);
      expect(m.lon, 2.3522);
      expect(m.title, 'Café');
    });

    test('empty title throws AssertionError', () {
      expect(() => buildMarker(title: ''), throwsA(isA<AssertionError>()));
    });

    test('whitespace-only title throws AssertionError', () {
      expect(() => buildMarker(title: '   '), throwsA(isA<AssertionError>()));
    });

    test('lat below -90 throws AssertionError', () {
      expect(() => buildMarker(lat: -90.1), throwsA(isA<AssertionError>()));
    });

    test('lat above +90 throws AssertionError', () {
      expect(() => buildMarker(lat: 90.1), throwsA(isA<AssertionError>()));
    });

    test('lon below -180 throws AssertionError', () {
      expect(() => buildMarker(lon: -180.1), throwsA(isA<AssertionError>()));
    });

    test('lon above +180 throws AssertionError', () {
      expect(() => buildMarker(lon: 180.1), throwsA(isA<AssertionError>()));
    });

    test('boundary lat/lon values construct successfully', () {
      expect(buildMarker(lat: -90.0, lon: -180.0).lat, -90.0);
      expect(buildMarker(lat: 90.0, lon: 180.0).lat, 90.0);
    });

    test('createdAtOffsetMinutes below kMinUtcOffsetMinutes throws AssertionError', () {
      expect(() => buildMarker(createdAtOffsetMinutes: kMinUtcOffsetMinutes - 1), throwsA(isA<AssertionError>()));
    });

    test('createdAtOffsetMinutes above kMaxUtcOffsetMinutes throws AssertionError', () {
      expect(() => buildMarker(createdAtOffsetMinutes: kMaxUtcOffsetMinutes + 1), throwsA(isA<AssertionError>()));
    });
  });
}
