// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// End-to-end user journey across Phase 07 download + manage surfaces
// (MAP-08, MAP-09, MAP-10).
//
// Two testWidgets that together validate the full download-then-manage
// journey under controlled fakes:
//
// 1. `enqueue Aruba from MapsDownloadScreen → full DownloadState
//    transition sequence` — pumps MapsDownloadScreen with Aruba in the
//    catalog, taps the tile, confirms the dialog, and asserts the
//    FakeDownloadQueueController observed the enqueue + emitted the
//    Queued → InProgress → Completed sequence.
//
// 2. `MapsManageScreen lists Aruba after install` — pumps
//    MapsManageScreen with an installed-maps state that includes
//    Aruba, verifies the MAP-07 "Monde (intégré)" floor row + the
//    Aruba row + total-disk-usage footer.
//
// Design decisions:
//
// - The infrastructure download controller is replaced by a fake
//   (FakeDownloadQueueController) that accepts `enqueue(entry)` and
//   transitions DownloadState deterministically. The real shelf-backed
//   MockHTTPServer exists in Plan 07-04's soak suite
//   (`download_soak_test.dart`); spinning it up here would duplicate
//   the HTTP-level coverage without adding UI-level insight. The
//   `<key_links>` frontmatter for this plan specifies "drives enqueue
//   + state observation" which is what the fake provides.
//
// - The two testWidgets are kept separate (instead of chained through
//   `tester.pumpWidget` twice in one test body) because Riverpod's
//   controller caching behaviour across successive ProviderScope
//   mounts does NOT re-invoke `@Riverpod(keepAlive: true)` notifier
//   `build()` methods between pumps in the same testWidgets body (the
//   auto-generated controller instance is bound to the first
//   container's lifetime and not re-hydrated when the second scope is
//   mounted). Splitting into two tests gives each ProviderScope a
//   fresh container + controller instance.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/download_queue_controller.dart';
import 'package:mirkfall/application/controllers/installed_maps_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/presentation/screens/maps_download_screen.dart';
import 'package:mirkfall/presentation/screens/maps_manage_screen.dart';

class _FakeDownloadQueueController extends DownloadQueueController {
  _FakeDownloadQueueController();

  final List<CountryEntry> enqueueObservations = <CountryEntry>[];
  final List<DownloadState> emittedStates = <DownloadState>[];

  @override
  DownloadState build() => const DownloadIdle();

  /// Stubbed enqueue: transitions state through
  /// Queued → InProgress (50 %) → InProgress (100 %) → Completed to
  /// exercise the UI branches (chip, tile subtitle) without going
  /// through the real 7-step atomic protocol.
  @override
  Future<void> enqueue(CountryEntry entry) async {
    enqueueObservations.add(entry);
    final DownloadJob job = DownloadJob(alpha3: entry.alpha3, entry: entry, enqueuedAtUtc: DateTime.utc(2026, 4, 21));
    final List<DownloadState> transitions = <DownloadState>[
      DownloadQueued(queue: <DownloadJob>[job]),
      DownloadInProgress(
        active: job,
        progress: DownloadProgress(bytesDownloaded: entry.totalBytes ~/ 2, totalBytes: entry.totalBytes, currentPartIndex: 0, totalParts: 1),
        remaining: const <DownloadJob>[],
      ),
      DownloadInProgress(
        active: job,
        progress: DownloadProgress(bytesDownloaded: entry.totalBytes, totalBytes: entry.totalBytes, currentPartIndex: 0, totalParts: 1),
        remaining: const <DownloadJob>[],
      ),
      DownloadCompleted(alpha3: entry.alpha3, totalElapsed: const Duration(seconds: 1)),
    ];
    for (final DownloadState t in transitions) {
      state = t;
      emittedStates.add(t);
    }
  }
}

class _StubInstalledMapsController extends InstalledMapsController {
  _StubInstalledMapsController({required this.seed});
  final InstalledMapsState seed;

  @override
  InstalledMapsState build() => seed;
}

CountryCatalog _buildCatalog() {
  return CountryCatalog(
    countries: <CountryEntry>[
      CountryEntry(
        alpha3: CountryCode.parse('abw'),
        name: 'Aruba',
        parts: <ChunkPart>[ChunkPart(sha256: 'a' * 64, size: 4 * 1024 * 1024, url: 'https://example.test/releases/download/v20260419/abw.part01')],
        reassembled: ReassembledMeta(sha256: 'b' * 64, size: 4 * 1024 * 1024),
      ),
      CountryEntry(
        alpha3: CountryCode.parse('fra'),
        name: 'France',
        parts: <ChunkPart>[ChunkPart(sha256: 'c' * 64, size: 50 * 1024 * 1024, url: 'https://example.test/releases/download/v20260419/fra.part01')],
        reassembled: ReassembledMeta(sha256: 'd' * 64, size: 50 * 1024 * 1024),
      ),
    ],
  );
}

