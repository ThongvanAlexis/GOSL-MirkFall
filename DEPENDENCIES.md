# DEPENDENCIES.md — MirkFall

Audit log for every direct and transitive Dart/Flutter dependency resolved by
`flutter pub get` against the repository's pinned `pubspec.yaml`.

**Mandatory:** every entry in `pubspec.lock` (direct + transitive) MUST have a
row in one of the tables below with the same version string. Enforced by
`tool/check_dependencies_md.dart` in CI.

**Telemetry policy** (CLAUDE.md §Télémétrie — interdiction stricte): zero
outbound network traffic without explicit user action for that specific
transmission. The "Telemetry audit" column for each row confirms inspection
of the source (pub.dev repo link in the Source column) against this rule.

**License allowlist** (CLAUDE.md §Licences acceptées): MIT, BSD-2-Clause,
BSD-3-Clause, Apache-2.0, Unlicense, CC0-1.0, ISC, Zlib. Any package under
a copyleft license (GPL/AGPL/LGPL/MPL) is forbidden **unless** narrowly
scoped to a platform that MirkFall does not ship (e.g. Linux-only
transitive). Three such exceptions are documented in `tool/check_licenses.dart`
`_manualOverrides` with `MPL-2.0-Linux-only` rationale.

Initial audit date: **2026-04-17**. Re-audit required whenever
`pubspec.lock` changes.

## Direct dependencies

| Package | Version | License | Source | Telemetry audit | Date |
|---------|---------|---------|--------|-----------------|------|
| collection | 1.19.1 | BSD-3-Clause | https://pub.dev/packages/collection | Pure Dart collection utilities. No network. | 2026-04-17 |
| crypto | 3.0.7 | BSD-3-Clause | https://pub.dev/packages/crypto | Phase 07 plan 07-01 — **promoted 2026-04-20 from transitive → direct `dependencies`**. Previously pulled by `build_runner` only; Phase 07 needs it at runtime for the download pipeline's per-chunk + whole-file sha256 verification (RESEARCH Example 2: `AccumulatorSink<Digest>` streaming pattern). Source re-inspected (github.com/dart-lang/crypto) — pure Dart SHA-1/SHA-256/SHA-512/HMAC implementations, zero HTTP, zero platform channels, zero native dependencies. Dart-team package, no telemetry. Audit date: 2026-04-20. | 2026-04-20 |
| cupertino_icons | 1.0.9 | MIT | https://pub.dev/packages/cupertino_icons | Asset-only (icon font). No runtime code. | 2026-04-17 |
| device_info_plus | 12.4.0 | BSD-3-Clause | https://pub.dev/packages/device_info_plus | Phase 05 plan 05-02 — OEM family detection for GPS-08 guidance screen (Xiaomi / Samsung / Huawei / OnePlus / OPPO / Realme battery killers per 05-RESEARCH Pitfall #8). Audit 2026-04-19: source github.com/fluttercommunity/plus_plugins/device_info_plus inspected — pure platform-info queries (Android Build.MANUFACTURER / iOS UIDevice / Windows Registry / Linux /etc/os-release). Network audit: `grep -rni "analytics\|crashlytics\|sentry\|firebase\|mixpanel\|amplitude" lib/` returned 0 matches. HTTP audit: `grep -rn "package:http\|package:dio\|HttpClient" lib/` returned 0 matches. License file in pub cache: `Copyright 2017 The Chromium Authors` + standard BSD 3-clause preamble (inherited from flutter.dev/community plus_plugins convention). Publisher: fluttercommunity.dev (verified). Version pin note: 05-02-PLAN.md specified 13.0.0 but that release transitively requires `win32: ^6.0.0`, incompatible with the pinned `file_picker: 11.0.2` constraint `win32: ^5.9.0`. 12.4.0 is the highest line that still resolves against `win32: ^5.11.0` and exposes the same `AndroidDeviceInfo.manufacturer` + `brand` surface used by `OemDetector`. Re-evaluate 13.x when file_picker is upgraded. | 2026-04-19 |
| drift | 2.32.1 | MIT | https://pub.dev/packages/drift | SQLite ORM. Local DB access only, no network. | 2026-04-17 |
| drift_flutter | 0.3.0 | MIT | https://pub.dev/packages/drift_flutter | Flutter glue for drift. Local-only. | 2026-04-17 |
| file_picker | 11.0.2 | MIT | https://pub.dev/packages/file_picker | OS file picker bridge. No network. | 2026-04-17 |
| flutter_local_notifications | 21.0.0 | BSD-3-Clause | https://pub.dev/packages/flutter_local_notifications | Local OS notifications. No network. | 2026-04-17 |
| flutter_riverpod | 3.3.1 | MIT | https://pub.dev/packages/flutter_riverpod | Pure DI/state container. No network. Bumped 2026-04-18 from 3.1.0 to align with riverpod 3.2.1 chain required by riverpod_lint 3.1.3 + riverpod_generator 4.0.3 (see 03-04). | 2026-04-18 |
| freezed_annotation | 3.1.0 | MIT | https://pub.dev/packages/freezed_annotation | Annotations-only, no runtime. | 2026-04-17 |
| geolocator | 14.0.2 | MIT | https://pub.dev/packages/geolocator | Wraps OS GPS API. No network. | 2026-04-17 |
| go_router | 16.0.0 | BSD-3-Clause | https://pub.dev/packages/go_router | Pure routing, no network. | 2026-04-17 |
| image_picker | 1.2.1 | Apache-2.0 | https://pub.dev/packages/image_picker | Camera/gallery bridge. No network. | 2026-04-17 |
| json_annotation | 4.11.0 | BSD-3-Clause | https://pub.dev/packages/json_annotation | Annotations-only. Bumped 2026-04-18 from 4.9.0 — json_serializable 6.13.1 requires json_annotation >=4.11.0. | 2026-04-18 |
| logging | 1.3.0 | BSD-3-Clause | https://pub.dev/packages/logging | No outbound HTTP. Sinks defined by user. | 2026-04-17 |
| maplibre_gl | 0.25.0 | BSD-3-Clause | https://pub.dev/packages/maplibre_gl | Phase 07 plan 07-01 — **replaces `flutter_map 8.3.0` + `latlong2 0.9.1` (both dropped 2026-04-20)** for offline PMTiles rendering. MapLibre-org publisher (verified on pub.dev). Audit 2026-04-20: source github.com/maplibre/flutter-maplibre-gl inspected — no built-in analytics, no crash reporting, no remote config. Tile fetches happen only when a style layer source URL is HTTP(S); Phase 07 enforces `pmtiles://file:///…` local-only via the new `tool/check_avoid_remote_pmtiles.dart` CI gate. Native SDKs bundled: **MapLibre Native Android 12.3.0** (BSD-2-Clause, github.com/maplibre/maplibre-native) and **MapLibre Native iOS 6.14.0** (BSD-2-Clause, github.com/maplibre/maplibre-gl-native-distribution). Both native libraries are pure-rendering SDKs with no telemetry; Protomaps basemaps data (OSM-derived) ships inside the bundled PMTiles files under ODbL 1.0 attribution (see MAP-03 + "Bundled assets" section below). HTTP audit via `grep`: the runtime Dart surface issues `HttpClient` requests only when the style JSON references HTTPS URLs — our style.json uses `asset:///` for glyphs/sprites and `pmtiles://file:///` for tiles, yielding zero outbound traffic. Platform support: Android + iOS + Linux + macOS + Windows + Web (transitive `maplibre_gl_web` 0.25.0 pulls `image 4.8.0`). | 2026-04-20 |
| path | 1.9.1 | BSD-3-Clause | https://pub.dev/packages/path | Path manipulation. No network. | 2026-04-17 |
| path_provider | 2.1.5 | BSD-3-Clause | https://pub.dev/packages/path_provider | Wraps native path APIs. No network. | 2026-04-17 |
| permission_handler | 12.0.1 | MIT | https://pub.dev/packages/permission_handler | OS permissions bridge. No network. | 2026-04-17 |
| riverpod_annotation | 4.0.2 | MIT | https://pub.dev/packages/riverpod_annotation | Annotations-only, no runtime. Bumped 2026-04-18 from 4.0.0 to match riverpod 3.2.1 chain required by riverpod_generator 4.0.3. | 2026-04-18 |
| share_plus | 12.0.2 | BSD-3-Clause | https://pub.dev/packages/share_plus | OS share intent; no network itself. | 2026-04-17 |
| shared_preferences | 2.5.5 | BSD-3-Clause | https://pub.dev/packages/shared_preferences | Wraps OS key-value store. No network. | 2026-04-17 |
| sqlite3_flutter_libs | 0.6.0+eol | MIT | https://pub.dev/packages/sqlite3_flutter_libs | Bundles sqlite3 native. No network. | 2026-04-17 |

