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

// FileLogger flush cadence constants removed 2026-04-26 (BUG-009 follow-up).
// The hybrid flush policy (every-N records + periodic timer + lifecycle +
// shout) was a workaround for an [IOSink]-based sink whose `flush()` only
// drained user-space → kernel page cache (jettisoned by iOS jetsam under
// foreground RAM pressure during the 5.2 GB pmtiles install). The sink also
// suffered an `async` re-entrancy race against `Stream.listen` (which does
// not await `async` callbacks) → `StateError` on concurrent flushes →
// silent log loss for the rest of the session.
//
// FileLogger now writes via [RandomAccessFile.writeStringSync] +
// [RandomAccessFile.flushSync] (real `fsync(2)` per Dart docs) on every
// record from a synchronous handler. No buffer, no race, no durability
// gap. The cadence threshold + periodic backstop timer are therefore
// redundant and have been removed.

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

/// WGS-84 mean Earth radius in metres (per IUGG). Single source of truth
/// for great-circle distance maths across the revealed-domain code
/// (`reveal_calculator.dart`, `reveal_disc.dart`,
/// `revealed_sdf_builder.dart`). Promoted to a public constant when the
/// SDF builder became the third call site — at three callers the
/// file-private duplication started to feel like a "watch out, did anyone
/// nudge one of the three" hazard. Anything that wants Haversine over
/// short ground distances should reuse this value rather than re-deriving.
const double kEarthRadiusMeters = 6371008.8;

/// Approximate metres per degree of latitude (WGS-84, equator-aligned).
/// Constant globally because a meridian is a great circle — accurate to
/// ~0.5 % at any latitude. Used both by the cell-rasterisation
/// `computeRevealMask` (`reveal_calculator.dart`) and by the analytic
/// `RevealedSdfBuilder.buildFromDiscs` to convert metres ↔ degrees ↔
/// pixel space. Promoted at the same time as [kEarthRadiusMeters] for
/// the same "third call site" reason.
const double kMetersPerDegreeLat = 111320.0;

/// Tolerance (fraction of the larger disc's radius) applied by the
/// offline `RevealedDiscStore.compactSession` containment check. A disc
/// `A` is dropped when another disc `B` of the same session satisfies
/// `B.distanceMetersTo(A.lat, A.lon) + A.radiusMeters <=
///   B.radiusMeters * (1 + kRevealedDiscCompactionContainmentTolerance)`.
/// 5 % keeps the union of revealed area effectively unchanged (the slop
/// is below GPS accuracy at the 25 m default radius) while collapsing
/// stationary GPS-jitter clusters to a single disc. Hoisted as a constant
/// so a future tuner change has one source of truth.
const double kRevealedDiscCompactionContainmentTolerance = 0.05;

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

// =============== Phase 09 BUG-009 — fog visual (TIER 2) ===============
//
// Tunables for the volumetric-feeling fog shader pipeline introduced
// in BUG-009 fix. The shader (`assets/shaders/atmospheric_fog.frag`)
// reads these values via uniforms set Dart-side; renderers
// (atmospheric / heavenly_clouds) pass different subsets so the same
// `.frag` produces both palettes.
//
// Each tunable is grouped with the property it controls so a future
// debug-menu phase can wrap clusters into named `FogConfig` notifiers
// without re-classifying constants. NAMING: `kMirkFogXxx` prefix +
// `Atmospheric` / `Heavenly` qualifier where the variants diverge.
//
// Palette (Northern atlas indigo — research v2 Reference 11 / palette A):
//   - Atmospheric uses the cool indigo set (mystic, cartographic).
//   - Heavenly uses a lighter, cooler-sky variant (airy, daytime).

/// Atmospheric base fog colour (ARGB). Cool desaturated indigo,
/// reads cartographic-mystic over both light and dark OSM tiles.
/// Component R/G/B unpacked Dart-side and passed as `vec4` uniform.
const int kMirkFogAtmosphericBaseColorArgb = 0xFF3A4358;

/// Atmospheric highlight colour — what bright, sun-facing fog regions
/// shade towards. Used by the faux-shading delta (sample twice, brighten
/// the lighter side). Lighter blue-grey of the indigo palette.
const int kMirkFogAtmosphericHighlightColorArgb = 0xFF7C8AA3;

