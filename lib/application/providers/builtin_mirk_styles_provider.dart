// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// TODO(09-05): rewrite as @Riverpod(keepAlive: true) generator target.
//
// Wave 0 emits this non-Riverpod stub so downstream scaffolds can
// reference `builtinMirkStylesProvider` as a compiling symbol. Wave 4
// replaces this file with a @riverpod-annotated function returning the
// `kBuiltinMirkStyles` registry from `infrastructure/mirk/builtin_mirk_styles.dart`.

/// Provider stub — exposes the list of built-in mirk styles for the
/// style picker UI.
///
/// Wave 4 (plan 09-05) promotes this to a `@riverpod` function.
void builtinMirkStylesProvider() => throw UnimplementedError('Wave 4 — plan 09-05');
