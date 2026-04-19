// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/app.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_store.dart';
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

/// Minimal in-memory [SessionStore] used for the smoke test. Drops all
/// stream-backed features so there are no pending Drift timers at
/// ProviderScope teardown. Returns an empty list — the screen renders
/// the empty-state CTA.
class _EmptyStreamSessionStore implements SessionStore {
  @override
  Future<List<Session>> listAll() async => const <Session>[];

  @override
  Future<Session?> findById(SessionId id) async => null;

  @override
  Future<Session> requireById(SessionId id) async => throw StateError('smoke test: no sessions');

  @override
  Future<Session?> findActive() async => null;

  @override
  Future<void> insert(Session session) async {}

  @override
  Future<void> update(Session session) async {}

  @override
  Future<void> delete(SessionId id) async {}

  @override
  Future<void> activate(SessionId id) async {}

  @override
  Future<void> deactivate(SessionId id) async {}

  @override
  Stream<List<Session>> watchAll() => Stream<List<Session>>.value(const <Session>[]);
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
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Windows can hold the sqlite file open for a few frames after
        // tear-down. Swallow — the temp dir will be reclaimed by the
        // OS eventually. Not a production concern.
      }
    }
  });

  Future<void> settlePumpUntilText(WidgetTester tester, String text) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text(text).evaluate().isNotEmpty) return;
    }
  }

  testWidgets('MirkFallApp pumps and renders the Phase 05 session list home', (WidgetTester tester) async {
    // Phase 05-04: `/` is [SessionListScreen] which consumes
    // [sessionListProvider] → sessionStoreProvider → appDatabaseProvider.
    // The smoke test overrides [sessionStoreProvider] with an
    // in-memory fake so the widget tree does not drag in Drift's
    // stream-query timers (which fight the test-binding
    // verify-no-pending-timers gate at dispose time). Rationale:
    // end-to-end coverage is provided by phase-specific widget tests
    // that already inject fakes; the smoke only proves bootstrap +
    // route mount + Scaffold render.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWith((ref) async => _EmptyStreamSessionStore())],
        child: const MirkFallApp(),
      ),
    );
    await settlePumpUntilText(tester, 'Mes sessions');

    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Mes sessions')), findsOneWidget);
    // Double-check kAppName still resolves (catches unrelated Phase 01
    // constant renames that would break the smoke build).
    expect(kAppName, isNotEmpty);
  });
}
