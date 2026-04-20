// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Forward declaration for Phase 07 plan 07-03 (map infrastructure).
///
/// Placeholder so downstream plans can list this path in their
/// `files_modified` frontmatter. The real `FakePmtilesSource`
/// implementation lands when the `PmtilesSource` seam materialises in
/// `lib/infrastructure/map/pmtiles_source.dart` — at that point the
/// fake will expose a mutable installed-country map so country-resolver
/// tests can flip "installed" / "not installed" deterministically
/// without filesystem I/O.
///
/// The seam itself stays narrow: resolve an alpha3 (or the world
/// bundle fallback) to a local filesystem URL, report back via
/// `pmtiles://file:///…`. No remote HTTP path exists — the
/// `tool/check_avoid_remote_pmtiles.dart` CI gate (Phase 07 plan
/// 07-01 Task 2) enforces this invariant at lint time.
library;
