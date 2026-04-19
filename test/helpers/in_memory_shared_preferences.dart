// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:shared_preferences/shared_preferences.dart';

/// Primes [SharedPreferences] with an in-memory mock for tests.
///
/// Wraps [SharedPreferences.setMockInitialValues] — the seam recommended by
/// the `shared_preferences` README for unit/widget tests. Returns the
/// instance so callers can chain assertions.
///
/// Requires the widget-test binding to be initialised by the caller
/// (`TestWidgetsFlutterBinding.ensureInitialized()`).
Future<SharedPreferences> primeSharedPreferences([
  Map<String, Object>? seed,
]) async {
  SharedPreferences.setMockInitialValues(seed ?? const <String, Object>{});
  return SharedPreferences.getInstance();
}
