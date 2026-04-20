// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'country_code.dart';

/// Map-layer domain exceptions.
///
/// Every class in this file `implements Exception` — never `extends Error`
/// — per CLAUDE.md §Error handling: `Error` is reserved for programming
/// bugs (invariant violations, null surprises); these are recoverable
/// external-world failures (missing asset, on-disk corruption, filesystem
/// out of space, etc.) that the UI layer turns into user-facing dialogs.
///
/// `toString()` is always an override that inlines every structured field
/// so log inspection reveals the full context without extra allocations
/// or reflection.

/// Thrown when a required bundled asset is not reachable via `rootBundle`.
///
/// Catastrophic — the asset either never made it into the APK/IPA (build
/// config error) or was excluded by a misconfigured `pubspec.yaml` assets
/// block. The first-launch copier (Plan 07-03) raises this with
/// `assetPath == kWorldPmtilesAssetPath` and an action hint in [reason].
class MapAssetMissingException implements Exception {
  const MapAssetMissingException({required this.assetPath, this.reason});

  /// Asset path that was expected to exist (e.g. `assets/maps/world.pmtiles`).
  final String assetPath;

  /// Optional caller-provided context ("empty byte stream", "zero-length",
  /// "rootBundle.load threw FlutterError", etc.). UI surfaces this when
  /// available.
  final String? reason;

  @override
  String toString() {
    final String r = reason == null ? '' : ', reason=$reason';
    return 'MapAssetMissingException(assetPath=$assetPath$r)';
  }
}

/// Thrown when a PMTiles file on disk fails sha256 verification.
///
/// Plan 07-03's first-launch copier compares the on-disk world bundle
/// hash against the compiled-in [kWorldBundleSha256] constant; any
/// mismatch triggers a re-copy from the asset bundle (auto-heal). Plan
/// 07-04's download pipeline raises this on a reassembled country bundle
/// after per-chunk verification succeeds but the concatenated file's hash
/// diverges from the catalog's `reassembled.sha256` — signalling a
/// concatenation bug rather than a download bug.
class PmtilesCorruptException implements Exception {
  const PmtilesCorruptException({required this.filePath, required this.expectedSha256, required this.actualSha256});

  /// Absolute on-disk path of the PMTiles file (e.g. `<app_support>/maps/countries/fra.pmtiles`).
  final String filePath;

  /// Hex sha256 (lower-case, 64 chars) the verification expected.
  final String expectedSha256;

  /// Hex sha256 actually computed from the on-disk file.
  final String actualSha256;

  @override
  String toString() => 'PmtilesCorruptException(filePath=$filePath, expectedSha256=$expectedSha256, actualSha256=$actualSha256)';
}

/// Thrown when the UI attempts to show / interact with a country whose
/// PMTiles bundle is not present in the installed manifest.
///
/// Surfaces as a "Download the map first" toast/dialog — caller should
/// route the user to the Phase 07-05 download screen rather than propagate
/// the exception unhandled.
class CountryNotInstalledException implements Exception {
  const CountryNotInstalledException({required this.alpha3});

  final CountryCode alpha3;

  @override
  String toString() => 'CountryNotInstalledException(alpha3=${alpha3.value})';
}

/// Thrown when a structured document (catalog.json, installed.json, style.json)
/// cannot be parsed against its expected schema.
///
/// Distinct from a raw `FormatException` from json_serializable: the
/// domain layer turns codegen-level parse failures into this typed
/// exception so call sites can surface a single user-friendly message
/// instead of exposing the internal generator error.
class SchemaValidationException implements Exception {
  const SchemaValidationException({required this.documentPath, required this.reason});

  /// Document path being validated (may be an asset path, an absolute
  /// on-disk path, or a logical name — the intent is identification in
  /// logs, not filesystem semantics).
  final String documentPath;

  /// Human-readable reason (e.g. `"missing field 'alpha3'"`).
  final String reason;

  @override
  String toString() => 'SchemaValidationException(documentPath=$documentPath, reason=$reason)';
}

/// Thrown when pre-download disk-space check fails.
///
/// Plan 07-04 computes the needed bytes (chunk total × safety multiplier
/// `kDiskSpaceSafetyMarginMultiplier`) and compares against the
/// filesystem's free-space report BEFORE starting the download; any
/// shortfall raises this exception immediately so the user is not
/// surprised by a mid-download ENOSPC.
class DiskSpaceInsufficientException implements Exception {
  const DiskSpaceInsufficientException({required this.neededBytes, required this.freeBytes});

  final int neededBytes;
  final int freeBytes;

  @override
  String toString() => 'DiskSpaceInsufficientException(neededBytes=$neededBytes, freeBytes=$freeBytes)';
}

/// Thrown when `assets/maps/style.json` is unparseable or fails the
/// frozen 8-layer structural check.
///
/// The 8-layer order (`background, landcover, water, boundaries, roads,
/// pois, mirk_fog, user_location`) is frozen as of Plan 07-01 — Plan
/// 07-06's `map_style_layer_order_test.dart` asserts it explicitly, and
/// the runtime style loader surfaces a [MapStyleCorruptException] with
/// actionable [reason] when a bundled (or sideloaded) style drifts.
class MapStyleCorruptException implements Exception {
  const MapStyleCorruptException({required this.reason});

  final String reason;

  @override
  String toString() => 'MapStyleCorruptException(reason=$reason)';
}

/// Thrown when `CountryDeleteService` (Plan 07-04) is asked to delete
/// [CountryCode.world] — the bundled world basemap is read-only and
/// removing it would leave the map completely blank with no recovery
/// path other than reinstalling the app.
///
/// Callers MUST compare against [CountryCode.world] rather than the raw
/// string literal `'wld'` — see the `CountryCode` class docstring for the
/// reservation contract. [reason] is optional; when omitted the default
/// `toString()` still names the sentinel explicitly.
class CannotDeleteWorldBundleException implements Exception {
  const CannotDeleteWorldBundleException({this.reason});

  /// Optional log-context reason (e.g. `"triggered by settings → reset"`).
  final String? reason;

  @override
  String toString() {
    final String r = reason == null ? '' : ', reason=$reason';
    return 'CannotDeleteWorldBundleException(alpha3=${CountryCode.world.value}$r)';
  }
}
