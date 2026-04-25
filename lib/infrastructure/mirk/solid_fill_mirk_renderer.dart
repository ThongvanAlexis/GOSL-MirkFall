// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Color, Paint, PaintingStyle, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'tile_cell_iteration.dart';

/// Flat solid-color fog renderer — no noise, no animation.
///
/// MIRK-06 builtin variant. The minimalist proof-of-seam: if Atmospheric
/// works and Solid works, the renderer factory + `MirkPaintContext`
/// + tile-cell-iteration helpers are wired correctly. Static output makes
/// regression diffs trivial — any byte change between two frames
/// indicates a bug.
///
/// Configuration ([SolidConfig]):
/// * `colorArgb` — packed ARGB for the fog colour (default `0xFF1A1A1A`).
/// * `baselineAlpha` — additional alpha multiplier `[0, 1]` applied on
///   top of the colour's own alpha byte. Final alpha = `(colorArgb_A
///   * baselineAlpha) / 255`.
class SolidFillMirkRenderer implements MirkRenderer {
  /// Constructs a renderer using [config] for colour + alpha.
  SolidFillMirkRenderer(this.config);

  /// Fog colour + baseline alpha.
  final SolidConfig config;

  late final Paint _paint = Paint()
    ..color = _computeColor(config)
    ..style = PaintingStyle.fill;

  bool _disposed = false;

  /// Computes the final fog colour: extracts RGB from `config.colorArgb`
  /// and combines `colorArgb`'s alpha byte with `config.baselineAlpha`.
  static Color _computeColor(SolidConfig config) {
    final argb = config.colorArgb;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final aFromArgb = (argb >> 24) & 0xFF;
    final finalAlpha = (aFromArgb * config.baselineAlpha)
        .clamp(0.0, 255.0)
        .round();
    return Color.fromARGB(finalAlpha, r, g, b);
  }

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (_disposed) return;
    if (context.visibleTiles.isEmpty) return;
    for (final tile in context.visibleTiles) {
      final path = buildUnrevealedCellsPath(
        tile: tile,
        viewport: context.viewportBbox,
        canvasSize: size,
      );
      // Skip drawing entirely when the path is empty (every cell of the
      // tile was already revealed — nothing to fog).
      if (path.getBounds().isEmpty) continue;
      canvas.drawPath(path, _paint);
    }
  }

  @override
  void update(Duration elapsed) {
    // Solid is time-invariant — no internal state advances.
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
