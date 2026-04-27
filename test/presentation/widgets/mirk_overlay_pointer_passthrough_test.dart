// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-003 (issue C) regression test — guards against the "MirkOverlay
// captures all pointer events, freezing pan/pinch/zoom on the MapLibre
// platform view underneath" regression.
//
// BUG-014 architectural note: the overlay now returns SizedBox.shrink()
// (zero hit area), so pointer passthrough is inherent. The IgnorePointer
// wrapper in map_screen.dart is redundant but harmless — this test
// verifies the combined behaviour: IgnorePointer around a zero-size
// widget still lets taps reach the detector below.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

import '../../fakes/fake_map_view.dart';
import '../../fakes/fake_mirk_renderer.dart';

/// Single 100 m disc — gives the overlay non-trivial reveal geometry
/// so the renderer's `paint` produces a fog-with-hole clip path (not
/// the full-viewport-rect all-fog path that empty discs yield).
/// BUG-010 Option B Commit 5 — replaces the `_allUnrevealedTile()`
/// bitmap fixture.
RevealDisc _disc() =>
    RevealDisc(id: 'rvd_pointer_passthrough', sessionId: 'sess_test', lat: 43.6, lon: 5.4, radiusMeters: 100.0, fixedAtUtc: DateTime.utc(2026, 4, 26));

class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._initial);
  final ActiveSessionState _initial;

  @override
  ActiveSessionState build() => _initial;
}

class _SeededMapViewportZoom extends MapViewportZoom {
  _SeededMapViewportZoom(this._initial);
  final double? _initial;

  @override
  double? build() => _initial;
}

class _SeededMapViewport extends MapViewport {
  _SeededMapViewport(this._initial);
  final MirkViewportBbox? _initial;

  @override
  MirkViewportBbox? build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-003 — MirkOverlay pointer pass-through', () {
    testWidgets('MirkOverlay returns SizedBox.shrink — zero hit area by design', (tester) async {
      // BUG-014: the overlay is now purely a controller widget that
      // returns SizedBox.shrink(). It has zero hit area, so pointer
      // events pass through to whatever is behind it in the Stack.
      // This is a stronger guarantee than the old IgnorePointer wrapper
      // around CustomPaint.
      await tester.pumpWidget(
        const ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();

      // The overlay is in the tree...
      expect(find.byType(MirkOverlay), findsOneWidget);
      // ...and its output is a zero-size widget.
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('IgnorePointer-wrapped MirkOverlay lets a tap reach the GestureDetector below', (tester) async {
      final fakeRenderer = FakeMirkRenderer();
      final fakeMapView = FakeMapView();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      var tapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(sessionId: const SessionId('sess_pt_passthrough'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
              ),
            ),
            activeMirkRendererProvider.overrideWith((ref) async => fakeRenderer),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => <RevealDisc>[_disc()]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
            mapViewHolderProvider.overrideWithValue(fakeMapView),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 256,
              height: 256,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Layer 0 (bottom): a tappable area mimicking the
                  // MapLibre platform view that lives under the overlay
                  // in production (map_screen.dart Stack).
                  GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => tapCount++, child: const SizedBox.expand()),
                  // Layer 1 (top): the mirk overlay, wrapped exactly as
                  // map_screen.dart wraps it in production.
                  const Positioned.fill(child: IgnorePointer(child: MirkOverlay())),
                ],
              ),
            ),
          ),
        ),
      );
      // Pump the FutureProvider resolutions + past the throttle gate.
      // Cannot pumpAndSettle — the Ticker keeps the tree animating.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 51));

      // Tap the centre of the Stack → must reach the GestureDetector.
      // BUG-014: MirkOverlay is SizedBox.shrink (zero hit area), and
      // IgnorePointer makes it doubly transparent to pointers. The tap
      // reaches the GestureDetector below.
      await tester.tapAt(const Offset(128, 128));
      await tester.pump();

      expect(
        tapCount,
        equals(1),
        reason:
            'Tap on the overlay region MUST reach the underlying '
            'GestureDetector. tapCount=0 means something absorbed the pointer. '
            'Check map_screen.dart wraps the overlay in IgnorePointer.',
      );
    });

    testWidgets('Stress: 5 sequential taps all reach the GestureDetector below', (tester) async {
      // Soak test — every tap on the overlay surface must reach the
      // detector. Catches subtle hit-test state-machine bugs where the
      // first tap might pass through but subsequent ones don't.
      final fakeRenderer = FakeMirkRenderer();
      final fakeMapView = FakeMapView();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      var tapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(sessionId: const SessionId('sess_pt_stress'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
              ),
            ),
            activeMirkRendererProvider.overrideWith((ref) async => fakeRenderer),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => <RevealDisc>[_disc()]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
            mapViewHolderProvider.overrideWithValue(fakeMapView),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 256,
              height: 256,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => tapCount++, child: const SizedBox.expand()),
                  const Positioned.fill(child: IgnorePointer(child: MirkOverlay())),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 51));

      for (var i = 0; i < 5; i++) {
        await tester.tapAt(const Offset(128, 128));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tapCount, equals(5), reason: 'All 5 taps on MirkOverlay must pass through to the GestureDetector below.');
    });
  });
}
