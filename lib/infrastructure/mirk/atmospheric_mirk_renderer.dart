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

/// Default atmospheric fog renderer — dark noise-modulated overlay
/// with subtle directional drift.
///
/// MIRK-04 default builtin. Reads `context.sessionElapsed` for
/// animation phase (NOT a separate `frameElapsed` field — research
/// consolidation, plan 09-02 SUMMARY).
///
/// ## Animation
///
/// The fog's overall alpha is modulated by simplex noise sampled at:
/// ```
/// (tSec * noiseSpeed * driftX, tSec * noiseSpeed * driftY)
/// ```
/// where `tSec = context.sessionElapsed.inMilliseconds / 1000.0` and
/// `(driftX, driftY) = (cos(driftDirectionDeg), -sin(driftDirectionDeg))`.
/// The negative `sin` accounts for screen-Y growing south while
/// nautical-style headings increment east-of-north.
///
/// Pre-BUG-003 the noise sample mixed in `(parentX, parentY)` for each
/// visible tile, producing per-tile alpha variation. Post-BUG-003 the
/// renderer paints ONE viewport-wide path with ONE alpha value per
/// frame, so per-parent-tile spatial variation is gone — the fog
/// pulsates uniformly over time. The drift direction still affects the
/// noise sampling trajectory, so `noiseSpeed` and `driftDirectionDeg`
/// remain meaningful animation parameters.
///
/// ## Visible texture overlay (BUG-004 fix, 2026-04-25)
///
/// On top of the alpha-pulsing solid fog, the renderer paints a SECOND
/// pass: a tileable simplex-noise grayscale image (256×256, built once
/// from [NoiseTexture.build]) drawn through an [ImageShader] over the
/// same fog clip path. The shader's translation matrix evolves with
/// `sessionElapsed`, so the noise pattern visibly drifts across frames
/// (the "moving fog" the user expects from a fog-of-war atmosphere).
///
/// Blend mode `BlendMode.softLight` lays the grayscale noise on top of
/// the fog colour without bleaching it — bright noise pixels lighten the
/// fog slightly, dark pixels darken it slightly, giving the "billowing
/// cloud" texture without changing the overall density. The 2-pass cost
/// is one extra `drawPath` per frame; the noise image is GPU-resident
/// after the first paint so the per-frame cost is just a shader sample.
///
/// First few frames before the noise image future resolves: noise pass
/// is skipped (solid coloured fog only, indistinguishable from the
/// existing pre-BUG-004 behaviour). Imperceptible at 60 fps.
///
/// ## Feather edge — single mask filter pass per frame
///
/// `MaskFilter.blur(BlurStyle.normal, sigma)` applies to ONE composite
/// path covering the entire viewport's fogged area (see
/// [buildViewportFogClipPath]). Pre-BUG-003 each visible tile drew with
/// its own mask filter — the parent-tile seams accumulated TWO feather
/// passes (one from each side), producing the bright-band damier the
/// user reported on iOS sideload. The single-pass strategy puts the
/// feather only on the global fog/clear boundary.
///
/// `BlurStyle.normal` (BUG-006 fix, 2026-04-25) replaces `BlurStyle.inner`.
/// Inner-only blur erodes alpha INWARD from each path edge but leaves the
/// hole side perfectly sharp — the cell-rectangle corners of revealed
/// areas read as a stair-step grid of squares instead of a smooth circle.
/// Normal blur smears alpha symmetrically across the boundary: fog leaks
/// slightly into the reveal cells, rounding their corners into something
/// that reads as a circle (matches classic fog-of-war visuals). Sigma is
/// kept conservative (driven by `featherRadiusFraction`) so the leak does
/// not visibly shrink the cleared zone.
class AtmosphericMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config] and an optional [seed] for
  /// the internal simplex noise generator. Different seeds produce
  /// different fog patterns under the same config.
  AtmosphericMirkRenderer(this.config, {int seed = 42}) : _noise = SimplexNoise2D(seed: seed) {
    // Kick off the one-time noise-texture rasterisation. The Future
    // resolves asynchronously (~5-15 ms on first call); subsequent
    // frames sample the cached image. Errors are swallowed — the
    // renderer falls back to solid-coloured fog (existing pre-BUG-004
    // behaviour). Catching as `Object` keeps the pipeline alive against
    // any unexpected `decodeImageFromPixels` failure mode.
    //
    // _noiseReadyFuture chains the build with the field assignment, so
    // awaiting it guarantees `_noiseImage` is set (or null on error)
    // before the next paint sees it. Tests use this property to
    // synchronously assert the noise overlay's effect.
    final buildFuture = NoiseTexture.build(seed: seed);
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

  /// Atmospheric configuration: base colour, noise scale/speed, drift
  /// direction, baseline alpha, feather radius fraction.
  final AtmosphericConfig config;

  final SimplexNoise2D _noise;

  /// Pre-rasterised tileable noise texture, built ONCE on construction.
  /// Null until the async build resolves; null also if the build
  /// errored. Renderers gracefully skip the texture overlay while null.
  ui.Image? _noiseImage;

  /// Future that resolves AFTER `_noiseImage` has been assigned (success
  /// path) or AFTER the build error has been swallowed. Awaiting this
  /// gives tests a deterministic point at which the noise overlay
  /// becomes effective.
  late final Future<void> _noiseReadyFuture;

  /// Public accessor for the test-only "noise texture is ready" Future.
  /// Production paint code does not need to await this — the renderer
  /// falls back to solid-coloured fog while the image is loading,
  /// indistinguishable at 60 fps.
  Future<void> get noiseReady => _noiseReadyFuture;

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
    final featherSigma = cellSize * config.featherRadiusFraction * context.pixelRatio;

    // Sample noise once at the time-evolving "drift point" — the spatial
    // origin (0, 0) plus the time-evolving drift offset. The viewport
    // sees uniform-density fog whose density evolves over time.
    final noiseSample = _noise.noise2(tSec * config.noiseSpeed * driftX, tSec * config.noiseSpeed * driftY);
    // Modulate alpha by ±3% around the configured baseline.
    final alpha = (config.densityBaselineAlpha + noiseSample * 0.03).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Color.fromARGB((alpha * 255).round(), r, g, b)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);

    // BUG-003 fix (2026-04-25): single viewport-level path. See
    // [buildViewportFogClipPath] for the rationale (eliminates
    // per-tile feather-cumulation at parent-tile seams).
    final path = buildViewportFogClipPath(visibleTiles: context.visibleTiles, viewport: context.viewportBbox, canvasSize: size);
    // Skip drawing entirely when every visible tile is fully revealed
    // — the difference op carved out the entire viewport rect.
    if (path.getBounds().isEmpty) return;
    canvas.drawPath(path, paint);

    // BUG-004 fix (2026-04-25): animated noise texture overlay. Drawn
    // ONLY when the pre-rasterised image is ready (first frames before
    // the build future resolves render solid fog only — imperceptible
    // at 60 fps). Drift translation derives from `tSec * pixelsPerSec`
    // along the configured direction, so the shader sample shifts each
    // frame and the user sees moving fog.
    final noiseImage = _noiseImage;
    if (noiseImage != null) {
      // Drift speed in screen pixels per second. The constant 30 px/s
      // gives a "slow billowing" pace at typical viewport scales (~5
      // seconds to traverse the visible area). Tied to driftDirectionDeg
      // so the visual matches the alpha-modulation drift trajectory.
      const double pxPerSec = 30.0;
      final translateX = tSec * pxPerSec * driftX;
      final translateY = tSec * pxPerSec * driftY;
      // 4×4 column-major matrix (Float64List(16)) for the ImageShader
      // sample transform. We only need a translation, so identity + tx/ty
      // in the last column. Skia uses this to project canvas-space pixels
      // into image-space sample coordinates: a positive translateX moves
      // the SAMPLE point further along x for any given canvas pixel,
      // which visually scrolls the noise pattern in the OPPOSITE
      // direction. Multiplying by -1 aligns scroll direction with drift.
      final m = Float64List(16)
        ..[0] = 1.0
        ..[5] = 1.0
        ..[10] = 1.0
        ..[15] = 1.0
        ..[12] = -translateX
        ..[13] = -translateY;
      final shader = ImageShader(noiseImage, TileMode.repeated, TileMode.repeated, m);
      // saveLayer with reduced-alpha paint dims the entire noise pass.
      // Skia ignores `Paint.color` alpha when a shader is set, so this
      // is the cleanest way to scale the overlay's strength.
      // 80/255 ≈ 0.31 — bright noise peaks (RGB ~200) paint at ~62
      // over the (0, 0, 0) fog, dark troughs (~50) at ~16. The fog
      // stays visibly dark while showing texture variation.
      final layerBounds = path.getBounds();
      canvas.saveLayer(layerBounds, Paint()..color = const Color.fromARGB(80, 0, 0, 0));
      final noisePaint = Paint()..shader = shader;
      canvas.drawPath(path, noisePaint);
      canvas.restore();
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
    if (_disposed) return;
    _disposed = true;
    // Dispose the noise image if it was already built. If still in
    // flight, the `.then` callback above will dispose it on arrival
    // because `_disposed` flips before the future resolves.
    _noiseImage?.dispose();
    _noiseImage = null;
  }
}
