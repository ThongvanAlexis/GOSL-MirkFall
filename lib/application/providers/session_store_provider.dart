// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_session_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';
import 'id_generator_provider.dart';

part 'session_store_provider.g.dart';

/// Production [SessionStore] — wraps [`DriftSessionStore`] around the
/// app database + production id generator.
///
/// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
/// async (path_provider resolves `<app_support>/` off the UI thread).
/// Consumers that need the store synchronously (Phase 05 controllers)
/// await `ref.watch(sessionStoreProvider.future)` at construction time.
@Riverpod(keepAlive: true)
Future<SessionStore> sessionStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final idGen = ref.watch(idGeneratorProvider);
  return DriftSessionStore(db, idGen);
}
