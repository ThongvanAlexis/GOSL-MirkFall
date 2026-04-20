---
phase: 07-map-integration
plan: 06
type: execute
wave: 6
depends_on: ["07-05"]
files_modified:
  - lib/presentation/screens/about_placeholder_screen.dart
  - lib/presentation/screens/map_screen.dart
  - lib/presentation/screens/maps_download_screen.dart
  - lib/presentation/screens/maps_manage_screen.dart
  - lib/presentation/screens/style_import_placeholder_screen.dart
  - lib/presentation/screens/style_export_placeholder_screen.dart
  - lib/presentation/screens/session_detail_screen.dart
  - lib/presentation/screens/settings_screen.dart
  - lib/presentation/screens/session_list_screen.dart
  - lib/presentation/widgets/session_burger_menu.dart
  - lib/presentation/widgets/map_follow_me_fab.dart
  - lib/presentation/widgets/map_attribution_icon.dart
  - lib/presentation/widgets/map_country_banner.dart
  - lib/presentation/widgets/map_download_progress_chip.dart
  - lib/presentation/router.dart
  - test/presentation/screens/map_screen_test.dart
  - test/presentation/screens/maps_download_screen_test.dart
  - test/presentation/screens/maps_manage_screen_test.dart
  - test/presentation/screens/style_import_placeholder_screen_test.dart
  - test/presentation/screens/session_detail_screen_test.dart
  - test/presentation/screens/settings_screen_test.dart
  - test/presentation/widgets/session_burger_menu_test.dart
  - test/presentation/widgets/map_follow_me_fab_test.dart
  - test/presentation/widgets/map_attribution_icon_test.dart
  - test/presentation/screens/about_placeholder_screen_test.dart
  - test/presentation/widgets/map_country_banner_test.dart
  - test/presentation/widgets/map_download_progress_chip_test.dart
  - test/presentation/map_style_layer_order_test.dart
autonomous: true
requirements:
  - MAP-01
  - MAP-02
  - MAP-03
  - MAP-06
  - MAP-08
  - MAP-10

