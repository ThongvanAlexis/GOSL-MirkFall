// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';

/// Bottom-sheet picker that lists the 4 builtin mirk styles + any
/// imported custom styles.
///
/// Phase 09 Wave 0 scaffold. Plan 09-07 rewrites with the actual sheet
/// layout (preview thumbnails, currently-selected highlight, tap →
/// `MirkStyleSessionController.select(...)`). Wave 0 returns an inert
/// `SizedBox.shrink()` so the widget tree compiles end-to-end.
class MirkStylePickerSheet extends StatelessWidget {
  const MirkStylePickerSheet({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
