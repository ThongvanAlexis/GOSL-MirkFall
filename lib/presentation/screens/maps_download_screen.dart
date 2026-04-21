// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/download_queue_controller.dart';
import 'package:mirkfall/application/controllers/installed_maps_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';

import '../widgets/map_download_progress_chip.dart';

/// `/maps/download` — catalog browse + enqueue screen.
///
/// Lists every catalog entry (alpha3 name sort) with a per-row status
/// indicator:
/// - Installed + catalog-version match → "Installé" + green check
/// - Installed + stale version → "Mise à jour disponible" + orange dot
/// - Downloading → "En téléchargement XX %" + spinner
/// - Else → "Disponible" + download icon
///
/// Tap on a "Disponible" row opens a confirmation dialog. Confirm →
/// [DownloadQueueController.enqueue]. The in-flight download surfaces
/// in the AppBar via [MapDownloadProgressChip].
class MapsDownloadScreen extends ConsumerWidget {
  const MapsDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CountryCatalog> catalogAsync = ref.watch(countryCatalogProvider);
    final InstalledMapsState installedState = ref.watch(installedMapsControllerProvider);
    final DownloadState downloadState = ref.watch(downloadQueueControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Télécharger une carte'), actions: const <Widget>[MapDownloadProgressChip()]),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, st) => Center(
          child: Padding(padding: const EdgeInsets.all(24.0), child: Text('Erreur : $err')),
        ),
        data: (catalog) => _buildList(context, ref, catalog, installedState, downloadState),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, CountryCatalog catalog, InstalledMapsState installedState, DownloadState downloadState) {
    // Alphabetic sort over a fresh list — never mutate the catalog's own
    // `countries` list.
    final List<CountryEntry> sorted = <CountryEntry>[...catalog.countries]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final CountryCode? activeDownloadAlpha3 = _activeDownloadAlpha3(downloadState);
    final double? activeFraction = _activeFraction(downloadState);

    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1.0),
      itemBuilder: (context, index) {
        final CountryEntry entry = sorted[index];
        return _CountryTile(
          entry: entry,
          installedState: installedState,
          catalogVersion: _safeCatalogVersion(catalog),
          activeDownloadAlpha3: activeDownloadAlpha3,
          activeFraction: activeFraction,
        );
      },
    );
  }

  CountryCode? _activeDownloadAlpha3(DownloadState state) {
    return switch (state) {
      DownloadInProgress(:final active) => active.alpha3,
      DownloadPaused(:final active) => active.alpha3,
      _ => null,
    };
  }

  double? _activeFraction(DownloadState state) {
    return switch (state) {
      DownloadInProgress(:final progress) => progress.fractionDone,
      DownloadPaused(:final snapshot) => snapshot.fractionDone,
      _ => null,
    };
  }

  /// Returns the catalog version, or `''` when derivation throws (empty
  /// countries list — never expected in production, but keeps the widget
  /// resilient under misconfigured assets).
  String _safeCatalogVersion(CountryCatalog catalog) {
    try {
      return catalog.catalogVersion;
    } on FormatException {
      return '';
    }
  }
}

class _CountryTile extends ConsumerWidget {
  const _CountryTile({
    required this.entry,
    required this.installedState,
    required this.catalogVersion,
    required this.activeDownloadAlpha3,
    required this.activeFraction,
  });

  final CountryEntry entry;
  final InstalledMapsState installedState;
  final String catalogVersion;
  final CountryCode? activeDownloadAlpha3;
  final double? activeFraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InstalledCountry? installed = installedState.installed[entry.alpha3];
    final bool isDownloading = activeDownloadAlpha3 == entry.alpha3;
    final int totalMb = (entry.totalBytes / (1024 * 1024)).round();

    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget trailing;
    final String subtitle;
    final VoidCallback? onTap;
    final IconData leading;
    final Color leadingColor;

    if (isDownloading) {
      final int percent = ((activeFraction ?? 0.0) * 100).clamp(0, 100).round();
      trailing = SizedBox(width: 72.0, child: Text('$percent %', textAlign: TextAlign.end));
      subtitle = 'En téléchargement $percent %';
      onTap = null;
      leading = Icons.downloading_outlined;
      leadingColor = cs.primary;
    } else if (installed != null) {
      final bool needsUpdate = catalogVersion.isNotEmpty && installed.pmtilesVersion != catalogVersion;
      if (needsUpdate) {
        trailing = Icon(Icons.update, color: Colors.orange[700]);
        subtitle = 'Mise à jour disponible';
        onTap = () => _confirmAndEnqueue(context, ref);
        leading = Icons.check_circle_outline;
        leadingColor = Colors.orange[700]!;
      } else {
        trailing = const Icon(Icons.check, color: Colors.green);
        subtitle = 'Installé · $totalMb Mo';
        onTap = null;
        leading = Icons.check_circle;
        leadingColor = Colors.green;
      }
    } else {
      trailing = const Icon(Icons.download_outlined);
      subtitle = 'Disponible · $totalMb Mo';
      onTap = () => _confirmAndEnqueue(context, ref);
      leading = Icons.public_outlined;
      leadingColor = cs.onSurfaceVariant;
    }

    return ListTile(
      leading: Icon(leading, color: leadingColor),
      title: Text(entry.name),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Future<void> _confirmAndEnqueue(BuildContext context, WidgetRef ref) async {
    final int totalMb = (entry.totalBytes / (1024 * 1024)).round();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Télécharger ${entry.name} ?'),
        content: Text('Taille approximative : $totalMb Mo. La carte sera disponible hors-ligne une fois téléchargée.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Télécharger')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    await ref.read(downloadQueueControllerProvider.notifier).enqueue(entry);
  }
}
