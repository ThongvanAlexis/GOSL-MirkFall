// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — port of the POC `FogTransformLogger`
// (`mirk-poc-debug` @ 90c9321, `lib/infrastructure/mirk/fog_transform_logger.dart`).
// Changes vs the POC: `kPoc*` constants → `kMirkFogDiag*`, `appliedUOffset`
// → `appliedPixelOrigin` (named record), `LatLng` → `GeoPoint` (the file is
// outside the flutter_map import perimeter), the four scale / shear scalars
// are read from the matrix here instead of being passed by the painter,
// verbose-only gating (CLAUDE.md §Logging), `recordPaint` no-op before `start()`.

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';

/// Rollup of per-paint fog Canvas-transform vs camera-pixelOrigin vs
/// applied-pixelOrigin diagnostics (FOG-10) — POC diagnostic, active only in
/// verbose logging (`--dart-define=DEBUG=true` or the debug-menu toggle) —
/// CLAUDE.md §Logging.
///
/// Sibling of `FrameDeltaProbe` (FOG-08). Every diagnostic logger emits on
/// `now ~/ 1000` boundaries at [kMirkFogDiagRollupSeconds] cadence so post-walk
/// grep can join the streams by `epochSecond`.
///
/// Captured per paint: 15 diagnostic doubles (canvasTx, canvasTy, pixelOriginX,
/// pixelOriginY, centerLat, centerLon, uOffsetX, uOffsetY, canvasSx, canvasSy,
/// canvasShearYX, canvasShearXY, uResolutionX, uResolutionY, zoom). The rollup
/// emits min / median / max for each field — 45 numeric values plus
/// `epochSecond` + `sampleCount` = 47 keys per JSONL line.
///
/// The `uOffsetX*` / `uOffsetY*` JSONL keys are kept from the POC on purpose:
/// the post-walk grep tooling reads them, and their VALUE has been the raw
/// `uPixelOrigin` forwarded to the shader since FOG-18 (magnitudes ~1e6 at
/// zoom 13, not a [0, 1) fraction).
///
/// Idle windows (no [recordPaint] call) emit nothing. Buffer capped at
/// [kMirkFogDiagFogTransformBufferMaxSamples], FIFO drop on overflow.
///
/// ## Verbose gating
///
/// [recordPaint] and the rollup timer callback early-return while
/// `Logger('infrastructure.mirk.fog_transform').isLoggable(Level.FINE)` is
/// false; the timer stays armed so the debug-menu toggle acts without a
/// remount. [recordPaint] before [start] is a no-op.
class FogTransformLogger {
  /// [rollupInterval] is a test seam — defaults to [kMirkFogDiagRollupSeconds].
  FogTransformLogger({Duration? rollupInterval}) : _rollupInterval = rollupInterval ?? const Duration(seconds: kMirkFogDiagRollupSeconds);

  static final Logger _log = Logger('infrastructure.mirk.fog_transform');

  final Duration _rollupInterval;
  final List<_FogTransformSample> _buffer = <_FogTransformSample>[];
  Timer? _timer;
  int _frameCounter = 0;

  /// Whether the diagnostic is enabled (verbose logging active).
  bool get _isVerbose => _log.isLoggable(Level.FINE);

  /// Whether [start] has been called and [stop] has not.
  bool get isRunning => _timer != null;

  /// Starts the rollup timer. Idempotent.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_rollupInterval, (_) => _emitRollup());
  }

  /// Cancels the timer and flushes a final rollup if the buffer is non-empty
  /// (so an owner disposing mid-window does not lose the last samples). Idempotent.
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isNotEmpty) {
      _emitRollup();
    }
  }

  /// Records one paint observation. No-op unless verbose AND [isRunning].
  ///
  /// * [canvasTransform] — the single `Canvas.getTransform()` read of the paint
  ///   (translation, scale and shear slots are extracted here).
  /// * [cameraPixelOrigin] — raw `MapCamera.pixelOrigin`.
  /// * [cameraCenter] — `MapCamera.center` as a [GeoPoint].
  /// * [appliedPixelOrigin] — the value forwarded to the renderer after the
  ///   platform corrections (FOG-23 sign flip on Android).
  /// * [uResolutionX] / [uResolutionY] — painter `size`.
  /// * [zoom] — `MapCamera.zoom`.
  void recordPaint({
    required Float64List canvasTransform,
    required Point<double> cameraPixelOrigin,
    required GeoPoint cameraCenter,
    required ({double x, double y}) appliedPixelOrigin,
    required double uResolutionX,
    required double uResolutionY,
    required double zoom,
  }) {
    if (!_isVerbose || !isRunning) return;
    _frameCounter += 1;
    _buffer.add(
      _FogTransformSample(
        frameCounter: _frameCounter,
        canvasTx: canvasTransform[kCanvasTransformTxIndex],
        canvasTy: canvasTransform[kCanvasTransformTyIndex],
        pixelOriginX: cameraPixelOrigin.x,
        pixelOriginY: cameraPixelOrigin.y,
        centerLat: cameraCenter.latitude,
        centerLon: cameraCenter.longitude,
        uOffsetX: appliedPixelOrigin.x,
        uOffsetY: appliedPixelOrigin.y,
        canvasSx: canvasTransform[kCanvasTransformSxIndex],
        canvasSy: canvasTransform[kCanvasTransformSyIndex],
        canvasShearYX: canvasTransform[kCanvasTransformShearYxIndex],
        canvasShearXY: canvasTransform[kCanvasTransformShearXyIndex],
        uResolutionX: uResolutionX,
        uResolutionY: uResolutionY,
        zoom: zoom,
      ),
    );
    while (_buffer.length > kMirkFogDiagFogTransformBufferMaxSamples) {
      _buffer.removeAt(0);
    }
  }

  /// Computes (min, median, max) from a non-empty, ascending-sorted list.
  @visibleForTesting
  static (double min, double median, double max) computeStats(List<double> sortedAscending) {
    assert(sortedAscending.isNotEmpty, 'computeStats requires a non-empty sorted list');
    return (sortedAscending.first, sortedAscending[sortedAscending.length ~/ 2], sortedAscending.last);
  }

  void _emitRollup() {
    if (!_isVerbose) {
      _buffer.clear();
      return;
    }
    if (_buffer.isEmpty) return;
    final int sampleCount = _buffer.length;
    final Map<String, String> statsByKey = <String, String>{};
    for (final _FogTransformField field in _FogTransformField.values) {
      final (double min, double median, double max) stats = computeStats(_buffer.map(field.read).toList()..sort());
      statsByKey['${field.jsonKey}Min'] = stats.$1.toStringAsFixed(_kDecimals);
      statsByKey['${field.jsonKey}Median'] = stats.$2.toStringAsFixed(_kDecimals);
      statsByKey['${field.jsonKey}Max'] = stats.$3.toStringAsFixed(_kDecimals);
    }
    // WALL-CLOCK source — REQUIRED for the post-walk join with the other rollup loggers.
    final int epochSecond = DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    _log.info(json.encode(<String, Object>{'epochSecond': epochSecond, 'sampleCount': sampleCount, ...statsByKey}));
    _buffer.clear();
  }
}

