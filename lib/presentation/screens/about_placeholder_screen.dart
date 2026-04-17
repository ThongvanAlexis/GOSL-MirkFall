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

  void _onTap() {
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds > kAboutTapWindowMilliseconds) {
      // Window elapsed since last tap: reset counter.
      _tapCount = 0;
    }
    _tapCount++;
    _lastTap = now;
    if (_tapCount >= kAboutTapsToTriggerDebugMenu) {
      _tapCount = 0;
      context.go('/debug');
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
