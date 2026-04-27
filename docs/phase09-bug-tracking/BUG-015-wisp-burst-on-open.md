# BUG-015 — Wisp burst "rose" pattern on map open and pan

**Status:** ✅ fixed — `723984c`
**Reported:** 2026-04-27 (UAT walk on `743750d` after BUG-013 fix shipped)
**Introduced in:** `d47e5ab` (BUG-010 Option B Commit 5 — disc-based wisp emergence)
**Platform:** cross-platform (renderer CPU-side logic, same on iOS + Android)

## Symptoms

When opening the map, many expanding white circles appear simultaneously
along the boundary of all existing reveal discs, forming a visible "rose"
pattern that quickly fades. The same burst can occur when panning the map
away from the revealed area and back.

## Root cause (two related bugs)

Both bugs are in `_spawnWispsForNewlyEmergedDiscs()` inside
`AtmosphericMirkRenderer` and `HeavenlyCloudsMirkRenderer`.

### A. Viewport exit/re-enter resets the diff set

`_previousDiscIdSet` was **replaced** with `currentIds` every frame:

```dart
_previousDiscIdSet = currentIds;   // <-- replaced, not appended
```

When the user pans away from the revealed area, `discsInBbox` returns an
empty list (discs outside viewport). The code set `_previousDiscIdSet = {}`
(empty). When the user panned back, all discs reappeared as "new" because
their IDs were not in the now-empty set. Result: full wisp burst for every
existing disc.

### B. First-paint guard consumed an empty disc list

The `_firstPaint` guard was:

```dart
if (_firstPaint) {
  _previousDiscIdSet = currentIds;
  _firstPaint = false;
  return;
}
```

On map open, the disc provider often resolves with 0 discs for the first
frame (async timing). The guard consumed this empty set and flipped
`_firstPaint = false`. On the next frame, the real discs arrived but
`_previousDiscIdSet` was empty, so all were treated as "newly emerged".

## Investigation findings

**Log evidence** (20260427_1035.20_logs.txt):

- Line 46: `paint(): first invocation — discs=0` (empty first frame).
- Line 54: `discsInViewport: produced 2 discs` (discs arrive next frame).
- Lines 298-299: `hitCount=0` / `produced 0 discs` during pan-away.

The logs confirmed both root causes independently:
1. The empty first frame (line 46) poisoned `_previousDiscIdSet`, causing the "rose" burst on map open when the real discs arrived in the next frame (line 54).
2. The pan-away pattern (lines 298-299) shows the disc list dropping to 0 when panning away, which cleared `_previousDiscIdSet` via the replace-assignment. On pan-back, all discs were treated as new.

The two bugs compound: map open triggers bug B, pan-away-and-back triggers bug A. Both produce the same visual symptom (mass wisp burst) but via different code paths.

## Strategy / Fix

Two changes to the emergence diff in both renderers:

1. **Append-only `_previousDiscIdSet`**: changed from `_previousDiscIdSet =
   currentIds` (replace) to `_previousDiscIdSet.addAll(currentIds)`. Disc
   IDs that leave the viewport are still remembered; only genuinely new
   GPS-fix discs trigger wisps. This approach was chosen over clearing the set on viewport change because the set is bounded by the total number of discs in the session (typically < 3000), so memory is not a concern.

2. **First-paint guard skips empty disc lists**: if the first paint receives
   0 discs (provider not yet resolved), `_firstPaint` stays `true` and
   waits for the first non-empty list before ingesting. This prevents the
   empty-set poisoning of `_previousDiscIdSet`.

## Commits

```
723984c  fix(09-bug-015): prevent wisp burst on renderer (re)creation
```

## Files modified

- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — emergence diff logic
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — parallel fix
- `test/infrastructure/mirk/wisp/wisp_emergence_test.dart` — 2 regression tests

## Test coverage

Two targeted regression tests in `wisp_emergence_test.dart`:
- `BUG-015: discs leave viewport then re-enter — no spurious wisps` — simulates pan-away (empty disc list) followed by pan-back (same discs re-appear), asserts zero wisps spawned on re-entry
- `BUG-015: first paint with 0 discs then discs arrive — no spurious wisps` — simulates async provider timing where first frame has 0 discs, second frame has real discs, asserts zero wisps spawned for pre-existing discs

## Known follow-ups

- [ ] The append-only `_previousDiscIdSet` grows monotonically for the lifetime of the renderer. For very long sessions (10k+ discs), consider periodic compaction or switching to a bloom filter if memory becomes a concern (unlikely given typical session sizes)
- [ ] Candlelight and solid_fill renderers do not spawn wisps, so they are not affected. If wisps are added to these renderers in the future, the same append-only + empty-guard pattern must be applied

## Links

- **BUG-010** — parent refactor (`d47e5ab` Commit 5) that introduced the disc-based wisp emergence logic where both bugs lived
- **BUG-013** — related empty-disc-list edge case (fog disappears when panning away), fixed in the same UAT session
- **BUG-012** — the `_lastKnownDiscs` cache from BUG-012 iteration 3 mitigates the empty-disc-list timing at the widget layer, but this bug was at the renderer layer
