// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/gps/location_stream.dart';
import 'package:mirkfall/domain/ids/session_id.dart';

/// Reusable test double for [LocationStream].
///
/// Emits programmed [Fix] values via [emit] + [emitError]. Captures the
/// last arguments passed to [positions] so controller tests can assert
/// wiring. Signature tracks the Plan 05-02 upgrade: `sessionId` is now
/// [SessionId] (was `Object`) and a `sessionDisplayName` parameter was
/// added to feed the Android foreground-service notification title.
class FakeLocationStream implements LocationStream {
  final StreamController<Fix> _controller = StreamController<Fix>.broadcast();
  SessionId? _sessionId;
  int? _distanceFilter;
  String? _displayName;
  bool _disposed = false;
  Fix? _lastKnownFix;

  /// When non-null, [positions] throws this error synchronously before
  /// returning a stream. Lets controller tests exercise the
  /// "GpsError at start()" rollback path without wiring a real
  /// geolocator stack.
  Object? throwGpsOnPositions;

  @override
  Stream<Fix> positions({
    required SessionId sessionId,
    required int distanceFilterMeters,
    required String sessionDisplayName,
  }) {
    _sessionId = sessionId;
    _distanceFilter = distanceFilterMeters;
    _displayName = sessionDisplayName;
    final err = throwGpsOnPositions;
    if (err != null) throw err;
    return _controller.stream;
  }

  @override
  Fix? get lastKnownFix => _lastKnownFix;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }

  /// Injects a Fix into the stream. Downstream subscribers receive it
  /// synchronously on the next microtask. Also updates [lastKnownFix]
  /// so consumers (Phase 09 plan 09-06 `ActiveSessionController.start`
  /// fast path) read a coherent value.
  void emit(Fix fix) {
    _lastKnownFix = fix;
    _controller.add(fix);
  }

  /// Injects a stream error.
  void emitError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  /// Pre-seeds [lastKnownFix] without emitting on the stream — used by
  /// Plan 09-06 Task 4 to test the fast-path branch of
  /// `ActiveSessionController.start` (reveal seeded from a cached fix
  /// before any new emission lands).
  void setLastKnownFix(Fix? fix) => _lastKnownFix = fix;

  SessionId? get capturedSessionId => _sessionId;
  int? get capturedDistanceFilter => _distanceFilter;
  String? get capturedDisplayName => _displayName;
  bool get isDisposed => _disposed;
}
