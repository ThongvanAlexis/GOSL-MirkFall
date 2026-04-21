// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/download_queue_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/presentation/widgets/map_download_progress_chip.dart';

/// Fake download-queue controller that holds a caller-provided state.
class _FakeDownloadQueueController extends DownloadQueueController {
  _FakeDownloadQueueController({required this.seed});
  final DownloadState seed;

  @override
  DownloadState build() => seed;
}

CountryCatalog _catalogWith(String alpha3, String name) {
  final ChunkPart part = ChunkPart(
    sha256: 'a' * 64,
    size: 1000,
    url: 'https://example.com/releases/download/v1/$alpha3.part01',
  );
  return CountryCatalog(countries: <CountryEntry>[
    CountryEntry(
      alpha3: CountryCode.parse(alpha3),
      name: name,
      parts: <ChunkPart>[part],
      reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1000),
    ),
  ]);
}

DownloadJob _jobFor(String alpha3) => DownloadJob(
  alpha3: CountryCode.parse(alpha3),
  entry: _catalogWith(alpha3, alpha3.toUpperCase()).countries.first,
  enqueuedAtUtc: DateTime.utc(2026, 4, 21),
);

void main() {
  testWidgets('invisible when queue is idle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadQueueControllerProvider.overrideWith(
            () => _FakeDownloadQueueController(seed: const DownloadIdle()),
          ),
          countryCatalogProvider.overrideWith((ref) async => _catalogWith('fra', 'France')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapDownloadProgressChip()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Nothing to show — SizedBox.shrink.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('visible with percent + country name when InProgress at 50%', (tester) async {
    final DownloadState seed = DownloadInProgress(
      active: _jobFor('fra'),
      progress: DownloadProgress(bytesDownloaded: 500, totalBytes: 1000, currentPartIndex: 0, totalParts: 1),
      remaining: const <DownloadJob>[],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadQueueControllerProvider.overrideWith(() => _FakeDownloadQueueController(seed: seed)),
          countryCatalogProvider.overrideWith((ref) async => _catalogWith('fra', 'France')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapDownloadProgressChip()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('France 50 %'), findsOneWidget);
  });

  testWidgets('reads paused snapshot fraction when state is DownloadPaused', (tester) async {
    final DownloadState seed = DownloadPaused(
      active: _jobFor('fra'),
      snapshot: DownloadProgress(bytesDownloaded: 250, totalBytes: 1000, currentPartIndex: 0, totalParts: 1),
      reason: PauseReason.manual,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadQueueControllerProvider.overrideWith(() => _FakeDownloadQueueController(seed: seed)),
          countryCatalogProvider.overrideWith((ref) async => _catalogWith('fra', 'France')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapDownloadProgressChip()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('France 25 %'), findsOneWidget);
  });
}
