import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/local_store.dart';
import 'package:readapp/features/reading/book.dart';
import 'package:readapp/features/reading/quiz_screen.dart';
import 'package:readapp/features/reading/reader_screen.dart';
import 'package:readapp/ui/theme.dart';

class MemoryStore implements LocalStore {
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> value) async => data = value;
}

void main() {
  final books = (jsonDecode(
    File('assets/books/catalog.json').readAsStringSync(),
  ) as List).map((j) => Book.fromJson(j as Map<String, dynamic>)).toList();

  Future<void> showReader(
    WidgetTester tester,
    AppController controller,
    Book book,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: WinTheme.data,
        home: ReaderScreen(controller: controller, book: book),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ReaderScreen', () {
    for (final lastPage in [3, 6]) {
      testWidgets(
        'should wait for Start test when page $lastPage fits on screen',
        (tester) async {
          final book = books.last;
          final controller = AppController(MemoryStore());
          for (var p = 0; p < lastPage - 3; p++) {
            controller.reading.completePage(book.id, p, DateTime.now());
          }
          for (var p = lastPage - 3; p < lastPage - 1; p++) {
            await controller.markRead(book, p);
          }
          await controller.savePosition(book, lastPage - 1);
          await showReader(tester, controller, book, const Size(1365, 900));
          await tester.pump(const Duration(seconds: 5));

          expect(find.byType(QuizScreen), findsNothing);
          expect(find.text('Page $lastPage of 9'), findsOneWidget);
          await tester.tap(find.text('Start test'));
          await tester.pumpAndSettle();
          expect(find.byType(QuizScreen), findsOneWidget);
        },
      );
    }

    testWidgets(
      'should keep a long batch-ending page open after scrolling to its end',
      (tester) async {
        final book = books.first;
        final controller = AppController(MemoryStore());
        await controller.markRead(book, 0);
        await controller.markRead(book, 1);
        await controller.savePosition(book, 2);
        await showReader(tester, controller, book, const Size(430, 932));
        expect(find.byType(QuizScreen), findsNothing);
        expect(find.text('Start test'), findsNothing);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -4000),
        );
        await tester.pumpAndSettle();
        expect(find.byType(QuizScreen), findsNothing);
        expect(find.text('Page 3 of 13'), findsOneWidget);
        await tester.tap(find.text('Start test'));
        await tester.pumpAndSettle();
        expect(find.byType(QuizScreen), findsOneWidget);
      },
    );

    testWidgets(
      'should not mark an incoming long page from outgoing short metrics',
      (tester) async {
        final original = books.first;
        final book = Book(
          id: original.id,
          title: original.title,
          author: original.author,
          language: original.language,
          attribution: original.attribution,
          original: original.original,
          cover: original.cover,
          batches: original.batches,
          pages: [
            const BookPage(text: 'A short page.', sourcePage: 1),
            BookPage(
              text: List.filled(
                120,
                'A very long page needs scrolling.',
              ).join(' '),
              sourcePage: 2,
            ),
            ...original.pages.skip(2),
          ],
        );
        final c = AppController(MemoryStore());
        await showReader(tester, c, book, const Size(430, 932));
        expect(c.progressFor(book, book.batches.first).readPages, {0});
        await tester.tap(find.text('Next page'));
        await tester.pumpAndSettle();
        expect(c.progressFor(book, book.batches.first).readPages, {0});
        expect(find.text('Read to the end of this page'), findsOneWidget);
        expect(find.byType(QuizScreen), findsNothing);
      },
    );

    testWidgets(
      'should wait for Continue test when reopening an unfinished quiz',
      (tester) async {
        final book = books.first;
        final batch = book.batches.first;
        final store = MemoryStore();
        final previous = AppController(store);
        for (var p = 0; p < 3; p++) {
          await previous.markRead(book, p);
        }
        await previous.answerBatch(
          book,
          batch,
          0,
          (batch.questions[0].answer + 1) % 4,
        );
        await previous.savePosition(book, 1);
        final restored = AppController(store);
        await restored.load();
        await showReader(tester, restored, book, const Size(430, 932));

        expect(find.byType(QuizScreen), findsNothing);
        expect(find.text('Page 2 of 13'), findsOneWidget);
        await tester.tap(find.text('Continue test'));
        await tester.pumpAndSettle();
        expect(find.byType(QuizScreen), findsOneWidget);
        expect(find.textContaining('Attempts left: 1 of 2'), findsOneWidget);
      },
    );
  });
}
