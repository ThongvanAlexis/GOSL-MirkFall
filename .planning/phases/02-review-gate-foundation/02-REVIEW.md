# Phase 02: Review Gate — Foundation Review

**Opened:** 2026-04-17
**Status:** open
**Closed:** (pending)

## 1. User-observed findings (IDE review)

*Captured verbatim at phase start, BEFORE Claude's audit.*

*Aucune observation utilisateur — l'user n'a pas identifié de point à revoir dans son IDE (codebase encore minimale, une seule page).*

## 2. Claude audit findings

*Recorded by Plan 02-02 Task 1 after the 4 parallel sub-agents returned. Four agents spawned in a single tool-use message. Totals: 5 Blockers, 24 Shoulds, 13 Coulds, 12 Noted = 54 findings.*

Format: `[severity] Title — 1-line explanation — file:line`. Severities: Blocker / Should / Could / Noted.

### Agent #1 — CI gate scripts + adversarial design

[Blocker] SPDX matching is case-sensitive — `_allowedSpdx.contains()` and compound splitter `\s+OR\s+` are case-sensitive; a future package declaring `license: apache-2.0` or `MIT or Apache-2.0` would go unresolved/misclassified — `tool/check_licenses.dart:129-130`

[Blocker] Compound-license `AND` semantics silently wrong — `spdx.split(RegExp(r'\s+OR\s+'))` treats `"Apache-2.0 AND GPL-2.0"` as a monolithic unknown token; a parenthesised `(MIT OR Apache-2.0)` keeps the parens and fails to match — `tool/check_licenses.dart:129-135`

[Blocker] Declared `license:` field bypasses the forbidden-marker scan — step 1 returns early on any non-empty `license:` value before step 2 can scan the LICENSE text; a package declaring `license: MIT` in pubspec but shipping a GPL LICENSE would pass — `tool/check_licenses.dart:176-180`

[Blocker] MPL detection never fires on LICENSE text, only on `_forbiddenSubstrings` miss — `Mozilla Public License` is in the forbidden list, so any legitimate MPL-2.0 package without a manual override returns `UNKNOWN-FORBIDDEN-MARKER`; a new Linux MPL transitive silently breaks CI without a clear "add override" message — `tool/check_licenses.dart:188-194`

[Should] Whitespace-only / empty license field not treated as unresolved — `license: See LICENSE file` / `license: unknown` passes straight through as a literal SPDX that fails the allowlist with a confusing message rather than surfacing as "needs manual audit" — `tool/check_licenses.dart:178-180`

[Should] `LicenseRef-*` / SPDX-with-exception expressions not handled — no documented behaviour for `LicenseRef-proprietary` or `GPL-2.0 WITH Classpath-exception-2.0`; falls through to "not in allowlist" with no hint — `tool/check_licenses.dart:129-135`

[Should] Exit-2 coverage for `check_licenses` weak — only `pubspec.lock missing` is tested; the `package_config.json missing` branch has no test — `tool/test/check_licenses_test.dart:119-123`

[Should] No exit-1 test for "unresolved package" branch — advisory message at `check_licenses.dart:121-124,148-154` is uncovered — `tool/test/check_licenses_test.dart:91-124`

[Should] No test for the manual-override path — `_manualOverrides` is the single mechanism keeping `dbus`/`geoclue`/`gsettings`/`flutter_plugin_android_lifecycle` green; zero test covers that branch — `tool/test/check_licenses_test.dart` (entire file)

[Should] Header check accepts ANY offset-zero byte-string match without validating trailing newline — `trimmed.startsWith(_expectedHeader)` passes for a file starting with `// Copyright ...details// hack injected on same line`; minor poison vector — `tool/check_headers.dart:14-16,55`

[Should] Header-check exclude patterns miss common codegen suffixes (`*.pb.dart`, `*.swagger.dart`, `*.chopper.dart`, `*.mocks.dart`) — hand-maintained list is aspirational, not exhaustive — `tool/check_headers.dart:18-26`

[Should] Header check does not exclude `ios/`/`android/` managed Dart files — if a dev ever runs `dart run tool/check_headers.dart .` from repo root, plugin `example/` fixtures would fail — `tool/check_headers.dart:28`

[Should] `check_dependencies_md` parses tables by `line.startsWith('| ')` with the space requirement — a markdown-lint fix collapsing the space would make every row invisible and the gate would report "everything in lock is missing" — `tool/check_dependencies_md.dart:59`

[Should] `check_dependencies_md` filters "tooling" rows by `d.contains('/')` — loose heuristic; a future path dependency containing `/` is silently ignored — `tool/check_dependencies_md.dart:86-88`

[Should] `check_dependencies_md` uses `cells[1]`/`cells[2]` without a column-count guard beyond `length < 4` — schema evolution breaks silently — `tool/check_dependencies_md.dart:60-69`

[Should] No test for the exit-2 `pubspec.lock missing` path in `check_dependencies_md` — only `DEPENDENCIES.md missing` covered — `tool/test/check_dependencies_md_test.dart:115-121`

[Should] No test for "dual licensing `OR` expression passes" in `check_licenses` — the compound-split logic has no fixture proving `Apache-2.0 OR BSD-3-Clause` resolves green — `tool/test/check_licenses_test.dart`

