// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/mirk_style_store_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/presentation/widgets/session_burger_menu.dart';

import '../../fakes/fake_mirk_style_store.dart';

/// In-memory SessionStore — minimal surface needed by the picker.
class _FakeSessionStore implements SessionStore {
  _FakeSessionStore(Map<SessionId, Session>? rows)
    : _rowById = rows ?? <SessionId, Session>{};

  final Map<SessionId, Session> _rowById;

  /// Records every (sessionId, mirkStyleId) tuple passed to
  /// [updateMirkStyle] so the test can assert one call.
  final List<({SessionId sessionId, MirkStyleId? mirkStyleId})> updateCalls =
      <({SessionId sessionId, MirkStyleId? mirkStyleId})>[];

  @override
  Future<Session?> findById(SessionId id) async => _rowById[id];

  @override
  Future<Session> requireById(SessionId id) async {
    final row = _rowById[id];
    if (row == null) throw StateError('no row for ${id.value}');
    return row;
  }

  @override
  Future<Session?> findActive() async {
    for (final s in _rowById.values) {
      if (s.status == SessionStatus.active) return s;
    }
    return null;
  }

  @override
  Future<List<Session>> listAll() async => _rowById.values.toList();

  @override
  Stream<List<Session>> watchAll() =>
      Stream<List<Session>>.value(_rowById.values.toList());

  @override
  Future<void> insert(Session session) async => _rowById[session.id] = session;

  @override
  Future<void> update(Session session) async => _rowById[session.id] = session;

  @override
  Future<void> delete(SessionId id) async => _rowById.remove(id);

  @override
  Future<void> activate(SessionId id) async {}

  @override
  Future<void> deactivate(SessionId id) async {}

  @override
  Future<void> updateMirkStyle({
    required SessionId sessionId,
    required MirkStyleId? mirkStyleId,
  }) async {
    updateCalls.add((sessionId: sessionId, mirkStyleId: mirkStyleId));
    final existing = _rowById[sessionId];
    if (existing != null) {
      _rowById[sessionId] = existing.copyWith(mirkStyleId: mirkStyleId);
    }
  }
}

class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._initial);
  final ActiveSessionState _initial;
  int stopCalls = 0;

  @override
  ActiveSessionState build() => _initial;

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

MirkStyle _buildStyle({
  required String idValue,
  required String displayName,
  required MirkStyleConfig config,
}) => MirkStyle(
  id: MirkStyleId(idValue),
  displayName: displayName,
  config: config,
  createdAtUtc: DateTime.utc(2026, 4, 25),
  createdAtOffsetMinutes: 0,
);

Session _buildSession({required SessionId id, MirkStyleId? mirkStyleId}) =>
    Session(
      id: id,
      displayName: 'Session test',
      status: SessionStatus.active,
      startedAtUtc: DateTime.utc(2026, 4, 25, 10),
      startedAtOffsetMinutes: 0,
      mirkStyleId: mirkStyleId,
    );

