// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Display name shown in launcher / About screen.
const String kAppName = 'MirkFall';

/// Bundle / application ID — same on Android and iOS.
const String kBundleId = 'app.gosl.mirkfall';

/// Git commit SHA baked in at build time via `--dart-define=GIT_COMMIT_SHA=abc123`.
/// Falls back to `'dev'` for local builds where the define is not passed.
/// Read at startup by the logger and displayed in the debug menu.
const String kGitCommitSha = String.fromEnvironment('GIT_COMMIT_SHA', defaultValue: 'dev');

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

// ---------------------------------------------------------------------------
// Phase 05 (GPS & Session Lifecycle) — constants consumed across the
// geolocator seam (05-02), the notification service (05-02), the UI
// settings slider (05-04), and the cross-route active-session banner
// (05-04).
// ---------------------------------------------------------------------------

/// Default distance filter for Geolocator streams (meters). User-adjustable
/// via the settings slider (range 2..100). 5m targets a dense trace for
/// fog-rendering quality (Phase 09). Battery-vs-fidelity trade-off
/// profiled during the QUAL-01/02 POC.
const int kDefaultDistanceFilterMeters = 5;

/// Reject any GPS fix with reported accuracy worse than this (meters).
/// Source: indoor GPS typically reports >100m, outdoor open-sky <15m,
/// urban canyon 20–40m — 50m is the signal/noise frontier.
const double kMaxAcceptableAccuracyMeters = 50.0;

/// UI threshold — show "En attente du GPS…" if no fix received since
/// session start after this many seconds. Does not stop tracking; the
/// stream keeps running while the UI shows the waiting state.
const int kFirstFixTimeoutSeconds = 30;

/// Android notification channel ID for the session-tracking foreground
/// service. Stable across app installs — Android preserves per-channel
/// user preferences keyed by this ID.
const String kNotificationChannelId = 'mirkfall_session_tracking';

/// Cross-route active-session banner height in logical pixels.
const double kSessionActiveBannerHeightDp = 40.0;

// ---------------------------------------------------------------------------
// Phase 07 (Map Integration) — constants consumed across the map seam
// (07-03), the download pipeline (07-04), the installed-maps manifest
// (07-04), and the map screen (07-06).
//
// Sourced verbatim from 07-CONTEXT.md §Existing Code Insights. Downstream
// plans import from this single file rather than duplicating literals.
// ---------------------------------------------------------------------------

/// HTTP timeout (ms) applied to the Phase 07 download controller and to any
/// future map-layer fetch that opts in. 30 s is the "no data for this long"
/// threshold — fired per connect, response and per-stream-event.
///
/// History: originally 60 s to survive a 4G slow-start on the first byte of
/// 1.5 GB PMTiles chunks. Lowered to 30 s at the 2026-04-22 device-smoke
/// after observing GitHub Releases CDN closes idle edges around 30-45 s:
/// waiting 60 s for the stall to declare itself cost the user a whole
/// minute of blank progress every time the CDN dropped a connection. At
/// 30 s, the retry-loop recovers roughly twice as fast on transient
/// network hiccups. Retry budget (`kDownloadRetryAttempts` = 3 with
/// 1 s / 5 s / 30 s backoff) still tolerates a full dead-connection
/// scenario without surfacing an error to the user.
///
/// The Phase 05 foreground-service GPS stream does NOT use this constant —
/// geolocator has its own internal platform-level timeout semantics.
const int kHttpTimeout = 30000;

/// Asset path (bundled in APK/IPA) for the country catalog JSON used by
/// the download screen. Update = rebuild app. Superseded the earlier
/// `kMapCatalogUrl` remote-fetch design (see 07-CONTEXT.md amendments).
const String kMapCatalogAssetPath = 'assets/maps/catalog.json';

/// Asset path for the bundled z0-2 world map PMTiles (856 KB). Copied
/// verbatim to `<app_support>/maps/world.pmtiles` on first launch
/// (MAP-07 — non-deletable floor).
const String kWorldPmtilesAssetPath = 'assets/maps/world.pmtiles';

