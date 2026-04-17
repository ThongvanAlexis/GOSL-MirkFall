// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/logging/file_logger.dart';
import 'package:mirkfall/presentation/screens/debug_menu_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    tempDir = await Directory.systemTemp.createTemp('mirkfall_debugmenu_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await FileLogger.bootstrap();
  });

  tearDown(() async {
    await FileLogger.clearAll(rearm: false);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // pumpAndSettle() hangs here because each `LogRecord` emitted during the
  // test triggers FileLogger.sink.writeln which awaits flush(), feeding the
  // microtask queue continuously — the framework never reaches quiescence.
  // We drive pumps explicitly instead, with a bounded retry on the _loading
  // → loaded transition since _refresh() is async.
  Future<void> settleRefresh(WidgetTester tester) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      // runAsync lets real async work (FileLogger.readVerbosePref, listLogFiles)
      // complete; pump() alone only advances timers without executing the real
      // microtasks from outside the fake-async zone.
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(SwitchListTile).evaluate().isNotEmpty) return;
    }
  }

  testWidgets('DebugMenuScreen shows verbose switch, log-file list placeholder, and clear-all row', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: DebugMenuScreen())));
    await settleRefresh(tester);

    expect(find.text('Verbose logging'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('Supprimer tous les logs'), findsOneWidget);
    expect(find.textContaining('Active: '), findsOneWidget);
    expect(find.textContaining('(none)'), findsNothing);
  });

  testWidgets('Tapping the verbose switch flips the SharedPreferences flag', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: DebugMenuScreen())));
    await settleRefresh(tester);

    expect(await FileLogger.readVerbosePref(), isFalse);

    // Tap the switch and let the async toggle + setState flush.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(await FileLogger.readVerbosePref(), isTrue);

    // Toggle back.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(await FileLogger.readVerbosePref(), isFalse);
  });
}
