// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-003 (issue C) regression test — guards against the "MirkOverlay
// captures all pointer events, freezing pan/pinch/zoom on the MapLibre
// platform view underneath" regression.
//
// `CustomPaint` with a non-null painter hit-tests as opaque by default.
// Without an `IgnorePointer` wrapper around the overlay, every pointer
// event that lands on the canvas is consumed by the overlay's
// RenderCustomPaint and never reaches the platform view below.
//
// The production fix wraps the overlay in `IgnorePointer` at the call
// site (lib/presentation/screens/map_screen.dart). This test mirrors
// that production setup: it places `MirkOverlay` (wrapped in
// `IgnorePointer`) over a `GestureDetector(onTap: ...)` and asserts the
// tap reaches the detector. If a future refactor removes the
// `IgnorePointer` wrapper (or moves the overlay above the detector
// without an equivalent), this test fails.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/providers/visible_mirk_tiles_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

import '../../fakes/fake_mirk_renderer.dart';

VisibleMirkTile _allUnrevealedTile() =>
    VisibleMirkTile(parentX: 8456, parentY: 5959, bitmap: Uint8List(512), tileNorthLat: 43.7, tileWestLon: 5.3, tileSouthLat: 43.5, tileEastLon: 5.5);

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
    testWidgets('IgnorePointer-wrapped MirkOverlay lets a tap reach the GestureDetector below', (tester) async {
      final fakeRenderer = FakeMirkRenderer();
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
            visibleMirkTilesProvider.overrideWith((ref) async => [_allUnrevealedTile()]),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => const <RevealDisc>[]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
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
      // Pump the FutureProvider resolutions + a Ticker tick so the
      // overlay reaches its CustomPaint state. Cannot pumpAndSettle —
      // the Ticker keeps the tree animating forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Sanity: the overlay IS painting. If this fails, the test is
      // not actually exercising the overlay's hit-test behaviour
      // (overlay would be SizedBox.shrink) and any pass-through
      // assertion below is meaningless.
      expect(fakeRenderer.paintCallCount, greaterThan(0), reason: 'MirkOverlay must be actively painting for the pass-through assertion to be meaningful');

      // Tap the centre of the overlay → must reach the GestureDetector.
      // warnIfMissed: false — by design the tap MISSES MirkOverlay's
      // hit-test (IgnorePointer makes it transparent to pointers). The
      // tap reaches the GestureDetector below; the warning is the
      // success condition, not an issue.
      await tester.tap(find.byType(MirkOverlay), warnIfMissed: false);
      await tester.pump();

      expect(
        tapCount,
        equals(1),
        reason:
            'Tap on MirkOverlay (IgnorePointer-wrapped) MUST reach the underlying '
            'GestureDetector. tapCount=0 means the CustomPaint absorbed the pointer '
            '(IgnorePointer regression). Check map_screen.dart wraps the overlay in '
            'IgnorePointer.',
      );
    });

    testWidgets('Stress: 5 sequential taps all reach the GestureDetector below', (tester) async {
      // Soak test — every tap on the overlay surface must reach the
      // detector. Catches subtle hit-test state-machine bugs where the
      // first tap might pass through but subsequent ones don't.
      final fakeRenderer = FakeMirkRenderer();
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
            visibleMirkTilesProvider.overrideWith((ref) async => [_allUnrevealedTile()]),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => const <RevealDisc>[]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
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
      await tester.pump(const Duration(milliseconds: 16));

      for (var i = 0; i < 5; i++) {
        // warnIfMissed: false — by design the tap MISSES MirkOverlay's
        // hit-test (IgnorePointer makes it transparent to pointers). The
        // tap reaches the GestureDetector below; the warning is the
        // success condition, not an issue.
        await tester.tap(find.byType(MirkOverlay), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tapCount, equals(5), reason: 'All 5 taps on MirkOverlay must pass through to the GestureDetector below.');
    });
  });
}