## Dev dependencies

| Package | Version | License | Source | Telemetry audit | Date |
|---------|---------|---------|--------|-----------------|------|
| build_runner | 2.13.1 | BSD-3-Clause | https://pub.dev/packages/build_runner | Dev codegen only. No app runtime. Bumped 2026-04-18 from 2.9.0 — 2.9.0 uses analyzer APIs removed in analyzer 10; 2.13.1 supports analyzer >=8.0.0 <13.0.0. | 2026-04-18 |
| custom_lint | 0.8.1 | Apache-2.0 | https://pub.dev/packages/custom_lint | Phase 03 — analyzer-plugin host for riverpod_lint rules. Audit 2026-04-18: source github.com/invertase/dart_custom_lint inspected — analyzer-plugin runtime only, zero outbound HTTP, only opens a local IPC channel to the analyzer. License preamble in pub cache is Apache-2.0 (plan stated MIT — corrected here). **Status: silently-degraded** — under the analyzer-10 override (added in 03-04 for drift_dev), this version cannot load its plugin (`custom_lint_core` 0.8.1 built against pre-`Element2` API, cascades to unresolved `Annotatable`, `ErrorCode`, `libraryElement2`, `resolveFile2`). `flutter analyze --fatal-infos --fatal-warnings` stays green via the analyzer-10 stack — operational impact = 0. Formally accepted as Noted in Phase 04 review gate (04-REVIEW.md §3 P2). Re-verify at each deps bump and Phase 15 polish at the latest. | 2026-04-18 |
| drift_dev | 2.32.1 | MIT | https://pub.dev/packages/drift_dev | Phase 03 — Drift codegen (AppDatabase, schema dumps, SchemaVerifier migration helpers). Audit 2026-04-18: source github.com/simolus3/drift inspected — pure build_runner generator + schema dump CLI; zero runtime code; no network access; reads .dart source, writes .g.dart and JSON artefacts. Same author as `drift` + `sqlparser` (Simon Binder). | 2026-04-18 |
| flutter_lints | 6.0.0 | BSD-3-Clause | https://pub.dev/packages/flutter_lints | Analyzer config, no runtime. | 2026-04-17 |
| freezed | 3.2.5 | MIT | https://pub.dev/packages/freezed | Dev codegen. No app runtime. Bumped 2026-04-18 from 3.2.3 — 3.2.5 supports analyzer >=9 <11, needed under the analyzer-10 override added for drift_dev 2.32.1. | 2026-04-18 |
| json_serializable | 6.13.1 | BSD-3-Clause | https://pub.dev/packages/json_serializable | Dev codegen. Bumped 2026-04-18 from 6.11.2 — 6.13.1 requires analyzer >=10 <13, needed under the analyzer-10 override. | 2026-04-18 |
| path_provider_platform_interface | 2.1.2 | BSD-3-Clause | https://pub.dev/packages/path_provider_platform_interface | Test-mock contract. No network. | 2026-04-17 |
| plugin_platform_interface | 2.1.8 | BSD-3-Clause | https://pub.dev/packages/plugin_platform_interface | MockPlatformInterfaceMixin for tests. No runtime. | 2026-04-17 |
| riverpod_generator | 4.0.3 | MIT | https://pub.dev/packages/riverpod_generator | Dev codegen. Bumped 2026-04-18 from 4.0.0+1 — 4.0.3 declares analyzer ^9.0.0 but runs under the analyzer-10 override and pulls riverpod_analyzer_utils 1.0.0-dev.9 which matches riverpod_lint 3.1.3. | 2026-04-18 |
| riverpod_lint | 3.1.3 | MIT | https://pub.dev/packages/riverpod_lint | Phase 03 — Riverpod misuse detection (`@riverpod` provider rules). Bumped 2026-04-18 from 3.1.0 to align with riverpod 3.2.1 chain. Source re-inspected (github.com/rrousselGit/riverpod v3.1.3 tag): still pure analyzer-plugin rule definitions, zero outbound HTTP. NOTE: under analyzer-10 override, `custom_lint` 0.8.1 host cannot load the analyzer plugin — riverpod_lint silently degrades until custom_lint ships an analyzer-^10 compatible release. | 2026-04-18 |
| shelf | 1.4.2 | BSD-3-Clause | https://pub.dev/packages/shelf | Phase 07 plan 07-01 — **promoted 2026-04-20 from transitive (was pulled by `test`) → direct `dev_dependencies`**. Dart-team package. Phase 07 download soak tests spin up a MockHTTPServer via `package:shelf/shelf_io.dart` to exercise chunk-interrupt + resume + sha256-mismatch paths against a controlled local server (RESEARCH §Tests — MockHTTPServer pattern). Dev-only, never shipped in the app binary. Same `depend_on_referenced_packages` rationale as the Phase 03 promotion of `test` + `yaml`. | 2026-04-20 |
| test | 1.30.0 | BSD-3-Clause | https://pub.dev/packages/test | Dart test runner used by tool/test/. No app runtime. | 2026-04-17 |
| yaml | 3.1.3 | MIT | https://pub.dev/packages/yaml | YAML parser used by tool/check_*.dart. No network. | 2026-04-17 |

