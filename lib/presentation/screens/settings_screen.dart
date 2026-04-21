// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';

import '../widgets/map_download_progress_chip.dart';

/// `/settings` — minimal Phase 05 settings screen.
///
/// Exposes:
/// 1. A slider controlling `distanceFilter_meters` — persists to
///    `SharedPreferences` via
///    [`sessionSettingsProvider`](../../application/providers/session_settings_provider.dart).
///    Drag is intentionally throttled: only `onChangeEnd` persists so
///    the drag itself does not spam
///    `SharedPreferences.setInt` (one write per release).
/// 2. A tile that navigates to `/permissions/oem` so the OEM
///    battery-killer guidance remains reachable post-first-run
///    (CONTEXT.md §OEM guidance).
///
/// Phase 13 will extend this screen (theme, export/import, etc.). Kept
/// intentionally minimal here.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double? _localValue;

  @override
  void initState() {
    super.initState();
    // Phase 06 Should #21 (Agent #3 #6) — seed _localValue from the
    // current snapshot so the build() body stays free of init-on-first-
    // build side-effects (CLAUDE.md §Widgets — no logique in build()).
    // The provider is keepAlive:true and already hydrated by the time
    // the settings route is opened, so read() is safe synchronously.
    final asyncSettings = ref.read(sessionSettingsProvider);
    final snapshot = asyncSettings.value;
    if (snapshot != null) {
      _localValue = snapshot.distanceFilterMeters.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(sessionSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: const <Widget>[MapDownloadProgressChip()],
      ),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, st) => Center(child: Text('Erreur : $err')),
        data: (settings) {
          // Local drag-state stays in [_localValue] during a pan so the
          // slider does not jitter on every SharedPreferences write.
          // initState() seeded this from the snapshot; if the snapshot
          // was still loading at initState (rare — provider not prewarmed),
          // fall back to the now-resolved settings value.
          final double value = (_localValue ?? settings.distanceFilterMeters.toDouble()).clamp(
            kMinDistanceFilterMeters.toDouble(),
            kMaxDistanceFilterMeters.toDouble(),
          );

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Filtre de distance', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4.0),
                      Text('${value.round()} m', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4.0),
                      Text('Plus dense = trace plus précise, consommation batterie plus élevée.', style: Theme.of(context).textTheme.bodySmall),
                      Slider(
                        value: value,
                        min: kMinDistanceFilterMeters.toDouble(),
                        max: kMaxDistanceFilterMeters.toDouble(),
                        divisions: kMaxDistanceFilterMeters - kMinDistanceFilterMeters,
                        label: '${value.round()} m',
                        onChanged: (v) {
                          setState(() => _localValue = v);
                        },
                        onChangeEnd: (v) async {
                          final int snapped = v.round();
                          setState(() => _localValue = snapped.toDouble());
                          await ref.read(sessionSettingsProvider.notifier).setDistanceFilterMeters(snapped);
                          // No `mounted` check needed after await — we
                          // don't touch BuildContext / setState in the
                          // success path. Errors surface via provider
                          // state and will re-render through the
                          // AsyncValue.when above.
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.battery_saver_outlined),
                  title: const Text('Aide : batterie & arrière-plan'),
                  subtitle: const Text("Guide pour éviter que ton OEM ne tue MirkFall en arrière-plan."),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/permissions/oem'),
                ),
              ),
              const SizedBox(height: 16.0),
              // Phase 07 — Cartes section.
              const _SectionHeader(label: 'Cartes'),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Télécharger une carte'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/maps/download'),
                    ),
                    const Divider(height: 1.0),
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('Gérer les cartes installées'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/maps/manage'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              // Phase 07 — Styles section (Phase 13 placeholders).
              const _SectionHeader(label: 'Styles'),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.file_upload_outlined),
                      title: const Text('Importer un style de mirk'),
                      subtitle: const Text('En construction (Phase 13)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/styles/import'),
                    ),
                    const Divider(height: 1.0),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('Exporter un style de mirk'),
                      subtitle: const Text('En construction (Phase 13)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/styles/export'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Debug menu'),
                  subtitle: const Text('Logs, verbose toggle, partage de fichiers'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/debug'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small section header reused across the settings screen sections.
/// Hoisted as a private widget so each Card keeps a predictable shape.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4.0, 0.0, 0.0, 8.0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
