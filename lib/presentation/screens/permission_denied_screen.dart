// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/permissions/location_permission_flow.dart';
import 'package:permission_handler/permission_handler.dart';

/// Signature of the handler that opens the system location settings —
/// overridable in tests to avoid platform channel activation.
typedef OpenLocationSettingsFn = Future<bool> Function();

/// Signature of the read-only location-permission status check used by
/// the resume-observer hook. Matches [checkLocationWhenInUseStatus] and
/// is overridable in tests to simulate the user flipping the permission
/// inside the system settings app while MirkFall was backgrounded.
typedef CheckLocationPermissionFn = Future<PermissionStatus> Function();

/// `/permissions/denied` — GPS-07 recovery screen shown when the user
/// declines the location prompt or has set it to "Don't ask again".
///
/// The "Ouvrir les paramètres" CTA calls [openLocationSettings] (from
/// `lib/application/permissions/location_permission_flow.dart`), which
/// wraps `permission_handler.openAppSettings()`. The return value is
/// not used to infer the outcome — the user could return without
/// changing anything.
///
/// Auto-detection on resume: the screen observes [WidgetsBindingObserver]
/// and, whenever the app returns to [AppLifecycleState.resumed], reads
/// `Permission.locationWhenInUse.status` (no dialog; status-only query).
/// A granted status triggers `context.pop(true)` so the parent rationale
/// flow can treat the side-trip to settings as a successful completion
/// of the permission flow, without forcing the user to tap "Retour"
/// themselves.
class PermissionDeniedScreen extends StatefulWidget {
  const PermissionDeniedScreen({super.key, this.openLocationSettingsFn, this.checkLocationPermissionFn});

  /// Test seam — defaults to the real [openLocationSettings].
  final OpenLocationSettingsFn? openLocationSettingsFn;

  /// Test seam — defaults to [checkLocationWhenInUseStatus].
  final CheckLocationPermissionFn? checkLocationPermissionFn;

  @override
  State<PermissionDeniedScreen> createState() => _PermissionDeniedScreenState();
}

class _PermissionDeniedScreenState extends State<PermissionDeniedScreen> with WidgetsBindingObserver {
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_recheckPermissionAndMaybePop());
  }

  Future<void> _recheckPermissionAndMaybePop() async {
    if (_popped) return;
    final CheckLocationPermissionFn fn = widget.checkLocationPermissionFn ?? checkLocationWhenInUseStatus;
    final PermissionStatus status = await fn();
    if (!mounted || _popped) return;
    if (!status.isGranted) return;
    _popped = true;
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/');
    }
  }

  /// Phase 06 Should #16 (Agent #3 #1) — pop back to whoever pushed this
  /// route rather than replacing the stack with `/`. Deep-link / cold-
  /// start origins (no parent) fall back to go('/') to avoid GoError.
  void _dismiss(BuildContext context) {
    _popped = true;
    if (context.canPop()) {
      context.pop(false);
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
                  final fn = widget.openLocationSettingsFn ?? openLocationSettings;
                  await fn();
                  // No mounted check needed — we don't touch the
                  // BuildContext after this await, user returns
                  // manually from the system settings page. The
                  // WidgetsBindingObserver hook above picks up the
                  // result on the next resume.
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

