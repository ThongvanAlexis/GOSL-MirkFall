// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/map/country_code.dart';

/// In-memory stand-in for the Plan 07-03 `CountryResolver` seam.
///
/// The real `CountryResolver` reads the bundled polygons under
/// `assets/maps/polygons/` and returns the alpha3 whose bounding box
/// contains a given viewport center. This fake replaces all of that
/// with a [seed]ed answer — tests deterministically set the viewport →
/// alpha3 mapping without loading GeoJSON at test time.
///
/// The seam lands in Plan 07-03 under
/// `lib/infrastructure/map/country_resolver.dart`; at that point this
/// fake upgrades to `implements CountryResolver`. Meanwhile, its surface
/// mirrors the seam's single-method shape so widget tests can already
/// type-check against it.
class FakeCountryResolver {
  FakeCountryResolver({CountryCode? seededAnswer}) : _seeded = seededAnswer;

  CountryCode? _seeded;

  /// Every `(lat, lon, zoom)` triple passed to [resolveForViewport] so
  /// far. Tests assert count + argument fidelity.
  final List<({double lat, double lon, double zoom})> viewportsQueriedObserved = <({double lat, double lon, double zoom})>[];

  /// Sets the answer returned by subsequent [resolveForViewport] calls.
  /// `null` means "no country covers this viewport — fall back to the
  /// world bundle".
  void seed(CountryCode? answer) {
    _seeded = answer;
  }

  /// Returns the currently-[seed]ed alpha3 (or `null`). Records the
  /// input triple for post-hoc inspection.
  CountryCode? resolveForViewport({required double lat, required double lon, required double zoom}) {
    viewportsQueriedObserved.add((lat: lat, lon: lon, zoom: zoom));
    return _seeded;
  }
}
