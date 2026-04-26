// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/reveal_streaming_controller.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/infrastructure/ids/seeded_id_generator.dart';

import '../../fakes/fake_revealed_disc_store.dart';

/// Plan 09-06 Task 1 — `RevealStreamingController` (MIRK-01) batch flush
/// behaviour. Reformatted by BUG-010 Option B Commit 4 (2026-04-26): the
/// controller's write target is now [`RevealedDiscStore.addDisc`] instead
/// of the per-parent-tile [`RevealedTileStore.mergeMask`] surface.
///
/// Tests cover:
/// 1. count-bound flush at [kRevealFlushMaxFixes] — N fixes triggers an
///    immediate flush at threshold.
/// 2. time-bound flush via the `flush()` proxy (manual trigger — avoids
///    waiting [kRevealFlushIntervalSeconds] in unit tests).
/// 3. `revealInitial` writes ONE disc with [kInitialRevealRadiusMeters]
///    radius without buffering.
/// 4. each fix produces ONE disc carrying the geometry directly — there
///    is no per-parent-tile fan-out anymore (the SDF builder consumes the
///    continuous geometry at render time).
/// 5. `dispose` flushes pending buffered fixes before returning.
/// 6. repeated identical fixes still write a disc per call (idempotence
///    is now id-level: each fix mints a fresh `rvd_<ULID>` so the prod
///    `INSERT OR IGNORE` is the dedup mechanism).
/// 7. `addDisc` failure on a single fix is logged and the batch
///    continues (CLAUDE.md §Error handling level 2).

const SessionId _testSessionId = SessionId('sess_01HRSTREAMTESTAAAAAAAAAAAAAA');

Fix _buildFix({required double lat, required double lon, int epochMs = 1745056800000, String suffix = 'XX'}) => Fix(
  id: FixId('fix_01HR000000000000000000$suffix'),
  sessionId: _testSessionId,
  recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
  recordedAtOffsetMinutes: 120,
  latitude: lat,
  longitude: lon,
  accuracyMeters: 5.0,
);

