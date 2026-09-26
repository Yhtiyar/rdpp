import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/screen_time_service.dart';
import 'package:readapp/features/reading/book.dart';
import 'package:readapp/features/rewards/reward_message.dart';
import 'package:readapp/features/rewards/wallet_screen.dart';

import 'package:readapp/core/time_wallet.dart';

import 'purchase_test.dart' show FakeProtection;
import 'reader_screen_test.dart' show MemoryStore;

void main() {
  final books = (jsonDecode(
    File('assets/books/catalog.json').readAsStringSync(),
  ) as List).map((j) => Book.fromJson(j)).toList();
  AppController earned(int pages, {int spent = 0}) {
    final c = AppController(MemoryStore())
      ..books = books
      ..sound = false;
    var left = pages;
    for (final b in books) {
      for (var i = 0; i < b.pages.length && left > 0; i++, left--) {
        c.reading.completePage(b.id, i, DateTime.now());
      }
    }
    c.reading.spentCoins = spent;
    return c;
  }

  group('Reward availability', () {
    test('should acknowledge remaining earning even when another window is unreachable', () {
      final c = earned(21, spent: 200);
      expect(rewardMessage(c), contains('1 new page'));
      expect(rewardMessage(c), isNot(contains('won’t earn more coins')));
      expect(reachableDurations(c), isEmpty);
    });
    test('should distinguish balance, allowance, preview and permission', () {
      final c = earned(12)..dailyLimit = 0;
      expect(rewardMessage(c), contains('allowance is used'));
      c.dailyLimit = 60;
      c.protection = const ProtectionStatus(preview: true);
      expect(rewardMessage(c), contains('preview'));
      c.protection = const ProtectionStatus(authorized: false);
      expect(rewardMessage(c), contains('parent'));
      c.protection = const ProtectionStatus(authorized: true);
      expect(rewardMessage(c), contains('enough coins'));
      expect(reachableDurations(earned(0)), [15, 30]);
    });
    testWidgets(
      'should stop claiming time is ready when a confirmed timer expires',
      (t) async {
        var now = DateTime.now();
        final c = AppController(MemoryStore(), screenTime: FakeProtection())
          ..books = books
          ..sound = false
          ..wallet = TimeWallet(clock: () => now);
        for (var i = 0; i < 12; i++) {
          c.reading.completePage(books.first.id, i, now);
        }
        await t.pumpWidget(MaterialApp(home: WalletScreen(controller: c)));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Use 15 minutes'));
        await t.tap(find.text('Use 15 minutes'));
        await t.pumpAndSettle();
        await t.tap(find.text('Start my time'));
        await t.pumpAndSettle();
        expect(find.text('Your playtime is ready'), findsOneWidget);
        now = now.add(const Duration(minutes: 16));
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(find.text('Your playtime is ready'), findsNothing);
        expect(find.text('Your wins, your time'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'should remove impossible purchase action and earning promise after catalog completion',
      (t) async {
        final c = earned(22, spent: 200);
        await t.pumpWidget(MaterialApp(home: WalletScreen(controller: c)));
        await t.pumpAndSettle();
        expect(find.textContaining('Read a little more'), findsNothing);
        expect(find.text('Use 15 minutes'), findsNothing);
        expect(find.textContaining('Reread for fun'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
    );
  });
}
