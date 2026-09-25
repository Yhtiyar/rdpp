import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/features/reading/book.dart';

void main() {
  group('BookCatalog', () {
    test(
      'should bundle both complete stories with one grounded quiz per page',
      () {
        final books =
            (jsonDecode(File('assets/books/catalog.json').readAsStringSync())
                    as List)
                .map((j) => Book.fromJson(j as Map<String, dynamic>))
                .toList();
        expect(books.map((b) => b.language), containsAll(['en', 'ru']));
        expect(books.first.pages.length, 13);
        expect(books.last.pages.length, 9);
        expect(books.first.pages.last.text, contains('happily ever after'));
        expect(books.last.pages.last.text, contains('скушала'));
        for (final book in books) {
          expect(book.attribution, isNotEmpty);
          for (final page in book.pages) {
            expect(page.text.length, greaterThan(60));
            expect(page.question.options.length, 3);
            expect(page.question.answer, inInclusiveRange(0, 2));
            expect(page.question.hint, isNotEmpty);
            if (page.image != null) {
              expect(File(page.image!).existsSync(), isTrue);
            }
          }
        }
      },
    );
  });
}
