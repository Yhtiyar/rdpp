import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/reward_progress.dart';
import '../../ui/celebration.dart';
import '../../ui/components.dart';
import '../../ui/mimi_character.dart';
import '../../ui/motion_spec.dart';
import '../../ui/theme.dart';

/// Presents an already committed award. No persistence or navigation side effects.
class RewardCelebration extends StatefulWidget {
  const RewardCelebration({
    super.key,
    required this.coinsEarned,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.bookCompleted,
    required this.newlyReachedMilestones,
    required this.title,
    required this.nextMessage,
    required this.onContinue,
    required this.onBooks,
    this.cover,
    this.locale = 'en',
  });
  final int coinsEarned, balanceBefore, balanceAfter;
  final bool bookCompleted;
  final List<int> newlyReachedMilestones;
  final String title, nextMessage, locale;
  final String? cover;
  final VoidCallback onContinue, onBooks;
  @override
  State<RewardCelebration> createState() => _RewardCelebrationState();
}

class _RewardCelebrationState extends State<RewardCelebration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;
  String tr(String en, String ru) => widget.locale == 'ru' ? ru : en;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionSpec.of(context).reduceMotion ||
        !TickerMode.valuesOf(context).enabled) {
      _motion.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _motion.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _motion.value = 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = RewardProgress.fromBalance(widget.balanceAfter);
    final special =
        widget.newlyReachedMilestones.isNotEmpty || widget.bookCompleted;
    final earned = widget.coinsEarned > 0
        ? tr('+${widget.coinsEarned} coins', '+${widget.coinsEarned} монет')
        : tr('Great remembering!', 'Отличная память!');
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: '$earned. ${tr('Balance', 'Баланс')}: ${widget.balanceAfter}.',
          child: ExcludeSemantics(
            child: Heading(
              widget.bookCompleted
                  ? tr(
                      'You finished ${widget.title}!',
                      'Ты прочитал ${widget.title}!',
                    )
                  : tr(
                      'You understood this part of the story.',
                      'Ты понял этот отрывок истории.',
                    ),
              large: true,
              center: true,
            ),
          ),
        ),
        smallGap,
        SizedBox(
          height: widget.bookCompleted ? 200 : 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.bookCompleted && widget.cover != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(widget.cover!, height: 160),
                    ),
                  ),
                ),
              Flexible(
                child: MiMiCharacter(
                  mood: special ? MiMiMood.celebrating : MiMiMood.proud,
                  size: 180,
                  reactionId: 1,
                ),
              ),
            ],
          ),
        ),
        Heading(earned, large: true, center: true),
        smallGap,
        Text(
          widget.coinsEarned > 0
              ? tr('Added to your coins', 'Монеты добавлены')
              : tr(
                  'You already earned this section’s coins',
                  'Монеты за этот отрывок уже получены',
                ),
          textAlign: TextAlign.center,
        ),
        gap,
        SoftPanel(
          color: WinTheme.mint,
          child: Column(
            children: [
              Text(tr('Your coins', 'Твои монеты')),
              ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(
                      ((_motion.value * 1100 - 180) / 470).clamp(0, 1),
                    );
                    final balance =
                        (widget.balanceBefore +
                                (widget.balanceAfter - widget.balanceBefore) *
                                    t)
                            .round();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$balance',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        if (!MotionSpec.of(context).reduceMotion &&
                            t > 0 &&
                            t < 1)
                          ...List.generate(
                            3,
                            (i) => Transform.translate(
                              offset: Offset(
                                70 - i * 24,
                                -35 * sin(t * pi) - i * 5,
                              ),
                              child: Opacity(
                                opacity: sin(t * pi),
                                child: const Icon(
                                  Icons.stars_rounded,
                                  color: Color(0xFFF2B420),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Text(
                tr(
                  'Saved balance: ${widget.balanceAfter} coins',
                  'Сохранено: ${widget.balanceAfter} монет',
                ),
              ),
              smallGap,
              LinearProgressIndicator(
                value: p.fraction,
                minHeight: 8,
                backgroundColor: WinTheme.lavender,
              ),
              smallGap,
              Text(widget.nextMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
        if (widget.newlyReachedMilestones.isNotEmpty) ...[
          smallGap,
          Text(
            widget.newlyReachedMilestones
                .map(
                  (m) => switch (m) {
                    1 => tr('First little win', 'Первая победа'),
                    10 => tr('Ten-page explorer', '10 страниц открытий'),
                    _ => tr('Story superstar', 'Звезда чтения'),
                  },
                )
                .join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: WinTheme.purple,
            ),
          ),
        ],
        gap,
        WinButton(
          tr('Keep reading', 'Читать дальше'),
          onPressed: widget.onContinue,
        ),
        smallGap,
        WinButton(
          tr('Back to my books', 'К моим книгам'),
          onPressed: widget.onBooks,
          secondary: true,
          icon: null,
        ),
      ],
    );
    return special ? Celebration(child: content) : content;
  }
}
