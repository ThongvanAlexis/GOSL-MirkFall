// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/logging/file_logger.dart';
import 'package:path/path.dart' as p;
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

/// Size chosen so that 6 such files > [kMaxLogsDirBytes] (10 MB).
/// 6 × 2 MB = 12 MB, so prune must remove at least 2 files to get under the cap.
const int _kFakeFileBytes = 2 * 1024 * 1024;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory logsDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_prune_');
    logsDir = Directory(p.join(tempDir.path, 'logs'));
    await logsDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await FileLogger.clearAll(rearm: false);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('prune trims oldest files until total size < kMaxLogsDirBytes', () async {
    // Seed 6 fake log files totaling 12 MB (above the 10 MB cap).
    final payload = Uint8List(_kFakeFileBytes);
    final seeded = <File>[];
    for (var i = 1; i <= 6; i++) {
      final name =
          '20260417_100000.0$i'
          '_logs.txt';
      final f = File(p.join(logsDir.path, name));
      await f.writeAsBytes(payload, flush: true);
      seeded.add(f);
    }

    // Sanity check: seeded total exceeds the cap.
    int totalBefore = 0;
    for (final f in seeded) {
      totalBefore += await f.length();
    }
    expect(totalBefore, greaterThan(kMaxLogsDirBytes));

    // Bootstrap runs the prune.
    await FileLogger.bootstrap();

    // Measure the remaining files. The newly-opened active file is
    // excluded from the cap check — bootstrap immediately writes a
    // first-record line capturing `activeFilename` (cross-check anchor
    // for iOS sandbox container UUID drift) so it is no longer 0 bytes
    // at this point, and the prune algorithm is only responsible for
    // the SEEDED total, not the post-bootstrap write.
    final activeFilename = FileLogger.activeFilename;
    int totalAfter = 0;
    final remaining = <String>[];
    await for (final entity in logsDir.list()) {
      if (entity is File && entity.path.endsWith('_logs.txt')) {
        if (entity.path == activeFilename) continue;
        totalAfter += await entity.length();
        remaining.add(p.basename(entity.path));
      }
    }
    expect(totalAfter, lessThanOrEqualTo(kMaxLogsDirBytes), reason: 'Seeded files must be under the cap after prune (active file excluded)');

    // Oldest seeded file should be gone; newest should survive.
    expect(remaining, isNot(contains('20260417_100000.01_logs.txt')), reason: 'Oldest seeded file must have been pruned');
    expect(remaining, contains('20260417_100000.06_logs.txt'), reason: 'Newest seeded file must survive');
  });
}
