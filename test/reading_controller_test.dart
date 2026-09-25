import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/local_store.dart';
import 'package:readapp/features/reading/book.dart';

class MemoryStore implements LocalStore {
  Map<String, dynamic>? value;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (fail) {
      throw StateError('Full disk');
    }
    value = data;
  }
}

void main() {
  group('AppController reading', () {
    final book = Book.fromJson(
      (jsonDecode(
            File('assets/books/catalog.json').readAsStringSync(),
          ) as List).first
          as Map<String, dynamic>,
    );
    test(
      'should require reading to the end and the correct answer before credit',
      () async {
        final c = AppController(MemoryStore());
        expect(await c.answerPage(book, 0, 1), -1);
        c.markRead(book, 0);
        expect(await c.answerPage(book, 0, 0), -1);
        expect(c.reading.balance, 0);
        expect(await c.answerPage(book, 0, 1), 10);
        expect(await c.answerPage(book, 0, 1), 0);
        expect(c.reading.balance, 10);
      },
    );
    test(
      'should preserve an already-earned page when storage is unavailable',
      () async {
        final store = MemoryStore();
        final c = AppController(store);
        c.markRead(book, 0);
        expect(await c.answerPage(book, 0, 1), 10);
        store.fail = true;
        expect(await c.answerPage(book, 0, 1), 0);
        expect(c.reading.balance, 10);
        expect(c.reading.isComplete(book.id, 0), true);
      },
    );
    test('should roll back reward when local storage fails', () async {
      final store = MemoryStore()..fail = true;
      final c = AppController(store);
      c.markRead(book, 0);
      await expectLater(c.answerPage(book, 0, 1), throwsStateError);
      expect(c.reading.balance, 0);
      expect(c.reading.isComplete(book.id, 0), false);
    });
  });
}
