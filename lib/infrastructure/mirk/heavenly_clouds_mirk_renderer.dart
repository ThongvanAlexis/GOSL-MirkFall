// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui show Image;
import 'dart:ui' show BlurStyle, Canvas, Color, ImageShader, MaskFilter, Paint, PaintingStyle, Size, TileMode;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'noise/noise_texture.dart';
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
/// The fog's overall alpha is sampled at:
/// ```
/// noise2(tSec * noiseSpeed * driftX, tSec * noiseSpeed * driftY)
/// ```
/// Pre-BUG-003 the noise sample was offset per-parent-tile by
/// `(parentX * noiseScale, parentY * noiseScale)`. Post-BUG-003 the
/// renderer paints ONE viewport-wide path, so per-tile spatial
/// modulation is gone — the alpha pulses uniformly over time. Drift
/// direction still matters for the noise sampling trajectory.
///
/// ## BUG-003 (2026-04-25): single viewport-level path
///
/// Same fix as atmospheric/candlelight: composes a single viewport-wide
/// fog path so `MaskFilter.blur(BlurStyle.normal, sigma)` runs ONCE on
/// the global silhouette. No more per-tile feather cumulation at parent
/// tile seams.
///
/// ## BUG-006 (2026-04-25): rounded reveal corners
///
/// Switched `BlurStyle.inner` → `BlurStyle.normal` so the hole edges
/// blur in BOTH directions, rounding cell-rectangle corners into circle
/// approximations (classic fog-of-war visual). Inner-only blur left hole
/// boundaries perfectly square. See atmospheric renderer docstring.
///
/// ## BUG-004 (2026-04-25): visible drifting cloud texture
///
/// On top of the alpha-pulsing solid pass, the renderer paints a tileable
/// noise image through an [ImageShader] whose translation evolves with
/// `sessionElapsed`. Pre-fix the renderer had collapsed all spatial
/// modulation into a single per-frame alpha value — the user saw uniform
/// fog with no clouds. Post-fix the ImageShader supplies the visible
/// drifting texture; the existing alpha pulse still adds slow density
/// variation on top. See atmospheric renderer for the full rationale.
/// Heavenly clouds uses a brighter overlay alpha (160) than atmospheric
/// (128) — the variant is meant to read as "thin clouds" so the texture
/// is more prominent.
class HeavenlyCloudsMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config] and an optional [seed] for
  /// the internal cloud-noise generator.
  HeavenlyCloudsMirkRenderer(this.config, {int seed = 91}) : _noise = SimplexNoise2D(seed: seed) {
    // BUG-004: kick off one-time tileable-noise rasterisation. See
    // atmospheric renderer for the full rationale + dispose semantics.
    // Cloud variant uses a lower spatial frequency (3.0 vs atmospheric
    // 4.0) — bigger blobs, "puffier" feel.
    final buildFuture = NoiseTexture.build(seed: seed, frequency: 3.0);
    _noiseReadyFuture = buildFuture
        .then<void>((image) {
          if (_disposed) {
            image.dispose();
            return;
          }
          _noiseImage = image;
        })
        .catchError((Object _) {
          // Fall back to solid fog only.
        });
  }

  /// Heavenly-clouds configuration.
  final HeavenlyCloudsConfig config;

  final SimplexNoise2D _noise;

  /// Pre-rasterised tileable noise — see [AtmosphericMirkRenderer] for
  /// the full lifecycle rationale.
  ui.Image? _noiseImage;

  late final Future<void> _noiseReadyFuture;

  /// See [AtmosphericMirkRenderer.noiseReady].
  Future<void> get noiseReady => _noiseReadyFuture;

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

    // Sample noise once at the time-evolving "drift point" — uniform
    // alpha across the viewport, evolving over time.
    final noiseSample = _noise.noise2(tSec * config.noiseSpeed * driftX, tSec * config.noiseSpeed * driftY);
    // Modulate alpha by ±10% around the configured baseline (wider
    // swing than atmospheric 3% — clouds change density visibly).
    final alpha = (config.baselineAlpha + noiseSample * 0.10).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Color.fromARGB((alpha * 255).round(), r, g, b)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);

    // BUG-003 fix (2026-04-25): single viewport-level path. See
    // [buildViewportFogClipPath] for the rationale.
    final path = buildViewportFogClipPath(visibleTiles: context.visibleTiles, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) return;
    canvas.drawPath(path, paint);

    // BUG-004 fix: animated cloud texture overlay. Cloud variant drifts
    // faster than atmospheric to read as visibly "moving clouds".
    final noiseImage = _noiseImage;
    if (noiseImage != null) {
      // Faster pace than atmospheric (50 vs 30 px/s) — clouds visibly
      // travel across the viewport every few seconds.
      const double pxPerSec = 50.0;
      final translateX = tSec * pxPerSec * driftX;
      final translateY = tSec * pxPerSec * driftY;
      final m = Float64List(16)
        ..[0] = 1.0
        ..[5] = 1.0
        ..[10] = 1.0
        ..[15] = 1.0
        ..[12] = -translateX
        ..[13] = -translateY;
      final shader = ImageShader(noiseImage, TileMode.repeated, TileMode.repeated, m);
      // Layer alpha 140/255 ≈ 55% — heavenly_clouds reads as "thin,
      // bright clouds" so the texture is more prominent than
      // atmospheric (which uses 80/255 ≈ 31%). The fog colour beneath
      // is light grey-white (0xFFE8E8EE), so the noise's white peaks
      // and dark troughs both produce visible variation.
      canvas.saveLayer(path.getBounds(), Paint()..color = const Color.fromARGB(140, 0, 0, 0));
      final noisePaint = Paint()..shader = shader;
      canvas.drawPath(path, noisePaint);
      canvas.restore();
    }
  }

  @override
  void update(Duration elapsed) {
    // sessionElapsed drives drift (read inside paint).
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _noiseImage?.dispose();
    _noiseImage = null;
  }
}
