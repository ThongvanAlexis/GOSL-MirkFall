// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:logging/logging.dart';

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';

final Logger _log = Logger('infrastructure.mirk.offscreen_fog');

/// Renders the fog-of-war to an offscreen image and returns PNG bytes.
///
/// This bridges the [MirkRenderer] painting API (which targets a [ui.Canvas])
/// with MapLibre's image source, which expects raw PNG data. The caller
/// controls the output resolution via [Size] — typical values are 256x256
/// (SDF resolution) or 512x512 for higher-fidelity fog tiles.
class OffscreenFogRenderer {
  /// Creates a stateless offscreen renderer. All mutable state lives in the
  /// [MirkRenderer] and [MirkPaintContext] passed to [renderToPng].
  const OffscreenFogRenderer();

  /// Renders the fog to an offscreen image and returns PNG bytes suitable
  /// for MapLibre's image source.
  ///
  /// The [renderer] paints to a virtual canvas of [size] pixels using
  /// [context] as the paint context. The canvas starts fully transparent;
  /// the renderer is responsible for painting the fog fill and clearing
  /// revealed areas.
  ///
  /// Returns `null` if PNG encoding fails (e.g. the renderer is not ready
  /// yet or the platform cannot allocate the requested image size).
  Future<Uint8List?> renderToPng({required MirkRenderer renderer, required MirkPaintContext context, required ui.Size size}) async {
    final int width = size.width.ceil();
    final int height = size.height.ceil();

    if (width <= 0 || height <= 0) {
      _log.warning('renderToPng called with degenerate size: ${size.width}x${size.height}');
      return null;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    renderer.paint(canvas, size, context);

    final ui.Picture picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width, height);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _log.warning('PNG encoding returned null for ${width}x$height image');
        return null;
      }
      return byteData.buffer.asUint8List();
    } on Exception catch (e, st) {
      _log.severe('Failed to render offscreen fog (${width}x$height)', e, st);
      return null;
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }
}
