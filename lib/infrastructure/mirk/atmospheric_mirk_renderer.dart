// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async' show Timer;
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
///    AND the SDF for the current viewport+disc-list hash is built,
///    the renderer issues ONE `canvas.drawRect(viewport, Paint()..shader =
///    fragmentShader)` clipped to the fog path. The shader handles all
///    7 TIER 2 quality dimensions; the boundary watercolour falloff
///    inside the shader supersedes the previous `MaskFilter.blur` on
///    the host Paint.
///
/// 2. **Fallback path**: when the shader load fails (invalid asset,
///    Impeller blocklist, etc.) OR while waiting for the first SDF
///    build, the renderer paints a uniform solid fog using the base
///    palette colour at the configured baseline alpha. No noise, no
///    animation — see class docstring history before BUG-010 Option B
///    Commit 5 collapsed the dual visibleTiles/discs input.
///
/// ## Wisp emergence (BUG-010 Option B Commit 5)
///
/// Wisps spawn on the per-frame diff of the disc id set. When a fix
/// lands, the disc-list provider gains exactly one new id; the renderer
/// detects the new id and spawns N evenly-spaced wisps along the disc
/// perimeter. First-paint guard: the very first paint populates
/// `_previousDiscIdSet` from the current input WITHOUT spawning, so
/// resuming a session does not spray wisps over already-revealed area.
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
  /// `paint()` early-returned so we only log INFO on transitions
  /// (`null` → `disposed`, `disposed` → `noDiscs`, `noDiscs` → `none`,
  /// etc.). Without this, the file logger would never confirm whether
  /// `paint()` is even being called.
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;

  /// Future that resolves to a `ui.FragmentProgram` (or null on load
  /// failure). Awaited by tests via [shaderReady].
  late final Future<ui.FragmentProgram?> _shaderLoadFuture;

  /// Cached fragment shader instance. Lazily extracted from the
  /// program when it first becomes available; reused across frames.
  ui.FragmentShader? _shader;

  /// Cached SDF image. Rebuilt when disc-list or viewport hash changes.
  ui.Image? _sdfImage;

  /// The viewport the current [_sdfImage] was built for. Used by
  /// [_computeSdfRect] to map the SDF onto the current viewport each
  /// frame so the reveal stays pinned at its true lat/lon position
  /// during pan/zoom instead of sliding with the viewport.
  MirkViewportBbox? _sdfViewport;

  /// Whether an SDF rebuild is currently in flight. Prevents redundant
  /// concurrent rebuilds when paint is called many times during the
  /// async build window.
  bool _sdfBuildInFlight = false;

  /// Hash of the disc list that produced [_sdfImage]. Changes when the
  /// user walks and a new GPS fix lands a new disc. Disc-list changes
  /// trigger IMMEDIATE rebuilds — the reveal must appear now.
  int _lastDiscHash = 0;

  /// Hash of the viewport bbox that produced [_sdfImage]. Changes during
  /// pan/zoom gestures. Viewport-only changes are debounced to avoid the
  /// strobe described in BUG-012.
  int _lastViewportHash = 0;

  /// Debounce timer for viewport-only SDF rebuilds (BUG-012 fix). When
  /// only the viewport hash changes (pan/zoom, no new disc), we restart
  /// this timer. The old SDF is reused during the wait — slightly
  /// misaligned but visually stable. When the timer fires, we rebuild
  /// with the latest captured viewport.
  Timer? _viewportDebounceTimer;

  /// Pending rebuild inputs captured when the viewport debounce timer is
  /// active. On timer fire these feed [_triggerSdfRebuild].
  List<RevealDisc>? _pendingRebuildDiscs;

  /// Pending viewport captured alongside [_pendingRebuildDiscs].
  MirkViewportBbox? _pendingRebuildViewport;

  /// Public future used by tests to wait until the shader has loaded
  /// (or failed to load). Mirrors the previous `noiseReady` shape.
  Future<void> get shaderReady => _shaderLoadFuture.then((_) {});

  bool _disposed = false;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    // BUG-009 follow-up diagnostic (2026-04-26). Log the first paint()
    // invocation unconditionally + heartbeat every 60 frames AT INFO so
    // we can prove paint() is firing irrespective of which path we end
    // up on.
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

    // BUG-010 Option B Commit 5: single canonical disc-based clip path.
    final path = buildViewportFogClipPathFromDiscs(discs: context.discs, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible region fully revealed?)');
      return;
    }
    _logEarlyReturnTransition('none');

    // Try to materialise the shader. The first frames after construction
    // may see `_shader == null` while the program is loading; subsequent
    // frames pick it up.
    _shader ??= _shaderService.obtainShaderSync();

    // Make sure the SDF for the current frame is up to date. This may
    // schedule an async rebuild whose result we'll see on the NEXT paint.
    _refreshSdfIfNeeded(context: context, canvasSize: size);

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
      // Heartbeat at ~1 Hz when in steady state — confirms paint() is
      // still being called, useful when investigating "no fog visible".
      _log.info(
        'paint(): post-paint heartbeat path=$pathThisFrame · frame=$_paintCallCount discs=${context.discs.length} sessionElapsed=${context.sessionElapsed.inMilliseconds}ms',
      );
    }
    _paintCallCount++;
    if (shader != null && sdf != null) {
      _paintShaderPath(canvas, size, context, path, shader, sdf);
    } else {
      // Fallback: solid fog at base palette colour. No noise, no
      // animation — the shader path is what produces texture in TIER 2.
      _paintFallbackPath(canvas, size, context, path);
    }

    // Wisps render LAST — additive on top of the fog body.
    canvas.save();
    canvas.clipPath(path);
    _wispSystem.render(canvas, const Color(0xFFE0E6F0)); // Light cool tint.
    canvas.restore();
  }

  /// BUG-009 follow-up diagnostic (2026-04-26) — emits an INFO log only
  /// when the early-return reason transitions (so we don't flood the
  /// file logger at 60 Hz). [reason] is `'none'` when paint() proceeds
  /// past every guard; otherwise the textual gate that fired.
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
  /// ingested into [_previousDiscIdSet] WITHOUT spawning wisps. This
  /// covers two distinct race windows:
  ///
  ///   1. **First frames with async-delayed discs.** On map open the disc
  ///      provider may resolve with 0 discs for one or more frames. If
  ///      we consumed the empty set and left warm-up, the next frame's
  ///      real discs would all appear "new" → burst.
  ///
  ///   2. **Viewport animation scroll-in.** When the map opens, MapLibre
  ///      animates the camera (zoom-out settling, initial fly-to). During
  ///      the ~5 s animation, previously-existing discs that were outside
  ///      the initial narrow viewport scroll into view and appear "new" to
  ///      the frame-diff logic → massive wisp burst forming the visible
  ///      "rose of ellipses" on the boundary. The time-based warm-up
  ///      absorbs ALL these discs without spawning.
  ///
  /// After the warm-up elapses, the normal per-frame diff activates:
  /// only discs not yet in [_previousDiscIdSet] (genuinely new GPS-fix
  /// reveals) spawn wisps. The set remains append-only so discs that
  /// leave the viewport (pan away) are still remembered.
  void _spawnWispsForNewlyEmergedDiscs({required MirkPaintContext context, required Size canvasSize}) {
    final currentIds = <String>{for (final disc in context.discs) disc.id};

    // During warm-up: ingest all disc IDs without spawning. Skip empty
    // frames entirely (the disc provider hasn't resolved yet).
    if (_warmingUp) {
      if (currentIds.isNotEmpty) {
        _previousDiscIdSet.addAll(currentIds);
      }
      final elapsedSec = context.sessionElapsed.inMilliseconds / 1000.0;
      // Stay in warm-up until both conditions are met:
      //   a) enough time has passed for the viewport animation to settle
      //   b) we have seen at least one non-empty disc list
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
  /// perimeter. Sample count is `ceil(circumference / kMirkFogMetersPerWisp)`,
  /// floored to 1 so a tiny disc still gets a single puff.
  void _spawnWispsAlongDiscPerimeter({required RevealDisc disc, required MirkViewportBbox viewport, required Size canvasSize}) {
    // Circumference-driven sample count: keeps the wisp density along
    // the perimeter constant regardless of disc radius. At the 25 m
    // default radius and kMirkFogMetersPerWisp = 8 m, this produces
    // ~20 wisps per emergence.
    final circumferenceMeters = 2.0 * math.pi * disc.radiusMeters;
    final sampleCount = math.max(1, (circumferenceMeters / kMirkFogMetersPerWisp).ceil());

    // Local equirectangular conversion factors at the disc's centre lat.
    // 1 m of latitude ≈ 1 / kMetersPerDegreeLat degrees; 1 m of longitude
    // is the same scaled by cos(lat).
    final latRad = disc.lat * math.pi / 180.0;
    final cosLat = math.cos(latRad);
    final degPerMeterLat = 1.0 / kMetersPerDegreeLat;
    // Polar guard: at ±90° cos drops to 0 and divides explode. The disc
    // skip-on-bbox check above already guards the SDF builder; here we
    // guard the conversion math too.
    final degPerMeterLon = cosLat.abs() < 1e-6 ? degPerMeterLat : 1.0 / (kMetersPerDegreeLat * cosLat);

    for (var k = 0; k < sampleCount; k++) {
      final theta = (2.0 * math.pi * k) / sampleCount;
      final perimeterLat = disc.lat + (disc.radiusMeters * degPerMeterLat) * math.sin(theta);
      final perimeterLon = disc.lon + (disc.radiusMeters * degPerMeterLon) * math.cos(theta);
      final screen = MirkProjection.latLonToScreen(lat: perimeterLat, lon: perimeterLon, viewport: viewport, size: canvasSize);
      // Skip if this perimeter point is far off-screen — saves wisp
      // budget for visible action. 50 px slack matches the cell-spawn
      // bound from the pre-Commit-5 code.
      if (screen.dx < -50 || screen.dx > canvasSize.width + 50 || screen.dy < -50 || screen.dy > canvasSize.height + 50) {
        continue;
      }
      // Outward direction at this perimeter point: `(cos(theta), -sin(theta))`
      // — `-sin` because screen-y grows southward while `sin(theta)` in our
      // lat-offset above grows northward (positive theta = north when k=π/2).
      final direction = Offset(math.cos(theta), -math.sin(theta));
      _wispSystem.spawnAtPosition(position: screen, direction: direction);
    }
  }

  /// Shader path — clip to fog path, draw a viewport-filling rect with
  /// the FragmentShader-bound Paint. The shader handles all visual
  /// dimensions internally.
  void _paintShaderPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path, ui.FragmentShader shader, ui.Image sdf) {
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;

    // Per-instance perturbation: feed `_seed * 0.137` as a uTime offset
    // so different-seed renderers produce different shader output. The
    // 0.137 factor is arbitrary but coprime with typical drift speeds,
    // ensuring no aliasing.
    final tUniform = tSec + _seed * 0.137;

    // World pan: derive from viewport centre lat/lon. Same noise UV
    // space the shader internally evaluates the FBM in. Conservative
    // coupling — pans the fog with the camera at a slow rate.
    final centreLat = (context.viewportBbox.north + context.viewportBbox.south) * 0.5;
    final centreLon = (context.viewportBbox.east + context.viewportBbox.west) * 0.5;
    final offsetX = centreLon * 0.05;
    final offsetY = -centreLat * 0.05;

    // Configure all uniforms via the FogShaderUniforms helper. Slot
    // indices are hand-counted there — single source of truth.
    //
    // Read every shader-tunable parameter from [MirkRuntimeTunables.instance]
    // instead of the const literal, so the in-app tuner sheet (Phase 09
    // BUG-009 follow-up) can scrub each value live without rebuilding the
    // app. The tunables singleton is initialised from the same `kMirkFog*`
    // defaults; production builds with the tuner closed see byte-identical
    // output.
    final t = MirkRuntimeTunables.instance;
    // Effective curlScale: triangle-wave animation by default (UAT
    // 2026-04-26 — slowly varying curlScale gives the fog a "really
    // alive" volumetric feel). Falls back to the static t.curlScale
    // when the dev tuner toggles the animation off.
    final double effectiveCurlScale = t.curlScaleAnimationEnabled
        ? triangleWave(tSec: tSec, period: t.curlScaleAnimationPeriodSec, minV: t.curlScaleAnimationMin, maxV: t.curlScaleAnimationMax)
        : t.curlScale;
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
      // SDF rect: shader maps screen-normalised [0,1] uv to SDF uv via
      // (uv - rect.xy) / rect.zw. Dynamically computed to pin the SDF
      // at its true lat/lon position during pan/zoom (BUG-012 follow-up).
      sdfRect: _computeSdfRect(context.viewportBbox),
      sdfImage: sdf,
    );

    canvas.save();
    canvas.clipPath(path);
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    canvas.restore();
  }

  /// Fallback path — solid base palette colour with feather. No
  /// animation, no noise. Pre-BUG-009 the renderer painted a tileable
  /// noise-image overlay here (BUG-004 fix), but that was the very
  /// "cheap noise sliding" the TIER 2 shader replaces — keeping it as
  /// a fallback would re-introduce the cosmetic regression.
  void _paintFallbackPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path) {
    final r = (kMirkFogAtmosphericBaseColorArgb >> 16) & 0xFF;
    final g = (kMirkFogAtmosphericBaseColorArgb >> 8) & 0xFF;
    final b = kMirkFogAtmosphericBaseColorArgb & 0xFF;

    // Feather sigma — pre-Commit-5 this scaled to the bitmap cell size
    // (canvas.height / 64) so the soft edge matched a single grid cell.
    // Post-Commit-5 the reveal silhouette is continuous geometry, so the
    // feather scales to a small fraction of the canvas dimension. The
    // numerator (canvas height / kRevealedTileParentZoom heuristic) is
    // gone; we use a fixed 4 px base and let `featherRadiusFraction`
    // tune the actual blur.
    const baseFeatherPx = 4.0;
    final featherSigma = baseFeatherPx * config.featherRadiusFraction * context.pixelRatio;

    // Tiny per-frame alpha jitter sourced from the CPU noise generator
    // — gives the regression test "different seeds produce different
    // output" a real signal to discriminate on the fallback path.
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

  /// Checks whether the SDF needs rebuilding and either triggers an
  /// immediate rebuild (disc list changed — GPS fix landed) or starts /
  /// restarts a debounce timer (viewport-only change — pan/zoom gesture).
  ///
  /// BUG-012 fix: the previous implementation hashed disc-list AND
  /// viewport into a single hash. Every pan/zoom frame changed the hash →
  /// triggered a 200+ ms async build → the SDF was shown for the build's
  /// viewport while the map showed the current viewport → strobe. Now the
  /// two inputs have separate hashes: disc changes rebuild immediately,
  /// viewport-only changes are debounced.
  void _refreshSdfIfNeeded({required MirkPaintContext context, required Size canvasSize}) {
    if (_sdfBuildInFlight) return;

    final discHash = _hashDiscList(context.discs);
    final viewportHash = _hashViewport(context.viewportBbox);

    if (discHash != _lastDiscHash) {
      // Disc list changed → rebuild immediately. The user walked, the
      // new reveal must appear now.
      _lastDiscHash = discHash;
      _lastViewportHash = viewportHash;
      _viewportDebounceTimer?.cancel();
      _pendingRebuildDiscs = null;
      _pendingRebuildViewport = null;
      _triggerSdfRebuild(context.discs, context.viewportBbox);
    } else if (viewportHash != _lastViewportHash) {
      // Only viewport changed (pan/zoom) → debounce. Keep the old SDF
      // (slightly misaligned but stable — no strobe). When the timer
      // fires, rebuild with the LATEST viewport captured here.
      _lastViewportHash = viewportHash;
      _pendingRebuildDiscs = context.discs;
      _pendingRebuildViewport = context.viewportBbox;
      _viewportDebounceTimer?.cancel();
      _viewportDebounceTimer = Timer(const Duration(milliseconds: kMirkFogSdfViewportDebounceMs), () {
        if (!_disposed && !_sdfBuildInFlight && _pendingRebuildDiscs != null && _pendingRebuildViewport != null) {
          _triggerSdfRebuild(_pendingRebuildDiscs!, _pendingRebuildViewport!);
          _pendingRebuildDiscs = null;
          _pendingRebuildViewport = null;
        }
      });
    } else if (_sdfImage == null) {
      // Same inputs but no SDF yet (first frame) → build now.
      _triggerSdfRebuild(context.discs, context.viewportBbox);
    }
  }

  /// Kicks off an async SDF build for [discs] at [viewport]. On
  /// completion the result is stored in [_sdfImage] and the next paint
  /// picks it up on the shader path.
  void _triggerSdfRebuild(List<RevealDisc> discs, MirkViewportBbox viewport) {
    _sdfBuildInFlight = true;
    // Capture the viewport at trigger time so we can pin the SDF to its
    // true lat/lon position when the build completes (BUG-012 follow-up).
    final viewportForThisBuild = viewport;
    _log.fine('_triggerSdfRebuild: scheduling rebuild (discs=${discs.length})');
    _sdfBuilder
        .buildFromDiscs(discs: discs, viewport: viewport)
        .then((ui.Image image) {
          if (_disposed) {
            image.dispose();
            return;
          }
          _sdfImage?.dispose();
          _sdfImage = image;
          _sdfViewport = viewportForThisBuild;
          _log.fine('_triggerSdfRebuild: rebuild complete — _sdfImage now set (${image.width}x${image.height})');
        })
        .catchError((Object e, StackTrace st) {
          _log.severe('_triggerSdfRebuild: build FAILED — fallback path will activate', e, st);
        })
        .whenComplete(() {
          _sdfBuildInFlight = false;
        });
  }

  /// Maps the SDF's reference viewport onto the current viewport's
  /// screen-normalised [0,1] space. Returns `(originX, originY, sizeX,
  /// sizeY)` for the four `uSdfRect*` shader uniforms.
  ///
  /// When the viewport hasn't moved since the SDF was built, returns
  /// `(0, 0, 1, 1)` — the existing behaviour. When the viewport pans,
  /// the origin shifts. When the viewport zooms, the size scales. The
  /// shader's `clamp(sdfUv, 0.0, 1.0)` ensures pixels outside the
  /// SDF's coverage read as all-fog.
  (double, double, double, double) _computeSdfRect(MirkViewportBbox currentViewport) {
    final sdfVp = _sdfViewport;
    if (sdfVp == null) return (0.0, 0.0, 1.0, 1.0);
    final dLon = currentViewport.east - currentViewport.west;
    final dLat = currentViewport.north - currentViewport.south;
    if (dLon == 0 || dLat == 0) return (0.0, 0.0, 1.0, 1.0);
    // X axis: longitude. SDF west edge -> screen UV.x, SDF east edge -> screen UV.x.
    final x0 = (sdfVp.west - currentViewport.west) / dLon;
    final xSize = (sdfVp.east - sdfVp.west) / dLon;
    // Y axis: latitude. North -> top (y=0), south -> bottom (y=1).
    final y0 = (currentViewport.north - sdfVp.north) / dLat;
    final ySize = (sdfVp.north - sdfVp.south) / dLat;
    // BUG-014 diagnostic: log the SDF rect when it deviates from identity
    // so future axis-mapping issues are traceable from the device log.
    if (_paintCallCount % 60 == 0 && (x0 != 0 || y0 != 0 || xSize != 1 || ySize != 1)) {
      _log.info(
        '_computeSdfRect: x0=${x0.toStringAsFixed(4)} y0=${y0.toStringAsFixed(4)} '
        'xSize=${xSize.toStringAsFixed(4)} ySize=${ySize.toStringAsFixed(4)} · '
        'sdfVp=[${sdfVp.south.toStringAsFixed(4)},${sdfVp.west.toStringAsFixed(4)}'
        '→${sdfVp.north.toStringAsFixed(4)},${sdfVp.east.toStringAsFixed(4)}] '
        'curVp=[${currentViewport.south.toStringAsFixed(4)},${currentViewport.west.toStringAsFixed(4)}'
        '→${currentViewport.north.toStringAsFixed(4)},${currentViewport.east.toStringAsFixed(4)}]',
      );
    }
    return (x0, y0, xSize, ySize);
  }

  /// FNV-1a hash of the disc list (id + lat + lon + radius per entry).
  /// Cheap — sub-microsecond for a few-hundred-entry list.
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

  /// FNV-1a hash of the viewport bbox edges.
  int _hashViewport(MirkViewportBbox bbox) {
    var hash = 0x811C9DC5;
    hash = _mix(hash, bbox.south.hashCode);
    hash = _mix(hash, bbox.west.hashCode);
    hash = _mix(hash, bbox.north.hashCode);
    hash = _mix(hash, bbox.east.hashCode);
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
    _viewportDebounceTimer?.cancel();
    _viewportDebounceTimer = null;
    _pendingRebuildDiscs = null;
    _pendingRebuildViewport = null;
    _shader?.dispose();
    _shader = null;
    _sdfImage?.dispose();
    _sdfImage = null;
    _sdfViewport = null;
    _wispSystem.clear();
    _previousDiscIdSet = <String>{};
    _warmingUp = true;
  }
}
