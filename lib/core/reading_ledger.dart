/// A persisted ledger of distinct, verified reading pages.
class ReadingLedger {
  ReadingLedger();
  factory ReadingLedger.fromJson(Map<String, dynamic> json) {
    final result = ReadingLedger();
    result._completed.addAll(
      Map<String, String>.from(json['completed'] as Map? ?? {}),
    );
    result._positions.addAll(
      Map<String, int>.from(json['positions'] as Map? ?? {}),
    );
    result.spentCoins = json['spentCoins'] as int? ?? 0;
    return result;
  }
  final Map<String, String> _completed = {};
  final Map<String, int> _positions = {};
  int spentCoins = 0;
  int get totalPages => _completed.length;
  int get earnedCoins => totalPages * 10;
  int get balance => earnedCoins - spentCoins;
  int position(String bookId) => _positions[bookId] ?? 0;
  bool isComplete(String bookId, int page) =>
      _completed.containsKey('$bookId:$page');
  int completedCount(String bookId) =>
      _completed.keys.where((k) => k.startsWith('$bookId:')).length;
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  int pagesOn(DateTime date) =>
      _completed.values.where((v) => v == dateKey(date)).length;
  void savePosition(String bookId, int page) {
    _positions[bookId] = page;
  }

  int completePage(String bookId, int page, DateTime date) {
    if (isComplete(bookId, page)) {
      return 0;
    }
    _completed['$bookId:$page'] = dateKey(date);
    return 10;
  }

  void revokePage(String bookId, int page) {
    _completed.remove('$bookId:$page');
  }

  int streak(DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if (pagesOn(day) == 0) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var count = 0;
    while (pagesOn(day) > 0) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
    'completed': Map<String, String>.from(_completed),
    'positions': Map<String, int>.from(_positions),
    'spentCoins': spentCoins,
  };
}
