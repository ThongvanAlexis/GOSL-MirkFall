// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_session_id_provider.g.dart';

/// Id of the session currently being tracked, or `null` while Idle / Starting / loading / error.
///
/// Narrow projection of `activeSessionControllerProvider`: the controller re-emits a NEW
/// `Tracking` on every accepted fix (`copyWith(fixCount:, lastFix:)`), so anything that must
/// live for the whole session — the mirk renderer above all — watches this provider instead of
/// the controller. A functional provider notifies its dependents only when `previous != next`
/// (riverpod `Provider.updateShouldNotify`) and `SessionId` compares by value, so a fix on the
/// same session never propagates. A provider rather than `.select(...)`: `riverpod_annotation`
/// does not re-export the `select` modifier and the application layer stays free of
/// `flutter_riverpod`.
@riverpod
SessionId? activeSessionId(Ref ref) {
  final AsyncValue<ActiveSessionState> sessionAsync = ref.watch(activeSessionControllerProvider);
  return switch (sessionAsync.value) {
    Tracking(:final SessionId sessionId) => sessionId,
    Idle() || Starting() || null => null,
  };
}