/// Atmospheric shadow colour — what dim, sun-shadowed fog regions
/// shade towards. Darker indigo end of the same palette.
const int kMirkFogAtmosphericShadowColorArgb = 0xFF1E2536;

/// Heavenly clouds base colour. Light dawn-grey with a slight warm
/// touch (Hebridean dawn split — research v2 palette B).
const int kMirkFogHeavenlyBaseColorArgb = 0xFFA8B5C4;

/// Heavenly clouds highlight — warm cream sun-side accent.
const int kMirkFogHeavenlyHighlightColorArgb = 0xFFE8DCC8;

/// Heavenly clouds shadow — cool grey-blue away-from-sun accent.
const int kMirkFogHeavenlyShadowColorArgb = 0xFF5D6878;

// Drift speeds — multi-rate motion (Reference 12). Three octaves at
// three speeds. The SLOWEST layer dominates bulk drift, the FASTEST
// surface boil. Pure z-axis (time) drift is what "kills the linear
// slide" perception per shader-techniques T6.

/// Z-axis (time-slice) drift speed for the FAR/coarse octave of 3D-FBM.
/// Lower values → noise morphs more slowly. Atmospheric is meant to feel
/// thick and lazy, so the values stay low.
///
/// 2026-04-26: bumped 0.018 → 0.07 (~4×) after BUG-009 UAT walk #N
/// confirmed pipeline + uniforms healthy but visible motion below the
/// perceptual threshold. Far octave drives ~55% of the visible signal
/// (kMirkFogOpacityFar) so its drift dominates the "is this animating"
/// reading.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogAtmosphericDriftZFar = 0.23;

/// Z-axis drift speed for the MID octave. Slightly faster than far so
/// the layers don't track in lockstep.
///
/// 2026-04-26: bumped 0.035 → 0.15 (~4×) — see DriftZFar comment.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogAtmosphericDriftZMid = 0.24;

/// Z-axis drift speed for the NEAR/fine octave (surface boil). Fastest
/// — this is where the eye reads "alive".
///
/// 2026-04-26: bumped 0.075 → 0.30 (4×) — see DriftZFar comment.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogAtmosphericDriftZNear = 0.23;

/// Heavenly clouds far-octave drift. Heavenly reads as "thinner, faster
/// clouds" so all three octaves are uniformly faster.
///
/// 2026-04-26: bumped proportionally with atmospheric (~4×) so the
/// heavenly-vs-atmospheric speed gap stays consistent.
const double kMirkFogHeavenlyDriftZFar = 0.11;

/// Heavenly mid-octave drift.
const double kMirkFogHeavenlyDriftZMid = 0.24;

/// Heavenly near-octave drift.
const double kMirkFogHeavenlyDriftZNear = 0.46;

// Noise scales — spatial frequency per octave. Larger = finer detail.
// Layer ratios chosen to read as parallax depth (Reference 3 — Ventusky
// three-altitude trick). Atmospheric and heavenly share the same ratios
// for now — only the absolute scales differ.

/// Spatial scale of the FAR/coarse 3D-FBM octave. Big lazy blobs.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogAtmosphericScaleFar = 2.9;

/// Spatial scale of the MID octave. Mid-frequency detail.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogAtmosphericScaleMid = 5.1;

/// Spatial scale of the NEAR/fine octave. Fine surface texture.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogAtmosphericScaleNear = 10.5;

/// Heavenly far-octave scale. Heavenly clouds are smaller "puffs" than
/// the atmospheric mass, so the near scale is finer.
const double kMirkFogHeavenlyScaleFar = 0.8;

const double kMirkFogHeavenlyScaleMid = 1.8;

const double kMirkFogHeavenlyScaleNear = 3.6;

// Per-octave opacities — sum to ~1.0. The far octave dominates the
// silhouette; the near octave is a high-frequency boil layer.

/// Far-octave weight in the final density mix. Largest contributor —
/// gives the fog its bulk shape.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogOpacityFar = 0.58;

/// Mid-octave weight.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogOpacityMid = 0.58;

