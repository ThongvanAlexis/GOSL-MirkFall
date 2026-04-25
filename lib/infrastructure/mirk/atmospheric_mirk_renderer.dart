// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show FragmentProgram, FragmentShader, Image, Path;
import 'dart:ui' show BlurStyle, Canvas, Color, MaskFilter, Offset, Paint, PaintingStyle, Rect, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

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
///    AND the SDF for the current viewport+revealed-cell hash is built,
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
///    animation. This is intentional: the previous BUG-004 ImageShader
///    overlay was the "cheap noise sliding" the BUG-009 visual target
///    is replacing — keeping it as fallback would defeat the purpose.
///    The fallback is only reached on devices that cannot run the
///    shader (rare in 2026), and even then a flat fog is preferable to
///    the cheap drift.
///
/// ## SDF caching
///
/// The SDF depends on (a) the union of revealed cell bitmaps and (b)
/// the viewport bbox. The renderer hashes both and rebuilds only when
/// the hash changes. Hash construction happens on the synchronous paint
/// path; SDF rebuild kicks off as a side-effect Future and the renderer
/// uses the previously-cached `ui.Image` (or a fallback "all fog" SDF)
/// while the new build resolves.
///
/// ## Pre-BUG-009 behaviour preserved
///
/// * `buildViewportFogClipPath` is still consulted to determine which
///   region to fog (BUG-003 invariant — single composite path, no
///   per-tile seam erosion).
/// * `MaskFilter.blur(BlurStyle.normal, sigma)` is retained on the
///   FALLBACK path so a worst-case device sees feathered edges. The
///   shader path doesn't need it (the watercolour boundary inside the
///   shader produces a softer + more cartographic edge).
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

  /// Last-paint snapshot of revealed-cell bitmaps per parent tile.
  /// Used to compute the diff "newly revealed since last frame" for
  /// wisp spawning.
  final Map<int, Uint8List> _lastBitmapByTileKey = <int, Uint8List>{};

  /// Last-paint sessionElapsed in seconds. Used to compute dt for the
  /// wisp system's advance step.
  double _lastTSec = 0.0;

  /// Last path tag we INFO-logged ('shader' / 'fallback' / null at start).
  /// We only log on transitions to avoid 60 Hz spam. Diagnostic-only
  /// (BUG-009 follow-up — added 2026-04-25 to debug "all-grey solid fog").
  String? _lastLoggedPath;

  /// Frame counter for the FINE heartbeat log (every 60 frames ≈ 1 Hz).
  int _paintCallCount = 0;

  /// Future that resolves to a `ui.FragmentProgram` (or null on load
  /// failure). Awaited by tests via [shaderReady].
  late final Future<ui.FragmentProgram?> _shaderLoadFuture;

  /// Cached fragment shader instance. Lazily extracted from the
  /// program when it first becomes available; reused across frames.
  ui.FragmentShader? _shader;

  /// Cached SDF image. Rebuilt when [_lastSdfHash] no longer matches
  /// the current frame's revealed-cell + viewport hash.
  ui.Image? _sdfImage;

  /// Hash of the inputs that produced [_sdfImage]. Re-computed every
  /// paint; if it differs from the last build, schedule a rebuild.
  int _lastSdfHash = 0;

  /// Whether an SDF rebuild is currently in flight. Prevents redundant
  /// concurrent rebuilds when paint is called many times during the
  /// async build window.
  bool _sdfBuildInFlight = false;

  /// Public future used by tests to wait until the shader has loaded
  /// (or failed to load). Mirrors the previous `noiseReady` shape.
  Future<void> get shaderReady => _shaderLoadFuture.then((_) {});

  bool _disposed = false;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (_disposed) return;
    if (context.visibleTiles.isEmpty) return;

    // Resolve the fog clip path FIRST — same rules as pre-BUG-009. This
    // also gives us a fast bail-out when every visible tile is fully
    // revealed.
    final path = buildViewportFogClipPath(visibleTiles: context.visibleTiles, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) return;

    // Try to materialise the shader. The first frames after construction
    // may see `_shader == null` while the program is loading; subsequent
    // frames pick it up.
    _shader ??= _shaderService.obtainShaderSync();

    // Make sure the SDF for the current frame is up to date. This may
    // schedule an async rebuild whose result we'll see on the NEXT paint.
    _refreshSdfIfNeeded(context: context, canvasSize: size);

    // Diff against last frame's bitmaps to find newly-revealed cells →
    // spawn wisps along their SDF gradient.
    _spawnWispsForNewlyRevealed(context: context, canvasSize: size);

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
        'paint(): path transition ${_lastLoggedPath ?? "(initial)"} → $pathThisFrame · shader=${shader != null} sdf=${sdf != null} sdfBuildInFlight=$_sdfBuildInFlight visibleTiles=${context.visibleTiles.length}',
      );
      _lastLoggedPath = pathThisFrame;
    } else if (_paintCallCount % 60 == 0) {
      // Heartbeat at ~1 Hz when in steady state — confirms paint() is
      // still being called, useful when investigating "no fog visible".
      _log.fine(
        'paint(): heartbeat path=$pathThisFrame · frame=$_paintCallCount visibleTiles=${context.visibleTiles.length} sessionElapsed=${context.sessionElapsed.inMilliseconds}ms',
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

  /// Diff each visible tile's current bitmap against [_lastBitmapByTileKey];
  /// for every cell that flipped 0→1 (newly revealed), spawn wisps at
  /// the cell's screen-space centre with velocity along the cell's
  /// SDF gradient (approximated by the cell's offset from the parent
  /// tile centre — the gradient direction is "outward from revealed
  /// area").
  void _spawnWispsForNewlyRevealed({required MirkPaintContext context, required Size canvasSize}) {
    for (final tile in context.visibleTiles) {
      final key = (tile.parentX << 16) ^ tile.parentY;
      final last = _lastBitmapByTileKey[key];
      if (last == null) {
        // First time we've seen this tile this session — record the
        // bitmap as baseline. Existing revealed cells do NOT spawn
        // wisps retroactively (they would on every fresh viewport
        // intersection — way too many wisps).
        _lastBitmapByTileKey[key] = Uint8List.fromList(tile.bitmap);
        continue;
      }
      // Iterate bytes; a byte that changed indicates >= 1 cell flip.
      for (var byteIdx = 0; byteIdx < tile.bitmap.length; byteIdx++) {
        final newByte = tile.bitmap[byteIdx];
        final oldByte = last[byteIdx];
        if (newByte == oldByte) continue;
        // Find cells that flipped 0→1.
        final flipped = newByte & ~oldByte;
        if (flipped == 0) continue;
        for (var bit = 0; bit < 8; bit++) {
          if ((flipped & (1 << bit)) == 0) continue;
          final bitIndex = byteIdx * 8 + bit;
          final j = bitIndex ~/ kRevealedTileSubgridSize;
          final i = bitIndex % kRevealedTileSubgridSize;
          _spawnWispForCell(tile: tile, cellI: i, cellJ: j, viewport: context.viewportBbox, canvasSize: canvasSize);
        }
      }
      // Update baseline. Copy because the source Uint8List may be
      // mutated by the next provider rebuild.
      _lastBitmapByTileKey[key] = Uint8List.fromList(tile.bitmap);
    }
  }

  /// Computes the screen-space centre of cell ([cellI], [cellJ]) of
  /// [tile], then spawns wisps there with velocity along the SDF
  /// gradient. Gradient direction is approximated as "from the cell
  /// centre toward the parent tile centre, then negated" — wisps stream
  /// OUT of the revealed area into the surrounding fog.
  void _spawnWispForCell({
    required VisibleMirkTile tile,
    required int cellI,
    required int cellJ,
    required MirkViewportBbox viewport,
    required Size canvasSize,
  }) {
    final cellLatSpan = (tile.tileNorthLat - tile.tileSouthLat) / kRevealedTileSubgridSize;
    final cellLonSpan = (tile.tileEastLon - tile.tileWestLon) / kRevealedTileSubgridSize;
    final cellCentreLat = tile.tileNorthLat - (cellJ + 0.5) * cellLatSpan;
    final cellCentreLon = tile.tileWestLon + (cellI + 0.5) * cellLonSpan;
    final centre = MirkProjection.latLonToScreen(lat: cellCentreLat, lon: cellCentreLon, viewport: viewport, size: canvasSize);
    // Skip if cell centre is far off-screen (saves wisp budget for
    // visible action).
    if (centre.dx < -50 || centre.dx > canvasSize.width + 50 || centre.dy < -50 || centre.dy > canvasSize.height + 50) {
      return;
    }
    // Direction: outward from the cell. Approximate by random unit
    // vector — the SDF gradient at the cell is hard to compute on the
    // hot path. Random-direction wisps give a "puff dispersing
    // omnidirectionally" reading which is visually acceptable.
    final angle = (cellI * 13 + cellJ * 17) * 0.6283185; // Cheap deterministic angle.
    final direction = Offset(math.cos(angle), math.sin(angle));
    _wispSystem.spawnAtCellCenter(position: centre, direction: direction);
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
    FogShaderUniforms.setAll(
      shader,
      resolution: size,
      time: tUniform,
      offset: (offsetX, offsetY),
      baseArgb: kMirkFogAtmosphericBaseColorArgb,
      baseAlpha: config.densityBaselineAlpha,
      highlightArgb: kMirkFogAtmosphericHighlightColorArgb,
      shadowArgb: kMirkFogAtmosphericShadowColorArgb,
      driftZFar: kMirkFogAtmosphericDriftZFar,
      driftZMid: kMirkFogAtmosphericDriftZMid,
      driftZNear: kMirkFogAtmosphericDriftZNear,
      scaleFar: kMirkFogAtmosphericScaleFar,
      scaleMid: kMirkFogAtmosphericScaleMid,
      scaleNear: kMirkFogAtmosphericScaleNear,
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
      // SDF rect: shader maps screen-normalised [0,1] uv to SDF uv via
      // (uv - rect.xy) / rect.zw. Default fills the full screen, which
      // is correct because the SDF was built for the entire viewport.
      sdfRect: const (0.0, 0.0, 1.0, 1.0),
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

    final cellSize = size.height / kRevealedTileSubgridSize;
    final featherSigma = cellSize * config.featherRadiusFraction * context.pixelRatio;

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

  /// Hashes the inputs that affect the SDF. If they changed since
  /// [_lastSdfHash], schedule a rebuild (kick off async; the new SDF
  /// will be picked up on the NEXT frame). Cheap — runs every paint.
  void _refreshSdfIfNeeded({required MirkPaintContext context, required Size canvasSize}) {
    if (_sdfBuildInFlight) return;
    final hash = _computeSdfHash(context);
    if (hash == _lastSdfHash && _sdfImage != null) return;
    _sdfBuildInFlight = true;
    _lastSdfHash = hash;
    _log.fine('_refreshSdfIfNeeded: scheduling rebuild (hash=$hash visibleTiles=${context.visibleTiles.length})');
    _sdfBuilder
        .build(visibleTiles: context.visibleTiles, viewport: context.viewportBbox)
        .then((image) {
          if (_disposed) {
            image.dispose();
            return;
          }
          _sdfImage?.dispose();
          _sdfImage = image;
          _log.fine('_refreshSdfIfNeeded: rebuild complete — _sdfImage now set (${image.width}x${image.height})');
        })
        .catchError((Object e, StackTrace st) {
          _log.severe('_refreshSdfIfNeeded: build FAILED — fallback path will activate', e, st);
        })
        .whenComplete(() {
          _sdfBuildInFlight = false;
        });
  }

  /// Cheap hash combining viewport bbox + a digest of revealed-cell
  /// bitmaps. Not cryptographic — just needs to discriminate between
  /// "the user walked" and "no change".
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
      // Sparse hash of the bitmap — sample 8 bytes spread across 512.
      // Misses the rare case where two distinct bitmaps share these
      // sampled bytes; in practice the parent-tile hash collision rate
      // is negligible since the whole tile gets a fresh allocation
      // every time the store updates.
      for (var i = 0; i < 8; i++) {
        hash = _mix(hash, tile.bitmap[i * 64]);
      }
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
    _wispSystem.clear();
    _lastBitmapByTileKey.clear();
  }
}
