// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';

/// Phase 01 placeholder screen. Phase 02 replaces the router home with the
/// real entry screens (map + about + debug menu).
///
/// Carries an explicit navigation affordance to `/about` so the 7-tap debug
/// menu is reachable from a pristine build without code changes (finding #23
/// surfaced this gap during the Phase 02 visual walk).
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: <Widget>[IconButton(icon: const Icon(Icons.info_outline), tooltip: 'À propos', onPressed: () => context.push('/about'))],
      ),
      body: const Center(child: Text('MirkFall — bootstrap OK')),
    );
  }
}
