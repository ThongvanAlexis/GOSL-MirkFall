# BUG-015 — Wisp burst "rose" pattern on map open and pan

**Status:** CLOSED (2026-04-27)
**Introduced in:** d47e5ab (BUG-010 Option B Commit 5 — disc-based wisp emergence)

## Symptom

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

**Log evidence** (20260427_1035.20_logs.txt):

- Line 46: `paint(): first invocation — discs=0` (empty first frame).
- Line 54: `discsInViewport: produced 2 discs` (discs arrive next frame).
- Lines 298-299: `hitCount=0` / `produced 0 discs` during pan-away.

## Fix

Two changes to the emergence diff in both renderers:

1. **Append-only `_previousDiscIdSet`**: changed from `_previousDiscIdSet =
   currentIds` (replace) to `_previousDiscIdSet.addAll(currentIds)`. Disc
   IDs that leave the viewport are still remembered; only genuinely new
   GPS-fix discs trigger wisps.

2. **First-paint guard skips empty disc lists**: if the first paint receives
   0 discs (provider not yet resolved), `_firstPaint` stays `true` and
   waits for the first non-empty list before ingesting. This prevents the
   empty-set poisoning of `_previousDiscIdSet`.

## Files modified

- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — emergence diff
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — parallel fix
- `test/infrastructure/mirk/wisp/wisp_emergence_test.dart` — 2 regression tests

## Regression tests

- `BUG-015: discs leave viewport then re-enter — no spurious wisps`
- `BUG-015: first paint with 0 discs then discs arrive — no spurious wisps`
