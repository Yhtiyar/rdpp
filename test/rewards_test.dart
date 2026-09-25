import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/reading_ledger.dart';

void main() {
  group('ReadingLedger', () {
    test('should award each page once and total 100 coins across books', () {
      final ledger = ReadingLedger();
      for (var i = 0; i < 9; i++) {
        expect(ledger.completePage('kolobok', i, DateTime(2026, 9, 25)), 10);
      }
      expect(ledger.completePage('kolobok', 0, DateTime(2026, 9, 25)), 0);
      expect(ledger.balance, 90);
      ledger.completePage('frog', 0, DateTime(2026, 9, 25));
      expect(ledger.balance, 100);
      expect(ledger.completedCount('kolobok'), 9);
    });
    test(
      'should preserve reading position and earned pages through reload',
      () {
        final ledger = ReadingLedger();
        ledger.savePosition('frog', 4);
        ledger.completePage('frog', 4, DateTime(2026, 9, 25));
        final restored = ReadingLedger.fromJson(ledger.toJson());
        expect(restored.position('frog'), 4);
        expect(restored.isComplete('frog', 4), true);
        expect(restored.balance, 10);
        expect(restored.completePage('frog', 4, DateTime(2026, 9, 26)), 0);
        expect(restored.streak(DateTime(2026, 9, 25)), 1);
      },
    );
  });
}
