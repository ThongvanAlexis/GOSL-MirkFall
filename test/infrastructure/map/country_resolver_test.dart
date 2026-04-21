// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/map/country_resolver.dart';
import 'package:test/test.dart';

void main() {
  // Load the 5 test fixtures from Plan 07-01's test/fixtures/polygons/
  // tree — coarse bboxes for FRA/DEU/ESP/GBR/USA. The fixtures ship as
  // closed axis-aligned squares that are trivially simple polygons, so
  // the ray-cast resolver sees a clean geometry.
  Future<Map<CountryCode, List<CountryPolygonRing>>> loadFixtures() async {
    final Map<CountryCode, List<CountryPolygonRing>> out = <CountryCode, List<CountryPolygonRing>>{};
    for (final String code in <String>['fra', 'deu', 'esp', 'gbr', 'usa']) {
      final String raw = File('test/fixtures/polygons/$code.geo.json').readAsStringSync();
      final CountryPolygonLoader loader = CountryPolygonLoaderTestSeam.withAssetLoader((_) async => raw);
      final Map<CountryCode, List<CountryPolygonRing>> loaded = await loader.loadPolygonsForInstalled(<CountryCode>[CountryCode.parse(code)]);
      out.addAll(loaded);
    }
    return out;
  }

  late Map<CountryCode, List<CountryPolygonRing>> fixtures;

  setUp(() async {
    fixtures = await loadFixtures();
  });

  group('CountryResolver.resolve — 15+ lat/lon cases', () {
    test('Paris (48.8566, 2.3522) at zoom 13 → FRA', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 48.8566, longitude: 2.3522, zoom: 13)?.value, 'fra');
    });

    test('Lyon (45.7640, 4.8357) at zoom 13 → FRA', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 45.7640, longitude: 4.8357, zoom: 13)?.value, 'fra');
    });

    test('Berlin (52.5200, 13.4050) at zoom 13 → DEU', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 52.5200, longitude: 13.4050, zoom: 13)?.value, 'deu');
    });

    test('Munich (48.1351, 11.5820) at zoom 13 → DEU', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 48.1351, longitude: 11.5820, zoom: 13)?.value, 'deu');
    });

    test('Madrid (40.4168, -3.7038) at zoom 13 → ESP', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 40.4168, longitude: -3.7038, zoom: 13)?.value, 'esp');
    });

    test('Barcelona (41.3851, 2.1734) at zoom 13 → deterministic first match', () {
      // Barcelona may fall inside both FRA and ESP bounding boxes
      // depending on fixture coordinates. The resolver iterates in
      // insertion order (LinkedHashMap) and returns the first match —
      // load order was fra/deu/esp/gbr/usa. Whatever the answer is,
      // it MUST be one of fra/esp and MUST be consistent across calls.
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      final CountryCode? first = r.resolve(latitude: 41.3851, longitude: 2.1734, zoom: 13);
      expect(first?.value, anyOf(equals('fra'), equals('esp')));
      // Re-run — determinism.
      final CountryCode? second = r.resolve(latitude: 41.3851, longitude: 2.1734, zoom: 13);
      expect(second?.value, first?.value);
    });

    test('London (51.5074, -0.1278) at zoom 13 → GBR', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 51.5074, longitude: -0.1278, zoom: 13)?.value, 'gbr');
    });

    test('Edinburgh (55.9533, -3.1883) at zoom 13 → GBR', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 55.9533, longitude: -3.1883, zoom: 13)?.value, 'gbr');
    });

    test('New York City (40.7128, -74.0060) at zoom 13 → USA', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 40.7128, longitude: -74.0060, zoom: 13)?.value, 'usa');
    });

    test('Los Angeles (34.0522, -118.2437) at zoom 13 → USA', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 34.0522, longitude: -118.2437, zoom: 13)?.value, 'usa');
    });

    test('Mid-Atlantic (30.0, -40.0) → null (world fallback)', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 30.0, longitude: -40.0, zoom: 13), isNull);
    });

    test('Sydney (-33.8688, 151.2093) → null (AUS not installed)', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: -33.8688, longitude: 151.2093, zoom: 13), isNull);
    });

    test('Paris at zoom 2 → null (below world-fallback cutoff)', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 48.8566, longitude: 2.3522, zoom: 2), isNull);
    });

    test('Paris at zoom 7 → null (cutoff bumped to 8 in device-smoke fix 2026-04-21)', () {
      // Previously zoom 3 switched to the country PMTiles; at zoom 3-7
      // the per-country file has no data for neighbouring countries
      // which rendered as blank white areas. The cutoff now holds the
      // world bundle in place until zoom 8.
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 48.8566, longitude: 2.3522, zoom: 7), isNull);
    });

    test('Paris at zoom 8 exactly → FRA (cutoff is strict <8)', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 48.8566, longitude: 2.3522, zoom: 8)?.value, 'fra');
    });

    test('Empty installed map → null regardless of zoom', () {
      final CountryResolver r = CountryResolver(installedPolygons: <CountryCode, List<CountryPolygonRing>>{});
      expect(r.resolve(latitude: 48.8566, longitude: 2.3522, zoom: 13), isNull);
      expect(r.resolve(latitude: 0.0, longitude: 0.0, zoom: 20), isNull);
    });

    test('Equator crossing (0.0, 0.0) at zoom 13 → null (no fixture covers)', () {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      expect(r.resolve(latitude: 0.0, longitude: 0.0, zoom: 13), isNull);
    });
  });

  group('CountryResolver — stream debounce', () {
    test('resolveForViewportUpdates emits one value after debounce window', () async {
      final CountryResolver r = CountryResolver(installedPolygons: fixtures);
      final StreamController<({double latitude, double longitude, double zoom})> input = StreamController<({double latitude, double longitude, double zoom})>();
      final List<CountryCode?> emitted = <CountryCode?>[];
      final StreamSubscription<CountryCode?> sub = r.resolveForViewportUpdates(input.stream, debounce: const Duration(milliseconds: 10)).listen(emitted.add);

      // Burst of 3 events in quick succession — debounce collapses to 1.
      input.add((latitude: 48.8566, longitude: 2.3522, zoom: 13.0));
      input.add((latitude: 48.8566, longitude: 2.3523, zoom: 13.0));
      input.add((latitude: 48.8566, longitude: 2.3524, zoom: 13.0));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(emitted.length, 1);
      expect(emitted.first?.value, 'fra');

      await sub.cancel();
      await input.close();
    });
  });

  group('CountryPolygonLoader — GeoJSON parsing', () {
    test('parses Polygon feature into a single ring', () async {
      const String polygonJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"alpha3": "xxx"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      }
    }
  ]
}
''';
      final CountryPolygonLoader loader = CountryPolygonLoaderTestSeam.withAssetLoader((_) async => polygonJson);
      final Map<CountryCode, List<CountryPolygonRing>> out = await loader.loadPolygonsForInstalled(<CountryCode>[CountryCode.parse('xxx')]);
      expect(out.values.first.length, 1);
      expect(out.values.first.first.length, 5);
    });

    test('parses MultiPolygon feature into multiple rings', () async {
      const String multiPolygonJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"alpha3": "xxx"},
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [[[0, 0], [1, 0], [1, 1], [0, 0]]],
          [[[5, 5], [6, 5], [6, 6], [5, 5]]]
        ]
      }
    }
  ]
}
''';
      final CountryPolygonLoader loader = CountryPolygonLoaderTestSeam.withAssetLoader((_) async => multiPolygonJson);
      final Map<CountryCode, List<CountryPolygonRing>> out = await loader.loadPolygonsForInstalled(<CountryCode>[CountryCode.parse('xxx')]);
      expect(out.values.first.length, 2);
    });

    test('skips unknown/missing files silently', () async {
      final CountryPolygonLoader loader = CountryPolygonLoaderTestSeam.withAssetLoader((_) async => throw Exception('asset not found'));
      final Map<CountryCode, List<CountryPolygonRing>> out = await loader.loadPolygonsForInstalled(<CountryCode>[CountryCode.parse('xxx')]);
      expect(out, isEmpty);
    });
  });
}
