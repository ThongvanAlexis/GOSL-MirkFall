// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';
import 'package:mirkfall/presentation/widgets/mirk_initial_reveal_fade.dart';

import '../../fakes/fake_mirk_renderer.dart';

/// Test-only mutable controller that swaps its emitted state on demand.
class _MutableActiveSessionController extends ActiveSessionController {
  _MutableActiveSessionController(this._initial);

  final ActiveSessionState _initial;

  @override
  ActiveSessionState build() => _initial;

  void emitState(ActiveSessionState next) {
    state = AsyncData(next);
  }
}

Tracking _tracking() => Tracking(
  sessionId: const SessionId('sess_fade'),
  startedAtUtc: DateTime.utc(2026, 4, 25, 10),
  fixCount: 0,
  distanceFilterMeters: kDefaultDistanceFilterMeters,
);

/// Longer than `kInitialRevealFadeInMs` — the fade has reached 1.0.
const Duration _pastFade = Duration(milliseconds: 600);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opacity stays at 0 while session is Idle', (tester) async {
    final controller = _MutableActiveSessionController(const Idle());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeSessionControllerProvider.overrideWith(() => controller)],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: MirkInitialRevealFade(child: SizedBox(width: 100, height: 100)),
        ),
      ),
    );
    await tester.pump();
    // Fade controller starts at 0 — FadeTransition.opacity reflects it.
    final FadeTransition fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(fade.opacity.value, 0.0);
  });

  testWidgets('opacity evolves 0 → 1 over 500 ms on Idle → Tracking transition', (tester) async {
    final controller = _MutableActiveSessionController(const Idle());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeSessionControllerProvider.overrideWith(() => controller)],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: MirkInitialRevealFade(child: SizedBox(width: 100, height: 100)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 0.0);

    // Trigger transition.
    controller.emitState(_tracking());
    await tester.pump();
    // Drive midway — opacity should be > 0 + < 1 with easeOut curve.
    await tester.pump(const Duration(milliseconds: 250));
    final mid = tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
    expect(mid, greaterThan(0.1));
    expect(mid, lessThan(1.0));

    // Advance past full duration.
    await tester.pump(const Duration(milliseconds: 300));
    final endOpacity = tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
    expect(endOpacity, 1.0);
  });

  testWidgets('inside a FlutterMap, a FogLayer child reads MapCamera.of through the FadeTransition and paints once faded in (09.1-07)', (tester) async {
    final controller = _MutableActiveSessionController(_tracking());
    final renderer = FakeMirkRenderer();
    final probe = FrameDeltaProbe();
    addTearDown(() async => probe.dispose());
    final fogTransformLogger = FogTransformLogger();
    addTearDown(fogTransformLogger.stop);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeSessionControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          home: FlutterMap(
            options: const MapOptions(initialCenter: LatLng(48.85, 2.35)),
            children: <Widget>[
              MirkInitialRevealFade(
                child: FogLayer(
                  renderer: renderer,
                  discs: const <RevealDisc>[],
                  frameDeltaProbe: probe,
                  fogTransformLogger: fogTransformLogger,
                  isAndroid: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // First build: `MapCamera.of(context)` resolved through the FadeTransition (no throw).
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(MirkInitialRevealFade), matching: find.byType(FogLayer)), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(FogLayer), matching: find.byType(FadeTransition)),
      findsWidgets,
      reason: 'the fade wraps the layer',
    );

    await tester.pump(_pastFade);
    // flutter_map has FadeTransitions of its own — read the one owned by MirkInitialRevealFade.
    final Finder fadeOfMirk = find.descendant(of: find.byType(MirkInitialRevealFade), matching: find.byType(FadeTransition));
    expect(tester.widget<FadeTransition>(fadeOfMirk).opacity.value, 1.0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(renderer.paintCallCount, greaterThan(0), reason: 'the layer paints through the fully faded-in FadeTransition');
  });

  testWidgets('session ends → opacity resets to 0 (idempotence guard re-arms)', (tester) async {
    final controller = _MutableActiveSessionController(_tracking());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeSessionControllerProvider.overrideWith(() => controller)],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: MirkInitialRevealFade(child: SizedBox(width: 100, height: 100)),
        ),
      ),
    );
    // Initial frame triggers the fade (build seeded Tracking →
    // listenManual fires immediately).
    await tester.pump();
    // Fade fully in.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 1.0);

    // End session — opacity should reset.
    controller.emitState(const Idle());
    await tester.pump();
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 0.0);
  });

  testWidgets('second Tracking transition replays the fade (idempotence guard re-fires)', (tester) async {
    final controller = _MutableActiveSessionController(const Idle());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeSessionControllerProvider.overrideWith(() => controller)],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: MirkInitialRevealFade(child: SizedBox(width: 100, height: 100)),
        ),
      ),
    );
    await tester.pump();

    // Cycle: Idle → Tracking → Idle → Tracking
    controller.emitState(_tracking());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    controller.emitState(const Idle());
    await tester.pump();
    controller.emitState(_tracking());
    await tester.pump();
    // At t=0 of the second fade, opacity is 0.
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 0.0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value, 1.0);
  });
}