/// Near-octave weight. Smallest contributor; rides as detail on top.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogOpacityNear = 0.58;

// Curl-noise advection — how much each octave warps in 2D from a
// curl-of-scalar-noise vector field (Reference 7).

/// Curl-noise warp amplitude (in noise UV units). Higher = more
/// pronounced eddies and swirls. Bumped 2026-04-25 from 0.18 → 0.45
/// (BUG-009 follow-up) — initial value was too conservative: at 0.18
/// the swirling motion was visually invisible and the user reported
/// "ressemble juste à un truc semi-transparent". 0.45 gives clearly
/// visible eddies while still preserving the far-octave silhouette.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogCurlAmplitude = 1.0;

/// Spatial frequency of the curl-noise potential field. Lower → bigger
/// vortices. Tied to `kMirkFogAtmosphericScaleMid` so eddies live at the
/// mid-octave scale (where they read most as "stirred fluid").
///
/// NOTE: this is the STATIC fallback used only when
/// [MirkRuntimeTunables.curlScaleAnimationEnabled] is false. By default
/// the renderers animate curlScale as a triangle wave (0..10 over 20s)
/// to give the fog a "really alive" volumetric feel — the static value
/// here is therefore the off-state baseline, not the typical runtime
/// value (see commit 3 of the 2026-04-26 baking pass).
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogCurlScale = 0.8;

/// Default state of the curlScale auto-animation. The 2026-04-26 UAT
/// walk concluded that the slowly varying curlScale produces a
/// significantly more "alive" volumetric look than any static value, so
/// the animation is on by default. The dev tuner exposes a toggle to
/// fall back to the static [kMirkFogCurlScale] when needed.
const bool kMirkFogCurlScaleAnimationDefaultEnabled = true;

/// Full period (seconds) of the curlScale triangle-wave animation. 60 s
/// = `0 → 4 → 0` once every 60 seconds (30 s up, 30 s down). UAT walk
/// 2026-04-26 (N+2) preferred an even slower cadence than the prior
/// 40 s — the 60 s period reads as ambient breathing rather than active
/// motion, which is the desired "alive but calm" volumetric feel.
const double kMirkFogCurlScaleAnimationPeriodSec = 40.0;

/// Minimum value of the curlScale triangle-wave animation. 0.0 is the
/// "no curl noise warp at all" extremum — paired with
/// [kMirkFogCurlAmplitude] the fog momentarily flattens into pure
/// FBM-density before swelling back into the fully-warped state.
const double kMirkFogCurlScaleAnimationMin = 0.0;

/// Maximum value of the curlScale triangle-wave animation. 4.0 — UAT
/// walk 2026-04-26 (N+1): the previous 10.0 ceiling produced visible
/// "boil-over" artefacts at apex; 4.0 keeps the warp inside the
/// eye-pleasing range while still reading as actively swirling.
const double kMirkFogCurlScaleAnimationMax = 4.0;

// Faux directional shading — the single highest-leverage trick for
// "feels volumetric" (Reference 6 + 10). Sample density at the pixel
// AND at `pixel + lightDir * offset`. The delta modulates brightness.

/// Faux-light direction (radians, 0 = +x). Slightly off-axis so the
/// shading reads as "sun from upper-left" rather than dead-on. Standard
/// cartographic NW-light convention (~135° clockwise-from-north → in
/// math coords ~-45°).
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogLightDirRadians = -1.11;

/// Distance (in noise UV units) offset between the two density samples
/// for faux shading. Roughly equivalent to "screen px" at the shader's
/// typical UV scale. Bumped 2026-04-25 from 0.04 → 0.12 (BUG-009
/// follow-up) — too small a step landed both samples inside the same
/// noise cell, so the delta was always near zero and the fake-shading
/// contributed nothing visible.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogLightOffset = 0.46;

/// Strength of the faux-shading brightness modulation. 0 = no effect,
/// 1 = sample-delta fully drives lightness. Bumped 2026-04-25 from
/// 0.55 → 1.4 (BUG-009 follow-up) — combined with the wider light
/// offset above, this is what produces visible bright/dark sides on
/// the fog mass. Values >1.0 are intentional: shadeDelta is small in
/// absolute terms (delta of two normalised noise samples), so the
/// strength multiplier needs headroom to actually move the colour.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogLightStrength = 1.67;

