// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/sessions/session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'session_store_provider.dart';

part 'session_list_provider.g.dart';

/// Derived stream provider that bridges [sessionStoreProvider] (a
/// `Future<SessionStore>`) to the widget layer.
///
/// Plan 05-04 `SessionListScreen` consumes this via
/// `ref.watch(sessionListProvider)` and renders three arms:
/// `AsyncLoading` → spinner, `AsyncError` → error card, `AsyncData` →
/// session tiles (or empty-state CTA).
///
/// The implementation `await`s the store future once then pipes through
/// `watchAll()` — first emission carries the current snapshot, subsequent
/// emissions fire on every `t_sessions` row change. Ordering matches the
/// store's `listAll` contract (`startedAtUtc` DESC).
@Riverpod(keepAlive: true)
Stream<List<Session>> sessionList(Ref ref) async* {
  final store = await ref.watch(sessionStoreProvider.future);
  yield* store.watchAll();
}
