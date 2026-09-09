// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// CI gate enforcing the MAP-06 seam for the Phase 09.1 flutter_map engine:
/// any `import 'package:<engine>/…'` (single or double quoted) where
/// `<engine>` is `flutter_map`, `latlong2`, `vector_map_tiles`,
/// `vector_map_tiles_pmtiles`, `vector_tile_renderer`, `pmtiles` — or the
/// retired `maplibre_gl` — must live inside the explicit perimeter:
///
///   - everything under `lib/infrastructure/map/` (the adapter), and
///   - the three allow-listed presentation files that form the FogLayer
///     boundary (`fog_layer.dart`, `fog_clip_path.dart`, `map_screen.dart`).
///
/// Why an explicit allow-list rather than a pure prefix rule: invariant
/// FOG-07 requires reading `MapCamera.of(context)` from inside the
/// `build()` of a direct child of `FlutterMap`, so `FogLayer` is
/// structurally a flutter_map consumer. 09.1-CONTEXT §Périmètre d'import
/// chose to assume that and list the file rather than abstract it
/// artificially. Everything else (application, domain, the Riverpod
/// connector, the wisp system, the renderers) depends only on the
/// `MapView` domain port (`lib/domain/map/map_view.dart`) and receives a
/// typed projection through `MirkPaintContext`
/// (`lib/domain/mirk/mirk_paint_context.dart`) — never a `MapCamera`.
///
/// `maplibre_gl` stays in the pattern after its removal in plan 09.1-02 so
/// that any accidental reintroduction of the old SDK fails the gate.
///
/// Scans recursively under `lib/`. Generated files (`*.g.dart`,
/// `*.freezed.dart`, etc.) are exempt — their imports come from codegen
/// templates and are not in scope for the rule applied to hand-written
/// code. The scanner is quote-agnostic (single OR double quotes) so a
/// stylistic choice does not bypass it.
///
/// CLI contract (Phase 01 convention, shared with `tool/check_*.dart`):
///   - exit 0 : clean — no engine imports anywhere, or only inside the
///     perimeter.
///   - exit 1 : at least one violation (file path + line number + line
///     contents emitted on stderr).
///   - exit 2 : misconfiguration — the scan root does not exist at all.
const List<String> _excludedSuffixes = <String>['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart'];

/// Packages of the map engine confined to the perimeter (MAP-06). Matches
/// `import 'package:<name>/…'` or `import "package:<name>"` at the start of
/// a line (optional leading whitespace). The trailing `(?:/|['"])` anchor
/// accepts either a path separator or the closing quote, so a bare
/// `import 'package:flutter_map';` also matches while a different package
/// sharing the prefix (`flutter_map_foo`) does not. Case-sensitive (pub.dev
/// package names are lowercase).
final RegExp _leakPattern = RegExp(
  r"""^\s*import\s+['"]package:(flutter_map|latlong2|vector_map_tiles|vector_map_tiles_pmtiles|vector_tile_renderer|pmtiles|maplibre_gl)(?:/|['"])""",
);

/// Forward-slash allowed prefix (all of `lib/infrastructure/map/**`),
/// compared against the normalised relative path of every scanned file
/// (backslashes → forward slashes on Windows). Comparing prefixes on the
/// normalised path avoids a brittle `Platform.isWindows` branch inside the
/// hot loop.
const String _allowedPrefix = 'infrastructure/map/';

/// Exact files allowed outside the prefix — decision 09.1-CONTEXT
/// §Périmètre d'import (FogLayer boundary, see the library docstring).
/// Paths are relative to the scan root and forward-slash normalised.
const Set<String> _allowedExactPaths = <String>{
  'presentation/widgets/fog_layer.dart',
  'presentation/widgets/fog_clip_path.dart',
  'presentation/screens/map_screen.dart',
};

/// Human-readable perimeter, reused by the OK line and the violation hint.
final String _perimeterDescription = 'lib/$_allowedPrefix + ${_allowedExactPaths.map((String path) => 'lib/$path').join(' / ')}';

/// Whether [relativePath] (forward-slash, relative to the scan root) is inside the MAP-06 perimeter.
bool _isInsidePerimeter(String relativePath) => relativePath.startsWith(_allowedPrefix) || _allowedExactPaths.contains(relativePath);

/// Runs the scan against [rootPath] (default `lib/`).
///
/// Public so unit tests can drive the scanner against synthetic fixture
/// trees built with `Directory.systemTemp.createTemp`. Same shape as
/// `tool/check_domain_purity.dart`'s `runCheck` for family consistency.
Future<int> runCheck({String? rootPath}) async {
  final String resolvedRoot = rootPath ?? p.join(Directory.current.path, 'lib');
  final Directory libDir = Directory(resolvedRoot);
  if (!libDir.existsSync()) {
    stderr.writeln('check_avoid_flutter_map_leak: lib/ not found at ${libDir.path}');
    return 2;
  }

  final List<String> violations = <String>[];
  var scanned = 0;

  await for (final FileSystemEntity entity in libDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final String normalized = entity.path.replaceAll('\\', '/');
    if (!normalized.endsWith('.dart')) continue;
    if (_excludedSuffixes.any(normalized.endsWith)) continue;

    // Normalised path RELATIVE to the scan root — so the perimeter check
    // works regardless of whether `rootPath` is absolute (real CI) or a
    // Windows `%TEMP%\…\lib` (unit-test fixtures).
    final String rel = p.relative(entity.path, from: resolvedRoot).replaceAll('\\', '/');

    scanned++;
    if (_isInsidePerimeter(rel)) continue;
    final List<String> lines = await entity.readAsLines();
    for (var i = 0; i < lines.length; i++) {
      if (!_leakPattern.hasMatch(lines[i])) continue;
      violations.add('${p.relative(entity.path)}:${i + 1}: ${lines[i].trim()}');
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_avoid_flutter_map_leak: OK ($scanned file(s), zero map-engine imports outside $_perimeterDescription)');
    return 0;
  }

  stderr.writeln('check_avoid_flutter_map_leak: ${violations.length} forbidden map-engine import(s) outside the MAP-06 perimeter:');
  for (final String violation in violations) {
    stderr.writeln('  $violation');
  }
  stderr.writeln();
  stderr.writeln('Rule (MAP-06): imports of flutter_map / latlong2 / vector_map_tiles / vector_map_tiles_pmtiles / vector_tile_renderer / pmtiles');
  stderr.writeln('(and the retired maplibre_gl) MUST live inside: $_perimeterDescription.');
  stderr.writeln('Depend on the MapView port (lib/domain/map/map_view.dart) instead; renderers receive a typed projection through');
  stderr.writeln('MirkPaintContext (lib/domain/mirk/mirk_paint_context.dart), never a MapCamera.');
  return 1;
}

Future<void> main(List<String> args) async {
  final int code = await runCheck();
  exitCode = code;
}