// Sub-grey hue variation — second cheap noise channel modulates a tint
// shift (Reference 5 NASA SVS multi-channel encoding).

/// Spatial scale of the hue-variation noise. Coarser than the density
/// noise so tint regions are bigger than density blobs.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogHueNoiseScale = 1.6;

/// Strength of the hue tint. 0 = pure grey, 1 = pull fully toward the
/// base palette colour. Bumped 2026-04-25 from 0.35 → 0.7 (BUG-009
/// follow-up) — at 0.35 the tint shift was inside JPEG-compression
/// noise on most screens. 0.7 produces a clear "warmer in valleys,
/// cooler on ridges" reading without rainbowing.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogHueStrength = 0.44;

// Two-stop watercolour boundary — sharp inner gradient + long-tail
// bleed (Reference 11 Heaven's Vault inspiration).
//
// SDF semantics in the shader: signed distance, normalised to [-1, 1].
// Negative inside revealed area, positive inside fog area. The boundary
// is at sdf = 0.

/// Distance (SDF units) over which the SHARP inner gradient ramps from
/// 0 to 0.7 alpha. Small → crisp watercolour core.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogBoundarySharpDistance = 0.04;

/// Distance over which the LONG-TAIL bleed ramps from 0.7 to 1.0 alpha.
/// Several times the sharp distance — the trailing watercolour fade.
///
/// 2026-04-26 (BUG-009 follow-up): restored to 0.12 after the previous bake
/// at 0.0 collapsed the second smoothstep into a hard step, producing a
/// stark white-ish edge where the alpha jumped 0.7 → 1.0 in one pixel.
/// The long-tail smoothstep was specifically designed to hide the SDF's
/// 8-bit quantisation steps; zeroing it defeats the design AND surfaces
/// concentric "rings of light" the user reported on the UAT walk. The
/// restored value gives a soft halo of ~12% of the SDF range — visible
/// watercolour fade, no hard line.
const double kMirkFogBoundaryBleedDistance = 0.12;

/// Width (SDF units) of the curl-rotated edge field. Within this band
/// of the fog/clear boundary the curl-noise sample is rotated ~90° so
/// wisps appear to spiral outward from the boundary instead of through
/// it.
// 2026-04-26: baked from live tuner walk N+M
const double kMirkFogBoundaryEdgeBand = 0.17;

/// "Watercolour pigment pool" boost — multiplier applied to the fog
/// density immediately INSIDE the boundary bleed band so the nearby fog
/// reads as visibly thicker along the inside edge of the revealed area
/// (like watercolour pigment pooling at the perimeter of a wash).
///
/// 0.0 = no boost (fog density flat across boundary). 0.15 = +15% along
/// the boundary tapering smoothly to 0% at `uBoundaryBleedDistance` away.
/// Range guidance for the tuner: [0.0, 0.5]. Higher values produce a
/// pronounced halo; default is the subtle "fog reacting to the boundary"
/// look the user asked for in BUG-009 follow-up walk #N+2.
///
/// Implementation lives in `assets/shaders/atmospheric_fog.frag` —
/// modulates `density` (NOT `fogColor`) so the boost reads as more fog
/// rather than a stark colour change.
const double kMirkFogBoundaryDensityBoost = 0.15;

/// Resolution (square) of the CPU-built SDF texture passed to the
/// shader as `sampler2D`. 256² is a good cost/quality balance — the
/// SDF is rebuilt only when revealed cells change (user walks),
/// not every frame.
const int kMirkFogSdfResolution = 256;

// CPU wisp particle system — discrete tendrils spawned at the boundary
// when the user walks (Reference 1 + 9).

/// Hard cap on simultaneously alive wisp particles. LRU-evicted when
/// `life <= 0`. ~200 is invisible cost on any 2026 mobile GPU and
/// dense enough that the eye latches onto motion.
const int kMirkFogWispMaxCount = 200;

