// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style_store.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';

final Logger _log = Logger('application.controllers.mirk_style_session');

/// Coordinates in-session mirk-style swaps.
///
/// User flow (plan 09-07's burger-menu picker):
/// 1. User taps a style entry → handler calls
///    [select] with the active session id + the chosen style id.
/// 2. Controller persists `t_sessions.mirk_style_id = styleId` via
///    [`SessionStore.updateMirkStyle`].
/// 3. Controller invokes the injected `invalidateRenderer` callback so
///    Riverpod re-resolves [`activeMirkRendererProvider`] on the next
///    frame. The provider's resolution cascade (plan 09-05) reads the
///    session row's new `mirkStyleId` and instantiates the matching
///    renderer.
///
/// Defensive checks:
/// * Unknown `styleId` (no row in `t_mirk_styles`) →
///   [MirkStyleNotFoundException]. No write, no invalidate.
/// * Unknown `sessionId` → [NoActiveSessionException]. No write, no
///   invalidate.
/// * Same-style reselect (session already references [styleId]) → no-op
///   (no DB write, no invalidate, no log noise).
class MirkStyleSessionController {
  MirkStyleSessionController({
    required this.sessionStore,
    required this.styleStore,
    required this.invalidateRenderer,
  });

  final SessionStore sessionStore;
  final MirkStyleStore styleStore;

  /// Callback that invalidates [`activeMirkRendererProvider`] in the
  /// hosting Riverpod container. Injected so the controller stays a
  /// plain class (constructor DI per CLAUDE.md §Dependency Injection)
  /// and tests can substitute a counter without spinning up a
  /// `ProviderContainer`.
  final void Function() invalidateRenderer;

  /// Persists [styleId] as the new mirk style for [sessionId] and
  /// triggers a renderer swap.
  ///
  /// Idempotent on same-style reselect. Throws on missing session /
  /// missing style — never silent.
  Future<void> select({
    required SessionId sessionId,
    required MirkStyleId styleId,
  }) async {
    final style = await styleStore.findById(styleId);
    if (style == null) {
      throw MirkStyleNotFoundException(styleId: styleId);
    }

    final session = await sessionStore.findById(sessionId);
    if (session == null) {
      throw NoActiveSessionException(sessionId: sessionId);
    }

    if (session.mirkStyleId == styleId) {
      _log.fine('select(${styleId.value}) — same as current; no-op');
      return;
    }

    await sessionStore.updateMirkStyle(
      sessionId: sessionId,
      mirkStyleId: styleId,
    );
    invalidateRenderer();
  }
}

/// Thrown when [MirkStyleSessionController.select] is called with a
/// `styleId` that has no matching row in `t_mirk_styles`.
class MirkStyleNotFoundException implements Exception {
  const MirkStyleNotFoundException({required this.styleId});

  final MirkStyleId styleId;

  @override
  String toString() => 'MirkStyleNotFoundException(styleId=${styleId.value})';
}

/// Thrown when [MirkStyleSessionController.select] is called for a
/// session id with no matching row in `t_sessions`.
///
/// Distinct from `SessionNotFoundException` (which is a generic
/// store-level signal) because the controller only triggers it for the
/// specific case where the burger-menu picker fires for a session that
/// no longer exists (e.g. deleted from another route mid-flight).
class NoActiveSessionException implements Exception {
  const NoActiveSessionException({required this.sessionId});

  final SessionId sessionId;

  @override
  String toString() => 'NoActiveSessionException(sessionId=${sessionId.value})';
}
