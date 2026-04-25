// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/mirk_style_session_controller.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';

import '../../fakes/fake_mirk_style_store.dart';

/// Plan 09-06 Task 2 — `MirkStyleSessionController.select(styleId)`
/// behaviour.
///
/// Tests cover:
/// 1. Happy path: persists `t_sessions.mirk_style_id` + invalidates
///    renderer exactly once.
/// 2. Same-style reselect → no-op (no write, no invalidate).
/// 3. Unknown styleId → MirkStyleNotFoundException; no write, no
///    invalidate.
/// 4. Missing session → NoActiveSessionException; no write, no
///    invalidate.
/// 5. Persistence verified via SessionStore.findById round-trip after
///    select() returns.

const SessionId _testSessionId = SessionId('sess_01HRMIRKSTYLETESTAAAAAAAAAAA');
const MirkStyleId _styleAtmospheric = MirkStyleId(
  'mst_01HRMIRKSTYLEATMOSPHEREXXXX',
);
const MirkStyleId _styleSolid = MirkStyleId('mst_01HRMIRKSTYLESOLIDXXXXXXXXX');
const MirkStyleId _styleUnknown = MirkStyleId(
  'mst_01HRMIRKSTYLENONEXISTENTXXX',
);

/// In-memory fake [SessionStore] tracking `updateMirkStyle` calls for
/// MirkStyleSessionController test coverage.
class _FakeSessionStore implements SessionStore {
  _FakeSessionStore(this._sessionById);

  final Map<SessionId, Session> _sessionById;
  final List<({SessionId sessionId, MirkStyleId? mirkStyleId})>
  updateMirkStyleCalls = <({SessionId sessionId, MirkStyleId? mirkStyleId})>[];

  @override
  Future<Session?> findById(SessionId id) async => _sessionById[id];

  @override
  Future<Session> requireById(SessionId id) async {
    final row = _sessionById[id];
    if (row == null) throw StateError('No session for $id');
    return row;
  }

  @override
  Future<Session?> findActive() async => null;

  @override
  Future<List<Session>> listAll() async =>
      _sessionById.values.toList(growable: false);

  @override
  Stream<List<Session>> watchAll() =>
      Stream<List<Session>>.value(_sessionById.values.toList(growable: false));

  @override
  Future<void> insert(Session session) async =>
      _sessionById[session.id] = session;

  @override
  Future<void> update(Session session) async =>
      _sessionById[session.id] = session;

  @override
  Future<void> delete(SessionId id) async => _sessionById.remove(id);

  @override
  Future<void> activate(SessionId id) async {}

  @override
  Future<void> deactivate(SessionId id) async {}

  @override
  Future<void> updateMirkStyle({
    required SessionId sessionId,
    required MirkStyleId? mirkStyleId,
  }) async {
    updateMirkStyleCalls.add((sessionId: sessionId, mirkStyleId: mirkStyleId));
    final existing = _sessionById[sessionId];
    if (existing != null) {
      _sessionById[sessionId] = existing.copyWith(mirkStyleId: mirkStyleId);
    }
  }
}

Session _buildSession({MirkStyleId? mirkStyleId}) => Session(
  id: _testSessionId,
  displayName: 'Test session',
  status: SessionStatus.active,
  startedAtUtc: DateTime.utc(2026, 4, 25, 8),
  startedAtOffsetMinutes: 120,
  mirkStyleId: mirkStyleId,
);

MirkStyle _buildStyle(MirkStyleId id, String name) => MirkStyle(
  id: id,
  displayName: name,
  config: const AtmosphericConfig(),
  createdAtUtc: DateTime.utc(2026, 4, 25),
  createdAtOffsetMinutes: 0,
);

({
  MirkStyleSessionController controller,
  _FakeSessionStore sessionStore,
  FakeMirkStyleStore styleStore,
  int Function() invalidateCount,
})
_buildController({MirkStyleId? initialMirkStyleId}) {
  final sessionStore = _FakeSessionStore(<SessionId, Session>{
    _testSessionId: _buildSession(mirkStyleId: initialMirkStyleId),
  });
  final styleStore = FakeMirkStyleStore();
  styleStore.rows.addAll([
    _buildStyle(_styleAtmospheric, 'Atmospheric'),
    _buildStyle(_styleSolid, 'Solid'),
  ]);
  var invalidateCount = 0;
  final controller = MirkStyleSessionController(
    sessionStore: sessionStore,
    styleStore: styleStore,
    invalidateRenderer: () => invalidateCount++,
  );
  return (
    controller: controller,
    sessionStore: sessionStore,
    styleStore: styleStore,
    invalidateCount: () => invalidateCount,
  );
}

