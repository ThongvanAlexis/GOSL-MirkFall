// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/map/country_code.dart';

/// In-memory stand-in for the Plan 07-03 `PmtilesSource` seam.
///
/// `PmtilesSource` itself is introduced by Plan 07-03 in
/// `lib/infrastructure/map/pmtiles_source.dart` — at that point this fake
/// will be upgraded to `implements PmtilesSource`. Meanwhile, the surface
/// exposed here matches the seam's narrow single-method shape
/// (`forCountry(CountryCode?) -> String uri`), so widget + controller
/// tests that consume the resolver function can already type-check
/// against the fake ahead of the interface landing.
///
/// Default results are absolute-looking local paths (Phase 09.1: the
/// seam resolves to a filesystem path consumed by
/// `PmTilesVectorTileProvider.fromSource`, never a URI — MAP-05). Tests
/// that need a specific path pass it in via [uriOverrides].
class FakePmtilesSource {
  FakePmtilesSource({Map<CountryCode?, String>? uriOverrides}) : _uriOverrides = <CountryCode?, String>{...?uriOverrides};

  final Map<CountryCode?, String> _uriOverrides;

  /// Every `(country) -> uri` resolution performed so far — tests assert
  /// count + ordering by reading this list.
  final List<CountryCode?> forCountryCallsObserved = <CountryCode?>[];

  /// Resolves [code] to a local archive path. Returns the caller-provided
  /// override when present; otherwise synthesises a deterministic fake
  /// path so a smoke test can observe the return value without a
  /// filesystem fixture.
  ///
  /// `null` means "world bundle fallback" — matches the [MapView.showMap]
  /// contract.
  String forCountry(CountryCode? code) {
    forCountryCallsObserved.add(code);
    final String? override = _uriOverrides[code];
    if (override != null) return override;
    return '/fake/${code?.value ?? 'world'}.pmtiles';
  }
}
