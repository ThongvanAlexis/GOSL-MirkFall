// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../check_avoid_maplibre_leak.dart' as check_avoid_maplibre_leak;

/// Fixture-based tests for `tool/check_avoid_maplibre_leak.dart`.
///
/// Enforces the MAP-06 seam : any `import 'package:maplibre_gl/…'` must
/// live under `lib/infrastructure/map/` — application, domain, presentation,
/// and controllers are forbidden from importing the SDK directly so the
/// `MapView` domain interface stays vocabulary-pure.
///
/// Same shape as `tool/test/check_domain_purity_test.dart` (Phase 02
/// convention — paired tool tests live alongside the tool, picked up by
/// the existing `Tool scripts unit tests` CI step running
/// `dart test tool/test/`).
///
/// Covers the Phase 01 CLI contract:
///   - exit 0 : no imports (Phase 07-01 default — infra dir empty) OR
///              imports only inside the allowed prefix.
///   - exit 1 : violation — one or more imports outside the allowed prefix.
///   - exit 2 : misconfiguration — scan root does not exist.
///
/// The mutation-guard test (finding pattern from Phase 04 / 06 review
/// gates) adds a clean → violated → exit-flip flow so a future refactor
/// that silently neuters the scanner fails loudly rather than
/// degrading into a no-op.
const String _gosl = '''// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details
''';

void main() {
  group('check_avoid_maplibre_leak.runCheck', () {
    late Directory tempDir;
    late String libRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('check_avoid_maplibre_leak_test_');
      libRoot = p.join(tempDir.path, 'lib');
      await Directory(libRoot).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns 0 on a clean tree with no maplibre_gl imports anywhere', () async {
      // Phase 07-01 baseline: lib/infrastructure/map/ does not exist yet —
      // the scanner must treat "no imports anywhere" as clean.
      await File(p.join(libRoot, 'app.dart')).writeAsString('$_gosl\nimport \'dart:async\';\nvoid main() {}\n');
      await Directory(p.join(libRoot, 'domain')).create(recursive: true);
      await File(p.join(libRoot, 'domain', 'session.dart')).writeAsString('$_gosl\nclass Session {}\n');

      final int code = await check_avoid_maplibre_leak.runCheck(rootPath: libRoot);
      expect(code, 0);
    });

    test('returns 0 when maplibre_gl is imported inside lib/infrastructure/map/ (allowed)', () async {
      await Directory(p.join(libRoot, 'infrastructure', 'map')).create(recursive: true);
      await File(
        p.join(libRoot, 'infrastructure', 'map', 'adapter.dart'),
      ).writeAsString('$_gosl\nimport \'package:maplibre_gl/maplibre_gl.dart\';\n\nclass A {}\n');

      final int code = await check_avoid_maplibre_leak.runCheck(rootPath: libRoot);
      expect(code, 0);
    });

    test('returns 1 when maplibre_gl is imported from lib/domain/', () async {
      await Directory(p.join(libRoot, 'domain')).create(recursive: true);
      await File(p.join(libRoot, 'domain', 'bad.dart')).writeAsString('$_gosl\nimport \'package:maplibre_gl/maplibre_gl.dart\';\n\nclass Bad {}\n');

      final int code = await check_avoid_maplibre_leak.runCheck(rootPath: libRoot);
      expect(code, 1);
    });

    test('returns 1 when maplibre_gl is imported from lib/application/', () async {
      await Directory(p.join(libRoot, 'application')).create(recursive: true);
      await File(p.join(libRoot, 'application', 'controller.dart')).writeAsString('$_gosl\nimport "package:maplibre_gl/controller.dart";\n\nclass C {}\n');

      final int code = await check_avoid_maplibre_leak.runCheck(rootPath: libRoot);
      expect(code, 1);
    });

    test('returns 1 when maplibre_gl is imported from lib/presentation/', () async {
      await Directory(p.join(libRoot, 'presentation')).create(recursive: true);
      await File(p.join(libRoot, 'presentation', 'map_screen.dart')).writeAsString('$_gosl\nimport \'package:maplibre_gl/maplibre_gl.dart\';\n\nclass S {}\n');

      final int code = await check_avoid_maplibre_leak.runCheck(rootPath: libRoot);
      expect(code, 1);
    });

    test('returns 2 when lib/ root does not exist (misconfiguration)', () async {
      final int code = await check_avoid_maplibre_leak.runCheck(rootPath: p.join(tempDir.path, 'nonexistent'));
      expect(code, 2);
    });

    test('exempts generated files (.g.dart / .freezed.dart) from the scan', () async {
      await Directory(p.join(libRoot, 'domain')).create(recursive: true);
      // No header needed — generated files are skipped by suffix.
      await File(p.join(libRoot, 'domain', 'session.g.dart')).writeAsString("import 'package:maplibre_gl/maplibre_gl.dart';\n");
      await File(p.join(libRoot, 'domain', 'marker.freezed.dart')).writeAsString("import 'package:maplibre_gl/maplibre_gl.dart';\n");

      final int code = await check_avoid_maplibre_leak.runCheck(rootPath: libRoot);
      expect(code, 0);
    });

    test('mutation guard: clean tree → violated tree flips exit code from 0 to 1 '
        '(Phase 04/06 inertness-guard idiom)', () async {
      await File(p.join(libRoot, 'app.dart')).writeAsString('$_gosl\nclass App {}\n');
      // First: prove a clean tree returns 0.
      expect(await check_avoid_maplibre_leak.runCheck(rootPath: libRoot), 0);

      // Then: inject a violation and prove the exit code flips. If the
      // scanner ever gets silently neutered (regex typo, early-return, etc.)
      // the second expect fails loudly, defeating the no-op trap.
      await Directory(p.join(libRoot, 'domain')).create(recursive: true);
      await File(p.join(libRoot, 'domain', 'poisoned.dart')).writeAsString('$_gosl\nimport \'package:maplibre_gl/maplibre_gl.dart\';\n\nclass P {}\n');
      expect(await check_avoid_maplibre_leak.runCheck(rootPath: libRoot), 1);
    });
  });
}
