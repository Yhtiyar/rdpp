import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/features/reading/book.dart';

void main() {
  group('BookCatalog', () {
    test('bundles every supplied story with consecutive reading quizzes', () {
      final books = (jsonDecode(
        File('assets/books/catalog.json').readAsStringSync(),
      ) as List).map((j) => Book.fromJson(j as Map<String, dynamic>)).toList();
      expect(books.map((b) => b.language), containsAll(['en', 'ru']));
      expect(books.map((b) => b.id).toSet(), {
        'frog',
        'kolobok',
        'aibolit',
        'ugly-duckling',
        'little-red-riding-hood',
        'turnip',
        'teremok',
        'frog-princess',
        'lion-and-mouse',
        'city-and-country-mouse',
        'goldilocks',
        'gingerbread-man',
        'shoemaker-and-elves',
        'little-red-hen',
        'thumbelina',
        'turtle-shell',
        'why-flies-buzz',
        'three-little-pigs',
      });
      expect(books.map((b) => b.id).toSet().length, books.length);
      final frog = books.singleWhere((b) => b.id == 'frog');
      final kolobok = books.singleWhere((b) => b.id == 'kolobok');
      expect(frog.pages.length, 13);
      expect(kolobok.pages.length, 9);
      expect(frog.pages.last.text, contains('happily ever after'));
      expect(kolobok.pages.last.text, contains('скушала'));
      for (final book in books) {
        expect(book.attribution, isNotEmpty);
        expect(File(book.original).existsSync(), isTrue, reason: book.id);
        expect(File(book.cover).existsSync(), isTrue, reason: book.id);
        expect(book.pages, isNotEmpty);
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
          expect(page.text.trim(), isNotEmpty);
          expect(page.sourcePage, greaterThan(0));
          if (page.image != null) {
            expect(File(page.image!).existsSync(), isTrue);
          }
        }
      }
    });
  });
}
