// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:freezed_annotation/freezed_annotation.dart';

part 'mirk_paint_context.freezed.dart';

/// Inputs passed to [MirkRenderer.paint] on every frame.
///
/// Kept deliberately narrow in Phase 07 — the renderer impl is a no-op
/// stub. Phase 09 expands this context (viewport bounds, current fix,
/// revealed-tile bitmap, session distance, …) as the real renderer
/// materialises. Sealing the field list in Freezed means adding a new
/// one is a compile-time friction point that forces call-site review —
/// exactly what we want for a rendering contract.
@freezed
abstract class MirkPaintContext with _$MirkPaintContext {
  @Assert('zoomLevel >= 0.0', 'MirkPaintContext.zoomLevel must be >= 0')
  @Assert('pixelRatio > 0.0', 'MirkPaintContext.pixelRatio must be > 0')
  factory MirkPaintContext({required double zoomLevel, required double pixelRatio, required Duration sessionElapsed}) = _MirkPaintContext;
}
