// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:test/test.dart';

import 'fake_revealed_disc_store.dart';

RevealDisc _disc({
  required String id,
  required String sessionId,
  double lat = 48.8566,
  double lon = 2.3522,
  double radiusMeters = 25.0,
  DateTime? fixedAtUtc,
}) => RevealDisc(id: id, sessionId: sessionId, lat: lat, lon: lon, radiusMeters: radiusMeters, fixedAtUtc: fixedAtUtc ?? DateTime.utc(2026, 4, 26, 12));

void main() {
  late FakeRevealedDiscStore store;
  const String sessionId = 'sess_01HRFAKEDISCSTOREMAIN0000A';

  setUp(() {
    store = FakeRevealedDiscStore();
  });

  test('addDisc + discsForSession round-trip + counter increments', () async {
    final disc = _disc(id: 'rvd_01HRFAKEROUNDTRIP0000000AA', sessionId: sessionId);
    await store.addDisc(disc);

    expect(store.addDiscCallCount, 1);
    final rows = await store.discsForSession(sessionId);
    expect(rows, hasLength(1));
    expect(rows.single.id, disc.id);
    expect(store.discsForSessionCallCount, 1);
  });

  test('addDisc is idempotent on duplicate id', () async {
    final disc = _disc(id: 'rvd_01HRFAKEIDEMPOTENT0000000A', sessionId: sessionId);
    await store.addDisc(disc);
    await store.addDisc(disc);
    await store.addDisc(disc);

    expect(store.discCount, 1);
    expect(store.addDiscCallCount, 3, reason: 'counter still increments — only the persisted row count is dedup');
  });

  test('discsInBbox filters by both sessionId and bbox', () async {
    final MirkViewportBbox parisBbox = MirkViewportBbox(south: 48.80, west: 2.30, north: 48.91, east: 2.42);
    await store.addDisc(_disc(id: 'rvd_01HRFAKEBBOXIN00000000000A', sessionId: sessionId, lat: 48.86, lon: 2.36));
    await store.addDisc(_disc(id: 'rvd_01HRFAKEBBOXOUT0000000000A', sessionId: sessionId, lat: 35.68, lon: 139.76));
    await store.addDisc(_disc(id: 'rvd_01HRFAKEBBOXOTHER0000000A', sessionId: 'sess_01HRFAKEDISCSTOREOTHER0000', lat: 48.86, lon: 2.36));

    final hits = await store.discsInBbox(sessionId: sessionId, bbox: parisBbox);
    expect(hits, hasLength(1));
    expect(hits.single.id, 'rvd_01HRFAKEBBOXIN00000000000A');
    expect(store.discsInBboxCallCount, 1);
  });

  test('compactSession collapses stationary cluster + path stays intact', () async {
    // 3 stationary discs.
    for (int i = 0; i < 3; i++) {
      await store.addDisc(_disc(id: 'rvd_01HRFAKECOMPACT${i.toString().padLeft(10, '0')}', sessionId: sessionId, lat: 48.86, lon: 2.36));
    }
    // 2 walking discs (30 m east) at a different latitude.
    const double lonStepDeg = 30.0 / 73225.0;
    for (int i = 0; i < 2; i++) {
      await store.addDisc(_disc(id: 'rvd_01HRFAKECOMPACTWALK${i.toString().padLeft(5, '0')}', sessionId: sessionId, lat: 48.87, lon: 2.36 + i * lonStepDeg));
    }

    final dropped = await store.compactSession(sessionId);
    expect(dropped, 2, reason: 'cluster collapses 3→1, path keeps both');
    expect(store.discCount, 3);
    expect(store.compactSessionCallCount, 1);
  });

  test('reset clears state and counters', () async {
    await store.addDisc(_disc(id: 'rvd_01HRFAKERESET00000000000AA', sessionId: sessionId));
    expect(store.discCount, 1);
    expect(store.addDiscCallCount, 1);

    store.reset();
    expect(store.discCount, 0);
    expect(store.addDiscCallCount, 0);
    expect(store.discsForSessionCallCount, 0);
    expect(store.discsInBboxCallCount, 0);
    expect(store.compactSessionCallCount, 0);
  });
}
