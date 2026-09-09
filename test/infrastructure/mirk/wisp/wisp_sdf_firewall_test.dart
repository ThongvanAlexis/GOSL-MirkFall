// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-05 — structural firewall between the wisp system and the SDF pipeline
// (POC Pitfall 4) and between the wisp system and the map engine (WISP-01 world basis).
//
// No file under `lib/infrastructure/mirk/wisp/` may import:
//   * `sdf/sdf_cache.dart`, `sdf/revealed_sdf_builder.dart`, `sdf_rebuild_logger.dart` — the
//     wisps and the SDF are independent consumers of the same disc list; a wisp system that
//     reads the SDF would couple the puff timing to the (debounced, cached) fog build;
//   * `package:latlong2` / `package:flutter_map` — wisps live in the domain `GeoPoint` record
//     and are projected by the renderer through `MirkPaintContext.projectToScreen`.
//
// Same idiom as `tool/check_domain_purity.dart` (import-line regex over a directory), run under
// `flutter test` so it is part of the ordinary suite.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _wispDirRelative = 'lib/infrastructure/mirk/wisp';

/// Forbidden import targets — matched against the URI of every `import` / `export` directive.
final List<RegExp> _forbiddenImportPatterns = <RegExp>[
  RegExp(r'sdf/sdf_cache\.dart'),
  RegExp(r'sdf/revealed_sdf_builder\.dart'),
  RegExp(r'sdf_rebuild_logger\.dart'),
  RegExp(r'^package:latlong2/'),
  RegExp(r'^package:flutter_map/'),
];

final RegExp _directiveUri = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

void main() {
  group('09.1-05 — wisp/ ↔ SDF firewall (structural)', () {
    late List<File> wispFiles;

    setUpAll(() {
      final Directory dir = Directory(p.join(Directory.current.path, _wispDirRelative));
      expect(dir.existsSync(), isTrue, reason: 'run from the package root: $_wispDirRelative must exist');
      wispFiles = dir.listSync(recursive: true).whereType<File>().where((File f) => f.path.endsWith('.dart')).toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
    });

    test('the scan covers the three wisp sources (guards against a silently empty directory)', () {
      final Set<String> basenames = wispFiles.map((File f) => p.basename(f.path)).toSet();
      expect(basenames, containsAll(<String>['wisp_particle.dart', 'wisp_particle_system.dart', 'wisp_transform_logger.dart']));
    });

    test('no wisp/ file imports the SDF cache, the SDF builder or the SDF rebuild logger (Pitfall 4)', () {
      final List<String> violations = _violations(wispFiles, _forbiddenImportPatterns.sublist(0, 3));
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('no wisp/ file imports latlong2 or flutter_map (WISP-01 — GeoPoint + projectToScreen only)', () {
      final List<String> violations = _violations(wispFiles, _forbiddenImportPatterns.sublist(3));
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}

/// `<relative path>: <uri>` for every directive whose URI matches one of [patterns].
List<String> _violations(List<File> files, List<RegExp> patterns) {
  final List<String> violations = <String>[];
  for (final File file in files) {
    final String source = file.readAsStringSync();
    for (final RegExpMatch match in _directiveUri.allMatches(source)) {
      final String uri = match.group(1)!;
      if (patterns.any((RegExp pattern) => pattern.hasMatch(uri))) {
        violations.add('${p.relative(file.path, from: Directory.current.path)}: $uri');
      }
    }
  }
  return violations;
}
