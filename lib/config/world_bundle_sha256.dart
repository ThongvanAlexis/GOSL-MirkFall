// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// sha256 (hex) of the bundled `assets/maps/world.pmtiles` world-map PMTiles.
///
/// Emitted build-time by `tool/generate_world_sha256.dart`. The first-launch
/// world copier (Phase 07 plan 07-03) compares this constant against the hash
/// of the file currently at `<app_support>/maps/world.pmtiles`; a mismatch or
/// missing file triggers a re-seed from the asset. Zero runtime cost — no
/// asset re-read at app boot.
///
/// **Do NOT hand-edit.** Regenerate via `dart run tool/generate_world_sha256.dart`
/// after every `assets/maps/world.pmtiles` update.
const String kWorldBundleSha256 = '62782f3bbc16bc3d3d005299007374d3e281dcdc97e5282ec04c027e867f38d6';
