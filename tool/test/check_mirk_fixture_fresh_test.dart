// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Paired test for `tool/check_mirk_fixture_fresh.dart`.
///
/// Plan 09-08 Task 1 RED — tests both branches of the freshness gate now
/// that the real diff logic lands:
///
/// 1. exit 0 when the committed `test/fixtures/mirk/fifty_k_tiles_seed.sql`
///    matches what the builder produces.
/// 2. exit 1 when the committed fixture is tampered (1 byte changed) —
///    test backs the file up, mutates it, runs the gate, restores.
///
/// Subprocess invocation (vs direct function import) is intentional: the
/// gate's CI contract is shaped around exit codes.
void main() {
  group('check_mirk_fixture_fresh subprocess', () {
    final String fixturePath = p.join(Directory.current.path, 'test', 'fixtures', 'mirk', 'fifty_k_tiles_seed.sql.gz');

    test('exits 0 when the committed fixture matches the builder output', () async {
      // Pre-condition: the fixture exists. If this fails, the builder
      // hasn't been run yet — the green ratchet on this gate depends
      // on the SQL fixture being committed alongside the builder.
      expect(File(fixturePath).existsSync(), isTrue, reason: 'Expected committed fixture at $fixturePath');

      final ProcessResult result = await Process.run(Platform.executable, <String>['run', 'tool/check_mirk_fixture_fresh.dart']);
      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}\nstderr=${result.stderr}');
    });

    test('exits 1 when the committed fixture is tampered', () async {
      final File fixture = File(fixturePath);
      expect(fixture.existsSync(), isTrue);

      // Backup, mutate, run, restore. Mutation flips a single byte at
      // a position guaranteed to land inside an INSERT bitmap (the
      // SQL header is < 200 bytes; row 1 starts well past that).
      final List<int> backup = fixture.readAsBytesSync();
      try {
        final List<int> tampered = List<int>.from(backup);
        // Pick an offset deep enough to hit a hex literal inside an
        // INSERT row.  The fixture is multi-MB; offset 5000 is
        // comfortably past the prelude.
        const int targetOffset = 5000;
        tampered[targetOffset] = (tampered[targetOffset] ^ 0x01) & 0xFF;
        fixture.writeAsBytesSync(tampered, flush: true);

        final ProcessResult result = await Process.run(Platform.executable, <String>['run', 'tool/check_mirk_fixture_fresh.dart']);
        expect(result.exitCode, 1, reason: 'tamper should cause exit 1\nstdout=${result.stdout}\nstderr=${result.stderr}');
      } finally {
        fixture.writeAsBytesSync(backup, flush: true);
      }
    });
  });
}
