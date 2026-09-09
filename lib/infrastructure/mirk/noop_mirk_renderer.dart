// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';

/// Phase 07 stub implementation of [MirkRenderer] — paints nothing,
/// updates nothing, disposes immediately.
///
/// Purpose: the MapView infrastructure (Plan 07-03) and the Phase 07-06
/// screens need a concrete [MirkRenderer] instance wired into the Riverpod
/// graph so the full wire-up compiles end-to-end. A real renderer lands
/// in Phase 09 (fog rendering); until then this class keeps the seam
/// alive without rendering any fog — the Phase 07 style.json already
/// ships `mirk_fog` as a transparent `background` layer, so a no-op
/// Dart-level renderer simply mirrors the map-side no-op.
final class NoopMirkRenderer implements MirkRenderer {
  const NoopMirkRenderer();

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    // Intentional no-op. Phase 09 supplies the real paint logic.
    return;
  }

  @override
  void update(Duration elapsed) {
    // Intentional no-op. No internal state to advance.
    return;
  }

  @override
  Future<void> dispose() async {
    // No resources held; complete immediately.
    return;
  }
}
