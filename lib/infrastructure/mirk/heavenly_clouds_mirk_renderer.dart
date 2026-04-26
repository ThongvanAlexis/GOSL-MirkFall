// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show FragmentProgram, FragmentShader, Image, Path;
import 'dart:ui' show BlurStyle, Canvas, Color, MaskFilter, Offset, Paint, PaintingStyle, Rect, Size;

import 'package:logging/logging.dart';
import 'package:mirkfall/application/tunables/mirk_runtime_tunables.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';

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

  /// Last-paint snapshot of revealed-cell bitmaps per parent tile.
  final Map<int, Uint8List> _lastBitmapByTileKey = <int, Uint8List>{};
  double _lastTSec = 0.0;

  /// BUG-009 follow-up diagnostic: last path tag we INFO-logged
  /// ('shader' / 'fallback' / null at start). We only log on transitions
  /// to avoid 60 Hz spam.
  String? _lastLoggedPath;
  int _paintCallCount = 0;

  /// BUG-009 follow-up diagnostic (2026-04-26). Mirrors the atmospheric
  /// renderer — tracks the last `paint()` early-return reason so we can
  /// surface silent bailouts (every gate logs INFO on transition only).
  /// See `AtmosphericMirkRenderer._logEarlyReturnTransition` for the
  /// rationale.
  String? _lastEarlyReturnReason;
  bool _firstPaintLogged = false;

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
    // BUG-009 follow-up diagnostic (2026-04-26) — mirror of the
    // atmospheric renderer's instrumentation. See that file for the
    // throttling rationale.
    if (!_firstPaintLogged) {
      _log.info(
        'paint(): first invocation — disposed=$_disposed visibleTiles=${context.visibleTiles.length} canvasSize=${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}',
      );
      _firstPaintLogged = true;
    } else if (_paintCallCount % 60 == 0) {
      _log.info('paint(): entry heartbeat frame=$_paintCallCount disposed=$_disposed visibleTiles=${context.visibleTiles.length}');
    }
    if (_disposed) {
      _logEarlyReturnTransition('disposed');
      return;
    }
    if (context.visibleTiles.isEmpty) {
      _logEarlyReturnTransition('visibleTiles.isEmpty');
      return;
    }
    final path = buildViewportFogClipPath(visibleTiles: context.visibleTiles, viewport: context.viewportBbox, canvasSize: size);
    if (path.getBounds().isEmpty) {
      _logEarlyReturnTransition('clipPath.bounds.isEmpty (every visible tile fully revealed?)');
      return;
    }
    _logEarlyReturnTransition('none');
    _shader ??= _shaderService.obtainShaderSync();
    _refreshSdfIfNeeded(context: context, canvasSize: size);

    // Spawn wisps for newly revealed cells + advance the system.
    _spawnWispsForNewlyRevealed(context: context, canvasSize: size);
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final dt = (tSec - _lastTSec).clamp(0.0, 0.1);
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
      // BUG-009 follow-up (2026-04-26): bumped FINE → INFO so the user's
      // file logger captures it without a root-level threshold change.
      _log.info(
        'paint(): post-paint heartbeat path=$pathThisFrame · frame=$_paintCallCount visibleTiles=${context.visibleTiles.length} sessionElapsed=${context.sessionElapsed.inMilliseconds}ms',
      );
    }
    _paintCallCount++;
    if (shader != null && sdf != null) {
      _paintShaderPath(canvas, size, context, path, shader, sdf);
    } else {
      _paintFallbackPath(canvas, size, context, path);
    }

    // Wisps render last — additive over the fog body. Heavenly uses a
    // warmer wisp tint to read as "sunlit cloud puff".
    canvas.save();
    canvas.clipPath(path);
    _wispSystem.render(canvas, const Color(0xFFF8F0E2));
    canvas.restore();
  }

  /// BUG-009 follow-up diagnostic (2026-04-26) — see
  /// `AtmosphericMirkRenderer._logEarlyReturnTransition`. Duplicated to
  /// keep the parallel structure between the two builtins (each renderer
  /// has its own logger and its own state field).
  void _logEarlyReturnTransition(String reason) {
    if (reason == _lastEarlyReturnReason) return;
    _log.info('paint(): early-return state ${_lastEarlyReturnReason ?? "(initial)"} → $reason · frame=$_paintCallCount');
    _lastEarlyReturnReason = reason;
  }

  /// Same logic as the atmospheric renderer — diff bitmap to find
  /// newly-revealed cells and spawn wisps. Duplicated here because
  /// each renderer owns its own [WispParticleSystem] and bitmap
  /// snapshots; pulling into a shared helper would impose a state-
  /// management coupling that doesn't simplify the call sites.
  void _spawnWispsForNewlyRevealed({required MirkPaintContext context, required Size canvasSize}) {
    for (final tile in context.visibleTiles) {
      final key = (tile.parentX << 16) ^ tile.parentY;
      final last = _lastBitmapByTileKey[key];
      if (last == null) {
        _lastBitmapByTileKey[key] = Uint8List.fromList(tile.bitmap);
        continue;
      }
      for (var byteIdx = 0; byteIdx < tile.bitmap.length; byteIdx++) {
        final newByte = tile.bitmap[byteIdx];
        final oldByte = last[byteIdx];
        if (newByte == oldByte) continue;
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
      _lastBitmapByTileKey[key] = Uint8List.fromList(tile.bitmap);
    }
  }

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
    if (centre.dx < -50 || centre.dx > canvasSize.width + 50 || centre.dy < -50 || centre.dy > canvasSize.height + 50) {
      return;
    }
    final angle = (cellI * 13 + cellJ * 17) * 0.6283185;
    final direction = Offset(math.cos(angle), math.sin(angle));
    _wispSystem.spawnAtCellCenter(position: centre, direction: direction);
  }

  void _paintShaderPath(Canvas canvas, Size size, MirkPaintContext context, ui.Path path, ui.FragmentShader shader, ui.Image sdf) {
    final tSec = context.sessionElapsed.inMilliseconds / 1000.0;
    final tUniform = tSec + _seed * 0.137;
    final centreLat = (context.viewportBbox.north + context.viewportBbox.south) * 0.5;
    final centreLon = (context.viewportBbox.east + context.viewportBbox.west) * 0.5;
    final offsetX = centreLon * 0.05;
    final offsetY = -centreLat * 0.05;
    // Read every shader uniform from [MirkRuntimeTunables.instance] (see
    // atmospheric renderer for rationale).
    final t = MirkRuntimeTunables.instance;
    // Effective curlScale: triangle-wave animation by default — same
    // helper as atmospheric so both palettes breathe in lockstep.
    final double effectiveCurlScale = t.curlScaleAnimationEnabled
        ? triangleWave(tSec: tSec, period: t.curlScaleAnimationPeriodSec, minV: t.curlScaleAnimationMin, maxV: t.curlScaleAnimationMax)
        : t.curlScale;
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
      driftZFar: t.heavenlyDriftZFar,
      driftZMid: t.heavenlyDriftZMid,
      driftZNear: t.heavenlyDriftZNear,
      // Bigger puffs (finer near-octave for cloud detail).
      scaleFar: t.heavenlyScaleFar,
      scaleMid: t.heavenlyScaleMid,
      scaleNear: t.heavenlyScaleNear,
      // Same opacity weights as atmospheric — the parallax depth
      // signature stays consistent across builtins.
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
    // BUG-009 follow-up diagnostic — see atmospheric renderer for the
    // rationale. Discriminates "bits lost upstream" vs "lost inside
    // the SDF projection" on the next iOS UAT walk.
    var totalSetBits = 0;
    for (final tile in context.visibleTiles) {
      for (final byte in tile.bitmap) {
        var b = byte;
        while (b != 0) {
          b &= b - 1;
          totalSetBits++;
        }
      }
    }
    _log.fine('_refreshSdfIfNeeded: visibleTiles=${context.visibleTiles.length} totalSetBits=$totalSetBits');
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
    _wispSystem.clear();
    _lastBitmapByTileKey.clear();
  }
}
