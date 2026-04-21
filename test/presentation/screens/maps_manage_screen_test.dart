// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/installed_maps_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/presentation/screens/maps_manage_screen.dart';

class _FakeInstalledMapsController extends InstalledMapsController {
  _FakeInstalledMapsController({required this.seed});
  final InstalledMapsState seed;
  final List<CountryCode> deleteObservations = <CountryCode>[];

  @override
  InstalledMapsState build() => seed;

  @override
  Future<void> deleteCountry(CountryCode alpha3) async {
    deleteObservations.add(alpha3);
  }
}

ChunkPart _partFor(String alpha3) => ChunkPart(sha256: 'a' * 64, size: 5 * 1024 * 1024, url: 'https://example.com/releases/download/v20260419/$alpha3.part01');

CountryCatalog _twoCountryCatalog() => CountryCatalog(
  countries: <CountryEntry>[
    CountryEntry(
      alpha3: CountryCode.parse('fra'),
      name: 'France',
      parts: <ChunkPart>[_partFor('fra')],
      reassembled: ReassembledMeta(sha256: 'b' * 64, size: 5 * 1024 * 1024),
    ),
    CountryEntry(
      alpha3: CountryCode.parse('deu'),
      name: 'Allemagne',
      parts: <ChunkPart>[_partFor('deu')],
      reassembled: ReassembledMeta(sha256: 'c' * 64, size: 5 * 1024 * 1024),
    ),
  ],
);

InstalledCountry _installed(String alpha3, {String version = 'v20260419'}) => InstalledCountry(
  alpha3: CountryCode.parse(alpha3),
  installedAtUtc: DateTime.utc(2026, 4, 20),
  fileSize: 5 * 1024 * 1024,
  pmtilesVersion: version,
  sha256: 'b' * 64,
  filePath: 'maps/countries/$alpha3.pmtiles',
);

void main() {
  group('MapsManageScreen', () {
    testWidgets('shows world bundle row with non-deletable delete button', (tester) async {
      const InstalledMapsState seed = InstalledMapsState.empty();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryCatalogProvider.overrideWith((ref) async => _twoCountryCatalog()),
            installedMapsControllerProvider.overrideWith(() => _FakeInstalledMapsController(seed: seed)),
          ],
          child: const MaterialApp(home: MapsManageScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // "Monde (intégré)" appears twice — once as section header, once
      // as tile title.
      expect(find.text('Monde (intégré)'), findsNWidgets(2));
      // The non-deletable IconButton: first (and only) delete icon when
      // no per-country rows are installed.
      final IconButton worldDelete = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline).first);
      expect(worldDelete.onPressed, isNull);
    });

    testWidgets('lists 2 installed countries with size + version + update badge on stale row', (tester) async {
      final InstalledMapsState seed = InstalledMapsState(
        installed: <CountryCode, InstalledCountry>{
          CountryCode.parse('fra'): _installed('fra'),
          CountryCode.parse('deu'): _installed('deu', version: 'v20260101'),
        },
        updatesAvailable: <CountryCode>{CountryCode.parse('deu')},
        totalDiskUsageBytes: 10 * 1024 * 1024,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryCatalogProvider.overrideWith((ref) async => _twoCountryCatalog()),
            installedMapsControllerProvider.overrideWith(() => _FakeInstalledMapsController(seed: seed)),
          ],
          child: const MaterialApp(home: MapsManageScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('France'), findsOneWidget);
      expect(find.text('Allemagne'), findsOneWidget);
      expect(find.textContaining('v20260419'), findsOneWidget);
      expect(find.textContaining('Mise à jour disponible'), findsOneWidget);
    });

    testWidgets('tap delete → confirm → controller.deleteCountry called', (tester) async {
      final InstalledMapsState seed = InstalledMapsState(
        installed: <CountryCode, InstalledCountry>{CountryCode.parse('fra'): _installed('fra')},
        updatesAvailable: const <CountryCode>{},
        totalDiskUsageBytes: 5 * 1024 * 1024,
      );
      final fake = _FakeInstalledMapsController(seed: seed);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [countryCatalogProvider.overrideWith((ref) async => _twoCountryCatalog()), installedMapsControllerProvider.overrideWith(() => fake)],
          child: const MaterialApp(home: MapsManageScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // There are 2 delete icons: one for the world row (disabled) and
      // one for the France row. The France delete is the non-disabled
      // IconButton.
      final Finder deleteIcons = find.widgetWithIcon(IconButton, Icons.delete_outline);
      expect(deleteIcons, findsNWidgets(2));
      // Tap the SECOND delete (the France one).
      await tester.tap(deleteIcons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer la carte de France ?'), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(fake.deleteObservations, hasLength(1));
      expect(fake.deleteObservations.single.value, equals('fra'));
    });
  });
}