## Transitive dependencies

Resolved by `flutter pub get` against Flutter 3.41.7 + pinned `pubspec.yaml`.
Every entry is marked `dependency: transitive` in `pubspec.lock`.

| Package | Version | License | Pulled in by | Notes | Date |
|---------|---------|---------|--------------|-------|------|
| _fe_analyzer_shared | 93.0.0 | BSD-3-Clause | analyzer | Dev-only. Bumped 2026-04-18 from 91.0.0 alongside analyzer 10.0.1. | 2026-04-18 |
| analysis_server_plugin | 0.3.3 | BSD-3-Clause | custom_lint | Dev-only. Dart-team package providing the analysis-server plugin host API. | 2026-04-18 |
| analyzer | 10.0.1 | BSD-3-Clause | drift_dev, build_runner, riverpod_generator, custom_lint, json_serializable, freezed | Dev-only. Bumped 2026-04-18 from 8.4.0 via `dependency_overrides: analyzer: ^10.0.0` — drift_dev 2.32.1 requires analyzer ^10.0.0. Supersedes the 03-01 analyzer-<9 pin decision. custom_lint 0.8.1 cannot load its plugin under analyzer 10 and silently degrades (no @riverpod targets yet). | 2026-04-18 |
| analyzer_buffer | 0.3.1 | MIT | riverpod_analyzer_utils | Dev-only. Bumped 2026-04-18 from 0.1.11 alongside analyzer 10.0.1. | 2026-04-18 |
| analyzer_plugin | 0.13.10 | BSD-3-Clause | custom_lint | Dev-only. Dart-team package: analyzer plugin protocol implementation. | 2026-04-18 |
| archive | 4.0.9 | MIT | build_runner | Dev-only. | 2026-04-17 |
| args | 2.7.0 | BSD-3-Clause | build_runner, test | Dev-only. | 2026-04-17 |
| async | 2.13.1 | BSD-3-Clause | multiple | Pure async utilities. | 2026-04-17 |
| boolean_selector | 2.1.2 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| build | 4.0.5 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| build_config | 1.3.0 | BSD-3-Clause | build_runner | Dev-only. Bumped 2026-04-18 from 1.2.0. | 2026-04-18 |
| build_daemon | 4.1.1 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| built_collection | 5.1.1 | BSD-3-Clause | code_builder | Dev-only. | 2026-04-17 |
| built_value | 8.12.5 | BSD-3-Clause | code_builder | Dev-only. | 2026-04-17 |
| characters | 1.4.1 | BSD-3-Clause | flutter | Grapheme clusters. | 2026-04-17 |
| charcode | 1.4.0 | BSD-3-Clause | drift_dev | Dev-only. Pulled transitively by drift_dev. Dart-team package for ASCII char-code constants. License file: "Copyright 2014, the Dart project authors" + standard Google 3-clause preamble. No network. Added 2026-04-18. | 2026-04-18 |
| checked_yaml | 2.0.4 | BSD-3-Clause | json_serializable | Dev-only. | 2026-04-17 |
| ci | 0.1.0 | Apache-2.0 | custom_lint | Dev-only. Detects CI environment for plugin output formatting. | 2026-04-18 |
| cli_config | 0.2.0 | BSD-3-Clause | native_toolchain_c | Dev-only. | 2026-04-17 |
| cli_util | 0.4.2 | BSD-3-Clause | custom_lint | Dev-only. Dart-team CLI helpers (paths, OS detection). | 2026-04-18 |
| clock | 1.1.2 | Apache-2.0 | fake_async | Testing utility. | 2026-04-17 |
| code_assets | 1.0.0 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| code_builder | 4.11.1 | BSD-3-Clause | riverpod_generator | Dev-only. | 2026-04-17 |
| convert | 3.1.2 | BSD-3-Clause | crypto | Pure encoding. | 2026-04-17 |
| coverage | 1.15.0 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| cross_file | 0.3.5+2 | BSD-3-Clause | share_plus_platform_interface | XFile type. | 2026-04-17 |
| custom_lint_core | 0.8.1 | Apache-2.0 | custom_lint | Dev-only. Shared logic between custom_lint and rule packages. | 2026-04-18 |
| custom_lint_visitor | 1.0.0+8.4.0 | Apache-2.0 | custom_lint | Dev-only. AST visitor helpers pinned to analyzer 8.4.x compatibility. | 2026-04-18 |
| dart_style | 3.1.7 | BSD-3-Clause | build_runner | Dev-only formatter. Bumped 2026-04-18 from 3.1.3 via `dependency_overrides` — 3.1.8 requires analyzer ^12, but our override holds analyzer at ^10, so 3.1.7 (supports analyzer >=10 <12) is the ceiling. | 2026-04-18 |
| dbus | 0.7.12 | MPL-2.0-Linux-only | flutter_local_notifications_linux, geolocator_linux, gsettings | Linux-only transitive; does not ship on Android/iOS. MPL-2.0 is file-level weak-copyleft, does not contaminate combined work. Override in tool/check_licenses.dart. | 2026-04-17 |
| device_info_plus_platform_interface | 7.0.3 | BSD-3-Clause | device_info_plus | Platform interface contract for device_info_plus. License in pub cache: Chromium Authors + BSD 3-clause preamble. No analytics, no HTTP imports. Added 2026-04-19 with device_info_plus 12.4.0. | 2026-04-19 |
| fake_async | 1.3.3 | Apache-2.0 | flutter_test | Testing utility. | 2026-04-17 |
| ffi | 2.2.0 | BSD-3-Clause | native plugins | FFI bindings. | 2026-04-17 |
| file | 7.0.1 | BSD-3-Clause | build_runner | Dev-only FS abstraction. | 2026-04-17 |
| file_selector_linux | 0.9.4 | BSD-3-Clause | file_picker | Linux-only plugin surface. | 2026-04-17 |
| file_selector_macos | 0.9.5 | BSD-3-Clause | file_picker | macOS-only plugin surface. | 2026-04-17 |
| file_selector_platform_interface | 2.7.0 | BSD-3-Clause | file_picker | Platform interface. | 2026-04-17 |
| file_selector_windows | 0.9.3+5 | BSD-3-Clause | file_picker | Windows-only plugin surface. | 2026-04-17 |
| fixnum | 1.1.1 | BSD-3-Clause | built_value | Pure Dart ints. | 2026-04-17 |
| flutter_local_notifications_linux | 8.0.0 | BSD-3-Clause | flutter_local_notifications | Linux-only surface. | 2026-04-17 |
| flutter_local_notifications_platform_interface | 11.0.0 | BSD-3-Clause | flutter_local_notifications | Platform interface. | 2026-04-17 |
| flutter_local_notifications_windows | 3.0.0 | BSD-3-Clause | flutter_local_notifications | Windows-only surface. | 2026-04-17 |
| flutter_plugin_android_lifecycle | 2.0.34 | BSD-3-Clause | multiple android plugins | Android lifecycle bridge. BSD-3-Clause override in tool/check_licenses.dart (LICENSE file preamble defeats heuristic). | 2026-04-17 |
| frontend_server_client | 4.0.0 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| geoclue | 0.1.1 | MPL-2.0-Linux-only | geolocator_linux | Linux-only. Same rationale as dbus above. Override in tool/check_licenses.dart. | 2026-04-17 |
| geolocator_android | 5.0.2 | MIT | geolocator | Android GPS bridge. No network. | 2026-04-17 |
| geolocator_apple | 2.3.13 | MIT | geolocator | iOS GPS bridge. No network. | 2026-04-17 |
| geolocator_linux | 0.2.4 | MIT | geolocator | Linux-only surface. | 2026-04-17 |
| geolocator_platform_interface | 4.2.6 | MIT | geolocator | Platform interface. | 2026-04-17 |
| geolocator_web | 4.1.3 | MIT | geolocator | Web-only surface. Not a MirkFall target. | 2026-04-17 |
| geolocator_windows | 0.2.5 | MIT | geolocator | Windows-only surface. | 2026-04-17 |
| glob | 2.1.3 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| graphs | 2.3.2 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| gsettings | 0.2.8 | MPL-2.0-Linux-only | geolocator_linux (via shared_preferences_linux) | Linux-only. Same rationale as dbus above. Override in tool/check_licenses.dart. | 2026-04-17 |
| hooks | 1.0.2 | BSD-3-Clause | native_toolchain_c | Dev build-hook framework. | 2026-04-17 |
| http | 1.6.0 | BSD-3-Clause | build_runner (dev), flutter_map (runtime) | Used by flutter_map for tile fetches (Phase 07 will enforce User-Agent). | 2026-04-17 |
| http_multi_server | 3.2.2 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| http_parser | 4.1.2 | BSD-3-Clause | http, test | Pure parser. | 2026-04-17 |
| image | 4.8.0 | Apache-2.0 | maplibre_gl_web | Pure-Dart image codec / encoder used by the MapLibre web surface. Apache-2.0 (Brendan Duncan); verified via pub.dev + upstream github.com/brendan-duncan/image LICENSE. Zero network; pure-Dart byte manipulation. Added 2026-04-20 with maplibre_gl 0.25.0 (Phase 07 plan 07-01). Non-Web MirkFall ship (Android + iOS + Windows + macOS + Linux) does not actually execute this codepath — `maplibre_gl_web` is a web-only surface — but `image` stays in the lockfile because pub resolves the full transitive graph across all platforms. | 2026-04-20 |
| image_picker_android | 0.8.13+16 | Apache-2.0 | image_picker | Android-only surface. | 2026-04-17 |
| image_picker_for_web | 3.1.1 | BSD-3-Clause | image_picker | Web-only surface. | 2026-04-17 |
| image_picker_ios | 0.8.13+6 | Apache-2.0 | image_picker | iOS-only surface. | 2026-04-17 |
| image_picker_linux | 0.2.2 | BSD-3-Clause | image_picker | Linux-only surface. | 2026-04-17 |
| image_picker_macos | 0.2.2+1 | BSD-3-Clause | image_picker | macOS-only surface. | 2026-04-17 |
| image_picker_platform_interface | 2.11.1 | BSD-3-Clause | image_picker | Platform interface. | 2026-04-17 |
| image_picker_windows | 0.2.2 | BSD-3-Clause | image_picker | Windows-only surface. | 2026-04-17 |
| io | 1.0.5 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| jni | 1.0.0 | BSD-3-Clause | native plugins | Android JNI bridge. | 2026-04-17 |
| jni_flutter | 1.0.1 | BSD-3-Clause | native plugins | Android JNI Flutter glue. | 2026-04-17 |
| leak_tracker | 11.0.2 | BSD-3-Clause | flutter_test | Dev-test-only. | 2026-04-17 |
| leak_tracker_flutter_testing | 3.0.10 | BSD-3-Clause | flutter_test | Dev-test-only. | 2026-04-17 |
| leak_tracker_testing | 3.0.2 | BSD-3-Clause | flutter_test | Dev-test-only. | 2026-04-17 |
| lints | 6.1.0 | BSD-3-Clause | flutter_lints | Analyzer rules. | 2026-04-17 |
| maplibre_gl_platform_interface | 0.25.0 | BSD-3-Clause | maplibre_gl | Phase 07 plan 07-01 — platform-interface contract for maplibre_gl. Pure Dart; no network; publisher maplibre.org verified on pub.dev. Audit 2026-04-20: source github.com/maplibre/flutter-maplibre-gl/tree/main/maplibre_gl_platform_interface inspected — abstract method channel definitions and codec only, zero telemetry. | 2026-04-20 |
| maplibre_gl_web | 0.25.0 | BSD-3-Clause | maplibre_gl | Phase 07 plan 07-01 — web-only backend for maplibre_gl (wraps maplibre-gl-js via JS interop). MirkFall does not ship to web (Android + iOS + desktop only), so this code never executes at runtime — it stays in the dependency graph because pub resolves all platforms. Publisher maplibre.org verified on pub.dev. Audit 2026-04-20: source github.com/maplibre/flutter-maplibre-gl/tree/main/maplibre_gl_web inspected — pure JS-interop wrapper, no telemetry beyond whatever the JS library would emit (not a MirkFall concern since we never ship web). Pulls `image 4.8.0` transitively. | 2026-04-20 |
| matcher | 0.12.19 | BSD-3-Clause | test, flutter_test | Dev-test-only. | 2026-04-17 |
| material_color_utilities | 0.13.0 | Apache-2.0 | flutter | Material color math. | 2026-04-17 |
| meta | 1.17.0 | BSD-3-Clause | multiple | Annotations. | 2026-04-17 |
| mime | 2.0.0 | BSD-3-Clause | shelf | MIME type lookup. | 2026-04-17 |
| mockito | 5.6.4 | Apache-2.0 | flutter_test | Dev-test-only. | 2026-04-17 |
| native_toolchain_c | 0.17.6 | BSD-3-Clause | build_runner (build hooks) | Dev-only. | 2026-04-17 |
| node_preamble | 2.0.2 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| objective_c | 9.3.0 | BSD-3-Clause | native iOS plugins | iOS FFI bindings. | 2026-04-17 |
| package_config | 2.2.0 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| package_info_plus | 9.0.1 | BSD-3-Clause | file_picker | Bundle metadata only. No network. | 2026-04-17 |
| package_info_plus_platform_interface | 3.2.1 | BSD-3-Clause | package_info_plus | Platform interface. | 2026-04-17 |
| path_provider_android | 2.3.1 | BSD-3-Clause | path_provider | Android surface. | 2026-04-17 |
| path_provider_foundation | 2.6.0 | BSD-3-Clause | path_provider | iOS/macOS surface. | 2026-04-17 |
| path_provider_linux | 2.2.1 | BSD-3-Clause | path_provider | Linux-only surface. | 2026-04-17 |
| path_provider_windows | 2.3.0 | BSD-3-Clause | path_provider | Windows-only surface. | 2026-04-17 |
| permission_handler_android | 13.0.1 | MIT | permission_handler | Android surface. | 2026-04-17 |
| permission_handler_apple | 9.4.7 | MIT | permission_handler | iOS surface. | 2026-04-17 |
| permission_handler_html | 0.1.3+5 | MIT | permission_handler | Web-only surface. | 2026-04-17 |
| permission_handler_platform_interface | 4.3.0 | MIT | permission_handler | Platform interface. | 2026-04-17 |
| permission_handler_windows | 0.2.1 | MIT | permission_handler | Windows-only surface. | 2026-04-17 |
| petitparser | 7.0.2 | MIT | xml | Parser combinator. | 2026-04-17 |
| platform | 3.1.6 | BSD-3-Clause | multiple | Platform detection. | 2026-04-17 |
| pool | 1.5.2 | BSD-3-Clause | build_runner | Resource pool. | 2026-04-17 |
| posix | 6.5.0 | MIT | shared_preferences_linux | Linux-only bindings. | 2026-04-17 |
| process | 5.0.5 | BSD-3-Clause | integration_test (via webdriver) | Dev-only. Pulled transitively by `integration_test` → `webdriver`. Pure-Dart process wrapper from the Dart project authors. License preamble: "Copyright 2013, the Dart project authors" + BSD 3-clause. Zero network. Added 2026-04-21 with `integration_test` (Phase 07 plan 07-07). | 2026-04-21 |
| pub_semver | 2.2.0 | BSD-3-Clause | build_runner, pubspec_parse | Pure semver. | 2026-04-17 |
| pubspec_parse | 1.5.0 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| recase | 4.1.0 | BSD-2-Clause | drift_dev | Dev-only. Pulled transitively by drift_dev. Pure-Dart string case conversion (camelCase <-> snake_case). License file: "Copyright 2017 Keith Elliott" + standard BSD 2-clause "Redistribution and use..." preamble. No network. Added 2026-04-18. | 2026-04-18 |
| riverpod | 3.2.1 | MIT | flutter_riverpod | Core DI/state container. Bumped 2026-04-18 from 3.1.0 alongside flutter_riverpod 3.3.1 + riverpod_lint 3.1.3 + riverpod_generator 4.0.3. | 2026-04-18 |
| riverpod_analyzer_utils | 1.0.0-dev.9 | MIT | riverpod_generator | Dev-only. Bumped 2026-04-18 from 1.0.0-dev.8 with riverpod_generator 4.0.3. | 2026-04-18 |
| rxdart | 0.28.0 | Apache-2.0 | riverpod_lint | Dev-only. Reactive extensions used internally by riverpod_lint rule engine. | 2026-04-18 |
| share_plus_platform_interface | 6.1.0 | BSD-3-Clause | share_plus | Platform interface. | 2026-04-17 |
| shared_preferences_android | 2.4.23 | BSD-3-Clause | shared_preferences | Android surface. | 2026-04-17 |
| shared_preferences_foundation | 2.5.6 | BSD-3-Clause | shared_preferences | iOS/macOS surface. | 2026-04-17 |
| shared_preferences_linux | 2.4.1 | BSD-3-Clause | shared_preferences | Linux-only surface. | 2026-04-17 |
| shared_preferences_platform_interface | 2.4.2 | BSD-3-Clause | shared_preferences | Platform interface. | 2026-04-17 |
| shared_preferences_web | 2.4.3 | BSD-3-Clause | shared_preferences | Web-only surface. | 2026-04-17 |
| shared_preferences_windows | 2.4.1 | BSD-3-Clause | shared_preferences | Windows-only surface. | 2026-04-17 |
| shelf_packages_handler | 3.0.2 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| shelf_static | 1.1.3 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| shelf_web_socket | 3.0.0 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| source_gen | 4.2.2 | BSD-3-Clause | riverpod_generator | Dev-only. | 2026-04-17 |
| source_helper | 1.3.11 | Apache-2.0 | json_serializable | Dev-only. Bumped 2026-04-18 from 1.3.8 with json_serializable 6.13.1. | 2026-04-18 |
| source_map_stack_trace | 2.1.2 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| source_maps | 0.10.13 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| source_span | 1.10.2 | BSD-3-Clause | yaml, analyzer | Pure Dart. | 2026-04-17 |
| sqlcipher_flutter_libs | 0.7.0+eol | Apache-2.0 | drift_flutter (optional) | Optional cipher bundle. Not enabled by default. | 2026-04-17 |
| sqlite3 | 3.3.1 | MIT | drift_flutter | Pure-Dart sqlite bindings. | 2026-04-17 |
| sqlparser | 0.44.3 | MIT | drift_dev | Dev-only. Pulled transitively by drift_dev. Pure-Dart SQL parser used by drift codegen to verify query AST. Same author as drift + drift_dev (Simon Binder). MIT license preamble in pub cache. No network. Added 2026-04-18. | 2026-04-18 |
| stack_trace | 1.12.1 | BSD-3-Clause | multiple | Pure Dart. | 2026-04-17 |
| state_notifier | 1.0.0 | MIT | riverpod | Core DI. | 2026-04-17 |
| stream_channel | 2.1.4 | BSD-3-Clause | test | Pure Dart. | 2026-04-17 |
| stream_transform | 2.1.1 | BSD-3-Clause | shelf_web_socket | Pure Dart. | 2026-04-17 |
| string_scanner | 1.4.1 | BSD-3-Clause | yaml, analyzer | Pure scanner. | 2026-04-17 |
| sync_http | 0.3.1 | BSD-3-Clause | integration_test (via webdriver) | Dev-only. Pulled transitively by `integration_test` → `webdriver`. Synchronous HTTP client (pure Dart) used by webdriver for blocking JSON-wire-protocol calls. License preamble: "Copyright 2017, the Dart project authors" + BSD 3-clause. Zero runtime network in MirkFall — test-harness only, never linked into release APK/IPA. Added 2026-04-21 with `integration_test` (Phase 07 plan 07-07). | 2026-04-21 |
| term_glyph | 1.2.2 | BSD-3-Clause | string_scanner | Pure Dart. | 2026-04-17 |
| test_api | 0.7.10 | BSD-3-Clause | test, flutter_test | Dev-test-only. | 2026-04-17 |
| test_core | 0.6.16 | BSD-3-Clause | test | Dev-test-only. | 2026-04-17 |
| timezone | 0.11.0 | BSD-2-Clause | flutter_local_notifications | Pure timezone DB. | 2026-04-17 |
| typed_data | 1.4.0 | BSD-3-Clause | crypto | Pure Dart. | 2026-04-17 |
| url_launcher_linux | 3.2.2 | BSD-3-Clause | file_picker (indirect) | Linux-only surface. | 2026-04-17 |
| url_launcher_platform_interface | 2.3.2 | BSD-3-Clause | url_launcher_linux | Platform interface. | 2026-04-17 |
| url_launcher_web | 2.4.2 | Apache-2.0 | file_picker (indirect) | Web-only surface. | 2026-04-17 |
| url_launcher_windows | 3.1.5 | BSD-3-Clause | file_picker (indirect) | Windows-only surface. | 2026-04-17 |
| uuid | 4.5.3 | MIT | drift | Pure Dart UUID. | 2026-04-17 |
| vector_math | 2.2.0 | BSD-3-Clause | flutter | Pure math. | 2026-04-17 |
| vm_service | 15.1.0 | BSD-3-Clause | test, build_runner | Dev-only. | 2026-04-17 |
| watcher | 1.2.1 | BSD-3-Clause | build_runner | Dev-only. | 2026-04-17 |
| web | 1.1.1 | BSD-3-Clause | multiple web surfaces | Pure Dart web interop. | 2026-04-17 |
| web_socket | 1.0.1 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| web_socket_channel | 3.0.3 | BSD-3-Clause | shelf_web_socket | Dev-only. | 2026-04-17 |
| webdriver | 3.1.0 | Apache-2.0 | integration_test | Dev-only. Pulled transitively by `integration_test` for optional WebDriver-driven integration runs (browser + native). Pure-Dart Apache-2.0 implementation by the Google dart-lang team. No telemetry; spawns nothing unless the test harness explicitly drives it. Test-harness only — never linked into release APK/IPA. Added 2026-04-21 with `integration_test` (Phase 07 plan 07-07). | 2026-04-21 |
| webkit_inspection_protocol | 1.2.1 | BSD-3-Clause | test | Dev-only. | 2026-04-17 |
| win32 | 5.15.0 | BSD-3-Clause | Windows-only surfaces | Win32 FFI bindings. | 2026-04-17 |
| win32_registry | 2.1.0 | BSD-3-Clause | device_info_plus (Windows) | Windows registry FFI helpers used by device_info_plus to read OS version. License file: "BSD 3-Clause License / Copyright (c) 2023, Halil Durmus". Windows-only; not shipped on Android/iOS. Added 2026-04-19 with device_info_plus 12.4.0. | 2026-04-19 |
| xdg_directories | 1.1.0 | BSD-3-Clause | path_provider_linux | Linux-only directory resolution. | 2026-04-17 |
| xml | 6.6.1 | MIT | flutter_local_notifications (via timezone) | Pure Dart XML parser. After `flutter_map` drop (Phase 07 plan 07-01), `xml` is still pulled transitively by `flutter_local_notifications` 21.0.0 (for Linux/Windows XML config). Verified by `flutter pub deps --no-dev --style=tree`: `flutter_local_notifications → xml 6.6.1`. Zero network. | 2026-04-20 |
| yaml_edit | 2.2.4 | BSD-3-Clause | riverpod_lint | Dev-only. Dart-team package for YAML edits (used by lint quick-fix output). | 2026-04-18 |

