import 'reading_ledger.dart';

/// Elapsed access windows, with a daily purchase allowance.
class TimeWallet {
  TimeWallet({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  factory TimeWallet.fromJson(
    Map<String, dynamic> json, {
    DateTime Function()? clock,
  }) {
    final result = TimeWallet(clock: clock);
    result._minutesByDay.addAll(
      Map<String, int>.from(json['minutesByDay'] as Map? ?? {}),
    );
    result._endsAt = DateTime.tryParse(json['endsAt'] as String? ?? '');
    return result;
  }
  final DateTime Function() _clock;
  final Map<String, int> _minutesByDay = {};
  DateTime? _endsAt;
  DateTime? get endsAt => _endsAt;
  int get usedToday => _minutesByDay[ReadingLedger.dateKey(_clock())] ?? 0;
  Duration get remaining {
    final left = _endsAt?.difference(_clock()) ?? Duration.zero;
    return left.isNegative ? Duration.zero : left;
  }

  String? problem({
    required int minutes,
    required int balance,
    required int dailyLimit,
  }) {
    if (![15, 30, 45].contains(minutes)) {
      return 'duration';
    }
    if (remaining > Duration.zero) {
      return 'active';
    }
    if (balance < minutes * 100 ~/ 15) {
      return 'coins';
    }
    if (usedToday + minutes > dailyLimit) {
      return 'limit';
    }
    return null;
  }

  void record({
    required int minutes,
    required DateTime endsAt,
    DateTime? purchasedAt,
  }) {
    final key = ReadingLedger.dateKey(purchasedAt ?? _clock());
    _minutesByDay[key] = (_minutesByDay[key] ?? 0) + minutes;
    _endsAt = endsAt;
  }

  Map<String, dynamic> toJson() => {
    'minutesByDay': Map<String, int>.from(_minutesByDay),
    'endsAt': _endsAt?.toIso8601String(),
  };
}
