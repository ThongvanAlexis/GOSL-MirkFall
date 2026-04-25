---
phase: quick-1
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/config/constants.dart
  - lib/main.dart
  - lib/presentation/screens/debug_menu_screen.dart
  - .github/workflows/ci.yml
autonomous: true
requirements: ["QUICK-1"]
must_haves:
  truths:
    - "CI-built APKs and IPAs contain the git commit SHA baked in at compile time"
    - "Logger prints the commit SHA at app startup"
    - "Debug menu displays the current commit SHA"
    - "Local dev builds show 'dev' (or empty) instead of a SHA when --dart-define is not passed"
  artifacts:
    - path: "lib/config/constants.dart"
      provides: "kGitCommitSha compile-time constant"
      contains: "String.fromEnvironment"
    - path: "lib/main.dart"
      provides: "Startup log line with commit SHA"
      contains: "kGitCommitSha"
    - path: "lib/presentation/screens/debug_menu_screen.dart"
      provides: "Commit SHA visible in debug menu"
      contains: "kGitCommitSha"
    - path: ".github/workflows/ci.yml"
      provides: "--dart-define=GIT_COMMIT_SHA passed to flutter build"
      contains: "GIT_COMMIT_SHA"
  key_links:
    - from: ".github/workflows/ci.yml"
      to: "lib/config/constants.dart"
      via: "--dart-define=GIT_COMMIT_SHA=${{ github.sha }}"
      pattern: "dart-define=GIT_COMMIT_SHA"
    - from: "lib/main.dart"
      to: "lib/config/constants.dart"
      via: "import constants.dart, reference kGitCommitSha"
      pattern: "kGitCommitSha"
---

<objective>
Bake the git commit SHA into CI builds via `--dart-define` and log it at startup.

Purpose: When debugging a device build or reading logs, instantly know which exact commit produced the running binary. Eliminates the "which build is this?" guessing game.

Output: Updated CI workflow, a new compile-time constant, startup log line, and debug menu display.
</objective>

<execution_context>
@C:/Users/oliver/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/oliver/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/config/constants.dart
@lib/main.dart
@lib/presentation/screens/debug_menu_screen.dart
@lib/infrastructure/logging/file_logger.dart
@.github/workflows/ci.yml

<interfaces>
<!-- Existing pattern for compile-time defines in this project -->

From lib/infrastructure/logging/file_logger.dart:
```dart
const debugDefine = bool.fromEnvironment('DEBUG');
```

From lib/presentation/screens/debug_menu_screen.dart:
```dart
static const bool _debugDefine = bool.fromEnvironment('DEBUG');
```

From lib/main.dart (line 111):
```dart
log.info('MirkFall starting — logger armed');
```

