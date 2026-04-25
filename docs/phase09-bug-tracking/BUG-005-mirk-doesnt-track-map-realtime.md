# BUG-005 — Le mirk ne suit pas la carte en temps réel pendant pan/pinch/zoom

**Status:** fixed (2026-04-25)
**Reported:** 2026-04-25 (iOS UAT walk après build `0b96197`)
**Platform:** iOS sideloaded
**Phase context:** Comportement initial Phase 09 — pas une régression de fix précédent. Le wiring `onCameraMove` n'a probablement jamais été câblé.

## Comportement attendu

Quand l'utilisateur pan / pinch / zoom la carte, le fog doit se déplacer / scaler EN MÊME TEMPS que les tiles de basemap, pas après le gesture.

## Comportement observé

Le fog reste à sa position précédente pendant le gesture, puis **snap** à la nouvelle position quand l'utilisateur lâche le doigt.

## Hypothèse forte

`mapViewportProvider` ne reçoit la nouvelle bbox qu'au `onCameraIdle` de MapLibre (un seul event en fin de gesture), pas pendant le `onCameraMove` (continu). Le `MirkOverlay` `ref.watch(mapViewportProvider)` ne rebuild donc qu'à la fin.

Solution : hooker le `onCameraMove` callback de MapLibre pour que la bbox soit publiée en continu pendant le gesture. Le Ticker du MirkOverlay assure un repaint à 60fps qui consommera la bbox la plus récente.

## Diagnostic à confirmer

- Lire `lib/infrastructure/map/maplibre_map_view.dart` — sur quel callback MapLibre publie-t-il la viewport ? Est-ce `onCameraIdle` uniquement ?
- Lire `lib/application/providers/map_viewport_provider.dart` — est-ce que le notifier est piloté par un seul event ou peut-il recevoir des updates continus ?
- Vérifier la fréquence des `setUserLocation` calls dans les logs — si MapLibre fire le callback `onCameraMove` mais qu'il n'est pas câblé au viewport provider, c'est juste du wiring manquant.

## Solutions

1. Câbler `onCameraMove` (en plus de `onCameraIdle`) au `mapViewportProvider`. Throttle si nécessaire (mais probablement inutile à 60fps — le notifier set est cheap).
2. Si `onCameraMove` n'est pas exposé par maplibre_gl Flutter, utiliser un Ticker interne dans `MapLibreMapViewWidget` qui poll le camera state et publie sur le provider.
3. Alternative : faire que le `MirkOverlay` lui-même interroge le `MapView` adapter via son Ticker (au lieu de passer par le provider). Plus direct mais introduit un couplage entre overlay et MapView.

## Resolution

**Resolved:** 2026-04-25

### Findings on the diagnostic hypothesis

The bug-doc hypothesis was MOSTLY correct but the root cause was more specific. The MapLibre Flutter controller already fires `notifyListeners()` on every `onCameraMove` (continuous, ~60 Hz during a gesture) — and `_MapLibreMapViewAdapter._cameraListener` correctly forwards each notification onto the broadcast `viewportUpdates` stream. So `viewportUpdates` was already publishing in realtime; no `onCameraMove` wiring needed.

The bottleneck was the **debounce in `MapViewport`**: every emission CANCELLED + rescheduled the 50 ms timer, so during a continuous gesture the timer never fired (each new emission reset it). `queryViewportBounds()` was only called 50 ms AFTER the gesture's last emission — the user observed this as "fog snaps to position at gesture release".

### Fix

Replaced the debounce with a **leading-edge + trailing throttle**:

- First emission of a burst → `queryViewportBounds()` fires immediately (no wait). The fog tracks the gesture from the very first frame of motion.
- Subsequent emissions inside the throttle window → coalesced into ONE trailing refresh that fires when the window expires.
- If the trailing refresh runs (gesture still ongoing), open a new throttle window so a continuous gesture sustains a steady ~20 Hz refresh cadence (1 / 50 ms window) without thrashing the platform method channel.
- Window expires with no trailing pending → throttle closes; the next emission is a leading edge again.

Cadence cap stays at 1 refresh / 50 ms (= 20 Hz) — well below the overlay's 60 Hz Ticker so the painter always reads a fresh-enough bbox without saturating MapLibre's method channel.

### Test coverage

`test/application/providers/map_viewport_provider_test.dart` — three relevant tests:

1. `viewport emission triggers a leading-edge refresh (no debounce wait)` — replaces the prior "debounced refresh ~50 ms" test. Asserts `queryViewportBounds` fires on the SAME microtask as the emission, not 50 ms later.
2. `rapid-fire emissions inside one window: 1 leading + 1 trailing refresh` — replaces the prior coalesce-by-debounce test. Three emissions inside the window now produce 2 refreshes (leading + trailing), capping cadence while still capturing both edges of the burst.
3. `continuous emissions across multiple windows refresh at throttle cadence (BUG-005 realtime tracking)` — NEW. Simulates a 200 ms continuous gesture (20 emissions @ 10 ms cadence) and asserts >= 3 refreshes fire across the gesture (vs pre-fix exactly 1 at the end). Final state captures the LAST viewport (trailing-window refresh).

### Files changed

- `lib/application/providers/map_viewport_provider.dart` — debounce → throttle. No public API change; the codegen `.g.dart` is unchanged because the `@Riverpod` class shape is identical.
- `test/application/providers/map_viewport_provider_test.dart` — replaced 2 debounce-semantics tests + added 1 realtime-tracking test.

### Verification

- `flutter analyze --fatal-warnings --fatal-infos` on both files — clean.
- `dart format --line-length 160 --set-exit-if-changed` — clean.
- All 6 viewport provider tests green.

### What was NOT changed

- `_MapLibreMapViewAdapter._cameraListener` — already forwards every `notifyListeners()` (covers `onCameraMove` and `onCameraIdle`). No new callback wiring was needed.
- `MapView` port — no surface change. The realtime behaviour is achieved entirely inside the provider.
- `IgnorePointer` wrapper around the overlay (BUG-003 issue C fix) — left strictly alone. The overlay continues to be transparent to pointers, so gestures still reach the MapLibre platform view underneath.
