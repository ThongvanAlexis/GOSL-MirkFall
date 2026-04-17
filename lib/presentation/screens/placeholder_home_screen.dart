// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';

import '../../config/constants.dart';

/// Phase 01 placeholder screen. Phase 02 replaces the router home with the
/// real entry screens (map + about + debug menu).
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(kAppName)),
      body: const Center(child: Text('MirkFall — bootstrap OK')),
    );
  }
}