must_haves:
  truths:
    - "Route `/map` full-screen renders `MapLibreMapViewWidget` (via provider) with burger menu top-left + follow-me FAB bas-droit + attribution icon bas-droit + country banner bottom-non-intrusive"
    - "SessionDetailScreen in active/stopped mode embeds the same `MapView` widget with the same burger menu + follow-me FAB — two entry points, one widget"
    - "Burger menu drawer opens via left-slide (75% width portrait, 40% landscape), lists: Changer le style / Prendre une photo (unwired → snackbar) / Placer un marker (unwired → snackbar) / separator / Position lat,lon / Distance parcourue / Durée session — 3 read-only live-data lines"
    - "SettingsScreen extended with 'Cartes' section (2 ListTiles → /maps/download, /maps/manage) + 'Styles' section (2 placeholders → /styles/import, /styles/export)"
    - "MapsDownloadScreen lists countries from `countryCatalogProvider`, shows 'Installé' / 'Disponible' / 'En téléchargement X %' / 'Mise à jour disponible' state per entry, triggers DownloadQueueController.enqueue on tap"
    - "MapsManageScreen lists installed countries with disk size + version + delete action; world bundle row explicitly read-only with disabled delete"
    - "Placeholder screens show 'En construction — disponible Phase 13' + back button"
    - "Router exposes `/map`, `/maps/download`, `/maps/manage`, `/styles/import`, `/styles/export`; SessionListScreen gains a 'Ouvrir la carte' CTA once at least one session exists"
    - "MapAttributionIcon is a 32dp circular icon bas-droit (opacity ~80%); tap opens bottom-sheet with '© OpenStreetMap contributors' + '© Protomaps' + 2 cliquable external URLs"
    - "AboutPlaceholderScreen (`lib/presentation/screens/about_placeholder_screen.dart`) renders the same attribution block (`© OpenStreetMap contributors` with link to https://www.openstreetmap.org/copyright AND `© Protomaps` with link to https://protomaps.com/) as required by ROADMAP Phase 07 SC#2 (attribution visible on map AND in the À propos screen with official copyright links)"
    - "MapCountryBanner appears when `CountryResolverController.inInstalled == false` with text 'Carte détaillée de <Pays> disponible dans Paramètres › Télécharger une carte' (NO deep-link CTA — user learns the path)"
    - "MapDownloadProgressChip appears in AppBar of settings + maps_download + session_list when `DownloadQueueController.aggregateProgressFraction != null` with '<Pays> — XX %'"
    - "Orientation portrait AND landscape supported on MapScreen + SessionDetailScreen (responsive drawer width)"
    - "`test/presentation/map_style_layer_order_test.dart` parses `assets/maps/style.json` + asserts exact 8-layer order matches Plan 07-01 frozen constant"
    - "FakeMapView (Plan 07-02) used in all widget tests via Riverpod override; no real MapLibre instantiation in unit/widget tests"
  artifacts:
    - path: "lib/presentation/screens/map_screen.dart"
      provides: "/map route full-screen"
      contains: "MapLibreMapViewWidget"
    - path: "lib/presentation/screens/maps_download_screen.dart"
      provides: "country catalog browse + enqueue"
    - path: "lib/presentation/screens/maps_manage_screen.dart"
      provides: "installed countries + delete"
    - path: "lib/presentation/widgets/session_burger_menu.dart"
      provides: "in-session vertical drawer with 3 unwired ListTile + 3 live-data lines"
    - path: "lib/presentation/widgets/map_attribution_icon.dart"
      provides: "MAP-03 attribution bas-droit + bottom sheet"
      contains: "OpenStreetMap"
    - path: "lib/presentation/screens/about_placeholder_screen.dart"
      provides: "MAP-03 attribution block on À propos screen (SC#2 second half)"
      contains: "OpenStreetMap"
    - path: "lib/presentation/router.dart"
      provides: "5 new routes wired"
      contains: "/maps/download"
    - path: "test/presentation/map_style_layer_order_test.dart"
      provides: "regression guard on style.json layer order"
  key_links:
    - from: "lib/presentation/screens/map_screen.dart"
      to: "lib/application/providers/map_providers.dart"
      via: "ref.watch on mapViewProvider + countryResolverController + mapCameraController"
      pattern: "ref.watch(mapViewProvider)"
    - from: "lib/presentation/screens/settings_screen.dart"
      to: "lib/presentation/router.dart"
      via: "ListTile onTap context.push('/maps/download')"
      pattern: "context.push('/maps/"
    - from: "lib/presentation/widgets/session_burger_menu.dart"
      to: "lib/application/controllers/active_session_controller.dart"
      via: "subscribes to fix stream for lat/lon + distance + chrono"
      pattern: "activeSessionControllerProvider"
---

<objective>
Build all new screens + widgets + router extensions for Phase 07. Every widget consumes providers/controllers from Plan 07-05; none directly import `lib/infrastructure/` or `maplibre_gl`. All widget tests run via `FakeMapView` + Riverpod overrides.

Purpose: The user-facing deliverable of Phase 07 — a full-screen interactive map with session-aware UX, a download-a-country screen, a manage-maps screen, and placeholder entry points for Phase 11/13 features. Locks layout decisions before Phase 09 fog rendering piles UX concerns on top.
Output: 5 new screens + 5 new widgets + router updated + 12 widget tests + 1 layer-order regression test.
</objective>

<execution_context>
@C:/Users/oliver/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/oliver/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-map-integration/07-CONTEXT.md
@.planning/phases/07-map-integration/07-RESEARCH.md
@.planning/phases/07-map-integration/07-05-SUMMARY.md
@CLAUDE.md
@lib/presentation/router.dart
@lib/presentation/screens/settings_screen.dart
@lib/presentation/screens/session_detail_screen.dart
@lib/presentation/screens/session_list_screen.dart
@lib/presentation/widgets/active_session_banner.dart
@lib/presentation/widgets/app_shell.dart

