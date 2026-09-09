// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Canvas, Color, Paint, PaintingStyle, Rect, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'fog_edge_feather.dart';

final Logger _log = Logger('infrastructure.mirk.solid_fill');

/// Sigma multiplier used to derive [SolidFillMirkRenderer]'s feather
/// radius from a fixed base-pixel reference. Matches the magnitude of the
/// `featherRadiusFraction` defaults on the animated variants (0.1 ×
/// baseFeatherPx) — keeps the rounded-reveal corners consistent across all
/// 4 builtins (BUG-006 fix, 2026-04-25).
///
/// BUG-010 Option B Commit 5: pre-Commit-5 the multiplier was paired with
/// `cellSize = size.height / 64` (the bitmap-cell pixel size). The
/// continuous-geometry reveal layer has no cell concept; the feather now
/// derives from a fixed 4-px base instead of a grid-cell pixel size.
const double _kSolidFeatherCellFraction = 0.1;

/// Base feather width in logical pixels before the fraction / pixel-ratio scaling.
const double _kBaseFeatherPx = 4.0;

/// Flat solid-color fog renderer — no noise, no animation.
///
/// MIRK-06 builtin variant. The minimalist proof-of-seam: if Atmospheric
/// works and Solid works, the renderer factory + `MirkPaintContext`
/// + the shared fog composition are wired correctly. Static output makes
/// regression diffs trivial — any byte change between two frames
/// indicates a bug.
///
/// Configuration ([SolidConfig]):
/// * `colorArgb` — packed ARGB for the fog colour (default `0xFF1A1A1A`).
/// * `baselineAlpha` — additional alpha multiplier `[0, 1]` applied on
///   top of the colour's own alpha byte. Final alpha = `(colorArgb_A
///   * baselineAlpha) / 255`.
///
/// ## Phase 09.1 (plan 09.1-06): the `FogLayer` owns the clip
///
/// [paint] assumes the clipped identity frame the `FogLayer` provides — the
/// reveal holes are already cut out of the canvas, so the body is a plain
/// `Offset.zero & size` rect. Nothing here depends on `pixelOrigin` /
/// `zoomScale`: Solid has no noise to anchor, so its bytes are invariant to
/// the camera-derived fields of the context (tested).
///
/// ## BUG-006 (2026-04-25): rounded reveal corners
///
/// Solid ships the same feather as the 3 animated variants so the reveal
/// silhouette reads as a soft circle — since 09.1-06 through
/// [paintFogBodyWithFeatheredEdges] (a blurred stroke along the hole
/// outline, on the fog side of the clip).
class SolidFillMirkRenderer implements MirkRenderer {
  /// Constructs a renderer using [config] for colour + alpha.
  SolidFillMirkRenderer(this.config);

  /// Fog colour + baseline alpha.
  final SolidConfig config;

  /// Cached fog colour (config is immutable, so this never changes).
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

  /// Paints the solid fog body over the whole frame, then feathers the reveal
  /// edges. Assumes the clipped identity frame provided by the `FogLayer`
  /// (Phase 09.1): no clip, no projection of its own.
  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (!_firstPaintLogged) {
      _log.info(
        'paint(): first invocation — disposed=$_disposed discs=${context.discs.length} canvasSize=${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}',
      );
      _firstPaintLogged = true;
    } else if (_paintCallCount % 60 == 0) {
      _log.info('paint(): entry heartbeat frame=$_paintCallCount disposed=$_disposed discs=${context.discs.length}');
    }
    _paintCallCount++;
    if (_disposed) {
      _logEarlyReturnTransition('disposed');
      return;
    }
    _logEarlyReturnTransition('none');
    // BUG-013: an empty disc list means the user panned away from the
    // revealed area → FULL FOG (the layer's clip is then the whole rect).
    final featherSigma = _kBaseFeatherPx * _kSolidFeatherCellFraction * context.pixelRatio;
    final Paint bodyPaint = Paint()
      ..color = _color
      ..style = PaintingStyle.fill;
    paintFogBodyWithFeatheredEdges(
      canvas: canvas,
      size: size,
      context: context,
      featherSigma: featherSigma,
      paintBody: (Canvas canvas, Rect viewport) => canvas.drawRect(viewport, bodyPaint),
    );
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
