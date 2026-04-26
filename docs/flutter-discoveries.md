# Flutter discoveries — MirkFall lessons learned

**Captured:** 2026-04-26
**Project of origin:** MirkFall — Flutter app under GOSL v1.0, cross-platform (Android primary, iOS via sideload), GPS fog-of-war map.
**Audience:** the Claude agent ramping up on the user's *next* Flutter project.
**Scope:** non-obvious gotchas we hit on MirkFall and the fixes that worked. Each entry cites the commit / bug doc / file that proves the lesson exists in this codebase, so a sceptical reader can verify before applying it elsewhere.

Mark "**MirkFall-specific:**" entries are tied to this app's domain (geo, fog rendering, polygon resolver). Everything else is **Cross-project lesson:** — useful in any Flutter project of similar shape (mobile-first, sideloaded iOS, real-time / animated UI, file-based logging).

---

## 1. iOS sideload reality

### 1.1 You cannot ship `--debug` builds via SideStore — `kDebugMode` is always false in any installed binary

**Cross-project lesson.** Without a paid Apple Developer account, the only iOS distribution path is `flutter build ios --release --no-codesign` packaged as an unsigned IPA, then sideloaded via SideStore / AltStore / Sideloadly which re-sign at install time with a free Apple ID. The free Apple ID profile only honours AOT-compiled binaries — JIT (debug-mode Dart VM) is rejected by the device. CI in this repo enforces this in `.github/workflows/ci.yml:408` (`flutter build ios --release --no-codesign`).

The trap: it is intuitive to gate a debug affordance on `if (kDebugMode) { ... }`. In a sideloaded MirkFall install, that branch is *always* dead code. We hit this directly with the live shader tuner: it was gated on `kDebugMode` in commit `af6be15`, then immediately ungated in commit `503dcd0` because the icon was permanently invisible on every device install. The commit body documents this verbatim: "Solo-dev with sideload as the only distribution channel means every install IS a dev build."

**For the next agent.** Do NOT gate developer affordances on `kDebugMode` if the app is distributed via sideload. Use one of: (a) unconditionally show the affordance during the dev phase and remove it before public distribution, (b) gate on a runtime SharedPreferences flag flipped by an in-app gesture (the 7-tap easter egg pattern in `lib/infrastructure/logging/file_logger.dart:48` `kDebugLoggingPrefsKey`), (c) gate on a `--dart-define=DEBUG_UI=true` baked into the build (still AOT, but customisable per CI artifact). The logger uses pattern (b): `const debugDefine = bool.fromEnvironment('DEBUG'); final verboseFromPrefs = prefs.getBool(kDebugLoggingPrefsKey) ?? false; Logger.root.level = (debugDefine || verboseFromPrefs) ? Level.ALL : Level.INFO;` (file_logger.dart:60-64).

### 1.2 iOS sandbox container UUIDs can shift between launches

**Cross-project lesson.** On iOS, the absolute path to the app's documents directory contains a container UUID (`/var/mobile/Containers/Data/Application/<UUID>/...`). Apple does not guarantee this UUID is stable across reinstalls or restores from backup, and there are anecdotal reports it can change at launch in unusual conditions (Flutter issue #50268 referenced in `.planning/research/PITFALLS.md`). Storing absolute file paths in the DB or in shared prefs is therefore wrong on iOS.

**For the next agent.** Always store paths as **relative-to-docsDir**, computed absolute at read-time via `p.join(docsDir, relativePath)`. This is mandated in `CLAUDE.md` (the path-naming convention with `xxxFilename` for absolute, `xxxBasename` for filename) and codified in PITFALLS.md item 5 (orphaned photos). For diagnostic logs, capture the resolved absolute path of the active log file as the very first record at bootstrap, so a reader can cross-check at read-time that they are looking at the same path that was written to — this is exactly what `lib/infrastructure/logging/file_logger.dart:91-95` does (commit `16db03c`).

### 1.3 The IPA pipeline is "zip Payload/Runner.app", nothing fancier

**Cross-project lesson.** An unsigned `.ipa` for sideload is just `Payload/Runner.app` zipped — no entitlement injection, no provisioning profile, no codesign step. See `.github/workflows/ci.yml:421-433`. Sideloaders re-sign with a free Apple ID at install time. Free Apple ID limitations to remember: 7-day app lifetime before re-signing required, max 3 sideloaded apps per Apple ID, no push, no CloudKit, no associated-domains.

