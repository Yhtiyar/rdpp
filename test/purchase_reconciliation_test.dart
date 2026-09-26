import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:readapp/features/reading/book.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/screen_time_service.dart';

import 'purchase_test.dart' show MemoryStore;

class AmbiguousProtection implements ScreenTimeService {
  String? receipt;
  DateTime? expiry;
  bool statusUnavailable = false;
  bool failAfterActivation = true;
  @override
  Future<ProtectionStatus> status() async {
    if (statusUnavailable && receipt != null) {
      throw StateError('Native process unavailable');
    }
    return ProtectionStatus(
      authorized: true,
      transactionId: receipt,
      endsAt: expiry,
    );
  }

  @override
  Future<ProtectionStatus> authorize() => status();
  @override
  Future<ProtectionStatus> configureEssentials(String locale) => status();
  @override
  Future<DateTime> unlock({
    required int minutes,
    required String transactionId,
  }) async {
    receipt = transactionId;
    expiry = DateTime.now().add(Duration(minutes: minutes));
    if (failAfterActivation) {
      throw StateError('Reply lost after activation');
    }
    return expiry!;
  }
}

void main() {
  group('Purchase reconciliation', () {
    test(
      'should keep debit when native activation succeeds but its reply fails',
      () async {
        final platform = AmbiguousProtection();
        final c = AppController(MemoryStore(), screenTime: platform);
        for (var i = 0; i < 10; i++) {
          c.reading.completePage('frog', i, DateTime.now());
        }
        await c.redeem(15);
        expect(c.reading.balance, 0);
        expect(c.wallet.usedToday, 15);
        expect(c.pendingPurchase, isNull);
      },
    );
    test(
      'should retain pending debit until an ambiguous outcome can be checked',
      () async {
        final store = MemoryStore();
        final platform = AmbiguousProtection()..statusUnavailable = true;
        final c = AppController(store, screenTime: platform);
        for (var i = 0; i < 10; i++) {
          c.reading.completePage('frog', i, DateTime.now());
        }
        await expectLater(c.redeem(15), throwsStateError);
        expect(c.reading.balance, 0);
        expect(c.pendingPurchase, isNotNull);
        final restored = AppController(store, screenTime: platform);
        await restored.load();
        platform.statusUnavailable = false;
        await restored.refreshProtection();
        expect(restored.reading.balance, 0);
        expect(restored.wallet.usedToday, 15);
        expect(restored.pendingPurchase, isNull);
        await restored.refreshProtection();
        expect(restored.wallet.usedToday, 15);
      },
    );
    test(
      'should not purchase while a reading credit is being persisted',
      () async {
        final store = DelayedStore();
        final platform = AmbiguousProtection()..failAfterActivation = false;
        final c = AppController(store, screenTime: platform);
        for (var i = 0; i < 10; i++) {
          c.reading.completePage('frog', i, DateTime.now());
        }
        final book = Book.fromJson(
          (jsonDecode(
                File('assets/books/catalog.json').readAsStringSync(),
              ) as List).first
              as Map<String, dynamic>,
        );
        final batch = book.batches[3];
        for (final page in batch.pageIndices) {
          await c.markRead(book, page);
        }
        for (var q = 0; q < 3; q++) {
          await c.answerBatch(book, batch, q, batch.questions[q].answer);
        }
        store.delay = true;
        final answer = c.answerBatch(book, batch, 3, batch.questions[3].answer);
        await expectLater(c.redeem(15), throwsStateError);
        store.pending.complete();
        await answer;
        expect(c.reading.balance, 120);
        expect(platform.receipt, isNull);
      },
    );
  });
}

class DelayedStore extends MemoryStore {
  final pending = Completer<void>();
  bool delay = false;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (delay) {
      await pending.future;
    }
    await super.write(value);
  }
}