/// Viewport zoom threshold below which [CountryResolver] always returns
/// `null` (→ world-bundle PMTiles), regardless of which installed
/// countries contain the viewport centre.
///
/// Raised 2026-04-21 from 3.0 to 8.0 after device smoke: at zoom 3-7
/// the viewport frames multiple countries at once, but any per-country
/// PMTiles file only contains tiles for that country — neighbours
/// render as blank white areas. At zoom [0, 7] the world bundle
/// (upscaled past its native z0-2 range) stays rectangle-to-rectangle
/// continuous, even if blurry. At zoom >= 8 a single country typically
/// dominates the viewport, so per-country detail wins over world
/// coverage.
///
/// Tuning: if a future bundled world PMTiles extends beyond z2, this
/// threshold can drop without visual impact — the world bundle always
/// renders the full planet at every zoom it natively carries.
const double kWorldFallbackZoomCutoff = 8.0;

/// Relative path (under `<app_support>/`) where the world PMTiles lives
/// at runtime after the first-launch copy. Per-country PMTiles live
/// alongside it under [kCountriesDir].
const String kWorldPmtilesInternalPath = 'maps/world.pmtiles';

/// Relative directory (under `<app_support>/`) where per-country
/// `<alpha3>.pmtiles` bundles land after a successful atomic commit.
const String kCountriesDir = 'maps/countries';

/// Relative directory (under `<app_support>/`) where in-flight downloads
/// stage their chunks before concat + rename. Cleaned on successful
/// commit or explicit cancel.
const String kStagingDir = 'maps/staging';

/// Relative path (under `<app_support>/`) for the installed-maps manifest
/// JSON — the source of truth for "which countries are on disk right
/// now + their sha256 + catalog version tag". Rewritten atomically
/// (tempfile + rename) after each download commit or deletion.
const String kInstalledManifestPath = 'maps/installed.json';

/// Asset directory containing the simplified country bounding polygons
/// used by the country resolver (viewport-center point-in-polygon).
/// Layout decision (per-file vs aggregate) made in Plan 07-01 itself;
/// the path stays stable for downstream consumers.
const String kCountryPolygonsAssetPath = 'assets/maps/polygons';

/// Asset path for the Protomaps basemaps neutral style JSON (frozen
/// 7-layer order: background / landcover / water / boundaries / roads /
/// pois / mirk_fog — `user_location` was removed post Phase 07 device
/// smoke in favour of maplibre_gl's built-in `addCircle` annotation
/// manager). Glyphs + sprites point to
/// `asset:///assets/maps/glyphs|sprites/…` URIs; the tile source URL is
/// a `pmtiles://file:///YOUR_PMTILES_PATH_PLACEHOLDER` placeholder
/// rewritten at runtime by `PmtilesSource` (Phase 07 plan 07-03).
const String kStyleJsonAssetPath = 'assets/maps/style.json';

/// Initial camera zoom level when opening the map screen from an active
/// session. Z=15 shows a ~500 m square — close enough that the 20 m
/// reveal radius is clearly visible AND the atmospheric fog's animated
/// noise effect resolves at a usable scale (z=13 was too far out: noise
/// was indistinguishable from a flat fill, and the user couldn't see what
/// they were revealing). Bumped during BUG-003 fix on 2026-04-25.
const int kInitialSessionMapZoom = 15;

/// Radius (meters) of the data-only reveal seeded around the user's
/// position at session open. Phase 07 captures the intent in the DB but
/// does NOT paint fog — the corresponding render lands in Phase 09 when
/// the mirk renderer materialises the RevealedTileStore state.
const int kInitialRevealRadiusMeters = 20;

/// Safety-margin multiplier applied to the expected total byte size when
/// refusing a download that would fit too tightly on free disk. 1.1 =
/// require at least 110 % of the expected size to stay available
/// post-write (buffer for the FS, staging, and concurrent app writes).
const double kDiskSpaceSafetyMarginMultiplier = 1.1;

/// Maximum number of consecutive retry attempts on a single chunk
/// download before the controller pauses and surfaces a "network
/// unavailable" banner. After N failures the pipeline is gated by
/// explicit user resume, NOT an open-ended auto-retry loop.
const int kDownloadRetryAttempts = 3;

/// Base delay (ms) for the exponential backoff between download retries.
/// Actual delays follow the 1 s / 5 s / 30 s curve described in
/// 07-CONTEXT.md §Pipeline download pays (kDownloadRetryBaseDelayMs,
/// ×5, ×30).
const int kDownloadRetryBaseDelayMs = 1000;

