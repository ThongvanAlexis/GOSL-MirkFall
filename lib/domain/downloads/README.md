# domain/downloads/

Pure-Dart domain types for the per-country PMTiles download pipeline (Phase 07).

**Allowed imports:** `dart:*`, `package:freezed_annotation`, `package:json_annotation`, `package:collection`, sibling `lib/domain/*` directories.

**Forbidden:** `package:flutter/*`, `package:drift/*`, `package:maplibre_gl/*`, `package:http/*`, `package:dio/*`, anything under `lib/application/` or `lib/infrastructure/`. The pipeline implementation + HTTP plumbing + retries + on-disk staging live in `lib/infrastructure/` (Plan 07-04).

Enforced by `tool/check_domain_purity.dart`.

**Exports:**

- `DownloadJob` — Freezed entity: the intent to download a single country's PMTiles bundle (`alpha3`, resolved `CountryEntry`, queued-at timestamp, user-paused flag).
- `DownloadState` — sealed hierarchy with 7 variants (`Idle`, `Queued`, `InProgress`, `Paused`, `Error`, `Completed`, `Cancelled`) consumed by the Phase 07-05 UI.
- `DownloadProgress` — Freezed snapshot: bytes downloaded + total bytes + current part index + total parts. `fractionDone` getter.
- `PauseReason` — enum (`manual`, `networkLost`, `retryExhausted`).
- 4 download-layer exceptions (`DownloadInterruptedException`, `Sha256MismatchException`, `ConcatFailureException`, `HttpRangeNotSupportedException`) — all `implements Exception`.
