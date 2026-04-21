// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';

import '../../fakes/fake_map_view.dart';

/// Fake [ActiveSessionController] for MapCameraController tests. Emits
/// a `Tracking` state with controllable `lastFix` — the unit under test
/// reads the controller via `ref.listen` (session listener) and
/// `ref.read` (openForSession latest-fix lookup).
///
/// The real controller's `build()` returns `FutureOr<ActiveSessionState>`,
/// which Riverpod surfaces as an `AsyncValue<ActiveSessionState>` state.
/// The fake returns the Tracking variant synchronously so consumers see
/// `AsyncData(Tracking(...))` on first read.
class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController({required this.seededSessionId, required this.seededStartedAt});

  final SessionId seededSessionId;
  final DateTime seededStartedAt;

  @override
  ActiveSessionState build() {
    // Start in a Tracking state with no fix — matches the
    // "session open, no GPS yet" scenario.
    return Tracking(sessionId: seededSessionId, startedAtUtc: seededStartedAt, fixCount: 0, distanceFilterMeters: kDefaultDistanceFilterMeters);
  }

  /// Simulates a new fix arriving from the GPS stream — updates the
  /// Tracking state's lastFix. MapCameraController observes via
  /// `ref.listen`.
  void pushFix(Fix fix) {
    final currentValue = state.value;
    if (currentValue is Tracking) {
      state = AsyncData(currentValue.copyWith(fixCount: currentValue.fixCount + 1, lastFix: fix));
    }
  }
}

