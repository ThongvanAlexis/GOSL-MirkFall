// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// TODO(09-05): rewrite as @Riverpod(keepAlive: true) generator target.
//
// Wave 0 emits this non-Riverpod stub so downstream scaffolds can
// reference `activeMirkRendererProvider` as a compiling symbol. Wave 4
// replaces this file with a @riverpod-annotated function + regenerated
// `.g.dart`.

/// Provider stub — exposes the currently active [MirkRenderer] for the
/// session.
///
/// Wave 4 (plan 09-05) promotes this to a `@riverpod` function that
/// watches the persisted style id and rebuilds the renderer via
/// [MirkRendererFactory] when it changes.
void activeMirkRendererProvider() => throw UnimplementedError('Wave 4 — plan 09-05');
