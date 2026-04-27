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

final Logger _log = Logger('infrastructure.mirk.atmospheric');

/// Atmospheric volumetric fog — TIER 2 shader-driven (BUG-009 fix).
///
/// MIRK-04 default builtin. Reads `context.sessionElapsed` for animation
/// phase. The volumetric look comes from a `ui.FragmentShader` that
/// performs 3D-sliced FBM, curl-noise advection, multi-octave parallax,
/// faux directional shading, hue variation, and a two-stop watercolour
/// boundary against a CPU-built SDF of the revealed area.
///
/// ## Two-path rendering
///
/// 1. **Shader path** (preferred): when [FogShaderService.load] succeeds
///    AND the SDF for the current disc-list hash is built, the renderer
///    issues ONE `canvas.drawRect(viewport, Paint()..shader =
///    fragmentShader)` clipped to the fog path. The shader handles all
///    7 TIER 2 quality dimensions; the boundary watercolour falloff
///    inside the shader supersedes the previous `MaskFilter.blur` on
///    the host Paint.
///
/// 2. **Fallback path**: when the shader load fails (invalid asset,
///    Impeller blocklist, etc.) OR while waiting for the first SDF
///    build, the renderer paints a uniform solid fog using the base
///    palette colour at the configured baseline alpha.
///
/// ## SDF in disc-bbox coordinates (BUG-014 iteration 4)
///
/// The SDF is built in a fixed coordinate space: the bounding box of all
/// current discs + padding. Camera movement does NOT trigger an SDF
/// rebuild — instead, each frame the renderer computes the UV mapping
/// from screen coordinates to SDF coordinates (4 trivial divisions).
/// This is how every fog-of-war game does it: the fog texture is in
/// WORLD coordinates, and camera movement only changes the UV mapping.
///
/// ## Wisp emergence (BUG-010 Option B Commit 5)
///
/// Wisps spawn on the per-frame diff of the disc id set. When a fix
/// lands, the disc-list provider gains exactly one new id; the renderer
/// detects the new id and spawns N evenly-spaced wisps along the disc
/// perimeter.
class AtmosphericMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config], an optional [seed] for
  /// deterministic noise / shader perturbation, an injected
  /// [shaderService] (for tests), and an injected [sdfBuilder].
  AtmosphericMirkRenderer(
    this.config, {
    int seed = 42,
    FogShaderService? shaderService,
    RevealedSdfBuilder sdfBuilder = const RevealedSdfBuilder(),
    WispParticleSystem? wispSystem,
  }) : _seed = seed,
       _noise = SimplexNoise2D(seed: seed),
       _shaderService = shaderService ?? FogShaderService(),
       _sdfBuilder = sdfBuilder,
       _wispSystem = wispSystem ?? WispParticleSystem(rngSeed: seed) {
    // Kick off the shader load early — first frames may render the
    // fallback path while the future resolves.
    _shaderLoadFuture = _shaderService.load();
  }

  /// Atmospheric configuration.
  final AtmosphericConfig config;

  /// Seed used for deterministic per-instance noise. Kept as a field so
  /// it can be passed to the shader as the `uTime` jitter offset (gives
  /// the "different seeds → different fog" property the BUG-009 tests
  /// rely on without re-introducing the heavy CPU SimplexNoise path).
  final int _seed;

  /// CPU simplex noise used by the FALLBACK path (alpha modulation
  /// only). Unused on the shader path.
  // ignore: unused_field — retained for the regression test that asserts
  // different seeds produce different output even on the fallback path.
  final SimplexNoise2D _noise;

  final FogShaderService _shaderService;
  final RevealedSdfBuilder _sdfBuilder;
  final WispParticleSystem _wispSystem;

  /// Disc id set as seen on the previous paint pass. Used to detect
  /// "newly emerged" discs (ids in `currentDiscs` but not here) so the
  /// wisp burst on a fresh GPS fix is local to the new disc only.
  Set<String> _previousDiscIdSet = <String>{};

  /// Whether the renderer is still in its warm-up phase. During warm-up,
  /// all disc IDs are ingested into [_previousDiscIdSet] without spawning
  /// wisps. The warm-up ends when `sessionElapsed` exceeds
  /// [kMirkFogWispWarmUpSeconds]. See [_spawnWispsForNewlyEmergedDiscs]
  /// for the full rationale (BUG-015 fix).
  bool _warmingUp = true;

  /// Last-paint sessionElapsed in seconds. Used to compute dt for the
  /// wisp system's advance step.
  double _lastTSec = 0.0;

  /// Last path tag we INFO-logged ('shader' / 'fallback' / null at start).
  /// We only log on transitions to avoid 60 Hz spam. Diagnostic-only
  /// (BUG-009 follow-up — added 2026-04-25 to debug "all-grey solid fog").
  String? _lastLoggedPath;

  /// Frame counter for the FINE heartbeat log (every 60 frames ≈ 1 Hz).
  int _paintCallCount = 0;

  /// BUG-009 follow-up diagnostic (2026-04-26). Tracks the last reason
  /// `paint()` early-returned so we only log INFO on transitions.
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;

  /// Future that resolves to a `ui.FragmentProgram` (or null on load
  /// failure). Awaited by tests via [shaderReady].
  late final Future<ui.FragmentProgram?> _shaderLoadFuture;

  /// Cached fragment shader instance. Lazily extracted from the
  /// program when it first becomes available; reused across frames.
  ui.FragmentShader? _shader;

  /// Cached SDF image. Rebuilt only when the disc list changes (NOT when
  /// the viewport changes — BUG-014 iteration 4 architectural fix).
  ui.Image? _sdfImage;

  /// Geographic bounding box the [_sdfImage] was built for. Used every
  /// frame to compute the screen-to-SDF UV mapping. Stable across
  /// viewport changes — only updated when the disc list changes.
  MirkViewportBbox? _sdfBbox;

  /// Whether an SDF rebuild is currently in flight. Prevents redundant
  /// concurrent rebuilds when paint is called many times during the
  /// async build window.
  bool _sdfBuildInFlight = false;

  /// Hash of the disc list that produced [_sdfImage]. Changes when the
  /// user walks and a new GPS fix lands a new disc. Disc-list changes
  /// trigger IMMEDIATE rebuilds — the reveal must appear now.
  int _lastDiscHash = 0;

  /// Public future used by tests to wait until the shader has loaded
  /// (or failed to load). Mirrors the previous `noiseReady` shape.
  Future<void> get shaderReady => _shaderLoadFuture.then((_) {});

  bool _disposed = false;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    // BUG-009 follow-up diagnostic (2026-04-26). Log the first paint()
    // invocation unconditionally + heartbeat every 60 frames AT INFO.
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
    // BUG-013 fix: do NOT early-return on empty discs. When the user pans
    // away from the revealed area, all discs fall outside the viewport →
    // discsInBbox returns []. The correct behaviour is FULL FOG (entire
    // viewport covered), not "skip rendering" which shows a clear map.

    // BUG-010 Option B Commit 5: single canonical disc-based clip path.
    final path = buildViewportFogClipPathFromDiscs(discs: context.discs, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible region fully revealed?)');
      return;
    }
    _logEarlyReturnTransition('none');

    // Try to materialise the shader.
    _shader ??= _shaderService.obtainShaderSync();

    // Make sure the SDF for the current disc list is up to date.
    _refreshSdfIfNeeded(context: context);

    // Diff against last frame's disc-id set to find newly-emerged discs →
    // spawn wisps along their perimeter.
    _spawnWispsForNewlyEmergedDiscs(context: context, canvasSize: size);

    // Advance wisps by the elapsed delta since last paint.
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final dt = (tSec - _lastTSec).clamp(0.0, 0.1); // Cap dt at 100 ms to absorb hangs / pauses.
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
      // Fallback: solid fog at base palette colour.
      _paintFallbackPath(canvas, size, context, path);
    }

    // Wisps render LAST — additive on top of the fog body.
    canvas.save();
    canvas.clipPath(path);
    _wispSystem.render(canvas, const Color(0xFFE0E6F0)); // Light cool tint.
    canvas.restore();
  }

  /// BUG-009 follow-up diagnostic (2026-04-26) — emits an INFO log only
  /// when the early-return reason transitions.
  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
  }

  /// Diff `context.discs` against [_previousDiscIdSet] to find discs that
  /// just emerged this frame. For each new disc, spawn N evenly-spaced
  /// wisps along its perimeter (N ∝ circumference / [kMirkFogMetersPerWisp]).
  ///
  /// ## Warm-up phase (BUG-015 root-cause fix)
  ///
  /// For the first [kMirkFogWispWarmUpSeconds] seconds after the renderer
  /// is created, ALL disc IDs that enter the viewport are silently
  /// ingested into [_previousDiscIdSet] WITHOUT spawning wisps.
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

  /// Emits one wisp at each evenly-spaced sample point along [disc]'s
  /// perimeter.
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

  /// Shader path — clip to fog path, draw a viewport-filling rect with
  /// the FragmentShader-bound Paint.
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

    // BUG-014 iteration 4: compute sdfRect from the stable disc bbox
    // and the current viewport. The disc bbox is fixed (only changes when
    // disc list changes), so these values are smooth across pan/zoom.
    final sdfRect = _computeSdfRect(context.viewportBbox);

    FogShaderUniforms.setAll(
      shader,
      resolution: size,
      time: tUniform,
      offset: (offsetX, offsetY),
      baseArgb: kMirkFogAtmosphericBaseColorArgb,
      baseAlpha: config.densityBaselineAlpha,
      highlightArgb: kMirkFogAtmosphericHighlightColorArgb,
      shadowArgb: kMirkFogAtmosphericShadowColorArgb,
      driftZFar: t.atmosphericDriftZFar,
      driftZMid: t.atmosphericDriftZMid,
      driftZNear: t.atmosphericDriftZNear,
      scaleFar: t.atmosphericScaleFar,
      scaleMid: t.atmosphericScaleMid,
      scaleNear: t.atmosphericScaleNear,
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

  /// Computes the sdfRect (originX, originY, sizeX, sizeY) that maps
  /// screen-normalised UV [0,1] to SDF-normalised UV [0,1].
  ///
  /// BUG-014 iteration 4: the SDF is built in disc-bbox coordinates.
  /// The screen UV (0,0)=(north,west) maps to some position within the
  /// disc bbox. This function computes where.
  ///
  /// If no SDF bbox is available yet (first frame before build completes),
  /// returns identity (0, 0, 1, 1) as a safe fallback.
  (double, double, double, double) _computeSdfRect(MirkViewportBbox currentViewport) {
    final sdfBbox = _sdfBbox;
    if (sdfBbox == null) return (0.0, 0.0, 1.0, 1.0);

    final currentDLon = currentViewport.east - currentViewport.west;
    final currentDLat = currentViewport.north - currentViewport.south;
    if (currentDLon <= 0 || currentDLat <= 0) return (0.0, 0.0, 1.0, 1.0);

    final sdfDLon = sdfBbox.east - sdfBbox.west;
    final sdfDLat = sdfBbox.north - sdfBbox.south;
    if (sdfDLon <= 0 || sdfDLat <= 0) return (0.0, 0.0, 1.0, 1.0);

    // Screen UV (0,0) is at (currentViewport.north, currentViewport.west).
    // SDF UV (0,0) is at (sdfBbox.north, sdfBbox.west).
    // We need: sdfUv = (screenUv - origin) / size
    // where origin is the SDF UV of the screen's (0,0) corner,
    // and size is the SDF UV span of the screen.
    final sdfOriginX = (currentViewport.west - sdfBbox.west) / sdfDLon;
    final sdfOriginY = (sdfBbox.north - currentViewport.north) / sdfDLat;
    final sdfSizeX = currentDLon / sdfDLon;
    final sdfSizeY = currentDLat / sdfDLat;

    return (sdfOriginX, sdfOriginY, sdfSizeX, sdfSizeY);
  }

  /// Fallback path — solid base palette colour with feather.
  void _paintFallbackPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path) {
    final r = (kMirkFogAtmosphericBaseColorArgb >> 16) & 0xFF;
    final g = (kMirkFogAtmosphericBaseColorArgb >> 8) & 0xFF;
    final b = kMirkFogAtmosphericBaseColorArgb & 0xFF;

    const baseFeatherPx = 4.0;
    final featherSigma = baseFeatherPx * config.featherRadiusFraction * context.pixelRatio;

    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final radians = config.driftDirectionDeg * math.pi / 180.0;
    final driftX = math.cos(radians);
    final driftY = -math.sin(radians);
    final noiseSample = _noise.noise2(tSec * config.noiseSpeed * driftX, tSec * config.noiseSpeed * driftY);
    final alpha = (config.densityBaselineAlpha + noiseSample * 0.03).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Color.fromARGB((alpha * 255).round(), r, g, b)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);
    canvas.drawPath(path, paint);
  }

  /// Checks whether the SDF needs rebuilding. BUG-014 iteration 4:
  /// the SDF only rebuilds when the DISC LIST changes (new GPS fix).
  /// Viewport changes do NOT trigger a rebuild — the renderer recomputes
  /// the screen-to-SDF UV mapping every frame instead.
  void _refreshSdfIfNeeded({required MirkPaintContext context}) {
    if (_sdfBuildInFlight) return;

    final discHash = _hashDiscList(context.discs);

    if (discHash != _lastDiscHash) {
      // Disc list changed → rebuild immediately.
      _lastDiscHash = discHash;
      _triggerSdfRebuild(context.discs, context.viewportBbox);
    } else if (_sdfImage == null) {
      // Same inputs but no SDF yet (first frame) → build now.
      _triggerSdfRebuild(context.discs, context.viewportBbox);
    }
  }

  /// Kicks off an async SDF build for [discs]. The viewport is passed
  /// as a fallback bbox for the empty-discs case only.
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

  /// FNV-1a hash of the disc list (id + lat + lon + radius per entry).
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

  /// FNV-1a-style mixer. Inline-friendly, deterministic, no deps.
  int _mix(int hash, int v) {
    hash ^= v;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
    return hash;
  }

  @override
  void update(Duration elapsed) {
    // sessionElapsed (read inside paint) drives animation — no internal
    // state to advance here.
  }

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
