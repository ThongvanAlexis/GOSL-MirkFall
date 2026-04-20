// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// CI gate enforcing the MAP-06 seam : any `import 'package:maplibre_gl/…'`
/// (single or double quoted) must live under `lib/infrastructure/map/`.
///
/// Downstream (application / domain / presentation) code depends only on
/// the `MapView` domain interface vocabulary (`showMap`, `moveCameraTo`,
/// `addLocationMarker`…), so MapLibre SDK types (`MapLibreMapController`,
/// `SymbolOptions`, `CameraUpdate`) never bubble above the infrastructure
/// boundary. Without this gate, a well-meaning widget test or controller
/// could import `maplibre_gl` directly and quietly re-couple the app to
/// the SDK, defeating the seam the first time a follow-up renderer (e.g.
/// Mapbox GL, custom WebGL layer) is considered.
///
/// Scans recursively under `lib/`. Generated files (`*.g.dart`,
/// `*.freezed.dart`, etc.) are exempt — their imports come from codegen
/// templates and are not in scope for the rule applied to hand-written
/// code. The scanner is quote-agnostic (single OR double quotes) so a
/// stylistic choice does not bypass it.
///
/// CLI contract (Phase 01 convention, shared with `tool/check_*.dart`):
///   - exit 0 : clean. Includes the Phase 07-01 baseline where
///     `lib/infrastructure/map/` does not yet exist and no file imports
///     the SDK anywhere.
///   - exit 1 : at least one violation (file path + line number + line
///     contents emitted on stderr).
///   - exit 2 : misconfiguration — the scan root does not exist at all.
const List<String> _excludedSuffixes = <String>['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart'];

/// Matches any `import 'package:maplibre_gl/…'` or
/// `import "package:maplibre_gl/…"` at the start of a line (optional
/// leading whitespace). The trailing `(?:/|['"])` anchor accepts either a
/// path separator or the closing quote — a bare
/// `import 'package:maplibre_gl';` would also match. Case-sensitive (the
/// package name on pub.dev is lowercase).
final RegExp _leakPattern = RegExp(r"""^\s*import\s+['"]package:maplibre_gl(?:/|['"])""");

/// Forward-slash allowed prefix, compared against the normalised relative
/// path of every scanned file (backslashes → forward slashes on Windows).
/// Comparing prefixes on the normalised path avoids a brittle
/// `Platform.isWindows` branch inside the hot loop.
const String _allowedPrefix = 'infrastructure/map/';

/// Runs the scan against [rootPath] (default `lib/`).
///
/// Public so unit tests can drive the scanner against synthetic fixture
/// trees built with `Directory.systemTemp.createTemp`. Same shape as
/// `tool/check_domain_purity.dart`'s `runCheck` for family consistency.
Future<int> runCheck({String? rootPath}) async {
  final String resolvedRoot = rootPath ?? p.join(Directory.current.path, 'lib');
  final Directory libDir = Directory(resolvedRoot);
  if (!libDir.existsSync()) {
    stderr.writeln('check_avoid_maplibre_leak: lib/ not found at ${libDir.path}');
    return 2;
  }

  final List<String> violations = <String>[];
  var scanned = 0;

  await for (final FileSystemEntity entity in libDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final String normalized = entity.path.replaceAll('\\', '/');
    if (!normalized.endsWith('.dart')) continue;
    if (_excludedSuffixes.any(normalized.endsWith)) continue;

    // Normalised path RELATIVE to the scan root — so the allowed-prefix
    // check works regardless of whether `rootPath` is absolute (real CI)
    // or a Windows `%TEMP%\…\lib` (unit-test fixtures).
    final String rel = p.relative(entity.path, from: resolvedRoot).replaceAll('\\', '/');

    scanned++;
    final List<String> lines = await entity.readAsLines();
    for (var i = 0; i < lines.length; i++) {
      if (!_leakPattern.hasMatch(lines[i])) continue;
      if (rel.startsWith(_allowedPrefix)) continue;
      violations.add('${p.relative(entity.path)}:${i + 1}: ${lines[i].trim()}');
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_avoid_maplibre_leak: OK ($scanned file(s), zero maplibre_gl imports outside lib/infrastructure/map/)');
    return 0;
  }

  stderr.writeln('check_avoid_maplibre_leak: ${violations.length} forbidden import(s) outside lib/infrastructure/map/:');
  for (final String v in violations) {
    stderr.writeln('  $v');
  }
  stderr.writeln();
  stderr.writeln('Rule (MAP-06): `package:maplibre_gl` imports MUST live under lib/infrastructure/map/.');
  stderr.writeln('Move the offending import into the infra layer and depend on the MapView domain interface instead.');
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
