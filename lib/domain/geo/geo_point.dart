// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Geographic point in degrees.
///
/// A record, not a class: same shape as the historical `MapView.markVisited` parameter,
/// and zero `latlong2` dependency in the domain (Phase 09.1 C2, option A). The map adapter
/// converts to / from `LatLng` at the `lib/infrastructure/map/` boundary; every domain and
/// renderer consumer stays engine-agnostic.
typedef GeoPoint = ({double latitude, double longitude});
