// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/controllers/reveal_streaming_controller.dart';
import 'package:mirkfall/application/providers/revealed_tile_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reveal_streaming_controller_provider.g.dart';

/// Resolves a [RevealStreamingController] bound to the current
/// `Tracking` session, or `null` when no session is active.
///
/// The controller is session-scoped — its `sessionId` field is the
/// active `Tracking.sessionId`, so a session change MUST invalidate
/// this provider so the next read produces a fresh controller for the
/// new session id. Riverpod's data dependency on
/// [activeSessionControllerProvider] handles that automatically: any
/// transition through `Idle` / `Starting` re-runs the build body and
/// returns `null`, then re-runs again when the next `Tracking` lands.
///
/// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
/// turn flushes any still-buffered fixes — so provider disposal never
/// loses reveal data.
///
/// NOT `keepAlive: true` — the controller's buffer is only meaningful
/// for the live `Tracking` session it was constructed for; carrying it
/// across `Idle` would risk flushing stale fixes to a freshly-restarted
/// session.
@riverpod
RevealStreamingController? revealStreamingController(Ref ref) {
  final sessionAsync = ref.watch(activeSessionControllerProvider);
  final sessionState = sessionAsync.value;
  final activeSessionId = switch (sessionState) {
    Tracking(:final sessionId) => sessionId,
    Idle() || Starting() || null => null,
  };
  if (activeSessionId == null) return null;

  // The store provider is async (path_provider boot). The controller is
  // sync — but we only build it once `Tracking` has materialised, by
  // which time the store's bootstrap is well past complete (the same
  // session controller had to await it during start()). Reading the
  // resolved value via `.value` here is safe — Riverpod 3.x exposes
  // `AsyncValue.value` as a nullable getter (returns null on
  // loading/error).
  final storeAsync = ref.watch(revealedTileStoreProvider);
  final store = storeAsync.value;
  if (store == null) return null;

  final controller = RevealStreamingController(
    sessionId: activeSessionId,
    store: store,
  );
  ref.onDispose(() async {
    await controller.dispose();
  });
  return controller;
}