<interfaces>
<!-- From Phase 05 — existing UI patterns to preserve -->

Phase 05 screen structure:
```dart
class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Paramètres')),
    body: ListView(children: [
      ListTile(title: Text('Rayon de révélation'), onTap: () { /* ... */ }),
      // Phase 07 EXTENSIONS go here
    ]),
  );
}
```

Phase 05 router.dart:
```dart
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SessionListScreen()),
      GoRoute(path: '/sessions/:id', builder: (_, state) => SessionDetailScreen(id: SessionId.parse(state.pathParameters['id']!))),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      // Phase 07 ADDS: /map, /maps/download, /maps/manage, /styles/import, /styles/export
    ],
  );
}
```

Phase 05 widget test override idiom (re: Override is NOT exported):
```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      activeSessionControllerProvider.overrideWith(() => FakeActiveSessionController()),
      mapViewProvider.overrideWith((ref) => FakeMapView()),
    ],
    child: MaterialApp.router(routerConfig: ref.read(appRouterProvider)),
  ),
);
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: MapScreen + MapAttributionIcon + MapFollowMeFab + MapCountryBanner + layer-order regression test + placeholder screens + router extension</name>
  <files>
    lib/presentation/screens/map_screen.dart,
    lib/presentation/screens/style_import_placeholder_screen.dart,
    lib/presentation/screens/style_export_placeholder_screen.dart,
    lib/presentation/widgets/map_follow_me_fab.dart,
    lib/presentation/widgets/map_attribution_icon.dart,
    lib/presentation/widgets/map_country_banner.dart,
    lib/presentation/router.dart,
    test/presentation/screens/map_screen_test.dart,
    test/presentation/screens/style_import_placeholder_screen_test.dart,
    test/presentation/widgets/map_follow_me_fab_test.dart,
    test/presentation/widgets/map_attribution_icon_test.dart,
    test/presentation/widgets/map_country_banner_test.dart,
    test/presentation/map_style_layer_order_test.dart
  </files>
  <behavior>
    - **`MapScreen`**: full-screen Stack. Layers:
      - `MapLibreMapViewWidget` (from Plan 07-03) at z-index 0
      - Positioned top-left: burger menu button (Task 2 widget)
      - Positioned bottom-right: `MapFollowMeFab` + `MapAttributionIcon` stacked vertically
      - Positioned bottom-center (non-intrusive): `MapCountryBanner` if viewportCountry not installed
      - AppBar hidden (no Scaffold AppBar); navigation via burger + back gesture + `SystemNavigator` to prev route.
    - **`MapFollowMeFab`**: Material FAB (crosshair icon), consumes `mapCameraControllerProvider` state. Tap → `toggleFollowMe()`. Colour tint reflects state (primary when FollowingUser, secondary when FreePan).
    - **`MapAttributionIcon`**: 32dp circular button bas-droit, 80% opacity Material icon (Icons.info_outline or similar). Tap → `showModalBottomSheet` with:
      - '© OpenStreetMap contributors' + cliquable link to `openstreetmap.org/copyright`
      - '© Protomaps' + cliquable link to `protomaps.com`
      - Links open via `url_launcher` — AUDIT: url_launcher is already pinned? If NOT, add to DEPENDENCIES.md Plan 07-01 OR use `SharePlus` existing Phase 01 pin. Decision: use a Text widget with a `TextButton` that copies the URL to clipboard + shows snackbar "URL copiée" (no new dep). Document the trade-off in summary: clicking-through to browser is a Phase 15 polish.
    - **`MapCountryBanner`**: `AnimatedContainer` at bottom that slides in from y=-40 when `CountryResolverController.state.inInstalled == false`. Copy: "Carte détaillée de <Pays> disponible dans Paramètres › Télécharger une carte". `<Pays>` derived from catalog entry's `name`. NO CTA button.
    - **Placeholder screens** `style_import_placeholder_screen.dart` + `style_export_placeholder_screen.dart`: each `Scaffold` with AppBar back button + Centered text "En construction — disponible en Phase 13" + small Icon.
    - **`router.dart`** extension:
      - Add `/map` route → `MapScreen`
      - Add `/maps/download` route → `MapsDownloadScreen` (Task 2)
      - Add `/maps/manage` route → `MapsManageScreen` (Task 2)
      - Add `/styles/import` → `StyleImportPlaceholderScreen`
      - Add `/styles/export` → `StyleExportPlaceholderScreen`
      - Preserve existing routes exactly; preserve `rootNavigatorKey`.
      - `/map` and `/maps/*` use `context.push` (per CLAUDE.md §Navigation — user expects back).
    - **Layer-order regression test** `test/presentation/map_style_layer_order_test.dart`:
      - Reads `assets/maps/style.json` via `rootBundle` in a `testWidgets` context
      - Parses, extracts `layers[].id`, asserts exact equality with `kStyleLayerOrder = ['background', 'landcover', 'water', 'boundaries', 'roads', 'pois', 'mirk_fog', 'user_location']`
      - Fails loudly if Phase 09 reorders (regression guard)
    - **Widget tests**:
      - `map_screen_test.dart`: pump with FakeMapView override + seed active session → assert burger menu present, follow-me FAB present, attribution icon present, country banner absent (no viewport update yet); pump a viewport update via FakeMapView.pushViewport + seed CountryResolverController → banner appears with correct copy
      - `map_follow_me_fab_test.dart`: tap → mapCameraController.toggleFollowMe called (verified via fake controller)
      - `map_attribution_icon_test.dart`: tap → bottom-sheet visible with OSM + Protomaps text
      - `map_country_banner_test.dart`: state-driven visibility + copy correctness
      - `style_import_placeholder_screen_test.dart`: "En construction" text + back button functional
  </behavior>
  <action>
    1. **Placeholder screens** first (smallest) — GOSL header + `StatelessWidget` + Scaffold.

    2. **3 widgets** (follow-me FAB + attribution icon + country banner) as independent `ConsumerWidget` files, each ~60-80 LoC.

    3. **`MapScreen`** — ~150 LoC including Stack layout + Riverpod watches + burger menu mount point (the drawer itself is Task 2's widget; MapScreen provides the Scaffold.key for it).

    4. **`router.dart`** extension — 5 new GoRoutes. Regenerate router.g.dart via `build_runner`.

    5. **SessionListScreen extension**: add a "Ouvrir la carte" button/tile that `context.push('/map')`, visible only when sessions.isNotEmpty. ~15 LoC. Update paired `session_list_screen_test.dart` if it asserts count of ListTiles (soft dependency).

    6. **Widget tests** — 5 tests + layer-order regression test. Use FakeMapView + fake controllers.

    7. **Layer-order test** is the ONE piece of Phase 09 insurance in this plan. Do not skip.

    8. **Analyze + headers + leak scan + format** all green.

    9. Commit.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/presentation/ test/presentation/ &&
      flutter test test/presentation/screens/map_screen_test.dart test/presentation/screens/style_import_placeholder_screen_test.dart test/presentation/widgets/map_follow_me_fab_test.dart test/presentation/widgets/map_attribution_icon_test.dart test/presentation/widgets/map_country_banner_test.dart test/presentation/map_style_layer_order_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    MapScreen renders via FakeMapView in widget tests. 3 map widgets independently testable. 2 placeholder screens navigable. Router has 5 new routes. Layer-order regression test green. No maplibre_gl leak into presentation.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: MapsDownloadScreen + MapsManageScreen + MapDownloadProgressChip + SessionBurgerMenu</name>
  <files>
    lib/presentation/screens/maps_download_screen.dart,
    lib/presentation/screens/maps_manage_screen.dart,
    lib/presentation/widgets/map_download_progress_chip.dart,
    lib/presentation/widgets/session_burger_menu.dart,
    test/presentation/screens/maps_download_screen_test.dart,
    test/presentation/screens/maps_manage_screen_test.dart,
    test/presentation/widgets/map_download_progress_chip_test.dart,
    test/presentation/widgets/session_burger_menu_test.dart
  </files>
  <behavior>
    - **`MapsDownloadScreen`** ConsumerWidget:
      - AppBar with title "Télécharger une carte" + `MapDownloadProgressChip` as trailing action when active download
      - Body: ListView.builder over `countryCatalogProvider.value?.countries`
      - Each list tile: country `name`, subtitle with total size (sum of parts), trailing indicator:
        - If installed with matching catalog tag → `Icon(Icons.check, color: green)` + text "Installé"
        - If installed with stale tag → orange dot + "Mise à jour disponible"
        - If currently downloading → circular progress + `"XX %"`
        - Else → download icon + "Disponible"
      - onTap → shows confirmation dialog ("Télécharger <name> (X GB) ?") → on confirm → `downloadQueueController.enqueue(entry)`
      - No search / grouping in Phase 07 — alphabetic sort (Claude's Discretion; document in summary).
    - **`MapsManageScreen`** ConsumerWidget:
      - AppBar title "Gérer les cartes installées" + `MapDownloadProgressChip`
      - Body: ListView with 2 sections:
        - Section 1: "Monde (intégré)" — non-deletable, shows file_size (856 KB from kWorldBundleSha256 companion const OR from actual file length)
        - Section 2: "Pays installés" — installedMapsController.installed values sorted by name
          - Each tile: name + subtitle "`<size GB>` · version `<pmtilesVersion>`"
          - Trailing: orange "Mise à jour" badge if updatesAvailable includes this alpha3 (onTap → re-enqueue via downloadQueueController)
          - IconButton delete → confirmation dialog → installedMapsController.deleteCountry
      - Footer: "Espace total utilisé : X GB"
    - **`MapDownloadProgressChip`**: small `Chip` in AppBar trailing with `LinearProgressIndicator(value: fraction)` + "<Pays> XX %" text. Nil when aggregateProgressFraction is null.
    - **`SessionBurgerMenu`**: `Drawer` widget mounted via MapScreen's Scaffold.drawer. Content per CONTEXT.md spec:
      - ListTile "Changer le style" onTap → `showModalBottomSheet` listing installed styles (Phase 07 = 1 entry, active marker; Phase 13 expands)
      - ListTile "Prendre une photo" onTap → `showSnackBar('Disponible en Phase 11')`
      - ListTile "Placer un marker" onTap → `showSnackBar('Disponible en Phase 11')`
      - `Divider()`
      - Live-data block (refreshed via `StreamBuilder` on active fix + chrono tick):
        - Row 1: "Position : <lat, lon>" or "En attente GPS..." (6 decimals — Claude's Discretion; documented)
        - Row 2: "Distance : X.XX km" or "X m" (km if > 1 km; computed by haversine over fixes — helper in `lib/domain/gps/` or local to this widget)
        - Row 3: "Durée : HH:MM:SS" — chrono from `session.startedAtUtc` ticking every 1 s (reuse Phase 05 `_ChronoCard` helper if extractable; otherwise inline)
      - Responsive width: MediaQuery.orientation portrait → 75% width; landscape → 40% width (via `Drawer(width: …)` in Flutter 3.x).
    - **Widget tests**:
      - MapsDownloadScreen: pump with 3-country catalog fixture + 1 installed → 3 tiles, correct "Installé"/"Disponible"/"En téléchargement" indicators; tap on "Disponible" tile opens dialog; confirm → downloadQueueController.enqueue called
      - MapsManageScreen: pump with 2 countries installed (1 with stale version) → 2 tiles + orange badge on stale; tap delete → confirmation → installedMapsController.deleteCountry called; world row has no delete button
      - MapDownloadProgressChip: pump with 50% progress → "<name> 50 %" visible; nil state → chip absent
      - SessionBurgerMenu: pump with active session + fake fix → position row + distance row + chrono tick present; tap "Prendre une photo" → snackbar visible
  </behavior>
  <action>
    1. **Widgets first**: MapDownloadProgressChip + SessionBurgerMenu (Drawer). ~120 LoC + ~200 LoC.

    2. **Screens**: MapsDownloadScreen ~220 LoC, MapsManageScreen ~180 LoC.

    3. **Widget tests** with Riverpod overrides for catalog, installedMapsController, downloadQueueController, activeSessionController — all via fakes from Plan 07-02.

    4. **Lint + format + analyze + headers** all green.

    5. Commit each screen + each widget in separate atomic commits.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/presentation/ test/presentation/ &&
      flutter test test/presentation/screens/maps_download_screen_test.dart test/presentation/screens/maps_manage_screen_test.dart test/presentation/widgets/map_download_progress_chip_test.dart test/presentation/widgets/session_burger_menu_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    4 new presentation files + 4 widget tests green. Download + manage screens cover happy-path UX. Burger menu lists 3 unwired actions + 3 live-data rows.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: SessionDetailScreen integration + SessionListScreen '/map' entry + SettingsScreen 'Cartes' + 'Styles' sections</name>
  <files>
    lib/presentation/screens/session_detail_screen.dart,
    lib/presentation/screens/session_list_screen.dart,
    lib/presentation/screens/settings_screen.dart,
    test/presentation/screens/session_detail_screen_test.dart,
    test/presentation/screens/settings_screen_test.dart
  </files>
  <behavior>
    - **`SessionDetailScreen`** EXTENDED:
      - Previously (Phase 05): dashboard text + banner. Now: Stack with `MapLibreMapViewWidget` at z=0 + dashboard overlay top-right or embedded in burger menu.
      - Preserve existing Phase 05 functionality — stop session button must remain accessible (now in burger menu under "Arrêter la session" — add a 4th action to the burger menu for session-stop when state is Tracking).
      - Camera opens at session fix or last-known-fix with Z=13 (delegated to `MapCameraControllerProvider.openForSession(sessionId)`).
      - Stopped session: same layout, Phase 09 will add the fix trajectory; Phase 07 just shows last fix as a static circle (user_location layer).
      - Widget test: pump with active session + fake MapView → burger menu opens, lat/lon row shows session fix, stop button fires activeSessionController.stop()
    - **`SessionListScreen`** EXTENDED:
      - When `sessions.isNotEmpty`: add a top-right `IconButton(Icons.map)` in AppBar → `context.push('/map')`. Tooltip "Ouvrir la carte".
      - When empty: no map button (user funneled to create-session, Phase 05 UX preserved).
      - Widget test extension: with 0 sessions no map button; with 1 session button appears.
    - **`SettingsScreen`** EXTENDED:
      - After existing "Rayon de révélation" section, add 2 new sections:
        - **Cartes**:
          - ListTile icon=download, title="Télécharger une carte", onTap `context.push('/maps/download')`
          - ListTile icon=folder, title="Gérer les cartes installées", onTap `context.push('/maps/manage')`
        - **Styles**:
          - ListTile icon=file_upload, title="Importer un style de mirk", subtitle="En construction (Phase 13)", onTap `context.push('/styles/import')`
          - ListTile icon=file_download, title="Exporter un style de mirk", subtitle="En construction (Phase 13)", onTap `context.push('/styles/export')`
      - Existing Phase 05 settings preserved. No debug-menu removal.
      - AppBar trailing → `MapDownloadProgressChip` if active download (chip re-used across multiple screens; inject via ConsumerWidget).
      - Widget test extension: 4 new ListTiles visible + tap on each navigates via context.push (verified via a mock router or by observing the emitted navigation event).
  </behavior>
  <action>
    1. **SessionDetailScreen refactor**: carefully preserve Phase 05 banner + stop-session wiring. Wrap existing content in Stack under MapLibreMapViewWidget. Session-stop action migrates to burger menu (add ListTile with IconData.stop).

    2. **SessionListScreen extension**: add AppBar `actions: [IconButton(Icons.map, onTap: () => context.push('/map'))]` conditional on sessions.isNotEmpty. Update paired test.

    3. **SettingsScreen extension**: 2 new sections + 4 ListTiles. Extract section-header helper for visual consistency.

    4. **Widget tests** updated — preserve existing Phase 05 assertions, add new ones. Run all existing Phase 05 tests in the session_* suite to confirm no regression.

    5. **Analyze + headers + leak + format** all green.

    6. Commit.
  </action>
  <verify>
    <automated>
      dart run build_runner build --delete-conflicting-outputs &&
      flutter analyze --fatal-infos lib/presentation/ test/presentation/ &&
      flutter test test/presentation/screens/session_detail_screen_test.dart test/presentation/screens/session_list_screen_test.dart test/presentation/screens/settings_screen_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    SessionDetailScreen now renders the map + burger menu + preserves Phase 05 stop flow. SessionListScreen gains the /map entry. SettingsScreen carries 'Cartes' and 'Styles' sections. All existing Phase 05 tests still green.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: Extend AboutPlaceholderScreen with MAP-03 attribution block (SC#2 second half)</name>
  <files>
    lib/presentation/screens/about_placeholder_screen.dart,
    test/presentation/screens/about_placeholder_screen_test.dart
  </files>
  <behavior>
    - `AboutPlaceholderScreen` PRESERVES all existing Phase 01 behaviour verbatim:
      - 7-tap easter egg unlocking `/debug` (inter-tap window + total-window reset logic untouched)
      - GestureDetector on the body
      - AppBar title "À propos"
      - Phase 15 placeholder text preserved
    - NEW attribution block added below the existing placeholder text:
      - Line 1: `© OpenStreetMap contributors` — `TextButton` (or `InkWell`-wrapped `Text`) that on tap opens `https://www.openstreetmap.org/copyright` via the same link-handling strategy used by `MapAttributionIcon` (Task 1). If Task 1 settled on copy-to-clipboard + snackbar (no `url_launcher` dep), the À propos screen uses the SAME pattern — consistency matters more than which path was chosen. If Task 1 landed on a different strategy, mirror it here.
      - Line 2: `© Protomaps` — same pattern, target `https://protomaps.com/`
      - Lines are styled subtly (small font size, muted colour) so the Phase 15 "full screen" later can restructure without breaking the test.
    - Separator/spacing between the existing placeholder text and the attribution block — visually distinct so users scanning the screen can find the attribution.
    - The 7-tap easter egg continues to work on taps that hit the body BUT NOT on the new `TextButton`/`InkWell` children (link taps are consumed by their own GestureDetector; plain-area taps still feed the counter). Test this invariant explicitly.
    - **Widget test `about_placeholder_screen_test.dart`**:
      - Renders the widget; asserts `find.text('© OpenStreetMap contributors')` and `find.text('© Protomaps')` both return exactly one widget.
      - Asserts the link URLs are present in the widget tree (either via the TextButton's `onPressed` callback capture OR via a dedicated testable `Uri` field exposed at the widget/state boundary).
      - Asserts the 7-tap easter egg STILL triggers when the taps land on the body area (not on the link buttons).
      - Asserts that tapping the `© OpenStreetMap contributors` button does NOT increment the easter-egg counter (link taps are consumed).
      - Tests the link-handling strategy chosen in Task 1: if copy-to-clipboard, assert a snackbar appears after tap with expected text + assert Clipboard.getData returns the URL; if url_launcher, assert the mock url_launcher received the expected Uri.
    - Preserve the `AboutPlaceholderScreen` test file if one already exists (Phase 01 shipped the 7-tap tests) — extend rather than rewrite.
  </behavior>
  <action>
    1. **Read existing `lib/presentation/screens/about_placeholder_screen.dart`** (Phase 01 output). Preserve every line of the 7-tap state-machine logic.

    2. **Extend the `build` method** — wrap the existing `Text` in a `Column` that also contains the attribution block. The `GestureDetector` stays as the outermost widget so body taps still count toward the easter egg.

    3. **Link-handling strategy** — mirror exactly the choice landed in Task 1 (Plan 07-06). Extract a small shared helper `_openAttributionLink(BuildContext context, Uri url)` into `lib/presentation/widgets/map_attribution_icon.dart` (or a new `lib/presentation/widgets/_attribution_link_handler.dart`) so both the map overlay and the À propos screen call the same function — no drift between the two copies of the same UX. Document in the 07-06 SUMMARY which path was taken.

    4. **Widget test** per behavior spec. Seed with a `TestWidgetsFlutterBinding` + a `MaterialApp.router` or `MaterialApp(home: AboutPlaceholderScreen())`. Use `tester.tap(find.text('© OpenStreetMap contributors'))` + `await tester.pumpAndSettle()` to drive the link tap.

    5. **Check existing Phase 01 `about_placeholder_screen_test.dart`** — if Phase 01 shipped one, extend it (keep 7-tap tests + add attribution tests). If Phase 01 did not ship one, create this new file.

    6. **Analyze + format + headers + leak + avoid_remote_pmtiles all green**.

    7. Commit: `feat(07-06): ajoute attribution OSM + Protomaps sur AboutPlaceholderScreen (MAP-03 SC#2)`.
  </action>
  <verify>
    <automated>
      flutter analyze --fatal-infos lib/presentation/screens/about_placeholder_screen.dart test/presentation/screens/about_placeholder_screen_test.dart &&
      flutter test test/presentation/screens/about_placeholder_screen_test.dart &&
      dart run tool/check_avoid_maplibre_leak.dart &&
      dart run tool/check_avoid_remote_pmtiles.dart &&
      dart run tool/check_headers.dart
    </automated>
  </verify>
  <done>
    AboutPlaceholderScreen renders both attribution lines with working link-handling (mirroring Task 1's strategy). 7-tap easter egg preserved. Widget test covers attribution presence + link-tap behaviour + easter-egg isolation. ROADMAP SC#2 second half (attribution on À propos screen) now satisfied.
  </done>
</task>

</tasks>

<verification>
```
dart run build_runner build --delete-conflicting-outputs &&
flutter analyze --fatal-infos --fatal-warnings &&
flutter test test/presentation/ &&
dart run tool/check_avoid_maplibre_leak.dart &&
dart run tool/check_avoid_remote_pmtiles.dart &&
dart run tool/check_headers.dart
```
</verification>

<success_criteria>
- 5 new screens + 5 new widgets compiled + tested
- Router has 5 new routes + SessionListScreen has /map entry
- SettingsScreen extended with Cartes + Styles sections
- SessionDetailScreen integrates MapLibreMapViewWidget + preserves Phase 05 stop flow
- Attribution bottom-sheet lists OSM + Protomaps (MAP-03)
- Country banner surfaces "Télécharger dans Paramètres" copy (verbatim user decision)
- Burger menu slides from left with 3 unwired ListTile + 3 live-data rows
- Responsive drawer width portrait/landscape
- Layer-order regression test green
- FakeMapView used in every widget test — no real MapLibre instantiation
</success_criteria>

<output>
After completion, create `.planning/phases/07-map-integration/07-06-SUMMARY.md`:
- Attribution link strategy (copy-to-clipboard vs url_launcher) decision + Phase 15 migration note
- Distance+chrono helper extraction (kept inline vs moved to lib/domain/gps/distance.dart)
- SessionDetailScreen stop-session UX migration (to burger menu) — document the Phase 05 banner location choice
- Orientation landscape test coverage (which widget tests run under `binding.window.physicalSize` override)
- Commit hashes + file counts
</output>
