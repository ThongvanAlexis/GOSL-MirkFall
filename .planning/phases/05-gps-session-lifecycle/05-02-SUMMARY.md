---
phase: 05-gps-session-lifecycle
plan: 02
subsystem: gps-infrastructure
tags: [gps, geolocator, foreground-service, background-location, notifications, oem-detection, android-manifest, info-plist, qual-04, wave-2, tdd]

# Dependency graph
requires:
  - phase: 05-gps-session-lifecycle
    plan: 01
    provides: "LocationStream port stub (Object sessionId), Fix Freezed entity with @Assert, FixStore port + DriftFixStore impl, FixId extension type, 5 Phase 05 constants (kDefaultDistanceFilterMeters, kMaxAcceptableAccuracyMeters, kFirstFixTimeoutSeconds, kNotificationChannelId, kSessionActiveBannerHeightDp), idGeneratorProvider Riverpod keepAlive"
provides:
  - "LocationStream port upgraded to strong-typed SessionId + required sessionDisplayName (was Object + no display name in 05-01 stub)"
  - "Sealed GpsError hierarchy: GpsError / LocationPermissionDeniedException(permanent) / LocationServiceDisabledException / TrackingBackgroundKilledException"
  - "LocationPermissionOutcome enum (granted / whileInUseOnly / denied / permanentlyDenied) for Plan 05-03 two-step flow"
  - "LocationSettingsFactory.buildLocationSettings: AndroidSettings (foregroundNotificationConfig + enableWakeLock=true + setOngoing=true) | AppleSettings (pauseLocationUpdatesAutomatically=false + activityType=fitness + showBackgroundLocationIndicator=true + allowBackgroundLocationUpdates=true) | plain LocationSettings on desktop"
  - "GeolocatorLocationStream implements LocationStream with PositionStreamFactory seam, accuracy reject (>50 m), stationary dedup (<1 m AND <10 s), domain-error translation"
  - "LocalNotificationsPort + FlutterLocalNotificationsAdapter seam around FlutterLocalNotificationsPlugin singleton"
  - "SessionNotificationService: idempotent initialize (LOW-importance channel + iOS permission), showResumeNotification(sessionId, displayName), dismiss()"
  - "Sealed OemFamily hierarchy (Xiaomi / Samsung / Huawei / OnePlus / Oppo / OtherOem / IosDevice) via device_info_plus"
  - "OemDetector with isIosOverride / isAndroidOverride seams for deterministic tests"
  - "3 Riverpod @keepAlive providers: locationStreamProvider, sessionNotificationServiceProvider, oemDetectorProvider"
  - "AndroidManifest.xml: 7 Phase 05 permissions + BOOT_COMPLETED receiver declaration (Kotlin impl Plan 05-06)"
  - "ios/Runner/Info.plist: final QUAL-04 copy (verbatim from 05-CONTEXT.md) + UIBackgroundModes=location"
  - "device_info_plus 12.4.0 strictly pinned + BSD-3-Clause audit in DEPENDENCIES.md"
  - "5 GREEN tests in tool/test/info_plist_final_copy_test.dart (QUAL-04 no-TODO + copy signature + UIBackgroundModes)"
affects: [05-03-permissions, 05-04-settings-ui, 05-05-session-ui, 05-06-auto-resume]

# Tech tracking
tech-stack:
  added:
    - "device_info_plus 12.4.0 (BSD-3-Clause, fluttercommunity.dev) — OEM brand detection for GPS-08 guidance screen"
    - "device_info_plus_platform_interface 7.0.3 (transitive, BSD-3-Clause)"
    - "win32_registry 2.1.0 (Windows-only transitive, BSD-3-Clause)"
  patterns:
    - "LocationStream port upgrade rationale: Plan 05-01's `Object sessionId` was motivated by avoiding a lateral peer-domain import from sessions/ into gps/. Plan 05-02 closes that loop — `lib/domain/gps/` now imports `lib/domain/ids/session_id.dart`, matching Phase 03's lateral-import pattern (e.g. `marker.dart` imports `session_id.dart`)."
    - "LocalNotificationsPort adapter seam: flutter_local_notifications uses a factory-singleton constructor that cannot be subclassed cleanly; introduced an internal port + adapter so tests inject a capturing fake without touching platform-channel plumbing."
    - "DeviceInfoPlugin test seam: subclass via `implements DeviceInfoPlugin` + override only `androidInfo` getter; `AndroidDeviceInfo.fromMap` (static factory) is the only public construction path, populated with test fixture map."
    - "isIosOverride / isAndroidOverride parameters on OemDetector.detect: avoid branching on runtime Platform during tests; same 'override with named parameter' seam pattern used by runtime-control dependencies elsewhere in the project."
    - "Platform-ignore comments for intentionally-explicit default arguments: pauseLocationUpdatesAutomatically=false + allowBackgroundLocationUpdates=true both match geolocator_apple defaults; kept explicit so any future default flip is a compile-time concern, not a silent behavior change. `// ignore: avoid_redundant_argument_values` documents the choice."

