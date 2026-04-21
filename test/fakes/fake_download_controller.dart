// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/map/country_code.dart';

/// In-memory stand-in for the Plan 07-04 `PmtilesDownloadController`.
///
/// The real controller is a Riverpod `AsyncNotifier`-style class with a
/// rich surface (enqueue, pause, resume, cancel, delete) and drives the
/// Phase 07-05 UI. This fake exposes a narrow test-oriented API:
/// - [stateStream] — subscribe to [DownloadState] transitions
/// - [emitState] — drive the stream from the test body
/// - [queueCountry], [pause], [resume], [cancel] — record high-level
///   user actions via counters + observable lists
///
/// Widget tests use this fake to exercise every [DownloadState]
/// transition deterministically, without spinning up a MockHTTPServer.
class FakeDownloadController {
  FakeDownloadController({DownloadState initialState = const DownloadIdle()}) : _state = initialState;

  final StreamController<DownloadState> _stateCtrl = StreamController<DownloadState>.broadcast();
  DownloadState _state;

  /// Ordered list of alpha3s for every [queueCountry] call.
  final List<CountryCode> enqueueOrderObserved = <CountryCode>[];

  /// Number of [pause] calls.
  int pauseCalls = 0;

  /// Number of [resume] calls.
  int resumeCalls = 0;

  /// Number of [cancel] calls, per alpha3.
  final Map<CountryCode, int> cancelCallsByAlpha3 = <CountryCode, int>{};

  /// Current snapshot (updated by [emitState]). Read by the UI via
  /// [state] / subscribed via [stateStream].
  DownloadState get state => _state;

  /// Broadcast stream of [DownloadState] transitions. Emits every time
  /// [emitState] is called.
  Stream<DownloadState> get stateStream => _stateCtrl.stream;

  /// Pushes a new state onto [stateStream] and updates [state].
  void emitState(DownloadState next) {
    _state = next;
    _stateCtrl.add(next);
  }

  void queueCountry(CountryCode alpha3) {
    enqueueOrderObserved.add(alpha3);
  }

  void pause() {
    pauseCalls++;
  }

  void resume() {
    resumeCalls++;
  }

  void cancel(CountryCode alpha3) {
    cancelCallsByAlpha3.update(alpha3, (int n) => n + 1, ifAbsent: () => 1);
  }

  /// Closes the internal controller. Tests wiring this fake up in
  /// `setUp` should close it in `tearDown`.
  Future<void> close() async {
    await _stateCtrl.close();
  }
}
