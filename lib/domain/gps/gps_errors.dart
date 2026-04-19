// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// Sealed hierarchy of GPS-domain exceptions propagated as stream errors
/// by [LocationStream] implementations and caught by upstream controllers.
///
/// All concrete variants `implement Exception` (CLAUDE.md §Error handling:
/// exceptions never extend `Error` — `Error` is reserved for programming
/// bugs). Marked `sealed` so downstream controllers can pattern-match over
/// every variant without an `is`-chain (CLAUDE.md §is-checks et polymorphisme).
sealed class GpsError implements Exception {
  const GpsError(this.message);

  /// Human-readable description; callers MAY log it but MUST NOT expose it
  /// verbatim in UI — UI strings live in the presentation layer (l10n-ready
  /// when Phase 14 adds localisation).
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Permission was denied (either non-permanently, re-prompt allowed; or
/// permanently, deep-link to system settings required — see [permanent]).
final class LocationPermissionDeniedException extends GpsError {
  const LocationPermissionDeniedException({this.permanent = false})
    : super(permanent ? 'Location permission permanently denied by user' : 'Location permission denied (can be re-requested)');

  /// True when the user has tapped "Don't ask again" / iOS equivalent.
  /// UI must send them to system settings rather than re-prompting.
  final bool permanent;
}

/// Device-wide location services are disabled (airplane mode, system
/// toggle off). Distinct from [LocationPermissionDeniedException] — the app
/// can hold permission yet still hit this state.
final class LocationServiceDisabledException extends GpsError {
  const LocationServiceDisabledException() : super('Device location service is disabled');
}

/// Background tracking was killed by the OS (Android battery killer, iOS
/// memory pressure). Plan 05-06 turns this into a "tap to resume" local
/// notification; the domain models the event so controllers can decide
/// whether to show a re-auth-style warning.
final class TrackingBackgroundKilledException extends GpsError {
  const TrackingBackgroundKilledException() : super('Background tracking was killed by the OS');
}