/// Column-major slots of the 4x4 `Float64List` returned by `Canvas.getTransform()`
/// (same convention as `vector_math.Matrix4`): `[0]` = sx, `[5]` = sy,
/// `[1]` = shear y/x, `[4]` = shear x/y, `[12]` = tx, `[13]` = ty. Shared with
/// the `FogLayer` painter (FOG-12) so the two never disagree on a slot.
const int kCanvasTransformSxIndex = 0;
const int kCanvasTransformShearYxIndex = 1;
const int kCanvasTransformShearXyIndex = 4;
const int kCanvasTransformSyIndex = 5;
const int kCanvasTransformTxIndex = 12;
const int kCanvasTransformTyIndex = 13;

/// Decimal places of every numeric JSONL field.
const int _kDecimals = 6;

/// The 15 diagnostic fields, in JSONL key order, with their sample accessor.
enum _FogTransformField {
  canvasTx('canvasTx'),
  canvasTy('canvasTy'),
  pixelOriginX('pixelOriginX'),
  pixelOriginY('pixelOriginY'),
  centerLat('centerLat'),
  centerLon('centerLon'),
  uOffsetX('uOffsetX'),
  uOffsetY('uOffsetY'),
  canvasSx('canvasSx'),
  canvasSy('canvasSy'),
  canvasShearYX('canvasShearYX'),
  canvasShearXY('canvasShearXY'),
  uResolutionX('uResolutionX'),
  uResolutionY('uResolutionY'),
  zoom('zoom');

  const _FogTransformField(this.jsonKey);

  final String jsonKey;

  double read(_FogTransformSample sample) => switch (this) {
    canvasTx => sample.canvasTx,
    canvasTy => sample.canvasTy,
    pixelOriginX => sample.pixelOriginX,
    pixelOriginY => sample.pixelOriginY,
    centerLat => sample.centerLat,
    centerLon => sample.centerLon,
    uOffsetX => sample.uOffsetX,
    uOffsetY => sample.uOffsetY,
    canvasSx => sample.canvasSx,
    canvasSy => sample.canvasSy,
    canvasShearYX => sample.canvasShearYX,
    canvasShearXY => sample.canvasShearXY,
    uResolutionX => sample.uResolutionX,
    uResolutionY => sample.uResolutionY,
    zoom => sample.zoom,
  };
}

/// Immutable per-paint observation (frame counter + 15 diagnostic doubles).
@immutable
class _FogTransformSample {
  const _FogTransformSample({
    required this.frameCounter,
    required this.canvasTx,
    required this.canvasTy,
    required this.pixelOriginX,
    required this.pixelOriginY,
    required this.centerLat,
    required this.centerLon,
    required this.uOffsetX,
    required this.uOffsetY,
    required this.canvasSx,
    required this.canvasSy,
    required this.canvasShearYX,
    required this.canvasShearXY,
    required this.uResolutionX,
    required this.uResolutionY,
    required this.zoom,
  });

  final int frameCounter;
  final double canvasTx;
  final double canvasTy;
  final double pixelOriginX;
  final double pixelOriginY;
  final double centerLat;
  final double centerLon;
  final double uOffsetX;
  final double uOffsetY;
  final double canvasSx;
  final double canvasSy;
  final double canvasShearYX;
  final double canvasShearXY;
  final double uResolutionX;
  final double uResolutionY;
  final double zoom;
}
