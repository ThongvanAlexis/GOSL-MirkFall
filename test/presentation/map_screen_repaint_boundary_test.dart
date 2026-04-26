// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

import '../fakes/fake_mirk_renderer.dart';
import '_harness.dart';

/// Plan 09-08 Task 2 — RepaintBoundary isolation regression guard (SC#4).
///
/// The mirk overlay sits inside its own [`RepaintBoundary`] in
/// [`MapScreen._buildMapStack`] so the per-frame `Ticker` that drives
/// [`MirkOverlay`]'s `setState` does NOT cascade rebuilds into the other
/// `Stack` siblings (attribution icon, follow-me FAB, country banner,
/// download progress chip).
///
/// Two complementary checks:
/// 1. Structural — `find.ancestor` confirms a [`RepaintBoundary`] sits
///    on the path between [`MirkOverlay`] and the test root.
/// 2. Behavioural — counter-wrapped sibling builders prove that 10
///    successive 16 ms pumps (Ticker frames) do not re-invoke any
///    sibling builder past the mount-time count.
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

/// Single 100 m disc — gives the overlay non-trivial geometry without
/// going through the legacy bitmap surface (BUG-010 Option B Commit 5).
RevealDisc _disc() =>
    RevealDisc(id: 'rvd_repaint_boundary', sessionId: 'sess_test', lat: 43.6, lon: 5.4, radiusMeters: 100.0, fixedAtUtc: DateTime.utc(2026, 4, 26));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('09-08 — MapScreen RepaintBoundary isolation (SC#4)', () {
    testWidgets('MirkOverlay ancestor chain contains a RepaintBoundary', (tester) async {
      final fakeRenderer = FakeMirkRenderer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(sessionId: const SessionId('sess_repaint_structural'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
              ),
            ),
            activeMirkRendererProvider.overrideWith((ref) async => fakeRenderer),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => <RevealDisc>[_disc()]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0))),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
          ],
          child: const TestMapScreenHarness(),
        ),
      );
      // Single pump — providers resolve synchronously through the
      // sealed seeders. Settling is impossible because the overlay
      // mounts a Ticker.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final Finder mirkFinder = find.byType(MirkOverlay);
      expect(mirkFinder, findsOneWidget, reason: 'overlay should mount inside the harness');

      final Finder ancestorBoundary = find.ancestor(of: mirkFinder, matching: find.byType(RepaintBoundary));
      expect(ancestorBoundary, findsWidgets, reason: 'MirkOverlay must have at least one RepaintBoundary ancestor');
    });

    testWidgets('Ticker frames do NOT rebuild sibling widgets (attribution, FAB, banner, chip)', (tester) async {
      int attrBuildCount = 0;
      int fabBuildCount = 0;
      int bannerBuildCount = 0;
      int chipBuildCount = 0;

      final fakeRenderer = FakeMirkRenderer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(sessionId: const SessionId('sess_repaint_behaviour'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
              ),
            ),
            activeMirkRendererProvider.overrideWith((ref) async => fakeRenderer),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => <RevealDisc>[_disc()]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0))),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
          ],
          child: TestMapScreenHarness(
            attributionBuilder: (ctx) {
              attrBuildCount++;
              return const SizedBox(width: 24, height: 24);
            },
            fabBuilder: (ctx) {
              fabBuildCount++;
              return const SizedBox(width: 56, height: 56);
            },
            bannerBuilder: (ctx) {
              bannerBuildCount++;
              return const SizedBox(width: 200, height: 40);
            },
            chipBuilder: (ctx) {
              chipBuildCount++;
              return const SizedBox(width: 80, height: 24);
            },
          ),
        ),
      );
      // Settle one frame so initial mount + provider futures resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Capture mount-time counts (a Builder may rebuild more than
      // once during initial layout/provider resolution; that's OK —
      // the SC#4 assertion is that *Ticker frames* don't re-trigger
      // siblings beyond what mount-time ordinarily costs).
      final int attrAtMount = attrBuildCount;
      final int fabAtMount = fabBuildCount;
      final int bannerAtMount = bannerBuildCount;
      final int chipAtMount = chipBuildCount;

      // Pump 10 successive Ticker frames. Each pump triggers the
      // overlay's setState (its Ticker fires every frame). If the
      // RepaintBoundary is correctly inserted, the sibling builders
      // are NOT re-invoked.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(attrBuildCount, attrAtMount, reason: 'attribution rebuilt during Ticker frames — RepaintBoundary leak');
      expect(fabBuildCount, fabAtMount, reason: 'FAB rebuilt during Ticker frames — RepaintBoundary leak');
      expect(bannerBuildCount, bannerAtMount, reason: 'banner rebuilt during Ticker frames — RepaintBoundary leak');
      expect(chipBuildCount, chipAtMount, reason: 'chip rebuilt during Ticker frames — RepaintBoundary leak');
    });
  });
}
