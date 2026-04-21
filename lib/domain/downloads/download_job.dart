// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// ignore_for_file: invalid_annotation_target — `@JsonKey` is valid on Freezed
// factory parameters (analyzer can't see it through the factory indirection).

import 'package:freezed_annotation/freezed_annotation.dart';

import '../map/country_catalog.dart';
import '../map/country_code.dart';

part 'download_job.freezed.dart';
part 'download_job.g.dart';

/// The intent to download a single country's PMTiles bundle.
///
/// A [DownloadJob] carries the resolved [CountryEntry] (NOT a lazy
/// reference) so the download pipeline can commit to one catalog snapshot
/// even if the catalog is re-loaded mid-download. The `enqueuedAtUtc`
/// timestamp lets the Phase 07-05 UI present a stable queue order.
/// `userPausedFlag` distinguishes a manually paused job (resume requires
/// explicit user action) from a network-dropped job (resume auto-triggers
/// when connectivity comes back).
@freezed
abstract class DownloadJob with _$DownloadJob {
  factory DownloadJob({
    @JsonKey(fromJson: countryCodeFromJson, toJson: countryCodeToJson) required CountryCode alpha3,
    required CountryEntry entry,
    required DateTime enqueuedAtUtc,
    @Default(false) bool userPausedFlag,
  }) = _DownloadJob;

  factory DownloadJob.fromJson(Map<String, Object?> json) => _$DownloadJobFromJson(json);
}
