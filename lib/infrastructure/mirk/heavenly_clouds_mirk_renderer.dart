// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui' as ui show FragmentProgram, FragmentShader, Image, Path;
import 'dart:ui' show BlurStyle, Canvas, Color, MaskFilter, Paint, PaintingStyle, Rect, Size;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';

import 'noise/simplex_noise_2d.dart';
import 'sdf/revealed_sdf_builder.dart';
import 'shader/fog_shader_service.dart';
import 'shader/fog_shader_uniforms.dart';
import 'tile_cell_iteration.dart';

/// Heavenly clouds — TIER 2 shader-driven (BUG-009 fix).
///
/// MIRK-06 builtin variant. Uses the same `atmospheric_fog.frag` as
/// the atmospheric renderer but with different uniform values:
///   - Lighter dawn-grey palette (`kMirkFogHeavenlyXxx` constants).
///   - Faster Z-axis drift speeds — clouds visibly evolve faster than
///     thick atmospheric fog.
///   - Slightly larger noise scales — cloud blobs read as bigger puffs.
///
/// See `AtmosphericMirkRenderer` for the full architecture rationale
/// (shader path + fallback path, SDF caching, hash-based rebuild
/// invalidation). The structure of this class is parallel — only the
/// uniform values differ.
class HeavenlyCloudsMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config], an optional [seed] for
  /// per-instance shader perturbation, an injected [shaderService],
  /// and an injected [sdfBuilder].
  HeavenlyCloudsMirkRenderer(this.config, {int seed = 91, FogShaderService? shaderService, RevealedSdfBuilder sdfBuilder = const RevealedSdfBuilder()})
    : _seed = seed,
      _noise = SimplexNoise2D(seed: seed),
      _shaderService = shaderService ?? FogShaderService(),
      _sdfBuilder = sdfBuilder {
    _shaderLoadFuture = _shaderService.load();
  }

  /// Heavenly-clouds configuration.
  final HeavenlyCloudsConfig config;

  /// Seed used for per-instance shader perturbation (uTime offset).
  final int _seed;

  /// CPU simplex noise — fallback path only.
  // ignore: unused_field — retained so the regression test "different
  // seeds produce different output" can discriminate even when the
  // shader path is unavailable on a given test platform.
  final SimplexNoise2D _noise;

  final FogShaderService _shaderService;
  final RevealedSdfBuilder _sdfBuilder;

  late final Future<ui.FragmentProgram?> _shaderLoadFuture;
  ui.FragmentShader? _shader;
  ui.Image? _sdfImage;
  int _lastSdfHash = 0;
  bool _sdfBuildInFlight = false;

  /// Public future used by tests to wait until the shader has loaded
  /// (or failed to load).
  Future<void> get shaderReady => _shaderLoadFuture.then((_) {});

  bool _disposed = false;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (_disposed) return;
    if (context.visibleTiles.isEmpty) return;
    final path = buildViewportFogClipPath(visibleTiles: context.visibleTiles, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) return;
    _shader ??= _shaderService.obtainShaderSync();
    _refreshSdfIfNeeded(context: context, canvasSize: size);
    final shader = _shader;
    final sdf = _sdfImage;
    if (shader != null && sdf != null) {
      _paintShaderPath(canvas, size, context, path, shader, sdf);
      return;
    }
    _paintFallbackPath(canvas, size, context, path);
  }

  void _paintShaderPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path, ui.FragmentShader shader, ui.Image sdf) {
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final tUniform = tSec + _seed * 0.137;
    final centreLat = (context.viewportBbox.north + context.viewportBbox.south) * 0.5;
    final centreLon = (context.viewportBbox.east + context.viewportBbox.west) * 0.5;
    final offsetX = centreLon * 0.05;
    final offsetY = -centreLat * 0.05;
    FogShaderUniforms.setAll(
      shader,
      resolution: size,
      time: tUniform,
      offset: (offsetX, offsetY),
      // Heavenly palette — Hebridean dawn (warm highlight, cool shadow).
      baseArgb: kMirkFogHeavenlyBaseColorArgb,
      baseAlpha: config.baselineAlpha,
      highlightArgb: kMirkFogHeavenlyHighlightColorArgb,
      shadowArgb: kMirkFogHeavenlyShadowColorArgb,
      // Faster drift than atmospheric — clouds evolve visibly faster.
      driftZFar: kMirkFogHeavenlyDriftZFar,
      driftZMid: kMirkFogHeavenlyDriftZMid,
      driftZNear: kMirkFogHeavenlyDriftZNear,
      // Bigger puffs (finer near-octave for cloud detail).
      scaleFar: kMirkFogHeavenlyScaleFar,
      scaleMid: kMirkFogHeavenlyScaleMid,
      scaleNear: kMirkFogHeavenlyScaleNear,
      // Same opacity weights as atmospheric — the parallax depth
      // signature stays consistent across builtins.
      opacityFar: kMirkFogOpacityFar,
      opacityMid: kMirkFogOpacityMid,
      opacityNear: kMirkFogOpacityNear,
      curlAmplitude: kMirkFogCurlAmplitude,
      curlScale: kMirkFogCurlScale,
      lightDirRadians: kMirkFogLightDirRadians,
      lightOffset: kMirkFogLightOffset,
      lightStrength: kMirkFogLightStrength,
      hueNoiseScale: kMirkFogHueNoiseScale,
      hueStrength: kMirkFogHueStrength,
      boundarySharpDistance: kMirkFogBoundarySharpDistance,
      boundaryBleedDistance: kMirkFogBoundaryBleedDistance,
      boundaryEdgeBand: kMirkFogBoundaryEdgeBand,
      sdfRect: const (0.0, 0.0, 1.0, 1.0),
      sdfImage: sdf,
    );
    canvas.save();
    canvas.clipPath(path);
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    canvas.restore();
  }

  void _paintFallbackPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path) {
    final r = (kMirkFogHeavenlyBaseColorArgb >> 16) & 0xFF;
    final g = (kMirkFogHeavenlyBaseColorArgb >> 8) & 0xFF;
    final b = kMirkFogHeavenlyBaseColorArgb & 0xFF;
    final cellSize = size.height / kRevealedTileSubgridSize;
    // Heavenly fallback uses a slightly larger feather than atmospheric
    // — clouds are softer-edged than thick fog. Same hard-coded 1.5×
    // multiplier as pre-BUG-009.
    final featherSigma = cellSize * 0.15 * context.pixelRatio;
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final radians = config.driftDirectionDeg * math.pi / 180.0;
    final driftX = math.cos(radians);
    final driftY = -math.sin(radians);
    final noiseSample = _noise.noise2(tSec * config.noiseSpeed * driftX, tSec * config.noiseSpeed * driftY);
    final alpha = (config.baselineAlpha + noiseSample * 0.10).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Color.fromARGB((alpha * 255).round(), r, g, b)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);
    canvas.drawPath(path, paint);
  }

  void _refreshSdfIfNeeded({required MirkPaintContext context, required Size canvasSize}) {
    if (_sdfBuildInFlight) return;
    final hash = _computeSdfHash(context);
    if (hash == _lastSdfHash && _sdfImage != null) return;
    _sdfBuildInFlight = true;
    _lastSdfHash = hash;
    _sdfBuilder
        .build(visibleTiles: context.visibleTiles, viewport: context.viewportBbox)
        .then((image) {
          if (_disposed) {
            image.dispose();
            return;
          }
          _sdfImage?.dispose();
          _sdfImage = image;
        })
        .catchError((Object _) {})
        .whenComplete(() {
          _sdfBuildInFlight = false;
        });
  }

  int _computeSdfHash(MirkPaintContext context) {
    var hash = 0x811C9DC5;
    final bbox = context.viewportBbox;
    hash = _mix(hash, bbox.south.hashCode);
    hash = _mix(hash, bbox.west.hashCode);
    hash = _mix(hash, bbox.north.hashCode);
    hash = _mix(hash, bbox.east.hashCode);
    for (final tile in context.visibleTiles) {
      hash = _mix(hash, tile.parentX);
      hash = _mix(hash, tile.parentY);
      for (var i = 0; i < 8; i++) {
        hash = _mix(hash, tile.bitmap[i * 64]);
      }
    }
    return hash;
  }

  int _mix(int hash, int v) {
    hash ^= v;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
    return hash;
  }

  @override
  void update(Duration elapsed) {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _shader?.dispose();
    _shader = null;
    _sdfImage?.dispose();
    _sdfImage = null;
  }
}
