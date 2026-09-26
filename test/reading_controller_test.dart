import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/batch_progress.dart';
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
  group('AppController batch reading', () {
    final book = Book.fromJson(
      (jsonDecode(
            File('assets/books/catalog.json').readAsStringSync(),
          ) as List).first
          as Map<String, dynamic>,
    );
    final batch = book.batches.first;
    Future<void> read(AppController c, BookBatch b) async {
      for (final page in b.pageIndices) {
        await c.markRead(book, page);
      }
    }

    Future<BatchAnswerResult> pass(AppController c, BookBatch b) async {
      late BatchAnswerResult result;
      for (var q = 0; q < b.questions.length; q++) {
        result = await c.answerBatch(book, b, q, b.questions[q].answer);
      }
      return result;
    }

    test(
      'should gate skipping and award a batch only after all questions pass',
      () async {
        final c = AppController(MemoryStore());
        expect(c.canOpenPage(book, 2), isFalse);
        await c.markRead(book, 2);
        expect(c.batchReady(book, batch), isFalse);
        await expectLater(
          c.answerBatch(book, batch, 0, batch.questions[0].answer),
          throwsStateError,
        );
        await read(c, batch);
        expect(c.canOpenPage(book, 3), isFalse);
        for (var q = 0; q < 3; q++) {
          await c.answerBatch(book, batch, q, batch.questions[q].answer);
          expect(c.reading.balance, 0);
        }
        final result = await c.answerBatch(
          book,
          batch,
          3,
          batch.questions[3].answer,
        );
        expect(result.coins, 30);
        expect(c.reading.completedCount(book.id), 3);
        expect(c.canOpenPage(book, 3), isTrue);
        await expectLater(
          c.answerBatch(book, batch, 3, batch.questions[3].answer),
          throwsStateError,
        );
        expect(c.reading.balance, 30);
      },
    );

    test(
      'should preserve errors across restart and reset only the current batch',
      () async {
        final store = MemoryStore();
        var c = AppController(store);
        await read(c, batch);
        await pass(c, batch);
        final next = book.batches[1];
        await read(c, next);
        final wrong = (next.questions[0].answer + 1) % 4;
        await c.answerBatch(book, next, 0, wrong);
        c = AppController(store);
        await c.load();
        expect(c.progressFor(book, next).attemptsLeft, 1);
        expect(
          (await c.answerBatch(book, next, 0, wrong)).outcome,
          BatchAnswerOutcome.exhausted,
        );
        await expectLater(
          c.answerBatch(book, next, 0, next.questions[0].answer),
          throwsStateError,
        );
        final result = await c.answerBatch(
          book,
          next,
          1,
          (next.questions[1].answer + 1) % 4,
        );
        expect(result.outcome, BatchAnswerOutcome.reset);
        expect(c.reading.position(book.id), 3);
        expect(c.reading.balance, 30);
        expect(c.canOpenPage(book, 5), isFalse);
        expect(c.batchReady(book, next), isFalse);
        c = AppController(store);
        await c.load();
        expect(c.progressFor(book, next).needsReread, isTrue);
        await expectLater(
          c.answerBatch(book, next, 0, next.questions[0].answer),
          throwsStateError,
        );
        await read(c, next);
        expect((await pass(c, next)).coins, 30);
        expect(c.reading.balance, 60);
      },
    );

    test(
      'should not expose readiness or lose rollback during a failed page save',
      () async {
        final store = DelayedFailureStore();
        final c = AppController(store);
        await c.markRead(book, 0);
        await c.markRead(book, 1);
        final gate = Completer<void>();
        store.pause = gate;
        final marking = c.markRead(book, 2);
        final failedMark = expectLater(marking, throwsStateError);
        // Simulate an unrelated settings snapshot queued while the write is pending.
        final queuedSave = c.save();
        final readyWhileSaving = c.batchReady(book, batch);
        final answer = c.answerBatch(book, batch, 0, batch.questions[0].answer);
        final blockedAnswer = expectLater(answer, throwsStateError);
        gate.complete();
        await failedMark;
        await blockedAnswer;
        await queuedSave;
        expect(readyWhileSaving, isFalse);
        expect(c.batchReady(book, batch), isFalse);
        final restored = AppController(store);
        await restored.load();
        expect(restored.batchReady(book, batch), isFalse);
        expect(restored.progressFor(book, batch).readPages, {0, 1});
        expect(restored.progressFor(book, batch).attempts, isEmpty);
      },
    );

    test(
      'should preserve old page credits and only reward missing pages',
      () async {
        final c = AppController(MemoryStore());
        c.reading.completePage(book.id, 0, DateTime.now());
        await read(c, batch);
        expect((await pass(c, batch)).coins, 20);
        expect(c.reading.balance, 30);
      },
    );

    test('should quiz and reward the final shorter batch', () async {
      final c = AppController(MemoryStore());
      for (var p = 0; p < 12; p++) {
        c.reading.completePage(book.id, p, DateTime.now());
      }
      final last = book.batches.last;
      await read(c, last);
      expect((await pass(c, last)).coins, 10);
      expect(c.pendingBatch(book), isNull);
      expect(c.reading.totalPages, 13);
    });

    test(
      'should roll back credit and quiz advancement on failed saves',
      () async {
        final store = MemoryStore();
        final c = AppController(store);
        await read(c, batch);
        for (var q = 0; q < 3; q++) {
          await c.answerBatch(book, batch, q, batch.questions[q].answer);
        }
        store.fail = true;
        await expectLater(
          c.answerBatch(book, batch, 3, batch.questions[3].answer),
          throwsStateError,
        );
        expect(c.reading.balance, 0);
        expect(c.progressFor(book, batch).questionIndex, 3);
        store.fail = false;
        expect(
          (await c.answerBatch(
            book,
            batch,
            3,
            batch.questions[3].answer,
          )).coins,
          30,
        );
      },
    );
  });
}

class DelayedFailureStore extends MemoryStore {
  Completer<void>? pause;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    final current = pause;
    if (current != null) {
      pause = null;
      await current.future;
      throw StateError('Temporary disk error');
    }
    await super.write(data);
  }
}
