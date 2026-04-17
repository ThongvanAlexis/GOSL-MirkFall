// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/constants.dart';
import 'presentation/router.dart';

/// Root application widget for MirkFall.
///
/// Phase 02 wires `MaterialApp.router` to the `appRouterProvider` (GoRouter
/// via Riverpod codegen). Three routes live there: `/`, `/about`, `/debug`.
/// Later phases replace the home placeholder with the real map entry.
class MirkFallApp extends ConsumerWidget {
  const MirkFallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: kAppName,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
