// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';

/// Placeholder "À propos" screen for Phase 01.
///
/// The real About screen ships in Phase 15 (ABOUT-01..05). This stub carries
/// the 7-tap easter egg that unlocks `/debug` — the pattern must already be
/// wired in Phase 01 because Phase 15's OPT-07 and Phase 05's release builds
/// rely on it as the only path to the debug menu when `--dart-define=DEBUG`
/// is not set.
class AboutPlaceholderScreen extends StatefulWidget {
  const AboutPlaceholderScreen({super.key});

  @override
  State<AboutPlaceholderScreen> createState() => _AboutPlaceholderScreenState();
}

class _AboutPlaceholderScreenState extends State<AboutPlaceholderScreen> {
  int _tapCount = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _firstTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();
    // Reset on either inter-tap window lapse OR total-window lapse since the
    // first tap. Inter-tap-only (Phase 01 behaviour) allowed 7 taps spaced
    // ~2.9s apart — ~21 s total — to still trigger the easter egg, which is
    // too lax for casual-interaction scenarios.
    final bool interTapStale = now.difference(_lastTap).inMilliseconds > kAboutTapWindowMilliseconds;
    final bool totalWindowStale = now.difference(_firstTap).inMilliseconds > kAboutTapTotalWindowMilliseconds;
    if (_tapCount == 0 || interTapStale || totalWindowStale) {
      _tapCount = 0;
      _firstTap = now;
    }
    _tapCount++;
    _lastTap = now;
    if (_tapCount >= kAboutTapsToTriggerDebugMenu) {
      _tapCount = 0;
      context.push('/debug');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(kScreenBodyPaddingLogicalPx),
            child: Text(
              'MirkFall\n\nPlaceholder À propos. '
              "Phase 15 livrera l'écran complet.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