**For the next agent.** If the next project also targets sideload distribution, copy the `Package unsigned IPA for sideloading` step from `.github/workflows/ci.yml`. The `macos-26` runner is required (not `macos-14`) because of `device_info_plus 12.4.0` using `[NSProcessInfo isiOSAppOnVision]` declared only in iOS 26.1 SDK — see the inline comment at `.github/workflows/ci.yml:309-322`.

---

## 2. File logging on Flutter — what we had to do to make it reliable

This was three weeks of intermittent log loss. Capturing every step.

### 2.1 `IOSink` + `Stream.listen(asyncCallback)` is fundamentally wrong for per-record file logging

**Cross-project lesson.** The natural-looking Dart pattern for a file logger is:

```dart
final sink = file.openWrite(mode: FileMode.append);
Logger.root.onRecord.listen((rec) async {
  sink.writeln(jsonEncode(rec));
  await sink.flush();
});
```

This contains TWO independently-fatal bugs:

**(a) `Stream.listen` does NOT await async callbacks.** If two `LogRecord`s arrive back-to-back (very common when an event handler emits multiple log lines), the second invocation of the handler enters its body before `await sink.flush()` from the first invocation has resolved. Concurrent writes against a single `IOSink` raise `StateError: StreamSink is bound to a stream`. Standard catch-and-log handlers then null the sink, after which ~99% of records are dropped silently for the remainder of the session.

**(b) `IOSink.flush()` is NOT `fsync(2)`.** It only drains userspace buffers into the kernel page cache. On iOS, when the OS is under memory pressure (in our case during a 5.2 GB pmtiles install), jetsam discards the page cache. Records written but not yet fsync'd are lost. The OS will SIGKILL the app while the file appears to contain only a fraction of what was logged.

Both defects manifested in MirkFall as "user shipped a 4-line log when the session generated thousands of records." See `docs/phase09-bug-tracking/BUG-009-cheap-fog-visual.md` row #13 in the chronological commit table for the full detective trail.

**For the next agent.** Do not build a Flutter file logger on `IOSink`. The fix in commit `16db03c` (`lib/infrastructure/logging/file_logger.dart`) replaces the entire pipeline with `RandomAccessFile` opened in `FileMode.writeOnlyAppend`, with a **synchronous** record handler that does `raf.writeStringSync(line); raf.flushSync();` per record. `flushSync` on a `RandomAccessFile` is documented as the real `fsync(2)` (durable to disk). Synchronous handler means `Stream.listen` cannot re-enter — no race possible. Per-call overhead is sub-millisecond on modern flash; acceptable for a single-user diagnostic app. The "non-blocking ring-buffer + flusher isolate" architecture is documented as a future evolution but was not needed in practice.

### 2.2 Don't trust periodic flush timers + threshold counters as a fix

