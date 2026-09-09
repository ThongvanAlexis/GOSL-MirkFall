// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async' show Completer;
import 'dart:isolate' show Isolate;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'simplex_noise_2d.dart';

/// Pre-rasterised tileable simplex-noise grayscale texture.
///
/// BUG-004 (2026-04-25) reintroduced the animated noise pattern that the
/// BUG-003 fix had collapsed into a single per-frame alpha sample. The
/// post-BUG-003 renderers paint ONE viewport-level fog body per frame —
/// per-cell noise modulation is gone. Re-adding texture without bringing
/// back the per-cell loop (which produced the damier) means painting an
/// animated noise pattern OVER the fog body: a tileable noise image
/// drawn through an `ImageShader` whose matrix carries the world anchor.
///
/// Since Phase 09.1-06 the tile is the CPU twin of the shader's world-pixel
/// noise for `HeavenlyCloudsMirkRenderer`'s fallback path: one tile spans
/// `kMirkFogNoiseTilePx × zoomScale` screen pixels and is translated by the
/// raw camera `pixelOrigin`, so a pan moves the clouds with the map and a
/// zoom scales them (FOG-17 / FOG-19 on the CPU).
///
/// ## Why pre-rasterise
///
/// Sampling [SimplexNoise2D] per pixel per frame on the CPU is too slow
/// (a 1080×1920 viewport = ~2 M samples × 60 fps = 124 M samples/sec).
/// A 256×256 noise tile is 65 k samples generated ONCE; subsequent
/// frames reuse the tile through the engine's native image-shader path on
/// the GPU side.
///
/// ## Tile size choice
///
/// 256×256 px:
/// - Large enough that the repeating pattern is not obviously tiled at
///   typical 800-1200 px viewport sizes (the eye sees ~3-4 repeats per
///   axis, blending into "irregular noise").
/// - Small enough that the rasterisation cost (~65 k simplex samples,
///   one-time on a mid-range device) is negligible compared to a 60 fps
///   frame budget.
/// - Power of 2 — friendlier to GPU samplers.
///
/// ## Tileability
///
/// To enforce seamless tiling each pixel is computed as the bilinear
/// blend of four simplex samples taken at the 2D-wrap corners of the
/// unit cell, weighted by `(1-u, 1-v)` etc. This is the standard "Perlin
/// torus blend" trick — the right + bottom seams match the left + top
/// seams up to perceptual threshold without needing a 4D sampler.
///
/// ## Lifecycle
///
/// Build once via [build] (returns a Future: the pixels are rasterised in a
/// background isolate and the `ui.Image` decode is async). Cache the result;
/// reuse for every frame; the caller owns and disposes the image. Renderers
/// hold a nullable `ui.Image?` field, kick off [build] in their constructor,
/// and skip the noise overlay until the future resolves.
class NoiseTexture {
  const NoiseTexture._();

  /// Tile dimensions in pixels.
  static const int kSize = 256;

  /// Bytes per RGBA pixel.
  static const int _kBytesPerPixel = 4;

  /// Opaque alpha byte — the overlay strength is applied by the caller's paint.
  static const int _kOpaqueAlpha = 255;

  /// Builds a 256×256 RGBA tileable noise image, sampled from
  /// [SimplexNoise2D] with the given [seed] and spatial [frequency]
  /// (cycles across the tile width). Returns a `ui.Image` ready for use
  /// as an [ui.ImageShader] source.
  ///
  /// ## Pixel format choice — grayscale RGB at full alpha
  ///
  /// Pixels are `(noiseByte, noiseByte, noiseByte, 255)`. The noise
  /// modulates the RGB intensity, NOT the alpha. Renderers set the overlay
  /// strength on their paint (colour filter) so the fog's own alpha stays
  /// untouched. Alpha-modulated white made every pixel paint as near-opaque
  /// white over the dark fog (simplex noise rarely drops below ~50 % →
  /// srcOver always won) — the fog became uniformly bleached.
  ///
  /// ## CPU work
  ///
  /// 256×256 × 4 (corner blends for tileability) ≈ 260 k simplex samples —
  /// tens of milliseconds even in AOT, so [rasterisePixels] runs in a
  /// background isolate (`Isolate.run`) and never stalls a frame at renderer
  /// construction. The `ui.Image` itself must be created on the root isolate.
  static Future<ui.Image> build({int seed = 17, double frequency = 4.0}) async {
    final Uint8List pixels = await Isolate.run(() => rasterisePixels(seed: seed, frequency: frequency));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, kSize, kSize, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Raw RGBA bytes of the tile (row-major, `kSize × kSize × 4`) — pure CPU,
  /// isolate-safe. Public so the rasterisation can be tested without a
  /// `ui.Image`.
  static Uint8List rasterisePixels({required int seed, required double frequency}) {
    final noise = SimplexNoise2D(seed: seed);
    final pixels = Uint8List(kSize * kSize * _kBytesPerPixel);

    for (var j = 0; j < kSize; j++) {
      for (var i = 0; i < kSize; i++) {
        final u = i / kSize;
        final v = j / kSize;
        // Four wrap-corner samples → bilinear blend by (u, v) weights.
        // The product weights `(1-u)*(1-v)` etc. sum to 1, so the result
        // stays in the simplex envelope `[-~1, ~1]`.
        final n00 = noise.noise2(u * frequency, v * frequency);
        final n10 = noise.noise2((u - 1.0) * frequency, v * frequency);
        final n01 = noise.noise2(u * frequency, (v - 1.0) * frequency);
        final n11 = noise.noise2((u - 1.0) * frequency, (v - 1.0) * frequency);
        final blended = n00 * (1 - u) * (1 - v) + n10 * u * (1 - v) + n01 * (1 - u) * v + n11 * u * v;
        // Map [-1, 1] → [0, 255]. Simplex envelope rarely exceeds ±1.05
        // so the clamp is a safety net.
        final byte = ((blended + 1.0) * 0.5 * _kOpaqueAlpha).clamp(0.0, _kOpaqueAlpha.toDouble()).toInt();
        final idx = (j * kSize + i) * _kBytesPerPixel;
        pixels[idx] = byte; // R — grayscale noise
        pixels[idx + 1] = byte; // G
        pixels[idx + 2] = byte; // B
        pixels[idx + 3] = _kOpaqueAlpha; // A — full opacity; the paint controls strength
      }
    }
    return pixels;
  }
}