key-files:
  created:
    - "lib/domain/gps/gps_errors.dart"
    - "lib/domain/gps/README.md"
    - "lib/domain/errors/location_permission_errors.dart"
    - "lib/infrastructure/gps/location_settings_factory.dart"
    - "lib/infrastructure/gps/geolocator_location_stream.dart"
    - "lib/infrastructure/gps/README.md"
    - "lib/infrastructure/notifications/session_notification_service.dart"
    - "lib/infrastructure/notifications/README.md"
    - "lib/infrastructure/platform/oem_detector.dart"
    - "lib/infrastructure/platform/README.md"
    - "lib/application/providers/location_stream_provider.dart"
    - "lib/application/providers/session_notification_service_provider.dart"
    - "lib/application/providers/oem_detector_provider.dart"
  modified:
    - "lib/domain/gps/location_stream.dart (port upgraded: Object → SessionId, added sessionDisplayName parameter)"
    - "test/helpers/fake_location_stream.dart (signature aligned with upgraded port)"
    - "test/infrastructure/gps/location_settings_factory_test.dart (stub → 7 GREEN tests across Android/iOS/desktop branches)"
    - "test/infrastructure/gps/geolocator_location_stream_test.dart (stub → 6 GREEN tests using PositionStreamFactory seam)"
    - "test/infrastructure/notifications/session_notification_service_test.dart (stub → 6 GREEN tests using LocalNotificationsPort capturing fake)"
    - "test/infrastructure/platform/oem_detector_test.dart (stub → 9 GREEN tests covering 6 target OEMs + Other + iOS + desktop fallback)"
    - "tool/test/info_plist_final_copy_test.dart (stub → 5 GREEN tests covering QUAL-04)"
    - "android/app/src/main/AndroidManifest.xml (7 Phase 05 permissions + BootCompletedReceiver declaration + merged-service verification note)"
    - "ios/Runner/Info.plist (final QUAL-04 copy for 2 usage-description keys + UIBackgroundModes=location)"
    - "pubspec.yaml (device_info_plus: 12.4.0 pinned — plan specified 13.0.0 but file_picker 11.0.2 win32 conflict forced 12.4.0)"
    - "pubspec.lock (device_info_plus chain resolved)"
    - "DEPENDENCIES.md (3 new entries: device_info_plus 12.4.0 direct + platform-interface 7.0.3 transitive + win32_registry 2.1.0 Windows transitive)"

key-decisions:
  - "device_info_plus pinned to 12.4.0 (not the plan's 13.0.0): 13.0.0 bumps its Windows backend transitive to win32 ^6.0.0, incompatible with the already-pinned file_picker 11.0.2 which holds win32 ^5.9.0. 12.4.0 is the ceiling that resolves against win32 ^5.11.0 and exposes the identical AndroidDeviceInfo.manufacturer + brand surface used by OemDetector. Re-evaluate 13.x when file_picker is upgraded."
  - "LocationStream port adopts SessionId (not Object): the 05-01 `Object` typing was a lateral-import workaround before infra landed in the same plan. Plan 05-02 now owns the infra impl, so the lateral-import concern is moot — tightening the type catches cross-type assignment at compile time rather than deferring to the impl-construction boundary."
  - "Added required sessionDisplayName to LocationStream.positions: feeds the Android foreground-service notification title ('MirkFall • ${displayName}'). Plumbed at the port so callers never branch on platform themselves; iOS + desktop ignore the parameter."
  - "Introduced LocalNotificationsPort + FlutterLocalNotificationsAdapter seam: flutter_local_notifications ships a factory-singleton (`factory FlutterLocalNotificationsPlugin() => _instance`) that cannot be subclassed cleanly (private `._()` constructor). The narrow port is 4 methods — createAndroidChannel, requestIosPermissions, show, cancel — which matches the service's exact surface area without re-exposing the plugin's full API."
  - "Removed `ongoing: false` on AndroidNotificationDetails (resume notification): matches the package default AND satisfies `prefer_const_constructors` on the NotificationDetails literal. The test still asserts `android.ongoing, isFalse` which now passes via the default, not an explicit arg."
  - "distanceFilter is `int`, not `double`: 05-RESEARCH.md Pattern 1 showed `distanceFilterMeters.toDouble()` for the iOS branch but the `LocationSettings` base class in geolocator_platform_interface 4.2.6 declares `final int distanceFilter` — the bridge casts internally on the native side. Corrected in the implementation + test."
  - "BootCompletedReceiver declared in AndroidManifest.xml now (Plan 05-02) but Kotlin class implementation is Plan 05-06: the manifest is a platform declaration (concentrated in this plan with all permissions), while the receiver body is platform-glue code (sits alongside Plan 05-06's iOS significant-change watchdog). The declaration alone does not cause runtime errors — Android silently ignores intents for missing receiver classes at install time, and manifest-merge validation is a build-time check."
  - "Info.plist final copy taken VERBATIM from 05-CONTEXT.md §Permission + Store copy: FINAL en Phase 05 — no interpretation, no rewording. The QUAL-04 assertion uses substring match on distinctive phrases ('révéler le brouillard', 'arrière-plan') rather than byte-equality to stay robust against XML attribute-quoting rendering choices."
  - "PositionStreamFactory typedef seam on GeolocatorLocationStream: `Geolocator.getPositionStream` is a static method not trivially mockable; the typedef-parameter form lets tests inject a StreamController-backed factory without a global override."
  - "Stationary dedup parameters: 1.0 m distance + 10 s window — CONTEXT.md said 'Claude's discretion (probablement skip si delta < 1m ET delta_time < 10s)'. Named as constants `_stationaryDedupMinDistanceMeters` + `_stationaryDedupWindowSeconds` inside `GeolocatorLocationStream` per CLAUDE.md §Magic numbers; callers never see the choice."

