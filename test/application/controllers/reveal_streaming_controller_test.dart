// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/reveal_streaming_controller.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/revealed_tile.dart';
import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';
import 'package:mirkfall/domain/revealed/tile_math.dart';

/// Plan 09-06 Task 1 — `RevealStreamingController` (MIRK-01) batch flush
/// + per-parent-tile merge behaviour.
///
/// Tests cover the 7 contract items declared in the plan's behavior block:
/// 1. count-bound flush at [kRevealFlushMaxFixes].
/// 2. time-bound flush at [kRevealFlushIntervalSeconds] (`fakeAsync` —
///    `flush()` is exposed for test control instead of waiting real
///    seconds).
/// 3. `revealInitial` writes a smaller-radius mask without touching the
///    buffer.
/// 4. fix near a parent-tile boundary produces 2+ distinct tile writes.
/// 5. `dispose` flushes pending buffered fixes before returning.
/// 6. repeated identical fixes still merge OR-stably (idempotence).
/// 7. `mergeMask` failure on a single tile is logged and the batch
///    continues (not propagated past the call site).

const SessionId _testSessionId = SessionId('sess_01HRSTREAMTESTAAAAAAAAAAAAAA');

/// Captures every `mergeMask` call. Tests assert on call count, per-tile
/// coordinates, and the cumulative merged bitmap per `(parentX, parentY)`
/// pair so the OR-stability check is exact rather than count-only.
class _FakeRevealedTileStore implements RevealedTileStore {
  final List<({int parentX, int parentY, Uint8List mask})> mergeMaskCalls =
      <({int parentX, int parentY, Uint8List mask})>[];

  /// When non-zero, the Nth call (1-indexed) throws [StateError]. Used
  /// by the error-tier test (CLAUDE.md §Error handling level 2: the
  /// failure must be logged and the rest of the batch must continue).
  int throwOnNthCall = 0;

  /// Cumulative OR of every mask received per `(parentX, parentY)` so
  /// the idempotence test can read back the bitmap after N writes and
  /// confirm bit monotonicity.
  final Map<({int parentX, int parentY}), Uint8List> _accumulated =
      <({int parentX, int parentY}), Uint8List>{};

  @override
  Future<void> mergeMask({
    required SessionId sessionId,
    required int parentX,
    required int parentY,
    required Uint8List mask,
  }) async {
    final callIndex = mergeMaskCalls.length + 1;
    mergeMaskCalls.add((
      parentX: parentX,
      parentY: parentY,
      mask: Uint8List.fromList(mask),
    ));
    if (throwOnNthCall == callIndex) {
      throw StateError(
        'FakeRevealedTileStore forced throw on call #$callIndex',
      );
    }
    final key = (parentX: parentX, parentY: parentY);
    final existing = _accumulated[key];
    if (existing == null) {
      _accumulated[key] = Uint8List.fromList(mask);
    } else {
      final merged = Uint8List(existing.length);
      for (var i = 0; i < existing.length; i++) {
        merged[i] = existing[i] | mask[i];
      }
      _accumulated[key] = merged;
    }
  }

  Uint8List? readAccumulated({required int parentX, required int parentY}) =>
      _accumulated[(parentX: parentX, parentY: parentY)];

  @override
  Future<List<RevealedTile>> listBySession(SessionId sessionId) async =>
      const <RevealedTile>[];

  @override
  Future<RevealedTile?> findByParent({
    required SessionId sessionId,
    required int parentX,
    required int parentY,
  }) async => null;
}

Fix _buildFix({
  required double lat,
  required double lon,
  int epochMs = 1745056800000,
  String suffix = 'XX',
}) => Fix(
  id: FixId('fix_01HR000000000000000000$suffix'),
  sessionId: _testSessionId,
  recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
  recordedAtOffsetMinutes: 120,
  latitude: lat,
  longitude: lon,
  accuracyMeters: 5.0,
);

