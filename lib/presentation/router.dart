// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'screens/about_placeholder_screen.dart';
import 'screens/debug_menu_screen.dart';
import 'screens/map_screen.dart';
import 'screens/maps_download_screen.dart';
import 'screens/maps_manage_screen.dart';
import 'screens/oem_guidance_screen.dart';
import 'screens/permission_denied_screen.dart';
import 'screens/permission_rationale_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/session_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/style_export_placeholder_screen.dart';
import 'screens/style_import_placeholder_screen.dart';
import 'widgets/app_shell.dart';

part 'router.g.dart';

/// Top-level navigator key used by the Phase 05 notification-tap handler in
/// `lib/main.dart` — `flutter_local_notifications` fires its
/// `onDidReceiveNotificationResponse` callback OUTSIDE the widget tree, so
/// the handler needs an out-of-band route to push against. The same key is
/// passed to [GoRouter.navigatorKey] in [appRouter] so `GoRouter.of(...)`
/// resolves against the active router regardless of build order.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNavigatorKey');

/// Root GoRouter exposed via Riverpod so consumers get it through DI.
///
/// Phase 05 route map (extended by Phase 07):
/// - `/` → [SessionListScreen] (was [PlaceholderHomeScreen] in Phase 01)
/// - `/sessions/:id` → [SessionDetailScreen]
/// - `/settings` → [SettingsScreen]
/// - `/permissions/rationale` → [PermissionRationaleScreen]
/// - `/permissions/denied` → [PermissionDeniedScreen]
/// - `/permissions/oem` → [OemGuidanceScreen]
/// - `/about` → [AboutPlaceholderScreen] (unchanged from Phase 01)
/// - `/debug` → [DebugMenuScreen] (unchanged from Phase 01)
///
/// Phase 07 additions:
/// - `/map` → [MapScreen] (full-screen interactive map)
/// - `/maps/download` → [MapsDownloadScreen] (catalog browse + enqueue)
/// - `/maps/manage` → [MapsManageScreen] (installed list + delete)
/// - `/styles/import` → [StyleImportPlaceholderScreen] (Phase 13 stub)
/// - `/styles/export` → [StyleExportPlaceholderScreen] (Phase 13 stub)
///
/// Every route is wrapped by a [ShellRoute] that injects [AppShell] on
/// top. [AppShell] decides — based on `currentLocation` — whether to
/// render the cross-route active-session banner (hidden on
/// `/sessions/:id` and `/map`).
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
              // `?start=true` is emitted by SessionListScreen when the
              // user taps "Créer et démarrer" in the create dialog.
              // The query param is the signal that triggers the Start
              // flow automatically once the detail route is on screen —
              // keeps the permission dialogs visible on a clean route
              // instead of hidden under the create dialog's Overlay.
              final bool autoStart = state.uri.queryParameters['start'] == 'true';
              return SessionDetailScreen(sessionId: SessionId(id), autoStart: autoStart);
            },
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/permissions/rationale', builder: (_, _) => const PermissionRationaleScreen()),
          GoRoute(path: '/permissions/denied', builder: (_, _) => const PermissionDeniedScreen()),
          GoRoute(path: '/permissions/oem', builder: (_, _) => const OemGuidanceScreen()),
          GoRoute(path: '/about', builder: (_, _) => const AboutPlaceholderScreen()),
          GoRoute(path: '/debug', builder: (_, _) => const DebugMenuScreen()),
          // Phase 07 (map integration) — 5 new routes.
          GoRoute(path: '/map', builder: (_, _) => const MapScreen()),
          GoRoute(path: '/maps/download', builder: (_, _) => const MapsDownloadScreen()),
          GoRoute(path: '/maps/manage', builder: (_, _) => const MapsManageScreen()),
          GoRoute(path: '/styles/import', builder: (_, _) => const StyleImportPlaceholderScreen()),
          GoRoute(path: '/styles/export', builder: (_, _) => const StyleExportPlaceholderScreen()),
        ],
      ),
    ],
  );
}
