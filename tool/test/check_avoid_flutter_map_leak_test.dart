// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../check_avoid_flutter_map_leak.dart' as check_avoid_flutter_map_leak;

/// Fixture-based tests for `tool/check_avoid_flutter_map_leak.dart`.
///
/// Enforces the MAP-06 seam for the Phase 09.1 flutter_map engine: any
/// import of `flutter_map`, `latlong2`, `vector_map_tiles`,
/// `vector_map_tiles_pmtiles`, `vector_tile_renderer`, `pmtiles` — or the
/// retired `maplibre_gl` — must live inside the explicit perimeter:
/// everything under `lib/infrastructure/map/` plus the three allow-listed
/// presentation files that form the FogLayer boundary (09.1-CONTEXT
/// §Périmètre d'import). Everything else depends only on the `MapView`
/// domain port and `MirkPaintContext`.
///
/// Same shape as `tool/test/check_domain_purity_test.dart` (Phase 02
/// convention — paired tool tests live alongside the tool, picked up by
/// the existing `Tool scripts unit tests` CI step running
/// `dart test tool/test/`).
///
/// Covers the Phase 01 CLI contract:
///   - exit 0 : no engine imports anywhere OR imports only inside the
///              allowed prefix / allow-listed exact files.
///   - exit 1 : violation — one or more imports outside the perimeter.
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

const String _flutterMapImport = "import 'package:flutter_map/flutter_map.dart';";
const String _latlong2Import = "import 'package:latlong2/latlong.dart';";
const String _vectorMapTilesDoubleQuotedImport = 'import "package:vector_map_tiles/vector_map_tiles.dart";';
const String _vectorMapTilesPmtilesImport = "import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';";
const String _vectorTileRendererImport = "import 'package:vector_tile_renderer/vector_tile_renderer.dart';";
const String _pmtilesImport = "import 'package:pmtiles/pmtiles.dart';";
const String _maplibreImport = "import 'package:maplibre_gl/maplibre_gl.dart';";

void main() {
  group('check_avoid_flutter_map_leak.runCheck', () {
    late Directory tempDir;
    late String libRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('check_avoid_flutter_map_leak_test_');
      libRoot = p.join(tempDir.path, 'lib');
      await Directory(libRoot).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Writes a GOSL-headed Dart file at `lib/<relativePath>` with [importLine] as its only import.
    Future<void> writeLibFile(String relativePath, {String? importLine}) async {
      final File file = File(p.join(libRoot, relativePath));
      await file.parent.create(recursive: true);
      final String body = importLine == null ? '$_gosl\nclass X {}\n' : '$_gosl\n$importLine\n\nclass X {}\n';
      await file.writeAsString(body);
    }

    test('returns 0 on a clean tree with no map-engine imports anywhere', () async {
      await File(p.join(libRoot, 'app.dart')).writeAsString('$_gosl\nimport \'dart:async\';\nvoid main() {}\n');
      await writeLibFile(p.join('domain', 'session.dart'));

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 0);
    });

    test('returns 0 when flutter_map is imported inside lib/infrastructure/map/ (allowed prefix)', () async {
      await writeLibFile(p.join('infrastructure', 'map', 'x.dart'), importLine: _flutterMapImport);

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 0);
    });

    test('returns 0 for the 3 allow-listed presentation files (FogLayer boundary)', () async {
      await writeLibFile(p.join('presentation', 'widgets', 'fog_layer.dart'), importLine: _flutterMapImport);
      await writeLibFile(p.join('presentation', 'widgets', 'fog_clip_path.dart'), importLine: _flutterMapImport);
      await writeLibFile(p.join('presentation', 'screens', 'map_screen.dart'), importLine: _flutterMapImport);

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 0);
    });

    test('returns 1 when latlong2 is imported from lib/infrastructure/mirk/wisp/ (C2 option A: wisps use the domain record)', () async {
      await writeLibFile(p.join('infrastructure', 'mirk', 'wisp', 'wisp_particle.dart'), importLine: _latlong2Import);

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);
    });

    test('returns 1 when vector_map_tiles is imported (double quotes) from lib/application/', () async {
      await writeLibFile(p.join('application', 'x.dart'), importLine: _vectorMapTilesDoubleQuotedImport);

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);
    });

    test('returns 1 when pmtiles is imported from lib/domain/', () async {
      await writeLibFile(p.join('domain', 'x.dart'), importLine: _pmtilesImport);

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);
    });

    test('returns 1 when vector_map_tiles_pmtiles or vector_tile_renderer is imported outside the perimeter', () async {
      await writeLibFile(p.join('application', 'a.dart'), importLine: _vectorMapTilesPmtilesImport);
      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);

      await File(p.join(libRoot, 'application', 'a.dart')).delete();
      await writeLibFile(p.join('application', 'b.dart'), importLine: _vectorTileRendererImport);
      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);
    });

    test('maplibre_gl: tolerated under lib/infrastructure/map/ (09.1-01 → 09.1-02 transition), forbidden elsewhere', () async {
      await writeLibFile(p.join('infrastructure', 'map', 'legacy.dart'), importLine: _maplibreImport);
      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 0);

      await writeLibFile(p.join('presentation', 'x.dart'), importLine: _maplibreImport);
      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);
    });

    test('exempts generated files (.g.dart / .freezed.dart) from the scan', () async {
      await Directory(p.join(libRoot, 'presentation', 'widgets')).create(recursive: true);
      // No header needed — generated files are skipped by suffix.
      await File(p.join(libRoot, 'presentation', 'widgets', 'fog_layer.g.dart')).writeAsString('$_flutterMapImport\n');
      await File(p.join(libRoot, 'presentation', 'widgets', 'fog_layer.freezed.dart')).writeAsString('$_latlong2Import\n');

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 0);
    });

    test('returns 1 when fog_layer_connector.dart imports flutter_map (the Riverpod connector is NOT in the perimeter)', () async {
      await writeLibFile(p.join('presentation', 'widgets', 'fog_layer_connector.dart'), importLine: _flutterMapImport);

      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);
    });

    test('returns 2 when lib/ root does not exist (misconfiguration)', () async {
      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: p.join(tempDir.path, 'nonexistent')), 2);
    });

    test('mutation guard: clean tree → violated tree flips exit code from 0 to 1 (Phase 04/06 inertness-guard idiom)', () async {
      await writeLibFile('app.dart');
      // First: prove a clean tree returns 0.
      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 0);

      // Then: inject a violation and prove the exit code flips. If the
      // scanner ever gets silently neutered (regex typo, early-return, etc.)
      // the second expect fails loudly, defeating the no-op trap.
      await writeLibFile(p.join('domain', 'poisoned.dart'), importLine: _flutterMapImport);
      expect(await check_avoid_flutter_map_leak.runCheck(rootPath: libRoot), 1);
    });
  });
}
