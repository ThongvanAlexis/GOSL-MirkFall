// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Forward declaration for Phase 07 plan 07-02 (domain interfaces).
///
/// This file is intentionally minimal in Phase 07-01 — it is a
/// placeholder so downstream plans can list it in their `files_modified`
/// frontmatter without the git diff turning into a two-step creation
/// dance. The real `FakeMapView` implementation lands in Plan 07-02
/// Task 2, once the `MapView` domain interface materialises in
/// `lib/domain/map/map_view.dart`.
///
/// `FakeMapView` will implement the full domain port literally (no
/// inheritance from the concrete `MaplibreMapView` adapter), tracking
/// state in memory via public observable getters (`layersAdded`,
/// `cameraMoves`, `markersAdded`, …) — same shape as the Phase 05
/// `test/fakes/fake_location_stream.dart`. Injected into widget tests
/// via Riverpod override to exercise MapScreen + SessionDetailScreen
/// + the burger menu without spinning up a real MapLibre surface.
library;
