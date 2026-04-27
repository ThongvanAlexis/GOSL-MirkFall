# BUG-015 — Wisp burst "rose" pattern on map open and pan

**Status:** fixed (iteration 2) — see Commits below
**Reported:** 2026-04-27 (UAT walk on `743750d` after BUG-013 fix shipped)
**Re-reported:** 2026-04-27 — still visible after iteration 1 (`723984c`)
**Introduced in:** `d47e5ab` (BUG-010 Option B Commit 5 — disc-based wisp emergence)
**Platform:** cross-platform (renderer CPU-side logic, same on iOS + Android)

## Symptoms

When opening the map, many expanding white circles appear simultaneously
along the boundary of all existing reveal discs, forming a visible "rose"
pattern that quickly fades. The same burst can occur when panning the map
away from the revealed area and back.

## Root cause (three related bugs — iteration 2 found the third)

All bugs are in `_spawnWispsForNewlyEmergedDiscs()` inside
`AtmosphericMirkRenderer` and `HeavenlyCloudsMirkRenderer`.

### A. Viewport exit/re-enter resets the diff set (fixed in iteration 1)

`_previousDiscIdSet` was **replaced** with `currentIds` every frame.
When panning away, `discsInBbox` returned empty; the set was cleared.
On pan-back, all discs appeared "new". Fixed by making the set
append-only (`addAll` instead of replace).

### B. First-paint guard consumed an empty disc list (fixed in iteration 1)

The `_firstPaint` guard consumed the first 0-disc frame from the async
provider and flipped `_firstPaint = false`. Real discs on the next frame
were all treated as "new". Fixed by skipping empty disc lists during
first-paint.

### C. Viewport animation scroll-in (root cause of iteration 2)

The previous fix only captured the discs visible in the INITIAL viewport
on the first non-empty frame. When the map opens, MapLibre animates the
camera (zoom-out settling, fly-to animation) for approximately 5 seconds.
During this animation, pre-existing discs that were OUTSIDE the initial
narrow viewport **scroll into view** and appear "new" to the frame-diff
logic. Each arriving disc spawned ~20 wisps along its perimeter, producing
the "rose of ellipses" pattern at the boundary.

For a session with e.g. 50 discs, only a few might be in the initial
viewport. The remaining ~45 scroll in over ~5 seconds, each triggering
a wisp burst — hundreds of wisps total, concentrated along the fog
boundary.

## Investigation findings (iteration 2)

**Log evidence** (20260427_1131.02_logs.txt):

- Line 45: first paint with `discs=0` (async provider not resolved)
- Line 56: `discsInViewport: produced 2 discs` (viewport expands)
- Lines 87-200: rapid viewport changes (bbox shrinking/expanding as MapLibre
  camera settles) — each bbox change triggers a disc query. For longer
  sessions, each viewport expansion would bring new discs into view.

The log was from a minimal 2-disc session where the bug was not dramatic
(only 2 discs, both at the same point). The user reported the bug on
sessions with more walking history, where the viewport animation scrolls
in many more discs.

The iteration 1 fix (boolean first-paint + append-only) correctly handled
the 2-disc case but did NOT handle the viewport-animation case: it ingested
only the initial viewport's discs, then flipped `_firstPaint = false`.
All subsequent discs entering via the viewport animation were treated as
"newly emerged."

## Strategy / Fix (iteration 2)

Replace the boolean `_firstPaint` with a **time-based warm-up phase**:

1. New constant `kMirkFogWispWarmUpSeconds = 5.0` — covers the ~5 s
   MapLibre camera-settling animation.

2. During warm-up (`sessionElapsed < threshold`), ALL disc IDs entering
   the viewport are silently ingested into `_previousDiscIdSet` without
   spawning wisps. Empty frames are skipped (provider not yet resolved).

3. Warm-up ends when BOTH conditions are met:
   - `sessionElapsed >= kMirkFogWispWarmUpSeconds`
   - At least one non-empty disc list has been seen

4. After warm-up, the normal per-frame diff activates: only disc IDs
   not yet in `_previousDiscIdSet` (genuinely new GPS-fix reveals)
   spawn wisps. The set remains append-only.

This approach absorbs all three race windows (async delay, viewport
animation, session resume) in a single mechanism.

## Commits

```
723984c  fix(09-bug-015): prevent wisp burst on renderer (re)creation (iteration 1)
<TBD>    fix(09-bug-015): time-based warm-up replaces boolean first-paint guard (iteration 2)
```

## Files modified

- `lib/config/constants.dart` — new `kMirkFogWispWarmUpSeconds` constant
- `lib/infrastructure/mirk/atmospheric_mirk_renderer.dart` — `_warmingUp` replaces `_firstPaint`; time-based warm-up in emergence diff
- `lib/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart` — parallel fix
- `test/infrastructure/mirk/wisp/wisp_emergence_test.dart` — 6 tests (rewritten for time-based warm-up)
- `docs/phase09-bug-tracking/BUG-015-wisp-burst-on-open.md` — this file

## Test coverage

Six tests in `wisp_emergence_test.dart`:
1. During warm-up: seed discs do NOT spawn wisps
2. After warm-up: same disc list spawns no new wisps (steady state)
3. After warm-up: one new disc spawns wisps along ITS perimeter only
4. BUG-015: discs leave viewport then re-enter — no spurious wisps
5. BUG-015: first paint with 0 discs then discs arrive during warm-up — no spurious wisps
6. **BUG-015 root-cause**: discs scrolling into viewport during warm-up are absorbed; genuinely new GPS-fix disc after warm-up DOES spawn wisps

## Known follow-ups

- [ ] The append-only `_previousDiscIdSet` grows monotonically for the lifetime of the renderer. For very long sessions (10k+ discs), consider periodic compaction or switching to a bloom filter if memory becomes a concern (unlikely given typical session sizes)
- [ ] Candlelight and solid_fill renderers do not spawn wisps, so they are not affected. If wisps are added to these renderers in the future, the same warm-up pattern must be applied

## Links

- **BUG-010** — parent refactor (`d47e5ab` Commit 5) that introduced the disc-based wisp emergence logic where all three bugs lived
- **BUG-013** — related empty-disc-list edge case (fog disappears when panning away), fixed in the same UAT session
- **BUG-012** — the `_lastKnownDiscs` cache from BUG-012 iteration 3 mitigates the empty-disc-list timing at the widget layer, but this bug was at the renderer layer
