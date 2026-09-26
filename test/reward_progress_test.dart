import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/reward_progress.dart';

void main() {
  group('RewardProgress', () {
    for (final row in [
      (30, 70, .3, false),
      (90, 10, .9, false),
      (100, 0, 1.0, true),
      (120, 0, 1.0, true),
      (20, 80, .2, false),
    ]) {
      test('should show spendable progress at ${row.$1} coins', () {
        final p = RewardProgress.fromBalance(row.$1);
        expect(p.coinsNeeded, row.$2);
        expect(p.fraction, row.$3);
        expect(p.affordable, row.$4);
      });
    }
  });
}