Fix _mkFix({required double lat, required double lon, DateTime? at, required SessionId sessionId}) {
  return Fix(
    id: FixId.parse('fix_01ARZ3NDEKTSV4RRFFQ69G5FAV'),
    sessionId: sessionId,
    recordedAtUtc: at ?? DateTime.utc(2026, 4, 21, 10),
    recordedAtOffsetMinutes: 120,
    latitude: lat,
    longitude: lon,
    accuracyMeters: 10.0,
    speedMps: 1.5,
    headingDegrees: 90.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final SessionId sid = SessionId.parse('sess_01ARZ3NDEKTSV4RRFFQ69G5FAV');
  final DateTime sessionStart = DateTime.utc(2026, 4, 21, 9);

  ProviderContainer makeContainer({Fix? initialFix}) {
    final container = ProviderContainer(
      overrides: [
        activeSessionControllerProvider.overrideWith(() {
          final ctrl = _FakeActiveSessionController(seededSessionId: sid, seededStartedAt: sessionStart);
          // If an initial fix is supplied, push it post-build so the
          // Tracking state reflects it. We do this via a post-construction
          // tweak — the cleaner shape would be to thread the fix into
          // the build but Riverpod codegen does not take fake-ctrl
          // args, so we leverage `ref.read(...notifier)` in the test body.
          return ctrl;
        }),
      ],
    );
    if (initialFix != null) {
      final fake = container.read(activeSessionControllerProvider.notifier) as _FakeActiveSessionController;
      fake.pushFix(initialFix);
    }
    return container;
  }

  group('MapCameraController — build + attach', () {
    test('initial state is Idle', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final state = container.read(mapCameraControllerProvider);
      expect(state, isA<MapCameraIdle>());
    });

    test('openForSession with a pre-existing fix centres the camera at Z=kInitialSessionMapZoom + enables follow-me', () async {
      final Fix fix = _mkFix(lat: 48.8566, lon: 2.3522, sessionId: sid);
      final container = makeContainer(initialFix: fix);
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);

      // Trigger the controller build BEFORE openForSession so attach is wired.
      container.read(mapCameraControllerProvider);

      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);

      expect(fakeMapView.cameraMovesObserved, hasLength(1));
      expect(fakeMapView.cameraMovesObserved.single.latitude, closeTo(48.8566, 1e-6));
      expect(fakeMapView.cameraMovesObserved.single.longitude, closeTo(2.3522, 1e-6));
      expect(fakeMapView.cameraMovesObserved.single.zoom, equals(kInitialSessionMapZoom.toDouble()));
      expect(fakeMapView.followMeEnabled, isTrue);
      expect(container.read(mapCameraControllerProvider), isA<MapCameraFollowing>());
      // Wait a microtask for the fire-and-forget setUserLocation to
      // drain. Regression guard for the 2026-04-21 device-smoke bug:
      // openForSession used to move the camera without priming the
      // puck, so the blue dot only appeared on the second fix.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(fakeMapView.lastUserLocationSet, equals(fix));
    });

    test('openForSession WITHOUT a fix transitions to Centering; next fix drives Centering → Following', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);

      container.read(mapCameraControllerProvider);
      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);

      // No fix yet — state is Centering + camera has not moved.
      expect(container.read(mapCameraControllerProvider), isA<MapCameraCentering>());
      expect(fakeMapView.cameraMovesObserved, isEmpty);

      // Push a fix; listener fires.
      final Fix fix = _mkFix(lat: 52.5200, lon: 13.4050, sessionId: sid);
      final fake = container.read(activeSessionControllerProvider.notifier) as _FakeActiveSessionController;
      fake.pushFix(fix);
      // Wait a microtask for ref.listen to fire.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(mapCameraControllerProvider), isA<MapCameraFollowing>());
      expect(fakeMapView.cameraMovesObserved, hasLength(1));
      expect(fakeMapView.followMeEnabled, isTrue);
    });
  });

  group('MapCameraController — follow-me lifecycle', () {
    test('new fix while Following pans the camera + preserves current zoom', () async {
      final Fix firstFix = _mkFix(lat: 48.0, lon: 2.0, sessionId: sid);
      final container = makeContainer(initialFix: firstFix);
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(mapCameraControllerProvider);
      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);
      expect(fakeMapView.cameraMovesObserved, hasLength(1));

      // Second fix — controller pans at current zoom.
      final Fix secondFix = _mkFix(lat: 48.5, lon: 2.5, sessionId: sid, at: DateTime.utc(2026, 4, 21, 10, 0, 5));
      final fake = container.read(activeSessionControllerProvider.notifier) as _FakeActiveSessionController;
      fake.pushFix(secondFix);
      await Future<void>.delayed(Duration.zero);

      expect(fakeMapView.cameraMovesObserved, hasLength(2));
      expect(fakeMapView.cameraMovesObserved[1].latitude, closeTo(48.5, 1e-6));
      expect(fakeMapView.cameraMovesObserved[1].zoom, equals(kInitialSessionMapZoom.toDouble()));
    });

    test('manual viewport update transitions Following → FreePan + drops follow-me', () async {
      final Fix fix = _mkFix(lat: 48.0, lon: 2.0, sessionId: sid);
      final container = makeContainer(initialFix: fix);
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(mapCameraControllerProvider);
      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);
      expect(container.read(mapCameraControllerProvider), isA<MapCameraFollowing>());

      // Wait past the pending-debounce window (1 s) so the next viewport
      // update counts as a user pan, NOT an echo of our own moveCameraTo.
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      fakeMapView.pushViewport(latitude: 40.0, longitude: 10.0, zoom: 12.0);
      // Let the listener fire + state update propagate.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(mapCameraControllerProvider), isA<MapCameraFreePan>());
      expect(fakeMapView.followMeEnabled, isFalse);
    });

    test('viewport update IMMEDIATELY after a controller moveCameraTo is treated as an echo, state stays Following', () async {
      final Fix fix = _mkFix(lat: 48.0, lon: 2.0, sessionId: sid);
      final container = makeContainer(initialFix: fix);
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(mapCameraControllerProvider);
      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);
      expect(container.read(mapCameraControllerProvider), isA<MapCameraFollowing>());

      // Immediate viewport update — simulates MapLibre's onCameraIdle
      // echoing our own moveCameraTo back to us.
      fakeMapView.pushViewport(latitude: 48.0, longitude: 2.0, zoom: kInitialSessionMapZoom.toDouble());
      await Future<void>.delayed(Duration.zero);

      // Still Following — the pending flag filtered the echo.
      expect(container.read(mapCameraControllerProvider), isA<MapCameraFollowing>());
      expect(fakeMapView.followMeEnabled, isTrue);
    });

    test('toggleFollowMe Following → FreePan disables follow-me; FreePan → Following re-centres + re-enables', () async {
      final Fix fix = _mkFix(lat: 48.0, lon: 2.0, sessionId: sid);
      final container = makeContainer(initialFix: fix);
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(mapCameraControllerProvider);
      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);
      expect(container.read(mapCameraControllerProvider), isA<MapCameraFollowing>());

      await container.read(mapCameraControllerProvider.notifier).toggleFollowMe();
      expect(container.read(mapCameraControllerProvider), isA<MapCameraFreePan>());
      expect(fakeMapView.followMeEnabled, isFalse);

      // Toggle back → re-centres at last fix + re-enables follow-me.
      final int movesBefore = fakeMapView.cameraMovesObserved.length;
      await container.read(mapCameraControllerProvider.notifier).toggleFollowMe();
      expect(container.read(mapCameraControllerProvider), isA<MapCameraFollowing>());
      expect(fakeMapView.followMeEnabled, isTrue);
      expect(fakeMapView.cameraMovesObserved.length, equals(movesBefore + 1));
    });
  });

  group('MapCameraController — user location puck', () {
    test('every incoming fix pushes setUserLocation(fix) into the MapView', () async {
      final Fix firstFix = _mkFix(lat: 48.0, lon: 2.0, sessionId: sid);
      final container = makeContainer(initialFix: firstFix);
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(mapCameraControllerProvider);
      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);

      // openForSession routes through the initial-fix path; _onFix not
      // fired. The listener drives subsequent fixes.
      final fake = container.read(activeSessionControllerProvider.notifier) as _FakeActiveSessionController;
      final Fix nextFix = _mkFix(lat: 48.1, lon: 2.1, sessionId: sid);
      fake.pushFix(nextFix);
      await Future<void>.delayed(Duration.zero);
      // setUserLocation is fire-and-forget; let the microtask drain twice
      // so the inner `unawaited(() async { await ... }())` lambda runs.
      await Future<void>.delayed(Duration.zero);

      expect(fakeMapView.lastUserLocationSet, equals(nextFix));
      expect(fakeMapView.methodLog.where((s) => s.startsWith('setUserLocation(')).length, greaterThanOrEqualTo(1));
    });

    test('session drops from Tracking to Idle → setUserLocation(null) clears the puck', () async {
      final Fix firstFix = _mkFix(lat: 48.0, lon: 2.0, sessionId: sid);
      final container = makeContainer(initialFix: firstFix);
      addTearDown(container.dispose);

      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(mapCameraControllerProvider);
      await container.read(mapCameraControllerProvider.notifier).openForSession(sid);

      // Push one in-session fix so the puck is set.
      final fake = container.read(activeSessionControllerProvider.notifier) as _FakeActiveSessionController;
      fake.pushFix(_mkFix(lat: 48.1, lon: 2.1, sessionId: sid));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(fakeMapView.lastUserLocationSet, isNotNull);

      // Transition to Idle (session stopped externally).
      fake.state = const AsyncData(Idle());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeMapView.lastUserLocationSet, isNull);
    });
  });
}
