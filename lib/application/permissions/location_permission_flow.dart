// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';
import 'package:mirkfall/domain/errors/location_permission_errors.dart';
import 'package:permission_handler/permission_handler.dart';

final Logger _log = Logger('application.permissions.location_permission_flow');

/// Signature of a function that requests a single platform [Permission]
/// and returns its [PermissionStatus].
///
/// Default is `(p) => p.request()` — the `permission_handler` shortcut
/// that internally calls the plugin's platform channel. Tests inject a
/// recording fake that captures every invocation and returns programmed
/// statuses (see `test/application/permissions/location_permission_flow_test.dart`).
typedef PermissionRequester = Future<PermissionStatus> Function(Permission permission);

/// Orchestrates the Android permission chain required for a GPS session :
/// `Permission.notification` -> `locationWhenInUse` -> `locationAlways`.
///
/// This is a pure top-level function, not a widget or service class —
/// single caller (Plan 05-04 PermissionRationaleScreen) and no state to
/// retain. Testable via the injected [requestPermission] seam without
/// relying on `PermissionHandlerPlatform` test channels.
///
/// **Why notification first?** Android 13+ (API 33+) requires
/// `POST_NOTIFICATIONS` at runtime for ANY app-posted notification —
/// including the one geolocator's foreground service shows while a
/// session is tracking. Without it, the manifest declaration alone is
/// not enough : the service still runs but the user sees no indicator.
/// We ask it FIRST so both dialogs appear back-to-back in the rationale
/// flow rather than one interrupting a session mid-walk. Denial does
/// NOT block location tracking — the outcome is still derived from the
/// location steps — but the UI will have to live without its indicator.
/// On Android < 13 and on iOS the call is a no-op (permission_handler
/// resolves instantly to `granted`).
///
/// **Why two location steps?** On Android 10 (API 29) and above,
/// requesting `Permission.locationAlways` without first obtaining
/// `Permission.locationWhenInUse` is silently ignored — the OS returns
/// `denied` without showing a prompt. The chain below requests
/// whenInUse first, checks the outcome, and ONLY THEN requests always.
/// The `neverRequestsAlwaysIfWhenInUseNotGrantedFirst` regression test
/// locks this invariant in.
///
/// Return values map to [LocationPermissionOutcome] :
/// - [LocationPermissionOutcome.granted] — full background tracking.
/// - [LocationPermissionOutcome.whileInUseOnly] — foreground-only.
///   User accepted whenInUse but declined always. UI should warn that
///   long sessions won't survive screen-off.
/// - [LocationPermissionOutcome.denied] — re-request allowed.
/// - [LocationPermissionOutcome.permanentlyDenied] — deep-link to
///   system settings required via [openLocationSettings].
Future<LocationPermissionOutcome> requestLocationAlways({PermissionRequester requestPermission = _defaultRequestPermission}) async {
  // Best-effort. Notification denial does not block the flow : the
  // session will track fine, only the persistent foreground notification
  // is missing. Exceptions from the plugin (very rare, typically only
  // on misconfigured test channels) are logged + swallowed so the
  // location cascade proceeds (CLAUDE.md §Error handling — no empty
  // catch; fine-level so production logs stay clean).
  try {
    await requestPermission(Permission.notification);
  } catch (e, st) {
    _log.fine('requestLocationAlways.notification_request_failed', e, st);
  }

  final whenInUse = await requestPermission(Permission.locationWhenInUse);
  if (whenInUse.isPermanentlyDenied) {
    return LocationPermissionOutcome.permanentlyDenied;
  }
  if (!whenInUse.isGranted) {
    return LocationPermissionOutcome.denied;
  }

  final always = await requestPermission(Permission.locationAlways);
  if (always.isGranted) {
    return LocationPermissionOutcome.granted;
  }
  if (always.isPermanentlyDenied) {
    return LocationPermissionOutcome.permanentlyDenied;
  }
  return LocationPermissionOutcome.whileInUseOnly;
}

/// Opens the system settings page for the app. Thin wrapper over
/// `permission_handler`'s top-level [openAppSettings] function so the
/// presentation layer does not import the plugin directly — keeps the
/// UI dependency graph symmetric with [requestLocationAlways].
///
/// Returns true if the settings page was opened successfully. Callers
/// should NOT rely on the return value to infer the outcome of the
/// user's actions there — re-check the permission status on resume
/// (Plan 05-04's WidgetsBindingObserver).
Future<bool> openLocationSettings() => openAppSettings();

/// Default [PermissionRequester] — delegates to `permission_handler`.
Future<PermissionStatus> _defaultRequestPermission(Permission permission) => permission.request();
