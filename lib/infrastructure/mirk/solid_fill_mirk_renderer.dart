// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show BlurStyle, Canvas, Color, MaskFilter, Paint, PaintingStyle, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'tile_cell_iteration.dart';

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
/// 3 animated variants so the reveal silhouette reads as a smooth
/// circle. With BUG-010 Option B Commit 5 the silhouette is already
/// mathematically circular (continuous-geometry discs); the feather is
/// now decorative softness on top.
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
    // BUG-013 fix: do NOT early-return on empty discs. When the user pans
    // away from the revealed area, all discs fall outside the viewport →
    // discsInBbox returns []. The correct behaviour is FULL FOG (entire
    // viewport covered), not "skip rendering" which shows a clear map.
    // buildViewportFogClipPathFromDiscs handles empty discs correctly by
    // returning the viewport rect (= everything is fog, nothing revealed).
    //
    // Solid renderer adopts the same viewport-level disc clip path as the
    // 3 animated renderers — BUG-010 Option B Commit 5 collapsed the 4
    // builtins onto a single canonical clip helper. Solid never showed
    // the damier (no MaskFilter pre-BUG-006) but unifying the path
    // strategy avoids future seam discrepancies between variants AND
    // saves N-1 drawPath calls per frame on a viewport with N visible
    // tiles (legacy bitmap path, retired here).
    //
    // BUG-006 (2026-04-25) — adds the same `BlurStyle.normal` feather as
    // the animated variants so the disc silhouette gets a soft
    // watercolour edge. Sigma derived from a fixed 4-px base × the
    // configured fraction × pixel ratio.
    const baseFeatherPx = 4.0;
    final featherSigma = baseFeatherPx * _kSolidFeatherCellFraction * context.pixelRatio;
    final paint = Paint()
      ..color = _color
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);
    final path = buildViewportFogClipPathFromDiscs(discs: context.discs, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible region fully revealed?)');
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
