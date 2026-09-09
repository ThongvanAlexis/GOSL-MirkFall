// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' as ui show FragmentShader, Image;
import 'dart:ui' show Canvas, Offset, Paint, Size;

import 'fog_shader_uniforms.dart';

/// Keys of the 20 runtime-tunable floats a [FogShaderRenderer] receives, in
/// shader slot order (17..36). String keys rather than a typed record so the
/// test double records exactly what the production renderer forwarded and the
/// POC `RecordingFogShaderRenderer` ports verbatim.
abstract final class FogShaderTunableKey {
  static const String driftZFar = 'driftZFar';
  static const String driftZMid = 'driftZMid';
  static const String driftZNear = 'driftZNear';
  static const String scaleFar = 'scaleFar';
  static const String scaleMid = 'scaleMid';
  static const String scaleNear = 'scaleNear';
  static const String opacityFar = 'opacityFar';
  static const String opacityMid = 'opacityMid';
  static const String opacityNear = 'opacityNear';
  static const String curlAmplitude = 'curlAmplitude';
  static const String curlScale = 'curlScale';
  static const String lightDirRadians = 'lightDirRadians';
  static const String lightOffset = 'lightOffset';
  static const String lightStrength = 'lightStrength';
  static const String hueNoiseScale = 'hueNoiseScale';
  static const String hueStrength = 'hueStrength';
  static const String boundarySharpDistance = 'boundarySharpDistance';
  static const String boundaryBleedDistance = 'boundaryBleedDistance';
  static const String boundaryEdgeBand = 'boundaryEdgeBand';
  static const String boundaryDensityBoost = 'boundaryDensityBoost';

  /// All 20 keys in slot order — the contract every caller must satisfy.
  static const List<String> all = <String>[
    driftZFar,
    driftZMid,
    driftZNear,
    scaleFar,
    scaleMid,
    scaleNear,
    opacityFar,
    opacityMid,
    opacityNear,
    curlAmplitude,
    curlScale,
    lightDirRadians,
    lightOffset,
    lightStrength,
    hueNoiseScale,
    hueStrength,
    boundarySharpDistance,
    boundaryBleedDistance,
    boundaryEdgeBand,
    boundaryDensityBoost,
  ];
}

/// Seam between a shader-driven [`MirkRenderer`] and the GPU: populates the
/// 42 uniform slots + the SDF sampler and draws the viewport rect.
///
/// Injected into `AtmosphericMirkRenderer` / `HeavenlyCloudsMirkRenderer`
/// so the headless test suite can observe every forwarded value through
/// `RecordingFogShaderRenderer` — `ui.FragmentShader` cannot be faked
/// (`base` class) and `FragmentProgram.fromAsset` needs a real GPU.
abstract class FogShaderRenderer {
  /// Populates the 42 slots + the sampler on [shader] and draws
  /// `Offset.zero & size` on [canvas]. Returns `false` if nothing was drawn
  /// (production: [shader] is `null` while the program loads or after a
  /// load failure → the caller paints its CPU fallback).
  ///
  /// [pixelOrigin] / [zoomScale] / [sdfRect] come straight from the
  /// `MirkPaintContext` (already platform-corrected). [tunables] must carry
  /// every key of [FogShaderTunableKey.all].
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
  });
}

/// Production [FogShaderRenderer] — delegates to the locked
/// [FogShaderUniforms.setAll] entry point then issues ONE `drawRect` with the
/// shader-bound [Paint]. Const-constructable so renderers default to it with
/// zero ceremony.
class FragmentShaderFogRenderer implements FogShaderRenderer {
  /// Creates the stateless production renderer.
  const FragmentShaderFogRenderer();

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
    if (shader == null) return false;
    FogShaderUniforms.setAll(
      shader,
      resolution: size,
      time: timeSeconds,
      pixelOrigin: pixelOrigin,
      baseArgb: baseArgb,
      baseAlpha: baseAlpha,
      highlightArgb: highlightArgb,
      shadowArgb: shadowArgb,
      driftZFar: _requireTunable(tunables, FogShaderTunableKey.driftZFar),
      driftZMid: _requireTunable(tunables, FogShaderTunableKey.driftZMid),
      driftZNear: _requireTunable(tunables, FogShaderTunableKey.driftZNear),
      scaleFar: _requireTunable(tunables, FogShaderTunableKey.scaleFar),
      scaleMid: _requireTunable(tunables, FogShaderTunableKey.scaleMid),
      scaleNear: _requireTunable(tunables, FogShaderTunableKey.scaleNear),
      opacityFar: _requireTunable(tunables, FogShaderTunableKey.opacityFar),
      opacityMid: _requireTunable(tunables, FogShaderTunableKey.opacityMid),
      opacityNear: _requireTunable(tunables, FogShaderTunableKey.opacityNear),
      curlAmplitude: _requireTunable(tunables, FogShaderTunableKey.curlAmplitude),
      curlScale: _requireTunable(tunables, FogShaderTunableKey.curlScale),
      lightDirRadians: _requireTunable(tunables, FogShaderTunableKey.lightDirRadians),
      lightOffset: _requireTunable(tunables, FogShaderTunableKey.lightOffset),
      lightStrength: _requireTunable(tunables, FogShaderTunableKey.lightStrength),
      hueNoiseScale: _requireTunable(tunables, FogShaderTunableKey.hueNoiseScale),
      hueStrength: _requireTunable(tunables, FogShaderTunableKey.hueStrength),
      boundarySharpDistance: _requireTunable(tunables, FogShaderTunableKey.boundarySharpDistance),
      boundaryBleedDistance: _requireTunable(tunables, FogShaderTunableKey.boundaryBleedDistance),
      boundaryEdgeBand: _requireTunable(tunables, FogShaderTunableKey.boundaryEdgeBand),
      boundaryDensityBoost: _requireTunable(tunables, FogShaderTunableKey.boundaryDensityBoost),
      sdfRect: sdfRect,
      zoomScale: zoomScale,
      sdfImage: sdfImage,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    return true;
  }

  /// A missing key is a programming error in the calling renderer (the 20
  /// keys are a fixed contract), so it propagates as [ArgumentError] rather
  /// than being defaulted silently.
  static double _requireTunable(Map<String, double> tunables, String key) {
    final double? value = tunables[key];
    if (value == null) {
      throw ArgumentError.value(tunables, 'tunables', 'missing shader tunable "$key" (expected every key of FogShaderTunableKey.all)');
    }
    return value;
  }
}
