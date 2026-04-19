# lib/application/permissions/

Pure-logic orchestrators for platform permission flows. Deliberately
NO widgets here — permission UI screens live in
`lib/presentation/screens/` (Plan 05-04 landing):

- `PermissionRationaleScreen` — the pre-prompt full-screen explainer.
- `PermissionDeniedScreen` — GPS-07 recovery with deep-link.

The functions in this layer are the testable, DI-seamable core that
those screens dispatch to. Keeping them in `application/` means
controllers (Plan 05-03 `ActiveSessionController` and beyond) can also
invoke them without a widget tree.

## Import rules

Allowed:
- `domain/errors/` (`LocationPermissionOutcome`, ...).
- `domain/ids/`.
- `package:permission_handler` (platform adapter — this layer owns the
  wrap so the presentation layer never imports it).

Forbidden:
- `presentation/` (logic layer never depends on UI).
- `infrastructure/` directly — go through `application/providers/`.

## Testing

Every function here takes a `PermissionRequester`-like optional
parameter with a sensible default, so tests inject a capturing fake
without needing `PermissionHandlerPlatform` overrides or widget-test
bindings. See `test/application/permissions/`.

## Entries

| File                             | Exports                          | Notes                                                     |
| -------------------------------- | -------------------------------- | --------------------------------------------------------- |
| `location_permission_flow.dart`  | `requestLocationAlways`          | Two-step Android 10+ chain, regression-locked             |
|                                  | `openLocationSettings`           | Deep-link thunk wrapping `permission_handler.openAppSettings` |
|                                  | `PermissionRequester` typedef    | Injection seam                                            |
