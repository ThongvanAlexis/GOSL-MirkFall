// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/presentation/widgets/map_follow_me_fab.dart';

/// Fake MapCameraController for widget tests — exposes `seedState` to
/// drive the rendered tint + assert `toggleFollowMe` delegation.
class _FakeMapCameraController extends MapCameraController {
  _FakeMapCameraController({required this.initialState});
  final MapCameraState initialState;
  int toggleCalls = 0;

  @override
  MapCameraState build() => initialState;

  @override
  Future<void> toggleFollowMe() async {
    toggleCalls++;
    // Flip state FreePan <-> Following for visual verification.
    final current = state;
    if (current is MapCameraFollowing) {
      state = MapCameraFreePan(sessionId: current.sessionId);
    } else if (current is MapCameraFreePan) {
      state = MapCameraFollowing(sessionId: current.sessionId);
    }
  }
}

void main() {
  final SessionId sid = SessionId.parse('sess_01ARZ3NDEKTSV4RRFFQ69G5FAV');

  testWidgets('renders with primary tint when MapCameraFollowing', (tester) async {
    final fake = _FakeMapCameraController(initialState: MapCameraFollowing(sessionId: sid));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapCameraControllerProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: Scaffold(body: MapFollowMeFab())),
      ),
    );
    await tester.pump();

    final FloatingActionButton fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    // Primary colour when Following.
    expect(fab.backgroundColor, isNotNull);
    expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
  });

  testWidgets('renders with secondary tint when NOT Following', (tester) async {
    final fake = _FakeMapCameraController(initialState: MapCameraFreePan(sessionId: sid));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapCameraControllerProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: Scaffold(body: MapFollowMeFab())),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.gps_not_fixed), findsOneWidget);
  });

  testWidgets('tap delegates to toggleFollowMe on the controller', (tester) async {
    final fake = _FakeMapCameraController(initialState: MapCameraFreePan(sessionId: sid));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapCameraControllerProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: Scaffold(body: MapFollowMeFab())),
      ),
    );
    await tester.pump();
    expect(fake.toggleCalls, equals(0));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(fake.toggleCalls, equals(1));
  });
}
