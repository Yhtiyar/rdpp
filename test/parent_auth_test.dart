import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/parent_auth.dart';

void main() {
  group('ParentAuth', () {
    test('should validate and hash a six-digit PIN', () {
      final auth = ParentAuth();
      expect(() => auth.create('123'), throwsArgumentError);
      final recovery = auth.create('123456');
      expect(auth.verify('654321'), isFalse);
      expect(auth.verify('123456'), isTrue);
      expect(auth.toJson().toString(), isNot(contains('123456')));
      expect(recovery.length, 12);
      expect(ParentAuth.fromJson(auth.toJson()).verify('123456'), isTrue);
    });
    test('should persist cooldown and allow recovery without a bypass', () {
      var now = DateTime(2026, 9, 25, 12);
      final auth = ParentAuth(clock: () => now);
      final recovery = auth.create('234567');
      for (var i = 0; i < 5; i++) {
        auth.verify('000000');
      }
      expect(auth.verify('234567'), isFalse);
      expect(
        ParentAuth.fromJson(auth.toJson(), clock: () => now).locked,
        isTrue,
      );
      now = now.add(const Duration(minutes: 1));
      expect(auth.verify('234567'), isTrue);
      expect(auth.recover('NOT-A-CODE'), isFalse);
      expect(auth.recover(recovery), isTrue);
    });
  });
}
