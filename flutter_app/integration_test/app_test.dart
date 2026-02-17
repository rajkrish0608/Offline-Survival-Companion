import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_survival_companion/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End App Test: Phase 2 Features', (WidgetTester tester) async {
    app.main();
    // Allow async init
    await Future.delayed(const Duration(seconds: 10)); 
    await tester.pumpAndSettle();

    // 1. Verify Home Screen or Onboarding
    if (find.text('Offline Survival Companion').evaluate().isEmpty) {
      debugPrint('Home Screen not found. Dumping widget tree:');
      debugPrint(tester.allWidgets.toString());
    }
    expect(find.text('Offline Survival Companion'), findsOneWidget);

    // 2. Maps Tab (New Logic: Download Pack)
    await tester.tap(find.byIcon(Icons.map));
    await tester.pumpAndSettle();
    
    // Verify Screen Title
    expect(find.text('Offline Maps'), findsOneWidget);
    
    // Verify list item presence
    expect(find.text('California, USA'), findsOneWidget);
    
    // Tap download on the first item (California)
    // Finding the icon button (download icon)
    final downloadIcon = find.byIcon(Icons.download).first;
    await tester.tap(downloadIcon);
    await tester.pump(); // Trigger setState
    
    // Allow time for simulation (10 * 100ms = 1s, plus buffer)
    await Future.delayed(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    
    // Verify successful download (Green check circle)
    // Note: London is already downloaded, so now we have 2 check circles (California + London)
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // 3. Vault Tab
    await tester.tap(find.byIcon(Icons.lock));
    await tester.pumpAndSettle();
    expect(find.text('Vault Screen'), findsOneWidget);
    expect(find.text('Store encrypted documents here'), findsOneWidget);

    // 4. Guide Tab (New Logic: Open Article)
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

    // 5. Emergency SOS (New Logic: Loud Alarm)
    // Navigate home first to access FAB clearly
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();

    final sosFabFinder = find.widgetWithText(FloatingActionButton, 'SOS');
    await tester.tap(sosFabFinder);
    await tester.pump(const Duration(milliseconds: 500)); // Wait for nav
    await tester.pump(const Duration(milliseconds: 500)); // Wait for Simulation start

    // Verify Emergency Screen
    expect(find.text('Loud Alarm'), findsOneWidget);
    
    // Activate Alarm
    await tester.tap(find.text('Loud Alarm'));
    await tester.pump(const Duration(milliseconds: 500));
    // SnackBar might disappear quickly, but widget tree should contain it if pumped correctly
    // We check for the text 'Loud Alarm ACTIVATED'
    expect(find.text('Loud Alarm ACTIVATED'), findsOneWidget);
    
    // Deactivate Alarm
    await tester.tap(find.text('Loud Alarm'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Alarm Silenced'), findsOneWidget);
    
    // End Emergency
    // Note: On Simulator, permission dialogs MIGHT block this. 
    // We try to tap it. If it fails due to splash/dialog, the test will fail.
    // However, iOS Simulator usually handles permissions gracefully if configured in Info.plist?
    // We will attempt it.
    await tester.tap(find.text('End Emergency Mode'));
    await tester.pump(const Duration(milliseconds: 500));
    
    // Handle Confirm Dialog
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    
    // Back Home
    expect(find.text('Offline Survival Companion'), findsOneWidget);
  });
}
