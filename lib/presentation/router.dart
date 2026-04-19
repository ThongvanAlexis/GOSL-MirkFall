// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'screens/about_placeholder_screen.dart';
import 'screens/debug_menu_screen.dart';
import 'screens/oem_guidance_screen.dart';
import 'screens/permission_denied_screen.dart';
import 'screens/permission_rationale_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/session_list_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/app_shell.dart';

part 'router.g.dart';

/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 05 route map:
/// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
/// - `/sessions/:id` → [SessionDetailScreen]
/// - `/settings` → [SettingsScreen]
/// - `/permissions/rationale` → [PermissionRationaleScreen]
/// - `/permissions/denied` → [PermissionDeniedScreen]
/// - `/permissions/oem` → [OemGuidanceScreen]
/// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
/// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
///
/// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
/// top. [AppShell] decides — based on `currentLocation` — whether to
/// render the cross-route active-session banner (hidden on
/// `/sessions/:id`).
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) => AppShell(currentLocation: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const SessionListScreen()),
          GoRoute(
            path: '/sessions/:id',
            builder: (_, state) {
              final String id = state.pathParameters['id'] ?? '';
              return SessionDetailScreen(sessionId: SessionId(id));
            },
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/permissions/rationale', builder: (_, _) => const PermissionRationaleScreen()),
          GoRoute(path: '/permissions/denied', builder: (_, _) => const PermissionDeniedScreen()),
          GoRoute(path: '/permissions/oem', builder: (_, _) => const OemGuidanceScreen()),
          GoRoute(path: '/about', builder: (_, _) => const AboutPlaceholderScreen()),
          GoRoute(path: '/debug', builder: (_, _) => const DebugMenuScreen()),
        ],
      ),
    ],
  );
}
