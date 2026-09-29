import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/features/parent/parent_screen.dart';
import 'package:readapp/ui/theme.dart';

import 'purchase_test.dart' show FakeProtection, MemoryStore;

class _FailingStore extends MemoryStore {
  bool fail = false;

  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('Storage unavailable');
    await super.write(value);
  }
}

void main() {
  Future<void> showSettings(WidgetTester tester, AppController c) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WinTheme.data,
        home: ParentScreen(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SegmentedButton<int>));
    await tester.pumpAndSettle();
  }

  group('ParentScreen age category', () {
    testWidgets('should persist each category without losing child progress', (
      tester,
    ) async {
      final store = MemoryStore();
      final c = AppController(store, screenTime: FakeProtection())
        ..onboarded = true
        ..sound = false;
      c.auth.create('123456');
      c.reading.completePage('frog', 0, DateTime(2026, 9, 27));
      c.reading.savePosition('frog', 2);
      await c.save();
      final reading = c.snapshot['reading'];
      final auth = c.snapshot['auth'];
      await showSettings(tester, c);
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {7},
      );

      for (final (label, age) in [('4–6', 4), ('10–12', 10), ('7–9', 7)]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final reloaded = AppController(store);
        await reloaded.load();
        expect(reloaded.age, age);
        expect(reloaded.snapshot['reading'], reading);
        expect(reloaded.snapshot['auth'], auth);
        expect(reloaded.onboarded, isTrue);
        expect(reloaded.sound, isFalse);
      }
    });

    testWidgets('should restore the saved category after a failed save', (
      tester,
    ) async {
      final store = _FailingStore();
      final c = AppController(store, screenTime: FakeProtection());
      await c.save();
      await showSettings(tester, c);
      store.fail = true;
      await tester.tap(find.text('4–6'));
      await tester.pumpAndSettle();
      expect(c.age, 7);
      expect(store.data!['age'], 7);
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {7},
      );
      expect(
        find.text('Age could not be saved. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      store.fail = false;
      await tester.tap(find.text('4–6'));
      await tester.pumpAndSettle();
      expect(store.data!['age'], 4);
      expect(
        find.text('Age could not be saved. Please try again.'),
        findsNothing,
      );
    });
  });
}