[Could] Forbidden-marker detection case-sensitive — `'GNU GENERAL PUBLIC LICENSE'` would miss a LICENSE titled `Gnu General Public License`; rare in practice — `tool/check_licenses.dart:65-70`

[Could] `_resolveSpdx` reads the entire LICENSE file into memory — for pathological multi-MB LICENSE in `pub-cache` allocates giant string; no stream reader — `tool/check_licenses.dart:188`

[Could] BOM detection only handles UTF-8 BOM (`\uFEFF`) — UTF-16 LE-encoded files (Windows PowerShell default) fail with a confusing message — `tool/check_headers.dart:54`

[Could] `runCheck` signature accepts a raw `List<String>` — no CLI-argument parsing layer; a future `--verbose`/`--help` flag needs restructuring — `tool/check_*.dart:75, 19, 34`

[Could] `_defaultRoots` doesn't include `integration_test/` — if added later (Phase 15 e2e), `.dart` files there escape the header check — `tool/check_headers.dart:28`

[Noted] Manual override `flutter_plugin_android_lifecycle: BSD-3-Clause` is NOT a platform-scope exception — it's a "heuristic defeated by LICENSE preamble" workaround; grouping it with the MPL-2.0-Linux-only entries collapses two distinct rationales into one map — `tool/check_licenses.dart:38-60`

[Noted] `MPL-2.0-Linux-only` synthetic SPDX is non-standard — any external license-scanning tool (FOSSA/ScanCode) flags as invalid; internal-only usage documented in both script and DEPENDENCIES.md — `tool/check_licenses.dart:28-33`

[Noted] Three MPL overrides target exact Linux-only transitive set (dbus/geoclue/gsettings) plus one non-MPL override — no creep to Android/iOS plugins — `tool/check_licenses.dart:43-59`

[Noted] Exit-code contract 0/1/2 respected by all three scripts, with the `check_headers` "no roots found" path correctly returning 2 (misconfig) — `tool/check_headers.dart:61-64`

[Noted] `check_dependencies_md` does not verify the Date column is recent — stale entries pass; CLAUDE.md policy-level, not script-level — `DEPENDENCIES.md:22-23`

[Noted] `tool/` is in header-check default roots but NOT in license-check scope — correct by design; `tool/test/` fixtures generate synthetic licenses in temp dirs — `tool/test/check_licenses_test.dart:99-102`

**Adversarial poison recipes (consumed by Plan 02-03):**

```
### Poison #1 — licenses gate
- Target gate: tool/check_licenses.dart
- Payload: On branch adversarial/02-licence-gpl-scan, add to pubspec.yaml under dependencies:
    multi_dropdown: 3.1.1
  Verify via pub.dev that multi_dropdown 3.1.x is still GPL-3.0 at commit time. Fallback:
  line_icons: 2.0.3 (also GPL-3.0) or iconsax: 0.0.8. Run flutter pub get so pubspec.lock
  + .dart_tool/package_config.json update; commit all three. Do NOT edit DEPENDENCIES.md
  (would trigger Gate #3 first and mask Gate #1 failure).
- Expected exit code: 1
- Expected log: "check_licenses: N violation(s):" + "  - multi_dropdown: UNKNOWN-FORBIDDEN-MARKER:
  GNU GENERAL PUBLIC LICENSE". Failing CI step: "Check licenses (GPL/AGPL/copyleft scan)".
- Rollback: git checkout main && git branch -D adversarial/02-licence-gpl-scan
  && git push origin --delete adversarial/02-licence-gpl-scan

### Poison #2 — headers gate
- Target gate: tool/check_headers.dart
- Payload: On branch adversarial/02-header-missing, create
    lib/presentation/widgets/poison_widget.dart
  (note: lib/presentation/widgets/ doesn't currently exist — creating the sub-dir is a
  realistic poison vector). File contents, exactly one line with NO GOSL header:
    class PoisonWidget {}
  Commit only the new file.
- Expected exit code: 1
- Expected log: "check_headers: 1 file(s) missing GOSL v1.0 header:" +
  "  - lib/presentation/widgets/poison_widget.dart". Failing CI step: "Check GOSL headers".
- Rollback: git checkout main && git branch -D adversarial/02-header-missing
  && git push origin --delete adversarial/02-header-missing

### Poison #3 — dependencies gate
- Target gate: tool/check_dependencies_md.dart
- Payload: On branch adversarial/02-deps-missing-entry, add to pubspec.yaml:
    equatable: 2.0.7
  (MIT, trivial, zero Dart transitive deps — clean choice). Verify MIT on pub.dev at
  commit time; fallback quiver: 3.2.2 (Apache-2.0). Run flutter pub get so pubspec.lock
  picks up the entry; commit pubspec.yaml + pubspec.lock + package_config.json.
  Leave DEPENDENCIES.md untouched so the new lockfile row has no matching markdown row.
- Expected exit code: 1
- Expected log: "check_dependencies_md: 1 package(s) in pubspec.lock MISSING from
  DEPENDENCIES.md:" + "  - equatable 2.0.7". Caveat: fires only if Gate #1 passes.
  Failing CI step: "Check DEPENDENCIES.md is up to date".
- Rollback: git checkout main && git branch -D adversarial/02-deps-missing-entry
  && git push origin --delete adversarial/02-deps-missing-entry
```

