// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Size;

import 'mirk_paint_context.dart';

/// Abstract port over the fog-of-war (mirk) rendering surface.
///
/// 3 methods, frozen in Phase 07 — see CONTEXT.md §MirkRenderer seam
/// (decision D6). Phase 09 supplied the first non-stub implementation
/// without expanding the surface: any new feature needs a new argument
/// on an existing method (plumbed through [MirkPaintContext]) or lives
/// outside the rendering hot path (settings, state, etc.).
///
/// BUG-014 iteration 6 temporarily added a 4th member (a getter exposing
/// the viewport the current SDF was built for) so the overlay could
/// compensate camera movement with an a-posteriori Canvas transform.
/// Phase 09.1 removed it: the same-canvas `FogLayer` compensates the
/// camera by construction (one `MapCamera` snapshot per paint, FOG-07),
/// so the port is back to its 3-member shape.
///
/// The `mirk_renderer_contract_test` asserts that these 3 members are
/// the *only* public surface, guarding against accidental growth.
///
/// ## Import rationale
///
/// This file imports `dart:ui` (`Canvas`, `Size`). `dart:ui` is part of
/// the Dart SDK — NOT Flutter widgets — and is therefore allowed in
/// domain per `tool/check_domain_purity.dart`'s import rules (the gate
/// forbids `package:flutter/*` and `package:drift/*`, not `dart:ui`).
/// Precedent: `lib/domain/mirk/mirk_style_config.dart` has lived in
/// domain since Phase 03.
///
/// `Canvas` + `Size` carry zero map-engine coupling — they are the Flutter
/// painting primitives that every renderer (same-canvas layer, custom, or
/// offscreen test harness) needs to interoperate with.
abstract class MirkRenderer {
  /// Draws the mirk for the current frame. Called inside a Flutter
  /// painting pass, in the identity frame the `FogLayer` already clipped
  /// and translated. Must NOT retain [canvas] past the call — the
  /// underlying picture recorder is short-lived.
  void paint(Canvas canvas, Size size, MirkPaintContext context);

  /// Advances internal animation state by [elapsed] (single frame
  /// delta). Called once per frame BEFORE [paint]; implementations that
  /// produce time-invariant output may leave this a no-op.
  void update(Duration elapsed);

  /// Releases any GPU / native resources (shader programs, cached
  /// bitmaps, ticker subscriptions). Idempotent — safe to call
  /// repeatedly.
  Future<void> dispose();
}
