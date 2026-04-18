# Deferred items surfaced during Plan 04-04 execution

Items discovered while executing adversarial tests that are OUT OF SCOPE for the
current task (poison insertion + CI observation) but MUST be tracked for a later
fix loop (Plan 04-05 or later).

## 1. Pre-existing dart format drift on main (SURPRISE BLOCKER)

**Discovered:** Plan 04-04 Task 1, CI run 24611006850 (adversarial branch) —
also confirmed on main via CI run 24610968531 which FAILED on the same step.

**Symptom:** `dart format --line-length 160 --set-exit-if-changed .` fails CI's
`Dart format check` gate on any push. Locally, the same command exits 0 on a
freshly-cloned workspace because `flutter pub get` regenerates .g.dart files
to match the local Dart SDK — but the files committed to git (generated under
a different SDK during Phase 03 runs) do not match CI's rendering.

**Scope:** 61 files reformat to different content between local and CI:
- 23 generated files (`.g.dart`, `.freezed.dart`): regenerated under different
  codegen/dart_format versions between Phase 03 and now.
- 38 hand-written files: smaller whitespace/line-break differences.

**Root cause (hypothesis):** CI pins `flutter-version: '3.41.5'` (bundled Dart
~3.11.x) but the specific patch version on the runner image differs from the
developer's local Dart 3.11.5, and `dart format` outputs diverge at minor
versions. Alternative: Phase 03's in-tree files were committed by a developer
using a slightly different `flutter format` toolchain from CI. 61 files all
drift simultaneously suggests a toolchain-wide format policy difference
(not a per-file edit).

**Why this was hidden:** Phase 03 tested locally where files matched. The
breakage lands the first time CI re-renders them under its own Dart SDK.

**Why out of scope for Plan 04-04:** The adversarial tests' purpose is to
prove Phase 03's two new guardrails (domain purity + drift schema) fire on
real violations. Fixing a pre-existing format drift is a separate concern and
belongs to Plan 04-05 (fix loop) or as a standalone Phase 04 fix.

**Status on adversarial/04-domain-import-flutter-and-drift branch (Test #1):**
Auto-reformatted 61 files on the branch alongside the poison commit so CI
could reach the target `Check domain purity` gate. These reformats are
included in the throwaway branch's poison commit scope and go away when the
branch is deleted — they do NOT pollute main.

**Recommended fix (Plan 04-05 or standalone):**
1. Run `dart format --line-length 160 .` on main once
2. Commit the reformat in a single `chore(format): align with CI dart format`
   commit
3. Investigate why format output differs — potentially pin a specific Dart
   patch version in CI, or add a `.dart_format` config file if one exists for
   this toolchain version.

## 2. main CI has been red since push of 61 Phase 04 docs commits

**Discovered:** Before Plan 04-04 Task 1 started, CI run 24610968531 on main
(triggered by today's push of the 61 local Phase 04 docs commits) completed
with conclusion=failure on `Dart format check` — same root cause as item #1.

**Note:** None of the docs commits could have caused a format failure
(Markdown files don't go through `dart format`). This means main was ALREADY
in a state where CI would fail the first time it ran — it just wasn't
exercised because Phase 03 + Phase 04 docs-only plans didn't push to main
until today.

**Status:** Same as item #1 — covered by the proposed format-align fix.
