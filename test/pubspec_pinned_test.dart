// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the FOUND-05 requirement: no caret / tilde version ranges allowed in
/// `dependencies:` or `dev_dependencies:` of pubspec.yaml.
///
/// SDK ranges in the `environment:` block are allowed (pub refuses exact
/// pins on SDK constraints — see RESEARCH.md §Pitfall 1).
void main() {
  test('pubspec.yaml has no `^` or `~` in dependencies / dev_dependencies', () {
    final File pubspecFile = File('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must exist at repo root for this test to run.');

    final List<String> lines = pubspecFile.readAsLinesSync();

    // Section tracking: we only enforce the pin rule inside
    // `dependencies:` and `dev_dependencies:` (top-level blocks).
    const Set<String> enforcedSectionSet = <String>{'dependencies', 'dev_dependencies'};

    String? currentSection;
    final List<String> offendingLines = <String>[];

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final String rawLine = lines[lineIndex];
      final String trimmedLine = rawLine.trimLeft();

      // Skip blanks and comments.
      if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
        continue;
      }

      // Detect a new top-level section (no leading indentation).
      final bool isTopLevelKey = rawLine == trimmedLine && trimmedLine.endsWith(':');
      if (isTopLevelKey) {
        final String sectionName = trimmedLine.substring(0, trimmedLine.length - 1);
        currentSection = sectionName;
        continue;
      }

      if (currentSection == null || !enforcedSectionSet.contains(currentSection)) {
        continue;
      }

      // Within an enforced section: fail on `^` or `~` preceded by a colon
      // (i.e. version specifier position). This avoids false positives on
      // SHA256 hashes or bitwise operators that never appear in pubspec
      // anyway.
      final RegExp caretOrTildeVersion = RegExp(r':\s*[\^~]\d');
      if (caretOrTildeVersion.hasMatch(trimmedLine)) {
        offendingLines.add('line ${lineIndex + 1}: $trimmedLine');
      }
    }

    expect(
      offendingLines,
      isEmpty,
      reason:
          'pubspec.yaml must pin every dependency exactly (no `^`, no `~`). '
          'Offending lines:\n${offendingLines.join('\n')}',
    );
  });
}
