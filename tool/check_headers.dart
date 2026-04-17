// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

/// CI gate: scans every non-generated `*.dart` file under the configured roots
/// (default: `lib/`, `test/`, `tool/`) and fails (exit 1) if any file does not
/// start with the exact GOSL v1.0 three-line header.
///
/// Matching is byte-exact — no regex fuzziness — so "close enough" headers
/// still fail. Excludes codegen outputs (`*.g.dart`, `*.freezed.dart`, etc.)
/// and conventional `generated/` / `build/` / `.dart_tool/` directories.
const String _expectedHeader = '''// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details''';

final List<RegExp> _excludePatterns = <RegExp>[
  // Build-generated files — explicitly exempt from the GOSL header rule per
  // CLAUDE.md convention. Every codegen tool in common use gets its own
  // suffix match; keep the list exhaustive so new generators in later phases
  // don't silently pollute the failure report.
  RegExp(r'\.g\.dart$'),
  RegExp(r'\.freezed\.dart$'),
  RegExp(r'\.gr\.dart$'),
  RegExp(r'\.config\.dart$'),
  RegExp(r'\.pb\.dart$'), // protobuf
  RegExp(r'\.pbenum\.dart$'), // protobuf enums
  RegExp(r'\.pbjson\.dart$'), // protobuf json
  RegExp(r'\.pbserver\.dart$'), // protobuf gRPC server stubs
  RegExp(r'\.swagger\.dart$'), // chopper swagger
  RegExp(r'\.chopper\.dart$'), // chopper
  RegExp(r'\.mocks\.dart$'), // mockito
  RegExp(r'[/\\]generated[/\\]'),
  RegExp(r'[/\\]\.dart_tool[/\\]'),
  RegExp(r'[/\\]build[/\\]'),
];

const List<String> _defaultRoots = <String>['lib', 'test', 'tool'];

/// Runs the header check. Accepts an optional list of root directories — if
/// empty the default `lib/test/tool` roots are scanned. Returns the process
/// exit code: 0 on success, 1 when at least one file is missing the header,
/// 2 if all roots are absent.
Future<int> runCheck(List<String> args) async {
  final List<String> roots = args.isNotEmpty ? args : _defaultRoots;
  final List<String> failures = <String>[];
  var scanned = 0;
  var rootsSeen = 0;

  for (final String rootPath in roots) {
    final Directory root = Directory(rootPath);
    if (!await root.exists()) continue;
    rootsSeen++;

    await for (final FileSystemEntity entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final String normalized = entity.path.replaceAll('\\', '/');
      if (!normalized.endsWith('.dart')) continue;
      if (_excludePatterns.any((RegExp re) => re.hasMatch(normalized))) continue;

      scanned++;
      final String contents = await entity.readAsString();
      // Strip leading BOM if present — some editors inject it silently.
      final String trimmed = contents.startsWith('\uFEFF') ? contents.substring(1) : contents;
      if (!trimmed.startsWith(_expectedHeader)) {
        failures.add(entity.path);
        continue;
      }
      // The header match must be followed by a line break — otherwise a file
      // starting with `// Copyright ...details// hack injected on same line`
      // would pass the startsWith check while actually concatenating arbitrary
      // content onto the final header line (minor poison vector).
      final int headerEnd = _expectedHeader.length;
      if (trimmed.length == headerEnd) continue; // EOF right after header — acceptable.
      final String afterHeader = trimmed.substring(headerEnd);
      if (!afterHeader.startsWith('\n') && !afterHeader.startsWith('\r\n')) {
        failures.add(entity.path);
      }
    }
  }

  if (rootsSeen == 0) {
    stderr.writeln('check_headers: no roots found (tried: ${roots.join(', ')})');
    return 2;
  }

  if (failures.isEmpty) {
    stdout.writeln('check_headers: OK ($scanned files)');
    return 0;
  }
  stderr.writeln('check_headers: ${failures.length} file(s) missing GOSL v1.0 header:');
  for (final String f in failures) {
    stderr.writeln('  - $f');
  }
  stderr.writeln();
  stderr.writeln('Expected exact header (3 lines, no trailing blank):');
  stderr.writeln(_expectedHeader);
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck(args);
  exitCode = code;
}
