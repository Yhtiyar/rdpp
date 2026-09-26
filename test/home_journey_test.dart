import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/features/reading/book.dart';

import 'reader_screen_test.dart' show MemoryStore;

void main() {
  final books = (jsonDecode(
    File('assets/books/catalog.json').readAsStringSync(),
  ) as List).map((j) => Book.fromJson(j)).toList();
  AppController controller(MemoryStore s) => AppController(s)..books = books;
  group('Home journey', () {
    test('should fall back by locale without old preference data', () async {
      final store = MemoryStore()..data = {'locale': 'ru'};
      final c = controller(store);
      await c.load();
      expect(c.lastOpenedBookId, isNull);
      expect(c.journeyBook?.id, books.last.id);
    });
    test('should remember interrupted English reading under Russian UI without credit', () async {
      final store = MemoryStore();
      final c = controller(store);
      await c.rememberBook(books.first.id);
      await c.markRead(books.first, 0);
      await c.setLocale('ru');
      final restored = controller(store);
      await restored.load();
      expect(restored.journeyBook?.id, books.first.id);
      expect(restored.reading.balance, 0);
      expect(
        restored.progressFor(books.first, books.first.batches.first).readPages,
        {0},
      );
    });
    test(
      'should choose an unfinished book before offering completed rereading',
      () async {
        final c = controller(MemoryStore());
        for (final p in books.first.pages.asMap().keys) {
          c.reading.completePage(books.first.id, p, DateTime.now());
        }
        expect(c.journeyBook?.id, books.last.id);
        for (final p in books.last.pages.asMap().keys) {
          c.reading.completePage(books.last.id, p, DateTime.now());
        }
        expect(c.journeyBook?.id, books.first.id);
        await c.rememberBook(books.last.id);
        expect(c.journeyBook?.id, books.last.id);
        expect(c.reading.balance, 220);
      },
    );
  });
}
