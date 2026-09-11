// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — shared harness of the `fog_*` widget tests. Folds the
// `_findFogPainter` / `_MockCanvas` / `_RecordingMockCanvas` idioms every POC test
// file repeated (`mirk-poc-debug` @ 90c9321) and adds `SpyMirkRenderer`, the
// MirkFall replacement for inspecting `RecordingFogShaderRenderer.renders` where
// the assertion is about the painter, not the shader.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';

import 'fake_map_camera.dart';

/// Tolerance on canvas-transform / translate arguments (POC `kPocCanvasTransformEpsilon`):
/// far below floating-point noise, orders of magnitude below the ~757 px regressions caught.
const double kTestCanvasTransformEpsilon = 1e-6;

/// Tolerance on `Path.getBounds()` after `Path.combine(difference, ...)` — the
/// path engine introduces ~1e-6 noise per axis on the disc oval.
const double kTestSubPixelTolerance = 1e-3;

/// Default widget viewport of the fog tests (POC portrait phone).
const Size kTestFogViewportSize = Size(400, 800);

/// One reveal disc at the test camera centre (POC fixture, 25 m by default).
RevealDisc centreTestDisc({double radiusMeters = 25.0, String id = 'rvd_test_centre'}) => RevealDisc(
  id: id,
  sessionId: 'sess_test',
  lat: kTestMapCenter.latitude,
  lon: kTestMapCenter.longitude,
  radiusMeters: radiusMeters,
  fixedAtUtc: DateTime.utc(2026, 5),
);

/// Mounts a real `FlutterMap` sized [viewportSize] with a `FogLayer` delegating
/// to [renderer]. The diagnostic loggers are constructed but never started (no
/// pending timers). Sizes the test screen to [viewportSize] LOGICAL pixels at
/// [devicePixelRatio] (1.0 by default) and pumps one extra frame so the first
/// build has run. [isAndroid] switches the FOG-21 / FOG-23 corrections on.
Future<void> pumpFogLayerInFlutterMap(
  WidgetTester tester, {
  required MirkRenderer renderer,
  List<RevealDisc> discs = const <RevealDisc>[],
  MapController? mapController,
  LatLng initialCenter = kTestMapCenter,
  double initialZoom = kTestMapZoom,
  Size viewportSize = kTestFogViewportSize,
  double devicePixelRatio = 1.0,
  bool isAndroid = false,
}) async {
  // The default test screen is 800×600 logical px: a taller SizedBox would be
  // clamped by the Scaffold body and camera.size would silently differ.
  tester.view.physicalSize = viewportSize * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final probe = FrameDeltaProbe();
  addTearDown(() async => probe.dispose());
  final fogTransformLogger = FogTransformLogger();
  addTearDown(fogTransformLogger.stop);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: initialCenter, initialZoom: initialZoom),
            children: <Widget>[
              FogLayer(renderer: renderer, discs: discs, frameDeltaProbe: probe, fogTransformLogger: fogTransformLogger, isAndroid: isAndroid),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Re-locates the `_FogPainter` underneath the `FogLayer` on every rebuild —
/// the painter is private, so tests drive it through the public `CustomPainter`
/// interface (`paint(canvas, size)`), the Flutter SDK's own `custom_paint_test` idiom.
CustomPainter findFogPainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(find.descendant(of: find.byType(FogLayer), matching: find.byType(CustomPaint)));
  final painter = customPaint.painter;
  if (painter == null) {
    fail('Expected FogLayer descendant CustomPaint to carry a non-null `painter`; got null.');
  }
  return painter;
}

/// `MirkRenderer` spy: records `(size, context)` per paint and draws ONE
/// viewport rect so a recording canvas sees the renderer's draw inside the
/// painter's save / translate / clip / restore block. With [inspectCanvas] the
/// spy also snapshots `getTransform()` and `getLocalClipBounds()` — only for
/// REAL canvases (a counting fake would see a second `getTransform` read).
class SpyMirkRenderer implements MirkRenderer {
  SpyMirkRenderer({this.inspectCanvas = false});

