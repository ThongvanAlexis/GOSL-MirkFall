// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/infrastructure/logging/file_logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This test MUST be run with `--dart-define=DEBUG=true`. Without the define,
/// the body falls back to an informational assertion so the default
/// `flutter test` run doesn't produce a false-positive claim that the
/// DEBUG-define path works. Plan 01-04 (CI) adds a dedicated step:
///   flutter test --dart-define=DEBUG=true test/file_logger_debug_define_test.dart
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
    tempDir = await Directory.systemTemp.createTemp('mirkfall_debug_define_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    // Empty prefs so only the DEBUG define can push level to ALL.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await FileLogger.clearAll(rearm: false);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('with --dart-define=DEBUG=true, bootstrap sets Logger.root.level = Level.ALL', () async {
    const debugDefine = bool.fromEnvironment('DEBUG');

    await FileLogger.bootstrap();

    if (debugDefine) {
      expect(Logger.root.level, Level.ALL, reason: 'With --dart-define=DEBUG=true and no verbose prefs, root level must be ALL');
    } else {
      // Without the define, the contract is the other direction: level must
      // stay at INFO (no implicit promotion).
      expect(Logger.root.level, Level.INFO, reason: 'Without --dart-define=DEBUG=true and no verbose prefs, root level must stay at INFO');
    }
  });
}
