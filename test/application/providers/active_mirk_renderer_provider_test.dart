// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/mirk_renderer_factory_provider.dart';
import 'package:mirkfall/application/providers/mirk_style_store_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/mirk_renderer_factory.dart';
import 'package:mirkfall/infrastructure/mirk/noop_mirk_renderer.dart';

import '../../fakes/fake_mirk_renderer.dart';
import '../../fakes/fake_mirk_style_store.dart';

/// Plan 09-05 Task 3 — `activeMirkRendererProvider` resolution +
/// lifecycle dispose.
///
/// Resolution cascade tested:
/// * Idle session → NoopMirkRenderer.
/// * Tracking + atmospheric style → AtmosphericMirkRenderer.
/// * Tracking + candlelight style → CandlelightMirkRenderer.
/// * Tracking + null mirkStyleId → AtmosphericMirkRenderer (default
///   fallback).
/// * Tracking + missing style id (referenced row deleted) →
///   AtmosphericMirkRenderer (renderer-level fallback).
/// * Lifecycle: invalidation calls `dispose()` exactly once on the
///   prior renderer (asserted via `_SpyingFactory` + `FakeMirkRenderer`
///   counter).
///
/// Mirrors the Phase 05 `_buildContainer` pattern from
/// `test/application/controllers/active_session_controller_test.dart`
/// — explicit ProviderContainer with concrete overrides for the session
/// + style store + factory dependency graph.

/// Captures inserts only — find/required/list flow through the seeded
/// `Map<SessionId, Session>`. Mirrors `_FakeSessionStore` from
/// `active_session_controller_test.dart` shape (subset of methods,
/// in-memory backing store).
class _FakeSessionStore implements SessionStore {
  _FakeSessionStore(this._sessionById);

  final Map<SessionId, Session> _sessionById;

  @override
  Future<Session?> findById(SessionId id) async => _sessionById[id];

  @override
  Future<Session> requireById(SessionId id) async {
    final row = _sessionById[id];
    if (row == null) {
      throw StateError('Test setup: no session seeded for ${id.value}');
    }
    return row;
  }

  @override
  Future<Session?> findActive() async {
    for (final session in _sessionById.values) {
      if (session.status == SessionStatus.active) return session;
    }
    return null;
  }

  @override
  Future<List<Session>> listAll() async => _sessionById.values.toList(growable: false);

  @override
  Stream<List<Session>> watchAll() => Stream<List<Session>>.value(_sessionById.values.toList(growable: false));

  @override
  Future<void> insert(Session session) async => _sessionById[session.id] = session;

  @override
  Future<void> update(Session session) async => _sessionById[session.id] = session;

  @override
  Future<void> delete(SessionId id) async => _sessionById.remove(id);

  @override
  Future<void> activate(SessionId id) async {
    final existing = _sessionById[id];
    if (existing != null) {
      _sessionById[id] = existing.copyWith(status: SessionStatus.active);
    }
  }

  @override
  Future<void> deactivate(SessionId id) async {
    final existing = _sessionById[id];
    if (existing != null) {
      _sessionById[id] = existing.copyWith(status: SessionStatus.stopped);
    }
  }

  @override
  Future<void> updateMirkStyle({required SessionId sessionId, required MirkStyleId? mirkStyleId}) async {
    final existing = _sessionById[sessionId];
    if (existing != null) {
      _sessionById[sessionId] = existing.copyWith(mirkStyleId: mirkStyleId);
    }
  }
}

/// Test-double notifier exposing a pre-baked [ActiveSessionState] without
/// running the real controller's start/stop/subscribe machinery.
///
/// Returns the seed synchronously from `build()` (the controller declares
/// `FutureOr<ActiveSessionState> build()` so a sync return is contract-
/// compatible). Async returns trigger Riverpod's "loading state" path
/// which races with the dependent `activeMirkRendererProvider`'s
/// dispose chain in tests.
class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._initial);
  final ActiveSessionState _initial;

  @override
  ActiveSessionState build() => _initial;
}

/// Minimal factory test-double returning the supplied [stubFor] renderer
/// regardless of config — lets the invalidation-dispose test inject an
/// observable renderer without having to spin up a real one.
class _SpyingFactory implements MirkRendererFactory {
  const _SpyingFactory({required this.stubFor});
  final MirkRenderer stubFor;

