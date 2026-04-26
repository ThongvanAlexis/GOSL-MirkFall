// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/revealed/revealed_disc_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_revealed_disc_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';

part 'revealed_disc_store_provider.g.dart';

/// Production [RevealedDiscStore] — wraps [DriftRevealedDiscStore] around
/// the app database. No id generator dependency: every reveal disc id is
/// minted at the call site (typically the GPS pipeline, BUG-010 Commit 4)
/// and passed into [RevealedDiscStore.addDisc] verbatim — the store does
/// not allocate ids on the insert branch (unlike `DriftRevealedTileStore`,
/// which mints `rvt_` ids when a parent tile is first written).
///
/// `keepAlive: true` matches `revealedTileStoreProvider` — the store is a
/// process singleton riding on top of the singleton `appDatabaseProvider`.
@Riverpod(keepAlive: true)
Future<RevealedDiscStore> revealedDiscStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftRevealedDiscStore(db);
}
