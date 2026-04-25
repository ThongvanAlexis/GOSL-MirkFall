// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/presentation/widgets/mirk_initial_reveal_fade.dart';

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
