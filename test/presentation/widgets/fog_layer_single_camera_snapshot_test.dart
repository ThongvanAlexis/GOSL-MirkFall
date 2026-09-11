// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_layer_single_camera_snapshot_test.dart — invariant FOG-07

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';

import '../../_helpers/fake_map_camera.dart';
import '../../_helpers/recording_fog_shader_renderer.dart';

/// FOG-07 KEYSTONE with the production shader renderer — `MapCamera.of(context)`
/// is called EXACTLY ONCE per `FogLayer.build` EVEN when the injected renderer is
/// the `AtmosphericMirkRenderer` (shader path + SDF + wisps).
///
/// Mirrors `fog_layer_camera_snapshot_test.dart` (which uses `FakeMirkRenderer`);
/// pins that nothing on the renderer side (wisp projection, SDF rebuild,
/// shader uniforms) re-reads the camera — the renderer only ever sees a
/// `MirkPaintContext`. The atmospheric renderer logs its `FragmentProgram.fromAsset`
/// failure in the headless test environment and paints its CPU fallback; tolerated.
void main() {
  testWidgets(
    'FogLayer reads MapCamera.of(context) exactly once per build EVEN WITH AtmosphericMirkRenderer (FOG-07 keystone holds through the renderer seam)',
    (tester) async {
      final counter = CameraAccessCounter();
      FogLayer.debugOnCameraRead = counter.recordRead;
      addTearDown(() => FogLayer.debugOnCameraRead = null);

      final probe = FrameDeltaProbe();
      addTearDown(() async => probe.dispose());
      final fogTransformLogger = FogTransformLogger();
      addTearDown(fogTransformLogger.stop);
      final renderer = AtmosphericMirkRenderer(const AtmosphericConfig(), shaderRenderer: RecordingFogShaderRenderer());

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

      expect(counter.count, 1, reason: 'FOG-07: exactly one MapCamera.of(context) call per build with the atmospheric renderer wired.');

      await tester.tap(find.byKey(const Key('rebuild-trigger')));
      await tester.pump();
      expect(counter.count, 2, reason: 'FOG-07: each forced rebuild bumps readCount by exactly 1, shader path included.');

      await tester.tap(find.byKey(const Key('rebuild-trigger')));
      await tester.pump();
      expect(counter.count, 3, reason: 'FOG-07: third rebuild → readCount == 3 (never more, never fewer); the renderer MUST NOT add reads.');

      // The renderer is owned by the test (in production by the provider), not by
      // the layer — dispose it inside the test body so its SDF build / logger timers
      // are cancelled before the widget-test pending-timer check.
      await renderer.dispose();
    },
  );
}
