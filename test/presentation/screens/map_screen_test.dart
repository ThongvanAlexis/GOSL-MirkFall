// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/controllers/map_camera_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:mirkfall/infrastructure/map/style_rewriter.dart';
import 'package:mirkfall/presentation/screens/map_screen.dart';
import 'package:mirkfall/presentation/widgets/map_attribution_icon.dart';
import 'package:mirkfall/presentation/widgets/map_country_banner.dart';
import 'package:mirkfall/presentation/widgets/map_follow_me_fab.dart';

import '../../fakes/fake_installed_manifest_repository.dart';
import '../../fakes/fake_map_view.dart';

/// Stub fake builder widget that swallows the MapLibre surface. Calls
/// [onReady] with a [FakeMapView] immediately after the first frame so
/// downstream controllers see a MapView instance via `mapViewProvider`.
class _FakeMapWidget extends StatefulWidget {
  const _FakeMapWidget({required this.onReady, required this.fakeMapView});
  final ValueChanged<MapView> onReady;
  final FakeMapView fakeMapView;

  @override
  State<_FakeMapWidget> createState() => _FakeMapWidgetState();
}

class _FakeMapWidgetState extends State<_FakeMapWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady(widget.fakeMapView);
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFFEFEFEF));
}

/// Fake resolver controller that seeds the country-resolver state.
class _FakeResolverController extends CountryResolverController {
  _FakeResolverController({required this.seed});
  final CountryResolverState seed;

  @override
  CountryResolverState build() => seed;
}

/// Fake active-session controller for tests that need a Tracking state
/// seed on /map entry.
class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController({required this.seed});
  final ActiveSessionState seed;

  @override
  ActiveSessionState build() => seed;
}

Fix _fix({required SessionId sid, required double lat, required double lon}) => Fix(
  id: FixId.parse('fix_01ARZ3NDEKTSV4RRFFQ69G5FAV'),
  sessionId: sid,
  recordedAtUtc: DateTime.utc(2026, 4, 21, 10, 30),
  recordedAtOffsetMinutes: 120,
  latitude: lat,
  longitude: lon,
  accuracyMeters: 10.0,
  speedMps: 1.0,
  headingDegrees: 0.0,
);

CountryCatalog _oneCountryCatalog() {
  final ChunkPart part = ChunkPart(sha256: 'a' * 64, size: 1000, url: 'https://example.com/releases/download/v1/fra.part01');
  return CountryCatalog(
    countries: <CountryEntry>[
      CountryEntry(
        alpha3: CountryCode.parse('deu'),
        name: 'Allemagne',
        parts: <ChunkPart>[part],
        reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1000),
      ),
    ],
  );
}

