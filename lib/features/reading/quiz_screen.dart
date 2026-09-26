import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/batch_progress.dart';
import '../../core/sound_service.dart';
import '../rewards/reward_celebration.dart';
import '../rewards/reward_message.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'book.dart';
import 'quiz_feedback_panel.dart';
import '../../ui/motion_spec.dart';
import '../../ui/mimi_character.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.controller,
    required this.book,
    required this.batch,
  });
  final AppController controller;
  final Book book;
  final BookBatch batch;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ScrollController _scroll = ScrollController();
  int? _selected, _coins;
  int _reactionId = 0;
  int _balanceBefore = 0, _balanceAfter = 0;
  List<int> _milestones = [];
  bool _bookCompleted = false;
  late int _questionIndex;
  bool _busy = false, _hint = false, _reset = false, _resetByErrors = false;
  BatchAnswerOutcome? _feedback;
  String? _error;
  AppController get c => widget.controller;
  BatchProgress get progress => c.progressFor(widget.book, widget.batch);
  Question get q => widget.batch.questions[_questionIndex];
  bool get _wrong =>
      _feedback == BatchAnswerOutcome.wrong ||
      _feedback == BatchAnswerOutcome.exhausted;
  int get _attemptsLeft =>
      BatchProgress.maxAttempts -
      (_questionIndex < progress.attempts.length
          ? progress.attempts[_questionIndex]
          : 0);

  @override
  void initState() {
    super.initState();
    _questionIndex = progress.questionIndex;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) {
      return;
    }
    if (_feedback != null) {
      setState(() {
        _questionIndex = progress.questionIndex;
        _selected = null;
        _feedback = null;
        _hint = false;
        _error = null;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }
    if (_selected == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final pagesBefore = c.reading.totalPages;
    final balanceBefore = c.reading.balance;
    final thirdError = progress.errors == 2 && _selected != q.answer;
    try {
      final result = await c.answerBatch(
        widget.book,
        widget.batch,
        _questionIndex,
        _selected!,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reactionId++;
        if (result.outcome == BatchAnswerOutcome.completed) {
          _coins = result.coins;
          _balanceBefore = balanceBefore;
          _balanceAfter = c.reading.balance;
          _milestones = [
            1,
            10,
            22,
          ].where((m) => pagesBefore < m && c.reading.totalPages >= m).toList();
          _bookCompleted =
              c.reading.completedCount(widget.book.id) ==
              widget.book.pages.length;
        } else if (result.outcome == BatchAnswerOutcome.reset) {
          _reset = true;
          _resetByErrors = thirdError;
        } else {
          _feedback = result.outcome;
          _hint = _wrong;
        }
      });
      SoundService.instance.playCue(
        result.outcome == BatchAnswerOutcome.completed
            ? (_milestones.isNotEmpty || _bookCompleted
                  ? FeedbackCue.milestone
                  : FeedbackCue.batchComplete)
            : result.outcome == BatchAnswerOutcome.correct
            ? FeedbackCue.correct
            : FeedbackCue.retry,
        enabled: c.sound,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              c.error ??
              c.tr(
                'Could not save your answer. Please try again.',
                'Не удалось сохранить ответ. Попробуй ещё раз.',
              ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SceneScaffold(
      scrollController: _scroll,
      bottom: _feedback == null
          ? null
          : QuizFeedbackPanel(
              outcome: _feedback!,
              character: MiMiCharacter(
                mood: _feedback == BatchAnswerOutcome.correct
                    ? MiMiMood.proud
                    : _feedback == BatchAnswerOutcome.exhausted
                    ? MiMiMood.calm
                    : MiMiMood.encouraging,
                size: 64,
                reactionId: _reactionId,
              ),
              message: _feedbackMessage,
              actionLabel: _feedback == BatchAnswerOutcome.wrong
                  ? c.tr('Try again', 'Попробовать ещё')
                  : c.tr('Next question', 'Следующий вопрос'),
              onContinue: _check,
            ),
      title: _coins == null ? c.tr('Reading', 'Чтение') : null,
      onBack: _coins == null && !_busy ? () => Navigator.pop(context) : null,
      trailing: IconButton(
        tooltip: c.tr('Close', 'Закрыть'),
        onPressed: _busy ? null : () => Navigator.pop(context, _coins != null),
        icon: const Icon(Icons.close_rounded, color: WinTheme.purple),
      ),
      child: _reset
          ? _reread()
          : _coins != null
          ? _success()
          : _question(),
    ),
  );

  Widget _reread() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Heading(
        c.tr(
          'Let’s read this part together again',
          'Давай перечитаем этот отрывок вместе',
        ),
        large: true,
        center: true,
      ),
      gap,
      MiMiCharacter(mood: MiMiMood.calm, size: 160, reactionId: _reactionId),
      gap,
      Text(
        _resetByErrors
            ? c.tr(
                'Three wrong answers reset this section’s progress.',
                'Три ошибки обнулили прогресс этого отрывка.',
              )
            : c.tr(
                'Every question needs a correct answer within two attempts.',
                'На каждый вопрос нужно ответить правильно за две попытки.',
              ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      gap,
      Text(
        c.tr(
          'Reread pages ${widget.batch.startPage + 1}–${widget.batch.endPage}, then try a fresh quiz. Your earlier coins are safe.',
          'Прочитай страницы ${widget.batch.startPage + 1}–${widget.batch.endPage} заново и пройди новую проверку. Ранее заработанные монеты сохранены.',
        ),
        textAlign: TextAlign.center,
      ),
      gap,
      WinButton(
        c.tr('Read the section again', 'Прочитать отрывок заново'),
        onPressed: () => Navigator.pop(context, false),
      ),
    ],
  );

  Widget _question() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            c.tr(
              'Question ${_questionIndex + 1} of ${widget.batch.questions.length}',
              'Вопрос ${_questionIndex + 1} из ${widget.batch.questions.length}',
            ),
            style: const TextStyle(
              color: WinTheme.purple,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.auto_stories_rounded,
            color: WinTheme.purple,
            size: 20,
          ),
        ],
      ),
      gap,
      Heading(widget.book.title), smallGap,
      Text(
        c.tr(
          _feedback == BatchAnswerOutcome.correct
              ? 'Pages ${widget.batch.startPage + 1}–${widget.batch.endPage} · Answer saved'
              : 'Pages ${widget.batch.startPage + 1}–${widget.batch.endPage} · Attempts left: $_attemptsLeft of 2 · Errors: ${progress.errors} of 3',
          _feedback == BatchAnswerOutcome.correct
              ? 'Страницы ${widget.batch.startPage + 1}–${widget.batch.endPage} · Ответ сохранён'
              : 'Страницы ${widget.batch.startPage + 1}–${widget.batch.endPage} · Осталось попыток: $_attemptsLeft из 2 · Ошибки: ${progress.errors} из 3',
        ),
        style: const TextStyle(color: WinTheme.muted),
      ),
      gap,
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          widget.book.pages[widget.batch.endPage - 1].image!,
          height: 165,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      gap,
      // Questions deliberately use the book's language, independently of the UI.
      Text(q.prompt, style: Theme.of(context).textTheme.titleLarge), gap,
      ...List.generate(
        q.options.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            selected: _selected == i,
            enabled: !_busy && _feedback == null,
            button: true,
            child: InkWell(
              onTap: _busy || _feedback != null
                  ? null
                  : () => setState(() => _selected = i),
              borderRadius: BorderRadius.circular(19),
              child: AnimatedContainer(
                duration: MotionSpec.of(context).selection,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selected == i
                      ? (_wrong
                            ? WinTheme.peach
                            : _feedback == BatchAnswerOutcome.correct
                            ? WinTheme.mint
                            : WinTheme.lavender)
                      : const Color(0xFFF8F5FD),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: _selected == i
                        ? (_wrong
                              ? const Color(0xFFE99265)
                              : _feedback == BatchAnswerOutcome.correct
                              ? WinTheme.green
                              : WinTheme.purple)
                        : const Color(0xFFEDE6F8),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      String.fromCharCode(65 + i),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: WinTheme.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q.options[i],
                        style: const TextStyle(
                          fontSize: 16,
                          color: WinTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_selected == i)
                      Icon(
                        _wrong
                            ? Icons.refresh_rounded
                            : _feedback == BatchAnswerOutcome.correct
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_checked,
                        color: WinTheme.purple,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      smallGap,
      if (_feedback == null) ...[
        Row(
          children: [
            MiMiCharacter(
              mood: _selected == null ? MiMiMood.ready : MiMiMood.thinking,
              size: 64,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _hint
                    ? q.hint
                    : c.tr('Think back to the story.', 'Вспомни историю.'),
              ),
            ),
          ],
        ),
        gap,
        if (_error != null) ...[Text(_error!), smallGap],
        WinButton(
          c.tr('Check answer', 'Проверить ответ'),
          onPressed: _selected == null || _busy ? null : _check,
          loading: _busy,
          icon: Icons.arrow_forward_rounded,
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _hint = !_hint),
          child: Text(c.tr('Need a hint?', 'Нужна подсказка?')),
        ),
      ],
    ],
  );

  String get _feedbackMessage => switch (_feedback) {
    BatchAnswerOutcome.correct =>
      '${c.tr(_attemptsLeft == 0 ? 'Correct! You tried again and found it.' : 'Correct! You spotted that detail!', _attemptsLeft == 0 ? 'Правильно! Ещё одна попытка — и получилось.' : 'Правильно! Ты заметил эту деталь!')}\n${q.explanation}',
    BatchAnswerOutcome.exhausted => c.tr(
      'No attempts left. Let’s practice the next one. We’ll reread this section before earning coins.',
      'Попытки закончились. Попробуем следующий вопрос. Перед получением монет перечитаем отрывок.',
    ),
    _ =>
      '${c.tr('Let’s look for a clue. One attempt left.', 'Поищем подсказку. Осталась одна попытка.')}\n${q.hint}',
  };
  Widget _success() => RewardCelebration(
    coinsEarned: _coins!,
    balanceBefore: _balanceBefore,
    balanceAfter: _balanceAfter,
    bookCompleted: _bookCompleted,
    newlyReachedMilestones: _milestones,
    title: widget.book.title,
    cover: widget.book.cover,
    locale: c.locale,
    nextMessage: rewardMessage(c),
    onContinue: () => Navigator.pop(context, true),
    onBooks: () {
      Navigator.pop(context, false);
      Navigator.pop(context);
    },
  );
}
