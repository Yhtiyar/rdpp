import 'package:flutter/foundation.dart';

import 'local_store.dart';
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
  final Set<String> _readPages = {};
  double textSize = 20;
  bool _answering = false;
  ParentAuth auth = ParentAuth();
  String locale = 'en';
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
  }

  Future<void> savePosition(Book book, int page) async {
    if (page < 0 || page >= book.pages.length) {
      throw RangeError.index(page, book.pages);
    }
    reading.savePosition(book.id, page);
    await save();
  }

  void markRead(Book book, int page) {
    _readPages.add('${book.id}:$page');
  }

  Future<int> answerPage(Book book, int page, int answer) async {
    if (_answering ||
        !_readPages.contains('${book.id}:$page') ||
        book.pages[page].question.answer != answer) {
      return -1;
    }
    _answering = true;
    try {
      final coins = reading.completePage(book.id, page, DateTime.now());
      if (coins == 0) {
        return 0;
      }
      await save();
      return coins;
    } catch (_) {
      reading.revokePage(book.id, page);
      // Flush a correction after any already-queued position/settings snapshots.
      try {
        await save();
      } catch (_) {
        /* Keep the storage error visible. */
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
    'age': age,
    'onboarded': onboarded,
    'sound': sound,
    'dailyLimit': dailyLimit,
    'auth': auth.toJson(),
    'reading': reading.toJson(),
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