/// Wisp particles spawned per newly-revealed cell event. The user
/// walking 1 step typically reveals 3-5 cells; multiplying by this
/// value gives a comfortable spawn rate without flooding the cap.
const int kMirkFogWispSpawnPerCell = 2;

/// Wisp lifetime in seconds. After this the particle is evicted.
/// Long enough that the user perceives a deliberate trail, short
/// enough that the cap rotation feels organic.
const double kMirkFogWispLifeSeconds = 2.5;

/// Wisp initial velocity magnitude (in screen pixels per second).
/// Slow drift — wisps are cinematic, not bullet trails.
const double kMirkFogWispInitialSpeedPx = 18.0;

/// Wisp size at birth in screen pixels. Each wisp is rendered as an
/// additive-blended soft circle.
const double kMirkFogWispBirthRadiusPx = 6.0;

/// Wisp size at death (extrapolated linearly with life). Wisps grow
/// as they fade — final size larger than birth gives the "puff
/// dispersing" reading.
const double kMirkFogWispDeathRadiusPx = 22.0;

/// Wisp peak alpha (0..1). Clamps the additive contribution so a stack
/// of wisps doesn't bleach the fog underneath. 0.35 is a comfortable
/// non-overwhelming peak.
const double kMirkFogWispPeakAlpha = 0.35;

/// DIAGNOSTIC TOGGLE (BUG-009 follow-up, 2026-04-25). When true, the
/// atmospheric fog shader replaces its final colour mix with a raw
/// density visualisation: `fragColor = vec4(dN, dN, dN, 1.0)` where dN
/// is the normalised post-FBM density driving the highlight↔shadow lerp.
///
/// Why this exists: the previous BUG-009 round bumped the curl/light/hue
/// constants but the user reports the fog body still looks uniformly
/// indigo with no volumetric variation. Two possible root causes:
///   (a) noise IS varying spatially but the colour-mix math collapses it
///   (b) noise ISN'T varying — uTime stuck, uniforms not propagating, or
///       the FBM sum is degenerate
/// Flipping this toggle to true and rebuilding gives the answer on
/// device: if dN reads as a clear noise pattern → (a) — colour math is
/// the bottleneck. If dN reads uniform → (b) — fix the noise pipeline.
///
/// IMPORTANT: this Dart constant is the source of truth for the project,
/// but GLSL cannot read Dart constants. The shader carries a paired
/// `#define MIRK_FOG_DEBUG_OUTPUT_DENSITY` block that must be flipped
/// in lockstep — see `assets/shaders/atmospheric_fog.frag` near the top
/// of `main()`. A future cleanup could route this through a uniform
/// (1 float, 0/1) but that costs an extra branch per fragment for a
/// dev-only toggle, so the inline `#define` is the right tool today.
///
/// Default: false (production output).
const bool kMirkFogDebugOutputDensity = false;

/// SharedPreferences key for the user-facing fog density slider exposed
/// in the session burger menu. Single double in `[kMirkFogOpacityMin,
/// kMirkFogOpacityMax]` — slider drag writes all three opacity octaves
/// (`MirkRuntimeTunables.opacity{Far,Mid,Near}`) to this value, which
/// in turn is persisted under this key. Read at app boot in `main.dart`
/// so the user's choice survives across launches.
const String kMirkFogOpacityPrefsKey = 'mirk_fog_opacity';

/// Inclusive lower bound of the user-facing fog density slider. 0.2 is
/// the floor where the fog reads as "thin haze with the basemap clearly
/// visible underneath" — below this the fog effectively disappears,
/// defeating the purpose of the user-facing control.
const double kMirkFogOpacityMin = 0.2;

/// Inclusive upper bound of the user-facing fog density slider. 1.0 is
/// the natural cap (fully opaque per octave). The render still respects
/// any palette alpha modulations on top of this — the slider drives the
/// noise-driven octave weights, not the final canvas alpha.
const double kMirkFogOpacityMax = 1.0;

/// Number of slider divisions for the user-facing fog density slider.
/// 16 divisions over `[0.2 .. 1.0]` = 0.05 step, coarse enough for an
/// end-user UX (the dev tuner exposes per-octave continuous sliders
/// for fine adjustment).
const int kMirkFogOpacitySliderDivisions = 16;
