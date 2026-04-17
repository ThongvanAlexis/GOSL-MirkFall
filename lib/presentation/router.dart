// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'screens/about_placeholder_screen.dart';
import 'screens/debug_menu_screen.dart';
import 'screens/placeholder_home_screen.dart';

part 'router.g.dart';

/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 01 ships three routes: `/` (home placeholder), `/about` (placeholder
/// with the 7-tap easter egg), `/debug` (debug menu). Later phases add the
/// real map / settings / marker routes.
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <GoRoute>[
      GoRoute(path: '/', builder: (_, _) => const PlaceholderHomeScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutPlaceholderScreen()),
      GoRoute(path: '/debug', builder: (_, _) => const DebugMenuScreen()),
    ],
  );
}
