// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui show FragmentProgram, FragmentShader, Image, ImageShader, TileMode;
import 'dart:ui' show BlendMode, Canvas, Color, ColorFilter, FilterQuality, Offset, Paint, PaintingStyle, Rect, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import 'animation_helpers.dart';
import 'fog_edge_feather.dart';
import 'noise/noise_texture.dart';
import 'noise/simplex_noise_2d.dart';
import 'sdf/sdf_cache.dart';
import 'sdf_rebuild_logger.dart';
import 'shader/fog_platform_corrections.dart';
import 'shader/fog_shader_renderer.dart';
import 'shader/fog_shader_service.dart';
import 'wisp/wisp_particle.dart';
import 'wisp/wisp_particle_system.dart';
import 'wisp/wisp_transform_logger.dart';

final Logger _log = Logger('infrastructure.mirk.heavenly_clouds');

/// `uTime` offset per seed unit — arbitrary but coprime with typical drift
/// speeds so two seeds never alias onto the same animation phase.
const double _kSeedTimeJitter = 0.137;

/// Wisp tint (palette constant kept as an int in `constants.dart`).
const Color _kWispTint = Color(kMirkWispTintHeavenlyArgb);

/// Base feather width in logical pixels before the fraction / pixel-ratio scaling.
const double _kBaseFeatherPx = 4.0;

/// Heavenly fallback feather fraction — a slightly larger feather than
/// atmospheric: clouds are softer-edged than thick fog. Matches the
/// pre-Commit-5 semantics (was scaled to the bitmap cell size; now to the
/// fixed 4 px base so the visual feel is preserved without a cell dependency).
const double _kFallbackFeatherFraction = 0.15;

/// Amplitude of the fallback path's per-frame alpha jitter (±10 %).
const double _kFallbackAlphaJitter = 0.10;