/// Minimum wall-clock gap between two consecutive `DownloadInProgress`
/// emissions from the Phase 07 download controller. Without this
/// throttle the HTTP `onProgress` callback (fired for every TCP chunk
/// — tens of times per second on a fast connection) would flood the
/// Riverpod state stream and rebuild the download screen at every
/// tick. 250 ms = 4 updates/s, which is smooth for the percent label
/// + the speed readout while costing ≤1 % extra CPU over the
/// one-emit-per-HTTP-chunk baseline. Bumping this down past ~100 ms
/// is possible but not measurably better — human eyes don't notice
/// faster than that.
const int kDownloadProgressEmitThrottleMs = 250;

/// Snackbar visible duration (seconds) for a download-completed success
/// toast on the maps download screen. Kept short — the success is
/// already mirrored in the list row turning green; the snackbar is a
/// courtesy marker, not a primary status channel.
const int kDownloadCompletedSnackbarSeconds = 3;

/// Snackbar visible duration (seconds) for a download-error toast on
/// the maps download screen. Longer than the success variant because
/// the error message itself is longer and the user may want to read
/// the cause before retrying.
const int kDownloadErrorSnackbarSeconds = 5;

/// Snackbar visible duration (seconds) for the immediate
/// "added to the download queue" confirmation toast shown right after
/// the user taps Download on the confirm dialog. Short — the AppBar
/// chip takes over once the controller transitions to
/// DownloadInProgress, so the snackbar is a brief hand-off marker.
const int kDownloadEnqueueConfirmSnackbarSeconds = 2;

/// Snackbar visible duration (seconds) for the error toast surfaced
/// when `enqueue` itself throws (queue store write failure, repository
/// error, etc.). Same length as the download-error toast because the
/// user will want to read the cause before retrying.
const int kDownloadEnqueueErrorSnackbarSeconds = 5;

/// Style-source ID for the GeoJSON source carrying the user-location
/// puck's current position. Namespaced with `mirkfall_` so a downstream
/// style tweak cannot accidentally collide. Hoisted here (rather than
/// file-local in `maplibre_map_view.dart`) per CLAUDE.md §Magic numbers
/// so any future widget that re-publishes the puck source references
/// the same string identifier.
const String kUserLocationSourceId = 'mirkfall_user_location_source';

/// Style-layer ID for the circle layer that renders the user-location
/// puck. Pairs with [kUserLocationSourceId].
const String kUserLocationLayerId = 'mirkfall_user_location_layer';

/// Debounce window on viewport updates for the `CountryResolverController`.
/// 500 ms matches the `CountryResolver.resolveForViewportUpdates`
/// default; keeps continuous-gesture panning off the point-in-polygon
/// hot path.
const Duration kCountryResolverViewportDebounce = Duration(milliseconds: 500);

/// Debounce window for the `MapCameraController` pending-move flag.
/// Larger than MapLibre's own idle-emit latency (~200 ms) but small
/// enough that a subsequent user pan within the same second still
/// registers as user intent. Tuned for the Plan 07-06 hot path.
const Duration kMapCameraPendingMoveDebounce = Duration(milliseconds: 1000);

/// Relative path (under `<app_support>/`) for the download queue
/// persistence JSON used by `DownloadQueueStore`. Lives alongside the
/// installed manifest under `maps/`.
const String kDownloadQueueStorePath = 'maps/download_queue.json';

/// Timeout for the native disk-space MethodChannel invocation. 5 s is
/// conservative — `StatFs` (Android) and `attributesOfFileSystem` (iOS)
/// both complete in sub-millisecond on consumer hardware; a pending
/// call past 5 s signals a wedged native side. Lives here per
/// CLAUDE.md §Timeouts: "Valeurs dans `lib/config/constants.dart`,
/// pas hardcodées dans le code d'appel".
const Duration kDiskSpaceCheckTimeout = Duration(seconds: 5);

// ---------------------------------------------------------------------------
// Phase 09 — Fog Rendering (reveal geometry + flush cadence + atmospheric +
// candlelight + heavenly-clouds + solid defaults). Consumed by
// `RevealStreamingController`, `ActiveSessionController.startSession`, the
// 4 built-in `MirkRenderer` implementations (atmospheric / candlelight /
// heavenly_clouds / solid) and the Wave 7 50k-tile perf probe. See
// 09-CONTEXT.md §Géométrie du reveal + 09-RESEARCH.md.
//
// NOTE: `kRevealedTileParentZoom` is declared in the Phase 03 block above
// (line ~75) — Phase 09 reuses that constant rather than duplicating it.
// ---------------------------------------------------------------------------

