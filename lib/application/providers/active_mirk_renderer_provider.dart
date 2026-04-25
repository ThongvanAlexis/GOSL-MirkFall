// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/noop_mirk_renderer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'mirk_renderer_factory_provider.dart';
import 'mirk_style_store_provider.dart';
import 'session_store_provider.dart';

part 'active_mirk_renderer_provider.g.dart';

final Logger _log = Logger('application.mirk.active_renderer');

/// Resolves the currently-active [MirkRenderer] for the active session.
///
/// Resolution cascade (top to bottom — each step short-circuits on
/// match):
/// 1. `ActiveSessionState` is `Idle` / `Starting` / loading / error
///    → return [NoopMirkRenderer] (no session, no fog).
/// 2. State is `Tracking(sessionId)` and the session row's
///    [Session.mirkStyleId] is non-null AND points to an existing
///    [MirkStyle] → return `factory.create(style.config)`.
/// 3. State is `Tracking` and `mirkStyleId` is null OR the referenced
///    style is missing → return `factory.create(AtmosphericConfig())`
///    (renderer-level default, atmospheric).
///
/// `UnknownConfig` payloads are handled inside the factory itself
/// (forward-compat fallback from plan 09-05 Task 1) — they never reach
/// this provider as a special case.
///
/// Lifecycle:
/// * `ref.onDispose` calls `renderer.dispose()` when the provider is
///   torn down (session change, style swap, app exit). This ensures GPU
///   resources, tickers, and noise generators are released exactly once
///   per renderer instance.
/// * NOT `keepAlive: true` — the renderer is session-scoped and should
///   be garbage-collected when the session ends or the style changes.
///   Plan 09-06's `MirkStyleSessionController.select()` calls
///   `ref.invalidate(activeMirkRendererProvider)` to force a swap when
///   the user picks a new style mid-session.
@riverpod
Future<MirkRenderer> activeMirkRenderer(Ref ref) async {
  final sessionAsync = ref.watch(activeSessionControllerProvider);
  final factory = ref.watch(mirkRendererFactoryProvider);

  // 1. No session → Noop. Loading / error AsyncValue states also
  //    surface as Noop — the UI's `MirkOverlay` (plan 09-07) is
  //    expected to be silent on a not-yet-loaded session.
  final sessionState = sessionAsync.value;
  final activeSessionId = switch (sessionState) {
    Tracking(:final sessionId) => sessionId,
    Idle() || Starting() || null => null,
  };

  if (activeSessionId == null) {
    final noop = const NoopMirkRenderer();
    ref.onDispose(noop.dispose);
    return noop;
  }

  // 2. Tracking — resolve the session row to read its mirkStyleId.
  //    Then resolve the style row to read its config. Either lookup
  //    can return null; both fall back to atmospheric.
  final sessionStore = await ref.watch(sessionStoreProvider.future);
  final session = await sessionStore.findById(activeSessionId);

  MirkStyleConfig config = const AtmosphericConfig();
  if (session?.mirkStyleId case final styleId?) {
    final styleStore = await ref.watch(mirkStyleStoreProvider.future);
    final style = await styleStore.findById(styleId);
    if (style != null) {
      // UnknownConfig still goes to the factory — the factory's
      // sealed-switch fallback (plan 09-05 Task 1) emits a default
      // AtmosphericMirkRenderer with a logged warning. We don't need
      // a second-layer null check here.
      config = style.config;
    } else {
      _log.warning(
        'session ${activeSessionId.value} references missing mirk style '
        '${styleId.value} — degrading to default atmospheric',
      );
    }
  }

  final renderer = factory.create(config);
  ref.onDispose(renderer.dispose);
  return renderer;
}