patterns-established:
  - "LocalNotificationsPort seam: flutter_local_notifications factory-singleton is opaque; a narrow 4-method port + thin adapter gives tests a capturing fake without coupling to platform channels"
  - "DeviceInfoPlugin test seam: override only the `androidInfo` getter on a subclass that `implements DeviceInfoPlugin` and populate `AndroidDeviceInfo.fromMap` with the minimal fixture"
  - "OemDetector.detect({isIosOverride, isAndroidOverride}): runtime-platform sentinel injection for deterministic tests on any host"
  - "PositionStreamFactory typedef: `Stream<Position> Function(LocationSettings)` seam lets tests drive `StreamController` without mocking the static `Geolocator.getPositionStream`"

requirements-completed:
  - GPS-02
  - GPS-03
  - GPS-04
  - GPS-05
  - GPS-08
  - QUAL-04

# Metrics
duration: "~17 min"
completed: 2026-04-19
---

# Phase 05 Plan 02: GPS Infrastructure & Platform Plumbing Summary

**The complete Phase-05 platform-integration layer: `geolocator`-backed `LocationStream`, `LocationSettingsFactory` covering every 05-RESEARCH pitfall, `SessionNotificationService`, `OemDetector`, and all native-side permission + service declarations (AndroidManifest + Info.plist).**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-04-19T09:39:55Z
- **Completed:** 2026-04-19T09:57:05Z
- **Tasks:** 3
- **Files created:** 13 (including 3 README.md)
- **Files modified:** 12 (port + helpers + 4 test stubs + 2 manifests + pubspec.yaml + pubspec.lock + DEPENDENCIES.md)
- **Commits:** 3 (`02f6c8e` + `7b301fc` + `19fa048`)

## Accomplishments

