// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/mirk/mirk_style_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_mirk_style_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';

part 'mirk_style_store_provider.g.dart';

/// Production [MirkStyleStore] — wraps [`DriftMirkStyleStore`] around
/// the app database. Phase 09 adds the first consumer (`MirkRenderer`
/// seam); Phase 03 only wires persistence.
@Riverpod(keepAlive: true)
Future<MirkStyleStore> mirkStyleStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftMirkStyleStore(db);
}