### Agent #2 — Bootstrap runtime

[Blocker] `runZonedGuarded` only covers errors raised inside the zone — `PlatformDispatcher.onError` is NOT wired. Phase 01 RESEARCH (`01-RESEARCH.md:349-354, 987-989`) explicitly flagged this as needing user confirmation; CLAUDE.md contract is literally met but the known-fragile combo remains — either add `PlatformDispatcher.onError` or record explicit user sign-off — `lib/main.dart:15-41`

[Should] `runZonedGuarded` wraps `WidgetsFlutterBinding.ensureInitialized()` AND `runApp` in the same zone — exact pattern RESEARCH flagged (Flutter 3.10+ zone-mismatch anti-pattern); no assertion tripped during visual walk but structurally fragile — `lib/main.dart:16-18`

[Should] `_onShare` has no `try/catch` and no timeout — CLAUDE.md §Timeouts mandates timeout on all native plugin calls; `share_plus` can pend on OS-level failure or dismissal — `lib/presentation/screens/debug_menu_screen.dart:63-65`

[Should] `_onShare` does not flush the active sink before sharing — un-flushed bytes would be absent from the shared copy; `_onRecord` flushes after every write (tiny window) but the invariant is enforced elsewhere — `lib/presentation/screens/debug_menu_screen.dart:63-65`

[Should] After `FileLogger.clearAll()` the logger silently becomes a no-op — any `Logger.*()` call drops records with no feedback; UI shows `Active: (none)` but easy to miss — `lib/infrastructure/logging/file_logger.dart:107-124`

[Should] No UI path from `/` to `/about` — `PlaceholderHomeScreen` has no navigation link to `/about`, so the 7-tap + debug menu is unreachable in a pristine build without code changes; visual walk required router patch to verify — `lib/presentation/screens/placeholder_home_screen.dart:11-21`, `lib/presentation/router.dart:22-27`

[Should] `listLogFiles()` sorts by `b.path.compareTo(a.path)` assuming filename = chronological — relies on `_formatFilenameTimestamp` left-padding; a format change silently breaks sort. Either add doc invariant or sort by `FileStat.modified` — `lib/infrastructure/logging/file_logger.dart:91-103`

[Should] Prune races with a second launch writing to the same directory — desktop Flutter allows two windows; concurrent bootstraps can mis-count bytes and over-delete; document single-instance invariant or guard with file lock — `lib/infrastructure/logging/file_logger.dart:141-168`

[Should] `_onRecord` does not handle write failures — if disk fills up, `sink.writeln`/`flush()` throws into the zone error handler which re-invokes `Logger('main').shout`, re-entering the sink — potential infinite loop; single try/catch that disables sink after first failure — `lib/infrastructure/logging/file_logger.dart:126-139`

[Could] `_onRecord` awaits `sink.flush()` after every single record — burns one write syscall per record; hybrid flush-every-N-or-Y-ms would be cheaper at 100s records/sec — `lib/infrastructure/logging/file_logger.dart:137-138`

[Could] 7-tap window is inter-tap, not total — 7 taps spaced 2.9s apart (~21s total) still trigger; intentional streak-keeping or should cap total duration? — `lib/presentation/screens/about_placeholder_screen.dart:28-40`

[Could] `_onToggleVerbose(bool _)` accepts but ignores the switch's new value, XORs the stored prefs value via `toggleVerbosePref()` — if switch UI and prefs desync, flips stored not intended value — `lib/presentation/screens/debug_menu_screen.dart:53-61`, `lib/infrastructure/logging/file_logger.dart:76-81`

[Noted] Log directory on Windows desktop resolves to `C:\Users\<user>\Documents\logs\` — how `path_provider.getApplicationDocumentsDirectory()` works on Windows desktop; not a bug; worth documenting (Documents is user-visible + OneDrive-backed)

[Noted] `flutter run -d windows` first run produced a non-deterministic MSBuild C1041 PDB error on `geolocator_windows` — environmental parallel-PDB write race; `flutter clean` + rerun succeeds; future CI should serialise with `/FS` or retry

### Agent #3 — Code quality sweep (lib/)

[Should] Magic number `EdgeInsets.all(24)` — inline padding literal violates CLAUDE.md §Magic numbers; extract into named constant — `lib/presentation/screens/about_placeholder_screen.dart:51`

[Should] Magic number `SizedBox(height: 16)` — bare pixel literal; extract into named constant — `lib/presentation/screens/debug_menu_screen.dart:115`

[Should] Magic number `EdgeInsets.all(16)` — bare padding literal; extract into named constant — `lib/presentation/screens/debug_menu_screen.dart:117`

[Could] Magic numbers `pad(…, 4)` / `pad(…, 2)` width params for ISO date components — arguably part of a well-known format; extracting to `const _yearWidth = 4; const _datePartWidth = 2;` is stricter — `lib/infrastructure/logging/file_logger.dart:172-173`

[Could] `main()` lacks a `///` docstring — CLAUDE.md §Docstring policy requires one on every public function — `lib/main.dart:15`

