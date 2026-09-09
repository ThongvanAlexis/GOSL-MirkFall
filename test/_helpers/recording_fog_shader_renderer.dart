// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-03 — port of the POC `RecordingFogShaderRenderer`
// (`mirk-poc-debug` @ 90c9321, `test/_helpers/recording_fog_shader_renderer.dart`)
// adapted to MirkFall's `FogShaderRenderer.render` signature (canvas + palette
// args, `pixelOrigin` as a named record, `bool` return).

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_renderer.dart';

/// Snapshot of every named arg passed to a single `FogShaderRenderer.render(...)`
/// invocation. Tests inspect this to assert the Phase 09.1 invariants:
///
///   * `pixelOrigin` / `zoomScale` / `sdfRect` forwarded verbatim from the
///     `MirkPaintContext` (no Dart-side modulo, no viewport remapping).
///   * 20 named tunables present ([namedFloatArgs]).
///   * Live `uTime` per paint: compare [timeSeconds] across successive renders.
@immutable
class RecordedFogRender {
  /// Captures a render invocation. All fields mirror named args of
  /// `FogShaderRenderer.render(...)`.
  const RecordedFogRender({
    required this.resolution,
    required this.timeSeconds,
    required this.pixelOrigin,
    required this.zoomScale,
    required this.sdfRect,
    required this.sdfImage,
    required this.baseArgb,
    required this.baseAlpha,
    required this.highlightArgb,
    required this.shadowArgb,
    required this.namedFloatArgs,
  });

  /// Painter `size` argument — drives the `uResolution` uniform.
  final Size resolution;

  /// LIVE `uTime` value at the moment of paint.
  final double timeSeconds;

  /// `uPixelOrigin` — full-precision world-pixel origin, `.y` already
  /// sign-flipped on Android (FOG-23). The shader consumes it verbatim.
  final ({double x, double y}) pixelOrigin;

  /// `uZoomScale` at slot 41 — `pow(2, zoom - kMirkFogReferenceZoom)` (FOG-19).
  final double zoomScale;

  /// The four `uSdfRect*` scalars — identity on iOS, `(0, 1, 1, -1)` on Android (FOG-21).
  final (double, double, double, double) sdfRect;

  /// SDF sampler — captured by reference, never inspected here.
  final ui.Image sdfImage;

  /// Palette forwarded by the renderer (atmospheric vs heavenly).
  final int baseArgb;
  final double baseAlpha;
  final int highlightArgb;
  final int shadowArgb;

  /// Every runtime tunable by named key → value (20 entries,
  /// `driftZFar` … `boundaryDensityBoost`).
  final Map<String, double> namedFloatArgs;

  /// Counts every distinct float slot observed through the seam:
  ///
  ///   * 2 floats from [resolution] (width, height)
  ///   * 1 float from [timeSeconds]
  ///   * 2 floats from [pixelOrigin]
  ///   * 1 float from [baseAlpha]
  ///   * 4 floats from [sdfRect]
  ///   * 1 float from [zoomScale]
  ///   * `namedFloatArgs.length` floats (the tunables)
  ///
  /// At 20 tunables the total is `2+1+2+1+4+1+20 = 31`. The ABI's 42 slots also
  /// count the 3 RGB triplets of `uBase` / `uHighlight` / `uShadow` (9 floats)
  /// and the 2 hard-coded alphas, which the production renderer derives from
  /// the ARGB ints — asserted by source reflection in
  /// `fog_shader_uniforms_test.dart`, not through this seam.
  int get totalFloatSlotsObserved => 2 + 1 + 2 + 1 + 4 + 1 + namedFloatArgs.length;
}

/// Test impl of [FogShaderRenderer] — records every `render(...)` call into
/// [renders] instead of touching a real `ui.FragmentShader` (which can't be
/// instantiated in headless test envs: `FragmentProgram.fromAsset` requires the
/// asset bundle + a working GPU). Always reports `true` ("drawn") so the
/// renderer under test takes the shader path even though `shader` is `null`.
class RecordingFogShaderRenderer implements FogShaderRenderer {
  /// All recorded renders, in invocation order.
  final List<RecordedFogRender> renders = <RecordedFogRender>[];

  @override
  bool render({
    required Canvas canvas,
    required ui.FragmentShader? shader,
    required Size size,
    required double timeSeconds,
    required ({double x, double y}) pixelOrigin,
    required double zoomScale,
    required (double, double, double, double) sdfRect,
    required ui.Image sdfImage,
    required int baseArgb,
    required double baseAlpha,
    required int highlightArgb,
    required int shadowArgb,
    required Map<String, double> tunables,
  }) {
    renders.add(
      RecordedFogRender(
        resolution: size,
        timeSeconds: timeSeconds,
        pixelOrigin: pixelOrigin,
        zoomScale: zoomScale,
        sdfRect: sdfRect,
        sdfImage: sdfImage,
        baseArgb: baseArgb,
        baseAlpha: baseAlpha,
        highlightArgb: highlightArgb,
        shadowArgb: shadowArgb,
        namedFloatArgs: Map<String, double>.from(tunables),
      ),
    );
    return true;
  }
}
