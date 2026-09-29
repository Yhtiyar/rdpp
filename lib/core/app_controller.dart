import 'package:flutter/foundation.dart';

import 'local_store.dart';
import 'batch_progress.dart';
import 'parent_auth.dart';
import 'reading_ledger.dart';
import 'time_wallet.dart';
import 'screen_time_service.dart';
import '../features/reading/book.dart';

class AppController extends ChangeNotifier {
  AppController(this.store, {ScreenTimeService? screenTime})
    : screenTime = screenTime ?? DeviceScreenTimeService();
  final LocalStore store;
  final ScreenTimeService screenTime;
  ProtectionStatus protection = const ProtectionStatus(supported: false);
  TimeWallet wallet = TimeWallet();
  Map<String, dynamic>? pendingPurchase;
  bool purchasing = false;
  List<Book> books = [];
  ReadingLedger reading = ReadingLedger();
  final Map<String, BatchProgress> _batchProgress = {};
  double textSize = 20;
  bool _answering = false;
  bool _markingRead = false;
  ParentAuth auth = ParentAuth();
  String locale = 'en';
  String? lastOpenedBookId;
  int age = 7;
  bool onboarded = false;
  bool sound = true;
  int dailyLimit = 60;
  String? error;
  Future<void> _pending = Future.value();
  String tr(String en, String ru) => locale == 'ru' ? ru : en;
  Future<void> load() async {
    final data = await store.read();
    if (data != null) {
      lastOpenedBookId = data['lastOpenedBookId'] as String?;
      locale = data['locale'] as String? ?? 'en';
      age = data['age'] as int? ?? 7;
      onboarded = data['onboarded'] as bool? ?? false;
      sound = data['sound'] as bool? ?? true;
      dailyLimit = data['dailyLimit'] as int? ?? 60;
      auth = ParentAuth.fromJson(
        Map<String, dynamic>.from(data['auth'] as Map? ?? {}),
      );
      restoreFeatures(data);
    }
  }

