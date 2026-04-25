// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

/// Default atmospheric fog — dark noise-modulated overlay.
///
/// Phase 09 Wave 0 scaffold. Wave 3 (plan 09-04) supplies the body:
/// simplex-noise modulated [config.baseColorArgb] alpha, sampled over the
/// viewport with [config.noiseScale] frequency.
class AtmosphericMirkRenderer implements MirkRenderer {
  AtmosphericMirkRenderer(this.config);
  final AtmosphericConfig config;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) => throw UnimplementedError('Wave 3 — plan 09-04');

  @override
  void update(Duration elapsed) => throw UnimplementedError('Wave 3 — plan 09-04');

  @override
  Future<void> dispose() async => throw UnimplementedError('Wave 3 — plan 09-04');
}
