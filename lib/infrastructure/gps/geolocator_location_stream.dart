// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/gps/gps_errors.dart';
import 'package:mirkfall/domain/gps/location_stream.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/domain/ids/session_id.dart';

import 'location_settings_factory.dart';

final Logger _log = Logger('gps.stream');

/// Factory shape that produces the underlying `Stream<Position>` from a
/// built [geo.LocationSettings]. Default hits `Geolocator.getPositionStream`;
/// tests inject a fake so the seam avoids mocking the static method.
typedef PositionStreamFactory = Stream<geo.Position> Function(geo.LocationSettings settings);

/// Production [LocationStream] — wraps `geolocator`'s `getPositionStream` and
/// translates `Position` into a domain [Fix].
///
/// Seam design: the constructor takes a [PositionStreamFactory] so tests can
/// drive the pipeline with a `StreamController` without touching
/// `Geolocator.getPositionStream` (static method, not trivially mockable).
/// Same seam pattern as Phase 03's [IdGenerator] injection.
///
/// Filtering rules applied inside [positions]:
/// - **Accuracy reject:** drop any fix where `accuracy > kMaxAcceptableAccuracyMeters`
///   (50 m — signal/noise frontier between urban-canyon and indoor GPS).
/// - **Stationary dedup:** skip a fix if < 1 m from the last emitted fix AND
///   < 10 s since the last emitted fix (CONTEXT.md leaves exact values to
///   Claude's discretion; these are the Plan 05-02 choices).
/// - **Error translation:** `PermissionDeniedException` from geolocator →
///   domain [LocationPermissionDeniedException]; `LocationServiceDisabledException`
///   from geolocator → domain [LocationServiceDisabledException]. Every other
///   platform error propagates verbatim (callers can still pattern-match on
///   [GpsError]; anything else is an infrastructure bug per CLAUDE.md's
///   error-handling tiers).
class GeolocatorLocationStream implements LocationStream {
  GeolocatorLocationStream({required IdGenerator idGenerator, PositionStreamFactory? positionStreamFactory})
    : _idGenerator = idGenerator,
      _positionStreamFactory = positionStreamFactory ?? _defaultFactory;

  final IdGenerator _idGenerator;
  final PositionStreamFactory _positionStreamFactory;
  StreamSubscription<geo.Position>? _subscription;
  bool _disposed = false;

  static Stream<geo.Position> _defaultFactory(geo.LocationSettings settings) => geo.Geolocator.getPositionStream(locationSettings: settings);

  /// Minimum distance (meters) below which a new fix is treated as the same
  /// spot as the last emitted one and filtered out if also within
  /// [_stationaryDedupWindow]. Named to avoid a magic literal per CLAUDE.md
  /// §Magic numbers.
  static const double _stationaryDedupMinDistanceMeters = 1.0;

  /// Time window (seconds) paired with [_stationaryDedupMinDistanceMeters]
  /// to form the stationary-dedup rule.
  static const int _stationaryDedupWindowSeconds = 10;

  @override
  Stream<Fix> positions({required SessionId sessionId, required int distanceFilterMeters, required String sessionDisplayName}) {
    final settings = buildLocationSettings(distanceFilterMeters: distanceFilterMeters, sessionDisplayName: sessionDisplayName);

    final controller = StreamController<Fix>();
    double? lastLatitude;
    double? lastLongitude;
    DateTime? lastEmittedAt;
    int positionsReceived = 0;
    int fixesEmitted = 0;
    int droppedAccuracy = 0;
    int droppedStationary = 0;

    controller.onListen = () {
      _log.fine('stream start · session=${sessionId.value} distanceFilter=${distanceFilterMeters}m accuracyCeiling=${kMaxAcceptableAccuracyMeters}m');
      _subscription = _positionStreamFactory(settings).listen(
        (geo.Position position) {
          positionsReceived++;
          if (position.accuracy > kMaxAcceptableAccuracyMeters) {
            droppedAccuracy++;
            _log.fine(
              'position rejected (accuracy ${position.accuracy.toStringAsFixed(1)}m > ${kMaxAcceptableAccuracyMeters}m) · '
              'lat=${position.latitude.toStringAsFixed(5)} lng=${position.longitude.toStringAsFixed(5)} '
              '· counters received=$positionsReceived emitted=$fixesEmitted droppedAcc=$droppedAccuracy droppedStat=$droppedStationary',
            );
            return;
          }

          final now = DateTime.now().toUtc();
          if (lastLatitude != null && lastLongitude != null && lastEmittedAt != null) {
            final double distanceMeters = geo.Geolocator.distanceBetween(lastLatitude!, lastLongitude!, position.latitude, position.longitude);
            final Duration sinceLast = now.difference(lastEmittedAt!);
            if (distanceMeters < _stationaryDedupMinDistanceMeters && sinceLast.inSeconds < _stationaryDedupWindowSeconds) {
              droppedStationary++;
              _log.fine(
                'position rejected (stationary ${distanceMeters.toStringAsFixed(2)}m < '
                '${_stationaryDedupMinDistanceMeters}m within ${sinceLast.inSeconds}s < ${_stationaryDedupWindowSeconds}s)',
              );
              return;
            }
          }

          final fix = Fix(
            id: FixId(_idGenerator.newId(FixId.prefix)),
            sessionId: sessionId,
            recordedAtUtc: position.timestamp.toUtc(),
            recordedAtOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            altitudeMeters: position.altitude.isFinite ? position.altitude : null,
            speedMps: position.speed.isFinite ? position.speed : null,
            headingDegrees: position.heading.isFinite ? position.heading : null,
          );
          lastLatitude = position.latitude;
          lastLongitude = position.longitude;
          lastEmittedAt = now;
          fixesEmitted++;
          _log.fine(
            'fix emitted #$fixesEmitted · lat=${fix.latitude.toStringAsFixed(5)} lng=${fix.longitude.toStringAsFixed(5)} '
            '± ${fix.accuracyMeters.toStringAsFixed(1)}m speed=${fix.speedMps?.toStringAsFixed(1) ?? "-"}m/s',
          );
          controller.add(fix);
        },
        onError: (Object error, StackTrace stackTrace) {
          final translated = _translate(error);
          _log.warning('stream error (translated=${translated.runtimeType})', error, stackTrace);
          controller.addError(translated, stackTrace);
        },
        cancelOnError: false,
      );
    };

    controller.onCancel = () async {
      _log.fine(
        'stream cancel · session=${sessionId.value} summary: received=$positionsReceived emitted=$fixesEmitted '
        'droppedAccuracy=$droppedAccuracy droppedStationary=$droppedStationary',
      );
      await _subscription?.cancel();
      _subscription = null;
    };

    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Translates a platform-layer geolocator error into the domain's sealed
  /// [GpsError] hierarchy. Unknown errors pass through unchanged so
  /// infrastructure bugs surface as-is (CLAUDE.md §Error handling: bugs
  /// propagate to the top-level handler).
  static Object _translate(Object error) {
    if (error is geo.LocationServiceDisabledException) {
      return const LocationServiceDisabledException();
    }
    if (error is geo.PermissionDeniedException) {
      return const LocationPermissionDeniedException();
    }
    return error;
  }
}