void main() {
  group('09-06 — RevealStreamingController (MIRK-01) — disc-store path', () {
    test('count-bound flush — N fixes triggers immediate flush at threshold', () async {
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        discStore: store,
        idGenerator: SeededIdGenerator(seed: 1),
        // Large interval so only the count trigger can fire.
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 3,
      );
      addTearDown(controller.dispose);

      // 2 fixes — under the threshold; no flush yet.
      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0, suffix: '0A'));
      await controller.onFix(_buildFix(lat: 45.0001, lon: 5.0, suffix: '0B'));
      expect(store.addDiscCallCount, 0, reason: 'count-bound flush must NOT fire below threshold');

      // 3rd fix — count threshold hit, flush fires immediately.
      await controller.onFix(_buildFix(lat: 45.0002, lon: 5.0, suffix: '0C'));
      expect(store.addDiscCallCount, 3, reason: 'one addDisc call per fix on flush');
      expect(store.discs, hasLength(3));
      for (final disc in store.discs) {
        expect(disc.radiusMeters, kDefaultRevealRadiusMeters);
        expect(disc.sessionId, _testSessionId.value);
      }
    });

    test('time-bound flush — buffered fixes flush after manual flush() proxy', () async {
      // We cannot wait a real 2 s in a unit test cleanly. The plan exposes
      // `flush()` for exactly this — assert that calling flush() after
      // accumulating < threshold fixes drains the buffer.
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        discStore: store,
        idGenerator: SeededIdGenerator(seed: 2),
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 100,
      );
      addTearDown(controller.dispose);

      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0, suffix: '0A'));
      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0001, suffix: '0B'));
      expect(store.addDiscCallCount, 0, reason: 'no flush below count threshold');

      await controller.flush();
      expect(store.addDiscCallCount, 2, reason: 'manual flush() must drain buffered fixes');
    });

    test('revealInitial writes one disc with kInitialRevealRadiusMeters without buffering', () async {
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        discStore: store,
        idGenerator: SeededIdGenerator(seed: 3),
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 100,
      );
      addTearDown(controller.dispose);

      await controller.revealInitial(_buildFix(lat: 45.0, lon: 5.0));

      expect(store.addDiscCallCount, 1, reason: 'revealInitial must bypass the buffer and write exactly one disc');
      final disc = store.discs.single;
      expect(disc.lat, 45.0);
      expect(disc.lon, 5.0);
      expect(disc.radiusMeters, kInitialRevealRadiusMeters.toDouble(), reason: 'initial reveal uses the smaller 20 m radius');
      expect(disc.sessionId, _testSessionId.value);
    });

    test('per-fix flush produces a disc with kDefaultRevealRadiusMeters at the fix coords', () async {
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        discStore: store,
        idGenerator: SeededIdGenerator(seed: 4),
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 1,
      );
      addTearDown(controller.dispose);

      const lat = 45.5;
      const lon = 5.25;
      await controller.onFix(_buildFix(lat: lat, lon: lon));

      expect(store.addDiscCallCount, 1);
      final disc = store.discs.single;
      expect(disc.lat, lat);
      expect(disc.lon, lon);
      expect(disc.radiusMeters, kDefaultRevealRadiusMeters);
    });

    test('dispose flushes any pending buffered fixes', () async {
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        discStore: store,
        idGenerator: SeededIdGenerator(seed: 5),
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 100,
      );

      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0, suffix: '0A'));
      await controller.onFix(_buildFix(lat: 45.0001, lon: 5.0, suffix: '0B'));
      expect(store.addDiscCallCount, 0, reason: 'no flush below count + interval threshold');

      await controller.dispose();
      expect(store.addDiscCallCount, 2, reason: 'dispose() must flush pending fixes — no data loss on session end');
    });

    test('repeated identical fixes each emit a fresh disc (id-level idempotence)', () async {
      // Pre-Commit-4 the bitmap path was OR-stable on the bytes; the disc
      // path's idempotence is at the row id level (`INSERT OR IGNORE`).
      // Each fix → new ULID → new row. Stationary GPS-jitter clusters
      // collapse offline via `RevealedDiscStore.compactSession` (Commit 6).
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        discStore: store,
        idGenerator: SeededIdGenerator(seed: 6),
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 1, // each fix flushes immediately
      );
      addTearDown(controller.dispose);

      const fixLat = 45.0;
      const fixLon = 5.0;
      for (var i = 0; i < 4; i++) {
        await controller.onFix(_buildFix(lat: fixLat, lon: fixLon, suffix: '0$i'));
      }
      expect(store.addDiscCallCount, 4);
      // Every disc carries the same lat/lon but a unique id.
      final ids = store.discs.map((d) => d.id).toSet();
      expect(ids.length, 4, reason: 'each fix mints a fresh rvd_<ULID> id');
      for (final disc in store.discs) {
        expect(disc.lat, fixLat);
        expect(disc.lon, fixLon);
      }
    });

    test('addDisc failure on a fix is logged and batch continues', () async {
      final store = FakeRevealedDiscStore()..throwOnNextCall = StateError('FakeRevealedDiscStore forced throw on first call');
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        discStore: store,
        idGenerator: SeededIdGenerator(seed: 7),
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 1,
      );
      addTearDown(controller.dispose);

      // First fix — addDisc throws once. The controller must swallow
      // the failure (CLAUDE.md §Error handling level 2).
      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0, suffix: '01'));
      // Second fix — addDisc no longer throws, the disc lands.
      await controller.onFix(_buildFix(lat: 45.0001, lon: 5.0, suffix: '02'));

      // The fake increments `addDiscCallCount` *after* the throw guard,
      // so the failed first call doesn't bump the counter — only the
      // surviving second call does. The controller still attempted the
      // first write (the throw came from inside addDisc), and the loop
      // continued to the second write, which is the property under test.
      expect(store.addDiscCallCount, 1, reason: 'second addDisc lands; the first one threw before persisting');
      // Only the second disc actually got persisted — the first throw
      // ate that write before the in-memory list grew.
      expect(store.discs, hasLength(1));
      expect(store.discs.single.lat, 45.0001);
    });

    test('flush() while no fixes buffered is a no-op', () async {
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(sessionId: _testSessionId, discStore: store, idGenerator: SeededIdGenerator(seed: 8));
      addTearDown(controller.dispose);

      await controller.flush();
      expect(store.addDiscCallCount, 0);
    });

    test('post-dispose calls are no-ops (does not throw)', () async {
      final store = FakeRevealedDiscStore();
      final controller = RevealStreamingController(sessionId: _testSessionId, discStore: store, idGenerator: SeededIdGenerator(seed: 9));

      await controller.dispose();
      // No assertion on count — just must not throw.
      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0));
      await controller.revealInitial(_buildFix(lat: 45.0, lon: 5.0));
      await controller.flush();
      await controller.dispose();
    });
  });
}
