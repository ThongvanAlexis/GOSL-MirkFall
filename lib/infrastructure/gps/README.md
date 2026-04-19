# lib/infrastructure/gps/

Platform-facing GPS plumbing: the geolocator-backed `LocationStream`
implementation and the platform-branching `LocationSettings` factory.

## Contents

- `location_settings_factory.dart` — pure function `buildLocationSettings`
  returning `AndroidSettings` (foreground-service + wake lock),
  `AppleSettings` (background mode + fitness activity type), or plain
  `LocationSettings` on desktop.
- `geolocator_location_stream.dart` — `GeolocatorLocationStream`
  implements `lib/domain/gps/location_stream.dart`. Maps `Position` to
  domain `Fix`, applies accuracy + stationary-dedup filtering, translates
  platform errors to the `GpsError` sealed hierarchy.

## Seams

- `PositionStreamFactory` typedef in `geolocator_location_stream.dart`
  lets tests drive the pipeline with a `StreamController` instead of the
  static `Geolocator.getPositionStream`.

## Imports

Allowed:
- `package:geolocator/`, `package:geolocator_android/`,
  `package:geolocator_apple/` — infrastructure layer, not domain.
- `package:flutter/foundation.dart` for `defaultTargetPlatform`.
- Domain ports under `lib/domain/gps/` and `lib/domain/fixes/`.

Forbidden:
- UI / presentation packages (`package:flutter/material.dart` etc.).
- Any network or telemetry library (none are pinned — GOSL policy).
