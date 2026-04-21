// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared link-handling strategy for attribution blocks (MAP-03).
///
/// Phase 07 does NOT pull `url_launcher` (no new dep policy — DEPENDENCIES.md
/// audit row would block a drive-by add). Instead, we copy the URL to the
/// clipboard and surface a short snackbar so the user knows the URL is on
/// their clipboard and can paste it into their browser. Phase 15 may revisit
/// this trade-off; until then, both the map's attribution bottom sheet
/// (`MapAttributionIcon`) and the À propos screen's attribution block share
/// this single helper so the UX stays identical across the two entry points.
Future<void> openAttributionLink(BuildContext context, Uri url) async {
  await Clipboard.setData(ClipboardData(text: url.toString()));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('URL copiée dans le presse-papier : $url'),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Canonical OSM copyright URL for the attribution block. Single source of
/// truth consumed by both the map's attribution bottom sheet and the About
/// screen so both surfaces point at the same URL byte-for-byte.
final Uri kOpenStreetMapCopyrightUrl = Uri.parse('https://www.openstreetmap.org/copyright');

/// Canonical Protomaps URL for the attribution block.
final Uri kProtomapsUrl = Uri.parse('https://protomaps.com/');
