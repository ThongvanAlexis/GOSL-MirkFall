// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the FOUND-05 requirement: no caret / tilde version ranges allowed in
/// `dependencies:`, `dev_dependencies:`, or `dependency_overrides:` of
/// pubspec.yaml (finding #28, Batch J — previously the overrides section was
/// silently skipped, meaning a caret drifting in via a merge could bypass the
/// gate).
///
/// Known-intentional caret overrides are allowlisted below with rationale —
/// the allowlist is a deliberate narrow hole so the test catches UNEXPECTED
/// carets in overrides without flagging the ones we ship on purpose.
///
/// SDK ranges in the `environment:` block are allowed (pub refuses exact
/// pins on SDK constraints — see RESEARCH.md §Pitfall 1).
void main() {
  test('pubspec.yaml has no `^` or `~` in dependencies / dev_dependencies / dependency_overrides '
      '(finding #28 / Batch J)', () {
    final File pubspecFile = File('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must exist at repo root for this test to run.');

    final List<String> lines = pubspecFile.readAsLinesSync();

    // Section tracking: enforce the pin rule inside `dependencies:`,
    // `dev_dependencies:`, AND `dependency_overrides:`.
    const Set<String> enforcedSectionSet = <String>{'dependencies', 'dev_dependencies', 'dependency_overrides'};

    // Allowlist of intentional caret overrides (finding #28, Batch J).
    // Each entry is `package_name` — lines matching `^<ws>package_name:\s*\^`
    // in the dependency_overrides section are exempted. Every allowlisted
    // package MUST be referenced in CLAUDE.md / DEPENDENCIES.md / a plan
    // summary with a rationale for why the caret is load-bearing.
    //
    // analyzer: ^10.0.0 is required because drift_dev 2.32.1 + freezed 3.2.5
    // + json_serializable 6.13.1 + riverpod_generator 4.0.3 declare
    // overlapping-but-non-identical analyzer constraints across the 10.x
    // range; an exact pin overconstrains the resolver and fails pub get.
    // Documented in pubspec.yaml itself + DEPENDENCIES.md custom_lint row.
    const Set<String> overridesCaretAllowlist = <String>{'analyzer'};

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
      if (!caretOrTildeVersion.hasMatch(trimmedLine)) {
        continue;
      }

      // Allowlist carve-out: only applies inside dependency_overrides,
      // only for documented packages.
      if (currentSection == 'dependency_overrides') {
        final RegExp packageKey = RegExp(r'^\s*([a-z0-9_]+)\s*:');
        final Match? match = packageKey.firstMatch(rawLine);
        if (match != null && overridesCaretAllowlist.contains(match.group(1))) {
          continue;
        }
      }

      offendingLines.add('line ${lineIndex + 1} (section $currentSection): $trimmedLine');
    }

    expect(
      offendingLines,
      isEmpty,
      reason:
          'pubspec.yaml must pin every dependency exactly (no `^`, no `~`) '
          'in dependencies / dev_dependencies / dependency_overrides. '
          'Offending lines:\n${offendingLines.join('\n')}',
    );
  });
}
