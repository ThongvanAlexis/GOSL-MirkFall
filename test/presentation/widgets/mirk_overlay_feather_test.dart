// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

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
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

import '../../fakes/fake_map_view.dart';
import '../../fakes/fake_mirk_renderer.dart';

/// Single 100 m disc at the centre of the test viewport — gives the
/// overlay non-trivial reveal geometry to project (BUG-010 Option B
/// Commit 5 — replaces the half-revealed-quadrant bitmap fixture).
RevealDisc _disc() =>
    RevealDisc(id: 'rvd_feather_centre', sessionId: 'sess_test', lat: 43.6, lon: 5.4, radiusMeters: 100.0, fixedAtUtc: DateTime.utc(2026, 4, 26));

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

  group('09-07 — MirkOverlay feather (MIRK-01)', () {
    testWidgets('paints via the active renderer when prerequisites resolved', (tester) async {
      final fakeRenderer = FakeMirkRenderer();
      final fakeMapView = FakeMapView();
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(sessionId: const SessionId('sess_test'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
              ),
            ),
            activeMirkRendererProvider.overrideWith((ref) async => fakeRenderer),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => <RevealDisc>[_disc()]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
            mapViewHolderProvider.overrideWithValue(fakeMapView),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      // First pump resolves the FutureProvider overrides. Second pump
      // advances past the 50 ms throttle gate so the Ticker fires
      // _scheduleRender → _renderAndPush. renderer.paint() is
      // synchronous and fires before the async toImage() call.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 51));

      expect(fakeRenderer.paintCallCount, greaterThan(0), reason: 'overlay must invoke renderer.paint at least once after mount');
      // Painted with the right ingredients. BUG-010 Option B Commit 5:
      // the overlay feeds `discs` from `discsInViewportProvider` (the
      // canonical reveal input post-Commit-5).
      final ctx = fakeRenderer.paintContexts.last;
      expect(ctx.zoomLevel, 14.0);
      // BUG-014 padded viewport: the overlay renders for a padded bbox
      // (3x the visible area) so the fog stays map-locked during panning.
      // The original viewport north=44, dLat=1, padded north=44+1*1.0=45.
      expect(ctx.viewportBbox.north, 45.0);
      expect(ctx.discs, hasLength(1), reason: 'overlay routes the discsInViewportProvider list verbatim');
      expect(ctx.discs.single.id, 'rvd_feather_centre');
    });

    testWidgets('AtmosphericMirkRenderer paints without throwing when wired through the overlay', (tester) async {
      // End-to-end smoke: an atmospheric renderer driven through the
      // overlay's offscreen render pipeline produces no exception (feather
      // mask application + simplex sampling all functional). Use the
      // const default config — every field already defaults to the
      // canonical Phase 09 constants, so there is nothing to override.
      final renderer = AtmosphericMirkRenderer(const AtmosphericConfig());
      addTearDown(renderer.dispose);

      final fakeMapView = FakeMapView();
      final viewport = MirkViewportBbox(south: 43.5, west: 5.3, north: 43.7, east: 5.5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(sessionId: const SessionId('sess_atmospheric'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
              ),
            ),
            activeMirkRendererProvider.overrideWith((ref) async => renderer),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => <RevealDisc>[_disc()]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
            mapViewHolderProvider.overrideWithValue(fakeMapView),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 51));
      // No throw == success — Atmospheric is the renderer that owns the
      // BlurStyle.inner mask filter (feather) so this also exercises
      // that code path through the offscreen render pipeline.
    });
  });

  testWidgets('Ticker drives paint calls across multiple frames', (tester) async {
    final fakeRenderer = FakeMirkRenderer();
    final fakeMapView = FakeMapView();
    final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSessionControllerProvider.overrideWith(
            () => _FakeActiveSessionController(
              Tracking(sessionId: const SessionId('sess_ticker'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
            ),
          ),
          activeMirkRendererProvider.overrideWith((ref) async => fakeRenderer),
          discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => <RevealDisc>[_disc()]),
          mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
          mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
          mapViewHolderProvider.overrideWithValue(fakeMapView),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
        ),
      ),
    );

    // Pump to resolve providers, then past the 50 ms throttle gate.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 51));
    final paintsAfterFirstRender = fakeRenderer.paintCallCount;
    expect(paintsAfterFirstRender, greaterThanOrEqualTo(1), reason: 'First render must fire after the throttle gate passes');

    // Flush the async toImage() pipeline so _renderInFlight resets.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    // Pump another throttle window to trigger a second render.
    await tester.pump(const Duration(milliseconds: 51));
    final paintsAfterSecondRender = fakeRenderer.paintCallCount;
    expect(paintsAfterSecondRender, greaterThan(paintsAfterFirstRender), reason: 'Ticker should drive additional paint calls after the async pipeline flushes');

    // sessionElapsed should advance between paint calls.
    final firstElapsed = fakeRenderer.paintContexts.first.sessionElapsed;
    final lastElapsed = fakeRenderer.paintContexts.last.sessionElapsed;
    expect(lastElapsed.inMicroseconds, greaterThan(firstElapsed.inMicroseconds), reason: 'sessionElapsed monotonically increases with the Ticker');
  });
}
