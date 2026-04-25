// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';

/// Fades the initial 20 m reveal from opacity 0 to 1 over
/// `kInitialRevealFadeInMs` (500 ms) at session start.
///
/// Uses a dedicated `AnimationController`, decoupled from the main mirk
/// Ticker — the fade is a one-shot session-open animation, not part of
/// the noise tick frequency. Plan 09-07 Task 4 implements the body.
///
/// TODO(09-07): SingleTickerProviderStateMixin + AnimationController +
/// trigger on ActiveSessionController.startSession() resolving (or first
/// fix arriving if no lastKnownFix).
class MirkInitialRevealFade extends StatefulWidget {
  const MirkInitialRevealFade({super.key, required this.child});
  final Widget child;

  @override
  State<MirkInitialRevealFade> createState() => _MirkInitialRevealFadeState();
}

class _MirkInitialRevealFadeState extends State<MirkInitialRevealFade> {
  @override
  Widget build(BuildContext context) => widget.child;
}