[Noted] Generated `lib/presentation/router.g.dart` lacks GOSL header — CLAUDE.md requires header on "chaque fichier source"; build-generated files typically exempt but no explicit exemption in rules; cross-refs Agent #1's header-check tool policy — `lib/presentation/router.g.dart:1`

[Noted] Unused parameter `_` in `_onToggleVerbose(bool _)` — same subject as Agent #2's Could-level finding above; captured under both lenses for audit transparency — `lib/presentation/screens/debug_menu_screen.dart:53`

### Agent #4 — Tests + tooling + CI workflow + platform

[Could] `depend_on_referenced_packages` inherited via `flutter_lints 6.0.0 → lints 6.1.0 → core.yaml` but not explicitly declared in `analysis_options.yaml` — a one-line explicit declaration would self-document the Phase 01 promotion rationale and guard against future `flutter_lints` dropping it from recommended — `analysis_options.yaml:20-30`

[Could] `smoke_test.dart` calls `tester.pump()` only once (no bounded `settleRefresh`) before asserting placeholder home text — single pump may be fragile if go_router adds a transition frame on some engines; align with `debug_menu_screen_test.dart`'s bounded-pump pattern for consistency — `test/smoke_test.dart:57-63`

[Could] CI `fail-fast` scope-sheet artifact — `.github/workflows/ci.yml` does not use a matrix; `android`/`ios` are independent jobs each `needs: gates`, so fail-fast is N/A. Current behaviour (one job failing does not cancel the other) is correct for "build both to surface platform-specific breakage" — `.github/workflows/ci.yml:60,149`

[Noted] iOS `Info.plist` contains 4 TODO-labeled UsageDescription entries for Phases 05 and 11 — expected per CONTEXT; Phase 15 fills with store-grade copy — `ios/Runner/Info.plist:69-76`

[Noted] `ios/Podfile.lock` is a 5-byte comment-only placeholder — expected per Option A; CI detects absence of `^COCOAPODS:` footer, removes placeholder, runs `pod install`, does NOT auto-commit back — `ios/Podfile.lock` / `.github/workflows/ci.yml:231-237`

<details>
<summary>Audit Notes (narrative appendix, per agent)</summary>

#### Agent #1 Narrative

The three scripts are well-written and cover the common cases cleanly. The design decision to rely on a heuristic LICENSE-text matcher + pubspec `license:` field + manual override map is pragmatic: implementing a real SPDX expression parser would be overkill for a 175-package tree where the override count is currently 4. The exit-code contract (0/1/2) is respected everywhere, and the test suites assert exit codes only (not stderr text), which is the right CI contract per CLAUDE.md and leaves room for log-message evolution.

The most interesting class of gap is case-sensitivity and SPDX expression complexity. Dart's `Set.contains` is case-sensitive, and `_allowedSpdx` holds only the canonical-case SPDX IDs. Today's tree uses canonical casing everywhere sampled, but a single upstream publisher deciding to lowercase their license field would produce a confusing "not in allowlist" violation rather than a clear "unrecognised" signal. SPDX expressions with `AND`, `WITH`, or parentheses are not parsed at all — the current `split(' OR ')` logic treats them as monolithic strings. Given the manual override escape hatch this is acceptable, but worth a guard/warning when a compound expression contains `AND` or `WITH` so a reviewer sees the problem explicitly.

The second sharp edge is `pubspec.yaml` license-field precedence over LICENSE-text forbidden-marker scan. A package that declares `license: MIT` in its pubspec but ships a GPL LICENSE file will pass the gate. This is the classic "divergence between pub.dev and repo source" that CLAUDE.md §Audit obligatoire flags. Mitigation today is CLAUDE.md's human-audit step, not the automated gate; a belt-and-braces fix would run both checks and union the results.

The manual overrides remain narrow and traceable. The `flutter_plugin_android_lifecycle` override is a different beast from the MPL trio — a "LICENSE preamble defeats heuristic" escape, not a platform-scope exception — and grouping them in the same `_manualOverrides` map without a visually distinct section is a minor code-reading smell.

Test coverage is honest about what it covers (exit code contract + three happy paths per script) but shallow. None of the three test files exercises `_manualOverrides`, the dual-licensing `OR` compound, the pubspec `license:` field path, the LICENSE-text forbidden-marker detection, the unresolved-package advisory, or more than one of the two possible exit-2 paths. A reviewer could silently delete `_manualOverrides` and every unit test still passes — real-tree `flutter pub get` + `dart run` is the only thing that catches it. Phase 03 adversarial branches partially compensate at integration level; unit coverage of heuristic branches would fail faster.

CI wiring is correct: `gates` runs the three scripts in sequence (lines 42-49), each a separate step; `needs: gates` blocks `android` and `ios`. `dart format --line-length 160 --set-exit-if-changed .` at step line 37 uses `.` as target, catching `tool/check_*.dart` consistent with the GOSL header being required there.

#### Agent #2 Narrative

**Runtime walk: performed successfully on Windows 10 desktop.**

