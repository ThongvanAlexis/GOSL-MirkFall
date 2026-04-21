// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';

/// In-memory [InstalledManifestRepository] double.
///
/// Seeds with [InstalledManifest.empty] unless a different initial state
/// is provided via [seedWith]. Every [write] updates the in-memory
/// snapshot atomically and emits on the [updates] broadcast stream —
/// matching the real `JsonFileInstalledManifestRepository` contract from
/// Plan 07-04.
///
/// Test helpers:
/// - [seedWith] replaces the cached state without emitting on [updates]
///   (matches the "load from disk at startup" read path).
/// - [writesObserved] counts every [write] call made so far.
/// - [simulateWriteFailure] when `true` causes the next [write] to throw
///   `Exception('simulated')`. The flag resets itself to `false` after
///   firing so tests can assert recovery paths without extra setup.
class FakeInstalledManifestRepository implements InstalledManifestRepository {
  FakeInstalledManifestRepository({InstalledManifest? initial}) : _state = initial ?? InstalledManifest.empty();

  InstalledManifest _state;
  final StreamController<InstalledManifest> _updatesCtrl = StreamController<InstalledManifest>.broadcast();

  int _writes = 0;
  bool simulateWriteFailure = false;

  /// Number of successful + failed [write] invocations since construction.
  int get writesObserved => _writes;

  /// Replace the cached manifest without emitting. Useful for the
  /// "load from disk at startup" read path.
  void seedWith(InstalledManifest initial) {
    _state = initial;
  }

  @override
  Future<InstalledManifest> read() async {
    // Return the state as-is; Freezed entities are already immutable, so
    // there is no need to deep-copy for test isolation.
    return _state;
  }

  @override
  Future<void> write(InstalledManifest manifest) async {
    _writes++;
    if (simulateWriteFailure) {
      simulateWriteFailure = false;
      throw Exception('simulated');
    }
    _state = manifest;
    _updatesCtrl.add(manifest);
  }

  @override
  Stream<InstalledManifest> get updates => _updatesCtrl.stream;

  /// Closes the internal controller. Tests that wire this fake up in
  /// `setUp` should close it in `tearDown` to avoid cross-test leakage.
  Future<void> close() async {
    await _updatesCtrl.close();
  }
}