  @override
  MirkRenderer create(MirkStyleConfig config) => stubFor;
}

/// Builds a [Session] entity with sensible defaults for tests that only
/// care about the id + mirkStyleId fields.
Session _buildSession({required SessionId id, MirkStyleId? mirkStyleId, SessionStatus status = SessionStatus.active}) => Session(
  id: id,
  displayName: 'Test session',
  status: status,
  startedAtUtc: DateTime.utc(2026, 4, 25, 10),
  startedAtOffsetMinutes: 0,
  mirkStyleId: mirkStyleId,
);

/// Builds a [MirkStyle] with the given id + config — sufficient for
/// resolver tests; createdAt fields are stable.
MirkStyle _buildStyle({required MirkStyleId id, required MirkStyleConfig config, String displayName = 'Test style'}) =>
    MirkStyle(id: id, displayName: displayName, config: config, createdAtUtc: DateTime.utc(2026, 4, 25), createdAtOffsetMinutes: 0);

/// Builds a `Tracking` state for [sessionId] with sensible defaults.
Tracking _buildTracking(SessionId sessionId) =>
    Tracking(sessionId: sessionId, startedAtUtc: DateTime.utc(2026, 4, 25, 10), fixCount: 0, distanceFilterMeters: 5);

ProviderContainer _buildContainer({
  required ActiveSessionState initialSessionState,
  required _FakeSessionStore sessionStore,
  required FakeMirkStyleStore styleStore,
  MirkRendererFactory? factoryOverride,
}) {
  return ProviderContainer(
    overrides: [
      activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(initialSessionState)),
      sessionStoreProvider.overrideWith((ref) async => sessionStore),
      mirkStyleStoreProvider.overrideWith((ref) async => styleStore),
      if (factoryOverride != null) mirkRendererFactoryProvider.overrideWithValue(factoryOverride),
    ],
  );
}

