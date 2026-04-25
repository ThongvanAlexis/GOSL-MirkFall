// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show BlurStyle, Canvas, Color, MaskFilter, Paint, PaintingStyle, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'tile_cell_iteration.dart';

final Logger _log = Logger('infrastructure.mirk.solid_fill');

/// Sigma multiplier used to derive [SolidFillMirkRenderer]'s feather
/// radius from the on-screen cell size. Matches the magnitude of the
/// `featherRadiusFraction` defaults on the animated variants (0.1 ×
/// cellSize) — keeps the rounded-reveal corners consistent across all
/// 4 builtins (BUG-006 fix, 2026-04-25). Hard-coded because [SolidConfig]
/// intentionally has no feather param (the variant is the debug /
/// proof-of-seam minimalist).
const double _kSolidFeatherCellFraction = 0.1;

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
///
/// ## BUG-006 (2026-04-25): rounded reveal corners
///
/// Solid ships a `MaskFilter.blur(BlurStyle.normal, sigma)` matching the
/// 3 animated variants so the cell-rectangle holes around the user's
/// reveal radius read as a smooth circle, not a stair-step grid of 64
/// little squares. Sigma is derived from the on-screen cell size at
/// paint time (depends on canvas height), not pre-computed in `_paint`.
class SolidFillMirkRenderer implements MirkRenderer {
  /// Constructs a renderer using [config] for colour + alpha.
  SolidFillMirkRenderer(this.config);

  /// Fog colour + baseline alpha.
  final SolidConfig config;

  /// Cached colour-only Paint base. Sigma depends on canvas height +
  /// device pixel ratio (resolved per `paint()` call), so the MaskFilter
  /// is applied on a fresh Paint each frame rather than baked into this
  /// `late final`.
  late final Color _color = _computeColor(config);

  bool _disposed = false;

  /// BUG-009 follow-up diagnostic (2026-04-26) — see the atmospheric
  /// renderer. Tracks the last `paint()` early-return reason so silent
  /// bailouts surface in the file logger.
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;
  int _paintCallCount = 0;

  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
  }

  /// Computes the final fog colour: extracts RGB from `config.colorArgb`
  /// and combines `colorArgb`'s alpha byte with `config.baselineAlpha`.
  static Color _computeColor(SolidConfig config) {
    final argb = config.colorArgb;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final aFromArgb = (argb >> 24) & 0xFF;
    final finalAlpha = (aFromArgb * config.baselineAlpha).clamp(0.0, 255.0).round();
    return Color.fromARGB(finalAlpha, r, g, b);
  }

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (!_firstPaintLogged) {
      _log.info(
        'paint(): first invocation — disposed=$_disposed visibleTiles=${context.visibleTiles.length} canvasSize=${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}',
      );
      _firstPaintLogged = true;
    } else if (_paintCallCount % 60 == 0) {
      _log.info('paint(): entry heartbeat frame=$_paintCallCount disposed=$_disposed visibleTiles=${context.visibleTiles.length}');
    }
    _paintCallCount++;
    if (_disposed) {
      _logEarlyReturnTransition('disposed');
      return;
    }
    if (context.visibleTiles.isEmpty) {
      _logEarlyReturnTransition('visibleTiles.isEmpty');
      return;
    }
    // Solid renderer adopts the same viewport-level path strategy as the
    // 3 animated renderers — BUG-003 (2026-04-25) consolidated all 4 on
    // [buildViewportFogClipPath] for consistency. Solid never showed the
    // damier (no MaskFilter) but unifying the path strategy avoids
    // future seam discrepancies between variants AND saves N-1 drawPath
    // calls per frame on a viewport with N visible tiles.
    //
    // BUG-006 (2026-04-25) — adds the same `BlurStyle.normal` feather as
    // the animated variants so cell-rectangle reveal holes round into a
    // circle. Sigma derived from canvas height because cells are
    // pixel-sized at paint time, not bake-time.
    final cellSize = size.height / kRevealedTileSubgridSize;
    final featherSigma = cellSize * _kSolidFeatherCellFraction * context.pixelRatio;
    final paint = Paint()
      ..color = _color
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);
    final path = buildViewportFogClipPath(visibleTiles: context.visibleTiles, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible tile fully revealed?)');
      return;
    }
    _logEarlyReturnTransition('none');
    canvas.drawPath(path, paint);
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
