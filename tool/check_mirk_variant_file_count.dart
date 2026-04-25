// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// CI gate: structurally enforces MIRK-05/06 "1 file per variant".
///
/// Counts `lib/infrastructure/mirk/*_mirk_renderer.dart` files and
/// asserts: (a) exactly 6 present (4 builtins + noop + shader), and
/// (b) each of the 4 builtin renderer filenames is present by string
/// match, plus `noop_mirk_renderer.dart` and `shader_mirk_renderer.dart`.
///
/// "1 file per variant" is a seam invariant: if this gate drifts, either
/// two variants accidentally share a file (smell — bad) or a variant is
/// missing (likely). See 09-RESEARCH §Registration Pattern Choice.
///
/// CLI contract (Phase 01 convention):
///   - exit 0 : clean — exactly the expected 6 filenames present.
///   - exit 1 : policy violation (missing or extra renderer file).
///   - exit 2 : misconfiguration (scan root does not exist).
///
/// `--root=<path>` opt overrides the default `lib/infrastructure/mirk/`
/// scan root; used by paired tool tests to drive the scanner against
/// synthetic fixture trees built with `Directory.systemTemp.createTemp`.

/// The exhaustive list of `*_mirk_renderer.dart` filenames Phase 09 ships.
/// Extended here means the seam grew — review the change before flipping
/// the gate green.
const Set<String> kExpectedRendererBasenames = <String>{
  'atmospheric_mirk_renderer.dart',
  'solid_fill_mirk_renderer.dart',
  'candlelight_mirk_renderer.dart',
  'heavenly_clouds_mirk_renderer.dart',
  'noop_mirk_renderer.dart',
  'shader_mirk_renderer.dart',
};

/// Default scan root, relative to the current working directory at run time.
const String _defaultRoot = 'lib/infrastructure/mirk';

/// Parses the optional `--root=<path>` argv override. Returns the resolved
/// root path. Unrecognised flags are silently ignored (forward-compat).
String _parseRoot(List<String> args) {
  for (final String a in args) {
    if (a.startsWith('--root=')) {
      return a.substring('--root='.length);
    }
  }
  return _defaultRoot;
}

/// Runs the scan against [rootPath] (default `lib/infrastructure/mirk`).
///
/// Public so unit tests can drive the scanner against synthetic fixture
/// trees. Same shape as `tool/check_avoid_maplibre_leak.dart`'s `runCheck`.
int runCheck({String? rootPath}) {
  final String resolvedRoot = rootPath ?? p.join(Directory.current.path, _defaultRoot);
  final Directory dir = Directory(resolvedRoot);
  if (!dir.existsSync()) {
    stderr.writeln('check_mirk_variant_file_count: scan root not found at ${dir.path}');
    return 2;
  }

  // Collect *_mirk_renderer.dart filenames at the top level of the scan
  // root. Sub-directories under lib/infrastructure/mirk/ (e.g. noise/) are
  // intentionally excluded — the "1 file per variant" rule covers
  // renderer impls only, not their helpers.
  final Set<String> foundBasenames = <String>{};
  for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final String basename = p.basename(entity.path);
    if (!basename.endsWith('_mirk_renderer.dart')) continue;
    foundBasenames.add(basename);
  }

  final Set<String> missing = kExpectedRendererBasenames.difference(foundBasenames);
  final Set<String> extra = foundBasenames.difference(kExpectedRendererBasenames);

  if (missing.isEmpty && extra.isEmpty) {
    stdout.writeln('check_mirk_variant_file_count: OK (${foundBasenames.length} renderer files, exact match)');
    return 0;
  }

  stderr.writeln('check_mirk_variant_file_count: structural drift detected under ${dir.path}');
  if (missing.isNotEmpty) {
    stderr.writeln('  Missing renderer files (${missing.length}):');
    for (final String f in missing) {
      stderr.writeln('    - $f');
    }
  }
  if (extra.isNotEmpty) {
    stderr.writeln('  Unexpected renderer files (${extra.length}):');
    for (final String f in extra) {
      stderr.writeln('    + $f');
    }
  }
  stderr.writeln();
  stderr.writeln('Rule (MIRK-05/06): exactly one *_mirk_renderer.dart file per variant.');
  stderr.writeln('Update kExpectedRendererBasenames here if the variant set legitimately changed.');
  return 1;
}

void main(List<String> args) {
  final String root = _parseRoot(args);
  final int code = runCheck(rootPath: root);
  exitCode = code;
}
