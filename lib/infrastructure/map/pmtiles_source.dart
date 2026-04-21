// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:path/path.dart' as p;

/// Converts an absolute filesystem [absolutePath] into the `pmtiles://file://`
/// URI accepted by MapLibre's PMTiles protocol handler.
///
/// Rules (validated by unit tests):
/// - Backslashes are normalised to forward slashes first so Windows-shaped
///   paths (`C:\maps\fra.pmtiles`) produce a stable URI. MapLibre Native is
///   not supported on desktop, but deterministic shape lets unit tests run
///   on Windows dev hosts.
/// - A leading `/` is guaranteed. POSIX paths already start with `/`;
///   Windows paths beginning with a drive letter (`C:/...`) gain an
///   extra `/` so the result reads `pmtiles://file:///C:/...` — the
///   RFC 8089 convention for local file URIs with drive letters.
/// - The `pmtiles://file://` scheme is explicitly exempt from the
///   `tool/check_avoid_remote_pmtiles.dart` CI gate (MAP-05). This function
///   never emits `pmtiles://http[s]`.
///
/// Returned strings always start with `pmtiles://file:///`.
String localPmtilesUri(String absolutePath) {
  final String normalised = absolutePath.replaceAll(r'\', '/');
  // Ensure exactly one leading `/` in the path component.
  final String withSlash = normalised.startsWith('/') ? normalised : '/$normalised';
  return 'pmtiles://file://$withSlash';
}

/// Resolves the runtime PMTiles URI to feed into MapLibre's style source.
///
/// Responsibilities:
/// - For a given `CountryCode?` and the current [InstalledManifest], decide
///   whether to return the bundled world basemap URI or a per-country
///   `.pmtiles` URI.
/// - Never produce a `pmtiles://http[s]` URI. Every path flows through
///   [localPmtilesUri].
///
/// Contract:
/// - `forCountry(null)` always returns the world bundle URI.
/// - `forCountry(CountryCode.world)` also returns the world bundle URI
///   (explicit sentinel path — matches the reservation contract on
///   [CountryCode.world]).
/// - `forCountry(code)` returns the per-country URI when `code` is present
///   in the manifest's `installed` map; otherwise falls back to the world
///   bundle. This mirrors the MapView "uninstalled → world" behaviour
///   called out in the 07-CONTEXT.md §MapView seam.
///
/// The synchronous companion [forCountryOrWorld] is provided for hot paths
/// (viewport-update throttled resolver) where the caller already holds a
/// manifest snapshot and does not want an extra `await` on every frame.
class PmtilesSource {
  PmtilesSource({required InstalledManifestRepository installedManifestPort, required String appSupportDir})
    : _manifestPort = installedManifestPort,
      _appSupportDir = appSupportDir;

  final InstalledManifestRepository _manifestPort;
  final String _appSupportDir;

  /// Absolute POSIX path to the bundled world basemap, e.g.
  /// `<app_support>/maps/world.pmtiles`. Computed once, used by both
  /// the async and sync resolver paths.
  String get _worldFilename => p.join(_appSupportDir, kWorldPmtilesInternalPath);

  /// Async resolver. Awaits a fresh manifest read from the port.
  ///
  /// Callers that do not want to pay the round-trip should use
  /// [forCountryOrWorld] with a pre-fetched snapshot.
  Future<String> forCountry(CountryCode? code) async {
    final InstalledManifest snapshot = await _manifestPort.read();
    return forCountryOrWorld(code, snapshot);
  }

  /// Synchronous resolver. Consumes a caller-provided manifest snapshot
  /// and returns the runtime URI without any I/O.
  ///
  /// Sentinel branches documented on the class docstring.
  String forCountryOrWorld(CountryCode? code, InstalledManifest snapshot) {
    if (code == null || code == CountryCode.world) {
      return localPmtilesUri(_worldFilename);
    }
    final InstalledCountry? entry = snapshot.installed[code.value];
    if (entry == null) {
      return localPmtilesUri(_worldFilename);
    }
    final String countryFilename = p.join(_appSupportDir, entry.filePath);
    return localPmtilesUri(countryFilename);
  }
}