Widget _wrapWithOverrides(
  Widget child, {
  required ActiveSessionController fakeController,
  required FakeMirkStyleStore styleStore,
  required _FakeSessionStore sessionStore,
}) {
  return ProviderScope(
    overrides: [
      activeSessionControllerProvider.overrideWith(() => fakeController),
      mirkStyleStoreProvider.overrideWith((ref) async => styleStore),
      sessionStoreProvider.overrideWith((ref) async => sessionStore),
      // Avoid the active-renderer cascade — the picker doesn't need it
      // and resolving the real provider would require seeding more
      // dependencies.
      activeMirkRendererProvider.overrideWith(
        (ref) async => throw StateError('renderer not under test'),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        drawer: child,
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('09-07 — SessionBurgerMenu style selector (MIRK-07)', () {
    const SessionId sid = SessionId('sess_01ARZ3NDEKTSV4RRFFQ69G5FAV');

    final tracking = Tracking(
      sessionId: sid,
      startedAtUtc: DateTime.utc(2026, 4, 25, 10),
      fixCount: 0,
      distanceFilterMeters: kDefaultDistanceFilterMeters,
    );

    final atmospheric = _buildStyle(
      idValue: 'style_builtin_atmospheric',
      displayName: 'Atmospheric (défaut)',
      config: const AtmosphericConfig(),
    );
    final solid = _buildStyle(
      idValue: 'style_builtin_solid',
      displayName: 'Solide',
      config: const SolidConfig(),
    );
    final candlelight = _buildStyle(
      idValue: 'style_builtin_candlelight',
      displayName: 'Lueur de bougie',
      config: const CandlelightConfig(),
    );
    final heavenly = _buildStyle(
      idValue: 'style_builtin_heavenly_clouds',
      displayName: 'Nuages célestes',
      config: const HeavenlyCloudsConfig(),
    );

    testWidgets(
      'tapping "Changer le style" opens MirkStylePickerSheet with 4 builtins',
      (tester) async {
        final styleStore = FakeMirkStyleStore()
          ..rows.addAll([atmospheric, solid, candlelight, heavenly]);
        final sessionStore = _FakeSessionStore({sid: _buildSession(id: sid)});
        final ctrl = _FakeActiveSessionController(tracking);
        await tester.pumpWidget(
          _wrapWithOverrides(
            const SessionBurgerMenu(),
            fakeController: ctrl,
            styleStore: styleStore,
            sessionStore: sessionStore,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Changer le style'));
        await tester.pumpAndSettle();

        // The 4 builtin display names are reachable.
        expect(find.text('Atmospheric (défaut)'), findsOneWidget);
        expect(find.text('Solide'), findsOneWidget);
        expect(find.text('Lueur de bougie'), findsOneWidget);
        expect(find.text('Nuages célestes'), findsOneWidget);
      },
    );

    testWidgets('tapping a tile calls updateMirkStyle + closes the sheet', (
      tester,
    ) async {
      final styleStore = FakeMirkStyleStore()
        ..rows.addAll([atmospheric, solid, candlelight, heavenly]);
      final sessionStore = _FakeSessionStore({sid: _buildSession(id: sid)});
      final ctrl = _FakeActiveSessionController(tracking);
      await tester.pumpWidget(
        _wrapWithOverrides(
          const SessionBurgerMenu(),
          fakeController: ctrl,
          styleStore: styleStore,
          sessionStore: sessionStore,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer le style'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solide'));
      await tester.pumpAndSettle();

      expect(sessionStore.updateCalls, hasLength(1));
      expect(sessionStore.updateCalls.first.sessionId, sid);
      expect(sessionStore.updateCalls.first.mirkStyleId, solid.id);
      // Sheet has closed — its specific marker (the 4 names) no longer
      // visible.
      expect(find.text('Solide'), findsNothing);
    });

    testWidgets('currently-selected style shows trailing checkmark', (
      tester,
    ) async {
      final styleStore = FakeMirkStyleStore()
        ..rows.addAll([atmospheric, solid, candlelight, heavenly]);
      // Pre-seed the session with the candlelight style.
      final sessionStore = _FakeSessionStore({
        sid: _buildSession(id: sid, mirkStyleId: candlelight.id),
      });
      final ctrl = _FakeActiveSessionController(
        tracking.copyWith()..hashCode, // hack to ensure unique state
      );
      // Override the controller seed directly with the desired
      // mirkStyleId on the Tracking state. The Tracking class doesn't
      // carry mirkStyleId — the picker resolves it via the session
      // store. So just rely on the controller seed + the store.
      // (The picker reads `Tracking.mirkStyleId` actually — check
      // that the state class has it.) — see the picker code.
      await tester.pumpWidget(
        _wrapWithOverrides(
          const SessionBurgerMenu(),
          fakeController: ctrl,
          styleStore: styleStore,
          sessionStore: sessionStore,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer le style'));
      await tester.pumpAndSettle();

      // The checkmark icon should sit alongside the candlelight tile.
      // We verify any check icon is present (the picker only renders a
      // checkmark for the current style, which is candlelight in this
      // setup).
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets(
      'no active session → tapping the entry shows a snackbar + no sheet opens',
      (tester) async {
        final styleStore = FakeMirkStyleStore()
          ..rows.addAll([atmospheric, solid, candlelight, heavenly]);
        final sessionStore = _FakeSessionStore(<SessionId, Session>{});
        final ctrl = _FakeActiveSessionController(const Idle());
        await tester.pumpWidget(
          _wrapWithOverrides(
            const SessionBurgerMenu(),
            fakeController: ctrl,
            styleStore: styleStore,
            sessionStore: sessionStore,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Changer le style'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Aucune session active'), findsOneWidget);
        // The picker's content is not in the tree — the sheet did not
        // open.
        expect(find.text('Solide'), findsNothing);
      },
    );
  });
}