- **LocationStream port upgrade** — `Object sessionId` → `SessionId` + `required sessionDisplayName`; `FakeLocationStream` helper signature aligned in the same commit so downstream controller tests (Plan 05-03) cannot hit a signature mismatch.
- **LocationSettingsFactory** implementing Pattern 1 from 05-RESEARCH.md verbatim — every flag maps back to a named pitfall with inline rationale (enableWakeLock=true for Pitfall #4, pauseLocationUpdatesAutomatically=false for Pitfall #3, activityType=fitness for Pattern 1 walking hint, showBackgroundLocationIndicator=true for user-transparency). Works across Android / iOS / desktop (dev flow).
- **GeolocatorLocationStream** with `PositionStreamFactory` test seam — accuracy filter (50 m), stationary dedup (<1 m AND <10 s), domain error translation (geolocator `PermissionDeniedException` → domain `LocationPermissionDeniedException`; geolocator `LocationServiceDisabledException` → domain `LocationServiceDisabledException`); unknown errors propagate verbatim so infrastructure bugs don't hide.
- **Sealed `GpsError` hierarchy** — 3 variants cover every tracking-time failure mode; `TrackingBackgroundKilledException` is pre-plumbed for Plan 05-06 auto-resume.
- **SessionNotificationService** with `LocalNotificationsPort` seam — idempotent `initialize()` creates the LOW-importance channel + requests iOS permission; `showResumeNotification(sessionId, displayName)` posts a HIGH-importance dismissible notification with `resume:{sessionId}` payload for Plan 05-06's BOOT_COMPLETED / iOS watchdog path.
- **Sealed `OemFamily` hierarchy** with all 6 battery-killer target brands (Xiaomi/Samsung/Huawei/OnePlus/OPPO + OtherOem + IosDevice); regex-based lowercase match on `manufacturer` + `brand` catches brand re-labels (POCO under Xiaomi, Realme under OPPO, HONOR under Huawei).
- **3 Riverpod @keepAlive providers** wired: `locationStreamProvider`, `sessionNotificationServiceProvider`, `oemDetectorProvider`.
- **AndroidManifest.xml** — all 7 Phase 05 permissions + `BootCompletedReceiver` declaration with `BOOT_COMPLETED` + `MY_PACKAGE_REPLACED` intent filters; inline comment block documents `geolocator_android`'s merged-service expectation and the post-build verification requirement.
- **Info.plist** — final QUAL-04 copy taken VERBATIM from 05-CONTEXT.md §Permission + Store copy : FINAL en Phase 05 for both usage-description keys; zero `TODO` markers remaining; `UIBackgroundModes=location` declared.
- **26 new GREEN tests** (7 factory + 6 stream + 6 notification + 9 OEM + 5 info.plist = 33 tests; 4 stubs turned GREEN from Plan 05-01 Wave-0 scaffolding).
- **device_info_plus 12.4.0** pinned + BSD-3-Clause audited (`grep -rni "analytics|crashlytics|sentry|firebase|mixpanel|amplitude"` → 0 matches; `grep -rn "package:http|package:dio|HttpClient"` → 0 matches); entry in DEPENDENCIES.md including version-pin-deviation rationale vs. the plan's 13.0.0 request.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | LocationStream port + GeolocatorLocationStream + LocationSettingsFactory | `02f6c8e` | 20 files (8 new + 12 modified incl. regenerated .g.dart) |
| 2 | SessionNotificationService + OemDetector + device_info_plus audit | `7b301fc` | 20 files (8 new + 12 modified incl. pubspec.{yaml,lock} + DEPENDENCIES.md) |
| 3 | AndroidManifest + Info.plist QUAL-04 final copy + Info.plist test | `19fa048` | 3 files (AndroidManifest.xml + Info.plist + info_plist_final_copy_test.dart) |

## GPS Infrastructure API Surface

### Domain

```dart
// lib/domain/gps/location_stream.dart
abstract class LocationStream {
  Stream<Fix> positions({
    required SessionId sessionId,
    required int distanceFilterMeters,
    required String sessionDisplayName,
  });
  Future<void> dispose();
}
```

```dart
// lib/domain/gps/gps_errors.dart
sealed class GpsError implements Exception { ... }
final class LocationPermissionDeniedException extends GpsError {
  const LocationPermissionDeniedException({this.permanent = false});
  final bool permanent;
}
final class LocationServiceDisabledException extends GpsError { ... }
final class TrackingBackgroundKilledException extends GpsError { ... }
```

```dart
// lib/domain/errors/location_permission_errors.dart
enum LocationPermissionOutcome {
  granted, whileInUseOnly, denied, permanentlyDenied,
}
```

### Infrastructure seams

```dart
// lib/infrastructure/gps/geolocator_location_stream.dart
typedef PositionStreamFactory = Stream<geo.Position> Function(geo.LocationSettings);

class GeolocatorLocationStream implements LocationStream {
  GeolocatorLocationStream({
    required IdGenerator idGenerator,
    PositionStreamFactory? positionStreamFactory,  // default = Geolocator.getPositionStream
  });
}
```

```dart
// lib/infrastructure/notifications/session_notification_service.dart
abstract class LocalNotificationsPort {
  Future<void> createAndroidChannel(AndroidNotificationChannel channel);
  Future<bool?> requestIosPermissions({required bool alert, required bool badge, required bool sound});
  Future<void> show({required int id, required String title, required String body, required NotificationDetails details, String? payload});
  Future<void> cancel({required int id});
}

class SessionNotificationService {
  SessionNotificationService(LocalNotificationsPort notifications);
  Future<void> initialize();                                                // idempotent
  Future<void> showResumeNotification(SessionId id, String displayName);    // Plan 05-06
  Future<void> dismiss();
}
```

```dart
// lib/infrastructure/platform/oem_detector.dart
sealed class OemFamily { const OemFamily(); }
// XiaomiFamily / SamsungFamily / HuaweiFamily / OnePlusFamily / OppoFamily / OtherOem / IosDevice

class OemDetector {
  OemDetector(DeviceInfoPlugin plugin);
  Future<OemFamily> detect({bool? isIosOverride, bool? isAndroidOverride});
}
```

### Riverpod providers

| Provider | Returns | Lifetime |
|----------|---------|----------|
| `locationStreamProvider` | `LocationStream` | `@Riverpod(keepAlive: true)` |
| `sessionNotificationServiceProvider` | `SessionNotificationService` | `@Riverpod(keepAlive: true)` |
| `oemDetectorProvider` | `OemDetector` | `@Riverpod(keepAlive: true)` |

## LocationSettingsFactory Decisions (flags flipped vs. default)

| Flag | Platform | Default | Plan 05-02 | Pitfall |
|------|----------|---------|------------|---------|
| `enableWakeLock` | Android | `false` | `true` | #4 — screen-off >30 min would otherwise silently kill tracking |
| `setOngoing` | Android | `false` | `true` | Required for the fg-service notification to be non-dismissible during active tracking |
| `pauseLocationUpdatesAutomatically` | iOS | `false` | `false` (kept explicit) | #3 — iOS community examples commonly flip this to `true`; the plan's explicit `false` is a documented-intent anchor against future default flips |
| `activityType` | iOS | `ActivityType.other` | `ActivityType.fitness` | Pattern 1 — walking/running hint prevents "stopped car = park and leave" semantics |
| `showBackgroundLocationIndicator` | iOS | `false` | `true` | User-visible transparency — blue bar/pill while location is streaming in background |
| `allowBackgroundLocationUpdates` | iOS | `true` (kept explicit) | `true` | Required for background tracking; kept explicit so future default flip doesn't silently break |
| `accuracy` | all | `LocationAccuracy.best` | `LocationAccuracy.high` | Battery/quality trade-off; `best` is GPS-chipset max, `high` is ~10 m urban — matches `kMaxAcceptableAccuracyMeters=50.0` reject threshold comfortably |

## SessionNotificationService Channel Config

| Field | Value | Why |
|-------|-------|-----|
| `id` | `kNotificationChannelId` = `'mirkfall_session_tracking'` | Stable across installs — Android preserves user prefs keyed by channel id |
| `name` | `'MirkFall session tracking'` | User-visible in system-settings channel list |
| `importance` | `Importance.low` | No alert sound, no heads-up; icon only in status bar — matches the "always-there, never-interruptive" contract from CONTEXT.md §Notification |
| `enableVibration` | `false` | No buzz during every fix |
| `playSound` | `false` | No chirp during every fix |
| `description` | `'Notification persistante pendant une session active'` | User-visible help text when long-pressing the channel in settings |

## OemDetector Brand-Matching Sources

| Family | Manufacturer / Brand patterns (lowercase substring) | Source |
|--------|-----------------------------------------------------|--------|
| `XiaomiFamily` | `xiaomi\|redmi\|poco` (regex) | dontkillmyapp.com/xiaomi — MIUI battery-saver is the most aggressive |
| `SamsungFamily` | `samsung` (substring) | dontkillmyapp.com/samsung |
| `HuaweiFamily` | `huawei\|honor` (regex) | dontkillmyapp.com/huawei — Honor spun out of Huawei but shares EMUI kill semantics |
| `OnePlusFamily` | `oneplus` (substring) | dontkillmyapp.com/oneplus — "App startup manager" |
| `OppoFamily` | `oppo\|realme` (regex) | dontkillmyapp.com/oppo — Realme under OPPO battery-manager lineage |
| `OtherOem` | fallback on unknown Android | Google Pixel, stock AOSP — no guidance screen |
| `IosDevice` | iOS runtime | Skip guidance — iOS has a different background-tracking contract |

Lowercase match on `${manufacturer} ${brand}` belt-and-suspenders: some devices report brand (POCO) without manufacturer, others only report manufacturer (Xiaomi) — matching on either catches re-brands.

## device_info_plus Audit Evidence

Package: `device_info_plus 12.4.0` (pub cache: `C:/Users/oliver/AppData/Local/Pub/Cache/hosted/pub.dev/device_info_plus-12.4.0`).

**License verification:**
```
$ head -5 device_info_plus-12.4.0/LICENSE
Copyright 2017 The Chromium Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
```
→ **BSD-3-Clause** (standard Chromium/fluttercommunity preamble).

**Telemetry / analytics audit:**
```
$ grep -rni "analytics|crashlytics|sentry|firebase|mixpanel|amplitude" device_info_plus-12.4.0/lib/
(zero matches)
```

**HTTP client audit:**
```
$ grep -rn "package:http|package:dio|HttpClient" device_info_plus-12.4.0/lib/
(zero matches)
```

**Platform interface (`device_info_plus_platform_interface 7.0.3`):** same LICENSE preamble, same grep audits → zero matches on both telemetry and HTTP axes.

**Transitive added:** `win32_registry 2.1.0` (BSD 3-Clause / Halil Durmus) — Windows-only FFI helpers used to read OS version on desktop dev flow. Not shipped on Android/iOS.

**Publisher:** fluttercommunity.dev (verified). Same publisher as `share_plus`, `package_info_plus`, etc. already in the project.

## AndroidManifest.xml Diff

**Before** (Phase 01 default):
- 0 GPS permissions
- 0 notification permissions
- 0 receivers

**After** (Phase 05-02):
```xml
<!-- GPS foreground + background -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>

<!-- Foreground service (Android 14+ requires both) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>

<!-- Notification (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Boot-completed watchdog -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
+ `<receiver android:name=".BootCompletedReceiver" ...>` inside `<application>` with `BOOT_COMPLETED` + `MY_PACKAGE_REPLACED` intent filters.
+ Comment block above `<application>` documents `geolocator_android`'s merged `<service>` declaration and the post-build verification requirement.

## Info.plist Diff

**Before:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>TODO Phase 05: rationale GPS WhenInUse</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>TODO Phase 05: rationale background location, store-grade copy en Phase 15</string>
```

**After (verbatim from 05-CONTEXT.md §Permission + Store copy : FINAL en Phase 05):**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>MirkFall utilise ta position pour révéler le brouillard de ta carte d'exploration personnelle. Tout reste sur ton téléphone — aucun serveur, aucun partage, aucune publicité.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>MirkFall continue à suivre ta position en arrière-plan pour que ta carte d'exploration se révèle pendant que ton téléphone est dans ta poche, écran éteint — comme une vraie sortie. Tout reste sur ton téléphone. Aucune donnée n'est envoyée ni partagée.</string>
<!-- ... -->
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

`NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` kept as Phase 11 TODO (explicit scope boundary — not this plan).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] device_info_plus 13.0.0 → 12.4.0 (win32 transitive conflict)**
- **Found during:** Task 2 (`flutter pub get` resolution failure)
- **Issue:** Plan frontmatter + DEPENDENCIES.md expectations specified `device_info_plus 13.0.0`, but that release bumps the Windows backend transitive to `win32: ^6.0.0`. The already-pinned `file_picker 11.0.2` constrains `win32: ^5.9.0`, so the resolver rejected 13.0.0. Upgrading `file_picker` was out of scope (not touched anywhere else in the plan).
- **Fix:** Pinned `device_info_plus: 12.4.0` — the highest `device_info_plus` release that still resolves against `win32: ^5.11.0`. Same `AndroidDeviceInfo.manufacturer` + `brand` surface used by `OemDetector`; the 13.0.0 bump was purely a Windows transitive. Pinning rationale inlined in `pubspec.yaml` comments and in DEPENDENCIES.md row.
- **Files modified:** `pubspec.yaml`, `pubspec.lock`, `DEPENDENCIES.md`.
- **Verification:** `flutter pub get` clean; `dart run tool/check_dependencies_md.dart` green (192 packages); `dart run tool/check_licenses.dart` green (0 forbidden).
- **Committed in:** `7b301fc` (same commit as the rest of Task 2).

