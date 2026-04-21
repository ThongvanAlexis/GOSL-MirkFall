<!-- Copyright (c) 2026 THONGVAN Alexis -->
<!-- Licensed under the Good Old Software License v1.0 -->
<!-- See LICENSE file for details -->

# `lib/infrastructure/downloads/` — country-download pipeline

Phase 07 plan 07-04 (download pipeline) materializes the 7-step atomic
protocol that takes a `CountryEntry` from the catalog and ends with a
fully-installed country PMTiles file on disk:

0. **Disk preflight** via `DiskSpaceChecker` — fail fast before network IO.
1. **Download N chunks** via `HttpChunkDownloader` — HTTP Range resume,
   graceful 200-OK restart fallback, retries with 1s/5s/30s backoff.
2. **Per-chunk sha256 verification** via `Sha256Verifier`.
3. **Streaming concatenation** via `BinaryConcatenator` (IOSink append).
4. **Global sha256** over the reassembled file (vs `reassembled.sha256`).
5. **Atomic rename** via `AtomicRenamer` — tempfile → final path.
6. **Manifest update** via `InstalledManifestRepository.write` — atomic
   tempfile + rename (Phase 03 `DbBackupService`-style precedent).
7. **Staging cleanup** — remove the per-alpha3 staging directory.

Every step is independently testable; the end-to-end soak test (gated
behind `@Tags(['soak'])`) exercises the full protocol against a
`shelf`-backed MockHTTPServer covering every crash + error path.

## Allowed imports

- `dart:*` (including `dart:io` HttpClient — do NOT adopt `package:http`)
- `package:crypto` (direct dep since Plan 07-01)
- `package:path` (already direct)
- `package:flutter/*` (platform-channels via `DiskSpaceChecker` /
  `IosBackupExcluder`)
- `package:logging`
- `package:mirkfall/...` domain + constants
- `package:riverpod_annotation` for `PmtilesDownloadController`

## Atomic-write invariant

MAP-09: a country is either **absent** or **fully installed** — never
partial. Callers that observe the `<app_support>/maps/countries/` tree
or `installed.json` must see one of:

- File present AND manifest entry present (fully installed)
- File absent AND manifest entry absent (clean uninstalled state)

Any other combination is a bug that this pipeline explicitly prevents
via the 7-step protocol + atomic rename ordering.

## Layout

- `sha256_verifier.dart` — streaming `crypto` AccumulatorSink (constant memory).
- `binary_concatenator.dart` — IOSink-based concat without loading into heap.
- `atomic_renamer.dart` — `File.rename` wrapper with cross-volume copy fallback.
- `http_chunk_downloader.dart` — `dart:io` HttpClient + Range resume + redirect.
- `download_queue_store.dart` — persistent JSON queue (survives app restart).
- `pmtiles_download_controller.dart` — Riverpod `keepAlive` orchestrator.

## Handoff

- Plan 07-05 (controllers and providers) exposes the controller to the UI
  via Riverpod providers.
- Plan 07-06 (presentation) renders download progress + manifest state.