  final bool inspectCanvas;
  final List<Size> paintSizes = <Size>[];
  final List<MirkPaintContext> paintContexts = <MirkPaintContext>[];
  final List<Float64List> canvasTransforms = <Float64List>[];
  final List<Rect> localClipBounds = <Rect>[];
  final List<Duration> updateElapsed = <Duration>[];

  MirkPaintContext get lastContext => paintContexts.last;

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) {
    if (inspectCanvas) {
      canvasTransforms.add(canvas.getTransform());
      localClipBounds.add(canvas.getLocalClipBounds());
    }
    paintSizes.add(size);
    paintContexts.add(context);
    canvas.drawRect(Offset.zero & size, Paint());
  }

  @override
  void update(Duration elapsed) => updateElapsed.add(elapsed);

  @override
  Future<void> dispose() async {}
}

/// Minimal `Canvas` fake at identity transform — overrides only what
/// `_FogPainter.paint` + [SpyMirkRenderer.paint] call; anything else throws
/// through `Fake`, so a new Canvas call in the painter fails fast.
class IdentityCanvasFake extends Fake implements Canvas {
  @override
  void save() {}

  @override
  void restore() {}

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {}

  @override
  void translate(double dx, double dy) {}

  @override
  void drawRect(Rect rect, Paint paint) {}

  @override
  Float64List getTransform() => identityMatrixWithTranslation(tx: 0, ty: 0);
}

/// Records the FULL Canvas call sequence (op name + raw args) with a
/// configurable translation reported by `getTransform()`, so tests assert
/// ordering (translate BEFORE clipPath BEFORE the renderer's drawRect BEFORE
/// restore), argument values and call counts (single-snapshot at the matrix level).
class RecordingCanvasFake extends Fake implements Canvas {
  RecordingCanvasFake({required this.canvasTx, required this.canvasTy});

  final double canvasTx;
  final double canvasTy;

  /// Every operation in invocation order.
  final List<({String op, Object? args})> calls = <({String op, Object? args})>[];

  List<ui.Path> get clipPathCalls => calls.where((c) => c.op == 'clipPath').map((c) => c.args! as ui.Path).toList();

  List<(double, double)> get translateCallArgs => calls.where((c) => c.op == 'translate').map((c) => c.args! as (double, double)).toList();

  int get getTransformCallCount => calls.where((c) => c.op == 'getTransform').length;

  /// Index of the FIRST occurrence of each op.
  Map<String, int> get firstIndexByOp {
    final indexByOp = <String, int>{};
    for (var i = 0; i < calls.length; i++) {
      indexByOp.putIfAbsent(calls[i].op, () => i);
    }
    return indexByOp;
  }

  /// True iff `translate` was called BEFORE `clipPath` (false if either is missing).
  bool get translateBeforeClipPath {
    final indexByOp = firstIndexByOp;
    final translateIdx = indexByOp['translate'];
    final clipPathIdx = indexByOp['clipPath'];
    if (translateIdx == null || clipPathIdx == null) return false;
    return translateIdx < clipPathIdx;
  }

  @override
  void save() => calls.add((op: 'save', args: null));

  @override
  void restore() => calls.add((op: 'restore', args: null));

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) => calls.add((op: 'clipPath', args: path));

  @override
  void translate(double dx, double dy) => calls.add((op: 'translate', args: (dx, dy)));

  @override
  void drawRect(Rect rect, Paint paint) => calls.add((op: 'drawRect', args: rect));

  @override
  Float64List getTransform() {
    calls.add((op: 'getTransform', args: null));
    return identityMatrixWithTranslation(tx: canvasTx, ty: canvasTy);
  }
}

/// 4×4 column-major identity matrix with translation `(tx, ty)` in the slots
/// `Canvas.getTransform()` uses ([kCanvasTransformTxIndex] / [kCanvasTransformTyIndex]).
Float64List identityMatrixWithTranslation({required double tx, required double ty}) {
  final m = Float64List(16)
    ..[0] = 1.0
    ..[5] = 1.0
    ..[10] = 1.0
    ..[15] = 1.0;
  m[kCanvasTransformTxIndex] = tx;
  m[kCanvasTransformTyIndex] = ty;
  return m;
}
