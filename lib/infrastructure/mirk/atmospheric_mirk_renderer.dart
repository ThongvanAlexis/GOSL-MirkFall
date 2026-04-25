// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui'
    show BlurStyle, Canvas, Color, MaskFilter, Paint, PaintingStyle, Size;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'noise/simplex_noise_2d.dart';
import 'tile_cell_iteration.dart';

/// Default atmospheric fog renderer — dark noise-modulated overlay
/// with subtle directional drift.
///
/// MIRK-04 default builtin. Reads `context.sessionElapsed` for
/// animation phase (NOT a separate `frameElapsed` field — research
/// consolidation, plan 09-02 SUMMARY).
///
/// ## Animation
///
/// Per-tile alpha is modulated by simplex noise sampled at:
/// ```
/// (parentX * noiseScale + tSec * noiseSpeed * driftX,
///  parentY * noiseScale + tSec * noiseSpeed * driftY)
/// ```
/// where `tSec = context.sessionElapsed.inMilliseconds / 1000.0` and
/// `(driftX, driftY) = (cos(driftDirectionDeg), -sin(driftDirectionDeg))`.
/// The negative `sin` accounts for screen-Y growing south while
/// nautical-style headings increment east-of-north.
///
/// ## Feather edge
///
/// `MaskFilter.blur(BlurStyle.inner, sigma)` is applied to the Paint so
/// the unrevealed-cell rectangles fade from opaque centre to soft edge.
/// Sigma scales with the tile cell size and the device pixel ratio so
/// the feather looks identical across DPI tiers.
class AtmosphericMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config] and an optional [seed] for
  /// the internal simplex noise generator. Different seeds produce
  /// different fog patterns under the same config.
  AtmosphericMirkRenderer(this.config, {int seed = 42})
    : _noise = SimplexNoise2D(seed: seed);

  /// Atmospheric configuration: base colour, noise scale/speed, drift
  /// direction, baseline alpha, feather radius fraction.
  final AtmosphericConfig config;

  final SimplexNoise2D _noise;

  bool _disposed = false;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (_disposed) return;
    if (context.visibleTiles.isEmpty) return;

    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final radians = config.driftDirectionDeg * math.pi / 180.0;
    final driftX = math.cos(radians);
    // Negate sin: nautical headings increment east-of-north (0=N, 90=E),
    // but screen Y grows south (DOWN). cos handles N/S vs E/W mixing
    // automatically; sin needs the flip for the projection to match the
    // user's expectation of "drift towards N over time → fog moves UP
    // on screen".
    final driftY = -math.sin(radians);

    final r = (config.baseColorArgb >> 16) & 0xFF;
    final g = (config.baseColorArgb >> 8) & 0xFF;
    final b = config.baseColorArgb & 0xFF;

    // Cell size in screen pixels — used to scale the feather sigma.
    // Each tile spans roughly the canvas height divided by the on-screen
    // tile count; with 1-2 visible tiles in a typical viewport, the
    // cell size is approximately size.height / 64 / tileCount. We
    // approximate with size.height / 64 (worst-case fattest cell);
    // this is a sigma magnitude, not an exact pixel count.
    final cellSize = size.height / kRevealedTileSubgridSize;
    final featherSigma =
        cellSize * config.featherRadiusFraction * context.pixelRatio;

    for (final tile in context.visibleTiles) {
      final noiseSample = _noise.noise2(
        tile.parentX * config.noiseScale + tSec * config.noiseSpeed * driftX,
        tile.parentY * config.noiseScale + tSec * config.noiseSpeed * driftY,
      );
      // Modulate alpha by ±3% around the configured baseline.
      final alpha = (config.densityBaselineAlpha + noiseSample * 0.03).clamp(
        0.0,
        1.0,
      );
      final paint = Paint()
        ..color = Color.fromARGB((alpha * 255).round(), r, g, b)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.inner, featherSigma);

      final path = buildUnrevealedCellsPath(
        tile: tile,
        viewport: context.viewportBbox,
        canvasSize: size,
      );
      // Skip drawing entirely when the path is empty (every cell of the
      // tile was already revealed — nothing to fog). Avoids cost of an
      // empty drawPath command in the picture record.
      if (path.getBounds().isEmpty) continue;
      canvas.drawPath(path, paint);
    }
  }

  @override
  void update(Duration elapsed) {
    // sessionElapsed (read inside paint) drives the animation phase —
    // no internal state to advance here. The Phase 09 research
    // consolidated on `sessionElapsed` as the single time source per
    // CONTEXT.md §MirkPaintContext Extension Spec.
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
