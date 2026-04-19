// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/fixes/fix_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_fix_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';

part 'fix_store_provider.g.dart';

/// Production [FixStore] — wraps [`DriftFixStore`] around the app database.
///
/// Returned as `Future<FixStore>` because [appDatabaseProvider] is async
/// (path_provider resolves `<app_support>/` off the UI thread). Consumers
/// (Plan 05-02 ActiveSessionController) await
/// `ref.watch(fixStoreProvider.future)` at construction time.
///
/// `keepAlive: true` — the store wraps a process-singleton database;
/// re-creating on every consumer subscription would not reduce DB load
/// (Drift holds the handle) but would churn the Riverpod graph.
@Riverpod(keepAlive: true)
Future<FixStore> fixStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftFixStore(db);
}
