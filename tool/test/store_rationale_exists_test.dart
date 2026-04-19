// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// QUAL-03 gate: `docs/store-review-rationale.md` exists with the 5
/// section headings mandated by 05-CONTEXT.md §Permission + Store copy,
/// plus the GitHub repo URL and contact email that store reviewers need.
///
/// Deliberately strict string matches (exact headings, exact URL, exact
/// email) — any drift in the document's structure should fail this test
/// so the maintainer makes an explicit choice about section naming.
///
/// Related: `info_plist_final_copy_test.dart` gates QUAL-04 (Info.plist
/// final usage-description copy).
void main() {
  final String rationaleFilename = p.join(Directory.current.path, 'docs', 'store-review-rationale.md');

  late String content;
  late int lineCount;

  setUpAll(() {
    final File file = File(rationaleFilename);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'docs/store-review-rationale.md must exist (QUAL-03). '
          'Expected at: $rationaleFilename',
    );
    content = file.readAsStringSync();
    // Split on \n so CRLF checkouts on Windows still produce the right
    // line count (empty last element is intentional for trailing newline).
    lineCount = content.split('\n').length;
  });

  test('has 5 required section headings', () {
    const List<String> requiredHeadings = <String>[
      '## Project description',
      '## Why Always location is required',
      '## Data handling',
      '## Source code accessibility',
      '## Contact',
    ];
    for (final String heading in requiredHeadings) {
      expect(content, contains(heading), reason: 'Missing required heading: "$heading"');
    }
  });

  test('is at least 50 lines of substantive content', () {
    expect(
      lineCount,
      greaterThanOrEqualTo(50),
      reason:
          'Rationale is too short ($lineCount lines) — reviewers expect '
          'a defensible multi-paragraph document, not a stub.',
    );
  });

  test('contains the GitHub repository URL', () {
    expect(
      content,
      contains('github.com/saibashirudo/GOSL-MirkFall'),
      reason:
          'Source-code accessibility section must link to the public repo '
          '(GitHub URL missing).',
    );
  });

  test('contains the maintainer contact email', () {
    expect(content, contains('saibashirudo@protonmail.com'), reason: 'Contact section must surface a reachable email address.');
  });

  test('declares GOSL v1.0 distribution', () {
    expect(
      content,
      contains('GOSL v1.0'),
      reason:
          'Rationale must name the license under which MirkFall is '
          'distributed — keeps reviewer expectations calibrated to the '
          'sideload + zero-revenue distribution model.',
    );
  });
}
