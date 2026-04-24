// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirkfall/application/controllers/installed_maps_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';

import '../widgets/map_download_progress_chip.dart';

/// `/maps/manage` — list of installed per-country PMTiles with delete
/// actions + a non-deletable "Monde (intégré)" row pinning the world
/// basemap floor (MAP-07).
///
/// Two sections:
/// 1. World bundle row (always first, never deletable).
/// 2. Per-country rows sorted alphabetically by display name.
///
/// Delete triggers a confirmation dialog, then delegates to
/// [InstalledMapsController.deleteCountry]. The service raises
/// `CannotDeleteWorldBundleException` on the world sentinel, but the
/// widget keeps the world row non-tappable anyway — defense in depth.
class MapsManageScreen extends ConsumerWidget {
  const MapsManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InstalledMapsState state = ref.watch(installedMapsControllerProvider);
    final AsyncValue<CountryCatalog> catalogAsync = ref.watch(countryCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gérer les cartes installées'), actions: const <Widget>[MapDownloadProgressChip()]),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, st) => Center(
          child: Padding(padding: const EdgeInsets.all(24.0), child: Text('Erreur : $err')),
        ),
        data: (catalog) => _buildList(context, ref, catalog, state),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, CountryCatalog catalog, InstalledMapsState state) {
    // Sort installed entries by catalog display name (fall back to alpha3
    // when the catalog does not carry the alpha3 — degrades gracefully).
    final List<InstalledCountry> sorted = <InstalledCountry>[...state.installed.values];
    sorted.sort((a, b) {
      final String nameA = _nameFor(catalog, a.alpha3);
      final String nameB = _nameFor(catalog, b.alpha3);
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });

    return ListView(
      children: <Widget>[
        const _SectionHeader(label: 'Monde (intégré)'),
        const _WorldBundleRow(),
        if (sorted.isNotEmpty) const _SectionHeader(label: 'Pays installés'),
        for (final installed in sorted)
          _InstalledCountryTile(
            entry: installed,
            displayName: _nameFor(catalog, installed.alpha3),
            updatesAvailable: state.updatesAvailableSet.contains(installed.alpha3),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Espace total utilisé : ${_formatBytes(state.totalDiskUsageBytes)}', style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }

  String _nameFor(CountryCatalog catalog, CountryCode alpha3) {
    for (final CountryEntry entry in catalog.countries) {
      if (entry.alpha3 == alpha3) return entry.name;
    }
    return alpha3.value.toUpperCase();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _WorldBundleRow extends StatelessWidget {
  const _WorldBundleRow();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.public),
      title: Text('Monde (intégré)'),
      subtitle: Text('Carte de base livrée avec l\'application · non supprimable'),
      trailing: IconButton(icon: Icon(Icons.delete_outline), tooltip: 'Le monde ne peut pas être supprimé', onPressed: null),
    );
  }
}

class _InstalledCountryTile extends ConsumerWidget {
  const _InstalledCountryTile({required this.entry, required this.displayName, required this.updatesAvailable});

  final InstalledCountry entry;
  final String displayName;
  final bool updatesAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int mb = (entry.fileSize / (1024 * 1024)).round();
    return ListTile(
      leading: Icon(updatesAvailable ? Icons.update : Icons.map_outlined, color: updatesAvailable ? Colors.orange[700] : null),
      title: Text(displayName),
      subtitle: Text(updatesAvailable ? '$mb Mo · version ${entry.pmtilesVersion} · Mise à jour disponible' : '$mb Mo · version ${entry.pmtilesVersion}'),
      trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Supprimer', onPressed: () => _confirmAndDelete(context, ref)),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer la carte de $displayName ?'),
        content: const Text('La carte sera retirée du stockage. Tu pourras la re-télécharger plus tard.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(installedMapsControllerProvider.notifier).deleteCountry(entry.alpha3);
    } on Exception catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $err')));
    }
  }
}
