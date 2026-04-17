// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/app.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/logging/file_logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake [PathProviderPlatform] pointing at a test-owned temp directory.
/// Reused across all Phase 02 widget tests that need `path_provider` to
/// return something that exists on the host OS.
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this._root);
  final Directory _root;

  @override
  Future<String?> getApplicationDocumentsPath() async => _root.path;

  @override
  Future<String?> getApplicationSupportPath() async => _root.path;

  @override
  Future<String?> getTemporaryPath() async => _root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_smoke_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // MirkFallApp no longer hard-depends on FileLogger (it watches
    // appRouterProvider only), but the router itself mounts screens that
    // may trigger FileLogger.readVerbosePref etc. on navigation in later
    // phases — bootstrap now to keep the smoke test representative.
    await FileLogger.bootstrap();
  });

  tearDown(() async {
    await FileLogger.clearAll(rearm: false);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Bounded pump helper aligned with debug_menu_screen_test's settleRefresh:
  // pumpAndSettle hangs because FileLogger's per-record flush feeds the
  // microtask queue. A single tester.pump() can be fragile if go_router
  // adds a transition frame on some engines — iterate with a short bound
  // and an explicit termination condition.
  Future<void> settlePumpUntilText(WidgetTester tester, String text) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text(text).evaluate().isNotEmpty) return;
    }
  }

  testWidgets('MirkFallApp pumps and renders the Phase 01 placeholder home', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MirkFallApp()));
    await settlePumpUntilText(tester, 'MirkFall — bootstrap OK');

    expect(find.text('MirkFall — bootstrap OK'), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text(kAppName)), findsOneWidget);
  });
}
