# lib/domain/gps/

Pure-Dart domain layer for GPS stream + typed error propagation. No
`package:flutter` / `package:drift` / `package:geolocator` imports
(enforced by `tool/check_domain_purity.dart`).

## Contents

- `location_stream.dart` — abstract `LocationStream` port (returns a
  `Stream<Fix>` tagged with a `SessionId`). Implementation in
  `lib/infrastructure/gps/geolocator_location_stream.dart`.
- `gps_errors.dart` — sealed `GpsError` hierarchy (permission denied,
  service disabled, background killed). Consumed by the application-layer
  `ActiveSessionController` (Plan 05-03) via pattern match.

## Imports

Allowed:
- `../fixes/fix.dart`
- `../ids/session_id.dart`

Forbidden (enforced by `tool/check_domain_purity.dart`):
- `package:flutter/`
- `package:drift/`, `package:drift_flutter/`
- `package:geolocator/` (platform impl only)
