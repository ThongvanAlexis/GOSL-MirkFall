// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Forward declaration for Phase 07 plan 07-04 (download pipeline).
///
/// Placeholder so downstream plans can list this path in their
/// `files_modified` frontmatter. The real
/// `FakeInstalledManifestRepository` implementation lands when the
/// `InstalledManifestRepository` port materialises — it will expose
/// an in-memory map that tracks installed-country entries without
/// touching `<app_support>/maps/installed.json`. Widget tests +
/// controller tests inject it via Riverpod override.
///
/// The manifest schema (`schemaVersion`, `catalogVersion`, and the
/// per-alpha3 `{installed_at_utc, file_size, pmtiles_version, sha256,
/// file_path}` dictionary) is locked in Plan 07-02 alongside the
/// domain entity it serialises.
library;
