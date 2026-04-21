// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/infrastructure/map/geo/point_in_polygon.dart';
import 'package:test/test.dart';

void main() {
  group('pointInPolygon — simple square', () {
    // Axis-aligned unit square in lon=[0..10], lat=[0..10].
    final List<({double lat, double lon})> square = const <({double lat, double lon})>[
      (lat: 0.0, lon: 0.0),
      (lat: 0.0, lon: 10.0),
      (lat: 10.0, lon: 10.0),
      (lat: 10.0, lon: 0.0),
    ];

    test('center is inside', () {
      expect(pointInPolygon(lat: 5.0, lon: 5.0, ring: square), isTrue);
    });

    test('far north is outside', () {
      expect(pointInPolygon(lat: 20.0, lon: 5.0, ring: square), isFalse);
    });

    test('far south is outside', () {
      expect(pointInPolygon(lat: -5.0, lon: 5.0, ring: square), isFalse);
    });

    test('far west is outside', () {
      expect(pointInPolygon(lat: 5.0, lon: -5.0, ring: square), isFalse);
    });

    test('far east is outside', () {
      expect(pointInPolygon(lat: 5.0, lon: 15.0, ring: square), isFalse);
    });
  });

  group('pointInPolygon — L-shape', () {
    // Non-convex L:
    //   (0,0) -> (10,0) -> (10,5) -> (5,5) -> (5,10) -> (0,10) -> close
    // Expressed as (lat, lon) tuples matching the algorithm.
    final List<({double lat, double lon})> lShape = const <({double lat, double lon})>[
      (lat: 0.0, lon: 0.0),
      (lat: 0.0, lon: 10.0),
      (lat: 5.0, lon: 10.0),
      (lat: 5.0, lon: 5.0),
      (lat: 10.0, lon: 5.0),
      (lat: 10.0, lon: 0.0),
    ];

    test('point inside the filled arm is inside', () {
      expect(pointInPolygon(lat: 2.5, lon: 2.5, ring: lShape), isTrue);
    });

    test('point inside the vertical arm is inside', () {
      expect(pointInPolygon(lat: 7.5, lon: 2.5, ring: lShape), isTrue);
    });

    test('point inside the horizontal arm is inside', () {
      expect(pointInPolygon(lat: 2.5, lon: 7.5, ring: lShape), isTrue);
    });

    test('notch interior is outside', () {
      // The L removes the top-right quadrant — a point at (7.5, 7.5)
      // sits in the hole cut out of the square bounding box.
      expect(pointInPolygon(lat: 7.5, lon: 7.5, ring: lShape), isFalse);
    });
  });

  group('pointInPolygon — real country bboxes', () {
    // France bbox taken from assets/maps/polygons/fra.geo.json (Plan 07-01).
    // The polygon is axis-aligned (bbox simplification).
    final List<({double lat, double lon})> franceBbox = const <({double lat, double lon})>[
      (lat: 41.364166, lon: -5.134723),
      (lat: 41.364166, lon: 9.562222),
      (lat: 51.089062, lon: 9.562222),
      (lat: 51.089062, lon: -5.134723),
    ];

    test('Paris (48.8566, 2.3522) is inside France bbox', () {
      expect(pointInPolygon(lat: 48.8566, lon: 2.3522, ring: franceBbox), isTrue);
    });

    test('Nice (43.7102, 7.2620) is inside France bbox', () {
      expect(pointInPolygon(lat: 43.7102, lon: 7.2620, ring: franceBbox), isTrue);
    });

    test('Berlin (52.5200, 13.4050) is NOT inside France bbox', () {
      expect(pointInPolygon(lat: 52.5200, lon: 13.4050, ring: franceBbox), isFalse);
    });

    test('Madrid (40.4168, -3.7038) is NOT inside France bbox', () {
      expect(pointInPolygon(lat: 40.4168, lon: -3.7038, ring: franceBbox), isFalse);
    });
  });

  group('pointInPolygon — degenerate rings', () {
    test('empty ring returns false', () {
      expect(pointInPolygon(lat: 0.0, lon: 0.0, ring: const <({double lat, double lon})>[]), isFalse);
    });

    test('single-point ring returns false', () {
      expect(pointInPolygon(lat: 0.0, lon: 0.0, ring: const <({double lat, double lon})>[(lat: 0.0, lon: 0.0)]), isFalse);
    });

    test('two-point ring returns false', () {
      expect(
        pointInPolygon(
          lat: 5.0,
          lon: 5.0,
          ring: const <({double lat, double lon})>[(lat: 0.0, lon: 0.0), (lat: 10.0, lon: 10.0)],
        ),
        isFalse,
      );
    });
  });

  group('pointInPolygon — antimeridian edges', () {
    // Polygon straddling 180°E uses signed longitudes — the ray-casting
    // algorithm does not un-wrap automatically. Consumers (CountryResolver)
    // must pre-split at the antimeridian; this test documents the behaviour.
    final List<({double lat, double lon})> pacific = const <({double lat, double lon})>[
      (lat: -10.0, lon: 170.0),
      (lat: -10.0, lon: 180.0),
      (lat: 10.0, lon: 180.0),
      (lat: 10.0, lon: 170.0),
    ];

    test('point inside the eastern half is inside', () {
      expect(pointInPolygon(lat: 0.0, lon: 175.0, ring: pacific), isTrue);
    });

    test('point west of the ring is outside', () {
      expect(pointInPolygon(lat: 0.0, lon: 169.0, ring: pacific), isFalse);
    });
  });
}
