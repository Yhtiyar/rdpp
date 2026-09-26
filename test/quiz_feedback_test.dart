import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/local_store.dart';
import 'package:readapp/features/reading/book.dart';
import 'package:readapp/features/reading/quiz_screen.dart';
import 'package:readapp/ui/theme.dart';

class AnswerStore implements LocalStore {
  bool fail = false;
  Completer<void>? gate;
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    await gate?.future;
    if (fail) throw StateError('full disk');
    data = value;
  }
}

void main() {
  final book = Book.fromJson(
    (jsonDecode(
      File('assets/books/catalog.json').readAsStringSync(),
    ) as List).first,
  );
  final batch = book.batches.first;
  Future<AppController> show(WidgetTester t, AnswerStore store) async {
    t.view.physicalSize = const Size(430, 932);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = AppController(store)..sound = false;
    for (final p in batch.pageIndices) {
      await c.markRead(book, p);
    }
    await t.pumpWidget(
      MaterialApp(
        theme: WinTheme.data,
        home: QuizScreen(controller: c, book: book, batch: batch),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  group('Quiz feedback', () {
    testWidgets('should distinguish selection from saved correctness', (
      t,
    ) async {
      await show(t, AnswerStore());
      await tap(t, batch.questions.first.options[batch.questions.first.answer]);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await tap(t, 'Check answer');
      expect(find.textContaining('Correct!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(find.textContaining('Think back'), findsNothing);
      expect(find.textContaining('Attempts left:'), findsNothing);
    });
    testWidgets('should keep failed saves neutral', (t) async {
      final store = AnswerStore();
      final c = await show(t, store);
      store.fail = true;
      await tap(t, batch.questions.first.options[batch.questions.first.answer]);
      await tap(t, 'Check answer');
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.textContaining('Correct!'), findsNothing);
      expect(c.progressFor(book, batch).attempts, isEmpty);
    });
    testWidgets(
      'should submit once during delayed save and announce after commit',
      (t) async {
        final store = AnswerStore();
        final c = await show(t, store);
        await tap(
          t,
          batch.questions.first.options[batch.questions.first.answer],
        );
        store.gate = Completer<void>();
        await t.ensureVisible(find.text('Check answer'));
        await t.tap(find.text('Check answer'));
        await t.tap(find.text('Check answer'));
        await t.pump();
        expect(find.textContaining('Correct!'), findsNothing);
        store.gate!.complete();
        await t.pumpAndSettle();
        expect(c.progressFor(book, batch).attempts, [1, 0, 0, 0]);
        expect(find.textContaining('Correct!'), findsOneWidget);
      },
    );
  });
}