void main() {
  group('09-05 — activeMirkRendererProvider', () {
    test('Idle session → NoopMirkRenderer', () async {
      final container = _buildContainer(
        initialSessionState: const Idle(),
        sessionStore: _FakeSessionStore(<SessionId, Session>{}),
        styleStore: FakeMirkStyleStore(),
      );
      addTearDown(container.dispose);

      final renderer = await container.read(activeMirkRendererProvider.future);
      expect(renderer, isA<NoopMirkRenderer>());
    });

    test('Starting session → NoopMirkRenderer (no fog until Tracking)', () async {
      final container = _buildContainer(
        initialSessionState: const Starting(SessionId('sess_starting')),
        sessionStore: _FakeSessionStore(<SessionId, Session>{}),
        styleStore: FakeMirkStyleStore(),
      );
      addTearDown(container.dispose);

      final renderer = await container.read(activeMirkRendererProvider.future);
      expect(renderer, isA<NoopMirkRenderer>(), reason: 'fog only appears once Tracking — Starting renders Noop');
    });

    test('Tracking + atmospheric style → AtmosphericMirkRenderer', () async {
      const styleId = MirkStyleId('style_builtin_atmospheric');
      const sessionId = SessionId('sess_tracking_atmospheric');
      final styleStore = FakeMirkStyleStore()..rows.add(_buildStyle(id: styleId, config: const AtmosphericConfig(), displayName: 'Atmospheric (défaut)'));
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(id: sessionId, mirkStyleId: styleId)});
      final container = _buildContainer(initialSessionState: _buildTracking(sessionId), sessionStore: sessionStore, styleStore: styleStore);
      addTearDown(container.dispose);

      final renderer = await container.read(activeMirkRendererProvider.future);
      expect(renderer, isA<AtmosphericMirkRenderer>());
    });

    test('Tracking + candlelight style → CandlelightMirkRenderer', () async {
      const styleId = MirkStyleId('style_builtin_candlelight');
      const sessionId = SessionId('sess_tracking_candlelight');
      final styleStore = FakeMirkStyleStore()..rows.add(_buildStyle(id: styleId, config: const CandlelightConfig(), displayName: 'Lueur de bougie'));
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(id: sessionId, mirkStyleId: styleId)});
      final container = _buildContainer(initialSessionState: _buildTracking(sessionId), sessionStore: sessionStore, styleStore: styleStore);
      addTearDown(container.dispose);

      final renderer = await container.read(activeMirkRendererProvider.future);
      expect(renderer, isA<CandlelightMirkRenderer>());
    });

    test('Tracking + null mirkStyleId → AtmosphericMirkRenderer (default fallback)', () async {
      const sessionId = SessionId('sess_tracking_null_style');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{
        // Explicit `mirkStyleId: null` is the SUT's fallback trigger;
        // the lint flags it as redundant because null is the default,
        // but the explicitness is load-bearing for test readability.
        // ignore: avoid_redundant_argument_values
        sessionId: _buildSession(id: sessionId, mirkStyleId: null),
      });
      final container = _buildContainer(initialSessionState: _buildTracking(sessionId), sessionStore: sessionStore, styleStore: FakeMirkStyleStore());
      addTearDown(container.dispose);

      final renderer = await container.read(activeMirkRendererProvider.future);
      expect(renderer, isA<AtmosphericMirkRenderer>(), reason: 'null mirkStyleId degrades to default atmospheric');
    });

    test('Tracking + referenced style missing from store → AtmosphericMirkRenderer (fallback)', () async {
      const sessionId = SessionId('sess_tracking_phantom_style');
      final sessionStore = _FakeSessionStore(<SessionId, Session>{
        sessionId: _buildSession(id: sessionId, mirkStyleId: const MirkStyleId('style_user_phantom_import')),
      });
      final container = _buildContainer(initialSessionState: _buildTracking(sessionId), sessionStore: sessionStore, styleStore: FakeMirkStyleStore());
      addTearDown(container.dispose);

      final renderer = await container.read(activeMirkRendererProvider.future);
      expect(
        renderer,
        isA<AtmosphericMirkRenderer>(),
        reason:
            'missing style row degrades to default atmospheric, '
            'never crashes the renderer chain',
      );
    });

    test('invalidation calls dispose() exactly once on the prior renderer', () async {
      final fakeRenderer = FakeMirkRenderer();
      final spyingFactory = _SpyingFactory(stubFor: fakeRenderer);

      const styleId = MirkStyleId('style_builtin_atmospheric');
      const sessionId = SessionId('sess_dispose_lifecycle');
      final styleStore = FakeMirkStyleStore()..rows.add(_buildStyle(id: styleId, config: const AtmosphericConfig()));
      final sessionStore = _FakeSessionStore(<SessionId, Session>{sessionId: _buildSession(id: sessionId, mirkStyleId: styleId)});
      final container = _buildContainer(
        initialSessionState: _buildTracking(sessionId),
        sessionStore: sessionStore,
        styleStore: styleStore,
        factoryOverride: spyingFactory,
      );
      addTearDown(container.dispose);

      final first = await container.read(activeMirkRendererProvider.future);
      expect(identical(first, fakeRenderer), isTrue, reason: 'spying factory must hand back the prepared FakeMirkRenderer');
      expect(fakeRenderer.disposeCallCount, 0);

      // Force teardown of the prior provider state.
      container.invalidate(activeMirkRendererProvider);
      // Re-read so the prior `ref.onDispose` actually fires.
      await container.read(activeMirkRendererProvider.future);

      expect(
        fakeRenderer.disposeCallCount,
        1,
        reason:
            'ref.onDispose must call dispose() exactly once on the prior '
            'renderer when the provider invalidates',
      );
    });

    test('Noop fallback path also routes through ref.onDispose', () async {
      // Sanity check: even the Idle → NoopMirkRenderer branch wires
      // dispose() via ref.onDispose. The Noop's dispose is a no-op so
      // there's nothing observable in production, but we want the path
      // exercised here so future renderer additions follow the same
      // contract.
      final container = _buildContainer(
        initialSessionState: const Idle(),
        sessionStore: _FakeSessionStore(<SessionId, Session>{}),
        styleStore: FakeMirkStyleStore(),
      );
      // No addTearDown for container — we explicitly dispose below
      // and want to assert no exception is thrown by the Noop dispose
      // chain.
      final renderer = await container.read(activeMirkRendererProvider.future);
      expect(renderer, isA<NoopMirkRenderer>());

      expect(
        container.dispose,
        returnsNormally,
        reason:
            'NoopMirkRenderer.dispose must not throw — Phase 09 '
            'lifecycle contract is "idempotent + safe"',
      );
    });
  });
}