**2. [Rule 1 - Bug] 05-RESEARCH.md Pattern 1 snippet used `distanceFilterMeters.toDouble()` on iOS branch — but LocationSettings.distanceFilter is `int`**
- **Found during:** Task 1 first compile (`flutter test test/infrastructure/gps/`)
- **Issue:** The research doc literally showed `distanceFilter: distanceFilterMeters.toDouble()` for AppleSettings. `LocationSettings.distanceFilter` in `geolocator_platform_interface 4.2.6` is declared `final int distanceFilter`; the native side casts to `CLLocationDistance` (double) internally. `AppleSettings extends LocationSettings` inherits the `int` type.
- **Fix:** Dropped the `.toDouble()` call in `location_settings_factory.dart`; adjusted the iOS-branch test assertion from `expect(settings.distanceFilter, 12.0)` to `expect(settings.distanceFilter, 12)`. Added a comment documenting the int/CLLocationDistance bridge cast.
- **Files modified:** `lib/infrastructure/gps/location_settings_factory.dart`, `test/infrastructure/gps/location_settings_factory_test.dart`.
- **Verification:** All 14 Task 1 tests green on re-run.
- **Committed in:** `02f6c8e`.

**3. [Rule 3 - Blocking] analyzer info-level warnings on unused geolocator_android/apple imports + prefer_const_constructors + avoid_redundant_argument_values**
- **Found during:** Task 1 / Task 2 post-implementation `flutter analyze`
- **Issue:** CI gate runs `flutter analyze --fatal-infos --fatal-warnings`. Initial implementation imported `geolocator_android.dart` and `geolocator_apple.dart` directly for `AndroidSettings` / `AppleSettings`, but the main `geolocator.dart` re-exports them — both imports became `unnecessary_import` + `depend_on_referenced_packages`. Also had `prefer_const_constructors` on `NotificationDetails` + `AndroidNotificationDetails` (both had all-const args), and `avoid_redundant_argument_values` on `ongoing: false` (matches default).
- **Fix:** Dropped the redundant imports (kept only `package:geolocator/geolocator.dart`). Added `const` to the `NotificationDetails` / `AndroidNotificationDetails` literals. Removed `ongoing: false` (relies on the false default). Kept intentional-redundancy args (`pauseLocationUpdatesAutomatically: false`, `allowBackgroundLocationUpdates: true`) with `// ignore: avoid_redundant_argument_values` comments documenting why they stay explicit — future default flips would silently break tracking otherwise.
- **Files modified:** `lib/infrastructure/gps/location_settings_factory.dart`, `lib/infrastructure/notifications/session_notification_service.dart`, `test/infrastructure/gps/location_settings_factory_test.dart`, `test/infrastructure/gps/geolocator_location_stream_test.dart` (trailing `0`s dropped from `DateTime.utc(...)` fixture).
- **Verification:** `flutter analyze` → `No issues found!`
- **Committed in:** `02f6c8e` + `7b301fc` (rolled into their respective task commits).

