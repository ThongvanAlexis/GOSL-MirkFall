// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:ui' as ui show FragmentProgram, FragmentShader, Image, Path;
import 'dart:ui' show BlurStyle, Canvas, Color, MaskFilter, Offset, Paint, PaintingStyle, Rect, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import 'animation_helpers.dart';
import 'mirk_projection.dart';
import 'noise/simplex_noise_2d.dart';
import 'sdf/revealed_sdf_builder.dart';
import 'shader/fog_shader_service.dart';
import 'shader/fog_shader_uniforms.dart';
import 'tile_cell_iteration.dart';
import 'wisp/wisp_particle_system.dart';

final Logger _log = Logger('infrastructure.mirk.heavenly_clouds');

/// Heavenly clouds — TIER 2 shader-driven (BUG-009 fix).
///
/// MIRK-06 builtin variant. Uses the same `atmospheric_fog.frag` as
/// the atmospheric renderer but with different uniform values:
///   - Lighter dawn-grey palette (`kMirkFogHeavenlyXxx` constants).
///   - Faster Z-axis drift speeds.
///   - Slightly larger noise scales.
///
/// See `AtmosphericMirkRenderer` for the full architecture rationale
/// (shader path + fallback path, SDF in disc-bbox coordinates, hash-based
/// rebuild invalidation, per-disc wisp emergence).
///
/// ## SDF in disc-bbox coordinates (BUG-014 iteration 4)
///
/// Same architecture as atmospheric: the SDF is built in a fixed
/// "disc bbox" coordinate space. Camera movement does NOT trigger a
/// rebuild — the renderer computes the UV mapping per frame.
class HeavenlyCloudsMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config], an optional [seed] for
  /// per-instance shader perturbation, an injected [shaderService],
  /// and an injected [sdfBuilder].
  HeavenlyCloudsMirkRenderer(
    this.config, {
    int seed = 91,
    FogShaderService? shaderService,
    RevealedSdfBuilder sdfBuilder = const RevealedSdfBuilder(),
    WispParticleSystem? wispSystem,
  }) : _seed = seed,
       _noise = SimplexNoise2D(seed: seed),
       _shaderService = shaderService ?? FogShaderService(),
       _sdfBuilder = sdfBuilder,
       _wispSystem = wispSystem ?? WispParticleSystem(rngSeed: seed) {
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
  final WispParticleSystem _wispSystem;

  /// Disc id set as seen on the previous paint pass.
  Set<String> _previousDiscIdSet = <String>{};

  /// Whether the renderer is still in its warm-up phase. See
  /// [AtmosphericMirkRenderer._warmingUp] for the full BUG-015 rationale.
  bool _warmingUp = true;
  double _lastTSec = 0.0;

  /// BUG-009 follow-up diagnostic: last path tag we INFO-logged.
  String? _lastLoggedPath;
  int _paintCallCount = 0;

  /// BUG-009 follow-up diagnostic (2026-04-26).
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;

  late final Future<ui.FragmentProgram?> _shaderLoadFuture;
  ui.FragmentShader? _shader;

  /// Cached SDF image. Rebuilt only when the disc list changes.
  ui.Image? _sdfImage;

  /// Geographic bounding box the [_sdfImage] was built for.
  MirkViewportBbox? _sdfBbox;

  bool _sdfBuildInFlight = false;

  /// Hash of the disc list that produced [_sdfImage]. Disc-list changes
  /// trigger IMMEDIATE rebuilds.
  int _lastDiscHash = 0;

  /// Public future used by tests to wait until the shader has loaded.
  Future<void> get shaderReady => _shaderLoadFuture.then((_) {});

  bool _disposed = false;

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
    if (_disposed) {
      _logEarlyReturnTransition('disposed');
      return;
    }
    // BUG-013 fix: do NOT early-return on empty discs.
    final path = buildViewportFogClipPathFromDiscs(discs: context.discs, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible region fully revealed?)');
      return;
    }
    _logEarlyReturnTransition('none');
    _shader ??= _shaderService.obtainShaderSync();
    _refreshSdfIfNeeded(context: context);

    // Spawn wisps for newly-emerged discs + advance the system.
    _spawnWispsForNewlyEmergedDiscs(context: context, canvasSize: size);
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final dt = (tSec - _lastTSec).clamp(0.0, 0.1);
    _wispSystem.advance(dt);
    _lastTSec = tSec;

    final shader = _shader;
    final sdf = _sdfImage;
    final pathThisFrame = (shader != null && sdf != null) ? 'shader' : 'fallback';
    if (pathThisFrame != _lastLoggedPath) {
      _log.info(
        'paint(): path transition ${_lastLoggedPath ?? "(initial)"} → $pathThisFrame · shader=${shader != null} sdf=${sdf != null} sdfBuildInFlight=$_sdfBuildInFlight discs=${context.discs.length}',
      );
      _lastLoggedPath = pathThisFrame;
    } else if (_paintCallCount % 60 == 0) {
      _log.info(
        'paint(): post-paint heartbeat path=$pathThisFrame · frame=$_paintCallCount discs=${context.discs.length} sessionElapsed=${context.sessionElapsed.inMilliseconds}ms',
      );
    }
    _paintCallCount++;
    if (shader != null && sdf != null) {
      _paintShaderPath(canvas, size, context, path, shader, sdf);
    } else {
      _paintFallbackPath(canvas, size, context, path);
    }

    // Wisps render last — additive over the fog body.
    canvas.save();
    canvas.clipPath(path);
    _wispSystem.render(canvas, const Color(0xFFF8F0E2));
    canvas.restore();
  }

  /// BUG-009 follow-up diagnostic (2026-04-26).
  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
  }

  /// Same logic as the atmospheric renderer — diff disc id set.
  /// BUG-015 fix: time-based warm-up absorbs the viewport animation.
  void _spawnWispsForNewlyEmergedDiscs({required MirkPaintContext context, required Size canvasSize}) {
    final currentIds = <String>{for (final disc in context.discs) disc.id};

    if (_warmingUp) {
      if (currentIds.isNotEmpty) {
        _previousDiscIdSet.addAll(currentIds);
      }
      final elapsedSec = context.sessionElapsed.inMilliseconds / 1000.0;
      if (elapsedSec >= kMirkFogWispWarmUpSeconds && _previousDiscIdSet.isNotEmpty) {
        _warmingUp = false;
      }
      return;
    }

    for (final disc in context.discs) {
      if (_previousDiscIdSet.contains(disc.id)) continue;
      _spawnWispsAlongDiscPerimeter(disc: disc, viewport: context.viewportBbox, canvasSize: canvasSize);
    }
    _previousDiscIdSet.addAll(currentIds);
  }

  void _spawnWispsAlongDiscPerimeter({required RevealDisc disc, required MirkViewportBbox viewport, required Size canvasSize}) {
    final circumferenceMeters = 2.0 * math.pi * disc.radiusMeters;
    final sampleCount = math.max(1, (circumferenceMeters / kMirkFogMetersPerWisp).ceil());
    final latRad = disc.lat * math.pi / 180.0;
    final cosLat = math.cos(latRad);
    final degPerMeterLat = 1.0 / kMetersPerDegreeLat;
    final degPerMeterLon = cosLat.abs() < 1e-6 ? degPerMeterLat : 1.0 / (kMetersPerDegreeLat * cosLat);
    for (var k = 0; k < sampleCount; k++) {
      final theta = (2.0 * math.pi * k) / sampleCount;
      final perimeterLat = disc.lat + (disc.radiusMeters * degPerMeterLat) * math.sin(theta);
      final perimeterLon = disc.lon + (disc.radiusMeters * degPerMeterLon) * math.cos(theta);
      final screen = MirkProjection.latLonToScreen(lat: perimeterLat, lon: perimeterLon, viewport: viewport, size: canvasSize);
      if (screen.dx < -50 || screen.dx > canvasSize.width + 50 || screen.dy < -50 || screen.dy > canvasSize.height + 50) {
        continue;
      }
      final direction = Offset(math.cos(theta), -math.sin(theta));
      _wispSystem.spawnAtPosition(position: screen, direction: direction);
    }
  }

  void _paintShaderPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path, ui.FragmentShader shader, ui.Image sdf) {
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final tUniform = tSec + _seed * 0.137;
    final centreLat = (context.viewportBbox.north + context.viewportBbox.south) * 0.5;
    final centreLon = (context.viewportBbox.east + context.viewportBbox.west) * 0.5;
    final offsetX = centreLon * 0.05;
    final offsetY = -centreLat * 0.05;
    final t = MirkRuntimeTunables.instance;
    final double effectiveCurlScale = t.curlScaleAnimationEnabled
        ? triangleWave(tSec: tSec, period: t.curlScaleAnimationPeriodSec, minV: t.curlScaleAnimationMin, maxV: t.curlScaleAnimationMax)
        : t.curlScale;

    // BUG-014 iteration 4: compute sdfRect from the stable disc bbox.
    final sdfRect = _computeSdfRect(context.viewportBbox);

    FogShaderUniforms.setAll(
      shader,
      resolution: size,
      time: tUniform,
      offset: (offsetX, offsetY),
      baseArgb: kMirkFogHeavenlyBaseColorArgb,
      baseAlpha: config.baselineAlpha,
      highlightArgb: kMirkFogHeavenlyHighlightColorArgb,
      shadowArgb: kMirkFogHeavenlyShadowColorArgb,
      driftZFar: t.heavenlyDriftZFar,
      driftZMid: t.heavenlyDriftZMid,
      driftZNear: t.heavenlyDriftZNear,
      scaleFar: t.heavenlyScaleFar,
      scaleMid: t.heavenlyScaleMid,
      scaleNear: t.heavenlyScaleNear,
      opacityFar: t.opacityFar,
      opacityMid: t.opacityMid,
      opacityNear: t.opacityNear,
      curlAmplitude: t.curlAmplitude,
      curlScale: effectiveCurlScale,
      lightDirRadians: t.lightDirRadians,
      lightOffset: t.lightOffset,
      lightStrength: t.lightStrength,
      hueNoiseScale: t.hueNoiseScale,
      hueStrength: t.hueStrength,
      boundarySharpDistance: t.boundarySharpDistance,
      boundaryBleedDistance: t.boundaryBleedDistance,
      boundaryEdgeBand: t.boundaryEdgeBand,
      boundaryDensityBoost: t.boundaryDensityBoost,
      sdfRect: sdfRect,
      sdfImage: sdf,
    );
    canvas.save();
    canvas.clipPath(path);
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    canvas.restore();
  }

  /// Computes the sdfRect mapping from screen UV to SDF UV. See
  /// [AtmosphericMirkRenderer._computeSdfRect] for the full rationale.
  (double, double, double, double) _computeSdfRect(MirkViewportBbox currentViewport) {
    final sdfBbox = _sdfBbox;
    if (sdfBbox == null) return (0.0, 0.0, 1.0, 1.0);

    final currentDLon = currentViewport.east - currentViewport.west;
    final currentDLat = currentViewport.north - currentViewport.south;
    if (currentDLon <= 0 || currentDLat <= 0) return (0.0, 0.0, 1.0, 1.0);

    final sdfDLon = sdfBbox.east - sdfBbox.west;
    final sdfDLat = sdfBbox.north - sdfBbox.south;
    if (sdfDLon <= 0 || sdfDLat <= 0) return (0.0, 0.0, 1.0, 1.0);

    final sdfOriginX = (currentViewport.west - sdfBbox.west) / sdfDLon;
    final sdfOriginY = (sdfBbox.north - currentViewport.north) / sdfDLat;
    final sdfSizeX = currentDLon / sdfDLon;
    final sdfSizeY = currentDLat / sdfDLat;

    return (sdfOriginX, sdfOriginY, sdfSizeX, sdfSizeY);
  }

  void _paintFallbackPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path) {
    final r = (kMirkFogHeavenlyBaseColorArgb >> 16) & 0xFF;
    final g = (kMirkFogHeavenlyBaseColorArgb >> 8) & 0xFF;
    final b = kMirkFogHeavenlyBaseColorArgb & 0xFF;
    const baseFeatherPx = 4.0;
    final featherSigma = baseFeatherPx * 0.15 * context.pixelRatio;
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

  /// Checks whether the SDF needs rebuilding. BUG-014 iteration 4:
  /// only disc-list changes trigger a rebuild.
  void _refreshSdfIfNeeded({required MirkPaintContext context}) {
    if (_sdfBuildInFlight) return;

    final discHash = _hashDiscList(context.discs);

    if (discHash != _lastDiscHash) {
      _lastDiscHash = discHash;
      _triggerSdfRebuild(context.discs, context.viewportBbox);
    } else if (_sdfImage == null) {
      _triggerSdfRebuild(context.discs, context.viewportBbox);
    }
  }

  /// Kicks off an async SDF build for [discs].
  void _triggerSdfRebuild(List<RevealDisc> discs, MirkViewportBbox viewport) {
    _sdfBuildInFlight = true;
    _log.fine('_triggerSdfRebuild: scheduling rebuild (discs=${discs.length})');
    _sdfBuilder
        .buildFromDiscs(discs: discs, viewport: viewport)
        .then((SdfBuildResult result) {
          if (_disposed) {
            result.image.dispose();
            return;
          }
          _sdfImage?.dispose();
          _sdfImage = result.image;
          _sdfBbox = result.bbox;
          _log.fine(
            '_triggerSdfRebuild: rebuild complete — _sdfImage now set (${result.image.width}x${result.image.height}) '
            'sdfBbox=[${result.bbox.south.toStringAsFixed(4)}, ${result.bbox.west.toStringAsFixed(4)} → ${result.bbox.north.toStringAsFixed(4)}, ${result.bbox.east.toStringAsFixed(4)}]',
          );
        })
        .catchError((Object e, StackTrace st) {
          _log.severe('_triggerSdfRebuild: build FAILED — fallback path will activate', e, st);
        })
        .whenComplete(() {
          _sdfBuildInFlight = false;
        });
  }

  /// FNV-1a hash of the disc list.
  int _hashDiscList(List<RevealDisc> discs) {
    var hash = 0x811C9DC5;
    hash = _mix(hash, discs.length);
    for (final disc in discs) {
      hash = _mix(hash, disc.id.hashCode);
      hash = _mix(hash, disc.lat.hashCode);
      hash = _mix(hash, disc.lon.hashCode);
      hash = _mix(hash, disc.radiusMeters.hashCode);
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
    _sdfBbox = null;
    _wispSystem.clear();
    _previousDiscIdSet = <String>{};
    _warmingUp = true;
  }
}
