// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 Task 1 — compilable RED skeleton. The same-canvas
// implementation (FOG-06/07/12/13/18/19/21/23) lands in Task 2; this skeleton
// only carries the constructor contract so the FOG-07 keystone tests compile
// and fail at runtime (09.1-02 precedent: analyze stays green at every commit).

import 'package:flutter/widgets.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';

/// Same-canvas fog layer — child (direct or via a `FadeTransition`) of `FlutterMap`.
class FogLayer extends StatefulWidget {
  /// Creates the layer. Everything is constructor-injected (no Riverpod `ref`).
  const FogLayer({
    super.key,
    required this.renderer,
    required this.discs,
    this.currentFix,
    required this.frameDeltaProbe,
    required this.fogTransformLogger,
    this.isAndroid,
    this.pixelRatio,
  });

  /// Active renderer; owned by its provider, never disposed by the layer.
  final MirkRenderer renderer;

  /// Snapshot of the reveal discs to punch through the fog.
  final List<RevealDisc> discs;

  /// Most recent accepted GPS fix (candlelight centre), or `null`.
  final Fix? currentFix;

  /// PERF-07 frame-delta probe (no-op unless verbose).
  final FrameDeltaProbe frameDeltaProbe;

  /// FOG-10 fog-transform rollup logger (no-op unless verbose).
  final FogTransformLogger fogTransformLogger;

  /// Platform flag; `null` → `Platform.isAndroid`. Test seam (FOG-21 / FOG-23).
  final bool? isAndroid;

  /// Device pixel ratio; `null` → `MediaQuery.devicePixelRatioOf(context)`.
  final double? pixelRatio;

  /// Keystone FOG-07 seam — invoked exactly once per build, right before `MapCamera.of(context)`.
  @visibleForTesting
  static void Function()? debugOnCameraRead;

  @override
  State<FogLayer> createState() => _FogLayerState();
}

class _FogLayerState extends State<FogLayer> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError('FogLayer same-canvas build lands in plan 09.1-04 Task 2');
}
