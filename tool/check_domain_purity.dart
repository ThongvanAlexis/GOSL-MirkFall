// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// Forbidden-import scanner for `lib/domain/`.
///
/// Domain purity invariant (Phase 03 SC#4): zero imports of `package:flutter`
/// or `package:drift` under `lib/domain/`. Application + infrastructure
/// layers may freely use them; the domain layer must stay pure Dart so
/// `dart test test/domain/` runs without a Flutter toolchain (and so that
/// the domain stays portable to a future CLI or server-side reuse).
///
/// Generated files (`*.g.dart`, `*.freezed.dart`, etc.) are exempt — they
/// are produced from annotated source and are not in scope for the purity
/// rule applied to hand-written domain code.
///
/// CLI contract (Phase 01 convention): exit 0 = clean, 1 = violations
/// found, 2 = misconfiguration (root missing, unreadable, etc.).
const List<String> _excludedSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.config.dart',
  '.mocks.dart',
];

/// Forbidden-package matcher. Anchored on `package:flutter/...` and
/// `package:drift/...` only — `package:drift_dev/` is dev-only codegen
/// and would never appear at runtime under `lib/`, but if it ever did
/// the broader `package:drift` prefix already catches it via the slash
/// boundary or the closing quote (the alternation `(?:/|['"])` accepts
/// either a path separator or the import string's terminator).
final RegExp _forbiddenPattern = RegExp(
  r"""^\s*import\s+['"]package:(flutter|drift)(?:/|['"])""",
);

/// Runs the scan against [rootPath] (default `lib/domain`).
///
/// Public so unit tests can drive the scanner against synthetic fixture
/// trees built with `Directory.systemTemp.createTemp`. The same shape as
/// `tool/check_headers.dart`'s `runCheck` so future CI gates can compose
/// the family the same way.
Future<int> runCheck({String? rootPath}) async {
  final String resolvedRoot = rootPath ?? p.join(Directory.current.path, 'lib', 'domain');
  final Directory domainDir = Directory(resolvedRoot);
  if (!domainDir.existsSync()) {
    stderr.writeln('check_domain_purity: lib/domain/ not found at ${domainDir.path}');
    return 2;
  }

  final List<String> violations = <String>[];
  var scanned = 0;

  await for (final FileSystemEntity entity in domainDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final String normalized = entity.path.replaceAll('\\', '/');
    if (!normalized.endsWith('.dart')) continue;
    if (_excludedSuffixes.any(normalized.endsWith)) continue;

    scanned++;
    final List<String> lines = await entity.readAsLines();
    for (var i = 0; i < lines.length; i++) {
      if (_forbiddenPattern.hasMatch(lines[i])) {
        violations.add('${p.relative(entity.path)}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_domain_purity: OK ($scanned files, zero forbidden imports)');
    return 0;
  }

  stderr.writeln('check_domain_purity: ${violations.length} forbidden import(s) under lib/domain/:');
  for (final String v in violations) {
    stderr.writeln('  $v');
  }
  stderr.writeln();
  stderr.writeln('Rule: lib/domain/ must not import package:flutter/* or package:drift/*.');
  stderr.writeln('Move the offending import to lib/application/ or lib/infrastructure/.');
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
