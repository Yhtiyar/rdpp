import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/local_store.dart';
import 'package:readapp/core/screen_time_service.dart';

class MemoryStore implements LocalStore {
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    data = value;
  }
}

class FakeProtection implements ScreenTimeService {
  bool fail = false;
  Completer<void>? wait;
  int unlockCalls = 0;
  @override
  Future<ProtectionStatus> status() async =>
      const ProtectionStatus(authorized: true);
  @override
  Future<ProtectionStatus> authorize() => status();
  @override
  Future<ProtectionStatus> configureEssentials(String locale) => status();
  @override
  Future<DateTime> unlock({
    required int minutes,
    required String transactionId,
  }) async {
    unlockCalls++;
    if (wait != null) {
      await wait!.future;
    }
    if (fail) {
      throw StateError('Permission revoked');
    }
    return DateTime.now().add(Duration(minutes: minutes));
  }
}

void main() {
  group('AppController purchases', () {
    late AppController c;
    late FakeProtection platform;
    late MemoryStore store;
    setUp(() {
      store = MemoryStore();
      platform = FakeProtection();
      c = AppController(store, screenTime: platform);
      for (var i = 0; i < 10; i++) {
        c.reading.completePage('frog', i, DateTime.now());
      }
    });
    test(
      'should refund coins and allowance when native activation fails',
      () async {
        platform.fail = true;
        await expectLater(c.redeem(15), throwsStateError);
        expect(c.reading.balance, 100);
        expect(c.wallet.usedToday, 0);
        final reloaded = AppController(store, screenTime: platform);
        await reloaded.load();
        expect(reloaded.reading.balance, 100);
      },
    );
    test('should serialize double taps and only debit once', () async {
      platform.wait = Completer<void>();
      final first = c.redeem(15);
      await expectLater(c.redeem(15), throwsStateError);
      platform.wait!.complete();
      await first;
      expect(platform.unlockCalls, 1);
      expect(c.reading.balance, 0);
      expect(c.wallet.usedToday, 15);
    });
  });
}
