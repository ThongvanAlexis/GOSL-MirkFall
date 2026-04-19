// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/gps/gps_errors.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/infrastructure/gps/geolocator_location_stream.dart';

/// Covers GPS-02 infrastructure — `Position` to domain [Fix] translation
/// plus accuracy filter, stationary dedup, and error-translation rules.
///
/// Uses the `positionStreamFactory` seam: every test passes a
/// [`StreamController`]-backed factory so the pipeline runs end-to-end
/// without touching `Geolocator.getPositionStream` (static method, not
/// mockable). Same DI pattern as Phase 03 stores.
void main() {
  late _FakeIdGenerator idGenerator;
  late StreamController<geo.Position> positionController;
  late GeolocatorLocationStream stream;
  final SessionId sessionId = SessionId('sess_${'A' * 26}');

  setUp(() {
    idGenerator = _FakeIdGenerator();
    positionController = StreamController<geo.Position>();
    stream = GeolocatorLocationStream(idGenerator: idGenerator, positionStreamFactory: (_) => positionController.stream);
  });

  tearDown(() async {
    if (!positionController.isClosed) {
      await positionController.close();
    }
    await stream.dispose();
  });

  test('emits a Fix for an accepted Position (accuracy under threshold)', () async {
    final fixes = <Fix>[];
    final sub = stream.positions(sessionId: sessionId, distanceFilterMeters: 5, sessionDisplayName: 'Test').listen(fixes.add);

    positionController.add(_position(latitude: 48.8566, longitude: 2.3522, accuracyMeters: 8.0));
    await Future<void>.delayed(Duration.zero);

    expect(fixes, hasLength(1));
    expect(fixes.first.latitude, 48.8566);
    expect(fixes.first.longitude, 2.3522);
    expect(fixes.first.accuracyMeters, 8.0);
    expect(fixes.first.sessionId, sessionId);
    expect(fixes.first.id.value, startsWith(FixId.prefix));

    await sub.cancel();
  });

  test('rejects a Position with accuracy above kMaxAcceptableAccuracyMeters (50 m)', () async {
    final fixes = <Fix>[];
    final sub = stream.positions(sessionId: sessionId, distanceFilterMeters: 5, sessionDisplayName: 'Test').listen(fixes.add);

    // 55 m accuracy — above the 50 m cap, must be silently dropped.
    positionController.add(_position(latitude: 48.8566, longitude: 2.3522, accuracyMeters: 55.0));
    await Future<void>.delayed(Duration.zero);

    expect(fixes, isEmpty);

    await sub.cancel();
  });

  test('deduplicates stationary fixes within 1 m AND 10 s of the last accepted fix', () async {
    final fixes = <Fix>[];
    final sub = stream.positions(sessionId: sessionId, distanceFilterMeters: 5, sessionDisplayName: 'Test').listen(fixes.add);

    positionController.add(_position(latitude: 48.8566, longitude: 2.3522, accuracyMeters: 5.0));
    await Future<void>.delayed(Duration.zero);

    // ~0.1 m shift — Geolocator.distanceBetween will return well below 1 m.
    // Within 10 s of the first emission, so dedup must drop it.
    positionController.add(_position(latitude: 48.85660001, longitude: 2.35220001, accuracyMeters: 5.0));
    await Future<void>.delayed(Duration.zero);

    expect(fixes, hasLength(1), reason: 'Second near-identical fix should be deduplicated');

    await sub.cancel();
  });

  test('emits a subsequent Fix once the user has actually moved (>1 m)', () async {
    final fixes = <Fix>[];
    final sub = stream.positions(sessionId: sessionId, distanceFilterMeters: 5, sessionDisplayName: 'Test').listen(fixes.add);

    positionController.add(_position(latitude: 48.8566, longitude: 2.3522, accuracyMeters: 5.0));
    await Future<void>.delayed(Duration.zero);

    // ~11 m north — well above 1 m threshold.
    positionController.add(_position(latitude: 48.85670, longitude: 2.3522, accuracyMeters: 5.0));
    await Future<void>.delayed(Duration.zero);

    expect(fixes, hasLength(2));
    expect(fixes[1].latitude, 48.85670);

    await sub.cancel();
  });

  test('translates geolocator PermissionDeniedException to domain LocationPermissionDeniedException', () async {
    final errors = <Object>[];
    final sub = stream.positions(sessionId: sessionId, distanceFilterMeters: 5, sessionDisplayName: 'Test').listen((_) {}, onError: errors.add);

    positionController.addError(const geo.PermissionDeniedException('denied'));
    await Future<void>.delayed(Duration.zero);

    expect(errors, hasLength(1));
    expect(errors.first, isA<LocationPermissionDeniedException>());

    await sub.cancel();
  });

  test('translates geolocator LocationServiceDisabledException to domain LocationServiceDisabledException', () async {
    final errors = <Object>[];
    final sub = stream.positions(sessionId: sessionId, distanceFilterMeters: 5, sessionDisplayName: 'Test').listen((_) {}, onError: errors.add);

    positionController.addError(const geo.LocationServiceDisabledException());
    await Future<void>.delayed(Duration.zero);

    expect(errors, hasLength(1));
    expect(errors.first, isA<LocationServiceDisabledException>());

    await sub.cancel();
  });
}

/// Deterministic [IdGenerator] — returns sequentially-numbered IDs with the
/// caller-supplied prefix so tests assert ordering without a real ULID.
class _FakeIdGenerator implements IdGenerator {
  int _counter = 0;

  @override
  String newId(String prefix) {
    _counter += 1;
    // Pad to 26 chars to satisfy FixId.isValid expectations (prefix + 26-body).
    final String body = _counter.toString().padLeft(26, '0');
    return '$prefix$body';
  }
}

/// Builds a [`geo.Position`] fixture with sensible defaults for the fields
/// this suite doesn't exercise (altitude, speed, heading).
geo.Position _position({required double latitude, required double longitude, required double accuracyMeters}) => geo.Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.utc(2026, 4, 19, 10),
  accuracy: accuracyMeters,
  altitude: 0.0,
  altitudeAccuracy: 0.0,
  heading: 0.0,
  headingAccuracy: 0.0,
  speed: 0.0,
  speedAccuracy: 0.0,
);
