// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/revealed_tile.dart';
import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';

/// Reusable no-op [RevealedTileStore] for tests that exercise
/// `ActiveSessionController.start` without caring about the reveal
/// pipeline.
///
/// BUG-009 follow-up (2026-04-25) — `start()` now awaits
/// `revealedTileStoreProvider.future` so the family-scoped reveal
/// controller is hydrated before the first fix arrives. Tests that
/// previously got away with the default (real) `revealedTileStoreProvider`
/// hung on path_provider in the test environment; overriding the
/// provider with this helper keeps `start()` synchronous-fast.
class NoOpRevealedTileStore implements RevealedTileStore {
  const NoOpRevealedTileStore();

  @override
  Future<List<RevealedTile>> listBySession(SessionId sessionId) async => const <RevealedTile>[];

  @override
  Future<RevealedTile?> findByParent({required SessionId sessionId, required int parentX, required int parentY}) async => null;

  @override
  Future<void> mergeMask({required SessionId sessionId, required int parentX, required int parentY, required Uint8List mask}) async {}
}