## Bundled assets (non-pub)

Assets bundled inside the APK/IPA that are **not** resolved by `flutter pub get`. They ship under `assets/maps/` and are out of scope for `tool/check_dependencies_md.dart` (which only reconciles `pubspec.lock`). This section documents their licensing so the audit trail stays in one place.

| Asset bundle | Upstream + pin | License | Audit notes | Date |
|--------------|----------------|---------|-------------|------|
| Protomaps basemaps-assets — fonts | github.com/protomaps/basemaps-assets (pinned by commit SHA, see `tool/prepare_style.dart` README) | SIL Open Font License 1.1 (OFL-1.1) | Phase 07 plan 07-01 — glyph PBF files copied verbatim into `assets/maps/glyphs/<fontstack>/<range>.pbf`. OFL-1.1 is on the CLAUDE.md allowlist (compatible with the BSD/MIT/Apache/Unlicense set for asset-level bundling; it does NOT impose itself on the host application because Dart source is not "Font Software" in OFL terms). Upstream `fonts/OFL.txt` inspected at pin-time. Attribution carried in the app's About/Legal screen alongside the OSM + Protomaps copy (Phase 15). | 2026-04-20 |
| Protomaps basemaps-assets — sprites | github.com/protomaps/basemaps-assets (same pinned commit SHA) | CC0-1.0 | Phase 07 plan 07-01 — sprite PNG + sprite.json copied verbatim into `assets/maps/sprites/`. CC0-1.0 waives all rights; no attribution required. | 2026-04-20 |
| Protomaps basemaps style (neutral variant) | github.com/protomaps/basemaps (style skeleton repo) | BSD-3-Clause (software) + CC0-1.0 (map design) | Phase 07 plan 07-01 — the frozen 8-layer JSON style ships as `assets/maps/style.json`. Software = style JSON schema authoring; the cartographic *design* (colours, widths, z-order choices) is CC0-1.0 per Protomaps' stated policy. Attribution carried alongside OSM attribution. | 2026-04-20 |
| OSM data (bundled inside world.pmtiles + country .pmtiles) | openstreetmap.org + Protomaps build pipeline | ODbL 1.0 | Phase 07 plan 07-01 — The `assets/maps/world.pmtiles` bundle + every `<alpha3>.pmtiles` downloaded via the catalog pipeline contains vector tiles derived from OpenStreetMap. **MAP-03 requires** the app's About/Legal screen + on-map attribution icon to carry `© OpenStreetMap contributors` with a link to openstreetmap.org/copyright. Attribution lives in `lib/presentation/widgets/map_attribution_icon.dart` (Phase 07 plan 07-06 scope) and in the About screen (Phase 15). | 2026-04-20 |
| World bundle PMTiles (z0-2) | `C:\claude_checkouts\files_for_mirkfall\world-z2.pmtiles` (user-provided) | Data = ODbL 1.0 (OSM via Protomaps) | Phase 07 plan 07-01 — 856 KB zoom-0-through-2 world tile bundle. Copied byte-identical into `assets/maps/world.pmtiles`; sha256 emitted at build-time into `lib/config/world_bundle_sha256.dart` by `tool/generate_world_sha256.dart`. Non-deletable floor per MAP-07. | 2026-04-20 |
| Country polygons (bounding simplification) | `C:\claude_checkouts\countries\data\<alpha3>.geo.json` (user-provided, derived from OSM admin boundaries) | ODbL 1.0 (OSM derivation) | Phase 07 plan 07-01 — simplified GeoJSON polygons used by `country_resolver.dart` (Phase 07 plan 07-03 scope) for viewport-center → alpha3 decisions. Simplification done one-shot via `mapshaper` or equivalent; ≤ 5 MB total budget. Attribution covered by the same OSM ODbL notice as the PMTiles bundles. | 2026-04-20 |

## Tooling / GitHub Actions

Third-party GitHub Actions to be used by the CI pipeline (Plan 01-04).
These entries are audited separately from `pubspec.lock` and are ignored
by `tool/check_dependencies_md.dart`.

| Action | Version | License | Notes |
|--------|---------|---------|-------|
| actions/checkout | v4 | MIT | Standard repo checkout. https://github.com/actions/checkout |
| actions/setup-java | v4 | MIT | Java 17 for Android Gradle. https://github.com/actions/setup-java |
| actions/upload-artifact | v4 | MIT | APK upload. Re-audit for release artifacts in Phase 15. https://github.com/actions/upload-artifact |
| maxim-lobanov/setup-xcode | v1 | MIT | Pins Xcode on iOS job. https://github.com/maxim-lobanov/setup-xcode |
| subosito/flutter-action | v2 | MIT | Flutter install in CI. https://github.com/subosito/flutter-action |
