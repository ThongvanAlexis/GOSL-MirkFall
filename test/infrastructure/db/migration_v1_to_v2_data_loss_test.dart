// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Phase 04 Adversarial Test #3 — permanent regression guard.
///
/// Proves that [SchemaSanityChecker.assertNoLoss] throws
/// [MigrationFailureException] when an adversarial V1→V2 migration loses
/// rows. Pattern reuses `migration_v1_to_v2_test.dart` for V1 fixture
/// loading and `schema_sanity_test.dart` for the checker invocation.
///
/// Why permanent: this is not a throwaway CI branch — the adversarial
/// discipline for runtime code (production [SchemaSanityChecker]) is a
/// unit test that lives in the repo forever. Future migrations (Phase 05+)
/// cannot silently bypass the safeguard: any onUpgrade implementation that
/// drops rows will be caught by this same assertion path at runtime + here
/// in the test suite with a concrete adversarial fixture.
@Tags(<String>['migration'])
library;

import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:mirkfall/domain/errors/migration_errors.dart';
import 'package:mirkfall/infrastructure/db/schema_sanity.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('SchemaSanityChecker row-loss regression guard (Phase 04 Test #3)', () {
    test('assertNoLoss throws MigrationFailureException when adversarial '
        'DELETE loses ~50% of t_sessions during a V1→V2-shaped migration', () async {
      // 1. Load the 03-01 V1 fixture (70 rows across 6 tables) into a
      //    V1 schema. Pattern mirrors migration_v1_to_v2_test.dart's
      //    "full v1_baseline.sql fixture" case so we reuse the same
      //    SQL-comment-stripping discipline (a naive `;` split would
      //    execute comment prose as SQL).
      final schema = await verifier.schemaAt(1);
      final seedDb = v1.DatabaseAtV1(schema.newConnection());
      final Map<String, int> before;
      try {
        final sqlFilename = p.join(Directory.current.path, 'test', 'fixtures', 'db_seed', 'v1_baseline.sql');
        final sqlSeed = File(sqlFilename).readAsStringSync();

        // Block-comment strip added by finding #30 (Batch J) so this test
        // shares the same tokenization contract as the two Phase 03 SQL
        // loaders.
        final blockCommentStripped = sqlSeed.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
        final stripped = blockCommentStripped
            .split('\n')
            .map((String line) {
              final trimmed = line.trimLeft();
              if (trimmed.startsWith('--')) return '';
              return line;
            })
            .join('\n');

        for (final stmt in stripped.split(';').map((String s) => s.trim()).where((String s) => s.isNotEmpty)) {
          await seedDb.customStatement(stmt);
        }

        // 2. Capture pre-migration row counts.
        final sanity = SchemaSanityChecker(seedDb.executor);
        before = await sanity.captureRowCounts();

        // Fixture sanity: confirm the fixture loaded as expected so a
        // fixture regression shows up here, not only downstream.
        expect(before['t_sessions'], 10, reason: 'fixture should ship 10 sessions; regression if changed');
        expect(before['t_markers'], 50);
        expect(before['t_revealed_tiles'], 5);

        // 3. Run the ADVERSARIAL migration directly against the V1
        //    executor: the legitimate V1→V2 change (ALTER TABLE ADD
        //    COLUMN notes) PLUS the adversarial row-loss (DELETE ~50%
        //    of t_sessions). Executing on the V1 DB keeps the raw SQL
        //    simple and avoids the AppDatabase construction path —
        //    we're not testing the prod migration wiring here, we're
        //    testing that the checker detects loss regardless of how
        //    the DELETE got there.
        await seedDb.customStatement('ALTER TABLE t_sessions ADD COLUMN "notes" TEXT NULL');
        await seedDb.customStatement('DELETE FROM t_sessions WHERE rowid % 2 = 0');

        // 4. Capture post-adversary counts.
        final after = await sanity.captureRowCounts();

        // Sanity: confirm the DELETE actually removed rows. If this
        // ever passes without row loss, the test is silently inert —
        // the rowid-parity DELETE MUST drop at least one session for
        // the assertion below to be meaningful.
        expect(
          after['t_sessions']! < before['t_sessions']!,
          isTrue,
          reason:
              'adversarial DELETE did not remove any session row — '
              'test would be inert. before=${before['t_sessions']} '
              'after=${after['t_sessions']}',
        );

        // 5. Expect MigrationFailureException with a message pointing at
        //    t_sessions and mentioning the before→after decrease. The
        //    prod checker message is "row count decreased on <table>:
        //    <before> → <after>" (see lib/infrastructure/db/schema_sanity.dart).
        expect(
          () => sanity.assertNoLoss(before, after),
          throwsA(
            isA<MigrationFailureException>()
                .having((MigrationFailureException e) => e.reason, 'reason', contains('t_sessions'))
                .having((MigrationFailureException e) => e.reason, 'reason', anyOf(contains('decreased'), contains('lost'))),
          ),
        );
      } finally {
        await seedDb.close();
      }
    });
  });
}
