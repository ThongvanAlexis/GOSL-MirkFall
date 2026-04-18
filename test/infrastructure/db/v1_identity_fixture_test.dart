// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Finding #6 (Batch J) — migration tag discipline restored.
// SchemaVerifier is slow; tag pins this test to `dart test -t migration`
// just like migration_v1_to_v2_test.dart.
@Tags(<String>['migration'])
library;

import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('SC#1 identity: V1 seed SQL loads against DatabaseAtV1, row counts match', () async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());

    try {
      final sqlFilename = p.join(Directory.current.path, 'test', 'fixtures', 'db_seed', 'v1_baseline.sql');
      final sqlSeed = File(sqlFilename).readAsStringSync();

      // Strip SQL line comments AND block comments BEFORE splitting on ';' —
      // some comments contain ';' in the prose (e.g. "'stopped'; partial
      // unique index...") and a naive split-then-filter would execute the
      // post-';' prose fragment as SQL.
      //
      // Finding #30 (Batch J) — previously only line comments (`-- ...`)
      // were stripped; `/* block comments */` fell through and similarly
      // risked containing `;`. The block-comment pass is minimal: a
      // non-greedy regex `/\* ... \*/` over the multiline source (dotAll
      // so it crosses line boundaries). SQL string literals containing
      // `/*` are rare in our fixtures; if that changes, upgrade to a
      // proper tokenizer.
      final blockCommentStripped = sqlSeed.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      final stripped = blockCommentStripped
          .split('\n')
          .map((line) {
            final trimmed = line.trimLeft();
            if (trimmed.startsWith('--')) return '';
            return line;
          })
          .join('\n');

      for (final stmt in stripped.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        await oldDb.customStatement(stmt);
      }

      Future<int> countRows(String table) async {
        final row = await oldDb.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
        return row.read<int>('c');
      }

      expect(await countRows('t_sessions'), 10, reason: 'fixture header claims 10 sessions');
      expect(await countRows('t_markers'), 50, reason: 'fixture header claims 50 markers');
      expect(await countRows('t_revealed_tiles'), 5, reason: 'fixture header claims 5 revealed_tiles');
      expect(await countRows('t_marker_categories'), 3, reason: 'fixture header claims 3 categories');
      expect(await countRows('t_mirk_styles'), 2, reason: 'fixture header claims 2 mirk_styles');
    } finally {
      await oldDb.close();
    }
  });

  test('SC#1 sentinel: committed drift_schema_v1.json contains expected '
      'table + partial-index keys', () async {
    // Bytewise V1 schema is guarded by the CI `drift_dev schema dump`
    // drift-detection step (see 03-01 gates job). This test is a local
    // sentinel so the failure surfaces under `dart test` without waiting
    // for the CI round-trip.
    final committedJson = await File(p.join(Directory.current.path, 'drift_schemas', 'drift_schema_v1.json')).readAsString();

    expect(committedJson, isNotEmpty);
    expect(committedJson, contains('t_sessions'));
    expect(committedJson, contains('t_markers'));
    expect(committedJson, contains('t_revealed_tiles'));
    expect(committedJson, contains('idx_t_sessions_status_active'));
  });
}
