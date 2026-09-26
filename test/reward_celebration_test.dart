import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:readapp/core/app_controller.dart';
import 'package:readapp/features/reading/book.dart';
import 'package:readapp/features/reading/quiz_screen.dart';

import 'quiz_feedback_test.dart' show AnswerStore;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/features/rewards/reward_celebration.dart';

void main() {
  group('RewardCelebration', () {
    testWidgets(
      'should not celebrate a failed award or duplicate a delayed award',
      (t) async {
        final book = Book.fromJson(
          (jsonDecode(
            File('assets/books/catalog.json').readAsStringSync(),
          ) as List).first,
        );
        final batch = book.batches.first;
        final store = AnswerStore();
        final c = AppController(store)
          ..sound = false
          ..books = [book];
        for (final p in batch.pageIndices) {
          await c.markRead(book, p);
        }
        for (var i = 0; i < 3; i++) {
          await c.answerBatch(book, batch, i, batch.questions[i].answer);
        }
        await t.pumpWidget(
          MaterialApp(
            home: QuizScreen(controller: c, book: book, batch: batch),
          ),
        );
        await t.pumpAndSettle();
        final option = find.text(
          batch.questions.last.options[batch.questions.last.answer],
        );
        await t.ensureVisible(option);
        await t.tap(option);
        await t.pumpAndSettle();
        store.fail = true;
        await t.ensureVisible(find.text('Check answer'));
        await t.tap(find.text('Check answer'));
        await t.pumpAndSettle();
        expect(find.byType(RewardCelebration), findsNothing);
        expect(c.reading.balance, 0);
        store.fail = false;
        store.gate = Completer<void>();
        await t.ensureVisible(find.text('Check answer'));
        await t.tap(find.text('Check answer'));
        await t.tap(find.text('Check answer'));
        await t.pump();
        expect(find.byType(RewardCelebration), findsNothing);
        store.gate!.complete();
        await t.pumpAndSettle();
        expect(find.byType(RewardCelebration), findsOneWidget);
        expect(c.reading.balance, 30);
        await t.pumpWidget(const SizedBox());
        final restored = AppController(store);
        await restored.load();
        expect(restored.reading.balance, 30);
      },
    );

    testWidgets(
      'should show committed values immediately and allow leaving during motion',
      (t) async {
        var left = 0;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RewardCelebration(
                  coinsEarned: 30,
                  balanceBefore: 90,
                  balanceAfter: 120,
                  bookCompleted: false,
                  newlyReachedMilestones: const [10],
                  title: 'The Frog Prince',
                  nextMessage: 'Enough coins for 15 minutes',
                  onContinue: () => left++,
                  onBooks: () => left++,
                ),
              ),
            ),
          ),
        );
        expect(find.text('+30 coins'), findsOneWidget);
        expect(find.text('Saved balance: 120 coins'), findsOneWidget);
        await t.ensureVisible(find.text('Keep reading'));
        await t.tap(find.text('Keep reading'));
        expect(left, 1);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 2));
        expect(t.takeException(), isNull);
      },
    );
    testWidgets('should not replay count-up when locale changes', (t) async {
      Widget build(String locale) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RewardCelebration(
              coinsEarned: 30,
              balanceBefore: 90,
              balanceAfter: 120,
              bookCompleted: true,
              newlyReachedMilestones: const [],
              title: 'The Frog Prince',
              locale: locale,
              nextMessage: '',
              onContinue: () {},
              onBooks: () {},
            ),
          ),
        ),
      );
      await t.pumpWidget(build('en'));
      await t.pumpAndSettle();
      await t.pumpWidget(build('ru'));
      await t.pump();
      expect(find.text('120'), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
    });
  });
}
