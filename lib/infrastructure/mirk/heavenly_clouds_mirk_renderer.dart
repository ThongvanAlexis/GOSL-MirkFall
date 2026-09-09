// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' as ui show FragmentProgram, FragmentShader, Image, Path;
import 'dart:ui' show BlurStyle, Canvas, Color, MaskFilter, Offset, Paint, PaintingStyle, Size;

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
import 'sdf/sdf_cache.dart';
import 'sdf_rebuild_logger.dart';
import 'shader/fog_shader_renderer.dart';
import 'shader/fog_shader_service.dart';
import 'tile_cell_iteration.dart';
import 'wisp/wisp_particle_system.dart';

final Logger _log = Logger('infrastructure.mirk.heavenly_clouds');

/// `uTime` offset per seed unit — arbitrary but coprime with typical drift
/// speeds so two seeds never alias onto the same animation phase.
const double _kSeedTimeJitter = 0.137;

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
/// (shader path + fallback path, `SdfCache` behind the viewport
/// debounce, per-disc wisp emergence). The structure of this class
/// is parallel — only the uniform values + wisp tint differ.
class HeavenlyCloudsMirkRenderer implements MirkRenderer {
  /// Constructs the renderer with [config], an optional [seed] for
  /// per-instance shader perturbation, an injected [shaderService],
  /// and an injected [sdfCache].
  HeavenlyCloudsMirkRenderer(
    this.config, {
    int seed = 91,
    FogShaderService? shaderService,
    FogShaderRenderer shaderRenderer = const FragmentShaderFogRenderer(),
    SdfCache? sdfCache,
    WispParticleSystem? wispSystem,
  }) : _seed = seed,
       _noise = SimplexNoise2D(seed: seed),
       _shaderService = shaderService ?? FogShaderService(),
       _shaderRenderer = shaderRenderer,
       _sdfCache = sdfCache ?? SdfCache(rebuildLogger: SdfRebuildLogger()..start()),
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

  /// GPU seam (Phase 09.1): populates the 42 uniform slots and draws the
  /// viewport rect. `RecordingFogShaderRenderer` in tests.
  final FogShaderRenderer _shaderRenderer;

  /// Quantised-key SDF cache (POC FOG-03 / PERF-08). Owns every image it hands out; the renderer
  /// only keeps [_currentSdfImage] as a borrowed handle. Default: production builder + a started
  /// verbose-only [SdfRebuildLogger] (stopped by the cache on dispose).
  final SdfCache _sdfCache;
  final WispParticleSystem _wispSystem;

  /// Disc id set as seen on the previous paint pass — see
  /// [`AtmosphericMirkRenderer`] for the BUG-010 Option B Commit 5
  /// emergence-diff rationale + warm-up guard.
  Set<String> _previousDiscIdSet = <String>{};

  /// Whether the renderer is still in its warm-up phase. See
  /// [AtmosphericMirkRenderer._warmingUp] for the full BUG-015 rationale.
  bool _warmingUp = true;
  double _lastTSec = 0.0;

  /// BUG-009 follow-up diagnostic: last path tag we INFO-logged
  /// ('shader' / 'fallback' / null at start). We only log on transitions
  /// to avoid 60 Hz spam.
  String? _lastLoggedPath;
  int _paintCallCount = 0;

  /// BUG-009 follow-up diagnostic (2026-04-26). Mirrors the atmospheric
  /// renderer — tracks the last `paint()` early-return reason so we can
  /// surface silent bailouts (every gate logs INFO on transition only).
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;

  late final Future<ui.FragmentProgram?> _shaderLoadFuture;
  ui.FragmentShader? _shader;

  /// Latest SDF handed out by [_sdfCache] — a BORROWED handle (the cache owns and disposes it).
  /// Stays in use while a rebuild is in flight (stale but stable: no BUG-012 strobe) and is never
  /// null again once the first build resolved.
  ui.Image? _currentSdfImage;

  /// The single in-flight [SdfCache.getOrBuild]; `null` when idle. Paints that need a rebuild
  /// while it runs set [_rebuildRequested] instead of starting a second build.
  Future<void>? _pendingSdfBuild;
  bool _rebuildRequested = false;
  List<RevealDisc>? _requestedDiscs;
  MirkViewportBbox? _requestedViewport;

  /// Signature (ids + geometry) of the disc list the last scheduled build used. A change means a
  /// GPS fix landed (or discs entered / left the padded query) → rebuild IMMEDIATELY.
  int? _lastDiscSignature;

