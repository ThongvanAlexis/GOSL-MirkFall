// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:test/test.dart';

/// Paired test for `tool/check_mirk_fixture_fresh.dart`.
///
/// Wave 0 trivial assertion: invoke the script as a subprocess and expect
/// exit 0 (the inert scaffold prints a one-liner and returns). Wave 7
/// (plan 09-08) extends with a "tamper a byte → exit 1" mutation branch
/// once the real diff logic lands.
///
/// Subprocess invocation (vs direct function import) is intentional:
/// the gate's CI contract is shaped around exit codes, and Wave 7's diff
/// logic will be most naturally tested against process exit codes. Locking
/// in the invocation shape now means Wave 7 only adds assertions, not a
/// rewrite of the test scaffold.
void main() {
  group('check_mirk_fixture_fresh subprocess', () {
    test('exits 0 on the current repo state (Wave 0 inert scaffold)', () async {
      final ProcessResult result = await Process.run(Platform.executable, <String>['run', 'tool/check_mirk_fixture_fresh.dart']);
      // Surface stdout/stderr in the test failure message if the exit
      // code drifts — speeds up debugging on CI without extra rerun.
      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}\nstderr=${result.stderr}');
    });
  });
}
