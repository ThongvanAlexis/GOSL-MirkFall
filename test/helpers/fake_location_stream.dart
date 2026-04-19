// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/gps/location_stream.dart';

/// Reusable test double for [LocationStream].
///
/// Emits programmed [Fix] values via [emit] + [emitError]. Captures the
/// last `sessionId` and `distanceFilterMeters` passed to [positions] so
/// controller tests can assert wiring.
class FakeLocationStream implements LocationStream {
  final StreamController<Fix> _controller = StreamController<Fix>.broadcast();
  Object? _sessionId;
  int? _distanceFilter;
  bool _disposed = false;

  @override
  Stream<Fix> positions({required Object sessionId, required int distanceFilterMeters}) {
    _sessionId = sessionId;
    _distanceFilter = distanceFilterMeters;
    return _controller.stream;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }

  /// Injects a Fix into the stream. Downstream subscribers receive it
  /// synchronously on the next microtask.
  void emit(Fix fix) => _controller.add(fix);

  /// Injects a stream error.
  void emitError(Object error, [StackTrace? stackTrace]) => _controller.addError(error, stackTrace);

  Object? get capturedSessionId => _sessionId;
  int? get capturedDistanceFilter => _distanceFilter;
  bool get isDisposed => _disposed;
}
