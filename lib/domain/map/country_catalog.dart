// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters because Freezed copies it onto the generated field; the
// analyzer can't see that through the factory indirection (mirrors the
// carve-out already documented in lib/domain/sessions/session.dart).

import 'package:freezed_annotation/freezed_annotation.dart';

import 'country_code.dart';

part 'country_catalog.freezed.dart';
part 'country_catalog.g.dart';

/// Root document of `assets/maps/catalog.json` — the frozen catalogue of
/// downloadable per-country PMTiles bundles.
///
/// Version is derived from the release-tag segment embedded in
/// `countries[0].parts[0].url` (see [catalogVersion]). The catalogue
/// itself has no version field on disk — the tag IS the version, and
/// bumping it requires regenerating every chunk + hash, so it is
/// authoritative.
///
/// Plain `factory` (not `const factory`) matches the Phase 03 Freezed
/// precedent for entities with `@Assert`s that compute over collection
/// shape: Dart 3.11 rejects some collection operations inside const
/// asserts, and keeping plain `factory` preserves room for future
/// asserts that read derived getters.
@freezed
abstract class CountryCatalog with _$CountryCatalog {
  @Assert('countries.length > 0', 'CountryCatalog.countries must not be empty')
  factory CountryCatalog({required List<CountryEntry> countries}) = _CountryCatalog;

  factory CountryCatalog.fromJson(Map<String, Object?> json) => _$CountryCatalogFromJson(json);
}

/// Lazily-computed helpers bolted onto [CountryCatalog].
///
/// [catalogVersion] extracts the GitHub Release tag from the first
/// chunk's URL — e.g.
/// `https://github.com/.../releases/download/v20260419/abw.part01` → `v20260419`.
/// Throws [FormatException] when the first URL does not match the expected
/// `releases/download/<tag>/...` shape (catastrophic — the catalogue is
/// malformed or points at a non-GitHub-Releases host).
extension CountryCatalogVersion on CountryCatalog {
  /// Release-tag version string derived from the first chunk URL.
  ///
  /// The catalog has no explicit version field — the tag segment in
  /// `parts[].url` IS the version. Bumping the tag implies regenerating
  /// every chunk hash, so the tag is authoritative.
  String get catalogVersion {
    if (countries.isEmpty || countries.first.parts.isEmpty) {
      throw const FormatException('CountryCatalog.catalogVersion: empty countries or parts list');
    }
    final String firstUrl = countries.first.parts.first.url;
    // Regex literal — documented in README: release URLs follow the
    // GitHub Release download scheme. Anchored on `/releases/download/`
    // so a non-matching host fails loudly.
    final RegExpMatch? match = RegExp(r'/releases/download/([^/]+)/').firstMatch(firstUrl);
    if (match == null) {
      throw FormatException('CountryCatalog.catalogVersion: URL does not match /releases/download/<tag>/ pattern: "$firstUrl"');
    }
    return match.group(1)!;
  }
}

/// One country in the catalogue: alpha-3 code, human-readable name, and
/// the ordered list of chunks that compose its PMTiles bundle.
///
/// `alpha3` is carried as a validated [CountryCode] — the field-level
/// `@JsonKey` converter pair bridges to/from the JSON string
/// representation (Phase 03 convention — see `id_json_converters.dart`).
@freezed
abstract class CountryEntry with _$CountryEntry {
  @Assert('name.trim().isNotEmpty', 'CountryEntry.name must be non-empty')
  @Assert('parts.length > 0', 'CountryEntry.parts must not be empty')
  factory CountryEntry({
    @JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) required CountryCode alpha3,
    required String name,
    required List<ChunkPart> parts,
    required ReassembledMeta reassembled,
  }) = _CountryEntry;

  factory CountryEntry.fromJson(Map<String, Object?> json) => _$CountryEntryFromJson(json);
}

/// Convenience aggregates over a [CountryEntry].
extension CountryEntryTotals on CountryEntry {
  /// Sum of all chunk sizes. Matches [ReassembledMeta.size] by contract
  /// when the catalogue is well-formed; verified at catalog-generation
  /// time, not at runtime (saves a per-country loop on every read).
  int get totalBytes => parts.fold<int>(0, (int acc, ChunkPart p) => acc + p.size);
}

/// One downloadable chunk of a country PMTiles bundle.
///
/// `sha256` is the 64-char lower-case hex digest of the chunk contents.
/// `size` is the expected byte length (used for progress math + Content-Length
/// cross-check during download). `url` is the absolute HTTPS URL of the
/// chunk (always GitHub Releases in Phase 07 — the CI gate
/// `tool/check_avoid_remote_pmtiles.dart` prohibits any `pmtiles://http…`
/// URIs, but ordinary `https://…` pointers to .part01 files are allowed).
@freezed
abstract class ChunkPart with _$ChunkPart {
  @Assert('sha256.length == 64', 'ChunkPart.sha256 must be exactly 64 hex chars')
  @Assert('size > 0', 'ChunkPart.size must be positive')
  @Assert('url.length > 0', 'ChunkPart.url must be non-empty')
  factory ChunkPart({required String sha256, required int size, required String url}) = _ChunkPart;

  factory ChunkPart.fromJson(Map<String, Object?> json) => _$ChunkPartFromJson(json);
}

/// Expected hash + size of the reassembled PMTiles file (after all
/// [ChunkPart]s are concatenated in order).
///
/// The download pipeline (Plan 07-04) verifies the concatenated file's
/// actual sha256 against [sha256] before the manifest is updated — a
/// mismatch throws [Sha256MismatchException] and the staging file is
/// deleted.
@freezed
abstract class ReassembledMeta with _$ReassembledMeta {
  @Assert('sha256.length == 64', 'ReassembledMeta.sha256 must be exactly 64 hex chars')
  @Assert('size > 0', 'ReassembledMeta.size must be positive')
  factory ReassembledMeta({required String sha256, required int size}) = _ReassembledMeta;

  factory ReassembledMeta.fromJson(Map<String, Object?> json) => _$ReassembledMetaFromJson(json);
}
