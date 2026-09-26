import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/screen_time_service.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceScreenTimeService preview', () {
    test(
      'should allow simulated rewards without native authorization',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const channel = MethodChannel('littlewins/screen_time');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (call) async => call.method == 'unlock'
                  ? {
                      'endsAt': DateTime.now()
                          .add(const Duration(minutes: 15))
                          .millisecondsSinceEpoch,
                    }
                  : {'preview': true, 'supported': false, 'authorized': false},
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final service = DeviceScreenTimeService();
        for (final status in [
          await service.status(),
          await service.authorize(),
          await service.configureEssentials('en'),
        ]) {
          expect(status.preview, isTrue);
          expect(status.supported, isFalse);
          expect(status.authorized, isFalse);
        }
        final controller = AppController(_MemoryStore(), screenTime: service);
        for (var page = 0; page < 10; page++) {
          controller.reading.completePage('book', page, DateTime.now());
        }
        await controller.redeem(15);
        expect(controller.reading.balance, 0);
        expect(controller.wallet.usedToday, 15);
        expect(controller.wallet.remaining.inSeconds, greaterThan(890));
        expect(controller.protection.authorized, isFalse);
        expect(controller.protection.preview, isTrue);
      },
    );
  });
}

class _MemoryStore implements LocalStore {
  @override
  Future<Map<String, dynamic>?> read() async => null;
  @override
  Future<void> write(Map<String, dynamic> value) async {}
}
