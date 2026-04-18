// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Display name shown in launcher / About screen.
const String kAppName = 'MirkFall';

/// Bundle / application ID — same on Android and iOS.
const String kBundleId = 'app.gosl.mirkfall';

/// Hard cap on total bytes used by `<app_docs>/logs/` after startup prune.
const int kMaxLogsDirBytes = 10 * 1024 * 1024; // 10 MB

/// 7-tap easter-egg parameters for the about-screen → debug-menu navigation.
const int kAboutTapsToTriggerDebugMenu = 7;
const int kAboutTapWindowMilliseconds = 3000;

/// Upper bound on total elapsed time from first tap to 7th tap for the
/// easter egg to fire. Guards against users inadvertently accumulating
/// seven taps over several minutes of casual interaction.
const int kAboutTapTotalWindowMilliseconds = 10000;

/// Share-sheet call timeout (ms). Applied to every native plugin share call
/// so a pending OS dialog cannot hang the UI indefinitely — mandated by
/// CLAUDE.md §Timeouts for native-plugin invocations.
const int kShareCallTimeoutMilliseconds = 30000;

/// Hybrid flush cadence for the FileLogger sink. A flush is forced every
/// [kFileLoggerFlushEveryNRecords] records OR whenever a Logger.shout is
/// emitted (errors always flush immediately). Balances the per-record fsync
/// cost against acceptable data-loss window on abrupt process termination.
const int kFileLoggerFlushEveryNRecords = 20;

/// Default screen-body padding for placeholder / full-bleed content screens
/// (logical pixels). Named so the intent ("breathing room around centered
/// text") is explicit rather than requiring the reader to guess a pixel
/// literal's purpose.
const double kScreenBodyPaddingLogicalPx = 24.0;

/// Default spacing between stacked list rows in Material layouts (logical px).
/// Aligns with Material Design's 16dp base grid — small enough to feel tight,
/// large enough to give each row its own focus region.
const double kListSectionPaddingLogicalPx = 16.0;

// ---------------------------------------------------------------------------
// Phase 03 (Persistence & Domain Models) — constants consumed across DB
// wiring (03-04, 03-05), migration/backup infra (03-05), and stores (03-06).
// ---------------------------------------------------------------------------

/// SQLite database filename inside `<app_support>/`. Single-file DB; the
/// directory itself is created lazily by `path_provider` on first access.
const String kDbFilename = 'mirkfall.db';

/// Directory (inside `<app_support>/`) where pre-migration backups land.
/// Backups are named with the schema version they were captured AT (i.e.
/// the version BEFORE the upgrade ran), so a corrupted upgrade can roll
/// back to the matching bytes-on-disk snapshot.
const String kDbBackupDirName = 'db_backups';

/// Rolling cap on kept pre-migration backups (oldest evicted FIFO).
/// Three is enough to cover "ran the migration twice in a row by accident"
/// without unbounded disk growth on devices with tight storage.
const int kMaxDbBackups = 3;

/// SQLite `busy_timeout` PRAGMA value (ms). Retry window before
/// `SQLITE_BUSY` propagates to the caller. 5 s is conservative on mobile —
/// the only contender for the writer lock is the foreground service writing
/// revealed-tile bitmaps (Phase 09), and even a flushed batch finishes in
/// well under one second.
const int kDbBusyTimeoutMs = 5000;

/// Zoom level at which "parent tiles" carry a 64×64 bitmap in
/// `t_revealed_tiles`. Revealed-mirk storage unit (decision D3 — see
/// PROJECT.md Key Decisions: zoom-14 parent tiles + 64×64 sub-tile grid).
const int kRevealedTileParentZoom = 14;

/// Sub-grid resolution per parent tile. 64×64 = 4096 bits = 512 bytes per
/// row. Smaller than 64 wastes per-row overhead; larger inflates per-tile
/// memory residency without improving reveal granularity at zoom 14+4.
const int kRevealedTileSubgridSize = 64;

/// Convenience: bytes per stored bitmap, derived from [kRevealedTileSubgridSize].
/// 64 * 64 / 8 = 512. Hoisted as a constant so callers (DB schema, perf
/// budgets, fixture seeders) reference the same number without re-deriving.
const int kRevealedTileBitmapBytes = (kRevealedTileSubgridSize * kRevealedTileSubgridSize) ~/ 8;

/// Lower bound on UTC-offset-minutes for Session + timestamp columns.
/// -720 min = UTC-12 (Baker Island / US Minor Outlying — the westernmost
/// IANA zone still in use).
///
/// NOTE on `@Assert` carve-out — Freezed `@Assert('expr', 'msg')` evaluates
/// the expression STRING at compile-time; Dart annotation bodies cannot
/// reference top-level `const int` identifiers inside the string. Callers
/// that live inside `@Assert` therefore keep the literal `-720` and pair
/// with a test-level guard that references this constant so any future
/// change propagates to a single source of truth.
const int kMinUtcOffsetMinutes = -720;

/// Upper bound on UTC-offset-minutes for Session + timestamp columns.
/// 840 min = UTC+14 (Kiribati Line Islands — the easternmost zone).
///
/// See [kMinUtcOffsetMinutes] for the `@Assert` carve-out rationale.
const int kMaxUtcOffsetMinutes = 840;

// Reserved for later phases (declared here so future callers can import from
// a stable location):
//   - kDefaultRevealRadiusMeters  (Phase 09 — fog reveal radius)
//   - kHttpTimeout                (Phase 07 — tile fetch timeout)
//   - kMarkerPhotoMaxDimension    (Phase 11 — photo downscale cap)