/// Default reveal radius in metres around the user position. Consumed by
/// `RevealStreamingController` and `ActiveSessionController.startSession`.
/// Decided Phase 09 CONTEXT (user choice 25 m over the 25–50 m ROADMAP
/// range). Kept distinct from [kInitialRevealRadiusMeters] = 20 (Phase 07
/// session-open value) — both are intentional per CONTEXT.md §Géométrie
/// du reveal.
const double kDefaultRevealRadiusMeters = 25.0;

/// DB flush cadence — time bound. First of [kRevealFlushIntervalSeconds]
/// OR [kRevealFlushMaxFixes] triggers a batched `mergeMask` write.
/// Tuneable in dev per user decision Phase 09 CONTEXT (amended from
/// ROADMAP's 5 s / 50 fixes).
const int kRevealFlushIntervalSeconds = 2;

/// DB flush cadence — fix-count bound. See [kRevealFlushIntervalSeconds].
const int kRevealFlushMaxFixes = 20;

/// Baseline opacity of the atmospheric fog before noise modulation. User
/// tunes in dev — 0.99 leaves 1 % of the basemap barely visible, which
/// anticipates Phase 11's MARK-07 under-mirk marker alpha 30 % composite.
const double kDefaultMirkBaselineAlpha = 0.99;

/// Fade-in duration for the initial 20 m reveal at `startSession()`.
/// Dedicated AnimationController (NOT the main mirk Ticker) per
/// 09-RESEARCH §In-Session Style Swap Lifecycle. Consumed by the
/// `MirkInitialRevealFade` widget introduced in plan 09-07 Task 4.
const int kInitialRevealFadeInMs = 500;

/// Fraction of the reveal radius over which the feather edge fades from
/// 100 % opaque to 0 %. Rendered via `MaskFilter.blur(BlurStyle.inner)`
/// at paint time — the stored bitmap remains binary (MIRK-03 invariant).
const double kFeatherRadiusFraction = 0.1;

/// Simplex noise spatial frequency default for `AtmosphericMirkRenderer`.
/// User tunes in dev.
const double kMirkNoiseScaleDefault = 0.5;

/// Simplex noise time speed default for `AtmosphericMirkRenderer` (lower
/// = slower drift).
const double kMirkNoiseSpeedDefault = 0.05;

/// Drift direction of atmospheric noise in degrees (0 = north, 90 = east).
const double kMirkDriftDirectionDegDefault = 0.0;

/// Candlelight warm-glow centre colour (ARGB). Start value — tune in dev.
const int kMirkCandlelightCenterColorArgb = 0xFFFF8F6A;

/// Candlelight periphery colour (ARGB, darker orange).
const int kMirkCandlelightPeripheryColorArgb = 0xFFC2542E;

/// Candlelight noise scale — finer than atmospheric (flicker feel).
const double kMirkCandlelightNoiseScale = 0.8;

/// Candlelight noise speed — faster flicker.
const double kMirkCandlelightNoiseSpeed = 0.1;

/// Candlelight baseline alpha — lower than atmospheric (ambient lit feel).
const double kMirkCandlelightBaselineAlpha = 0.85;

/// Heavenly clouds baseline colour (ARGB, light grey-lavender).
const int kMirkHeavenlyCloudsColorArgb = 0xFFE8E8EE;

/// Heavenly clouds noise scale — very coarse (cloud blobs).
const double kMirkHeavenlyCloudsNoiseScale = 0.3;

/// Heavenly clouds noise speed — medium drift.
const double kMirkHeavenlyCloudsNoiseSpeed = 0.08;

/// Heavenly clouds drift direction in degrees (45° = NE, airy feel).
const double kMirkHeavenlyCloudsDriftDirectionDeg = 45.0;

/// Heavenly clouds baseline alpha — lighter than atmospheric.
const double kMirkHeavenlyCloudsBaselineAlpha = 0.80;

/// Solid variant colour (ARGB, very dark grey — distinguishable from
/// atmospheric yet neutral).
const int kMirkSolidColorArgb = 0xFF1A1A1A;
