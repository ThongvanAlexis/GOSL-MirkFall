<!-- Copyright (c) 2026 THONGVAN Alexis -->
<!-- Licensed under the Good Old Software License v1.0 -->
<!-- See LICENSE file for details -->

# `lib/infrastructure/installed_maps/` — installed-maps manifest storage

Phase 07 plan 07-04 concrete impl of the `InstalledManifestRepository`
domain port from Plan 07-02:

- `installed_manifest_repository.dart` — `JsonFileInstalledManifestRepository`
  backed by `<app_support>/maps/installed.json`. Atomic write-to-temp
  + rename (Phase 03 `DbBackupService` atomic-backup precedent); a
  crash mid-write leaves either the old or the new file, never a
  truncated one.
- `first_launch_bootstrap.dart` — `FirstLaunchBootstrap` orchestrates
  the cold-start sequence: delegate world-bundle copy to Plan 07-03's
  `FirstLaunchWorldCopier`, scan the staging tree for orphan
  per-country directories left behind by a previous interrupted
  session, invoke `IosBackupExcluder.excludePath` on the maps tree
  once on iOS first launch.

## Allowed imports

- `dart:*`
- `package:path`
- `package:logging`
- `package:mirkfall/domain/installed_maps/...` (port definitions)
- `package:mirkfall/domain/map/country_code.dart`
- `package:mirkfall/infrastructure/map/first_launch_world_copier.dart`
  (delegated by the bootstrap)
- `package:mirkfall/infrastructure/platform/ios_backup_excluder.dart`

Never imports `maplibre_gl` (the `check_avoid_maplibre_leak` CI gate
enforces the seam), never reads a PMTiles file directly — the
manifest is a pure JSON document whose payloads live elsewhere.

## Atomic write pattern

Mirrors Phase 03's `DbBackupService` precedent. Every `write` lands
via:

1. `writeAsString(jsonEncode(manifest), flush: true)` to
   `installed.json.tmp`
2. `tmp.rename('installed.json')` — atomic on POSIX + ext4/APFS/NTFS

A stale `.tmp` file left over from an earlier crash is harmless: the
`read` path only looks at the canonical filename, and the next
successful `write` overwrites the stale temp with a fresh copy.

## Orphan staging policy

On app start, `FirstLaunchBootstrap` scans `<app_support>/maps/staging/`
for per-alpha3 subdirectories and routes each one through a
three-case cleanup policy:

1. **Staging dir + alpha3 IS in `installed.json`** — the atomic commit
   succeeded but the post-commit cleanup step failed. The pmtiles is
   already installed, so the staging dir is pure disk waste:
   **DELETE**.
2. **Staging dir + alpha3 NOT in manifest + IS in persisted download
   queue** (`maps/download_queue.json`) — genuinely in-flight; the
   `DownloadQueueController.rehydrate()` path will pick it up on app
   start, and the chunk pre-check in
   `PmtilesDownloadController._downloadChunkWithRetries` will reuse
   the bytes already on disk (skipping the network round-trip for any
   fully-written chunk): **LEAVE ALONE**.
3. **Staging dir + alpha3 NOT in manifest + NOT in queue** — truly
   abandoned (app killed before the queue was persisted, or the queue
   file was corrupt and got reset to empty). No consumer will ever
   pick this up: **DELETE**. User has to manually re-enqueue the
   country from the download screen if they want it.

`FirstLaunchBootstrap.orphanStagingAlpha3s` holds only the case-2
alpha3s (resumable orphans) after `run()`. It is exposed for test
assertions + debug inspection; no production consumer reads it.
