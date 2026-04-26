// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/revealed_disc_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'discs_in_viewport_provider.g.dart';

final Logger _log = Logger('application.providers.discs_in_viewport');

/// Async provider returning the [RevealDisc]s of the currently active
/// session that intersect [viewport].
///
/// BUG-010 Option B (Commit 4) — replaces the consumer side of the
/// cell-bitmap pipeline. The renderers feed the returned list to
/// [RevealedSdfBuilder.buildFromDiscs] (continuous-geometry SDF) instead
/// of the per-tile bitmap rasterisation that fed [RevealedSdfBuilder.build].
///
/// Empty list returned when:
///   * No session is active (`Idle` / `Starting`).
///   * The active-session sealed-state matches no `Tracking` variant.
///
/// `keepAlive: false` mirrors the prior `visibleMirkTilesProvider` policy:
/// the result is only meaningful while the overlay is mounted; tearing
/// down the slot when the consumer goes away avoids stale state surviving
/// across screen pushes.
@riverpod
Future<List<RevealDisc>> discsInViewport(Ref ref, {required MirkViewportBbox viewport}) async {
  final sessionAsync = ref.watch(activeSessionControllerProvider);
  final sessionState = sessionAsync.value;
  // Source-of-truth for the active session id matches the legacy
  // `visibleMirkTilesProvider` — pattern-match over the sealed
  // `ActiveSessionState` and only proceed when `Tracking`.
  final SessionId? sessionId = switch (sessionState) {
    Tracking(:final sessionId) => sessionId,
    Idle() || Starting() || null => null,
  };
  if (sessionId == null) return const <RevealDisc>[];

  final store = await ref.watch(revealedDiscStoreProvider.future);
  final discs = await store.discsInBbox(sessionId: sessionId.value, bbox: viewport);
  _log.fine('discsInViewport: produced ${discs.length} discs (sessionId=${sessionId.value})');
  return discs;
}