void main() {
  late Directory tmpDir;
  late FakeInstalledManifestRepository fakeRepo;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('map_screen_test_');
    fakeRepo = FakeInstalledManifestRepository();
    fakeRepo.seedWith(InstalledManifest.empty());
  });

  tearDown(() async {
    try {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    } on Object {
      // Best-effort cleanup; Windows occasionally holds file handles.
    }
  });

  Widget wrapScreen({required FakeMapView fakeMapView, CountryResolverState? resolverSeed, ActiveSessionState? sessionSeed}) {
    return ProviderScope(
      overrides: [
        appSupportDirProvider.overrideWith((ref) async => tmpDir.path),
        installedManifestRepositoryProvider.overrideWith((ref) async => fakeRepo),
        countryCatalogProvider.overrideWith((ref) async => _oneCountryCatalog()),
        if (resolverSeed != null) countryResolverControllerProvider.overrideWith(() => _FakeResolverController(seed: resolverSeed)),
        if (sessionSeed != null) activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(seed: sessionSeed)),
      ],
      child: MaterialApp(
        home: MapScreen(
          mapViewBuilderForTest: ({required StyleRewriter styleRewriter, required PmtilesSource pmtilesSource, required ValueChanged<MapView> onReady}) {
            return _FakeMapWidget(onReady: onReady, fakeMapView: fakeMapView);
          },
        ),
      ),
    );
  }

  testWidgets('renders map stack: burger button + follow-me FAB + attribution icon', (tester) async {
    final fakeMapView = FakeMapView();
    await tester.pumpWidget(wrapScreen(fakeMapView: fakeMapView));
    await tester.pumpAndSettle();

    // Burger menu trigger.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    // Follow-me FAB is present (any MapFollowMeFab instance).
    expect(find.byType(MapFollowMeFab), findsOneWidget);
    // Attribution icon is present.
    expect(find.byType(MapAttributionIcon), findsOneWidget);
  });

  testWidgets('country banner surfaces when viewport NOT in installed', (tester) async {
    final fakeMapView = FakeMapView();
    final CountryResolverState seed = CountryResolverState(viewportCountry: CountryCode.parse('deu'));
    await tester.pumpWidget(wrapScreen(fakeMapView: fakeMapView, resolverSeed: seed));
    await tester.pumpAndSettle();

    expect(find.byType(MapCountryBanner), findsOneWidget);
    expect(find.text('Carte détaillée de Allemagne disponible dans Paramètres › Télécharger une carte'), findsOneWidget);
  });

  testWidgets('country banner absent when viewport IS installed', (tester) async {
    final fakeMapView = FakeMapView();
    final CountryResolverState seed = CountryResolverState(
      activeCountry: CountryCode.parse('deu'),
      viewportCountry: CountryCode.parse('deu'),
      viewportInInstalled: true,
    );
    await tester.pumpWidget(wrapScreen(fakeMapView: fakeMapView, resolverSeed: seed));
    await tester.pumpAndSettle();

    // The MapCountryBanner widget is mounted but renders SizedBox.shrink
    // — so no text with "Carte détaillée" appears.
    expect(find.textContaining('Carte détaillée'), findsNothing);
  });

  testWidgets('tap on menu icon opens the drawer', (tester) async {
    final fakeMapView = FakeMapView();
    await tester.pumpWidget(wrapScreen(fakeMapView: fakeMapView));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Drawer open — "MirkFall" header is present.
    expect(find.text('MirkFall'), findsOneWidget);
    expect(find.text('Aucune session active'), findsOneWidget);
  });

  testWidgets('reaching /map with an active Tracking session auto-opens the camera controller (FAB transitions out of Idle)', (tester) async {
    // Regression guard: previously, MapScreen published the MapView
    // adapter but never called MapCameraController.openForSession(). If
    // a user started a session then navigated to /map via the SessionList
    // "Ouvrir la carte" entry, the controller stayed in MapCameraIdle
    // and the follow-me FAB misleadingly asked them to start a session
    // that was already running.
    final SessionId sid = SessionId.parse('sess_01ARZ3NDEKTSV4RRFFQ69G5FAV');
    final Tracking tracking = Tracking(
      sessionId: sid,
      startedAtUtc: DateTime.now().toUtc().subtract(const Duration(seconds: 30)),
      fixCount: 1,
      distanceFilterMeters: kDefaultDistanceFilterMeters,
      lastFix: _fix(sid: sid, lat: 48.8566, lon: 2.3522),
    );

    final fakeMapView = FakeMapView();
    await tester.pumpWidget(wrapScreen(fakeMapView: fakeMapView, sessionSeed: tracking));
    await tester.pumpAndSettle();

    // Read the camera controller state through a fresh ProviderContainer
    // scoped at the same ProviderScope — pump + settle already exercised
    // the PostFrameCallback that fires onReady → openForSession.
    final BuildContext context = tester.element(find.byType(MapFollowMeFab));
    final ProviderContainer container = ProviderScope.containerOf(context);
    final MapCameraState cameraState = container.read(mapCameraControllerProvider);

    // State is Following (lastFix present → openForSession goes straight
    // to Following, skipping Centering).
    expect(cameraState, isA<MapCameraFollowing>());
    expect((cameraState as MapCameraFollowing).sessionId, equals(sid));

    // Phase 07-07 (2026-04-22): openForSession no longer issues a
    // camera-moving method-channel call. The initial camera
    // positioning flows through MapLibreMap's `initialCameraPosition`
    // at widget-build time (see `_buildMapStack` in map_screen.dart).
    // The FakeMapView used in this test ignores that prop (it's
    // supplied via the `mapViewBuilderForTest` typedef which doesn't
    // pass initial camera). So we only assert the state transition +
    // follow-me side-effects that openForSession still owns.
    expect(fakeMapView.isFollowMeEnabled, isTrue);
    expect(fakeMapView.cameraMovesObserved, isEmpty);
  });
}
