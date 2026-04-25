// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';

/// Flat solid-color fog — no noise, no animation.
///
/// Phase 09 Wave 0 scaffold. Wave 3 (plan 09-04) supplies the body once
/// Wave 2 plan 09-02 adds `SolidConfig` to the `MirkStyleConfig` sealed
/// union. Until then, this renderer takes no constructor parameter.
///
// TODO(09-04): accept `SolidConfig config` once plan 09-02 adds the
// sealed variant. For Wave 0, no config parameter.
class SolidFillMirkRenderer implements MirkRenderer {
  SolidFillMirkRenderer();

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) => throw UnimplementedError('Wave 3 — plan 09-04');

  @override
  void update(Duration elapsed) => throw UnimplementedError('Wave 3 — plan 09-04');

  @override
  Future<void> dispose() async => throw UnimplementedError('Wave 3 — plan 09-04');
}
