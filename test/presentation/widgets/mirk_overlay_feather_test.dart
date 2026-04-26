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
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/presentation/widgets/mirk_overlay.dart';

import '../../fakes/fake_mirk_renderer.dart';

/// Returns a 512-byte bitmap with a top-left 32×32 quadrant revealed
/// (bit=1) and the rest unrevealed (bit=0). Mirrors
/// `_render_helpers.makeHalfRevealedBitmap`.
Uint8List _halfRevealedBitmap() {
  final bytes = Uint8List(512);
  for (var j = 0; j < 32; j++) {
    for (var i = 0; i < 32; i++) {
      final bit = j * 64 + i;
      bytes[bit >> 3] |= 1 << (bit & 7);
    }
  }
  return bytes;
}

VisibleMirkTile _tile() =>
    VisibleMirkTile(parentX: 8456, parentY: 5959, bitmap: _halfRevealedBitmap(), tileNorthLat: 43.7, tileWestLon: 5.3, tileSouthLat: 43.5, tileEastLon: 5.5);

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
            visibleMirkTilesProvider.overrideWith((ref) async => [_tile()]),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => const <RevealDisc>[]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      // Cannot use pumpAndSettle — the Ticker keeps the tree
      // animating forever. Two pumps suffice: first to flush the
      // FutureProvider resolutions, second to drive a Ticker tick.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(fakeRenderer.paintCallCount, greaterThan(0), reason: 'overlay must invoke renderer.paint at least once after mount');
      // Painted with the right ingredients. BUG-010 Option B Commit 4:
      // the overlay now feeds `discs` from `discsInViewportProvider`
      // rather than `visibleTiles` (the legacy bitmap field is
      // defaulted to const [] and Commit 5 deletes it).
      final ctx = fakeRenderer.paintContexts.last;
      expect(ctx.zoomLevel, 14.0);
      expect(ctx.viewportBbox.north, 44.0);
      expect(ctx.discs, isEmpty, reason: 'override seeds an empty disc list — overlay still paints (fog over viewport rect)');
    });

    testWidgets('AtmosphericMirkRenderer paints without throwing when wired through the overlay', (tester) async {
      // End-to-end smoke: an atmospheric renderer driven through the
      // overlay's paint pass produces no exception (feather mask
      // application + simplex sampling all functional). Use the
      // const default config — every field already defaults to the
      // canonical Phase 09 constants, so there is nothing to override.
      final renderer = AtmosphericMirkRenderer(const AtmosphericConfig());
      addTearDown(renderer.dispose);

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
            visibleMirkTilesProvider.overrideWith((ref) async => [_tile()]),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => const <RevealDisc>[]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
            mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // No throw == success — Atmospheric is the renderer that owns the
      // BlurStyle.inner mask filter (feather) so this also exercises
      // that code path through the overlay's CustomPainter.
    });
  });

  testWidgets('Ticker drives paint calls across multiple frames', (tester) async {
    final fakeRenderer = FakeMirkRenderer();
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
          visibleMirkTilesProvider.overrideWith((ref) async => [_tile()]),
          discsInViewportProvider.overrideWith((ref, MirkViewportBbox _) async => const <RevealDisc>[]),
          mapViewportProvider.overrideWith(() => _SeededMapViewport(viewport)),
          mapViewportZoomProvider.overrideWith(() => _SeededMapViewportZoom(14.0)),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 256, height: 256, child: MirkOverlay()),
        ),
      ),
    );
    // Pump several frames — the Ticker should fire setState each one.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final paintsAfter3Frames = fakeRenderer.paintCallCount;
    expect(
      paintsAfter3Frames,
      greaterThanOrEqualTo(2),
      reason:
          'Ticker should drive at least 2 paints across 3 frames '
          '(tolerant for CustomPainter shouldRepaint policy)',
    );
    // sessionElapsed should advance from 0 between calls.
    final firstElapsed = fakeRenderer.paintContexts.first.sessionElapsed;
    final lastElapsed = fakeRenderer.paintContexts.last.sessionElapsed;
    expect(lastElapsed.inMicroseconds, greaterThanOrEqualTo(firstElapsed.inMicroseconds), reason: 'sessionElapsed monotonically increases with the Ticker');
  });
}
