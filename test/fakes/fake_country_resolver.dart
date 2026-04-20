// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Forward declaration for Phase 07 plan 07-03 (map infrastructure —
/// country resolver).
///
/// Placeholder so downstream plans can list this path in their
/// `files_modified` frontmatter. The real `FakeCountryResolver`
/// implementation lands when the `CountryResolver` port materialises
/// in `lib/infrastructure/map/country_resolver.dart` — it will expose
/// a deterministic `(viewportCenter, zoom) -> Option<alpha3>` map
/// that widget tests and controller tests can drive by calling
/// `whenCenterIsIn(fixtureRegion).thenReturn('fra')` without loading
/// real polygon GeoJSON at test time.
///
/// The production resolver consumes the simplified polygons bundled
/// in `assets/maps/polygons/<alpha3>.geo.json` (produced one-shot by
/// `tool/simplify_polygons.dart` — Phase 07-01 Task 1 ships a
/// bounding-box simplification; a follow-up plan may replace with
/// higher-fidelity mapshaper output without churning the consumer
/// path).
library;
