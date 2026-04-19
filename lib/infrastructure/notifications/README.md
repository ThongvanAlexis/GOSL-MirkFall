# lib/infrastructure/notifications/

Wrappers around `flutter_local_notifications` for the Phase 05 session
lifecycle.

## Contents

- `session_notification_service.dart` — idempotent channel
  initialisation + "tap to resume" notification emission. The ACTIVE
  tracking notification itself is emitted by geolocator's
  `ForegroundNotificationConfig`; this service guarantees the channel
  exists AND owns the resume-notification lifecycle used by Plan
  05-06 (`BOOT_COMPLETED` watchdog on Android, significant-change
  watchdog on iOS).

## Imports

Allowed:
- `package:flutter_local_notifications/` (pinned, audited in
  DEPENDENCIES.md).
- `lib/config/constants.dart` (channel id).
- `lib/domain/ids/session_id.dart` (payload encoding).

Forbidden:
- Network / analytics packages.
- `dart:io` (the service stays platform-neutral; platform branching
  happens inside `flutter_local_notifications`).
