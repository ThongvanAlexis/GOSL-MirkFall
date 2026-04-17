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

// Reserved for later phases (declared here so future callers can import from
// a stable location):
//   - kDefaultRevealRadiusMeters  (Phase 09 — fog reveal radius)
//   - kHttpTimeout                (Phase 07 — tile fetch timeout)
//   - kMarkerPhotoMaxDimension    (Phase 11 — photo downscale cap)
