// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/sessions/session_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_session_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';

part 'session_store_provider.g.dart';

/// Production [SessionStore] — wraps [`DriftSessionStore`] around the
/// app database.
///
/// Returned as `Future<SessionStore>` because [appDatabaseProvider] is
/// async (path_provider resolves `<app_support>/` off the UI thread).
/// Consumers that need the store synchronously (Phase 05 controllers)
/// await `ref.watch(sessionStoreProvider.future)` at construction time.
///
/// Finding #21 (Batch G) — dropped the IdGenerator injection: the store
/// never used it (all session ids are pre-allocated by the caller). If a
/// future insert-without-id path emerges, inject the generator then.
@Riverpod(keepAlive: true)
Future<SessionStore> sessionStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftSessionStore(db);
}
