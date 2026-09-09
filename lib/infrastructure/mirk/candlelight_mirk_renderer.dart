// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Gradient, Offset, Paint, PaintingStyle, Rect, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'fog_edge_feather.dart';
import 'noise/simplex_noise_2d.dart';

final Logger _log = Logger('infrastructure.mirk.candlelight');

/// Base feather width in logical pixels before the fraction / pixel-ratio scaling.
const double _kBaseFeatherPx = 4.0;

/// Flicker amplitude around `baselineAlpha` (±7 %): fast enough to read as
/// "flame", not so strong it strobes.
const double _kFlickerAlphaAmplitude = 0.07;

/// Time multiplier of the flicker noise relative to `noiseSpeed` — the
/// candle oscillates an order of magnitude faster than the cloud drift.
const double _kFlickerTimeMultiplier = 10.0;

/// Warm-glow candlelight fog renderer — radial gradient anchored on
/// the current GPS fix (or viewport centre when no fix is yet available),
/// modulated by a high-frequency flicker.
///
/// MIRK-06 builtin variant. Faster oscillation than the atmospheric
/// drift gives a "dancing flame" feel; the radial gradient produces
/// the "lit room with a candle in the middle" composition.
///
/// ## Glow centre (Phase 09.1: exact camera projection)
///
/// `context.currentFix` (when present) is projected to screen space through
/// `context.projectToScreen` — the single per-paint `MapCamera` snapshot the
/// `FogLayer` hands out (FOG-07), so the glow sits exactly where the map
/// draws the puck. When `currentFix == null` (no fix yet — early session,
/// lost signal), the gradient falls back to the canvas centre
/// `(size.width / 2, size.height / 2)`. This matches the user's expectation
/// that the glow always has a visible centre, never disappears.
///
/// ## Flicker
///
/// `_noise.noise2(0.0, tSec * noiseSpeed * 10)` is sampled per frame
/// (1D-style flicker — the y-axis carries time, the x-axis is static).
/// The flicker amplitude is ±7% of `baselineAlpha`.
///
/// ## Phase 09.1 (plan 09.1-06): the `FogLayer` owns the clip
///
/// [paint] assumes the clipped identity frame the `FogLayer` provides — the
/// reveal holes are already cut, so the gradient fills `Offset.zero & size`
/// and [paintFogBodyWithFeatheredEdges] rounds the cut (BUG-006) with a
/// blurred stroke along the hole outline.
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
  /// in that case the early-return path below would otherwise
  /// produce zero log output.
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;
  int _paintCallCount = 0;

  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
  }

  /// Paints the radial glow over the whole frame, then feathers the reveal
  /// edges. Assumes the clipped identity frame provided by the `FogLayer`
  /// (Phase 09.1); the glow centre comes from `context.projectToScreen`.
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

    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    // Flicker noise sampled along time only — gives the
    // "single oscillating flame brightness" effect.
    final flicker = _noise.noise2(0.0, tSec * config.noiseSpeed * _kFlickerTimeMultiplier);

    final Offset centre = _glowCentre(size, context);

    // Glow radius — half the canvas diagonal so the gradient covers the
    // entire canvas even when centred at a corner. The radial fade does
    // the real "fades out further from centre" work. Defensive >0 guard:
    // the Gradient.radial constructor requires radius > 0.
    final diagonalSquared = size.width * size.width + size.height * size.height;
    final radius = diagonalSquared == 0 ? 1.0 : 0.5 * math.sqrt(diagonalSquared);

    final alpha = (config.baselineAlpha + flicker * _kFlickerAlphaAmplitude).clamp(0.0, 1.0);
    final aMul = (alpha * 255).round() / 255.0;

    final centerColor = _applyAlpha(config.centerColorArgb, aMul);
    final peripheryColor = _applyAlpha(config.peripheryColorArgb, aMul);

    // Feather sigma — pre-Commit-5 this scaled to the bitmap cell size
    // (canvas.height / 64) so the soft edge matched a single grid cell.
    // Post-Commit-5 the reveal silhouette is continuous geometry, so the
    // feather scales to a fixed 4 px base and `featherRadiusFraction`
    // tunes the actual blur.
    final featherSigma = _kBaseFeatherPx * config.featherRadiusFraction * context.pixelRatio;

    final shader = Gradient.radial(centre, radius, <Color>[centerColor, peripheryColor], <double>[0.0, 1.0]);
    final Paint bodyPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;
    paintFogBodyWithFeatheredEdges(
      canvas: canvas,
      size: size,
      context: context,
      featherSigma: featherSigma,
      paintBody: (Canvas canvas, Rect viewport) => canvas.drawRect(viewport, bodyPaint),
    );
  }

  /// Centre of the radial gradient: the GPS fix projected through the camera
  /// snapshot when available, the canvas centre as fallback. The fallback
  /// keeps the UX coherent before the first fix lands (or after a signal loss).
  static Offset _glowCentre(Size size, MirkPaintContext context) {
    final Fix? fix = context.currentFix;
    if (fix == null) return Offset(size.width / 2, size.height / 2);
    return context.projectToScreen((latitude: fix.latitude, longitude: fix.longitude));
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