void main() {
  group('09-06 — MirkStyleSessionController (MIRK-07)', () {
    test(
      'happy path — persists mirk_style_id + invalidates renderer once',
      () async {
        final ctx = _buildController();
        await ctx.controller.select(
          sessionId: _testSessionId,
          styleId: _styleSolid,
        );

        // Persistence: round-trip via findById confirms the column landed.
        final session = await ctx.sessionStore.findById(_testSessionId);
        expect(session, isNotNull);
        expect(session!.mirkStyleId, _styleSolid);

        // Exactly one updateMirkStyle call.
        expect(ctx.sessionStore.updateMirkStyleCalls.length, 1);
        expect(ctx.sessionStore.updateMirkStyleCalls.first, (
          sessionId: _testSessionId,
          mirkStyleId: _styleSolid,
        ));

        // Invalidate fired exactly once.
        expect(ctx.invalidateCount(), 1);
      },
    );

    test('same-style reselect — no write, no invalidate', () async {
      final ctx = _buildController(initialMirkStyleId: _styleAtmospheric);
      await ctx.controller.select(
        sessionId: _testSessionId,
        styleId: _styleAtmospheric,
      );

      expect(
        ctx.sessionStore.updateMirkStyleCalls,
        isEmpty,
        reason: 'no DB write on same-style reselect',
      );
      expect(
        ctx.invalidateCount(),
        0,
        reason: 'no renderer invalidation on same-style reselect',
      );
    });

    test(
      'unknown styleId — throws MirkStyleNotFoundException, no side effects',
      () async {
        final ctx = _buildController();
        await expectLater(
          ctx.controller.select(
            sessionId: _testSessionId,
            styleId: _styleUnknown,
          ),
          throwsA(isA<MirkStyleNotFoundException>()),
        );

        expect(ctx.sessionStore.updateMirkStyleCalls, isEmpty);
        expect(ctx.invalidateCount(), 0);
      },
    );

    test(
      'missing session — throws NoActiveSessionException, no side effects',
      () async {
        final ctx = _buildController();
        // Drop the seeded session row to simulate a deleted session.
        ctx.sessionStore._sessionById.remove(_testSessionId);

        await expectLater(
          ctx.controller.select(
            sessionId: _testSessionId,
            styleId: _styleSolid,
          ),
          throwsA(isA<NoActiveSessionException>()),
        );

        expect(ctx.sessionStore.updateMirkStyleCalls, isEmpty);
        expect(ctx.invalidateCount(), 0);
      },
    );

    test(
      'switching from null mirkStyleId to a real style persists + invalidates',
      () async {
        final ctx = _buildController();
        // Initial session has no mirkStyleId.
        final initial = await ctx.sessionStore.findById(_testSessionId);
        expect(initial!.mirkStyleId, isNull);

        await ctx.controller.select(
          sessionId: _testSessionId,
          styleId: _styleAtmospheric,
        );
        final after = await ctx.sessionStore.findById(_testSessionId);
        expect(after!.mirkStyleId, _styleAtmospheric);
        expect(ctx.invalidateCount(), 1);
      },
    );

    test('two distinct selects fire two invalidates + two writes', () async {
      final ctx = _buildController();
      await ctx.controller.select(
        sessionId: _testSessionId,
        styleId: _styleSolid,
      );
      await ctx.controller.select(
        sessionId: _testSessionId,
        styleId: _styleAtmospheric,
      );
      expect(ctx.sessionStore.updateMirkStyleCalls.length, 2);
      expect(ctx.invalidateCount(), 2);
      final finalSession = await ctx.sessionStore.findById(_testSessionId);
      expect(finalSession!.mirkStyleId, _styleAtmospheric);
    });
  });
}
