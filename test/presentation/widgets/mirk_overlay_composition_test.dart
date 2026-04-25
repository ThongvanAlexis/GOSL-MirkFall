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
import 'package:mirkfall/application/providers/visible_mirk_tiles_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

import '../../fakes/fake_mirk_renderer.dart';

VisibleMirkTile _allUnrevealedTile() => VisibleMirkTile(
  parentX: 8456,
  parentY: 5959,
  bitmap: Uint8List(512),
  tileNorthLat: 43.7,
  tileWestLon: 5.3,
  tileSouthLat: 43.5,
  tileEastLon: 5.5,
);

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

  group('09-07 — MirkOverlay composition (MAP-04)', () {
    testWidgets('renders SizedBox.shrink while session is Idle', (
      tester,
    ) async {
      final fakeRenderer = FakeMirkRenderer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(const Idle()),
            ),
            activeMirkRendererProvider.overrideWith(
              (ref) async => fakeRenderer,
            ),
            visibleMirkTilesProvider.overrideWith((ref) async => const []),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(null)),
            mapViewportZoomProvider.overrideWith(
              () => _SeededMapViewportZoom(null),
            ),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // No CustomPaint subtree under the overlay → renderer not called.
      expect(fakeRenderer.paintCallCount, 0);
    });

    testWidgets('renders SizedBox.shrink while viewport is null', (
      tester,
    ) async {
      final fakeRenderer = FakeMirkRenderer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(
                  sessionId: const SessionId('sess_no_viewport'),
                  startedAtUtc: DateTime.utc(2026, 4, 25),
                  fixCount: 0,
                  distanceFilterMeters: 5,
                ),
              ),
            ),
            activeMirkRendererProvider.overrideWith(
              (ref) async => fakeRenderer,
            ),
            visibleMirkTilesProvider.overrideWith(
              (ref) async => [_allUnrevealedTile()],
            ),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(null)),
            mapViewportZoomProvider.overrideWith(
              () => _SeededMapViewportZoom(14.0),
            ),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(fakeRenderer.paintCallCount, 0);
    });

    testWidgets('renders MirkOverlay widget — finder hits the public widget', (
      tester,
    ) async {
      // Smoke check: MirkOverlay's widget identity is reachable from the
      // tree even when prerequisites are unresolved (returns
      // SizedBox.shrink internally — overlay still mounted).
      await tester.pumpWidget(
        const ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 100, height: 100, child: MirkOverlay()),
          ),
        ),
      );
      // Don't pumpAndSettle — providers are unconfigured AsyncValues
      // that loop awaiting (no real store backs them). Single pump
      // exercises the build path.
      await tester.pump();
      expect(find.byType(MirkOverlay), findsOneWidget);
    });

    testWidgets('paints with all-zero bitmap tile (entire tile = fog)', (
      tester,
    ) async {
      final fakeRenderer = FakeMirkRenderer();
      final viewport = MirkViewportBbox(
        south: 43.0,
        west: 5.0,
        north: 44.0,
        east: 6.0,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(
              () => _FakeActiveSessionController(
                Tracking(
                  sessionId: const SessionId('sess_fog_tile'),
                  startedAtUtc: DateTime.utc(2026, 4, 25),
                  fixCount: 0,
                  distanceFilterMeters: 5,
                ),
              ),
            ),
            activeMirkRendererProvider.overrideWith(
              (ref) async => fakeRenderer,
            ),
            visibleMirkTilesProvider.overrideWith(
              (ref) async => [_allUnrevealedTile()],
            ),
            mapViewportProvider.overrideWith(
              () => _SeededMapViewport(viewport),
            ),
            mapViewportZoomProvider.overrideWith(
              () => _SeededMapViewportZoom(14.0),
            ),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Renderer was invoked + received the all-zero bitmap.
      expect(fakeRenderer.paintCallCount, greaterThan(0));
      final ctx = fakeRenderer.paintContexts.last;
      expect(ctx.visibleTiles.first.bitmap.every((b) => b == 0), isTrue);
    });
  });
}
