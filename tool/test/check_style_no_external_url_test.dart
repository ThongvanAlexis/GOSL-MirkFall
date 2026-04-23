// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../check_style_no_external_url.dart' as check_style_no_external_url;

/// Fixture-based paired tests for `tool/check_style_no_external_url.dart`.
///
/// The scanner's `runCheck({stylePath})` parameter is public so we can
/// invoke it against synthetic style.json fixtures in a tempdir without
/// touching the production asset.
///
/// 7 scenarios (Plan 08-04 Task 5):
///   1. Clean production asset — exit 0.
///   2. External http URL in `sources.<name>.tiles[]` — exit 1.
///   3. External https URL in glyphs — exit 1.
///   4. External https URL in sprite — exit 1.
///   5. Malformed JSON — exit 2.
///   6. Missing file — exit 2.
///   7. pmtiles:///, asset://, relative-path, + `{fontstack}` templates
///      all pass (whitelist coverage) — exit 0.

const String _cleanStyle = '''
{
  "version": 8,
  "glyphs": "asset:///assets/maps/glyphs/{fontstack}/{range}.pbf",
  "sprite": "asset:///assets/maps/sprites/sprite",
  "sources": {
    "mirkfall_map": {
      "type": "vector",
      "url": "pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER"
    }
  },
  "layers": []
}
''';

void main() {
  group('check_style_no_external_url.runCheck', () {
    late Directory tempDir;
    late String fixturePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('check_style_no_external_url_test_');
      fixturePath = p.join(tempDir.path, 'style.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('scenario 1: clean production style.json (at its real path) → exit 0', () async {
      // Production style IS the asset file — invoke with the default
      // path. If this ever flips to exit 1, the production asset has
      // drifted toward an external URL and the Phase 08 gate contract
      // is violated.
      final int code = await check_style_no_external_url.runCheck();
      expect(code, equals(0));
    });

    test('scenario 2: external http URL in sources.<name>.tiles[] → exit 1', () async {
      await File(fixturePath).writeAsString('''
{
  "version": 8,
  "glyphs": "asset:///assets/maps/glyphs/{fontstack}/{range}.pbf",
  "sprite": "asset:///assets/maps/sprites/sprite",
  "sources": {
    "mirkfall_map": {
      "type": "vector",
      "tiles": ["http://tile.openstreetmap.org/{z}/{x}/{y}.pbf"]
    }
  },
  "layers": []
}
''');

      final int code = await check_style_no_external_url.runCheck(stylePath: fixturePath);
      expect(code, equals(1), reason: 'external HTTP in tiles[] must fail');
    });

    test('scenario 3: external https URL in glyphs → exit 1', () async {
      await File(fixturePath).writeAsString('''
{
  "version": 8,
  "glyphs": "https://fonts.openmaptiles.org/{fontstack}/{range}.pbf",
  "sprite": "asset:///assets/maps/sprites/sprite",
  "sources": {
    "mirkfall_map": {
      "type": "vector",
      "url": "pmtiles://file:///local.pmtiles"
    }
  },
  "layers": []
}
''');

      final int code = await check_style_no_external_url.runCheck(stylePath: fixturePath);
      expect(code, equals(1), reason: 'external HTTPS in glyphs must fail');
    });

    test('scenario 4: external https URL in sprite → exit 1', () async {
      await File(fixturePath).writeAsString('''
{
  "version": 8,
  "glyphs": "asset:///assets/maps/glyphs/{fontstack}/{range}.pbf",
  "sprite": "https://maputnik.github.io/osm-liberty/sprites/osm-liberty",
  "sources": {
    "mirkfall_map": {
      "type": "vector",
      "url": "pmtiles://file:///local.pmtiles"
    }
  },
  "layers": []
}
''');

      final int code = await check_style_no_external_url.runCheck(stylePath: fixturePath);
      expect(code, equals(1), reason: 'external HTTPS in sprite must fail');
    });

    test('scenario 5: malformed JSON → exit 2', () async {
      await File(fixturePath).writeAsString('{"version": 8, "glyphs": "asset:///"\n');

      final int code = await check_style_no_external_url.runCheck(stylePath: fixturePath);
      expect(code, equals(2), reason: 'invalid JSON must signal misconfiguration (exit 2)');
    });

    test('scenario 6: missing file → exit 2', () async {
      final String nonExistent = p.join(tempDir.path, 'does-not-exist.json');
      final int code = await check_style_no_external_url.runCheck(stylePath: nonExistent);
      expect(code, equals(2), reason: 'missing file must signal misconfiguration (exit 2)');
    });

    test('scenario 7: whitelist coverage — pmtiles://file:/// + asset:/// + relative + template placeholders all pass → exit 0', () async {
      // Exercises every allowed URL shape in one fixture.
      await File(fixturePath).writeAsString('''
{
  "version": 8,
  "glyphs": "asset:///assets/maps/glyphs/{fontstack}/{range}.pbf",
  "sprite": "assets/maps/sprites/sprite",
  "sources": {
    "mirkfall_map": {
      "type": "vector",
      "url": "pmtiles://file:///path/to/world.pmtiles"
    },
    "local_file": {
      "type": "vector",
      "url": "file:///usr/local/share/map.pmtiles"
    },
    "asset_bundle": {
      "type": "vector",
      "url": "asset:///assets/maps/sample.pmtiles"
    }
  },
  "layers": []
}
''');

      final int code = await check_style_no_external_url.runCheck(stylePath: fixturePath);
      expect(code, equals(0), reason: 'all whitelist patterns must pass');
    });

    test('mutation guard: clean fixture → poisoned fixture flips exit code from 0 to 1 (Phase 04/06 inertness-guard idiom)', () async {
      await File(fixturePath).writeAsString(_cleanStyle);
      expect(await check_style_no_external_url.runCheck(stylePath: fixturePath), equals(0));

      // Inject a single https tile URL — smallest valid poison.
      await File(fixturePath).writeAsString(
        _cleanStyle.replaceFirst(
          '"url": "pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER"',
          '"url": "pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER", "tiles": ["https://tile.example.com/{z}/{x}/{y}.pbf"]',
        ),
      );

      expect(await check_style_no_external_url.runCheck(stylePath: fixturePath), equals(1));
    });
  });
}
