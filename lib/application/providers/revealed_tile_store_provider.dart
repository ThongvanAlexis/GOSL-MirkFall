// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_revealed_tile_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';
import 'id_generator_provider.dart';

part 'revealed_tile_store_provider.g.dart';

/// Production [RevealedTileStore] — wraps [`DriftRevealedTileStore`]
/// around the app database + production id generator. The id generator
/// is required at this layer: `mergeMask`'s insert branch mints a new
/// revealed-tile row id (`rvt_` prefix) when the parent tile has not
/// been written yet in the current session.
@Riverpod(keepAlive: true)
Future<RevealedTileStore> revealedTileStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final idGen = ref.watch(idGeneratorProvider);
  return DriftRevealedTileStore(db, idGen);
}
