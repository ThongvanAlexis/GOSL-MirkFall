// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

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
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

import '../../fakes/fake_mirk_renderer.dart';

VisibleMirkTile _tile() =>
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

  group('09-07 — MirkOverlay swap (MIRK-07)', () {
    final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

    testWidgets('invalidating activeMirkRendererProvider disposes the old renderer + paints with the new one', (tester) async {
      // Two distinct fake renderers; the override returns the current
      // value of `currentRenderer` so we can swap mid-test by calling
      // container.invalidate(...).
      final firstRenderer = FakeMirkRenderer();
      final secondRenderer = FakeMirkRenderer();
      var rendererSwapped = false;

      final container = ProviderContainer(
        overrides: [
          activeSessionControllerProvider.overrideWith(
            () => _FakeActiveSessionController(
              Tracking(sessionId: const SessionId('sess_swap'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
            ),
          ),
          // Mirror the production `ref.onDispose(renderer.dispose)`
          // wiring (plan 09-05 `activeMirkRendererProvider`) so the
          // swap test exercises the same lifecycle the live provider
          // ships.
          activeMirkRendererProvider.overrideWith((ref) async {
            final r = rendererSwapped ? secondRenderer : firstRenderer;
            ref.onDispose(r.dispose);
            return r;
          }),
          visibleMirkTilesProvider.overrideWith((ref) async => [_tile()]),
          // BUG-010 Option B Commit 4 — overlay now also watches the
          // disc-list provider; an empty list keeps the test focused on
          // the swap lifecycle (renderer.paint still fires, the disc-
          // path clip-path degenerates to the viewport rect).
          discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => const <RevealDisc>[]),
          mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
          mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(firstRenderer.paintCallCount, greaterThan(0));
      expect(firstRenderer.disposeCallCount, 0);
      expect(secondRenderer.paintCallCount, 0);

      // Trigger the swap.
      rendererSwapped = true;
      container.invalidate(activeMirkRendererProvider);
      // Drain provider rebuild + a Ticker tick so the new renderer
      // gets at least one paint.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Old renderer was disposed via ref.onDispose (plan 09-05).
      expect(firstRenderer.disposeCallCount, 1);
      // New renderer received at least one paint.
      expect(secondRenderer.paintCallCount, greaterThan(0));
    });

    testWidgets('overlay continues painting across multiple swaps', (tester) async {
      final renderers = <FakeMirkRenderer>[FakeMirkRenderer(), FakeMirkRenderer(), FakeMirkRenderer()];
      var index = 0;
      MirkRenderer current() => renderers[index];

      final container = ProviderContainer(
        overrides: [
          activeSessionControllerProvider.overrideWith(
            () => _FakeActiveSessionController(
              Tracking(sessionId: const SessionId('sess_swap_chain'), startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
            ),
          ),
          activeMirkRendererProvider.overrideWith((ref) async {
            final r = current();
            ref.onDispose(r.dispose);
            return r;
          }),
          visibleMirkTilesProvider.overrideWith((ref) async => [_tile()]),
          // BUG-010 Option B Commit 4 — overlay now also watches the
          // disc-list provider; an empty list keeps the test focused on
          // the swap lifecycle (renderer.paint still fires, the disc-
          // path clip-path degenerates to the viewport rect).
          discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => const <RevealDisc>[]),
          mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
          mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Two consecutive swaps.
      index = 1;
      container.invalidate(activeMirkRendererProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      index = 2;
      container.invalidate(activeMirkRendererProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // First two were disposed; last is alive.
      expect(renderers[0].disposeCallCount, 1);
      expect(renderers[1].disposeCallCount, 1);
      expect(renderers[2].disposeCallCount, 0);
      expect(renderers[2].paintCallCount, greaterThan(0));
    });
  });
}
