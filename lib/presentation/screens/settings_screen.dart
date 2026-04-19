// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';

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
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(sessionSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, st) => Center(child: Text('Erreur : $err')),
        data: (settings) {
          // Local drag-state stays in [_localValue] during a pan so the
          // slider does not jitter on every SharedPreferences write.
          // Initialize on first build from the persisted snapshot.
          _localValue ??= settings.distanceFilterMeters.toDouble();
          final double value = _localValue ?? settings.distanceFilterMeters.toDouble();

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
                      Text(
                        'Plus dense = trace plus précise, consommation batterie plus élevée.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Slider(
                        value: value.clamp(kMinDistanceFilterMeters.toDouble(), kMaxDistanceFilterMeters.toDouble()),
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
            ],
          );
        },
      ),
    );
  }
}
