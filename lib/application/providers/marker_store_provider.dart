// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/markers/marker_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_marker_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';

part 'marker_store_provider.g.dart';

/// Production [MarkerStore] — wraps [`DriftMarkerStore`] around the app
/// database. No id generator injection here: Phase 03 callers pass a
/// pre-allocated [MarkerId]; id-minting is a Phase 11 store extension
/// when the photo-capture flow starts minting markers on the fly.
@Riverpod(keepAlive: true)
Future<MarkerStore> markerStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftMarkerStore(db);
}
