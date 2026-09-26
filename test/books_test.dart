import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/features/reading/book.dart';

void main() {
  group('BookCatalog', () {
    test('should bundle both complete stories with four-option quizzes covering consecutive three-page batches', () {
      final books = (jsonDecode(
        File('assets/books/catalog.json').readAsStringSync(),
      ) as List).map((j) => Book.fromJson(j as Map<String, dynamic>)).toList();
      expect(books.map((b) => b.language), containsAll(['en', 'ru']));
      expect(books.first.pages.length, 13);
      expect(books.last.pages.length, 9);
      expect(books.first.pages.last.text, contains('happily ever after'));
      expect(books.last.pages.last.text, contains('скушала'));
      for (final book in books) {
        expect(book.attribution, isNotEmpty);
        var expectedStart = 0;
        for (final batch in book.batches) {
          expect(batch.startPage, expectedStart);
          expect(batch.pageCount, inInclusiveRange(1, 3));
          expect(batch.questions.length, inInclusiveRange(4, 5));
          for (final q in batch.questions) {
            expect(q.options.length, greaterThanOrEqualTo(4));
            expect(q.options.toSet().length, q.options.length);
            expect(q.answer, inInclusiveRange(0, q.options.length - 1));
            expect(q.hint, isNotEmpty);
            expect(q.explanation.trim(), isNotEmpty);
          }
          expectedStart = batch.endPage;
        }
        expect(expectedStart, book.pages.length);
        for (final page in book.pages) {
          expect(page.text.length, greaterThan(60));
          if (page.image != null) {
            expect(File(page.image!).existsSync(), isTrue);
          }
        }
      }
    });
  });
}
