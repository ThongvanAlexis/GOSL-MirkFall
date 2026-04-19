// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Result of a two-step location-permission flow (see Plan 05-03).
///
/// Used by `requestLocationAlways()` in `lib/application/permissions/` (Plan
/// 05-03) to signal to the UI which branch to render: session start, OEM
/// guidance, whileInUse warning, or open-system-settings deep-link.
///
/// Distinct from [`GpsError`](gps_errors.dart) — those are STREAM errors that
/// fire DURING tracking; this enum models the RESULT of an up-front permission
/// request before any stream is opened.
enum LocationPermissionOutcome {
  /// Always-on permission granted — full background tracking available.
  granted,

  /// Foreground-only permission granted. Background tracking will not
  /// survive screen-off > ~30 s on Android, or terminates on iOS. The UI
  /// must warn the user that long sessions will not persist while the app
  /// is backgrounded.
  whileInUseOnly,

  /// User tapped Deny. Re-request allowed on the next attempt (the OS will
  /// still show the dialog).
  denied,

  /// User tapped "Don't ask again" (Android) or denied twice (iOS). The OS
  /// will no longer show the dialog; UI must deep-link to system settings.
  permanentlyDenied,
}