/// White at the CPU noise overlay opacity — applied as a `modulate` colour
/// filter on the tile shader so the overlay strength does not depend on how
/// a backend combines `Paint.color` with a shader.
final Color _kNoiseOverlayTint = const Color(0xFFFFFFFF).withValues(alpha: kMirkHeavenlyCloudsCpuNoiseOverlayAlpha);

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
///
/// ## Phase 09.1 (plan 09.1-06): the `FogLayer` owns the clip
///
/// [paint] assumes the clipped identity frame the `FogLayer` provides — ONE
/// `clipPath(rect − discs)` per frame, shared by the four builtin variants.
/// The renderer never clips: the shader rect, the fallback body and the
/// wisps all paint `Offset.zero & size` and the layer's clip cuts the holes.
///
/// ## CPU fallback noise anchored to the world (Phase 09.1-06)
///
/// While the shader / SDF are unavailable the fallback body carries a
/// pre-rasterised simplex tile ([NoiseTexture]) drawn through an
/// `ImageShader` whose matrix is the CPU twin of the shader's
/// `worldPx / (kNoiseTilePx × uZoomScale)` sampling: one tile spans
/// `kMirkFogNoiseTilePx × zoomScale` screen px and is translated by the RAW
/// camera `pixelOrigin` ([rawPixelOriginOf] — the CPU does not suffer the
/// FOG-23 GPU codegen defect) plus the temporal drift. A pan of N px moves
/// the clouds N px on screen; a ×2 zoom doubles their size.
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
    WispTransformLogger? wispTransformLogger,
  }) : _seed = seed,
       _noise = SimplexNoise2D(seed: seed),
       _shaderService = shaderService ?? FogShaderService(),
       _shaderRenderer = shaderRenderer,
       _sdfCache = sdfCache ?? SdfCache(rebuildLogger: SdfRebuildLogger()..start()),
       _wispSystem = wispSystem ?? WispParticleSystem(rngSeed: seed),
       _wispTransformLogger = wispTransformLogger ?? (WispTransformLogger()..start()) {
    _shaderLoadFuture = _shaderService.load();
    _noiseTileFuture = _loadNoiseTile();
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

  /// Verbose-only per-paint wisp diagnostic (POC WISP-05); fed once per paint by [_renderWisps],
  /// stopped on dispose.
  final WispTransformLogger _wispTransformLogger;

  /// Disc ids already forwarded to [_wispSystem] — append-only pre-filter for
  /// [_spawnWispsForNewlyEmergedDiscs].
  final Set<String> _seenDiscIdSet = <String>{};

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

  /// Resolves once the CPU noise tile has been rasterised and published (or
  /// its build failed — the fallback then stays solid). Tests await it before
  /// painting the fallback path.
  Future<void> get noiseReady => _noiseTileFuture;

  late final Future<void> _noiseTileFuture;

  /// Tileable simplex tile for the fallback path — owned here, disposed in [dispose].
  ui.Image? _noiseTile;

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
    // viewport covered), not "skip rendering" which shows a clear map. The
    // FogLayer's clip is then the whole viewport rect.
    _logEarlyReturnTransition('none');
    _shader ??= _shaderService.obtainShaderSync();
    _refreshSdfIfNeeded(context);

    // Spawn wisps for newly-emerged discs + advance the system.
    _spawnWispsForNewlyEmergedDiscs(context);

    final ui.Image? sdf = _currentSdfImage;
    // Shader path needs a resolved SDF; the seam reports `false` when the
    // shader itself is unavailable (still loading / load failed) → CPU
    // fallback: solid fog at base palette colour, no noise, no animation.
    final bool painted = sdf != null && _paintShaderPath(canvas, size, context, sdf);
    if (!painted) {
      _paintFallbackPath(canvas, size, context);
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

    // Wisps render LAST — additive over the fog body, after the shader rect, in the FogLayer's
    // clipped identity frame (POC order).
    _renderWisps(canvas, context);
  }

  /// BUG-009 follow-up diagnostic (2026-04-26). Duplicated from the
  /// atmospheric renderer to keep the parallel structure between the
  /// two builtins (each has its own logger and its own state field).
  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
  }

  /// Diffs `context.discs` against [_seenDiscIdSet] and forwards each newly seen disc to
  /// [WispParticleSystem.spawnAtNewDisc]. The set is only a cheap pre-filter: idempotence per
  /// disc id AND the BUG-015 warm-up (`kMirkFogWispWarmUpSeconds` from the SYSTEM's
  /// construction) live in the system. Append-only, so discs that leave the viewport and come
  /// back are not "new" (BUG-015 A).
  ///
  /// No renderer-side warm-up flag and no reset hook (decision 09.1-05): a session start /
  /// resume or a style change rebuilds `activeMirkRendererProvider`, which calls
  /// `factory.create(config)` → a NEW renderer → a new system with a fresh stopwatch, while
  /// `ref.onDispose` disposes the previous one.
  void _spawnWispsForNewlyEmergedDiscs(MirkPaintContext context) {
    for (final RevealDisc disc in context.discs) {
      if (!_seenDiscIdSet.add(disc.id)) continue;
      _wispSystem.spawnAtNewDisc(discId: disc.id, disc: disc);
    }
  }

  /// Advances the wisp system by the `sessionElapsed` delta and draws every wisp as an additive
  /// soft circle at `context.projectToScreen(wisp.position)` — the same camera snapshot the fog
  /// rect used (FOG-07), in the FogLayer's clipped identity frame, AFTER the shader rect. Port of
  /// the POC `_FogPainter._renderWisps`. Radius lerps birth → death px with age, alpha follows
  /// `1 - age²` × peak × tint alpha. Emits ONE [WispTransformLogger.recordPaint] per paint
  /// (never per wisp); nothing at all when no wisp is alive.
  void _renderWisps(Canvas canvas, MirkPaintContext context) {
    _wispSystem.advanceFromElapsed(context.sessionElapsed);
    if (_wispSystem.activeCount == 0) return;

    // Paint hoisted out of the loop; additive blend so overlapping wisps brighten without
    // saturating the fog body.
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;

    double latMin = double.infinity;
    double latMax = double.negativeInfinity;
    double lonMin = double.infinity;
    double lonMax = double.negativeInfinity;
    double screenXMin = double.infinity;
    double screenXMax = double.negativeInfinity;
    double screenYMin = double.infinity;
    double screenYMax = double.negativeInfinity;
    double ageSum = 0.0;

    for (final WispParticle wisp in _wispSystem.wisps) {
      final double age = wisp.age;
      final double radius = kMirkFogWispBirthRadiusPx + (kMirkFogWispDeathRadiusPx - kMirkFogWispBirthRadiusPx) * age;
      final double alphaFactor = (1.0 - age * age).clamp(0.0, 1.0);
      paint.color = _kWispTint.withValues(alpha: alphaFactor * kMirkFogWispPeakAlpha * _kWispTint.a);
      final Offset screen = context.projectToScreen(wisp.position);
      canvas.drawCircle(screen, radius, paint);

      latMin = math.min(latMin, wisp.position.latitude);
      latMax = math.max(latMax, wisp.position.latitude);
      lonMin = math.min(lonMin, wisp.position.longitude);
      lonMax = math.max(lonMax, wisp.position.longitude);
      screenXMin = math.min(screenXMin, screen.dx);
      screenXMax = math.max(screenXMax, screen.dx);
      screenYMin = math.min(screenYMin, screen.dy);
      screenYMax = math.max(screenYMax, screen.dy);
      ageSum += age;
    }

    _wispTransformLogger.recordPaint(
      activeCount: _wispSystem.activeCount,
      meanAge: ageSum / _wispSystem.activeCount,
      latBounds: (latMin, latMax),
      lonBounds: (lonMin, lonMax),
      screenXBounds: (screenXMin, screenXMax),
      screenYBounds: (screenYMin, screenYMax),
      spawnRatePerSecond: _wispSystem.spawnRatePerSecondAndReset(),
    );
  }

  /// Shader path — delegates uniform population + the viewport-filling
  /// `drawRect` to the injected [FogShaderRenderer], in the FogLayer's
  /// clipped identity frame (no clip here). Returns `false` when nothing was
  /// drawn (shader still loading / failed) so [paint] falls back to the CPU
  /// path.
  ///
  /// Reads every runtime-tunable parameter from [MirkRuntimeTunables.instance]
  /// (not the const literal) so the in-app tuner scrubs each value live;
  /// production builds with the tuner closed see byte-identical output.
  /// `pixelOrigin` / `zoomScale` / `sdfRect` come from the context verbatim —
  /// the FogLayer already applied the platform corrections (FOG-21 / FOG-23),
  /// and there is no viewport → SDF remapping any more (BUG-014 closed by
  /// construction, not by a rect).
  bool _paintShaderPath(Canvas canvas, Size size, MirkPaintContext context, ui.Image sdf) {
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
    return _shaderRenderer.render(
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
  }

  /// Rasterises the CPU noise tile off the UI thread and publishes it for the
  /// fallback path. A tile arriving after [dispose] is released immediately.
  /// A build failure is an external error (isolate spawn / image decode):
  /// logged, the fallback simply stays solid.
  Future<void> _loadNoiseTile() async {
    final double frequency = config.noiseScale * kMirkHeavenlyCloudsCpuNoiseCyclesPerTilePerUnitScale;
    final ui.Image tile;
    try {
      tile = await NoiseTexture.build(seed: _seed, frequency: frequency);
    } on Exception catch (e, st) {
      _log.severe('_loadNoiseTile: noise tile build FAILED — fallback path stays solid', e, st);
      return;
    }
    if (_disposed) {
      tile.dispose();
      return;
    }
    _noiseTile = tile;
  }

  /// Fallback path — base palette colour over the whole frame, the
  /// world-anchored noise tile on top, then the shared edge feather; alpha
  /// jittered per frame by the CPU noise so the clouds still "breathe" while
  /// the shader / SDF are unavailable.
  void _paintFallbackPath(Canvas canvas, Size size, MirkPaintContext context) {
    final r = (kMirkFogHeavenlyBaseColorArgb >> 16) & 0xFF;
    final g = (kMirkFogHeavenlyBaseColorArgb >> 8) & 0xFF;
    final b = kMirkFogHeavenlyBaseColorArgb & 0xFF;
    final featherSigma = _kBaseFeatherPx * _kFallbackFeatherFraction * context.pixelRatio;
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final radians = config.driftDirectionDeg * math.pi / 180.0;
    final driftX = math.cos(radians);
    final driftY = -math.sin(radians);
    final noiseSample = _noise.noise2(tSec * config.noiseSpeed * driftX, tSec * config.noiseSpeed * driftY);
    final alpha = (config.baselineAlpha + noiseSample * _kFallbackAlphaJitter).clamp(0.0, 1.0);
    final Paint bodyPaint = Paint()
      ..color = Color.fromARGB((alpha * 255).round(), r, g, b)
      ..style = PaintingStyle.fill;
    paintFogBodyWithFeatheredEdges(
      canvas: canvas,
      size: size,
      context: context,
      featherSigma: featherSigma,
      paintBody: (Canvas canvas, Rect viewport) {
        canvas.drawRect(viewport, bodyPaint);
        _paintWorldAnchoredNoise(canvas, viewport, context, tSec: tSec);
      },
    );
  }

  /// Draws the CPU noise tile over the fallback body, anchored to WORLD
  /// pixels (FOG-17 / FOG-19 on the CPU): one tile spans
  /// `kMirkFogNoiseTilePx × zoomScale` screen px; the texture is translated by
  /// the raw camera `pixelOrigin` plus the temporal drift
  /// (`noiseSpeed` tiles per second along `driftDirectionDeg`), modulo the
  /// period so the float matrix never carries a ~1e6 offset (FOG-18 is a
  /// shader concern; the CPU tile is periodic by construction).
  /// `BlendMode.srcATop` modulates the fog colour without touching its alpha
  /// and never paints outside existing fog. No-op until the tile is ready.
  void _paintWorldAnchoredNoise(Canvas canvas, Rect viewport, MirkPaintContext context, {required double tSec}) {
    final ui.Image? tile = _noiseTile;
    if (tile == null) return;
    final ({double x, double y}) raw = rawPixelOriginOf(context);
    final double period = kMirkFogNoiseTilePx * context.zoomScale;
    final double radians = config.driftDirectionDeg * math.pi / 180.0;
    final double driftTiles = tSec * config.noiseSpeed;
    final double driftX = driftTiles * math.cos(radians) * period;
    final double driftY = -driftTiles * math.sin(radians) * period;
    final double texelScale = period / NoiseTexture.kSize;
    final double translateX = -((raw.x + driftX) % period);
    final double translateY = -((raw.y + driftY) % period);
    final Paint noisePaint = Paint()
      ..shader = ui.ImageShader(
        tile,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        _textureToScreenMatrix(scale: texelScale, translateX: translateX, translateY: translateY),
        filterQuality: FilterQuality.low,
      )
      ..colorFilter = ColorFilter.mode(_kNoiseOverlayTint, BlendMode.modulate)
      ..blendMode = BlendMode.srcATop;
    canvas.drawRect(viewport, noisePaint);
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
    _seenDiscIdSet.clear();
    _wispTransformLogger.stop();
    _noiseTile?.dispose();
    _noiseTile = null;
  }
}

/// Column-major 4×4 matrix mapping texture pixels to screen pixels for an
/// [ui.ImageShader]: `scale` first, then `translate` (no `vector_math` needed).
Float64List _textureToScreenMatrix({required double scale, required double translateX, required double translateY}) {
  const int scaleXIndex = 0;
  const int scaleYIndex = 5;
  const int scaleZIndex = 10;
  const int translateXIndex = 12;
  const int translateYIndex = 13;
  const int wIndex = 15;
  final Float64List matrix = Float64List(16);
  matrix[scaleXIndex] = scale;
  matrix[scaleYIndex] = scale;
  matrix[scaleZIndex] = 1.0;
  matrix[translateXIndex] = translateX;
  matrix[translateYIndex] = translateY;
  matrix[wIndex] = 1.0;
  return matrix;
}

/// Cheap content signature of a disc list — ids + geometry. Two lists holding the same discs in
/// the same order share a signature even when the provider handed out a fresh `List` instance
/// (it does, on every query), which is what keeps the viewport-only debounce effective.
int _discListSignature(List<RevealDisc> discs) => Object.hashAll(discs.map((RevealDisc d) => Object.hash(d.id, d.lat, d.lon, d.radiusMeters)));