  /// Viewport of the last scheduled build. A viewport-only change is debounced (BUG-012).
  MirkViewportBbox? _lastViewport;

  /// Debounce timer for viewport-only SDF rebuilds (BUG-012). Re-armed on every viewport-only
  /// paint; when it fires, the LATEST viewport goes to the cache (whose quantised key then
  /// decides whether anything is actually rebuilt).
  Timer? _viewportDebounceTimer;

  /// Public future used by tests to wait until the shader has loaded
  /// (or failed to load).
  Future<void> get shaderReady => _shaderLoadFuture.then((_) {});

  bool _disposed = false;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    // BUG-009 follow-up diagnostic (2026-04-26) — mirror of the
    // atmospheric renderer's instrumentation. See that file for the
    // throttling rationale.
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
    // buildViewportFogClipPathFromDiscs handles empty discs correctly by
    // returning the viewport rect (= everything is fog, nothing revealed).
    final path = buildViewportFogClipPathFromDiscs(discs: context.discs, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible region fully revealed?)');
      return;
    }
    _logEarlyReturnTransition('none');
    _shader ??= _shaderService.obtainShaderSync();
    _refreshSdfIfNeeded(context);

    // Spawn wisps for newly-emerged discs + advance the system.
    _spawnWispsForNewlyEmergedDiscs(context: context, canvasSize: size);
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final dt = (tSec - _lastTSec).clamp(0.0, 0.1);
    _wispSystem.advance(dt);
    _lastTSec = tSec;

    final ui.Image? sdf = _currentSdfImage;
    // Shader path needs a resolved SDF; the seam reports `false` when the
    // shader itself is unavailable (still loading / load failed) → CPU
    // fallback: solid fog at base palette colour, no noise, no animation.
    final bool painted = sdf != null && _paintShaderPath(canvas, size, context, path, sdf);
    if (!painted) {
      _paintFallbackPath(canvas, size, context, path);
    }
    final pathThisFrame = painted ? 'shader' : 'fallback';
    if (pathThisFrame != _lastLoggedPath) {
      _log.info(
        'paint(): path transition ${_lastLoggedPath ?? "(initial)"} → $pathThisFrame · shader=${_shader != null} sdf=${sdf != null} sdfBuildInFlight=${_pendingSdfBuild != null} discs=${context.discs.length}',
      );
      _lastLoggedPath = pathThisFrame;
    } else if (_paintCallCount % 60 == 0) {
      // Heartbeat at ~1 Hz when in steady state — confirms paint() is
      // still being called, useful when investigating "no fog visible".
      _log.info(
        'paint(): post-paint heartbeat path=$pathThisFrame · frame=$_paintCallCount discs=${context.discs.length} sessionElapsed=${context.sessionElapsed.inMilliseconds}ms',
      );
    }
    _paintCallCount++;

    // Wisps render last — additive over the fog body. Heavenly uses a
    // warmer wisp tint to read as "sunlit cloud puff".
    canvas.save();
    canvas.clipPath(path);
    _wispSystem.render(canvas, const Color(0xFFF8F0E2));
    canvas.restore();
  }

  /// BUG-009 follow-up diagnostic (2026-04-26). Duplicated from the
  /// atmospheric renderer to keep the parallel structure between the
  /// two builtins (each has its own logger and its own state field).
  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
  }

  /// Same logic as the atmospheric renderer — diff disc id set to find
  /// newly-emerged discs and spawn wisps along their perimeters.
  /// Duplicated here because each renderer owns its own
  /// [WispParticleSystem] and previous-id set; pulling into a shared
  /// helper would impose a state-management coupling that doesn't
  /// simplify the call sites.
  ///
  /// BUG-015 fix: see `AtmosphericMirkRenderer._spawnWispsForNewlyEmergedDiscs`
  /// for the full rationale. Time-based warm-up absorbs the viewport
  /// animation's disc scroll-in without spawning.
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

  /// Shader path — clips to the fog path and delegates uniform population +
  /// the viewport-filling `drawRect` to the injected [FogShaderRenderer].
  /// Returns `false` when nothing was drawn (shader still loading / failed)
  /// so [paint] falls back to the CPU path.
  ///
  /// Reads every runtime-tunable parameter from [MirkRuntimeTunables.instance]
  /// (not the const literal) so the in-app tuner scrubs each value live;
  /// production builds with the tuner closed see byte-identical output.
  /// `pixelOrigin` / `zoomScale` / `sdfRect` come from the context verbatim —
  /// the FogLayer already applied the platform corrections (FOG-21 / FOG-23),
  /// and there is no viewport → SDF remapping any more (BUG-014 closed by
  /// construction, not by a rect).
  bool _paintShaderPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path, ui.Image sdf) {
    final tSec = context.sessionElapsed.inMicroseconds / Duration.microsecondsPerSecond;
    // Per-instance perturbation: a seed-dependent uTime offset so
    // different-seed renderers produce different shader output.
    final tUniform = tSec + _seed * _kSeedTimeJitter;
    final t = MirkRuntimeTunables.instance;
    // Effective curlScale: triangle-wave animation by default (UAT
    // 2026-04-26 — slowly varying curlScale gives the fog a "really
    // alive" volumetric feel). Falls back to the static t.curlScale
    // when the dev tuner toggles the animation off.
    final double effectiveCurlScale = t.curlScaleAnimationEnabled
        ? triangleWave(tSec: tSec, period: t.curlScaleAnimationPeriodSec, minV: t.curlScaleAnimationMin, maxV: t.curlScaleAnimationMax)
        : t.curlScale;
    // Heavenly palette (Hebridean dawn) + faster drift / bigger puffs; opacity
    // weights shared with atmospheric so the parallax depth signature matches.
    final Map<String, double> tunables = <String, double>{
      FogShaderTunableKey.driftZFar: t.heavenlyDriftZFar,
      FogShaderTunableKey.driftZMid: t.heavenlyDriftZMid,
      FogShaderTunableKey.driftZNear: t.heavenlyDriftZNear,
      FogShaderTunableKey.scaleFar: t.heavenlyScaleFar,
      FogShaderTunableKey.scaleMid: t.heavenlyScaleMid,
      FogShaderTunableKey.scaleNear: t.heavenlyScaleNear,
      FogShaderTunableKey.opacityFar: t.opacityFar,
      FogShaderTunableKey.opacityMid: t.opacityMid,
      FogShaderTunableKey.opacityNear: t.opacityNear,
      FogShaderTunableKey.curlAmplitude: t.curlAmplitude,
      FogShaderTunableKey.curlScale: effectiveCurlScale,
      FogShaderTunableKey.lightDirRadians: t.lightDirRadians,
      FogShaderTunableKey.lightOffset: t.lightOffset,
      FogShaderTunableKey.lightStrength: t.lightStrength,
      FogShaderTunableKey.hueNoiseScale: t.hueNoiseScale,
      FogShaderTunableKey.hueStrength: t.hueStrength,
      FogShaderTunableKey.boundarySharpDistance: t.boundarySharpDistance,
      FogShaderTunableKey.boundaryBleedDistance: t.boundaryBleedDistance,
      FogShaderTunableKey.boundaryEdgeBand: t.boundaryEdgeBand,
      FogShaderTunableKey.boundaryDensityBoost: t.boundaryDensityBoost,
    };
    canvas.save();
    canvas.clipPath(path);
    final bool painted = _shaderRenderer.render(
      canvas: canvas,
      shader: _shader,
      size: size,
      timeSeconds: tUniform,
      pixelOrigin: context.pixelOrigin,
      zoomScale: context.zoomScale,
      sdfRect: context.sdfRect,
      sdfImage: sdf,
      baseArgb: kMirkFogHeavenlyBaseColorArgb,
      baseAlpha: config.baselineAlpha,
      highlightArgb: kMirkFogHeavenlyHighlightColorArgb,
      shadowArgb: kMirkFogHeavenlyShadowColorArgb,
      tunables: tunables,
    );
    canvas.restore();
    return painted;
  }

  void _paintFallbackPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path) {
    final r = (kMirkFogHeavenlyBaseColorArgb >> 16) & 0xFF;
    final g = (kMirkFogHeavenlyBaseColorArgb >> 8) & 0xFF;
    final b = kMirkFogHeavenlyBaseColorArgb & 0xFF;
    // Heavenly fallback uses a slightly larger feather than atmospheric
    // — clouds are softer-edged than thick fog. 0.15 multiplier matches
    // pre-Commit-5 semantics (was scaled to bitmap cell size; now to a
    // fixed 4 px base so the visual feel is preserved without a
    // bitmap-cell dependency).
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

  /// Decides whether the SDF must be (re)built for this paint.
  ///
  /// BUG-012: the disc list and the viewport are compared SEPARATELY. A disc-list change (GPS
  /// fix landed, discs entered / left the padded query) rebuilds immediately — the reveal must
  /// appear now. A viewport-only change (pan / zoom) re-arms a [kMirkFogSdfViewportDebounceMs]
  /// timer; the current (stale) SDF stays on screen meanwhile, which is visually stable, and the
  /// LATEST viewport is what reaches the cache when the timer fires. The cache's quantised key
  /// (RESEARCH §7, Pitfall 5) then absorbs whatever redundancy the debounce let through.
  void _refreshSdfIfNeeded(MirkPaintContext context) {
    final List<RevealDisc> discs = context.discs;
    final MirkViewportBbox viewport = context.viewportBbox;
    final int discSignature = _discListSignature(discs);
    final bool discsChanged = discSignature != _lastDiscSignature;
    final bool viewportChanged = viewport != _lastViewport;
    if (discsChanged) {
      _lastDiscSignature = discSignature;
      _lastViewport = viewport;
      _viewportDebounceTimer?.cancel();
      _viewportDebounceTimer = null;
      _scheduleSdfBuild(discs, viewport);
      return;
    }
    if (!viewportChanged) return;
    _lastViewport = viewport;
    _viewportDebounceTimer?.cancel();
    _viewportDebounceTimer = Timer(const Duration(milliseconds: kMirkFogSdfViewportDebounceMs), () {
      _viewportDebounceTimer = null;
      if (_disposed) return;
      _scheduleSdfBuild(discs, viewport);
    });
  }

  /// Starts ONE [SdfCache.getOrBuild] at a time. A request arriving while a build is in flight
  /// is coalesced into a single follow-up build with the most recent inputs.
  void _scheduleSdfBuild(List<RevealDisc> discs, MirkViewportBbox viewport) {
    if (_pendingSdfBuild != null) {
      _rebuildRequested = true;
      _requestedDiscs = discs;
      _requestedViewport = viewport;
      return;
    }
    _pendingSdfBuild = _runSdfBuild(discs, viewport);
  }

  /// Awaits the cache and publishes the image into [_currentSdfImage]. Build failures are
  /// external errors (image decode, GPU upload): logged SEVERE, the fallback path stays active.
  /// Programming errors propagate to the top-level handler.
  Future<void> _runSdfBuild(List<RevealDisc> discs, MirkViewportBbox viewport) async {
    try {
      final ui.Image image = await _sdfCache.getOrBuild(discs: discs, viewport: viewport);
      if (_disposed) return;
      _currentSdfImage = image;
    } on StateError catch (e) {
      // Expected when dispose() interrupted the build — the cache already released the image.
      _log.fine('_runSdfBuild: build discarded (${e.message})');
    } on Exception catch (e, st) {
      _log.severe('_runSdfBuild: SDF build FAILED — fallback path stays active', e, st);
    } finally {
      _pendingSdfBuild = null;
      _runCoalescedSdfBuildIfRequested();
    }
  }

  void _runCoalescedSdfBuildIfRequested() {
    if (!_rebuildRequested || _disposed) return;
    _rebuildRequested = false;
    final List<RevealDisc>? discs = _requestedDiscs;
    final MirkViewportBbox? viewport = _requestedViewport;
    _requestedDiscs = null;
    _requestedViewport = null;
    if (discs == null || viewport == null) return;
    _scheduleSdfBuild(discs, viewport);
  }

  @override
  void update(Duration elapsed) {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _viewportDebounceTimer?.cancel();
    _viewportDebounceTimer = null;
    _rebuildRequested = false;
    _requestedDiscs = null;
    _requestedViewport = null;
    _shader?.dispose();
    _shader = null;
    // The cache owns the image — dropping the borrowed handle is enough; the cache also stops
    // its rebuild logger.
    _currentSdfImage = null;
    _sdfCache.dispose();
    _wispSystem.clear();
    _previousDiscIdSet = <String>{};
    _warmingUp = true;
  }
}

/// Cheap content signature of a disc list — ids + geometry. Two lists holding the same discs in
/// the same order share a signature even when the provider handed out a fresh `List` instance
/// (it does, on every query), which is what keeps the viewport-only debounce effective.
int _discListSignature(List<RevealDisc> discs) => Object.hashAll(discs.map((RevealDisc d) => Object.hash(d.id, d.lat, d.lon, d.radiusMeters)));
