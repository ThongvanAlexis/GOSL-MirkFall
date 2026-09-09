// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_layer_camera_snapshot_test.dart — invariant FOG-07

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';

import '../../_helpers/fake_map_camera.dart';
import '../../fakes/fake_mirk_renderer.dart';

/// FOG-07 KEYSTONE — `MapCamera.of(context)` is called EXACTLY ONCE per
/// `FogLayer.build` invocation.
///
/// The single most important same-canvas regression gate: it defends against
/// the BUG-014 family where the clip path, the projection and the shader
/// uniforms each read a slightly different `MapCamera`, producing the
/// slide-then-snap fog artefact Phase 09.1 exists to close.
///
/// The seam is `FogLayer.debugOnCameraRead` — a `static void Function()?`
/// invoked exactly once per build right before `MapCamera.of(context)`.
/// Production: null, zero overhead.
void main() {
  testWidgets('FogLayer reads MapCamera.of(context) exactly once per build (FOG-07 KEYSTONE)', (tester) async {
    final counter = CameraAccessCounter();
    FogLayer.debugOnCameraRead = counter.recordRead;
    addTearDown(() => FogLayer.debugOnCameraRead = null);

    final probe = FrameDeltaProbe();
    addTearDown(() async => probe.dispose());
    final fogTransformLogger = FogTransformLogger();
    addTearDown(fogTransformLogger.stop);
    final renderer = FakeMirkRenderer();

    // Harness with a controlled rebuild trigger — bumping the FlutterMap's
    // ValueKey through setState remounts the map (and the FogLayer) without
    // involving the gesture system.
    var rebuildKey = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  Expanded(
                    child: FlutterMap(
                      key: ValueKey<int>(rebuildKey),
                      options: const MapOptions(initialCenter: kTestMapCenter),
                      children: <Widget>[
                        FogLayer(
                          renderer: renderer,
                          discs: const <RevealDisc>[],
                          frameDeltaProbe: probe,
                          fogTransformLogger: fogTransformLogger,
                          isAndroid: false,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(key: const Key('rebuild-trigger'), onPressed: () => setState(() => rebuildKey++), child: const Text('rebuild')),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Initial pump → exactly 1 read.
    expect(counter.count, 1, reason: 'FOG-07: exactly one MapCamera.of(context) call per build');
    expect(renderer.paintCallCount, greaterThanOrEqualTo(1), reason: 'the layer delegates its paint to the injected MirkRenderer');

    await tester.tap(find.byKey(const Key('rebuild-trigger')));
    await tester.pump();
    expect(counter.count, 2, reason: 'FOG-07: each forced rebuild bumps readCount by exactly 1');

    await tester.tap(find.byKey(const Key('rebuild-trigger')));
    await tester.pump();
    expect(counter.count, 3, reason: 'FOG-07: third rebuild → readCount == 3 (never more, never fewer)');
  });
}
