// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/permissions/location_permission_flow.dart';

/// Signature of the handler that opens the system location settings —
/// overridable in tests to avoid platform channel activation.
typedef OpenLocationSettingsFn = Future<bool> Function();

/// `/permissions/denied` — GPS-07 recovery screen shown when the user
/// declines the location prompt or has set it to "Don't ask again".
///
/// The "Ouvrir les paramètres" CTA calls [openLocationSettings] (from
/// `lib/application/permissions/location_permission_flow.dart`), which
/// wraps `permission_handler.openAppSettings()`. Return value is not
/// used to infer the outcome — the user could return without changing
/// anything. Re-check on app resume (Plan 05-04 `WidgetsBindingObserver`
/// — deferred; not blocking this plan).
class PermissionDeniedScreen extends StatelessWidget {
  const PermissionDeniedScreen({super.key, this.openLocationSettingsFn});

  /// Test seam — defaults to the real [openLocationSettings].
  final OpenLocationSettingsFn? openLocationSettingsFn;

  /// Phase 06 Should #16 (Agent #3 #1) — pop back to whoever pushed this
  /// route rather than replacing the stack with `/`. Deep-link / cold-
  /// start origins (no parent) fall back to go('/') to avoid GoError.
  void _dismiss(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission refusée'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _dismiss(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              Icon(Icons.location_off_outlined, size: 96.0, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 24.0),
              Text('Localisation refusée', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 16.0),
              Text(
                "MirkFall a besoin de ta localisation pour révéler le brouillard. Tu l'as refusée — tu peux l'accorder dans les paramètres système.",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final fn = openLocationSettingsFn ?? openLocationSettings;
                  await fn();
                  // No mounted check needed — we don't touch the
                  // BuildContext after this await, user returns
                  // manually from the system settings page.
                },
                child: const Text('Ouvrir les paramètres'),
              ),
              const SizedBox(height: 8.0),
              TextButton(onPressed: () => _dismiss(context), child: const Text('Retour')),
            ],
          ),
        ),
      ),
    );
  }
}
