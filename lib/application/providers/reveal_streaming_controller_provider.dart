// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/application/controllers/reveal_streaming_controller.dart';
import 'package:mirkfall/application/providers/id_generator_provider.dart';
import 'package:mirkfall/application/providers/revealed_disc_store_provider.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reveal_streaming_controller_provider.g.dart';

/// Family-style provider that returns a [RevealStreamingController] for
/// the given [sessionId]. Returns `null` while the
/// [revealedDiscStoreProvider] async bootstrap (path_provider boot) is
/// still resolving.
///
/// **Wiring rationale (Phase 09 plan 09-06 + BUG-010 Option B Commit 4).**
/// The controller is the WRITE side of the reveal pipeline; on
/// BUG-010 Option B (Commit 4) it switched from
/// [`RevealedTileStore.mergeMask`] to [`RevealedDiscStore.addDisc`]. The
/// provider therefore depends on:
///   * [revealedDiscStoreProvider] for the disc-store seam.
///   * [idGeneratorProvider] for `rvd_<26-char-ULID>` id minting.
///
/// This provider does NOT `watch(activeSessionControllerProvider)` —
/// that would create a circular dependency, since `ActiveSessionController`
/// itself reads the reveal controller in its `_onFix` and `stop` paths.
/// Callers that want the "controller for the live session" pattern are
/// expected to resolve the active session id from
/// `ActiveSessionController.state` at the call site and pass it as the
/// family parameter.
///
/// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
/// turn flushes any still-buffered fixes — so provider disposal never
/// loses reveal data. Each (sessionId) family slot is independently
/// disposed when no longer watched.
///
/// NOT `keepAlive: true` — the controller's buffer is only meaningful
/// for the session it was constructed for. Carrying it across session
/// changes would risk flushing stale fixes to a freshly-restarted
/// session.
@riverpod
RevealStreamingController? revealStreamingController(Ref ref, SessionId sessionId) {
  // The store provider is async (path_provider boot). When the consumer
  // (ActiveSessionController.start) reaches this provider, the store
  // bootstrap is well past complete (the same start() awaited the
  // sessionStoreProvider future, which fans out from the same
  // appDatabaseProvider).
  final storeAsync = ref.watch(revealedDiscStoreProvider);
  final discStore = storeAsync.value;
  if (discStore == null) return null;
  final idGenerator = ref.watch(idGeneratorProvider);

  final controller = RevealStreamingController(sessionId: sessionId, discStore: discStore, idGenerator: idGenerator);
  ref.onDispose(() async {
    await controller.dispose();
  });
  return controller;
}
