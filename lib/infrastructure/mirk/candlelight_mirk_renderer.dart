// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui' show BlurStyle, Canvas, Color, Gradient, MaskFilter, Offset, Paint, PaintingStyle, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'mirk_projection.dart';
import 'noise/simplex_noise_2d.dart';
import 'tile_cell_iteration.dart';

final Logger _log = Logger('infrastructure.mirk.candlelight');

/// Warm-glow candlelight fog renderer — radial gradient anchored on
/// the current GPS fix (or viewport centre when no fix is yet available),
/// modulated by a high-frequency flicker.
///
/// MIRK-06 builtin variant. Faster oscillation than the atmospheric
/// drift gives a "dancing flame" feel; the radial gradient produces
/// the "lit room with a candle in the middle" composition.
///
/// ## Glow centre
///
/// `context.currentFix` (when present) is projected to screen space via
/// [MirkProjection.latLonToScreen] and used as the gradient centre.
/// When `currentFix == null` (no fix yet — early session, lost signal),
/// the gradient falls back to the canvas centre `(size.width / 2,
/// size.height / 2)`. This matches the user's expectation that the
/// glow always has a visible centre, never disappears.
///
/// ## Flicker
///
/// `_noise.noise2(0.0, tSec * noiseSpeed * 10)` is sampled per frame
/// (1D-style flicker — the y-axis carries time, the x-axis is static).
/// The flicker amplitude is ±7% of `baselineAlpha`, fast enough to
/// read as "flame" but not so fast it becomes strobing.
///
/// ## BUG-003 (2026-04-25): single viewport-level path
///
/// Like the atmospheric and heavenly_clouds variants, candlelight now
/// composes a single viewport-wide fog path and emits ONE
/// `canvas.drawPath` per frame. The radial gradient covers the whole
/// canvas; the path carves out the union of revealed discs (BUG-010
/// Option B Commit 5 — continuous geometry replaces the cell-bitmap
/// hole rectangles).
///
/// ## BUG-006 (2026-04-25): rounded reveal corners
///
/// Switched `BlurStyle.inner` → `BlurStyle.normal` so the hole edges
/// blur in BOTH directions. With Commit 5's continuous-geometry clip
/// path the disc silhouette is already mathematically circular; the
/// `BlurStyle.normal` feather adds the soft watercolour edge.
class CandlelightMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config] and an optional [seed] for
  /// the internal flicker-noise generator.
  CandlelightMirkRenderer(this.config, {int seed = 17}) : _noise = SimplexNoise2D(seed: seed);

  /// Candlelight configuration.
  final CandlelightConfig config;

  final SimplexNoise2D _noise;

  bool _disposed = false;

  /// BUG-009 follow-up diagnostic (2026-04-26) — see the atmospheric
  /// renderer for the rationale. Mirrored here because the user MAY
  /// have selected the candlelight builtin instead of atmospheric, and
  /// in that case all four early-return paths below would otherwise
  /// produce zero log output.
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;
  int _paintCallCount = 0;

  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
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
    if (context.discs.isEmpty) {
      _logEarlyReturnTransition('discs empty');
      return;
    }

    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    // Flicker noise sampled along time only — gives the
    // "single oscillating flame brightness" effect.
    final flicker = _noise.noise2(0.0, tSec * config.noiseSpeed * 10.0);

    // Centre of the radial gradient: GPS fix when available, viewport
    // centre as fallback. The fallback keeps the user UX coherent
    // before the first fix lands (or after a signal loss).
    final centre = context.currentFix != null
        ? MirkProjection.latLonToScreen(lat: context.currentFix!.latitude, lon: context.currentFix!.longitude, viewport: context.viewportBbox, size: size)
        : Offset(size.width / 2, size.height / 2);

    // Glow radius — half the canvas diagonal so the gradient covers the
    // entire canvas even when centred at a corner. The radial fade does
    // the real "fades out further from centre" work. Defensive >0 guard:
    // the Gradient.radial constructor requires radius > 0.
    final diagonalSquared = size.width * size.width + size.height * size.height;
    final radius = diagonalSquared == 0 ? 1.0 : 0.5 * math.sqrt(diagonalSquared);

    // Modulate alpha by ±7% around the configured baseline.
    final alpha = (config.baselineAlpha + flicker * 0.07).clamp(0.0, 1.0);
    final aMul = (alpha * 255).round() / 255.0;

    final centerColor = _applyAlpha(config.centerColorArgb, aMul);
    final peripheryColor = _applyAlpha(config.peripheryColorArgb, aMul);

    // Feather sigma — pre-Commit-5 this scaled to the bitmap cell size
    // (canvas.height / 64) so the soft edge matched a single grid cell.
    // Post-Commit-5 the reveal silhouette is continuous geometry, so the
    // feather scales to a fixed 4 px base and `featherRadiusFraction`
    // tunes the actual blur. See atmospheric renderer for the same
    // rationale.
    const baseFeatherPx = 4.0;
    final featherSigma = baseFeatherPx * config.featherRadiusFraction * context.pixelRatio;

    final shader = Gradient.radial(centre, radius, <Color>[centerColor, peripheryColor], <double>[0.0, 1.0]);
    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);

    // BUG-010 Option B Commit 5 — single canonical disc-based clip path
    // (the per-tile bitmap helper retired with the rest of the cell
    // surface).
    final path = buildViewportFogClipPathFromDiscs(discs: context.discs, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible region fully revealed?)');
      return;
    }
    _logEarlyReturnTransition('none');
    canvas.drawPath(path, paint);
  }

  /// Multiplies the alpha byte of a packed ARGB integer by [factor]
  /// (in `[0, 1]`) and returns a [Color]. Keeps the RGB channels intact.
  static Color _applyAlpha(int argb, double factor) {
    final aFromArgb = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final finalAlpha = (aFromArgb * factor).clamp(0.0, 255.0).round();
    return Color.fromARGB(finalAlpha, r, g, b);
  }

  @override
  void update(Duration elapsed) {
    // sessionElapsed drives flicker (read inside paint) — no internal
    // state to advance.
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