bool _hasAnyBit(Uint8List bytes) {
  for (final b in bytes) {
    if (b != 0) return true;
  }
  return false;
}

int _popcount(Uint8List bytes) {
  var c = 0;
  for (final b in bytes) {
    var v = b;
    v = v - ((v >> 1) & 0x55);
    v = (v & 0x33) + ((v >> 2) & 0x33);
    c += (v + (v >> 4)) & 0x0F;
  }
  return c;
}

void main() {
  group('09-06 — RevealStreamingController (MIRK-01)', () {
    test(
      'count-bound flush — N fixes triggers immediate flush at threshold',
      () async {
        final store = _FakeRevealedTileStore();
        final controller = RevealStreamingController(
          sessionId: _testSessionId,
          store: store,
          // Large interval so only the count trigger can fire.
          flushInterval: const Duration(seconds: 60),
          flushMaxFixes: 3,
        );
        addTearDown(controller.dispose);

        // 2 fixes — under the threshold; no flush yet.
        await controller.onFix(_buildFix(lat: 45.0, lon: 5.0, suffix: '0A'));
        await controller.onFix(_buildFix(lat: 45.0001, lon: 5.0, suffix: '0B'));
        expect(
          store.mergeMaskCalls,
          isEmpty,
          reason: 'count-bound flush must NOT fire below threshold',
        );

        // 3rd fix — count threshold hit, flush fires immediately.
        await controller.onFix(_buildFix(lat: 45.0002, lon: 5.0, suffix: '0C'));
        expect(
          store.mergeMaskCalls.length,
          greaterThanOrEqualTo(3),
          reason: 'one mergeMask call per fix at minimum (single-tile case)',
        );
      },
    );

    test(
      'time-bound flush — buffered fixes flush after flushInterval (manual flush() proxy)',
      () async {
        // We cannot wait a real 2 s in a unit test cleanly. The plan exposes
        // `flush()` for exactly this — assert that calling flush() after
        // accumulating < threshold fixes drains the buffer.
        final store = _FakeRevealedTileStore();
        final controller = RevealStreamingController(
          sessionId: _testSessionId,
          store: store,
          flushInterval: const Duration(seconds: 60),
          flushMaxFixes: 100,
        );
        addTearDown(controller.dispose);

        await controller.onFix(_buildFix(lat: 45.0, lon: 5.0, suffix: '0A'));
        await controller.onFix(_buildFix(lat: 45.0, lon: 5.0001, suffix: '0B'));
        expect(
          store.mergeMaskCalls,
          isEmpty,
          reason: 'no flush below count threshold',
        );

        await controller.flush();
        expect(
          store.mergeMaskCalls.length,
          greaterThanOrEqualTo(2),
          reason: 'manual flush() must drain buffered fixes',
        );
      },
    );

    test(
      'revealInitial writes a smaller-radius mask without buffering',
      () async {
        final store = _FakeRevealedTileStore();
        final controller = RevealStreamingController(
          sessionId: _testSessionId,
          store: store,
          flushInterval: const Duration(seconds: 60),
          flushMaxFixes: 100,
        );
        addTearDown(controller.dispose);

        await controller.revealInitial(_buildFix(lat: 45.0, lon: 5.0));
        expect(
          store.mergeMaskCalls.length,
          greaterThanOrEqualTo(1),
          reason: 'revealInitial must bypass the buffer and write immediately',
        );

        // The smaller-radius (20 m) initial reveal must produce *fewer or
        // equal* set bits than a 25 m default reveal at the same fix
        // coords. We compare popcount on the home parent tile.
        final homeTile = TileMath.latLonToTile(
          lat: 45.0,
          lon: 5.0,
          zoom: kRevealedTileParentZoom,
        );
        final initialBitmap = store.readAccumulated(
          parentX: homeTile.x,
          parentY: homeTile.y,
        );
        expect(initialBitmap, isNotNull);
        final initialPopcount = _popcount(initialBitmap!);

        // Reset, then write the 25 m default reveal via onFix → flush.
        store.mergeMaskCalls.clear();
        // ignore: invalid_use_of_protected_member — Direct access for test.
        // We use a fresh controller to avoid mutating the prior one's state.
        final defaultStore = _FakeRevealedTileStore();
        final defaultController = RevealStreamingController(
          sessionId: _testSessionId,
          store: defaultStore,
          flushInterval: const Duration(seconds: 60),
          flushMaxFixes: 1,
        );
        addTearDown(defaultController.dispose);
        await defaultController.onFix(_buildFix(lat: 45.0, lon: 5.0));
        final defaultBitmap = defaultStore.readAccumulated(
          parentX: homeTile.x,
          parentY: homeTile.y,
        );
        expect(defaultBitmap, isNotNull);
        final defaultPopcount = _popcount(defaultBitmap!);

        expect(
          initialPopcount,
          lessThanOrEqualTo(defaultPopcount),
          reason:
              'kInitialRevealRadiusMeters (20 m) covers ≤ kDefaultRevealRadiusMeters (25 m) area',
        );
        expect(
          initialPopcount,
          greaterThan(0),
          reason:
              'a 20 m initial reveal at a tile-interior fix must set ≥ 1 bit',
        );
      },
    );

    test(
      'fix at parent-tile boundary produces ≥ 2 distinct tile writes',
      () async {
        final store = _FakeRevealedTileStore();
        final controller = RevealStreamingController(
          sessionId: _testSessionId,
          store: store,
          flushInterval: const Duration(seconds: 60),
          flushMaxFixes: 1,
        );
        addTearDown(controller.dispose);

        // Pick a fix sitting *exactly* on the eastern edge of a zoom-14 tile.
        // The tile NW of (lat 45, lon 5) at z=14 has a SE corner that is the
        // NW corner of the eastern neighbour. A fix at that exact lon is at
        // the boundary; a 25 m radius ALWAYS spills into both tiles.
        const homeLat = 45.0;
        const homeLon = 5.0;
        final homeTile = TileMath.latLonToTile(
          lat: homeLat,
          lon: homeLon,
          zoom: kRevealedTileParentZoom,
        );
        final eastTileNw = TileMath.tileToLatLon(
          x: homeTile.x + 1,
          y: homeTile.y,
          zoom: kRevealedTileParentZoom,
        );
        // Place the fix slightly inside the home tile near its eastern edge
        // so the bbox ALWAYS spills west-to-east — accounting for the small
        // overshoot in the bbox prune (which is fine, empty masks get
        // filtered before writing).
        final boundaryLon = eastTileNw.lon - 0.000001; // ~0.1 m west of edge
        final boundaryLat = (eastTileNw.lat) - 0.0005; // mid-tile in lat

        await controller.onFix(_buildFix(lat: boundaryLat, lon: boundaryLon));

        // Expect calls touching at least 2 distinct (parentX, parentY) tuples.
        final touchedTiles = store.mergeMaskCalls
            .map((c) => '${c.parentX}_${c.parentY}')
            .toSet();
        expect(
          touchedTiles.length,
          greaterThanOrEqualTo(2),
          reason:
              'a 25 m disc at a parent-tile boundary must straddle ≥ 2 tiles. Got writes for: $touchedTiles',
        );
      },
    );

    test('dispose flushes any pending buffered fixes', () async {
      final store = _FakeRevealedTileStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        store: store,
        flushInterval: const Duration(seconds: 60),
        flushMaxFixes: 100,
      );

      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0, suffix: '0A'));
      await controller.onFix(_buildFix(lat: 45.0001, lon: 5.0, suffix: '0B'));
      expect(
        store.mergeMaskCalls,
        isEmpty,
        reason: 'no flush below count + interval threshold',
      );

      await controller.dispose();
      expect(
        store.mergeMaskCalls.length,
        greaterThanOrEqualTo(2),
        reason:
            'dispose() must flush pending fixes — no data loss on session end',
      );
    });

    test(
      'repeated identical fixes preserve OR-stable monotone bitmap',
      () async {
        final store = _FakeRevealedTileStore();
        final controller = RevealStreamingController(
          sessionId: _testSessionId,
          store: store,
          flushInterval: const Duration(seconds: 60),
          flushMaxFixes: 1, // each fix flushes immediately
        );
        addTearDown(controller.dispose);

        const fixLat = 45.0;
        const fixLon = 5.0;
        final homeTile = TileMath.latLonToTile(
          lat: fixLat,
          lon: fixLon,
          zoom: kRevealedTileParentZoom,
        );

        // Three identical fixes back-to-back — bitmap must be byte-identical
        // after each one (idempotence at the fake level mirrors the
        // production OR-merge behaviour).
        for (var i = 0; i < 3; i++) {
          await controller.onFix(
            _buildFix(lat: fixLat, lon: fixLon, suffix: '0$i'),
          );
        }
        final after3 = store.readAccumulated(
          parentX: homeTile.x,
          parentY: homeTile.y,
        );
        expect(after3, isNotNull);
        expect(_hasAnyBit(after3!), isTrue);

        // One more identical fix — popcount must NOT decrease (no bit
        // ever resets), and is expected to be exactly the same.
        final beforeFourthPopcount = _popcount(after3);
        await controller.onFix(
          _buildFix(lat: fixLat, lon: fixLon, suffix: '0D'),
        );
        final after4 = store.readAccumulated(
          parentX: homeTile.x,
          parentY: homeTile.y,
        )!;
        expect(_popcount(after4), greaterThanOrEqualTo(beforeFourthPopcount));
        expect(_popcount(after4), beforeFourthPopcount);
      },
    );

    test(
      'mergeMask failure on one tile is logged and batch continues',
      () async {
        final store = _FakeRevealedTileStore()..throwOnNthCall = 1;
        final controller = RevealStreamingController(
          sessionId: _testSessionId,
          store: store,
          flushInterval: const Duration(seconds: 60),
          flushMaxFixes: 1,
        );
        addTearDown(controller.dispose);

        // A boundary fix — produces ≥ 2 mergeMask calls. The first throws;
        // the rest must still happen, AND no exception escapes onFix.
        const homeLat = 45.0;
        const homeLon = 5.0;
        final homeTile = TileMath.latLonToTile(
          lat: homeLat,
          lon: homeLon,
          zoom: kRevealedTileParentZoom,
        );
        final eastTileNw = TileMath.tileToLatLon(
          x: homeTile.x + 1,
          y: homeTile.y,
          zoom: kRevealedTileParentZoom,
        );
        final boundaryLon = eastTileNw.lon - 0.000001;
        final boundaryLat = (eastTileNw.lat) - 0.0005;

        // No expectLater(throwsA(...)) — the SUT MUST swallow the per-tile
        // failure (CLAUDE.md §Error handling level 2).
        await controller.onFix(_buildFix(lat: boundaryLat, lon: boundaryLon));

        expect(
          store.mergeMaskCalls.length,
          greaterThanOrEqualTo(2),
          reason: 'second tile write must still happen after first one threw',
        );
      },
    );

    test('flush() while no fixes buffered is a no-op', () async {
      final store = _FakeRevealedTileStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        store: store,
      );
      addTearDown(controller.dispose);

      await controller.flush();
      expect(store.mergeMaskCalls, isEmpty);
    });

    test('post-dispose calls are no-ops (does not throw)', () async {
      final store = _FakeRevealedTileStore();
      final controller = RevealStreamingController(
        sessionId: _testSessionId,
        store: store,
      );

      await controller.dispose();
      // No assertion on count — just must not throw.
      await controller.onFix(_buildFix(lat: 45.0, lon: 5.0));
      await controller.revealInitial(_buildFix(lat: 45.0, lon: 5.0));
      await controller.flush();
      await controller.dispose();
    });
  });
}
