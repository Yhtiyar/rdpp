import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../ui/components.dart';
import '../ui/mimi_character.dart';
import '../ui/theme.dart';
import 'reading/library_screen.dart';
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
                  'Two stories. So many discoveries!',
                  'Две истории. Столько открытий!',
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
        MiMiCharacter(
          mood: MiMiMood.ready,
          idle: true,
          size: (MediaQuery.sizeOf(context).width.clamp(0, 400) - 44) * .7,
        ),
        gap,
        Text(book.title, style: Theme.of(context).textTheme.headlineMedium),
        smallGap,
        Text(
          batch != null
              ? c.tr(
                  'Your section: pages ${batch.startPage + 1}–${batch.endPage}',
                  'Твой отрывок: страницы ${batch.startPage + 1}–${batch.endPage}',
                )
              : c.tr(
                  'A story to enjoy again. Previously verified pages earn no extra coins.',
                  'История для нового прочтения. За проверенные страницы новых монет не будет.',
                ),
        ),
        if (!started) ...[
          smallGap,
          Text(
            c.tr(
              'Read the first section with MiMi, then try four questions.',
              'Прочитай первый отрывок с МиМи и ответь на четыре вопроса.',
            ),
          ),
        ],
        const SizedBox(height: 22),
        WinButton(
          batch == null
              ? c.tr('Read it again', 'Перечитать')
              : started
              ? c.tr('Continue my story', 'Продолжить историю')
              : c.tr('Let’s read a story', 'Почитаем историю'),
          onPressed: () => openBook(context, c, book),
          icon: Icons.auto_stories_rounded,
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
                const Art('star', width: 48, height: 48),
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
