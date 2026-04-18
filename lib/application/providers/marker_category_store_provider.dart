// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/markers/marker_category_store.dart';
import 'package:mirkfall/infrastructure/stores/drift_marker_category_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database_provider.dart';

part 'marker_category_store_provider.g.dart';

/// Production [MarkerCategoryStore] — wraps
/// [`DriftMarkerCategoryStore`] around the app database. Carries the
/// non-CASCADE reassign-to-default transactional policy.
@Riverpod(keepAlive: true)
Future<MarkerCategoryStore> markerCategoryStore(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return DriftMarkerCategoryStore(db);
}
