// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';

/// Non-intrusive banner that appears at the bottom of the MapScreen when
/// the viewport centre falls inside a country that is NOT currently
/// installed.
///
/// Copy: "Carte détaillée de `<Pays>` disponible dans Paramètres ›
/// Télécharger une carte" — verbatim from the user decision on PLAN
/// 07-06 `must_haves.truths`. No deep-link CTA: the user learns the path.
///
/// Country display name is resolved from [countryCatalogProvider] via the
/// alpha3 code surfaced by [CountryResolverController.state.viewportCountry].
class MapCountryBanner extends ConsumerWidget {
  const MapCountryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CountryResolverState resolverState = ref.watch(countryResolverControllerProvider);
    if (resolverState.viewportInInstalled) {
      return const SizedBox.shrink();
    }
    final CountryCode? viewportCountry = resolverState.viewportCountry;
    if (viewportCountry == null) {
      return const SizedBox.shrink();
    }

    // Watch the catalog so the banner re-renders when it resolves —
    // otherwise the first paint shows the alpha3 fallback while the
    // FutureProvider is still loading.
    final AsyncValue<CountryCatalog> catalogSnap = ref.watch(countryCatalogProvider);
    final String countryDisplayName = _resolveDisplayName(catalogSnap.value, viewportCountry);

    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer,
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Text(
          'Carte détaillée de $countryDisplayName disponible dans Paramètres › Télécharger une carte',
          style: TextStyle(color: cs.onTertiaryContainer),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _resolveDisplayName(CountryCatalog? catalog, CountryCode alpha3) {
    if (catalog == null) return alpha3.value.toUpperCase();
    for (final CountryEntry entry in catalog.countries) {
      if (entry.alpha3 == alpha3) return entry.name;
    }
    return alpha3.value.toUpperCase();
  }
}
