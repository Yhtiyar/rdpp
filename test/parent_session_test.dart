import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/features/parent/parent_access.dart';

import 'purchase_test.dart' show MemoryStore;

void main() {
  group('Parent session', () {
    testWidgets('should close a recovery PIN screen when the app is hidden', (
      tester,
    ) async {
      final c = AppController(MemoryStore());
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ChangePinScreen(controller: c, recovering: true),
                  ),
                ),
                child: const Text('Open recovery'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open recovery'));
      await tester.pumpAndSettle();
      expect(find.text('A new parent PIN'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('A new parent PIN'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}