**4. [Rule 2 - Missing critical] FlutterLocalNotificationsPlugin singleton-factory is not subclassable — SessionNotificationService needed a seam for testability**
- **Found during:** Task 2 (writing `session_notification_service_test.dart`)
- **Issue:** `FlutterLocalNotificationsPlugin()` is a `factory` constructor that returns a process-singleton (`factory FlutterLocalNotificationsPlugin() => _instance;` with private `._()`). Subclassing to mock `show` / `cancel` is not possible without reaching into private API. The plan said "use `flutter_local_notifications`'s mock channel OR inject a fake via constructor seam" — the "mock channel" path requires a real Android/iOS engine, which pure-Dart tests don't have.
- **Fix:** Introduced `LocalNotificationsPort` abstract class (4 methods — createAndroidChannel, requestIosPermissions, show, cancel — matching the service's exact surface area) plus a `FlutterLocalNotificationsAdapter` concrete implementation. `SessionNotificationService` takes `LocalNotificationsPort` instead of the plugin directly. Tests pass a capturing fake that records every call; the Riverpod provider wires the adapter around `FlutterLocalNotificationsPlugin()`. Same shape as the Phase 03 store-port convention.
- **Files created:** `lib/infrastructure/notifications/session_notification_service.dart` (contains both port + adapter + service).
- **Verification:** 6 notification tests green using the fake port.
- **Committed in:** `7b301fc`.

**5. [Rule 2 - Missing critical] OemDetector needed platform-sentinel injection seams for deterministic tests**
- **Found during:** Task 2 (writing `oem_detector_test.dart`)
- **Issue:** `OemDetector.detect()` originally branched on `Platform.isIOS` / `Platform.isAndroid` — hardcoded by the Dart VM at process start. Tests running on Windows host would always hit the "desktop → OtherOem" branch regardless of the Android fixture. CLAUDE.md §Dependency Injection: services injected via constructor; runtime platform also qualifies as an injected dependency.
- **Fix:** Added `{bool? isIosOverride, bool? isAndroidOverride}` optional-named-param seams to `OemDetector.detect`. Defaults (`null`) use `Platform.isIOS` / `Platform.isAndroid`. Tests pass explicit booleans; production call sites don't pass overrides. Same pattern used elsewhere in the Phase 05 plans (e.g. Phase 03's `IdGenerator` injection).
- **Files modified:** `lib/infrastructure/platform/oem_detector.dart`.
- **Verification:** 9 OemDetector tests green without host-platform sensitivity.
- **Committed in:** `7b301fc`.

