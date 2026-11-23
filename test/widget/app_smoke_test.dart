import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfix/app.dart';
import 'package:pixelfix/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home shows the tools, onboarding appears once and can be skipped', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const PixelFixApp(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // First launch: coach marks.
    expect(find.text('Open a photo'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Choose an AI tool'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Open a photo'), findsNothing);

    // Home content.
    expect(find.text('PixelFix'), findsOneWidget);
    expect(find.text('Open Photo'), findsOneWidget);
    expect(find.text('Magic Eraser'), findsOneWidget);
    expect(prefs.getBool('onboarded'), true);
  });

  testWidgets('settings page lists theme, processing mode and the privacy note', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const PixelFixApp(),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Processing mode'), findsOneWidget);
    expect(find.text('AI Models'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('never leave your phone'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('never leave your phone'), findsOneWidget);
  });
}
