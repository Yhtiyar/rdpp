import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../ui/components.dart';
import '../ui/illustrated_icon.dart';
import '../ui/mimi_reading.dart';
import '../ui/theme.dart';
import 'reading/library_screen.dart';
import 'listening/listening_screen.dart';
import 'rewards/reward_message.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.controller,
    required this.onLibrary,
    required this.onWallet,
  });
  final AppController controller;
  final VoidCallback onLibrary, onWallet;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final today = c.reading.pagesOn(DateTime.now());
    final book = c.journeyBook;
    if (book == null) return const SizedBox.shrink();
    final remaining = remainingCatalogPages(c);
    final batch = c.pendingBatch(book);
    final started = c.lastOpenedBookId != null || c.reading.totalPages > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Heading(
          remaining == 0
              ? c.tr(
                  'So many stories. So many discoveries!',
                  'Столько историй. Столько открытий!',
                )
              : today > 0
              ? c.tr(
                  'You understood $today pages today.',
                  'Сегодня ты разобрался в $today страницах.',
                )
              : started
              ? c.tr(
                  'Welcome back to your story.',
                  'С возвращением в твою историю.',
                )
              : c.tr('Let’s read our first story.', 'Почитаем первую историю.'),
          large: true,
        ),
        gap,
        const MiMiReading(),
        gap,
        Text(
          c.tr('Read with MiMi', 'Читаем с МиМи'),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: WinTheme.purple),
        ),
        const SizedBox(height: 4),
        Text(book.title, style: Theme.of(context).textTheme.headlineMedium),
        smallGap,
        Text(
          batch != null
              ? c.tr(
                  'A few pages, then a little quiz!',
                  'Почитаем чуть-чуть, а потом — вопросы!',
                )
              : c.tr(
                  'Let’s enjoy this story again!',
                  'Почитаем эту книжку ещё раз!',
                ),
        ),
        const SizedBox(height: 22),
        WinButton(
          batch == null
              ? c.tr('Read it again', 'Перечитать')
              : started
              ? c.tr('Continue my story', 'Продолжить историю')
              : c.tr('Let’s read a story', 'Почитаем историю'),
          onPressed: () => openBook(context, c, book),
          illustration: Illustration.book,
        ),
        const SizedBox(height: 12),
        WinButton(
          c.tr('Listen & play', 'Слушать и играть'),
          secondary: true,
          icon: Icons.headphones_rounded,
          onPressed: () => openListeningBook(context, book.id),
        ),
        smallGap,
        TextButton(
          onPressed: onLibrary,
          child: Text(c.tr('Explore my books', 'Все мои книги')),
        ),
        gap,
        InkWell(
          onTap: onWallet,
          borderRadius: BorderRadius.circular(22),
          child: SoftPanel(
            color: WinTheme.mint,
            child: Row(
              children: [
                const IllustratedIcon(Illustration.coin, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.tr(
                          '${c.reading.balance} coins saved',
                          'Монет в копилке: ${c.reading.balance}',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(rewardMessage(c)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: WinTheme.green),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
