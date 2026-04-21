// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/presentation/widgets/map_country_banner.dart';

/// Fake resolver controller — emits a caller-provided [CountryResolverState]
/// and records no side effects. Used to drive the banner's render states.
class _FakeResolverController extends CountryResolverController {
  _FakeResolverController({required this.seed});
  final CountryResolverState seed;

  @override
  CountryResolverState build() => seed;
}

CountryCatalog _twoCountryCatalog() {
  final ChunkPart part = ChunkPart(sha256: 'a' * 64, size: 1000, url: 'https://example.com/releases/download/v1/fra.part01');
  return CountryCatalog(
    countries: <CountryEntry>[
      CountryEntry(
        alpha3: CountryCode.parse('fra'),
        name: 'France',
        parts: <ChunkPart>[part],
        reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1000),
      ),
      CountryEntry(
        alpha3: CountryCode.parse('deu'),
        name: 'Allemagne',
        parts: <ChunkPart>[part],
        reassembled: ReassembledMeta(sha256: 'c' * 64, size: 1000),
      ),
    ],
  );
}

void main() {
  group('MapCountryBanner', () {
    testWidgets('invisible when viewport IS installed', (tester) async {
      final CountryResolverState seed = CountryResolverState(
        activeCountry: CountryCode.parse('fra'),
        viewportCountry: CountryCode.parse('fra'),
        viewportInInstalled: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryResolverControllerProvider.overrideWith(() => _FakeResolverController(seed: seed)),
            countryCatalogProvider.overrideWith((ref) async => _twoCountryCatalog()),
          ],
          child: const MaterialApp(home: Scaffold(body: MapCountryBanner())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Carte détaillée'), findsNothing);
    });

    testWidgets('invisible when viewport country is null', (tester) async {
      const CountryResolverState seed = CountryResolverState();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryResolverControllerProvider.overrideWith(() => _FakeResolverController(seed: seed)),
            countryCatalogProvider.overrideWith((ref) async => _twoCountryCatalog()),
          ],
          child: const MaterialApp(home: Scaffold(body: MapCountryBanner())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Carte détaillée'), findsNothing);
    });

    testWidgets('visible with correct copy when viewport country is NOT installed', (tester) async {
      final CountryResolverState seed = CountryResolverState(viewportCountry: CountryCode.parse('deu'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryResolverControllerProvider.overrideWith(() => _FakeResolverController(seed: seed)),
            countryCatalogProvider.overrideWith((ref) async => _twoCountryCatalog()),
          ],
          child: const MaterialApp(home: Scaffold(body: MapCountryBanner())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Carte détaillée de Allemagne disponible dans Paramètres › Télécharger une carte'), findsOneWidget);
    });
  });
}
