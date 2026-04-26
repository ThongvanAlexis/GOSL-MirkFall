// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/domain/errors/migration_errors.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/db/schema_sanity.dart';
import 'package:test/test.dart';

/// Tests for [SchemaSanityChecker] — pre/post row-count capture + hard-fail on
/// loss (RESEARCH pitfall #7: SchemaVerifier validates schema shape, not data
/// survival).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('PRAGMA journal_mode = WAL');
          },
        ),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('captureRowCounts returns all 6 tables on a fresh DB', () async {
    // Force open + migration so the schema is materialized.
    await db.customStatement('SELECT 1');
    final checker = SchemaSanityChecker(db.executor);

    final counts = await checker.captureRowCounts();
    // BUG-010 Option B Commit 5: legacy `t_revealed_tiles` retired in V6
    // → swapped for `t_revealed_disc` (continuous-geometry reveal storage).
    expect(counts.keys, containsAll(<String>['t_sessions', 't_markers', 't_revealed_disc', 't_marker_categories', 't_mirk_styles', 't_photos']));
    // Fresh DB — every table empty EXCEPT t_marker_categories which carries
    // the onCreate-seeded `cat_default` sentinel row (04-rev Batch F /
    // finding #2).
    for (final entry in counts.entries) {
      if (entry.key == 't_marker_categories') {
        expect(entry.value, 1, reason: 't_marker_categories contains the cat_default seed row on a fresh DB');
      } else {
        expect(entry.value, 0, reason: '${entry.key} should be empty on fresh DB');
      }
    }
  });

  test('captureRowCounts reflects INSERTs', () async {
    await db.customStatement('SELECT 1');
    // cat_default is already seeded by onCreate (finding #2 / Batch F) —
    // this test previously inserted it manually, which would now PK-collide.
    // Start count for t_marker_categories is therefore 1, not 0.
    await db.customStatement(
      "INSERT INTO t_sessions "
      "(id, display_name, status, started_at_utc, started_at_offset_minutes) "
      "VALUES ('sess_S1', 'S1', 'stopped', 1000, 120)",
    );

    final checker = SchemaSanityChecker(db.executor);
    final counts = await checker.captureRowCounts();
    expect(counts['t_marker_categories'], 1, reason: 'onCreate seeded cat_default');
    expect(counts['t_sessions'], 1);
    expect(counts['t_markers'], 0);
  });

  test('assertNoLoss: identical counts → silent', () {
    final checker = SchemaSanityChecker(db.executor);
    final before = <String, int>{'t_sessions': 10, 't_markers': 50};
    final after = <String, int>{'t_sessions': 10, 't_markers': 50};
    checker.assertNoLoss(before, after); // must not throw
  });

  test('assertNoLoss: growth → silent (onUpgrade may seed rows)', () {
    final checker = SchemaSanityChecker(db.executor);
    final before = <String, int>{'t_sessions': 10, 't_marker_categories': 2};
    final after = <String, int>{'t_sessions': 10, 't_marker_categories': 3};
    checker.assertNoLoss(before, after);
  });

  test('assertNoLoss: loss → MigrationFailureException mentions table', () {
    final checker = SchemaSanityChecker(db.executor);
    final before = <String, int>{'t_sessions': 10};
    final after = <String, int>{'t_sessions': 9};
    expect(
      () => checker.assertNoLoss(before, after),
      throwsA(
        isA<MigrationFailureException>().having(
          (MigrationFailureException e) => e.reason,
          'reason',
          allOf(contains('t_sessions'), contains('10'), contains('9')),
        ),
      ),
    );
  });

  test('assertNoLoss: missing table key → treated as 0 → throws if before was non-zero', () {
    final checker = SchemaSanityChecker(db.executor);
    final before = <String, int>{'t_markers': 50};
    final after = <String, int>{}; // no entry
    expect(() => checker.assertNoLoss(before, after), throwsA(isA<MigrationFailureException>()));
  });
}
