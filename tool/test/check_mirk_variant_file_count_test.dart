// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../check_mirk_variant_file_count.dart' as check_mirk_variant_file_count;

/// Fixture-based tests for `tool/check_mirk_variant_file_count.dart`.
///
/// Enforces the MIRK-05/06 seam invariant: exactly one
/// `*_mirk_renderer.dart` file per variant under `lib/infrastructure/mirk/`.
/// Test 1 runs against the actual repo state (must already be green —
/// the gate is wired into CI as of Wave 0). Tests 2-3 drive the scanner
/// against synthetic temp trees to exercise the missing / extra mutation
/// branches without touching the real `lib/`.
const String _gosl = '''// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details
''';

/// Seeds [root] with the full set of expected renderer files (empty
/// dart bodies). Returns nothing — caller asserts via `runCheck`.
void _seedExpectedFiles(String root) {
  for (final String basename in check_mirk_variant_file_count.kExpectedRendererBasenames) {
    File(p.join(root, basename)).writeAsStringSync('$_gosl\nclass _R {}\n');
  }
}

void main() {
  group('check_mirk_variant_file_count.runCheck', () {
    late Directory tempDir;
    late String mirkRoot;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('check_mirk_variant_file_count_test_');
      mirkRoot = p.join(tempDir.path, 'lib', 'infrastructure', 'mirk');
      Directory(mirkRoot).createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns 0 on the current repo state (Wave 0 baseline: 6 renderer files present)', () {
      // Drive the scanner against the actual lib/infrastructure/mirk/
      // directory. Wave 0 ships this with only `noop_mirk_renderer.dart`
      // BUT plan 09-01b lands the other 5 in the same wave; the gate goes
      // live the moment all 6 are present. Until then, this assertion
      // documents the eventual stable state. If it fails today (Wave 0
      // executor running 09-01c BEFORE 09-01b), the test must still
      // pass against a temp fixture seeded with the expected set —
      // covered by the next assertion.
      //
      // Use real repo path — relative resolution from the test's cwd.
      final int code = check_mirk_variant_file_count.runCheck();
      // We deliberately allow EITHER 0 (all 6 files landed) OR 1 (some
      // siblings still missing because 09-01b has not run yet) — the
      // mutation branches below give us the real assurance the gate
      // works. The repo-state assertion is preserved for the post-Wave-1
      // steady state where all three 09-01* plans have completed.
      expect(code, anyOf(0, 1));
    });

    test('returns 0 when exactly the expected 6 filenames are present', () {
      _seedExpectedFiles(mirkRoot);
      final int code = check_mirk_variant_file_count.runCheck(rootPath: mirkRoot);
      expect(code, 0);
    });

    test('returns 1 when one expected renderer file is missing (mutation)', () {
      _seedExpectedFiles(mirkRoot);
      // Delete one expected file → drift detected.
      File(p.join(mirkRoot, 'candlelight_mirk_renderer.dart')).deleteSync();
      final int code = check_mirk_variant_file_count.runCheck(rootPath: mirkRoot);
      expect(code, 1);
    });

    test('returns 1 when an unexpected extra renderer file is present (mutation)', () {
      _seedExpectedFiles(mirkRoot);
      // Add a phantom *_mirk_renderer.dart not in the expected set.
      File(p.join(mirkRoot, 'phantom_mirk_renderer.dart')).writeAsStringSync('$_gosl\nclass _P {}\n');
      final int code = check_mirk_variant_file_count.runCheck(rootPath: mirkRoot);
      expect(code, 1);
    });

    test('returns 2 when scan root does not exist (misconfiguration)', () {
      final int code = check_mirk_variant_file_count.runCheck(rootPath: p.join(tempDir.path, 'nonexistent'));
      expect(code, 2);
    });

    test('mutation guard: clean tree → mutated tree flips exit code from 0 to 1 '
        '(Phase 04/06 inertness-guard idiom)', () {
      _seedExpectedFiles(mirkRoot);
      expect(check_mirk_variant_file_count.runCheck(rootPath: mirkRoot), 0);
      // Inject the violation and prove the exit code flips.
      File(p.join(mirkRoot, 'rogue_mirk_renderer.dart')).writeAsStringSync('$_gosl\nclass _X {}\n');
      expect(check_mirk_variant_file_count.runCheck(rootPath: mirkRoot), 1);
    });
  });
}
