// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Coordinates in-session mirk-style swaps: persists the user's choice,
/// disposes the outgoing renderer, instantiates the incoming one.
///
/// Phase 09 Wave 0 scaffold. Wave 5 (plan 09-06) supplies the body. See
/// 09-RESEARCH §In-Session Style Swap Lifecycle for the full state diagram.
class MirkStyleSessionController {
  // TODO(09-06): constructor accepts MirkStyleStore + MirkRendererFactory
  // + currently-active renderer reference.
  MirkStyleSessionController();

  /// Switches the active mirk style by id.
  ///
  /// Disposes the outgoing renderer, persists the choice, instantiates
  /// the new renderer via `MirkRendererFactory`.
  Future<void> select(/* MirkStyleId styleId */) async => throw UnimplementedError('Wave 5 — plan 09-06');

  /// Releases the currently active renderer. Idempotent.
  Future<void> dispose() async => throw UnimplementedError('Wave 5 — plan 09-06');
}
