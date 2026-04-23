// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Unit-test network-isolation guard (Plan 08-04 Task 3, Test #7).
//
// Scans every `.dart` file under `test/` for direct instantiations of
// `HttpClient()`, `http.Client()`, or `Dio()` and fails if any unit
// test reaches for real network. Complements the runtime-level
// airplane-mode test (`integration_test/airplane_mode_test.dart`)
// which proves no Phase 07 code path hits the wire under an
// HttpOverrides scope — this test proves no TEST itself sneakily
// bypasses that scope.
//
// Exclusions:
//   - Files that declare `@Tags(['integration'])` (integration_test/
//     lives in a sibling directory; but if a file under test/ ever
//     declares the tag, we respect it).
//   - Lines inside fake/mock class definitions (heuristic: line
//     containing `fake` / `Fake` case-insensitively — we own the
//     `test/fakes/` harness which includes shelf servers that legitimately
//     bind to a socket + a FakeHttpClient stub for airplane_mode_test).
//   - Comments (lines starting with `//`).
//
// Inertness guard: the scan visited ≥ 50 files. The current test tree
// is ~100+ files; a refactor that renames `test/` or empties it would
// otherwise silently pass the "no violations" assertion.
//
// Mutation experiment (author-time, Plan 08-04 Task 3):
//   1. Temporarily added `final _c = HttpClient();` to
//      `test/infrastructure/db/app_database_test.dart` (known pure-
//      Dart unit test, no Fake context).
//   2. Ran `dart test test/infrastructure/network/no_httpclient_in_unit_tests_test.dart`
//      → FAILED loudly listing the violating file + line.
//   3. Removed the line → green.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no test/ .dart file instantiates HttpClient() / http.Client() / Dio() outside fakes + integration tags', () {
    final Directory testDir = Directory('test');
    expect(testDir.existsSync(), isTrue);

    final List<File> dartFiles = testDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        // Exclude generated files (none today under test/, but pre-emptive:
        // build_runner emits .g.dart / .freezed.dart siblings that we never
        // want to scan as human code).
        .where((File f) => !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'))
        .toList();

    // Inertness guard: the scan visited enough files to be meaningful.
    // At time of writing (2026-04-23) there are ~100+ .dart test files.
    // Threshold of 50 is well below that but high enough to catch a
    // structure change that moves the tree.
    expect(
      dartFiles.length,
      greaterThan(50),
      reason:
          'test/ scan visited only ${dartFiles.length} Dart files — test inert. A refactor renaming or emptying test/ without updating this test would silently pass the "no violations" check on an empty set.',
    );

    // Patterns matched case-sensitively: `HttpClient(` (dart:io),
    // `http.Client(` (package:http), `Dio(` (package:dio, not in the
    // project today but guarded pre-emptively).
    final List<RegExp> patterns = <RegExp>[RegExp(r'\bHttpClient\s*\('), RegExp(r'\bhttp\.Client\s*\('), RegExp(r'\bDio\s*\(')];

    final List<String> violations = <String>[];

    for (final File f in dartFiles) {
      final String content = f.readAsStringSync();

      // Skip files that explicitly tag themselves as integration —
      // those are run on-demand with real network fakes (shelf, etc.)
      // and live under test/ for historical reasons. We are defensive
      // here even though the integration tests were moved to
      // integration_test/ in Plan 08-04 Task 1.
      if (content.contains("@Tags(<String>['integration'])") || content.contains("@Tags(['integration'])")) {
        continue;
      }
      // Skip files that explicitly tag themselves as soak — they spin
      // up real shelf servers + exercise real HttpClient via the
      // download controller under a _RealHttpOverrides scope. That is
      // the intended behaviour of that specific suite.
      if (content.contains("@Tags(<String>['soak'])") || content.contains("@Tags(['soak'])")) {
        continue;
      }

      final List<String> lines = content.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        final String trimmed = line.trimLeft();

        // Skip comments — a pattern inside a doc comment is not an
        // instantiation.
        if (trimmed.startsWith('//') || trimmed.startsWith('///') || trimmed.startsWith('*')) {
          continue;
        }

        for (final RegExp pat in patterns) {
          if (pat.hasMatch(line)) {
            final String lower = line.toLowerCase();
            // Heuristic: lines that define or construct a Fake-prefixed
            // class are legitimate (our test doubles). This matches
            // `_FailAllHttpClient` / `FakeHttpClient` / class-name-based
            // subclasses.
            final bool insideFakeScope =
                lower.contains('fake') ||
                // Class declarations that "implements HttpClient" are
                // our stubs; the matching pattern is the class contract,
                // not an instantiation.
                line.contains('implements HttpClient') ||
                line.contains('extends HttpClient');
            if (insideFakeScope) continue;

            violations.add('${f.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
    }

    // Main assert: no direct network instantiation in unit tests.
    expect(
      violations,
      isEmpty,
      reason:
          'unit tests must not instantiate HttpClient / http.Client / Dio — '
          'inject a fake via the test harness instead (see test/fakes/). '
          'Violations:\n${violations.join('\n')}',
    );
  });
}
