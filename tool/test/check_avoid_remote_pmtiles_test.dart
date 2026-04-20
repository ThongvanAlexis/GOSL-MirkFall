// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../check_avoid_remote_pmtiles.dart' as check_avoid_remote_pmtiles;

/// Fixture-based tests for `tool/check_avoid_remote_pmtiles.dart`.
///
/// Enforces the MAP-05 seam : no source file may embed a
/// `pmtiles://http…` or `pmtiles://https…` URI. The only accepted tile
/// scheme is `pmtiles://file:///…` (local-only). Scans `lib/`, `test/`,
/// and `assets/` roots; the placeholder URI in `assets/maps/style.json`
/// (`pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER`) does NOT match
/// the http(s) pattern, so it stays clean.
///
/// Phase 01 CLI contract:
///   - exit 0 : clean tree — no `pmtiles://http[s]` anywhere.
///   - exit 1 : violation — one or more offending strings found.
///   - exit 2 : misconfiguration — no scan roots exist.
const String _gosl = '''// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details
''';

void main() {
  group('check_avoid_remote_pmtiles.runCheck', () {
    late Directory tempDir;
    late String libDir;
    late String testDir;
    late String assetsDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('check_avoid_remote_pmtiles_test_');
      libDir = p.join(tempDir.path, 'lib');
      testDir = p.join(tempDir.path, 'test');
      assetsDir = p.join(tempDir.path, 'assets');
      await Directory(libDir).create(recursive: true);
      await Directory(testDir).create(recursive: true);
      await Directory(assetsDir).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns 0 on a clean tree with local-only pmtiles URIs', () async {
      await File(p.join(libDir, 'app.dart')).writeAsString('$_gosl\nconst url = "pmtiles://file:///path/to/world.pmtiles";\n');
      await File(p.join(assetsDir, 'style.json')).writeAsString('{"sources":{"main":{"url":"pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER"}}}\n');

      final int code = await check_avoid_remote_pmtiles.runCheck(roots: <String>[libDir, testDir, assetsDir]);
      expect(code, 0);
    });

    test('returns 1 when a .dart file embeds a pmtiles://https URI', () async {
      await File(p.join(libDir, 'leaky.dart')).writeAsString('$_gosl\nconst url = "pmtiles://https://tiles.example.com/world.pmtiles";\n');

      final int code = await check_avoid_remote_pmtiles.runCheck(roots: <String>[libDir, testDir, assetsDir]);
      expect(code, 1);
    });

    test('returns 1 when a .json asset embeds a pmtiles://http URI '
        '(the catalog.json `parts[].url` HTTPS URLs are NOT this pattern — '
        'they are plain `https://github.com/...` strings, not `pmtiles://http…`)', () async {
      await File(p.join(assetsDir, 'bad_style.json')).writeAsString('{"sources":{"main":{"url":"pmtiles://http://tiles.example.com/world.pmtiles"}}}\n');

      final int code = await check_avoid_remote_pmtiles.runCheck(roots: <String>[libDir, testDir, assetsDir]);
      expect(code, 1);
    });

    test('returns 1 when a test file embeds a pmtiles://HTTPS URI (case-insensitive)', () async {
      await File(p.join(testDir, 'bad_test.dart')).writeAsString('$_gosl\nconst bad = "pmtiles://HTTPS://tiles.example.com/us.pmtiles";\n');

      final int code = await check_avoid_remote_pmtiles.runCheck(roots: <String>[libDir, testDir, assetsDir]);
      expect(code, 1);
    });

    test('returns 0 when a file references regular https://github.com URLs '
        '(the catalog `parts[].url` pattern — NOT pmtiles://https) ', () async {
      // The Phase 07 catalog.json stores regular `https://github.com/ThongvanAlexis/...`
      // URLs pointing at raw .partNN chunks. These must NOT match the scanner,
      // otherwise the whole catalog would be false-positive red.
      await File(p.join(assetsDir, 'catalog.json')).writeAsString(
        '{"countries":[{"alpha3":"fra","parts":[{"url":"https://github.com/ThongvanAlexis/countries-pmtiles/releases/download/v20260419/fra.part01"}]}]}\n',
      );

      final int code = await check_avoid_remote_pmtiles.runCheck(roots: <String>[libDir, testDir, assetsDir]);
      expect(code, 0);
    });

    test('returns 2 when every scan root is missing (misconfiguration)', () async {
      final int code = await check_avoid_remote_pmtiles.runCheck(roots: <String>[p.join(tempDir.path, 'nope1'), p.join(tempDir.path, 'nope2')]);
      expect(code, 2);
    });

    test('mutation guard: clean tree → poisoned tree flips exit code from 0 to 1 '
        '(Phase 04/06 inertness-guard idiom)', () async {
      await File(p.join(assetsDir, 'style.json')).writeAsString('{"url":"pmtiles://file:///local.pmtiles"}\n');
      expect(await check_avoid_remote_pmtiles.runCheck(roots: <String>[libDir, testDir, assetsDir]), 0);

      await File(p.join(assetsDir, 'evil.json')).writeAsString('{"url":"pmtiles://https://tiles.example.com/evil.pmtiles"}\n');
      expect(await check_avoid_remote_pmtiles.runCheck(roots: <String>[libDir, testDir, assetsDir]), 1);
    });
  });
}
