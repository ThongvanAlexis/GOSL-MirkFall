// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/foundation.dart';
import 'package:mirkfall/config/constants.dart';

/// Runtime-mutable shadow of the `kMirkFog*` constants in
/// `lib/config/constants.dart`, exposed for the in-app live tuner.
///
/// ## Why this exists
///
/// During Phase 09 BUG-009 iteration the user has to walk physically with
/// the iOS sideload to validate fog parameters. Each constant tweak costs
/// a build / sideload / walk cycle (~10 minutes minimum), which makes
/// converging on a comfortable look impractical.
///
/// This singleton lets the on-device debug bottom sheet update each shader
/// uniform live: setters mutate the field and call [notifyListeners], the
/// renderers read [instance] per paint so the next 96 fps frame already
/// uses the new value, and a dedicated UI rebuilds when a slider changes.
///
/// ## Authority of the constants
///
/// `lib/config/constants.dart` REMAINS the source of truth. This class
/// only shadows them at runtime. [reset] returns every field to its
/// `kMirkFog*` default, and the constants are also what the user copies
/// back into the source file once a tuned look is approved.
///
/// ## Singleton, not Riverpod
///
/// The renderers are not Riverpod consumers — they live in
/// `lib/infrastructure/mirk/` and paint inside CustomPainter at 96 fps
/// without a `WidgetRef`. A plain `ChangeNotifier` singleton is the
/// minimal seam that lets both the renderer (read-per-paint, no
/// subscription) AND the tuner UI (rebuild on notify) share state. A
/// Riverpod `Notifier` would require either a `ProviderContainer` plumbed
/// through the renderer factory or a global `ref.read` — both heavier
/// than necessary for a debug tool.
class MirkRuntimeTunables extends ChangeNotifier {
  MirkRuntimeTunables._();

  /// Process-wide singleton. Lives for the duration of the app — the
  /// underlying ChangeNotifier never needs disposal.
  static final MirkRuntimeTunables instance = MirkRuntimeTunables._();

  // -----------------------------------------------------------------
  // Atmospheric drift speeds.
  // -----------------------------------------------------------------

  double _atmosphericDriftZFar = kMirkFogAtmosphericDriftZFar;
  double get atmosphericDriftZFar => _atmosphericDriftZFar;
  set atmosphericDriftZFar(double v) {
    if (_atmosphericDriftZFar == v) return;
    _atmosphericDriftZFar = v;
    notifyListeners();
  }

  double _atmosphericDriftZMid = kMirkFogAtmosphericDriftZMid;
  double get atmosphericDriftZMid => _atmosphericDriftZMid;
  set atmosphericDriftZMid(double v) {
    if (_atmosphericDriftZMid == v) return;
    _atmosphericDriftZMid = v;
    notifyListeners();
  }

