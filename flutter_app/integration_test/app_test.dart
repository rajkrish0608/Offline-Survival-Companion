import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_survival_companion/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End App Test: Phase 2 Features',
      (WidgetTester tester) async {
    app.main();
    // Allow async init (services, Hive, SQLite, etc.)
    await Future.delayed(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    // 1. Verify Home Screen or Onboarding
    if (find.text('Offline Survival Companion').evaluate().isEmpty) {
      debugPrint('Home Screen not found. Dumping widget tree:');
      debugPrint(tester.allWidgets.toString());
    }
    expect(find.text('Offline Survival Companion'), findsOneWidget);

    // 2. Maps Tab (Navigate via bottom nav, download a pack)
    await tester.tap(find.byIcon(Icons.map));
    await tester.pumpAndSettle();

    // Verify Screen Title
    expect(find.text('Offline Maps'), findsOneWidget);

    // Reveal downloads list (Manage Downloads icon)
    await tester.tap(find.byIcon(Icons.download_for_offline));
    await tester.pumpAndSettle();

    // Verify list item presence
    expect(find.text('California, USA'), findsOneWidget);

    // Tap download on the first item (California)
    final downloadIcon = find.byIcon(Icons.download).first;
    await tester.tap(downloadIcon);
    await tester.pump(); // Trigger setState

    // Allow time for simulated download (10 * 300ms = 3s, plus buffer)
    await Future.delayed(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Verify successful download (Green check circle)
    // London is already downloaded, so now we have 2 check circles (California + London)
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // 3. Vault Tab (shows locked view with biometric auth)
    await tester.tap(find.byIcon(Icons.lock));
    await tester.pumpAndSettle();
    // VaultScreen shows "Secure Vault" in AppBar and "Vault is Locked" in body
    expect(find.text('Secure Vault'), findsOneWidget);
    expect(find.text('Vault is Locked'), findsOneWidget);

    // 4. Guide Tab (Load JSON content and expand article)
    await tester.tap(find.byIcon(Icons.school));
    await tester.pumpAndSettle();

    // Verify content list
    expect(find.text('Survival Guides'), findsOneWidget); // App Bar
    expect(find.text('CPR (Cardiopulmonary Resuscitation)'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('CPR (Cardiopulmonary Resuscitation)'));
    await tester.pumpAndSettle();

    // Verify expanded content
    expect(find.textContaining('Call emergency number'), findsOneWidget);

    // 5. Emergency SOS (Navigate via FAB, verify emergency screen)
    // Navigate home first to access FAB clearly
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();

    final sosFabFinder = find.widgetWithText(FloatingActionButton, 'SOS');
    await tester.tap(sosFabFinder);
    // Pump multiple frames to allow GoRouter navigation + EmergencyScreen init
    await tester.pump(); // Process tap
    await tester.pump(const Duration(milliseconds: 500)); // Route transition
    await tester
        .pump(const Duration(milliseconds: 500)); // SOS simulation start

    // Verify Emergency Screen elements are present
    expect(find.text('Loud Alarm'), findsOneWidget);
    expect(find.text('Flashlight'), findsOneWidget);
    expect(find.text('Hospital'), findsOneWidget);
    expect(find.text('First Aid'), findsOneWidget);
    expect(find.text('Current Location'), findsOneWidget);
    expect(find.text('End Emergency Mode'), findsOneWidget);
    expect(find.text('Contact Status'), findsOneWidget);

    // Navigate back from emergency screen using Navigator.pop
    final NavigatorState navigator = tester.state(find.byType(Navigator).last);
    navigator.pop();
    await tester.pump(); // Process pop
    await tester.pump(const Duration(milliseconds: 500)); // Route transition
    await tester.pumpAndSettle();

    // Back Home
    expect(find.text('Offline Survival Companion'), findsOneWidget);

    // 6. Webpage Saver Screen - bug fix verification
    // The 'Web Saver' card is in the Quick Actions grid — ensure it is visible before tapping
    await tester.ensureVisible(find.text('Web Saver').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Web Saver').first);
    await tester.pumpAndSettle();

    // Verify screen title in AppBar
    expect(find.text('Webpage Saver'), findsOneWidget);

    // Verify no mock/fake pages are shown in the list
    expect(find.text('Build A Kit | Ready.gov'), findsNothing,
        reason: 'Mock pages must not appear; only actually-downloaded ones should');
    expect(find.text('Get Help | Red Cross'), findsNothing,
        reason: 'Mock pages must not appear; only actually-downloaded ones should');

    // Verify empty-state prompt is shown when no pages saved
    expect(find.text('No saved pages yet'), findsOneWidget);

    debugPrint('Webpage Saver screen verified: no mock data, empty state shown correctly.');
  });
}