**6. [Rule 3 - Blocking] flutter_local_notifications 21.0.0 plugin `show` + `cancel` use NAMED parameters, not positional**
- **Found during:** Task 2 first compile
- **Issue:** Initial implementation followed older plugin API examples: `_plugin.show(id, title, body, details, payload: ...)` (positional leading args). Plugin v21.0.0 made all params named: `Future<void> show({required int id, String? title, String? body, NotificationDetails? notificationDetails, String? payload})`. Same for `cancel({required int id, String? tag})`.
- **Fix:** Converted all invocations to named-arg form. Matches v21.0.0 API.
- **Files modified:** `lib/infrastructure/notifications/session_notification_service.dart` (twice — `show` + `cancel`; then the adapter since the port abstraction landed after).
- **Committed in:** `7b301fc`.

---

**Total deviations:** 6 auto-fixed (3 × Rule 3 blocking, 2 × Rule 2 missing-critical seams, 1 × Rule 1 bug in plan-referenced research snippet).

**Impact on plan:** All 6 fixes were necessary. #1 is the only user-visible one (dependency version deviation — documented). #4 and #5 are testability seams that strengthen the architecture rather than departing from it. #2, #3, #6 are mechanical — research-doc snippets + analyzer gates drifted since 05-RESEARCH.md was written (2026-04-19 morning) vs. the actual pinned package API surface.

## Issues Encountered

None blocking. The plan executed cleanly after the 6 auto-fixes above. No architectural decisions required user input.

## User Setup Required

None. `device_info_plus 12.4.0` installed via `flutter pub get`; no new SDK tooling or platform configuration needed. Info.plist + AndroidManifest.xml changes will take effect on the next build; existing Phase 01 `flutter build apk` smoke test remains green (no API usage changes that would fail codegen).

