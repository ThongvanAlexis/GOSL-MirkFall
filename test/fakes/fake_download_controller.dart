// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Forward declaration for Phase 07 plan 07-04 (download pipeline).
///
/// Placeholder so downstream plans can list this path in their
/// `files_modified` frontmatter. The real `FakeDownloadController`
/// implementation lands alongside `PmtilesDownloadController` — it
/// will expose a deterministic drive-by-step API (emit Downloading ->
/// Paused -> Downloading -> Completed sequences on demand) so widget
/// tests for `/maps/download` + the AppBar progress chip can exercise
/// every state transition without a real network round-trip.
///
/// Real network round-trips are covered separately by the MockHTTPServer
/// integration tests (Phase 07 plan 07-04) using `package:shelf`
/// (promoted to direct dev_dependencies in Plan 07-01 Task 1).
library;