Caveat: `PlaceholderHomeScreen` has no UI link to `/about`, so I briefly patched `lib/presentation/router.dart:22` from `initialLocation: '/'` to `initialLocation: '/about'`, ran `flutter run -d windows`, executed the full flow, then reverted the edit. `git status` confirmed no residual changes in `lib/`.

First clean attempt failed with MSBuild error C1041 on `geolocator_windows` (native-build PDB contention unrelated to project code). `flutter clean` + re-run succeeded. Debug build compiled in ~23.6s, produced `build\windows\x64\runner\Debug\mirkfall.exe`, attached a Dart VM Service at `http://127.0.0.1:55864/-OdIuvbFuXs=/`, opened a 1280×720 window titled "mirkfall".

Log file observed on disk: `C:\Users\oliver\Documents\logs\20260417_2025.32_logs.txt` (timestamp matches app start 20:25:32). Filename format matches `yyyymmdd_hhmm.ss_logs.txt` exactly. First line after boot:

```
{"ts":"2026-04-17T20:25:32.250364","level":"INFO","logger":"main","msg":"MirkFall starting — logger armed"}
```

One JSON object per line, valid UTF-8, ISO-8601 timestamp (microsecond precision, no TZ suffix — Dart's `DateTime.toIso8601String()` default). Three pre-existing log files from earlier bootstraps were present, confirming "one file per launch" + "no deletion below size cap".

Resolved logs directory on Windows desktop is `C:\Users\<user>\Documents\logs\`, NOT `<app_docs>` in the traditional AppData sense — that's how `path_provider` resolves `getApplicationDocumentsDirectory()` on Flutter Windows desktop. Orphan empty folder `C:\Users\oliver\AppData\Roaming\app.gosl\mirkfall` was created by the Flutter runner but not used by the logger.

7-tap gesture: seven `mouse_event` LEFTDOWN/LEFTUP pairs at screen center via Win32 API, ~180ms apart. Router navigated to `/debug` as expected (screenshot `C:/tmp/mirkfall_debug.png` shows the Debug menu AppBar, Verbose switch reading `--dart-define=DEBUG = false · prefs = false`, 4 log-file rows each with share buttons, Supprimer-tous-les-logs row, footer `Active: C:\Users\oliver\Documents\logs\20260417_2025.32_logs.txt`).

Clear-all with confirmation: clicked "Supprimer tous les logs" ListTile. Modal `AlertDialog` appeared ("Supprimer tous les logs ?" / "Cette action est irréversible." / Annuler / Supprimer). Clicked Annuler — dialog dismissed, list unchanged. Re-opened and clicked Supprimer — after ~1s async delete, `ls` showed all 4 files gone, UI refreshed to "Aucun fichier de log" with footer `Active: (none)`. Destructive-action confirmation contract satisfied.

Share flow: clicked share icon on active log row. Foreground window title switched to "Share" (verified via Win32 `GetForegroundWindow` + `GetWindowText`). Share UI modal appeared with document preview. File handed to `ShareParams(files: [XFile(f.path)])` is a real filesystem path — same as Active footer. Dismissed with WM_CLOSE.

Tests: `flutter test` ran 14 tests green in 4s: 5 constants, 3 file_logger bootstrap/JSONL/idempotency, 1 prune (seeds 6×2MB, asserts trim to <10MB keeping newest), 1 DEBUG-define branching (INFO without, ALL with), 2 debug_menu widget tests, 1 smoke, 1 pubspec-pinned.

Error-handling wiring: `main.dart` uses `runZonedGuarded<Future<void>>` + `FlutterError.onError` per CLAUDE.md mandate. Neither `PlatformDispatcher.onError` nor `Isolate.current.addErrorListener` is wired. Per Phase 01 RESEARCH line 987 ("Should runZonedGuarded be replaced with PlatformDispatcher.onError?") this was flagged as needing user confirmation. CLAUDE.md contract met literally but no recorded explicit decision — hence the Blocker.

DEBUG precedence: `file_logger.dart:44` reads `bool.fromEnvironment('DEBUG')` (compile-time, const) and `prefs.getBool('debug_logging_enabled')` (runtime, persisted). Precedence OR: `Level.ALL` if either true, else `Level.INFO`. Debug Menu subtitle displays both sources (`--dart-define=DEBUG = false · prefs = false`), precedence model observable to user. `_onToggleVerbose` additionally applies new level to `Logger.root.level` immediately, so toggle takes effect mid-session.

Post-walk state: killed `mirkfall.exe`; reverted `lib/presentation/router.dart`; `git status -s lib/` empty.

#### Agent #3 Narrative

Audit surface: 9 `.dart` files under `lib/` totalling ~430 source LOC (excluding 54-line generated `router.g.dart`). Full file list audited: `lib/config/constants.dart`, `lib/app.dart`, `lib/main.dart`, `lib/infrastructure/logging/file_logger.dart`, `lib/presentation/router.dart`, `lib/presentation/router.g.dart` (generated), `lib/presentation/screens/placeholder_home_screen.dart`, `lib/presentation/screens/about_placeholder_screen.dart`, `lib/presentation/screens/debug_menu_screen.dart`.

Overall: zero Blocker-level issues. No `print()`, no undocumented `dynamic`, no `.then()` chains, no null-forcing `!` without prior assignment, no `is`-type chains, no DTO duplicates, no delegation wrappers, no hidden singletons beyond the Phase-01-approved `FileLogger`. All `setState` calls in async flows correctly guarded by `if (!mounted) return;`. All widgets use `const` where possible. All public APIs carry `///` docstrings (the one miss being `main()`).

`constants.dart` already anchors non-trivial magic numbers (`kMaxLogsDirBytes`, `kAboutTapsToTriggerDebugMenu`, `kAboutTapWindowMilliseconds`, `kAppName`, `kBundleId`) — the exact pattern CLAUDE.md prescribes. Gaps (`EdgeInsets.all(24)` and two `16` pixel literals in `debug_menu_screen.dart`) are cosmetic — lift into `constants.dart` under a `kUi*` prefix or file-local `const _padding = 16.0;`.

`file_logger.dart` `pad()` widths (`4` for year, `2` for rest) live in a private method; the pattern is universally understood as ISO calendar format, tagged Could rather than Should.

Almost-list items:
- `_onToggleVerbose(bool _)` discards the value from `SwitchListTile` and re-derives via `toggleVerbosePref()`. Harmless, arguably more conservative (single source of truth = prefs).
- `_sink?.flush(); _sink?.close(); _subscription?.cancel();` sequence duplicated between `bootstrap()` and `clearAll()`. Refactor candidate for Phase 04+.
- `Logger('main')` instantiated twice in `main.dart`; benign — `logging` caches by name.
- `router.g.dart` generated; noted for Agent #1 header-tool policy cross-reference.

Ship-ready foundation. The three `EdgeInsets`/`SizedBox` magic numbers are the only items cleanly matching a CLAUDE.md `Should`-level rule.

#### Agent #4 Narrative

Test quality: all 7 Flutter tests and 3 tool tests make real SUT assertions. No `expect(true, isTrue)`, no tautologies, no disconnected mocks. `FakePathProvider` via `MockPlatformInterfaceMixin` wired through `PathProviderPlatform.instance`; `SharedPreferences.setMockInitialValues` called in every `setUp`. `file_logger_prune_test.dart` seeds 12 MB above the 10 MB cap and asserts both total-after ≤ cap and oldest-gone/newest-survives. `file_logger_debug_define_test.dart` asserts both branches of the DEBUG define (ALL when set, INFO when not) — both assertive, not placebo. `debug_menu_screen_test.dart` uses bounded `settleRefresh` (40 × 20ms + 20ms runAsync, ~1.6s bound) precisely as Phase 01 prescribes — `pumpAndSettle` would hang on FileLogger's per-record `flush()`. Toggle test reads prefs back through real SUT path `FileLogger.readVerbosePref()` before and after tap — genuine end-to-end prefs flip.

CI: `gates` covers format / analyze / 3 GOSL check scripts / tool unit tests / flutter test / flutter test with `--dart-define=DEBUG=true`. `android` + `ios` each `needs: gates` — gate failure blocks both downstream. Both downstream jobs have `continue-on-error: true` on forensic-dump step — diagnostic regression cannot break build. iOS Podfile.lock bootstrap correctly detects placeholder via `! grep -q "^COCOAPODS:"`, removes, runs `pod install`, no commit-back (Option A). Cache via `subosito/flutter-action@v2` with `cache: true` — internally keys on Flutter SDK version + OS. Concurrency group cancels superseded runs per branch — right policy for main-only solo-dev.

pubspec / lock / DEPENDENCIES.md drift: sampled 6 entries (flutter_riverpod 3.1.0, drift 2.32.1, go_router 16.0.0, share_plus 12.0.2, geolocator 14.0.2, cross_file 0.3.5+2) — all three sources agree. 4 `_manualOverrides` (dbus 0.7.12, geoclue 0.1.1, gsettings 0.2.8 → `MPL-2.0-Linux-only`; flutter_plugin_android_lifecycle 2.0.34 → `BSD-3-Clause`) consistent with DEPENDENCIES.md lines 98, 110, 112, 121. Synthetic `MPL-2.0-Linux-only` SPDX in `_allowedSpdx` line 32, reachable only through manual-override path — clean design. `cross_file 0.3.5+2` correctly transitive in both lock and DEPENDENCIES.md with "Pulled in by: share_plus_platform_interface" rationale — matches Phase 01-02 re-export decision.

Platform stubs: Android `build.gradle.kts` pins `desugar_jdk_libs:2.1.4` exactly (no `+`/wildcard) with AGP 8.x comment, `isCoreLibraryDesugaringEnabled = true`, `minSdk = 24`. iOS `Info.plist` has 4 TODO-labeled UsageDescription entries for Phases 05 (GPS When/Always) + 11 (Camera/PhotoLibrary) — expected. AndroidManifest.xml is standard Flutter scaffold.

`analysis_options.yaml`: strict-casts, strict-inference, strict-raw-types all true. `avoid_print`, `use_build_context_synchronously`, `missing_required_param`, `missing_return` elevated to errors. `depend_on_referenced_packages` active via transitive include (verified in package cache).

Layer READMEs: all 5 exist (`application/`, `config/`, `domain/`, `infrastructure/`, `presentation/`), short, accurately describe import rules. `presentation/` forbids `infrastructure/`; `domain/` forbids `package:flutter`, `drift`, `geolocator`, `path_provider`. Not stale at Phase 01-02 scope.

</details>

## 3. Triage decisions

*Captured by Plan 02-02 Task 2. User decision: "fix tous les could, should, et blocker, on est au setup du projet, autant rendre ça aussi propre qu'on peu maintenant". 42 findings to fix, 12 Noted retained as observations only.*

| # | Finding | Severity | Decision | Rationale |
|---|---------|----------|----------|-----------|
| 1 | SPDX matching case-sensitive | Blocker | fix | User blanket "fix all B/S/C" |
| 2 | Compound-license AND silently wrong | Blocker | fix | User blanket |
| 3 | Declared `license:` bypasses LICENSE-text scan | Blocker | fix | User blanket |
| 4 | MPL detection never fires on LICENSE text | Blocker | fix | User blanket |
| 5 | `PlatformDispatcher.onError` not wired | Blocker | fix | User blanket |
| 6 | Whitespace/empty license field not unresolved | Should | fix | User blanket |
| 7 | `LicenseRef-*` / SPDX-WITH-exception not handled | Should | fix | User blanket |
| 8 | Exit-2 coverage for check_licenses weak | Should | fix | User blanket |
| 9 | No exit-1 test for unresolved-package advisory | Should | fix | User blanket |
| 10 | No test for `_manualOverrides` path | Should | fix | User blanket |
| 11 | Header check no trailing-newline validation | Should | fix | User blanket |
| 12 | Header exclude patterns miss codegen suffixes | Should | fix | User blanket |
| 13 | Header scan doesn't exclude ios/android example/ | Should | fix | User blanket |
| 14 | check_dependencies_md `line.startsWith('\| ')` fragile | Should | fix | User blanket |
| 15 | check_dependencies_md tooling filter loose | Should | fix | User blanket |
| 16 | check_dependencies_md column-count guard weak | Should | fix | User blanket |
| 17 | No exit-2 test for pubspec.lock missing | Should | fix | User blanket |
| 18 | No test for dual-licensing OR passes | Should | fix | User blanket |
| 19 | runZonedGuarded wraps ensureInitialized+runApp | Should | fix | User blanket |
| 20 | `_onShare` no try/catch no timeout | Should | fix | User blanket |
| 21 | `_onShare` doesn't flush sink before share | Should | fix | User blanket |
| 22 | `FileLogger.clearAll()` leaves logger silent no-op | Should | fix | User blanket |
| 23 | No UI path from / to /about (7-tap unreachable) | Should | fix | User blanket |
| 24 | listLogFiles() sort relies on filename invariant | Should | fix | User blanket |
| 25 | Prune races with concurrent launches | Should | fix | User blanket |
| 26 | `_onRecord` no write-failure handling | Should | fix | User blanket |
| 27 | Magic `EdgeInsets.all(24)` | Should | fix | User blanket |
| 28 | Magic `SizedBox(height: 16)` | Should | fix | User blanket |
| 29 | Magic `EdgeInsets.all(16)` | Should | fix | User blanket |
| 30 | Forbidden-marker detection case-sensitive | Could | fix | User blanket |
| 31 | `_resolveSpdx` reads full LICENSE into memory | Could | fix | User blanket |
| 32 | BOM detection UTF-8 only (no UTF-16 LE) | Could | fix | User blanket |
| 33 | `runCheck(List<String>)` no CLI parser layer | Could | fix | User blanket |
| 34 | `_defaultRoots` missing `integration_test/` | Could | fix | User blanket |
| 35 | `_onRecord` flush after every record | Could | fix | User blanket |
| 36 | 7-tap window inter-tap not total | Could | fix | User blanket |
| 37 | `_onToggleVerbose(bool _)` ignores new value | Could | fix | User blanket |
| 38 | `pad(…, 4)` / `pad(…, 2)` width literals | Could | fix | User blanket |
| 39 | `main()` lacks docstring | Could | fix | User blanket |
| 40 | `depend_on_referenced_packages` implicit inherit | Could | fix | User blanket |
| 41 | `smoke_test.dart` single `pump()` fragile | Could | fix | User blanket |
| 42 | CI fail-fast scope-sheet artifact (N/A) | Could | fix | User blanket (marks as reviewed + documents N/A outcome) |
| 43 | Override `flutter_plugin_android_lifecycle` mixed rationale | Noted | noted | Observation only |
| 44 | `MPL-2.0-Linux-only` synthetic SPDX non-standard | Noted | noted | Observation only |
| 45 | MPL overrides stay narrow | Noted | noted | Observation only |
| 46 | Exit-code 0/1/2 respected everywhere | Noted | noted | Observation only |
| 47 | check_dependencies_md doesn't check Date recency | Noted | noted | Observation only |
| 48 | `tool/` in header-scope, not license-scope | Noted | noted | Observation only |
| 49 | Log dir Windows = Documents\logs\ | Noted | noted | Observation only |
| 50 | MSBuild C1041 PDB race (environmental) | Noted | noted | Observation only |
| 51 | `router.g.dart` lacks GOSL header (generated) | Noted | noted | Observation only |
| 52 | `_onToggleVerbose` unused `_` param (cross-ref #37) | Noted | noted | Same subject as #37 |
| 53 | `Info.plist` 4 TODO UsageDescription (expected) | Noted | noted | Observation only |
| 54 | `Podfile.lock` 5-byte placeholder (expected) | Noted | noted | Observation only |

**Triage summary:** 42 fix / 0 waived / 0 deferred / 0 won't-fix / 12 noted.

**User resume signal:** "fix tous les could, should, et blocker" (2026-04-17) — Plan 02-03 unblocked.

## 4. Adversarial evidence

*Filled by Plan 02-03 Wave 3. One block per guardrail test.*

### Test 1: License GPL scan

- **Branch:** `adversarial/02-licence-gpl-scan` (deleted 2026-04-17, local + remote)
- **Poison commit:** `c7f5ec4` — added `multi_dropdown: 3.1.1` (GPL-3.0) to `pubspec.yaml` + regenerated `pubspec.lock` via `flutter pub get`
- **CI-trigger commit:** `5d59e7f` — one-line change on the same branch expanding `on.push.branches` to include `adversarial/**` (main's trigger stays `[main]`-only; needed because the project's `.github/workflows/ci.yml` on `main` only runs on `push: branches:[main]` / `pull_request: branches:[main]`, so a direct push to an adversarial branch would never trigger CI otherwise)
- **Run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24581444173
- **Job:** `Lint / Licence / Headers / Deps` (the `gates` job, conclusion=failure)
- **Gate step:** `Check licenses (GPL/AGPL/copyleft scan)` — step #8, exit code **1** (policy violation, NOT exit 2 misconfiguration)
- **Error excerpt (stderr, step #8):**
  ```
  [command]dart run tool/check_licenses.dart
  check_licenses: 1 violation(s):
    - multi_dropdown: UNKNOWN-FORBIDDEN-MARKER: GNU GENERAL PUBLIC LICENSE NOT in allowlist
  ##[error]Process completed with exit code 1.
  ```
- **Detection path:** **LICENSE substring matched** — voie 2 of `_resolveSpdx` inside `tool/check_licenses.dart`, the `_forbiddenSubstrings` scan at lines 188-194. Stderr contains the literal `UNKNOWN-FORBIDDEN-MARKER: GNU GENERAL PUBLIC LICENSE` prefix, which is the forbidden-substring short-circuit (no `_manualOverrides` for `multi_dropdown` exists, and no pubspec `license:` field declaration bypass fired either — the LICENSE-text heuristic was the catcher).
- **Confirms:** `check_licenses.dart` catches real pub.dev GPL-3.0 packages at their LICENSE-text level — not just synthetic fixtures. The forbidden-substring path is exercised in production-like conditions against a freshly `pub get`-resolved tree. Plan 02-04 Blockers #1-#4 (case-sensitivity, compound-AND, license-field bypass, MPL-unreachable heuristic) remain for unit-level reinforcement, but the "real GPL package in `pubspec.yaml`" scenario is proven end-to-end green-to-red.

### Test 2: Missing GOSL header

- **Branch:** `adversarial/02-header-missing` (deleted 2026-04-17, local + remote)
- **Poison commit:** `7f26d24` — created `lib/presentation/widgets/poison_widget.dart` (single line `class PoisonWidget {}` — no GOSL header, but `dart format --line-length 160`-clean and `flutter analyze`-clean so gates #4 and #5 don't short-circuit before the header gate); same commit also expands `on.push.branches` to include `adversarial/**` for this branch only
- **Run URL:** https://github.com/ThongvanAlexis/GOSL-MirkFall/actions/runs/24581566943
- **Job:** `Lint / Licence / Headers / Deps` (the `gates` job, conclusion=failure)
- **Gate step:** `Check GOSL headers` — step #7, exit code **1** (policy violation). Preceding steps #4 (`Dart format check`) and #5 (`Flutter analyze`) passed, confirming the failure lands on the intended gate and not on an earlier lint pipeline stage (per plan sanity check).
- **Error excerpt (stderr, step #7):**
  ```
  [command]dart run tool/check_headers.dart
  check_headers: 1 file(s) missing GOSL v1.0 header:
    - lib/presentation/widgets/poison_widget.dart
  ##[error]Process completed with exit code 1.
  ```
- **Confirms:** `check_headers.dart` catches real `.dart` files missing the GOSL v1.0 3-line copyright header inside `lib/`, names the offending file path exactly, and returns exit 1 from real CI. The Phase 01 exclude list (`*.g.dart`, `*.freezed.dart`) does NOT falsely whitelist new files under `lib/presentation/widgets/`. Gate step name matches `.github/workflows/ci.yml:42` verbatim.

### Test 3: Missing DEPENDENCIES.md entry
(pending)

## 5. CI-green confirmation

*Filled by Plan 02-04 Wave 4 after all Blocker + non-waived Should fixes are applied.*

- **Final commit on main:** (pending)
- **CI run URL:** (pending)
- **Status:** (pending)
- **Date:** (pending)

---
_Phase 02 closed: (pending)_
_Phase 03 unblocked._