From .github/workflows/ci.yml:
```yaml
# android job, line 296:
run: flutter build apk --debug

# ios job, line 408:
run: flutter build ios --release --no-codesign
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add GIT_COMMIT_SHA constant, log at startup, show in debug menu</name>
  <files>lib/config/constants.dart, lib/main.dart, lib/presentation/screens/debug_menu_screen.dart</files>
  <action>
1. In `lib/config/constants.dart`, add at the TOP of the file (after the existing `kBundleId` line, before `kMaxLogsDirBytes`):

```dart
/// Git commit SHA baked in at build time via `--dart-define=GIT_COMMIT_SHA=abc123`.
/// Falls back to `'dev'` for local builds where the define is not passed.
/// Read at startup by the logger and displayed in the debug menu.
const String kGitCommitSha = String.fromEnvironment('GIT_COMMIT_SHA', defaultValue: 'dev');
```

2. In `lib/main.dart`, change line 111 from:
```dart
log.info('MirkFall starting — logger armed');
```
to:
```dart
log.info('MirkFall starting — logger armed — commit: $kGitCommitSha');
```
Also add the import if not already present: `import 'config/constants.dart';` (check — `constants.dart` may already be imported transitively, but `main.dart` does not currently import it directly). Add it after the existing imports, alphabetically.

3. In `lib/presentation/screens/debug_menu_screen.dart`, add a read-only `ListTile` showing the commit SHA. Place it BEFORE the verbose-logging `SwitchListTile` in the `build()` method's `ListView.children` list (so it appears at the very top of the debug menu). The tile:
```dart
ListTile(
  leading: const Icon(Icons.commit),
  title: const Text('Build commit'),
  subtitle: const Text(kGitCommitSha),
),
```
The `kGitCommitSha` constant is already available via the existing `import '../../config/constants.dart';` at the top of the file.
  </action>
  <verify>
    <automated>cd C:/claude_checkouts/GOSL-MirkFall && dart analyze --fatal-infos --fatal-warnings lib/config/constants.dart lib/main.dart lib/presentation/screens/debug_menu_screen.dart && dart format --line-length 160 --set-exit-if-changed lib/config/constants.dart lib/main.dart lib/presentation/screens/debug_menu_screen.dart</automated>
  </verify>
  <done>
  - `kGitCommitSha` constant exists in `constants.dart` reading `String.fromEnvironment('GIT_COMMIT_SHA', defaultValue: 'dev')`
  - `main.dart` logs the SHA at startup in the existing "MirkFall starting" info line
  - Debug menu screen shows the commit SHA as the first list tile
  - `flutter analyze` and `dart format` pass with zero issues
  </done>
</task>

<task type="auto">
  <name>Task 2: Pass --dart-define=GIT_COMMIT_SHA in CI build steps</name>
  <files>.github/workflows/ci.yml</files>
  <action>
In `.github/workflows/ci.yml`, update the two `flutter build` steps to pass the commit SHA:

1. **Android job** — change the "Build APK (debug)" step (currently line ~296):
```yaml
      - name: Build APK (debug)
        run: flutter build apk --debug --dart-define=GIT_COMMIT_SHA=${{ github.sha }}
```

2. **iOS job** — change the "Build iOS (no-codesign)" step (currently line ~408):
```yaml
      - name: Build iOS (no-codesign)
        run: flutter build ios --release --no-codesign --dart-define=GIT_COMMIT_SHA=${{ github.sha }}
```

Do NOT modify the `gates` job — it runs `flutter test` and `flutter analyze`, not `flutter build`. The `--dart-define` is only meaningful at build time.

Note: `${{ github.sha }}` is the full 40-char SHA. This is fine — it is a compile-time string constant, costs zero runtime, and the full SHA is more useful for `git show` / `git log` lookups than a truncated 7-char prefix.
  </action>
  <verify>
    <automated>cd C:/claude_checkouts/GOSL-MirkFall && grep -n "GIT_COMMIT_SHA" .github/workflows/ci.yml | head -10</automated>
  </verify>
  <done>
  - Android build step passes `--dart-define=GIT_COMMIT_SHA=${{ github.sha }}`
  - iOS build step passes `--dart-define=GIT_COMMIT_SHA=${{ github.sha }}`
  - Gates job is unchanged (no build step to modify)
  - CI YAML is syntactically valid
  </done>
</task>

</tasks>

<verification>
1. `flutter analyze --fatal-infos --fatal-warnings` — zero issues
2. `dart format --line-length 160 --set-exit-if-changed .` — no formatting drift
3. `flutter test` — all existing tests still pass (no regressions)
4. `grep -n GIT_COMMIT_SHA lib/config/constants.dart` — constant exists
5. `grep -n kGitCommitSha lib/main.dart` — logged at startup
6. `grep -n kGitCommitSha lib/presentation/screens/debug_menu_screen.dart` — displayed in debug menu
7. `grep -n GIT_COMMIT_SHA .github/workflows/ci.yml` — passed in both build steps
</verification>

<success_criteria>
- Local `flutter run` shows "commit: dev" in the startup log line (no --dart-define passed)
- CI-built APKs/IPAs will contain the real 40-char git SHA (verifiable after next CI run)
- Debug menu shows "Build commit" tile with the SHA (or "dev" for local builds)
- Zero new dependencies added
- All existing tests pass unchanged
</success_criteria>

<output>
After completion, create `.planning/quick/1-ci-stores-git-commit-sha-in-app-and-logg/1-SUMMARY.md`
</output>
