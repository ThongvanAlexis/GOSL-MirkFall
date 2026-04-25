// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';

/// Stateful overlay that hosts the mirk Ticker + CustomPainter.
///
/// Phase 09 Wave 0 scaffold. Plan 09-07 rewrites with
/// `SingleTickerProviderStateMixin` + `Ticker` driving
/// `MirkRenderer.update()` and a `CustomPainter` wrapping
/// `MirkRenderer.paint()`. Wave 0 returns an inert `SizedBox.shrink()` so
/// the widget tree compiles end-to-end.
class MirkOverlay extends StatefulWidget {
  const MirkOverlay({super.key});

  @override
  State<MirkOverlay> createState() => _MirkOverlayState();
}

class _MirkOverlayState extends State<MirkOverlay> {
  // TODO(09-07): SingleTickerProviderStateMixin + Ticker + CustomPainter.

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
