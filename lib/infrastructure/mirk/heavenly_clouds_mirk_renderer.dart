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

/// Light, airy drifting-clouds fog renderer — coarse-noise blobs that
/// drift NE (45° default) over time.
///
/// MIRK-06 builtin variant. Larger noise scale → bigger cloud blobs,
/// medium noise speed → cloud drift visible at human-comprehensible
/// pace, lighter baseline alpha → "looking through clouds at sunlight"
/// composition rather than the heavier atmospheric "thick-fog" feel.
///
/// ## Drift direction
///
/// `config.driftDirectionDeg` (default `45.0` = NE) controls the noise
/// sample's time-axis offset:
/// ```
/// driftX = cos(driftDirectionDeg)
/// driftY = -sin(driftDirectionDeg)  // screen Y grows south
/// ```
/// Per-tile alpha is sampled at:
/// ```
/// noise2(parentX * noiseScale + tSec * noiseSpeed * driftX,
///        parentY * noiseScale + tSec * noiseSpeed * driftY)
/// ```
class HeavenlyCloudsMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config] and an optional [seed] for
  /// the internal cloud-noise generator.
  HeavenlyCloudsMirkRenderer(this.config, {int seed = 91})
    : _noise = SimplexNoise2D(seed: seed);

  /// Heavenly-clouds configuration.
  final HeavenlyCloudsConfig config;

  final SimplexNoise2D _noise;

  bool _disposed = false;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (_disposed) return;
    if (context.visibleTiles.isEmpty) return;

    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final radians = config.driftDirectionDeg * math.pi / 180.0;
    final driftX = math.cos(radians);
    // See AtmosphericMirkRenderer for the negative-sin rationale
    // (screen Y grows south while nautical headings increment east-of-north).
    final driftY = -math.sin(radians);

    final r = (config.colorArgb >> 16) & 0xFF;
    final g = (config.colorArgb >> 8) & 0xFF;
    final b = config.colorArgb & 0xFF;

    // Use a slightly larger feather than atmospheric — clouds are
    // softer-edged than thick fog. Hard-coded multiplier (1.5×) is a
    // visual choice tied to the "airy" feel; would land in a config
    // field if a future plan needs to expose it.
    final cellSize = size.height / kRevealedTileSubgridSize;
    final featherSigma = cellSize * 0.15 * context.pixelRatio;

    for (final tile in context.visibleTiles) {
      final noiseSample = _noise.noise2(
        tile.parentX * config.noiseScale + tSec * config.noiseSpeed * driftX,
        tile.parentY * config.noiseScale + tSec * config.noiseSpeed * driftY,
      );
      // Modulate alpha by ±10% around the configured baseline (wider
      // swing than atmospheric 3% — clouds change density visibly).
      final alpha = (config.baselineAlpha + noiseSample * 0.10).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.fromARGB((alpha * 255).round(), r, g, b)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.inner, featherSigma);

      final path = buildUnrevealedCellsPath(
        tile: tile,
        viewport: context.viewportBbox,
        canvasSize: size,
      );
      if (path.getBounds().isEmpty) continue;
      canvas.drawPath(path, paint);
    }
  }

  @override
  void update(Duration elapsed) {
    // sessionElapsed drives drift (read inside paint).
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
