// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Drift re-exports an `isNotNull` column matcher that collides with
// matcher's value matcher; `hide` it so matcher's version dominates.
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/stores/drift_revealed_disc_store.dart';
import 'package:test/test.dart';

AppDatabase _newDb() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA journal_mode = WAL');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

/// Convenience builder so each test can spell out only the bits that
/// matter to the assertion. Defaults to a Paris-ish lat/lon, 25 m radius
/// (the project default reveal radius), and a stable UTC timestamp.
RevealDisc _disc({
  required String id,
  required String sessionId,
  double lat = 48.8566,
  double lon = 2.3522,
  double radiusMeters = 25.0,
  DateTime? fixedAtUtc,
}) => RevealDisc(
  id: id,
  sessionId: sessionId,
  lat: lat,
  lon: lon,
  radiusMeters: radiusMeters,
  fixedAtUtc: fixedAtUtc ?? DateTime.utc(2026, 4, 26, 12),
);

void main() {
  late AppDatabase db;
  late DriftRevealedDiscStore store;
  const String sessionId = 'sess_01HRDISCSTORETEST00000000AA';
  const String otherSessionId = 'sess_01HRDISCSTOREOTHER000000AA';

  setUp(() async {
    db = _newDb();
    store = DriftRevealedDiscStore(db);
    await db.customStatement('SELECT 1');

    // Seed two sessions — FK requires them before any reveal-disc
    // insert. Different session ids let the bbox/cascade tests assert
    // session isolation.
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('$sessionId', 'T', 'stopped', 1000, 120)",
    );
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('$otherSessionId', 'O', 'stopped', 1000, 120)",
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('addDisc + discsForSession', () {
    test('round-trip persists every column verbatim', () async {
      final disc = _disc(id: 'rvd_01HRDISCROUNDTRIP000000000A', sessionId: sessionId);
      await store.addDisc(disc);

      final List<RevealDisc> rows = await store.discsForSession(sessionId);
      expect(rows, hasLength(1));
      final RevealDisc roundTrippedDisc = rows.single;
      expect(roundTrippedDisc.id, disc.id);
      expect(roundTrippedDisc.sessionId, disc.sessionId);
      expect(roundTrippedDisc.lat, disc.lat);
      expect(roundTrippedDisc.lon, disc.lon);
      expect(roundTrippedDisc.radiusMeters, disc.radiusMeters);
      expect(roundTrippedDisc.fixedAtUtc, disc.fixedAtUtc);
    });

    test('orders rows by fixedAtUtc ascending', () async {
      await store.addDisc(_disc(id: 'rvd_01HRDISCORDERB00000000000A', sessionId: sessionId, fixedAtUtc: DateTime.utc(2026, 4, 26, 12, 0, 30)));
      // A keeps the `_disc` default (`DateTime.utc(2026, 4, 26, 12)`) — the earliest value of the three.
      await store.addDisc(_disc(id: 'rvd_01HRDISCORDERA00000000000A', sessionId: sessionId));
      await store.addDisc(_disc(id: 'rvd_01HRDISCORDERC00000000000A', sessionId: sessionId, fixedAtUtc: DateTime.utc(2026, 4, 26, 12, 1)));

      final rows = await store.discsForSession(sessionId);
      expect(rows.map((d) => d.id).toList(), <String>[
        'rvd_01HRDISCORDERA00000000000A',
        'rvd_01HRDISCORDERB00000000000A',
        'rvd_01HRDISCORDERC00000000000A',
      ]);
    });
  });

  test('addDisc is idempotent on duplicate id (count stays 1)', () async {
    final disc = _disc(id: 'rvd_01HRDISCIDEMPOTENT000000AA', sessionId: sessionId);
    await store.addDisc(disc);
    await store.addDisc(disc);
    await store.addDisc(disc);

    final rows = await store.discsForSession(sessionId);
    expect(rows, hasLength(1));
  });

  group('discsInBbox', () {
    // Paris bbox: roughly the île-de-France core (48.80–48.91, 2.30–2.42).
    final MirkViewportBbox parisBbox = MirkViewportBbox(south: 48.80, west: 2.30, north: 48.91, east: 2.42);

    test('disc fully inside the bbox is returned', () async {
      // Centre of the Paris bbox, 25 m radius.
      await store.addDisc(_disc(id: 'rvd_01HRDISCBBOXIN000000000AA', sessionId: sessionId, lat: 48.86, lon: 2.36));

      final hits = await store.discsInBbox(sessionId: sessionId, bbox: parisBbox);
      expect(hits, hasLength(1));
      expect(hits.single.id, 'rvd_01HRDISCBBOXIN000000000AA');
    });

    test('disc fully outside the bbox is filtered out', () async {
      // Tokyo — clearly outside the Paris bbox at 25 m radius.
      await store.addDisc(_disc(id: 'rvd_01HRDISCBBOXOUT00000000AA', sessionId: sessionId, lat: 35.68, lon: 139.76));

      final hits = await store.discsInBbox(sessionId: sessionId, bbox: parisBbox);
      expect(hits, isEmpty);
    });

    test('disc straddling the bbox edge is included (bbox-overlap conservative)', () async {
      // Centre is just south of the bbox south edge, but a 200 m radius
      // bleeds inside the bbox — `intersectsBbox` is centre±radius, so
      // this counts as a hit even though the centre itself is outside.
      await store.addDisc(
        _disc(id: 'rvd_01HRDISCBBOXSTRADDLE000AA', sessionId: sessionId, lat: 48.799, lon: 2.36, radiusMeters: 200.0),
      );

      final hits = await store.discsInBbox(sessionId: sessionId, bbox: parisBbox);
      expect(hits, hasLength(1));
    });

    test('filters by sessionId — discs from another session are not returned', () async {
      await store.addDisc(_disc(id: 'rvd_01HRDISCBBOXOTHER0000000A', sessionId: otherSessionId, lat: 48.86, lon: 2.36));

      final hits = await store.discsInBbox(sessionId: sessionId, bbox: parisBbox);
      expect(hits, isEmpty);
    });
  });

  group('compactSession', () {
    test('stationary cluster (5 identical discs) collapses to 1', () async {
      // Five discs at the exact same lat/lon/radius — only the ids
      // differ. The largest (= any of them, all radius 25 m) is kept;
      // the other four are containment-dropped.
      for (int i = 0; i < 5; i++) {
        await store.addDisc(_disc(id: 'rvd_01HRDISCSTATIONARY${i.toString().padLeft(7, '0')}', sessionId: sessionId, lat: 48.86, lon: 2.36));
      }

      final pre = await store.discsForSession(sessionId);
      expect(pre, hasLength(5));

      final dropped = await store.compactSession(sessionId);
      expect(dropped, 4);

      final post = await store.discsForSession(sessionId);
      expect(post, hasLength(1));
    });

    test('walking path (5 discs in a line, 30 m apart, radius 25 m) keeps all 5', () async {
      // Walk east — 30 m at the Paris latitude is roughly
      // 30 / (111320 * cos(48.86°)) ≈ 0.000409° in longitude. Two
      // 25 m discs 30 m apart are properly disjoint, so none is
      // contained in any other.
      const double lonStepDeg = 30.0 / 73225.0; // ≈ 0.000410°
      for (int i = 0; i < 5; i++) {
        await store.addDisc(
          _disc(
            id: 'rvd_01HRDISCWALK${i.toString().padLeft(13, '0')}A',
            sessionId: sessionId,
            lat: 48.86,
            lon: 2.36 + i * lonStepDeg,
          ),
        );
      }

      final dropped = await store.compactSession(sessionId);
      expect(dropped, 0, reason: 'walking-path discs are not contained in each other');

      final post = await store.discsForSession(sessionId);
      expect(post, hasLength(5));
    });

    test('mixed: stationary cluster + walking path → cluster collapses, path intact', () async {
      // Stationary cluster (3 discs at one centre).
      for (int i = 0; i < 3; i++) {
        await store.addDisc(_disc(id: 'rvd_01HRDISCMIXEDSTATION${i.toString().padLeft(4, '0')}', sessionId: sessionId, lat: 48.86, lon: 2.36));
      }
      // Walking path (4 discs spaced 30 m east).
      const double lonStepDeg = 30.0 / 73225.0;
      for (int i = 0; i < 4; i++) {
        await store.addDisc(
          _disc(
            id: 'rvd_01HRDISCMIXEDWALK${i.toString().padLeft(8, '0')}',
            sessionId: sessionId,
            lat: 48.87, // distinct latitude → no overlap with the stationary cluster
            lon: 2.36 + i * lonStepDeg,
          ),
        );
      }

      final pre = await store.discsForSession(sessionId);
      expect(pre, hasLength(7));

      final dropped = await store.compactSession(sessionId);
      expect(dropped, 2, reason: 'cluster collapses 3→1, walking path keeps 4');

      final post = await store.discsForSession(sessionId);
      expect(post, hasLength(5));
    });

    test('compaction is idempotent — running it twice returns 0 the second time', () async {
      for (int i = 0; i < 5; i++) {
        await store.addDisc(_disc(id: 'rvd_01HRDISCIDEM2RUN${i.toString().padLeft(8, '0')}A', sessionId: sessionId, lat: 48.86, lon: 2.36));
      }

      final firstRun = await store.compactSession(sessionId);
      expect(firstRun, 4);

      final secondRun = await store.compactSession(sessionId);
      expect(secondRun, 0);

      final post = await store.discsForSession(sessionId);
      expect(post, hasLength(1));
    });
  });

  test('FK cascade — deleting a session row removes its discs', () async {
    await store.addDisc(_disc(id: 'rvd_01HRDISCCASCADE000000000A', sessionId: sessionId));
    await store.addDisc(_disc(id: 'rvd_01HRDISCCASCADESURVIVE00A', sessionId: otherSessionId));

    expect(await store.discsForSession(sessionId), hasLength(1));
    expect(await store.discsForSession(otherSessionId), hasLength(1));

    // Delete the session — FK ON DELETE CASCADE must drop the disc row.
    await db.customStatement("DELETE FROM t_sessions WHERE id = '$sessionId'");

    expect(await store.discsForSession(sessionId), isEmpty, reason: 'FK ON DELETE CASCADE did not fire on t_revealed_disc');
    expect(await store.discsForSession(otherSessionId), hasLength(1), reason: 'other session must be untouched');
  });
}
