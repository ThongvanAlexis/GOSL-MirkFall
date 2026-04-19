// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/permissions/location_permission_flow.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/domain/errors/location_permission_errors.dart';

/// Signature of the function used to kick off the two-step Android 10+
/// permission chain. Tests inject a fake instead of the
/// `permission_handler`-backed [requestLocationAlways] default so the
/// flow can be exercised without platform channels.
typedef RequestLocationAlwaysFn = Future<LocationPermissionOutcome> Function();

/// `/permissions/rationale` — GPS-01 pre-prompt full-screen rationale.
///
/// Body copy comes VERBATIM from 05-CONTEXT.md §Permission flow
/// rationale — do not rewrite without a user decision (validates
/// verbatim in a widget test assertion).
///
/// The "Continuer" button invokes [requestLocationAlways] and routes
/// based on the [LocationPermissionOutcome]:
///
/// | Outcome               | Navigation                                                                          |
/// | --------------------- | ----------------------------------------------------------------------------------- |
/// | `granted`             | Mark flow completed, pop with `true`; if OEM match + guidance unseen, push /oem     |
/// | `whileInUseOnly`      | Mark flow completed, pop with `true` (caller decides whether to warn)               |
/// | `denied`              | Push `/permissions/denied`                                                          |
/// | `permanentlyDenied`   | Push `/permissions/denied` (deep-link CTA lives there)                              |
///
/// "Pas maintenant" pops the route with `false` — the caller interprets
/// that as "user declined to proceed, do not start the session".
class PermissionRationaleScreen extends ConsumerStatefulWidget {
  const PermissionRationaleScreen({super.key, this.requestLocationAlwaysFn});

  /// Test seam. Default = the real [requestLocationAlways] function.
  final RequestLocationAlwaysFn? requestLocationAlwaysFn;

  @override
  ConsumerState<PermissionRationaleScreen> createState() => _PermissionRationaleScreenState();
}

class _PermissionRationaleScreenState extends ConsumerState<PermissionRationaleScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              Icon(Icons.explore_outlined, size: 96.0, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24.0),
              Text('Pour suivre ton exploration', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 16.0),
              Text(
                // CONTEXT.md §Permission flow rationale — VERBATIM.
                // Any edit must go through a user decision + widget
                // test assertion update.
                "MirkFall a besoin de ta localisation en arrière-plan pour continuer à révéler le brouillard pendant que ton téléphone est dans ta poche, écran éteint. Tes positions restent sur ton téléphone. Aucun serveur, aucune publicité, aucune analytique.",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(onPressed: _busy ? null : _onContinue, child: const Text('Continuer')),
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        context.pop(false);
                      },
                child: const Text('Pas maintenant'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onContinue() async {
    setState(() => _busy = true);
    final RequestLocationAlwaysFn fn = widget.requestLocationAlwaysFn ?? requestLocationAlways;
    final LocationPermissionOutcome outcome = await fn();
    if (!mounted) return;

    switch (outcome) {
      case LocationPermissionOutcome.granted:
      case LocationPermissionOutcome.whileInUseOnly:
        await ref.read(sessionSettingsProvider.notifier).markPermissionFlowCompleted();
        if (!mounted) return;
        final settings = await ref.read(sessionSettingsProvider.future);
        if (!mounted) return;
        if (outcome == LocationPermissionOutcome.granted && !settings.oemGuidanceSeen) {
          // Route to the OEM screen and wait for its OK pop. The screen
          // itself decides (based on detected family) whether to render
          // anything non-trivial.
          await context.push<void>('/permissions/oem');
          if (!mounted) return;
        }
        context.pop(true);
      case LocationPermissionOutcome.denied:
      case LocationPermissionOutcome.permanentlyDenied:
        context.go('/permissions/denied');
    }
  }
}
