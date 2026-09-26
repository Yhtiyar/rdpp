import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../../ui/mimi_character.dart';
import '../reading/library_screen.dart';

class ProgressContent extends StatelessWidget {
  const ProgressContent({
    super.key,
    required this.controller,
    required this.onWallet,
  });
  final AppController controller;
  final VoidCallback onWallet;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final pages = c.reading.totalPages;
    if (pages == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Heading(
            c.tr(
              'Your first little win is waiting',
              'Твоя первая победа впереди',
            ),
            large: true,
          ),
          gap,
          const MiMiCharacter(mood: MiMiMood.encouraging, size: 190),
          gap,
          Text(
            c.tr(
              'Finish your first section with MiMi. Read, discover, and tell us what happened.',
              'Закончи первый отрывок с МиМи. Читай, узнавай и расскажи, что произошло.',
            ),
          ),
          gap,
          SoftPanel(
            color: WinTheme.peach,
            child: Text(
              c.tr(
                'First little win · Understand your first section',
                'Первая победа · Разберись в первом отрывке',
              ),
            ),
          ),
          gap,
          WinButton(
            c.tr('Let’s read a story', 'Почитаем историю'),
            onPressed: c.journeyBook == null
                ? null
                : () => openBook(context, c, c.journeyBook!),
          ),
        ],
      );
    }
    final streak = c.reading.streak(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Heading(
          c.tr('Every little win counts', 'Каждая победа важна'),
          large: true,
        ),
        gap,
        SoftPanel(
          child: Row(
            children: [
              const Art('reward_star', width: 80, height: 86),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tr(
                        '${c.reading.balance} coins',
                        '${c.reading.balance} монет',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      c.tr(
                        '$pages pages read • $streak day streak',
                        'Прочитано: $pages стр. • Дней подряд: $streak',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          c.tr('Your reading week', 'Твоя неделя чтения'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        gap,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final now = DateTime.now();
            final date = DateTime(
              now.year,
              now.month,
              now.day - (now.weekday - 1) + i,
            );
            final active = c.reading.pagesOn(date) > 0;
            return Column(
              children: [
                Text(
                  c.locale == 'ru'
                      ? ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i]
                      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                  style: const TextStyle(fontSize: 12),
                ),
                smallGap,
                Container(
                  width: 33,
                  height: 33,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? WinTheme.purple : WinTheme.lavender,
                  ),
                  child: Icon(
                    active ? Icons.check_rounded : Icons.circle_outlined,
                    color: active ? Colors.white : const Color(0xFFD6C7ED),
                    size: 19,
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 28),
        Text(
          c.tr('Your little milestones', 'Твои достижения'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        gap,
        ...[
          (1, 'First little win', 'Первая победа', Icons.auto_stories_rounded),
          (10, 'Ten-page explorer', '10 страниц открытий', Icons.stars_rounded),
          (22, 'Story superstar', 'Звезда чтения', Icons.emoji_events_rounded),
        ].map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftPanel(
              color: pages >= v.$1 ? WinTheme.peach : const Color(0xFFF5F2F9),
              child: Row(
                children: [
                  Icon(
                    v.$4,
                    size: 39,
                    color: pages >= v.$1
                        ? const Color(0xFFF2B420)
                        : const Color(0xFFB7AACB),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.tr(v.$2, v.$3),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          c.tr(
                            '${pages.clamp(0, v.$1)} / ${v.$1} pages',
                            '${pages.clamp(0, v.$1)} / ${v.$1} страниц',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pages >= v.$1)
                    const Icon(Icons.check_circle, color: WinTheme.green),
                ],
              ),
            ),
          ),
        ),
        gap,
        WinButton(
          c.tr('Use my coins', 'Потратить монеты'),
          onPressed: onWallet,
          icon: Icons.timer_outlined,
        ),
      ],
    );
  }
}
