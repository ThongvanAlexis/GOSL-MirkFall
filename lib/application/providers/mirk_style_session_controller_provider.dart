// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/application/controllers/mirk_style_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/mirk_style_store_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mirk_style_session_controller_provider.g.dart';

/// Production [MirkStyleSessionController] — wires the controller with
/// [`sessionStoreProvider`], [`mirkStyleStoreProvider`], and an
/// `invalidateRenderer` callback that invalidates
/// [`activeMirkRendererProvider`] on style change.
///
/// Returned as `Future<MirkStyleSessionController>` because both store
/// providers are async (path_provider boot). Plan 09-07's burger-menu
/// picker awaits the future once and caches the controller for the
/// session's lifetime.
///
/// `keepAlive: true` — the controller has no long-lived state of its
/// own (it reads stores per-call) and re-creating it on widget-tree
/// changes would not save anything. Mirrors the rest of the
/// store-wrapping providers in the Phase 03/05 graph.
@Riverpod(keepAlive: true)
Future<MirkStyleSessionController> mirkStyleSessionController(Ref ref) async {
  final sessionStore = await ref.watch(sessionStoreProvider.future);
  final styleStore = await ref.watch(mirkStyleStoreProvider.future);
  return MirkStyleSessionController(
    sessionStore: sessionStore,
    styleStore: styleStore,
    invalidateRenderer: () => ref.invalidate(activeMirkRendererProvider),
  );
}