  void restoreFeatures(Map<String, dynamic> data) {
    reading = ReadingLedger.fromJson(
      Map<String, dynamic>.from(data['reading'] as Map? ?? {}),
    );
    wallet = TimeWallet.fromJson(
      Map<String, dynamic>.from(data['wallet'] as Map? ?? {}),
    );
    pendingPurchase = data['pendingPurchase'] == null
        ? null
        : Map<String, dynamic>.from(data['pendingPurchase'] as Map);
    textSize = (data['textSize'] as num?)?.toDouble() ?? 20;
    _batchProgress.clear();
    final sessions = Map<String, dynamic>.from(
      data['batchProgress'] as Map? ?? {},
    );
    for (final entry in sessions.entries) {
      _batchProgress[entry.key] = BatchProgress.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
  }

  Book? get journeyBook {
    final remembered = books.where((b) => b.id == lastOpenedBookId).firstOrNull;
    if (remembered != null) return remembered;
    final unfinished = books.where((b) => pendingBatch(b) != null);
    return unfinished.where((b) => b.language == locale).firstOrNull ??
        unfinished.firstOrNull ??
        books.where((b) => b.language == locale).firstOrNull ??
        books.firstOrNull;
  }

  Future<void> rememberBook(String bookId) async {
    if (!books.any((b) => b.id == bookId)) {
      throw ArgumentError.value(bookId, 'bookId');
    }
    final previous = lastOpenedBookId;
    lastOpenedBookId = bookId;
    try {
      await save();
    } catch (_) {
      lastOpenedBookId = previous;
      try {
        await save();
      } catch (_) {
        /* Preserve the original storage failure. */
      }
      rethrow;
    }
  }

  BookBatch? pendingBatch(Book book) {
    for (final batch in book.batches) {
      if (!batch.pageIndices.every(
        (page) => reading.isComplete(book.id, page),
      )) {
        return batch;
      }
    }
    return null;
  }

  BatchProgress progressFor(Book book, BookBatch batch) => _batchProgress
      .putIfAbsent('${book.id}:${batch.startPage}', BatchProgress.new);

  bool batchReady(Book book, BookBatch batch) =>
      !_markingRead &&
      batch.pageIndices.every(progressFor(book, batch).readPages.contains);

  bool canOpenPage(Book book, int page) {
    if (page < 0 || page >= book.pages.length) {
      return false;
    }
    final batch = pendingBatch(book);
    if (batch == null) {
      return true;
    }
    final progress = progressFor(book, batch);
    final furthest = batch.pageIndices.firstWhere(
      (p) => !progress.readPages.contains(p),
      orElse: () => batch.endPage - 1,
    );
    return page <= furthest;
  }

  Future<void> savePosition(Book book, int page) async {
    if (_markingRead) {
      throw StateError('busy');
    }
    if (!canOpenPage(book, page)) {
      throw StateError('Finish the current section first.');
    }
    reading.savePosition(book.id, page);
    await save();
  }

  Future<void> markRead(Book book, int page) async {
    if (_markingRead) {
      throw StateError('busy');
    }
    final batch = pendingBatch(book);
    if (_answering ||
        batch == null ||
        page < batch.startPage ||
        page >= batch.endPage ||
        !canOpenPage(book, page)) {
      return;
    }
    final progress = progressFor(book, batch);
    if (progress.readPages.contains(page)) {
      return;
    }
    final before = progress.toJson();
    _markingRead = true;
    progress.readPages.add(page);
    progress.needsReread = false;
    try {
      await save();
    } catch (_) {
      _batchProgress['${book.id}:${batch.startPage}'] = BatchProgress.fromJson(
        before,
      );
      // An unrelated save may have queued the optimistic read marker. Ensure
      // the rollback follows those writes instead of resurrecting it on reload.
      try {
        await save();
      } catch (_) {
        /* Preserve the storage error. */
      }
      notifyListeners();
      rethrow;
    } finally {
      _markingRead = false;
      notifyListeners();
    }
  }

  Future<BatchAnswerResult> answerBatch(
    Book book,
    BookBatch batch,
    int questionIndex,
    int answer,
  ) async {
    if (_answering || _markingRead || purchasing || pendingPurchase != null) {
      throw StateError('busy');
    }
    final progress = progressFor(book, batch);
    if (pendingBatch(book)?.startPage != batch.startPage ||
        !batchReady(book, batch) ||
        progress.needsReread ||
        progress.passed ||
        questionIndex != progress.questionIndex ||
        questionIndex < 0 ||
        questionIndex >= batch.questions.length) {
      throw StateError('Finish reading this section before answering.');
    }
    final question = batch.questions[questionIndex];
    if (answer < 0 || answer >= question.options.length) {
      throw RangeError.index(answer, question.options);
    }
    _answering = true;
    final beforeProgress = progress.toJson();
    final beforeReading = reading.toJson();
    try {
      final correct = answer == question.answer;
      progress.recordAnswer(
        correct: correct,
        questionCount: batch.questions.length,
      );
      var coins = 0;
      late BatchAnswerOutcome outcome;
      if (progress.needsReread) {
        reading.savePosition(book.id, batch.startPage);
        outcome = BatchAnswerOutcome.reset;
      } else if (progress.passed) {
        for (final page in batch.pageIndices) {
          coins += reading.completePage(book.id, page, DateTime.now());
        }
        outcome = BatchAnswerOutcome.completed;
      } else if (correct) {
        outcome = BatchAnswerOutcome.correct;
      } else {
        outcome = progress.questionIndex == questionIndex
            ? BatchAnswerOutcome.wrong
            : BatchAnswerOutcome.exhausted;
      }
      await save();
      return BatchAnswerResult(outcome, coins: coins);
    } catch (_) {
      reading = ReadingLedger.fromJson(beforeReading);
      _batchProgress['${book.id}:${batch.startPage}'] = BatchProgress.fromJson(
        beforeProgress,
      );
      // Flush the rollback after any already queued snapshots.
      try {
        await save();
      } catch (_) {
        /* The storage error stays visible. */
      }
      notifyListeners();
      rethrow;
    } finally {
      _answering = false;
    }
  }

  Future<void> refreshProtection() async {
    try {
      protection = await screenTime.status();
      // Resolve an interrupted reservation against the native transaction receipt.
      if (pendingPurchase != null && !purchasing) {
        final pending = pendingPurchase!;
        if (protection.transactionId == pending['id'] &&
            protection.endsAt != null) {
          wallet.record(
            minutes: pending['minutes'] as int,
            endsAt: protection.endsAt!,
            purchasedAt: DateTime.parse(pending['created'] as String),
          );
        } else {
          reading.spentCoins -= pending['cost'] as int;
        }
        pendingPurchase = null;
        await save();
      }
    } catch (_) {
      error = tr(
        'Screen-time status could not be checked. Open parent settings to reconnect.',
        'Не удалось проверить экранное время. Откройте настройки родителей.',
      );
    }
    notifyListeners();
  }

  Future<void> redeem(int minutes) async {
    if (purchasing || _answering || pendingPurchase != null) {
      throw StateError('busy');
    }
    final problem = wallet.problem(
      minutes: minutes,
      balance: reading.balance,
      dailyLimit: dailyLimit,
    );
    if (problem != null) {
      throw StateError(problem);
    }
    purchasing = true;
    notifyListeners();
    final cost = minutes * 100 ~/ 15;
    var reserved = false;
    var requestedNative = false;
    try {
      protection = await screenTime.status();
      if (!protection.authorized && !protection.preview) {
        throw StateError('permission');
      }
      final now = DateTime.now();
      final id = now.microsecondsSinceEpoch.toString();
      reading.spentCoins += cost;
      pendingPurchase = {
        'id': id,
        'minutes': minutes,
        'cost': cost,
        'created': now.toIso8601String(),
      };
      reserved = true;
      await save();
      requestedNative = true;
      DateTime endsAt;
      try {
        endsAt = await screenTime.unlock(minutes: minutes, transactionId: id);
      } catch (_) {
        // An exception can mean that the reply was lost after activation.
        // If status also fails, preserve the reservation until reconnect/restart.
        protection = await screenTime.status();
        if (protection.transactionId == id && protection.endsAt != null) {
          endsAt = protection.endsAt!;
        } else {
          reading.spentCoins -= cost;
          pendingPurchase = null;
          reserved = false;
          await save();
          rethrow;
        }
      }
      wallet.record(minutes: minutes, endsAt: endsAt, purchasedAt: now);
      pendingPurchase = null;
      await save();
    } catch (_) {
      if (reserved && !requestedNative) {
        reading.spentCoins -= cost;
        pendingPurchase = null;
        await save();
      }
      rethrow;
    } finally {
      purchasing = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> get snapshot => {
    'version': 1,
    'locale': locale,
    'lastOpenedBookId': lastOpenedBookId,
    'age': age,
    'onboarded': onboarded,
    'sound': sound,
    'dailyLimit': dailyLimit,
    'auth': auth.toJson(),
    'reading': reading.toJson(),
    'batchProgress': {
      for (final entry in _batchProgress.entries)
        entry.key: entry.value.toJson(),
    },
    'textSize': textSize,
    'wallet': wallet.toJson(),
    'pendingPurchase': pendingPurchase == null
        ? null
        : Map<String, dynamic>.from(pendingPurchase!),
  };
  Future<void> save() {
    final data = snapshot;
    final next = _pending.then((_) => store.write(data));
    _pending = next.catchError((Object e) {
      error = tr(
        'Your changes could not be saved. Please try again.',
        'Не удалось сохранить изменения. Попробуйте ещё раз.',
      );
      notifyListeners();
    });
    notifyListeners();
    return next;
  }

  Future<void> setLocale(String value) async {
    locale = value;
    await save();
  }

  Future<void> setAge(int value) async {
    final previous = age;
    age = value;
    try {
      await save();
    } catch (_) {
      age = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> finishSetup() async {
    onboarded = true;
    try {
      await save();
    } catch (_) {
      onboarded = false;
      notifyListeners();
      rethrow;
    }
  }
}