  double _atmosphericDriftZNear = kMirkFogAtmosphericDriftZNear;
  double get atmosphericDriftZNear => _atmosphericDriftZNear;
  set atmosphericDriftZNear(double v) {
    if (_atmosphericDriftZNear == v) return;
    _atmosphericDriftZNear = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Atmospheric scales.
  // -----------------------------------------------------------------

  double _atmosphericScaleFar = kMirkFogAtmosphericScaleFar;
  double get atmosphericScaleFar => _atmosphericScaleFar;
  set atmosphericScaleFar(double v) {
    if (_atmosphericScaleFar == v) return;
    _atmosphericScaleFar = v;
    notifyListeners();
  }

  double _atmosphericScaleMid = kMirkFogAtmosphericScaleMid;
  double get atmosphericScaleMid => _atmosphericScaleMid;
  set atmosphericScaleMid(double v) {
    if (_atmosphericScaleMid == v) return;
    _atmosphericScaleMid = v;
    notifyListeners();
  }

  double _atmosphericScaleNear = kMirkFogAtmosphericScaleNear;
  double get atmosphericScaleNear => _atmosphericScaleNear;
  set atmosphericScaleNear(double v) {
    if (_atmosphericScaleNear == v) return;
    _atmosphericScaleNear = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Heavenly drift speeds.
  // -----------------------------------------------------------------

  double _heavenlyDriftZFar = kMirkFogHeavenlyDriftZFar;
  double get heavenlyDriftZFar => _heavenlyDriftZFar;
  set heavenlyDriftZFar(double v) {
    if (_heavenlyDriftZFar == v) return;
    _heavenlyDriftZFar = v;
    notifyListeners();
  }

  double _heavenlyDriftZMid = kMirkFogHeavenlyDriftZMid;
  double get heavenlyDriftZMid => _heavenlyDriftZMid;
  set heavenlyDriftZMid(double v) {
    if (_heavenlyDriftZMid == v) return;
    _heavenlyDriftZMid = v;
    notifyListeners();
  }

  double _heavenlyDriftZNear = kMirkFogHeavenlyDriftZNear;
  double get heavenlyDriftZNear => _heavenlyDriftZNear;
  set heavenlyDriftZNear(double v) {
    if (_heavenlyDriftZNear == v) return;
    _heavenlyDriftZNear = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Heavenly scales.
  // -----------------------------------------------------------------

  double _heavenlyScaleFar = kMirkFogHeavenlyScaleFar;
  double get heavenlyScaleFar => _heavenlyScaleFar;
  set heavenlyScaleFar(double v) {
    if (_heavenlyScaleFar == v) return;
    _heavenlyScaleFar = v;
    notifyListeners();
  }

  double _heavenlyScaleMid = kMirkFogHeavenlyScaleMid;
  double get heavenlyScaleMid => _heavenlyScaleMid;
  set heavenlyScaleMid(double v) {
    if (_heavenlyScaleMid == v) return;
    _heavenlyScaleMid = v;
    notifyListeners();
  }

  double _heavenlyScaleNear = kMirkFogHeavenlyScaleNear;
  double get heavenlyScaleNear => _heavenlyScaleNear;
  set heavenlyScaleNear(double v) {
    if (_heavenlyScaleNear == v) return;
    _heavenlyScaleNear = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Shared opacities.
  // -----------------------------------------------------------------

  double _opacityFar = kMirkFogOpacityFar;
  double get opacityFar => _opacityFar;
  set opacityFar(double v) {
    if (_opacityFar == v) return;
    _opacityFar = v;
    notifyListeners();
  }

  double _opacityMid = kMirkFogOpacityMid;
  double get opacityMid => _opacityMid;
  set opacityMid(double v) {
    if (_opacityMid == v) return;
    _opacityMid = v;
    notifyListeners();
  }

  double _opacityNear = kMirkFogOpacityNear;
  double get opacityNear => _opacityNear;
  set opacityNear(double v) {
    if (_opacityNear == v) return;
    _opacityNear = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Curl noise.
  // -----------------------------------------------------------------

  double _curlAmplitude = kMirkFogCurlAmplitude;
  double get curlAmplitude => _curlAmplitude;
  set curlAmplitude(double v) {
    if (_curlAmplitude == v) return;
    _curlAmplitude = v;
    notifyListeners();
  }

  double _curlScale = kMirkFogCurlScale;
  double get curlScale => _curlScale;
  set curlScale(double v) {
    if (_curlScale == v) return;
    _curlScale = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Faux directional shading.
  // -----------------------------------------------------------------

  double _lightDirRadians = kMirkFogLightDirRadians;
  double get lightDirRadians => _lightDirRadians;
  set lightDirRadians(double v) {
    if (_lightDirRadians == v) return;
    _lightDirRadians = v;
    notifyListeners();
  }

  double _lightOffset = kMirkFogLightOffset;
  double get lightOffset => _lightOffset;
  set lightOffset(double v) {
    if (_lightOffset == v) return;
    _lightOffset = v;
    notifyListeners();
  }

  double _lightStrength = kMirkFogLightStrength;
  double get lightStrength => _lightStrength;
  set lightStrength(double v) {
    if (_lightStrength == v) return;
    _lightStrength = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Hue variation.
  // -----------------------------------------------------------------

  double _hueNoiseScale = kMirkFogHueNoiseScale;
  double get hueNoiseScale => _hueNoiseScale;
  set hueNoiseScale(double v) {
    if (_hueNoiseScale == v) return;
    _hueNoiseScale = v;
    notifyListeners();
  }

  double _hueStrength = kMirkFogHueStrength;
  double get hueStrength => _hueStrength;
  set hueStrength(double v) {
    if (_hueStrength == v) return;
    _hueStrength = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Watercolour boundary.
  // -----------------------------------------------------------------

  double _boundarySharpDistance = kMirkFogBoundarySharpDistance;
  double get boundarySharpDistance => _boundarySharpDistance;
  set boundarySharpDistance(double v) {
    if (_boundarySharpDistance == v) return;
    _boundarySharpDistance = v;
    notifyListeners();
  }

  double _boundaryBleedDistance = kMirkFogBoundaryBleedDistance;
  double get boundaryBleedDistance => _boundaryBleedDistance;
  set boundaryBleedDistance(double v) {
    if (_boundaryBleedDistance == v) return;
    _boundaryBleedDistance = v;
    notifyListeners();
  }

  double _boundaryEdgeBand = kMirkFogBoundaryEdgeBand;
  double get boundaryEdgeBand => _boundaryEdgeBand;
  set boundaryEdgeBand(double v) {
    if (_boundaryEdgeBand == v) return;
    _boundaryEdgeBand = v;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Diagnostic — raw density visualisation toggle. Mirrors
  // [kMirkFogDebugOutputDensity]. Note: the GLSL `#define` paired with
  // this constant cannot be flipped at runtime — when this field flips
  // true, the shader keeps the production output unless the build also
  // flipped the `.frag` `#define`. Exposed here so the toggle is at
  // least visible for future shader work that routes the flag through
  // a uniform.
  // -----------------------------------------------------------------

  bool _debugOutputDensity = kMirkFogDebugOutputDensity;
  bool get debugOutputDensity => _debugOutputDensity;
  set debugOutputDensity(bool v) {
    if (_debugOutputDensity == v) return;
    _debugOutputDensity = v;
    notifyListeners();
  }

  /// Resets every tunable to its `kMirkFog*` default. Called by the
  /// "Reset all" button in the tuner sheet AND by tests that want a
  /// clean per-test state.
  void reset() {
    _atmosphericDriftZFar = kMirkFogAtmosphericDriftZFar;
    _atmosphericDriftZMid = kMirkFogAtmosphericDriftZMid;
    _atmosphericDriftZNear = kMirkFogAtmosphericDriftZNear;
    _atmosphericScaleFar = kMirkFogAtmosphericScaleFar;
    _atmosphericScaleMid = kMirkFogAtmosphericScaleMid;
    _atmosphericScaleNear = kMirkFogAtmosphericScaleNear;
    _heavenlyDriftZFar = kMirkFogHeavenlyDriftZFar;
    _heavenlyDriftZMid = kMirkFogHeavenlyDriftZMid;
    _heavenlyDriftZNear = kMirkFogHeavenlyDriftZNear;
    _heavenlyScaleFar = kMirkFogHeavenlyScaleFar;
    _heavenlyScaleMid = kMirkFogHeavenlyScaleMid;
    _heavenlyScaleNear = kMirkFogHeavenlyScaleNear;
    _opacityFar = kMirkFogOpacityFar;
    _opacityMid = kMirkFogOpacityMid;
    _opacityNear = kMirkFogOpacityNear;
    _curlAmplitude = kMirkFogCurlAmplitude;
    _curlScale = kMirkFogCurlScale;
    _lightDirRadians = kMirkFogLightDirRadians;
    _lightOffset = kMirkFogLightOffset;
    _lightStrength = kMirkFogLightStrength;
    _hueNoiseScale = kMirkFogHueNoiseScale;
    _hueStrength = kMirkFogHueStrength;
    _boundarySharpDistance = kMirkFogBoundarySharpDistance;
    _boundaryBleedDistance = kMirkFogBoundaryBleedDistance;
    _boundaryEdgeBand = kMirkFogBoundaryEdgeBand;
    _debugOutputDensity = kMirkFogDebugOutputDensity;
    notifyListeners();
  }
}