**Cross-project lesson.** When we first noticed log loss on device, the obvious-looking fix was "flush more often": commits `fb35154` (force-flush on lifecycle + 2 s timer + threshold lowered to 5 records) and `cbde5bf` (threshold dropped to 1 because 5 still wasn't enough). These were workarounds chasing a symptom — the underlying race was still there, the periodic flush just shrank the window in which records could be lost. Commit `16db03c` deleted the timer, the `kFileLoggerFlushEveryNRecords` constant, the `kFileLoggerFlushPeriodSeconds` constant, and the entire periodic-flush regression test, because they became redundant once each record was sync-flushed at write-time.

**For the next agent.** When you find yourself adding a periodic flush, ask whether you have an architectural problem (asynchronous handler that should be synchronous, sink that doesn't fsync, missing lifecycle hook) instead of a tuning problem. Periodic flush is a band-aid; the underlying API is either correct or wrong.

### 2.3 Bootstrap can run more than once — beware parallel log files

**Cross-project lesson.** If your app has any background-execution path (Android boot-completed receiver, iOS significant-change wake, desktop multi-window, even hot-reload during dev), Flutter can create a second engine that re-runs `main()`. Each `main()` call re-bootstraps the logger and produces a parallel log file. The user will then send you ONE of N files and you will spend an afternoon convinced their session emitted no logs.

We hit this with the Android boot-completed watchdog isolate. Fix in commit `16db03c` (`lib/infrastructure/platform/boot_completed_watchdog.dart`): the watchdog isolate skips `FileLogger.bootstrap()` entirely and routes its log records through `dart:developer log()` instead, with a `Logger.root` listener that pipes records to `developer.log` so warnings still reach Xcode console / Logcat without producing a parallel file.

**For the next agent.** Audit every entry point that calls `runApp()` or starts an isolate. Decide which ones own the file logger and which ones should defer to the shared sink (or use `dart:developer` only). Make `bootstrap()` idempotent — `lib/infrastructure/logging/file_logger.dart:82-88` closes the previous handle and unsubscribes before re-arming, covering hot-reload and tests that re-bootstrap between cases.

### 2.4 Make `flush()` a cheap no-op rather than removing it from the API

**Cross-project lesson.** Several call-sites had grown a habit of calling `await logger.flush()` before handing the file path off to a share-sheet, before lifecycle suspension, before exporting diagnostics. Once every record is `flushSync`'d at write time, those calls become semantically empty — but ripping the entry-point out of the API is a churny refactor. Instead, keep `flush()` as a documented no-op (`file_logger.dart:127-135`). Call-sites stay correct, no behaviour change, future evolution to a buffered architecture can re-implement `flush()` without another caller-site sweep.

**For the next agent.** Deprecating an entry-point in a logger is rarely worth the diff. Make it a no-op with a docstring explaining why.

---

## 3. CI / build pipeline

### 3.1 Flutter version drift between local and CI breaks `dart format` non-determistically

**Cross-project lesson.** Local dev was on Flutter 3.41.7 (Dart 3.11.5), CI was pinned to 3.41.7's predecessor 3.41.5. The two formatters produce subtly different output. Result: every push fails `dart format --set-exit-if-changed`, forcing a "dart format align" commit that the next push then re-misaligns. This bit us repeatedly until commit `a965012`, which bumped CI to 3.41.7 and reformatted 87 files in the same commit (no logic changes — pure reflow).

**For the next agent.** Pin the Flutter version EXACTLY in CI to whatever version the dev machine runs. Not `stable`, not a major minor — the full triple. `.github/workflows/ci.yml:38` shows `flutter-version: '3.41.7'`. If the dev machine upgrades Flutter, that upgrade ships in the same commit as the CI bump or the user gets a CI flake on the next push.

### 3.2 Gzip OS byte differs Windows vs Linux — kills byte-identical fixture comparisons

**Cross-project lesson.** Per RFC 1952 §2.3.1, byte 9 of a gzip stream is the OS field. Dart's `GZipCodec` writes it based on the host platform: `0x0A` (Windows NT) on Windows, `0x03` (Unix) on Linux. If you commit a gzipped fixture built locally on Windows and CI rebuilds the fixture on Linux for a byte-comparison freshness check, you get a single-byte diff at offset 9 with no actual data difference. CI run 24929833271 hit this and burned an hour of confusion. Fix in commit `f152445` (`tool/fixtures/build_50k_tiles.dart`): force OS=`0xFF` ("unknown") after `gzip.encode` for cross-platform reproducibility.

**For the next agent.** If your CI compares any gzipped artifact byte-by-byte, normalise byte 9 to `0xFF` at build time. The trap is that the data IS identical — only the metadata header differs, which makes the failure inscrutable until you read the RFC.

### 3.3 `package:flutter_test` vs `package:test` — same `test()` name, different harness

**Cross-project lesson.** A test file under `test/domain/` that does pure-Dart assertions can be run by either `flutter test` (with the Flutter binding) or plain `dart test` (without). They use the same `test()` and `expect()` API, but the import is different:

- `package:flutter_test/flutter_test.dart` — pulls `dart:ui`, requires the Flutter binding, fails to load under plain `dart test` with errors like "dart:ui not found"
- `package:test/test.dart` — pure Dart, no `dart:ui`, no `Canvas`, no `rootBundle`

In MirkFall, CI splits the test suite: `flutter test` for everything Flutter-bound, plain `dart test` for `test/domain/` and select `test/infrastructure/` subdirs (see `.github/workflows/ci.yml:188-212`). A test that imports `flutter_test` but lives in a plain-Dart subdir fails to load under the plain runner. Commit `851c7b4` is the fix: swap the import. Two `test/domain/` files use Canvas / rootBundle and are EXCLUDED from the plain-dart runner with explicit `! -path` filters at `.github/workflows/ci.yml:201-203`.

**For the next agent.** Decide for each test file whether it needs the Flutter binding or not, then import accordingly. If the project's CI splits the runners (highly recommended for fast feedback on pure-Dart logic), the `flutter_test` import implies "this file goes through `flutter test`" and the wrong directory placement breaks the load step.

### 3.4 `pumpAndSettle` deadlocks when a `Ticker` is alive

**Cross-project lesson.** `WidgetTester.pumpAndSettle()` waits for the framework to reach idle. A widget tree containing a continuously-firing `Ticker` (a 60 fps `AnimationController.repeat()` for example) NEVER reaches idle — `pumpAndSettle` will hit its 10-minute test default timeout. This bit MirkFall in `integration_test/airplane_mode_test.dart` after the `MirkOverlay` Ticker shipped, fixed in commit `5c81c65`: replace `pumpAndSettle` with a fixed cadence of `tester.pump(Duration(milliseconds: ...))` calls.

**For the next agent.** If your app has any animated `CustomPaint` / `Ticker` / `AnimationController.repeat()`, scan integration tests for `pumpAndSettle` and replace with fixed-cadence pumps. The symptom (12-minute timeout instead of an actual assertion failure) is unhelpfully cryptic.

### 3.5 GitHub Actions concurrency + auto-cancellation: a "failed" run isn't always a real failure

**Cross-project lesson.** `.github/workflows/ci.yml:10-12` sets `concurrency: cancel-in-progress: true` on `${{ github.workflow }}-${{ github.ref }}`. When two pushes land within 30 seconds on the same branch, the first run is auto-cancelled mid-execution — `gh run watch` reports it as "failure" with exit code != 0. This is not a real failure; the second push's run is the relevant one.

**For the next agent.** When inspecting CI status programmatically (`gh run list --json conclusion`), filter for `conclusion: cancelled` distinctly from `failure`, or compare the run's `head_sha` to the latest commit on the branch and ignore older runs.

### 3.6 `fail-fast` is a matrix-only knob and does not apply to standalone `needs:` chains

**Cross-project lesson.** When you have three jobs `gates / android / ios`, you might assume `fail-fast: true` will cancel `android` if `ios` fails. Wrong — `fail-fast` only applies inside a matrix block. Standalone jobs use `needs:` for ordering and run in parallel by default. See the explanatory comment at `.github/workflows/ci.yml:14-23`. In MirkFall this is intentional: if `android` fails while `ios` is still running, `ios` continues so a single CI run surfaces both platform breakages instead of masking one behind the other.

**For the next agent.** This is the desired behaviour for cross-platform builds. Document it in the workflow comment so future maintainers don't try to "fix" it.

---

## 4. Shader pipeline (Impeller / FragmentShader)

The TIER 2 fog shader iteration in BUG-009 surfaced a cluster of pitfalls that apply to any Flutter project using `ui.FragmentShader`.

### 4.1 The Paint fallback path silently masks shader bugs

**Cross-project lesson.** When `FragmentProgram.fromAsset()` fails (compilation error, missing `flutter.shaders:` declaration in `pubspec.yaml`, Impeller fallback to Skia where the `.frag` doesn't compile, etc.), the typical pattern is to fall back to a plain `Paint()` so the renderer still produces something visible. This is correct — but unless you LOG the path you're on, you cannot tell at a glance whether the user is seeing the shader output or the fallback. Multiple BUG-009 walks were spent chasing visual bugs that turned out to be "the fallback is rendering and producing the bug."

**For the next agent.** Instrument the path-transition with INFO logs (not FINE) so the file logger captures it: `paint(): path transition (initial) → shader` vs `paint(): path transition (initial) → fallback`. See commit `7b6d819` and the diagnostic table in BUG-009 row #12. Also log the SHADER load result: `FogShaderService` in `lib/infrastructure/mirk/shader/fog_shader_service.dart` logs success / failure on `FragmentProgram.fromAsset` exactly because Flutter issue #108037 occasionally corrupts the asset on hot-reload.

### 4.2 Drift speeds need empirical tuning, not first-principles guessing

**MirkFall-specific (but the general pattern is cross-project).** A correctly-implemented shader pipeline with mathematically-correct constants can still produce visually-static output if the drift / advection speeds are wrong relative to the noise scale. We bumped the drift constants ~4x in commit `0bb407a` after a UAT walk where the fog appeared frozen — the math was right, the speeds just weren't perceptible to a human eye over the timescale of looking at the screen.

**For the next agent.** Build a live tuner UI EARLY for any animated shader, not late. We landed one in commit `af6be15` (`MirkRuntimeTunables.instance` shadowing the compile-time constants in `lib/config/constants.dart`) only after burning a dozen build/sideload/walk cycles. Each cycle is ~15 minutes (Flutter build + CI artifact wait + IPA download + sideload + walk + observe). A tuner with sliders saves dozens of cycles in a single afternoon.

### 4.3 Three classic shader-math bugs to check explicitly when colour-collapse looks "flat"

**Cross-project lesson.** When a colour-blend shader produces a uniform output instead of a textured one, three common math bugs cumulate:

1. **Range mismatch.** A noise function that returns `[0,1]` accumulated through FBM with weights summing to e.g. 0.875 produces `density ∈ [0, 0.875]`. If you then do `dN = density * 0.5 + 0.5` expecting a `[0,1]` mapping you actually get `[0.5, 0.94]` — clamped, low contrast.
2. **Double-applied uniform.** A scale uniform `uHueStrength` applied inside a helper that computes `hueShift` AND again at the mix call-site (`mix(..., uBase.rgb, abs(hueShift) * uHueStrength)`) is squared, then a directional `mix(..., uBase, ...)` flattens any signed variation back toward the base colour.
3. **Same trap on the additive side.** `(uHighlight - uShadow) * shadeDelta * uLightStrength` where `shadeDelta` already incorporates `uLightStrength` — the strength gets cubed and then clamps to white at any non-trivial value.

All three landed in MirkFall's `assets/shaders/atmospheric_fog.frag` simultaneously and produced a uniform grey sheet. Fix in commit `76dfca4` — the commit body documents each bug separately. The diagnostic that found them was a debug toggle (`kMirkFogDebugOutputDensity`) that emitted raw `dN` as RGB so we could see whether noise was generating at all (it was).

**For the next agent.** When debugging a shader that produces a flat output, add a debug uniform that emits intermediate values directly instead of going through the colour-blend. Fastest way to localise which stage collapses.

### 4.4 Impeller startup-fail guard: no unused uniforms

**Cross-project lesson.** Impeller is stricter than Skia about shader hygiene. A `.frag` that declares uniforms it does not reference will cause Impeller to fail program creation at startup with a non-obvious error. We hit this when we declared all 40 uniform slots upfront in commit `a07dff9` and only used 38 — the build succeeded, the runtime startup failed silently. Fix: remove unused uniform declarations OR reference them in a no-op (`gl_FragColor.a += 0.0 * uUnusedUniform`).

**For the next agent.** Treat unused uniform declarations as a compile-time error. Lint the `.frag` if your project has more than one shader.

### 4.5 SDF visible stepping cannot be fully fixed by post-processing if the source data is on a coarse grid

**Cross-project lesson.** When you build a signed distance field from a coarse rasterised seed (e.g. cells written as binary 0/1 on a 64×64 grid), the rectangular character of those cells is baked into the distance field at every iso-surface, not just the boundary line. Downstream attempts to hide the stepping — shader-side `smoothstep` over a wider band, ordered dither at sample time, post-chamfer separable Gaussian blur on the float `signedDistPixels` array before encoding to uint8 — each soften the corners but cannot remove the rectangular character because the SDF distances themselves encode the rectangle topology. A 5×5 Pascal Gaussian (σ ≈ 1.0) over an SDF where each cell projects to 20-30 pixels has a blur radius (3-5 px) that's an order of magnitude smaller than the feature it would need to dissolve.

We hit this end-to-end in MirkFall's BUG-009. The shader-side dither + smoothstep band (`4736342`) reduced banding to acceptable, but the rectangle silhouette stayed visible at small reveal radii. The post-chamfer Gaussian (`a9c7ced`) was reverted (`118b95a`) because it changed the boundary glow band's aspect globally without fixing the steppy character. The architectural fix tracked under `BUG-010` is to rasterise cells as **circles** (coverage-based circle fill at SDF build time) or to drop the bitmap entirely for a continuous geometry (`(lat, lon, radius, ts)` discs + `union-of-discs` SDF directly).

**For the next agent.** When you find yourself adding the third post-processing layer to hide stepping in an SDF, stop and audit the source data. If the source is rasterised on a grid coarse enough that a single feature projects to N pixels of the SDF (N ≈ 20-30 in MirkFall's case), no kernel of reasonable cost (radius 3-5 px) can dissolve it. The fixes that work: (a) rasterise the source as a smoother shape (circle instead of rectangle) BEFORE the chamfer pass, (b) compute the SDF directly from continuous geometry (`min over primitives of (dist(p, primitive) - radius)`), or (c) increase the SDF resolution so each source cell projects to fewer pixels and reasonable blurs CAN dissolve it (linear cost increase). Post-process band-aids cost engineering attention without paying off architecturally.

### 4.6 `FlutterFragCoord()` and the OpenGLES Y-flip guard

**Cross-project lesson.** Use `FlutterFragCoord()` instead of `gl_FragCoord` in Flutter `.frag` files. The former is the abstraction that handles the OpenGLES vs Metal Y-flip difference. Bare `gl_FragCoord` produces an output that is upside-down on one platform and right-side-up on the other. See `assets/shaders/atmospheric_fog.frag` in commit `a07dff9`.

**For the next agent.** Always `FlutterFragCoord()`. If you see the shader output flipped vertically when porting between iOS and Android, this is the cause.

---

## 5. CustomPaint / RepaintBoundary / IgnorePointer

### 5.1 `CustomPaint` is hit-test-opaque by default and will eat all pointer events

**Cross-project lesson.** A `CustomPaint` placed over an interactive widget (e.g. a map) blocks every gesture before the underlying widget can see them. There is no warning, no log, no error — gestures just die. We hit this in BUG-003 issue C: MirkOverlay was painted on top of MapLibre and the entire map became frozen (no pan, no pinch, no zoom). Fix in commit `6298f05`: wrap the overlay subtree in `IgnorePointer(ignoring: true, child: ...)` at `lib/presentation/screens/map_screen.dart`.

**For the next agent.** Any visual-only `CustomPaint` overlay must be wrapped in `IgnorePointer`. Add a regression test that taps through the overlay and asserts the underlying widget receives the gesture (see `test/presentation/widgets/mirk_overlay_pointer_passthrough_test.dart`).

### 5.2 Per-tile MaskFilter passes accumulate at seams and produce a visible damier

**MirkFall-specific (but the general pattern is cross-project).** When you draw N adjacent rectangles each with its own `MaskFilter.blur(BlurStyle.inner, sigma)`, the blur passes from adjacent rects bleed into each other at the seam, halving alpha at the boundary line — visible as a checkerboard / grid pattern. The fix is structural: build ONE composite path for the entire visible region and apply MaskFilter to that single silhouette. Commit `2811900` (`buildViewportFogClipPath`) and the BUG-003 doc cover this in detail.

**For the next agent.** If you are tiling a `CustomPaint` and applying a per-tile filter, the filter belongs on the union, not on each tile. Compose the path first, filter once.

### 5.3 `BlurStyle.inner` leaves the hole side perfectly sharp

**Cross-project lesson.** `BlurStyle.inner` erodes alpha INWARD from each path edge — the outer contour stays sharp on the hole side. If the visual goal is "rounded reveals" (smooth blob inside fog), `inner` produces the opposite: soft fog edge, sharp hole edge. Use `BlurStyle.normal` for symmetric blur that rounds the hole corners. Commit `5dc1a41` is the one-liner fix; the bug `BUG-006-square-reveal-instead-of-circle.md` documents the diagnostic.

**For the next agent.** Read the BlurStyle enum docs carefully. `normal` is symmetric, `inner` erodes inward, `outer` dilates outward, `solid` paints fully on top. Wrong choice = wrong silhouette.

---

## 6. State management — Riverpod 3.x

### 6.1 `await ref.read(provider.future)` BEFORE you start any subscription that depends on it

**Cross-project lesson.** A `keepAlive: true` family provider with an async bootstrap (in our case, a Drift store backed by `path_provider`) returns null synchronously on cold launch until its bootstrap settles. If a controller's `start()` method calls `ref.listen(otherProvider, ...)` and the listener body does `ref.read(asyncProvider).value` synchronously, the value is null on the first GPS fix and the fix is silently dropped.

This was BUG-009 walk #7 / commit `935b9de`. The first 20 m initial reveal of every cold-launched session never landed because `ActiveSessionController.start()` did not await `revealedTileStoreProvider.future` before subscribing to GPS. The second session worked fine because the keep-alive cache was warm.

**For the next agent.** Any controller with a `start()` method that depends on async providers must `await provider.future` for each one BEFORE subscribing to event streams that will read them. Upgrade `if (provider == null) return;` early-returns from silent to `_log.warning` so a regression is visible in the user-shipped log file rather than silently dropping events.

### 6.2 Debounce vs throttle on a continuous gesture stream

**Cross-project lesson.** A `Timer` debounce on a viewport-update stream cancels and reschedules on every emission. During a continuous gesture (60 Hz), the timer never fires until the gesture ends — the consumer sees ONE update at gesture release and the UI snaps. The user perceives this as "the overlay doesn't track the gesture." Fix in commit `1f55804` (BUG-005): replace debounce with leading-edge throttle (first emission fires immediately, subsequent emissions inside the window coalesce into one trailing refresh, trailing refresh chains into a fresh window for sustained ~20 Hz cadence).

**For the next agent.** Debounce = "fire after silence." Throttle = "fire at most once per window." For real-time UI tracking, you want throttle with leading edge. For "save when user stops typing," debounce. They are not interchangeable.

---

## 7. Test fixtures and flake mitigation

### 7.1 `Timer.periodic` polling races with controller backoff in tests

**Cross-project lesson.** When a test polls a state every 20 ms via `Timer.periodic` to flip a fake server's behaviour between requests, and the controller-under-test has its retry backoff pinned to `Duration.zero`, the controller's retry can fire BEFORE the next polling tick lands. The fake serves the pre-flip behaviour for both requests, the retry budget is exhausted, and the test fails non-deterministically on slow CI runners. We hit this in `test/infrastructure/downloads/download_soak_test.dart`, fixed in commit `9260ae4`.

**For the next agent.** When a test needs to coordinate state changes with a request-driven system, use a SYNCHRONOUS hook (`onRequestRecorded` callback in our case) that fires deterministically in the same microtask as the request. Polling is a flake source.

### 7.2 Software rasteriser does not execute fragment shaders

**Cross-project lesson.** `flutter test` uses a software rasteriser that does NOT execute `.frag` shaders. Pixel-level assertions on shader output simply do not run. Tests that assert "shader produces visible output at pixel (x,y)" will silently pass against a no-op or a fallback path, providing zero coverage of the actual visual behaviour. The right level for shader tests in `flutter test` is structural: shader loads, shader doesn't throw, fallback paints visible output. Visual quality is verified on real device sideload. See `test/infrastructure/mirk/noise_overlay_test.dart` and the explanatory note in BUG-009 resolution section "Verification."

**For the next agent.** Don't write pixel-level assertions on shader output in `flutter test`. Either (a) test structurally — shader loads, no throw, expected path taken — or (b) test on a real device via integration tests. Anything else is ceremony without coverage.

### 7.3 Drift schema verification needs a frozen snapshot per version

**Cross-project lesson.** `drift_dev schema dump` produces a JSON snapshot of the current schema. CI compares this against a checked-in `drift_schema_current.json` — if the current code's schema has drifted from what's committed, CI fails with a clear "regenerate this file" message. Critically, the `drift_schema_v{N}.json` per-version files are FROZEN historical snapshots. They are produced ONCE at version-bump time and NEVER touched by CI. If you let CI regenerate them, the next schema bump destroys round-trip migration tests. See the explanatory comment at `.github/workflows/ci.yml:80-99`.

**For the next agent.** Distinguish "current schema must match committed dump" (regeneratable) from "v1 / v2 frozen snapshots" (write-once, read-many, never CI-regenerated). Document this in the workflow comment so a future maintainer doesn't innocently bulk-regenerate.

---

## 8. MirkFall-specific gotchas (skip if next project is not a geo / mapping app)

### 8.1 First-match-wins polygon resolver: order by ascending bbox area

**MirkFall-specific.** A point-in-polygon resolver that iterates a frozen list and returns the first match must receive its polygons sorted by ASCENDING ring-bbox area, so a sub-region (e.g. France-Melun, ~0.04 deg²) wins over the containing country (France, ~140 deg²) when a GPS fix is inside both. See commit `b76169a` (`_rebuildResolver` reorders before construction).

### 8.2 The "10 TB of GPS points" model: don't store fixes, store revealed tiles

**MirkFall-specific.** A naive 1 Hz GPS logger over 4 h/day produces ~5M rows/year. The right model for fog-of-war is to store NOT the trajectory but the SET of revealed tiles, deduplicated. See PROJECT.md §9 and `.planning/research/PITFALLS.md` item 6. With a 64×64 bitmap per parent tile at zoom 14, a year of typical use stays under 10 KB. This is a structural decision that must be made before the schema is frozen.

### 8.3 64×64 bitmap resolution produces a "+" silhouette at small reveal radii

**MirkFall-specific.** The 19 m cell size at zoom 14 means a 25 m reveal radius covers ~1.5 cells — the silhouette is structurally a "+" of 5 cells regardless of how good the SDF / blur / shader is downstream. Fixing this requires moving to continuous geometry (union-of-discs) instead of a bitmap. See `BUG-010-cell-grid-resolution-blocky.md`. The next geo project should pick the storage resolution AFTER prototyping the smallest reveal radius the UX actually needs.

### 8.4 OSM tile server User-Agent and bulk-download policy

**Cross-project lesson (any OSM consumer).** OSM Operations blocks generic library default User-Agents without warning. Set a unique app-identifying UA in a single config place. Never bulk-download. `.planning/research/PITFALLS.md` item 8 has the full rejection-source citations.

### 8.5 OEM battery killers silently stop foreground services on ~70% of Android devices

**Cross-project lesson (any background-GPS app).** Xiaomi, Huawei, Samsung, OnePlus all have OEM-specific battery optimisers that kill foreground services regardless of `FOREGROUND_SERVICE_LOCATION` permission. Detect manufacturer via `Build.MANUFACTURER`, deep-link to OEM-specific settings, request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with rationale. Detect interruption on next launch and surface a "tracking was interrupted" banner. See `.planning/research/PITFALLS.md` item 7 and `dontkillmyapp.com`.

---

## 9. Things we deliberately rejected

Citing CLAUDE.md and `DEPENDENCIES.md` so the next agent doesn't re-evaluate from scratch.

- **All analytics / crash-reporting / RUM SDKs** — Firebase Analytics/Crashlytics/Performance, Sentry, Bugsnag, Mixpanel, Amplitude, Segment, AppsFlyer, Adjust, Branch, Kochava, Hotjar, FullStory, LogRocket. Forbidden by CLAUDE.md §Télémétrie. CI's `no_telemetry_test.dart` asserts no outbound HTTP in the idle flow.
- **All copyleft licenses** — GPL (any version), AGPL, LGPL with static linking, SSPL, CC-BY-NC. Forbidden by CLAUDE.md §Licences interdites. CI runs `dart run tool/check_licenses.dart` (`.github/workflows/ci.yml:64`) to scan transitive licenses on every build.
- **`flutter_map_tile_caching`** — GPL-3.0, despite being the standard tile-cache library. STACK.md documents the rejection.
- **`flutter_background_geolocation`** — requires a paid per-app license key for Android release builds, incompatible with GitHub-distributed GOSL apps. Use `geolocator` + a hand-rolled foreground service.
- **`GetIt` / global service locator** — CLAUDE.md §Dependency Injection forbids hidden global singletons. Use Riverpod providers as the DI container.
- **Cloud sync, gamification, ads, subscriptions** — anti-features per the project's GOSL philosophy.

---

## Appendix — the meta-lesson

A common thread runs through the BUG-009 iteration log: when the visible symptom changes ("fog is grey," "fog is too uniform," "fog snaps to position," "no fog at startup"), the temptation is to chase each symptom in isolation. The fastest path forward in practice was to invest one cycle in DIAGNOSTIC INSTRUMENTATION (the `paint() first invocation` / `paint() early-return state` / `path transition` logs in commit `7b6d819`) so the next walk produced a discriminating signal that pointed at ONE of the four hypotheses. Without that instrumentation, every walk was an undirected search over (data layer × renderer × shader × fallback × pipeline) — five axes, exponential in walks.

**For the next agent.** When a visible bug doesn't reproduce on the rasteriser and only shows up on real-device walks, the cost of one diagnostic-only commit is lower than the cost of a single misdirected fix-and-walk cycle. Instrument first.
