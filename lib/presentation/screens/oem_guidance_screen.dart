// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/providers/oem_detector_provider.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/platform/oem_detector.dart';
import 'package:share_plus/share_plus.dart';

/// Signature of the function invoked when the user taps the
/// "dontkillmyapp.com" link — test seam so we can assert wiring without
/// pumping `SharePlus.instance`. Returns void because we don't care
/// about the OS share-sheet outcome.
typedef ShareLinkFn = Future<void> Function(String url);

/// `/permissions/oem` — GPS-08 OEM battery-killer guidance screen.
///
/// Pattern-matches over the sealed
/// [`OemFamily`](../../infrastructure/platform/oem_detector.dart) to
/// render vendor-specific 2-step guidance plus a link to
/// `dontkillmyapp.com/[vendor]`. Link dispatch reuses `share_plus`
/// (already audited & pinned in Phase 01 DEPENDENCIES.md) so we avoid
/// adding `url_launcher` for a single link — 05-RESEARCH §Open
/// Question #4.
///
/// Copy is intentionally concise (2 steps max per vendor) — the long
/// guidance lives at dontkillmyapp.com.
class OemGuidanceScreen extends ConsumerStatefulWidget {
  const OemGuidanceScreen({super.key, this.shareLinkFn, this.familyOverride});

  /// Test seam — defaults to `SharePlus.instance.share(...)`.
  final ShareLinkFn? shareLinkFn;

  /// Test seam — when provided, skip the `oemDetectorProvider` lookup
  /// and use this family directly. Keeps the widget pure for unit
  /// tests that seed a specific vendor.
  final OemFamily? familyOverride;

  @override
  ConsumerState<OemGuidanceScreen> createState() => _OemGuidanceScreenState();
}

class _OemGuidanceScreenState extends ConsumerState<OemGuidanceScreen> {
  late final Future<OemFamily> _familyFuture;

  @override
  void initState() {
    super.initState();
    final override = widget.familyOverride;
    if (override != null) {
      _familyFuture = Future<OemFamily>.value(override);
    } else {
      _familyFuture = ref.read(oemDetectorProvider).detect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batterie & arrière-plan')),
      body: SafeArea(
        child: FutureBuilder<OemFamily>(
          future: _familyFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            final OemFamily family = snapshot.data!;
            return _OemBody(family: family, onShare: _onShare, onDone: _onDone);
          },
        ),
      ),
    );
  }

  Future<void> _onShare(String url) async {
    final fn = widget.shareLinkFn ?? _defaultShare;
    await fn(url);
  }

  Future<void> _defaultShare(String url) async {
    try {
      await SharePlus.instance.share(ShareParams(text: url)).timeout(const Duration(milliseconds: kShareCallTimeoutMilliseconds));
    } on TimeoutException {
      // Share sheet hung — silently swallow; the user can still copy
      // the URL from the body if needed. CLAUDE.md §Error handling:
      // non-critical periphery error, log only (no UI feedback here
      // because the share plugin might have already shown the sheet).
    }
  }

  Future<void> _onDone() async {
    await ref.read(sessionSettingsProvider.notifier).markOemGuidanceSeen();
    if (!mounted) return;
    // Prefer `pop()` when we have a previous route — the screen was
    // pushed from rationale or from settings' help tile. Fall back to
    // `/` when there is nothing to pop (deep-link / test harness
    // entry).
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
  }
}

/// Inner body widget — accepts the [OemFamily] once it has been
/// resolved and pattern-matches to render per-vendor content. Hoisted
/// out of `_OemGuidanceScreenState` so the pattern-match is exhaustive
/// at the top level (compile-time check across all 7 variants).
class _OemBody extends StatelessWidget {
  const _OemBody({required this.family, required this.onShare, required this.onDone});

