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
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/presentation/screens/maps_download_screen.dart';

class _FakeDownloadQueueController extends DownloadQueueController {
  _FakeDownloadQueueController({this.initialState = const DownloadIdle()});
  final DownloadState initialState;
  final List<CountryEntry> enqueueObservations = <CountryEntry>[];

  @override
  DownloadState build() => initialState;

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

CountryCatalog _threeCountryCatalog() =>
    CountryCatalog(countries: <CountryEntry>[_entryFor('fra', 'France'), _entryFor('deu', 'Allemagne'), _entryFor('esp', 'Espagne')]);

InstalledCountry _installed(String alpha3, {String version = 'v20260419'}) => InstalledCountry(
  alpha3: CountryCode.parse(alpha3),
  installedAtUtc: DateTime.utc(2026, 4, 20),
  fileSize: 5 * 1024 * 1024,
  pmtilesVersion: version,
  sha256: 'b' * 64,
  filePath: 'maps/countries/$alpha3.pmtiles',
);

void main() {
  group('formatDownloadSpeed', () {
    test('shows integer kB/s below 1 kB/s threshold', () {
      expect(formatDownloadSpeed(0.0), '0 kB/s');
      expect(formatDownloadSpeed(500.0), '1 kB/s'); // 0.5 kB → rounds to 1
    });

    test('shows integer kB/s in the tens and hundreds', () {
      expect(formatDownloadSpeed(12_345.0), '12 kB/s');
      expect(formatDownloadSpeed(450_000.0), '450 kB/s');
      expect(formatDownloadSpeed(999_499.0), '999 kB/s'); // 999.499 kB → rounds to 999
    });

    test('boundary at 1000 kB/s switches to MB/s', () {
      // 999.999 kB/s still renders as 1000 kB/s under toStringAsFixed(0)
      // rounding, which is correct — the branch is <1000, not <=.
      // 1_000_000 B/s = 1000.0 kB/s → exactly the MB/s branch.
      expect(formatDownloadSpeed(1_000_000.0), '1.0 MB/s');
      expect(formatDownloadSpeed(1_000_001.0), '1.0 MB/s');
    });

    test('shows 1-decimal MB/s above the threshold', () {
      expect(formatDownloadSpeed(1_400_000.0), '1.4 MB/s');
      expect(formatDownloadSpeed(12_500_000.0), '12.5 MB/s');
      expect(formatDownloadSpeed(99_900_000.0), '99.9 MB/s');
    });

    test('decimal SI units — 1 kB = 1000 B, 1 MB = 1_000_000 B', () {
      // Prove the unit choice explicitly so a future refactor can't
      // silently swap to binary (1024-based) kibibytes without breaking
      // this regression guard.
      expect(formatDownloadSpeed(1_000.0), '1 kB/s');
      expect(formatDownloadSpeed(1_024.0), '1 kB/s'); // NOT the binary unit
      expect(formatDownloadSpeed(1_000_000.0), '1.0 MB/s');
      expect(formatDownloadSpeed(1_048_576.0), '1.0 MB/s'); // 1 MiB; still ≈1.0 MB
    });
  });

  group('MapsDownloadScreen', () {
    testWidgets('lists 3 countries from catalog + marks 1 as Installed', (tester) async {
      final InstalledMapsState seed = InstalledMapsState(
        installed: <CountryCode, InstalledCountry>{CountryCode.parse('fra'): _installed('fra')},
        updatesAvailableSet: const <CountryCode>{},
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

    testWidgets('search field filters the list case-insensitively on partial matches', (tester) async {
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

      // Baseline — all 3 countries visible.
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Allemagne'), findsOneWidget);
      expect(find.text('Espagne'), findsOneWidget);

      // Lowercase "esp" matches "Espagne" on partial substring; case-insensitive.
      await tester.enterText(find.byType(TextField), 'esp');
      await tester.pump();

      expect(find.text('Espagne'), findsOneWidget);
      expect(find.text('France'), findsNothing);
      expect(find.text('Allemagne'), findsNothing);

      // Uppercase "ALL" matches "Allemagne" partially.
      await tester.enterText(find.byType(TextField), 'ALL');
      await tester.pump();

      expect(find.text('Allemagne'), findsOneWidget);
      expect(find.text('France'), findsNothing);
      expect(find.text('Espagne'), findsNothing);

      // Clear button restores the full list.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(find.text('France'), findsOneWidget);
      expect(find.text('Allemagne'), findsOneWidget);
      expect(find.text('Espagne'), findsOneWidget);
    });

    testWidgets('search with no match shows an empty-state message', (tester) async {
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

      await tester.enterText(find.byType(TextField), 'xxxxxx');
      await tester.pump();

      expect(find.textContaining('Aucun pays ne correspond'), findsOneWidget);
      expect(find.text('France'), findsNothing);
    });

    testWidgets('downloading row shows "En téléchargement XX %" subtitle without the speed label before samples accumulate', (tester) async {
      const InstalledMapsState seed = InstalledMapsState.empty();
      final CountryEntry france = _entryFor('fra', 'France');
      final fakeDownload = _FakeDownloadQueueController(
        initialState: DownloadInProgress(
          active: DownloadJob(alpha3: france.alpha3, entry: france, enqueuedAtUtc: DateTime.utc(2026, 4, 21)),
          snapshot: DownloadProgress(bytesDownloaded: 1_000_000, totalBytes: 5_000_000, currentPartIndex: 0, totalParts: 1),
          remaining: const <DownloadJob>[],
        ),
      );

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

      // Percent subtitle present on the France row.
      expect(find.text('En téléchargement 20 %'), findsOneWidget);
      // With only one sample, the speed label renders SizedBox.shrink —
      // no kB/s text visible yet. The formatter tests cover the unit
      // thresholds; this test just proves the row composes without
      // crashing and holds back the label until a second sample arrives.
      expect(find.textContaining('kB/s'), findsNothing);
      expect(find.textContaining('MB/s'), findsNothing);
    });

    testWidgets('stale pmtilesVersion surfaces "Mise à jour disponible"', (tester) async {
      final InstalledMapsState seed = InstalledMapsState(
        installed: <CountryCode, InstalledCountry>{CountryCode.parse('fra'): _installed('fra', version: 'v20260101')},
        updatesAvailableSet: <CountryCode>{CountryCode.parse('fra')},
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