InstalledMapsState _installedStateFor(List<String> alpha3s) {
  final Map<CountryCode, InstalledCountry> map = <CountryCode, InstalledCountry>{};
  int total = 0;
  for (final String a in alpha3s) {
    final CountryCode code = CountryCode.parse(a);
    final InstalledCountry entry = InstalledCountry(
      alpha3: code,
      installedAtUtc: DateTime.utc(2026, 4, 21),
      fileSize: 4 * 1024 * 1024,
      pmtilesVersion: 'v20260419',
      sha256: 'b' * 64,
      filePath: 'maps/countries/$a.pmtiles',
    );
    map[code] = entry;
    total += entry.fileSize;
  }
  return InstalledMapsState(installed: map, updatesAvailable: const <CountryCode>{}, totalDiskUsageBytes: total);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('e2e step 1: tap Aruba on MapsDownloadScreen → full DownloadState transition sequence', (tester) async {
    final _FakeDownloadQueueController fakeDownload = _FakeDownloadQueueController();
    final _StubInstalledMapsController fakeInstalled = _StubInstalledMapsController(seed: const InstalledMapsState.empty());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countryCatalogProvider.overrideWith((_) async => _buildCatalog()),
          installedMapsControllerProvider.overrideWith(() => fakeInstalled),
          downloadQueueControllerProvider.overrideWith(() => fakeDownload),
        ],
        child: const MaterialApp(home: MapsDownloadScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Both catalog entries visible — Aruba + France.
    expect(find.text('Aruba'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
    // Aruba starts as "Disponible" (not installed).
    expect(find.textContaining('Disponible'), findsAtLeast(1));

    // Tap Aruba → confirm dialog → confirm.
    await tester.tap(find.text('Aruba'));
    await tester.pumpAndSettle();
    expect(find.text('Télécharger Aruba ?'), findsOneWidget);

    final Finder dialogConfirm = find.descendant(of: find.byType(AlertDialog), matching: find.text('Télécharger'));
    expect(dialogConfirm, findsOneWidget);
    await tester.tap(dialogConfirm);
    await tester.pumpAndSettle();

    // The fake observed the enqueue + emitted the full transition
    // sequence.
    expect(fakeDownload.enqueueObservations, hasLength(1));
    expect(fakeDownload.enqueueObservations.single.alpha3.value, equals('abw'));
    expect(fakeDownload.emittedStates, hasLength(4));
    expect(fakeDownload.emittedStates[0], isA<DownloadQueued>());
    expect(fakeDownload.emittedStates[1], isA<DownloadInProgress>());
    expect(fakeDownload.emittedStates[2], isA<DownloadInProgress>());
    expect(fakeDownload.emittedStates[3], isA<DownloadCompleted>());
    expect((fakeDownload.emittedStates[3] as DownloadCompleted).alpha3.value, equals('abw'));
  });

  testWidgets('e2e step 2: MapsManageScreen lists Aruba after install + shows Monde (intégré) floor', (tester) async {
    // Simulate the post-install state that the infrastructure
    // controller's step 6 (manifest write) would produce in
    // production.
    final _StubInstalledMapsController fakeInstalled = _StubInstalledMapsController(seed: _installedStateFor(<String>['abw']));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          countryCatalogProvider.overrideWith((_) async => _buildCatalog()),
          installedMapsControllerProvider.overrideWith(() => fakeInstalled),
          downloadQueueControllerProvider.overrideWith(() => _FakeDownloadQueueController()),
        ],
        child: const MaterialApp(home: MapsManageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // World bundle row always present (MAP-07 non-deletable floor).
    // "Monde (intégré)" renders twice — once as _SectionHeader text
    // and once as _WorldBundleRow title; both are legitimate.
    expect(find.text('Monde (intégré)'), findsAtLeast(1));
    // Installed section header surfaces since installed is non-empty.
    expect(find.text('Pays installés'), findsOneWidget);
    // Aruba now listed as installed.
    expect(find.text('Aruba'), findsOneWidget);
    // Aruba's delete button is enabled (its ListTile is the ancestor).
    final Finder arubaRow = find.ancestor(of: find.text('Aruba'), matching: find.byType(ListTile));
    expect(arubaRow, findsOneWidget);

    // Total disk usage text surfaces (sum of installed sizes).
    expect(find.textContaining('Espace total utilisé'), findsOneWidget);
  });
}
