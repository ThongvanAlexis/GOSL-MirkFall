# infrastructure/mirk/

Concrete [`MirkRenderer`](../../domain/mirk/mirk_renderer.dart) implementations.

## Phase 07 content

`noop_mirk_renderer.dart` — stub renderer that paints nothing. Satisfies the seam so the MapView infrastructure + screens compile end-to-end, keeps the fog layer invisible until the real renderer lands.

## Phase 09+ plan

Phase 09 supplies the first non-stub `MirkRenderer` (atmospheric / shader variants, tuned for the zoom-14 parent-tile grid from Phase 03). Any new input the real renderer needs flows through `MirkPaintContext` — the `MirkRenderer` interface itself is locked at exactly 3 public methods (`paint`, `update`, `dispose`) via the compile-time witness in `test/domain/mirk/mirk_renderer_contract_test.dart`.

## Rule of thumb

Adding a method to `MirkRenderer` breaks the contract test by design. If you find yourself needing one, it is a Rule 4 architectural decision for the relevant phase.
