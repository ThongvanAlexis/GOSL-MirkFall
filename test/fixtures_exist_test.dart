// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Phase 07 plan 07-01 Task 1 scaffold: the `assets/maps/`
/// directory ships with every Day-1 file downstream plans (07-03 map
/// infrastructure, 07-06 presentation) rely on. Running under
/// `flutter test` lets us shell-probe the working directory the same
/// way the CI gate would — no need to pull path_provider for a
/// repo-root existence check.
///
/// Layer-order assertion against the full `style.json` payload lives
/// in Plan 07-06 (presentation test). This file only verifies the
/// files are non-empty + parseable — the contract for downstream
/// consumers to trust their paths.
void main() {
  group('Phase 07 assets/maps/ scaffold', () {
    test('assets/maps/world.pmtiles exists and is non-empty', () {
      final File f = File('assets/maps/world.pmtiles');
      expect(f.existsSync(), isTrue, reason: 'world PMTiles bundle must be committed for first-launch copy (MAP-07).');
      expect(f.lengthSync(), greaterThan(0));
    });

    test('assets/maps/catalog.json exists and is non-empty', () {
      final File f = File('assets/maps/catalog.json');
      expect(f.existsSync(), isTrue, reason: 'Country catalog must be bundled (MAP-08).');
      expect(f.lengthSync(), greaterThan(0));
    });

    test('assets/maps/style.json exists and declares the mirk_fog layer', () {
      final File f = File('assets/maps/style.json');
      expect(f.existsSync(), isTrue, reason: 'Protomaps-derived style must be bundled (Phase 07 plan 07-06 consumer).');
      final String contents = f.readAsStringSync();
      expect(contents, contains('"id": "mirk_fog"'), reason: 'Frozen 8-layer order includes mirk_fog (Phase 09 replaces the paint with a real fill layer).');
    });

    test('assets/maps/polygons/ carries at least one <alpha3>.geo.json with a FeatureCollection', () {
      final Directory dir = Directory('assets/maps/polygons');
      expect(dir.existsSync(), isTrue);
      final List<File> geoFiles = dir.listSync().whereType<File>().where((File f) => f.path.endsWith('.geo.json')).toList();
      expect(geoFiles, isNotEmpty, reason: 'Country resolver (Phase 07 plan 07-03) relies on at least one polygon entry.');
      // Spot-check one file is a valid GeoJSON FeatureCollection so a
      // future refactor that accidentally writes empty files fails loudly.
      final String contents = geoFiles.first.readAsStringSync();
      expect(contents, contains('FeatureCollection'));
      expect(contents, contains('"type": "Polygon"'));
    });

    test('assets/maps/glyphs/ + sprites/ exist (placeholder READMEs ship in 07-01)', () {
      expect(Directory('assets/maps/glyphs').existsSync(), isTrue);
      expect(Directory('assets/maps/sprites').existsSync(), isTrue);
      // Phase 07-01 ships a placeholder README; Phase 07-06 will swap in
      // real glyph PBF + sprite PNG files via tool/prepare_style.dart.
      expect(File('assets/maps/glyphs/README.md').existsSync(), isTrue);
      expect(File('assets/maps/sprites/README.md').existsSync(), isTrue);
    });
  });
}
