import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../ui/components.dart';
import '../ui/mimi_character.dart';
import '../ui/theme.dart';
import 'reading/library_screen.dart';

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
    final book =
        c.books.where((b) => b.language == c.locale).firstOrNull ??
        c.books.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: WinTheme.peach,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                c.tr(
                  '${c.reading.streak(DateTime.now())} day streak',
                  'Дней подряд: ${c.reading.streak(DateTime.now())}',
                ),
                style: const TextStyle(
                  color: WinTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Text(c.tr('Let’s grow!', 'Растём вместе!')),
          ],
        ),
        gap,
        Heading(
          c.tr('Your next\nlittle win awaits.', 'Твоя следующая\nпобеда ждёт.'),
          large: true,
        ),
        gap,
        MiMiCharacter(
          mood: MiMiMood.ready,
          idle: true,
          size: (MediaQuery.sizeOf(context).width.clamp(0, 400) - 44) * .7,
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: Text(
                c.tr('Today’s reading goal', 'Цель на сегодня'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${today.clamp(0, 10)} / 10',
              style: const TextStyle(
                color: WinTheme.purple,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        gap,
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(
            value: (today / 10).clamp(0, 1),
            minHeight: 12,
            backgroundColor: WinTheme.lavender,
          ),
        ),
        smallGap,
        Text(
          c.tr(
            '10 pages = 100 coins = 15 minutes',
            '10 страниц = 100 монет = 15 минут',
          ),
        ),
        const SizedBox(height: 22),
        WinButton(
          c.reading.completedCount(book.id) > 0
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
                      Text(
                        c.tr(
                          'A little effort. Time you earned.',
                          'Твои старания — твоё время.',
                        ),
                      ),
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