  final OemFamily family;
  final Future<void> Function(String url) onShare;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final _OemCopy copy = _copyFor(family);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(copy.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12.0),
          Text(copy.intro, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16.0),
          for (int i = 0; i < copy.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${i + 1}. ', style: Theme.of(context).textTheme.bodyMedium),
                  Expanded(child: Text(copy.steps[i], style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
          if (copy.learnMoreUrl != null) ...<Widget>[
            const SizedBox(height: 16.0),
            TextButton.icon(
              onPressed: () => onShare(copy.learnMoreUrl!),
              icon: const Icon(Icons.open_in_new),
              label: Text("Plus d'info : ${copy.learnMoreUrl!}"),
            ),
          ],
          const Spacer(),
          FilledButton(onPressed: onDone, child: const Text("OK j'ai fait")),
        ],
      ),
    );
  }

  _OemCopy _copyFor(OemFamily family) => switch (family) {
    XiaomiFamily() => const _OemCopy(
      title: 'Xiaomi / Redmi / POCO',
      intro: 'MIUI peut tuer MirkFall en arrière-plan. Deux étapes pour éviter ça :',
      steps: <String>[
        "Ouvre Paramètres > Batterie > Économiseur de batterie d'application > MirkFall > Pas de restrictions.",
        "Ouvre Paramètres > Apps > Gestion des permissions > Autostart > active MirkFall.",
      ],
      learnMoreUrl: 'https://dontkillmyapp.com/xiaomi',
    ),
    SamsungFamily() => const _OemCopy(
      title: 'Samsung',
      intro: 'Samsung Device Care peut mettre MirkFall en veille. Deux étapes :',
      steps: <String>[
        'Paramètres > Batterie et entretien de la batterie > Utilisation de la batterie > MirkFall > Autoriser en arrière-plan.',
        "Paramètres > Apps > MirkFall > Batterie > passe sur Illimité.",
      ],
      learnMoreUrl: 'https://dontkillmyapp.com/samsung',
    ),
    HuaweiFamily() => const _OemCopy(
      title: 'Huawei / Honor',
      intro: 'EMUI / Magic UI killent agressivement. Deux étapes :',
      steps: <String>[
        "Paramètres > Batterie > Démarrage d'application > MirkFall > gérer manuellement, active Démarrage auto + Démarrage secondaire + Fonctionnement en arrière-plan.",
        "Paramètres > Batterie > Plus de paramètres de batterie > désactive Fermer les applis très gourmandes.",
      ],
      learnMoreUrl: 'https://dontkillmyapp.com/huawei',
    ),
    OnePlusFamily() => const _OemCopy(
      title: 'OnePlus',
      intro: "OxygenOS a un 'App startup manager' qui tue le background. Deux étapes :",
      steps: <String>[
        "Paramètres > Batterie > Optimisation de batterie > MirkFall > Ne pas optimiser.",
        "Paramètres > Apps > MirkFall > Consommation de la batterie > Autorise l'activité en arrière-plan.",
      ],
      learnMoreUrl: 'https://dontkillmyapp.com/oneplus',
    ),
    OppoFamily() => const _OemCopy(
      title: 'OPPO / Realme',
      intro: 'ColorOS peut couper les apps en arrière-plan sans prévenir. Deux étapes :',
      steps: <String>[
        "Paramètres > Batterie > Optimisation de la batterie d'application > MirkFall > Autoriser.",
        "Paramètres > Apps > MirkFall > Utilisation de la batterie > Autoriser l'arrière-plan.",
      ],
      learnMoreUrl: 'https://dontkillmyapp.com/oppo',
    ),
    OtherOem() => const _OemCopy(title: 'Android', intro: "Ton device n'est pas un battery-killer connu ; aucune étape spécifique requise.", steps: <String>[]),
    IosDevice() => const _OemCopy(title: 'iOS', intro: "iOS gère automatiquement l'arrière-plan ; aucune étape requise sur iPhone ou iPad.", steps: <String>[]),
  };
}

/// Immutable content-container for per-vendor copy.
class _OemCopy {
  const _OemCopy({required this.title, required this.intro, required this.steps, this.learnMoreUrl});

  final String title;
  final String intro;
  final List<String> steps;
  final String? learnMoreUrl;
}
