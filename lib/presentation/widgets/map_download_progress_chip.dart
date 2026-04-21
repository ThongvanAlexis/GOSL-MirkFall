// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/download_queue_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';

/// Small chip displayed in the AppBar trailing area of settings /
/// maps-download / session-list screens when a download is in flight.
///
/// Surfaces `<Pays> XX %` with a horizontal linear progress indicator.
/// Returns [SizedBox.shrink] when [DownloadQueueController.aggregateProgressFraction]
/// is `null` (idle, completed, cancelled).
class MapDownloadProgressChip extends ConsumerWidget {
  const MapDownloadProgressChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DownloadState state = ref.watch(downloadQueueControllerProvider);
    final double? fraction = ref.watch(downloadQueueControllerProvider.notifier).aggregateProgressFraction;
    if (fraction == null) return const SizedBox.shrink();

    final CountryCode? alpha3 = _alpha3From(state);
    final String countryName = alpha3 == null ? '…' : _countryDisplayName(ref, alpha3);
    final int percent = (fraction * 100).clamp(0, 100).round();

    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            '$countryName $percent %',
            style: TextStyle(color: cs.onSurface, fontSize: 12.0, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2.0),
          SizedBox(
            width: 100.0,
            child: LinearProgressIndicator(value: fraction),
          ),
        ],
      ),
    );
  }

  CountryCode? _alpha3From(DownloadState state) {
    return switch (state) {
      DownloadInProgress(:final active) => active.alpha3,
      DownloadPaused(:final active) => active.alpha3,
      _ => null,
    };
  }

  String _countryDisplayName(WidgetRef ref, CountryCode alpha3) {
    final AsyncValue<CountryCatalog> catalogSnap = ref.read(countryCatalogProvider);
    final CountryCatalog? catalog = catalogSnap.value;
    if (catalog == null) return alpha3.value.toUpperCase();
    for (final CountryEntry entry in catalog.countries) {
      if (entry.alpha3 == alpha3) return entry.name;
    }
    return alpha3.value.toUpperCase();
  }
}