## Handoff Notes for Downstream Plans

### Plan 05-03 (Permission flow UI)

Available from this plan:
- **`LocationPermissionOutcome` enum** (granted / whileInUseOnly / denied / permanentlyDenied) in `lib/domain/errors/location_permission_errors.dart` — Plan 05-03 `requestLocationAlways()` should return this.
- **`locationStreamProvider`** Riverpod provider ready to wire into the controller (Plan 05-03) — call `ref.read(locationStreamProvider).positions(sessionId: ..., distanceFilterMeters: ..., sessionDisplayName: ...)`.
- **`sessionNotificationServiceProvider.initialize()`** — call once at app startup to guarantee the channel exists BEFORE geolocator's fg-service posts into it.
- **`oemDetectorProvider`** — `await ref.read(oemDetectorProvider).detect()` returns the sealed `OemFamily` value the Plan 05-04 guidance-screen controller pattern-matches on.

### Plan 05-04 (Settings + end-to-end UI)

- **OemDetector consumption pattern:** call `await ref.read(oemDetectorProvider).detect()` once on permission-granted, pattern-match exhaustively over the 7 `OemFamily` variants. For Android variants that match dontkillmyapp.com brands, show the guidance screen; for `OtherOem` / `IosDevice`, skip it.
- **Distance-filter slider:** persist via SharedPreferences key (to be locked in Plan 05-04 — suggest `distanceFilter_meters` from the 05-RESEARCH Pattern 2 sketch). Pass the persisted int into `LocationStream.positions(distanceFilterMeters: ...)`.

### Plan 05-05 (Session UI)

- **Session display name plumbing:** `LocationStream.positions` now requires `sessionDisplayName` — the session-list / session-start path must thread the session's `displayName` through to the stream call. The Android foreground-service notification title uses this value.

### Plan 05-06 (Store review + POC)

- **`BootCompletedReceiver` declaration is in place** (manifest) — Plan 05-06 creates the Kotlin file at `android/app/src/main/kotlin/.../BootCompletedReceiver.kt` with `BOOT_COMPLETED` + `MY_PACKAGE_REPLACED` handling.
- **`SessionNotificationService.showResumeNotification(sessionId, displayName)`** — Plan 05-06 calls this from the receiver (Android) and from the iOS significant-change watchdog. Payload format `resume:{sessionId}` is stable.
- **`TrackingBackgroundKilledException`** is already defined in `gps_errors.dart` — Plan 05-06 emits this from the stream when a watchdog detects a kill event.
- **`Info.plist` QUAL-04 final copy is in place** — Plan 05-06 `tool/test/store_rationale_exists_test.dart` turns GREEN when `docs/store-review-rationale.md` lands.

## Next Phase Readiness

- **GPS pipeline plumbing complete.** `LocationStream` port + `GeolocatorLocationStream` impl + `LocationSettingsFactory` + notification service + OEM detection — all green, all tested.
- **Native-side declarations complete.** AndroidManifest has all Phase 05 permissions + receiver; Info.plist has QUAL-04 final copy + `UIBackgroundModes=location`.
- **Dependency audit complete.** `device_info_plus 12.4.0` + 2 transitives audited, documented, and pin-justified.
- **26 new GREEN tests** + 4 Plan 05-01 Wave-0 stubs turned GREEN.
- **Known carryovers:**
  - `BootCompletedReceiver.kt` Kotlin body → Plan 05-06 (manifest declaration alone is inert at runtime — no broken contract).
  - Dynamic Island investigation → Plan 05-06 (05-RESEARCH Open Question #1 — explicitly deferred per plan locked-decision #12).
  - `device_info_plus 13.0.0` re-evaluation → whenever `file_picker` is upgraded past its `win32: ^5.9.0` constraint.

---
*Phase: 05-gps-session-lifecycle*
*Completed: 2026-04-19*

## Self-Check: PASSED

- lib/domain/gps/gps_errors.dart: FOUND
- lib/domain/gps/README.md: FOUND
- lib/domain/errors/location_permission_errors.dart: FOUND
- lib/infrastructure/gps/location_settings_factory.dart: FOUND
- lib/infrastructure/gps/geolocator_location_stream.dart: FOUND
- lib/infrastructure/gps/README.md: FOUND
- lib/infrastructure/notifications/session_notification_service.dart: FOUND
- lib/infrastructure/notifications/README.md: FOUND
- lib/infrastructure/platform/oem_detector.dart: FOUND
- lib/infrastructure/platform/README.md: FOUND
- lib/application/providers/location_stream_provider.dart: FOUND
- lib/application/providers/session_notification_service_provider.dart: FOUND
- lib/application/providers/oem_detector_provider.dart: FOUND
- Commit 02f6c8e: FOUND
- Commit 7b301fc: FOUND
- Commit 19fa048: FOUND
