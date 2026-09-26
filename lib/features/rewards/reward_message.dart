import '../../core/app_controller.dart';
import '../../core/reward_progress.dart';

int remainingCatalogPages(AppController c) => c.books.fold(
  0,
  (sum, book) =>
      sum +
      book.pages
          .asMap()
          .keys
          .where((p) => !c.reading.isComplete(book.id, p))
          .length,
);

List<int> reachableDurations(AppController c) {
  final maximum = c.reading.balance + remainingCatalogPages(c) * 10;
  return [
    15,
    30,
    45,
  ].where((minutes) => minutes * 100 ~/ 15 <= maximum).toList();
}

String rewardMessage(AppController c) {
  final p = RewardProgress.fromBalance(c.reading.balance);
  if (c.pendingPurchase != null) {
    return c.tr(
      'Your purchase is being checked. Your coins are reserved.',
      'Покупка проверяется. Монеты зарезервированы.',
    );
  }
  if (c.wallet.remaining > Duration.zero) {
    return c.tr('Your time is already running.', 'Твоё время уже идёт.');
  }
  if (!p.affordable) {
    if (remainingCatalogPages(c) * 10 + c.reading.balance < 100) {
      return c.tr(
        'You’ve explored these stories! Reread for fun; these pages won’t earn more coins.',
        'Эти истории уже изучены! Перечитывай для удовольствия; за эти страницы новых монет не будет.',
      );
    }
    return c.tr(
      '${p.coinsNeeded} more coins for 15 minutes.',
      'Ещё ${p.coinsNeeded} монет — и 15 минут отдыха.',
    );
  }
  if (c.wallet.usedToday + 15 > c.dailyLimit) {
    return c.tr(
      'Enough coins for 15 minutes. Today’s allowance is used; your coins are safe.',
      'Монет хватит на 15 минут. На сегодня лимит исчерпан; монеты сохранены.',
    );
  }
  if (c.protection.preview) {
    return c.tr(
      'Enough coins for a 15-minute preview. This browser cannot unlock apps.',
      'Хватит на 15 минут предпросмотра. Браузер не может разблокировать приложения.',
    );
  }
  if (!c.protection.authorized) {
    return c.tr(
      'Enough coins for 15 minutes. Ask a parent to connect protection.',
      'Монет хватит на 15 минут. Попроси родителей подключить защиту.',
    );
  }
  return c.tr(
    'You have enough coins for 15 minutes!',
    'Твоих монет хватит на 15 минут!',
  );
}
