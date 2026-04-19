# lib/application/controllers/

`@Riverpod`-annotated controllers that orchestrate cross-layer flows.
Controllers live here (NOT in `lib/presentation/`) because they are
logic, not widgets — they survive UI tree changes (`keepAlive: true`),
they are the single point where business rules are enforced, and they
must stay testable without a widget tree.

## Import rules

Allowed:
- `lib/application/state/` — the sealed state types the controller
  exposes.
- `lib/application/providers/` — every infrastructure dependency goes
  through a provider (DI via `ref.read(...)` / `ref.watch(...)`).
- `lib/domain/` — domain entities, ports, errors.

Forbidden:
- `lib/presentation/` — logic never depends on UI.
- `lib/infrastructure/` directly — always through `application/providers/`
  so tests can override with in-memory fakes.

## Controllers

| File                              | Exposes                                   | State type              | Notes                                                  |
| --------------------------------- | ----------------------------------------- | ----------------------- | ------------------------------------------------------ |
| `active_session_controller.dart`  | `activeSessionControllerProvider`          | `ActiveSessionState`    | GPS session lifecycle — start / stop / stream errors   |

## Testing

Tests instantiate a `ProviderContainer` with overrides for every port:

```dart
final container = ProviderContainer(overrides: [
  sessionStoreProvider.overrideWith((ref) async => fakeSessionStore),
  fixStoreProvider.overrideWith((ref) async => fakeFixStore),
  locationStreamProvider.overrideWith((ref) => fakeLocationStream),
  sessionNotificationServiceProvider.overrideWith((ref) => fakeNotificationService),
]);
```

Hand-rolled fakes (no mockito/mocktail per Phase 03 convention) live
directly in the test file. `FakeLocationStream` is the one shared
helper (`test/helpers/fake_location_stream.dart`) because the signature
is stable and it's referenced from multiple downstream plans
(05-04 UI, 05-06 auto-resume).

SharedPreferences is primed via `SharedPreferences.setMockInitialValues`
— the `sessionSettingsProvider` uses the in-memory mock binding
automatically after `TestWidgetsFlutterBinding.ensureInitialized()`.
