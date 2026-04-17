// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/constants.dart';
import 'presentation/screens/placeholder_home_screen.dart';

/// Root application widget for MirkFall.
///
/// Phase 01 uses a minimal `MaterialApp` with a fixed home so the smoke test
/// can pump the app without pulling in GoRouter or Riverpod codegen. Phase 02
/// will swap the `home:` for `routerConfig:` once `appRouterProvider` exists.
class MirkFallApp extends ConsumerWidget {
  const MirkFallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: kAppName,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PlaceholderHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
