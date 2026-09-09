// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:path/path.dart' as p;

/// Resolves the absolute filesystem path of the PMTiles archive to open
/// for a given `CountryCode?`.
///
/// The path is consumed by `PmTilesVectorTileProvider.fromSource` (see
/// `flutter_map_map_view.dart`): `pmtiles 1.2.0` routes any source that
/// does not start with `http(s)://` to a local `FileAt` reader, so this
/// resolver is the MAP-05 guarantee — it never emits a URL, only
/// `p.join` results rooted at the app-support directory.
///
/// Contract:
/// - `forCountry(null)` always returns the world bundle path.
/// - `forCountry(CountryCode.world)` also returns the world bundle path
///   (explicit sentinel — matches the reservation contract on
///   [CountryCode.world]).
/// - `forCountry(code)` returns the per-country path when `code` is present
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

  /// Absolute path to the bundled world basemap, e.g.
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
  /// and returns the absolute archive path without any I/O.
  ///
  /// Sentinel branches documented on the class docstring.
  String forCountryOrWorld(CountryCode? code, InstalledManifest snapshot) {
    if (code == null || code == CountryCode.world) {
      return _worldFilename;
    }
    final InstalledCountry? entry = snapshot.installed[code.value];
    if (entry == null) {
      return _worldFilename;
    }
    return p.join(_appSupportDir, entry.filePath);
  }
}
