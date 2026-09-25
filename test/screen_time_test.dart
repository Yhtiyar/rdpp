import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/time_wallet.dart';

void main() {
  group('TimeWallet', () {
    test(
      'should reject insufficient coins and purchases above the daily cap',
      () async {
        final wallet = TimeWallet(clock: () => DateTime(2026, 9, 25, 12));
        expect(
          wallet.problem(minutes: 15, balance: 90, dailyLimit: 60),
          'coins',
        );
        expect(
          wallet.problem(minutes: 30, balance: 300, dailyLimit: 15),
          'limit',
        );
        expect(
          wallet.problem(minutes: 20, balance: 300, dailyLimit: 60),
          'duration',
        );
      },
    );
    test(
      'should preserve expiry and daily usage through restart and midnight',
      () async {
        var now = DateTime(2026, 9, 25, 23, 50);
        final wallet = TimeWallet(clock: () => now);
        wallet.record(
          minutes: 15,
          endsAt: now.add(const Duration(minutes: 15)),
        );
        final restored = TimeWallet.fromJson(wallet.toJson(), clock: () => now);
        expect(restored.remaining.inMinutes, 15);
        expect(restored.usedToday, 15);
        now = DateTime(2026, 9, 26, 0, 0);
        expect(restored.usedToday, 0);
        expect(restored.remaining.inMinutes, 5);
        now = now.add(const Duration(minutes: 6));
        expect(restored.remaining, Duration.zero);
      },
    );
    test('should reject adding time to an active window', () {
      final now = DateTime(2026, 9, 25, 12);
      final wallet = TimeWallet(clock: () => now)
        ..record(minutes: 15, endsAt: now.add(const Duration(minutes: 15)));
      expect(
        wallet.problem(minutes: 15, balance: 100, dailyLimit: 60),
        'active',
      );
    });
  });
}
