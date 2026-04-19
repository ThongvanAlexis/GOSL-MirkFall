// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/infrastructure/platform/oem_detector.dart';
import 'package:mirkfall/presentation/screens/oem_guidance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/permissions/oem',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/permissions/oem', builder: (_, _) => child),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  group('OemGuidanceScreen', () {
    testWidgets('rendersXiaomiStepsWhenXiaomiFamily', (tester) async {
      await tester.pumpWidget(_wrap(const OemGuidanceScreen(familyOverride: XiaomiFamily())));
      await tester.pumpAndSettle();

      expect(find.text('Xiaomi / Redmi / POCO'), findsOneWidget);
      expect(find.textContaining('MIUI'), findsOneWidget);
      expect(find.textContaining('dontkillmyapp.com/xiaomi'), findsOneWidget);
    });

    testWidgets('rendersSamsungSteps', (tester) async {
      await tester.pumpWidget(_wrap(const OemGuidanceScreen(familyOverride: SamsungFamily())));
      await tester.pumpAndSettle();

      expect(find.text('Samsung'), findsOneWidget);
      expect(find.textContaining('Device Care'), findsOneWidget);
    });

    testWidgets('rendersHuaweiSteps', (tester) async {
      await tester.pumpWidget(_wrap(const OemGuidanceScreen(familyOverride: HuaweiFamily())));
      await tester.pumpAndSettle();

      expect(find.text('Huawei / Honor'), findsOneWidget);
      expect(find.textContaining('EMUI'), findsOneWidget);
    });

    testWidgets('rendersIosNoteWhenIos', (tester) async {
      await tester.pumpWidget(_wrap(const OemGuidanceScreen(familyOverride: IosDevice())));
      await tester.pumpAndSettle();

      expect(find.text('iOS'), findsOneWidget);
      expect(find.textContaining('iOS gère automatiquement'), findsOneWidget);
    });

    testWidgets('okMarksOemGuidanceSeen', (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.pumpWidget(_wrap(const OemGuidanceScreen(familyOverride: OtherOem())));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(OemGuidanceScreen));
      final container = ProviderScope.containerOf(element);

      await tester.tap(find.text("OK j'ai fait"));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('oem_guidance_seen'), isTrue);
      final snapshot = await container.read(sessionSettingsProvider.future);
      expect(snapshot.oemGuidanceSeen, isTrue);
    });

    testWidgets('linkInvokesShare', (tester) async {
      int invocations = 0;
      String? capturedUrl;
      await tester.pumpWidget(
        _wrap(
          OemGuidanceScreen(
            familyOverride: const XiaomiFamily(),
            shareLinkFn: (url) async {
              invocations++;
              capturedUrl = url;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('dontkillmyapp.com/xiaomi'));
      await tester.pumpAndSettle();

      expect(invocations, 1);
      expect(capturedUrl, 'https://dontkillmyapp.com/xiaomi');
    });
  });
}
