// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/providers/revealed_disc_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import '../../fakes/fake_revealed_disc_store.dart';

/// Sealed-state stub for `ActiveSessionController`. Mirrors the helper
/// shape used in `visible_mirk_tiles_provider_test.dart`.
class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._initial);
  final ActiveSessionState _initial;

  @override
  ActiveSessionState build() => _initial;
}

ProviderContainer _buildContainer({required ActiveSessionState sessionState, required FakeRevealedDiscStore store}) {
  return ProviderContainer(
    overrides: [
      activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(sessionState)),
      revealedDiscStoreProvider.overrideWith((ref) async => store),
    ],
  );
}

const SessionId _testSessionId = SessionId('sess_01HRDISCVIEWPORTTEST00000000');

RevealDisc _buildDisc({required double lat, required double lon, double radiusMeters = 25.0, String idSuffix = 'AA'}) => RevealDisc(
  id: 'rvd_01HRDISCVIEWPORTTEST00000$idSuffix',
  sessionId: _testSessionId.value,
  lat: lat,
  lon: lon,
  radiusMeters: radiusMeters,
  fixedAtUtc: DateTime.utc(2026, 4, 25, 12),
);

void main() {
  group('discsInViewportProvider — BUG-010 Option B Commit 4', () {
    test('returns empty list when no session is active', () async {
      final store = FakeRevealedDiscStore()..discs.add(_buildDisc(lat: 43.298, lon: 5.39, idSuffix: '01'));
      final container = _buildContainer(sessionState: const Idle(), store: store);
      addTearDown(container.dispose);

      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final discs = await container.read(discsInViewportProvider(viewport: viewport).future);
      expect(discs, isEmpty);
    });

    test('returns empty list when active session has no discs in bbox', () async {
      // Session is tracking, but every seeded disc is far from the viewport.
      final store = FakeRevealedDiscStore()..discs.add(_buildDisc(lat: 0.0, lon: 0.0, idSuffix: '02'));
      final container = _buildContainer(
        sessionState: Tracking(sessionId: _testSessionId, startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
        store: store,
      );
      addTearDown(container.dispose);

      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final discs = await container.read(discsInViewportProvider(viewport: viewport).future);
      expect(discs, isEmpty);
    });

    test('returns only discs intersecting the viewport — far discs filtered out', () async {
      final inside = _buildDisc(lat: 43.5, lon: 5.5, idSuffix: '03');
      final outside = _buildDisc(lat: 0.0, lon: 0.0, idSuffix: '04');
      final store = FakeRevealedDiscStore()..discs.addAll(<RevealDisc>[inside, outside]);
      final container = _buildContainer(
        sessionState: Tracking(sessionId: _testSessionId, startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
        store: store,
      );
      addTearDown(container.dispose);

      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final discs = await container.read(discsInViewportProvider(viewport: viewport).future);
      expect(discs, hasLength(1));
      expect(discs.single.id, inside.id);
    });

    test('discs from a DIFFERENT session are not returned', () async {
      final mineInside = _buildDisc(lat: 43.5, lon: 5.5, idSuffix: '05');
      final otherInside = RevealDisc(
        id: 'rvd_01HRDISCVIEWPORTTEST0000006X',
        sessionId: 'sess_01HROTHERSESSIONTESTAAAAAAA',
        lat: 43.5,
        lon: 5.5,
        radiusMeters: 25.0,
        fixedAtUtc: DateTime.utc(2026, 4, 25, 12),
      );
      final store = FakeRevealedDiscStore()..discs.addAll(<RevealDisc>[mineInside, otherInside]);
      final container = _buildContainer(
        sessionState: Tracking(sessionId: _testSessionId, startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 0, distanceFilterMeters: 5),
        store: store,
      );
      addTearDown(container.dispose);

      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final discs = await container.read(discsInViewportProvider(viewport: viewport).future);
      expect(discs, hasLength(1));
      expect(discs.single.sessionId, _testSessionId.value);
    });
  });
}
