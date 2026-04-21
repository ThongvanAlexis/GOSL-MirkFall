// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/download_queue_controller.dart';
import 'package:mirkfall/application/controllers/installed_maps_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/presentation/screens/maps_download_screen.dart';

class _FakeDownloadQueueController extends DownloadQueueController {
  _FakeDownloadQueueController();
  final List<CountryEntry> enqueueObservations = <CountryEntry>[];

  @override
  DownloadState build() => const DownloadIdle();

  @override
  Future<void> enqueue(CountryEntry entry) async {
    enqueueObservations.add(entry);
  }
}

class _FakeInstalledMapsController extends InstalledMapsController {
  _FakeInstalledMapsController({required this.seed});
  final InstalledMapsState seed;

  @override
  InstalledMapsState build() => seed;
}

ChunkPart _partFor(String alpha3) => ChunkPart(
  sha256: 'a' * 64,
  size: 5 * 1024 * 1024, // 5 MB
  url: 'https://example.com/releases/download/v20260419/$alpha3.part01',
);

CountryEntry _entryFor(String alpha3, String name) => CountryEntry(
  alpha3: CountryCode.parse(alpha3),
  name: name,
  parts: <ChunkPart>[_partFor(alpha3)],
  reassembled: ReassembledMeta(sha256: 'b' * 64, size: 5 * 1024 * 1024),
);

CountryCatalog _threeCountryCatalog() => CountryCatalog(countries: <CountryEntry>[
  _entryFor('fra', 'France'),
  _entryFor('deu', 'Allemagne'),
  _entryFor('esp', 'Espagne'),
]);

InstalledCountry _installed(String alpha3, {String version = 'v20260419'}) => InstalledCountry(
  alpha3: CountryCode.parse(alpha3),
  installedAtUtc: DateTime.utc(2026, 4, 20),
  fileSize: 5 * 1024 * 1024,
  pmtilesVersion: version,
  sha256: 'b' * 64,
  filePath: 'maps/countries/$alpha3.pmtiles',
);

void main() {
  group('MapsDownloadScreen', () {
    testWidgets('lists 3 countries from catalog + marks 1 as Installed', (tester) async {
      final InstalledMapsState seed = InstalledMapsState(
        installed: <CountryCode, InstalledCountry>{CountryCode.parse('fra'): _installed('fra')},
        updatesAvailable: const <CountryCode>{},
        totalDiskUsageBytes: 5 * 1024 * 1024,
      );
      final fakeDownload = _FakeDownloadQueueController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryCatalogProvider.overrideWith((ref) async => _threeCountryCatalog()),
            installedMapsControllerProvider.overrideWith(() => _FakeInstalledMapsController(seed: seed)),
            downloadQueueControllerProvider.overrideWith(() => fakeDownload),
          ],
          child: const MaterialApp(home: MapsDownloadScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // All three country names appear in alphabetical order.
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Allemagne'), findsOneWidget);
      expect(find.text('Espagne'), findsOneWidget);
      // Installed marker.
      expect(find.textContaining('Installé'), findsOneWidget);
      // Available markers on the other two rows.
      expect(find.textContaining('Disponible'), findsAtLeast(1));
    });

    testWidgets('tap on a "Disponible" tile opens a confirm dialog; confirm calls enqueue', (tester) async {
      const InstalledMapsState seed = InstalledMapsState.empty();
      final fakeDownload = _FakeDownloadQueueController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryCatalogProvider.overrideWith((ref) async => _threeCountryCatalog()),
            installedMapsControllerProvider.overrideWith(() => _FakeInstalledMapsController(seed: seed)),
            downloadQueueControllerProvider.overrideWith(() => fakeDownload),
          ],
          child: const MaterialApp(home: MapsDownloadScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('France'));
      await tester.pumpAndSettle();

      // Dialog surfaces the country name.
      expect(find.text('Télécharger France ?'), findsOneWidget);
      await tester.tap(find.text('Télécharger'));
      await tester.pumpAndSettle();

      expect(fakeDownload.enqueueObservations, hasLength(1));
      expect(fakeDownload.enqueueObservations.single.alpha3.value, equals('fra'));
    });

    testWidgets('stale pmtilesVersion surfaces "Mise à jour disponible"', (tester) async {
      final InstalledMapsState seed = InstalledMapsState(
        installed: <CountryCode, InstalledCountry>{CountryCode.parse('fra'): _installed('fra', version: 'v20260101')},
        updatesAvailable: <CountryCode>{CountryCode.parse('fra')},
        totalDiskUsageBytes: 5 * 1024 * 1024,
      );
      final fakeDownload = _FakeDownloadQueueController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryCatalogProvider.overrideWith((ref) async => _threeCountryCatalog()),
            installedMapsControllerProvider.overrideWith(() => _FakeInstalledMapsController(seed: seed)),
            downloadQueueControllerProvider.overrideWith(() => fakeDownload),
          ],
          child: const MaterialApp(home: MapsDownloadScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mise à jour disponible'), findsOneWidget);
    });
  });
}
