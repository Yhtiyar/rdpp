import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/sound_service.dart';
import '../../ui/celebration.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'book.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.controller,
    required this.book,
    required this.page,
  });
  final AppController controller;
  final Book book;
  final int page;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int? _selected, _coins;
  bool _wrong = false, _busy = false, _hint = false;
  String? _error;
  AppController get c => widget.controller;
  Question get q => widget.book.pages[widget.page].question;
  Future<void> _check() async {
    if (_wrong) {
      setState(() {
        _selected = null;
        _wrong = false;
      });
      return;
    }
    if (_selected != q.answer) {
      setState(() {
        _wrong = true;
        _hint = true;
      });
      SoundService.instance.play('try_again', enabled: c.sound);
      return;
    }
    setState(() => _busy = true);
    try {
      final coins = await c.answerPage(widget.book, widget.page, _selected!);
      if (!mounted) {
        return;
      }
      if (coins < 0) {
        setState(
          () => _error = c.tr(
            'Return to the page and finish reading first.',
            'Вернись на страницу и дочитай её.',
          ),
        );
      } else {
        setState(() => _coins = coins);
        SoundService.instance.play('success', enabled: c.sound);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = c.error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SceneScaffold(
    title: _coins == null ? c.tr('Reading', 'Чтение') : null,
    onBack: _coins == null ? () => Navigator.pop(context) : null,
    trailing: IconButton(
      tooltip: c.tr('Close', 'Закрыть'),
      onPressed: () => Navigator.pop(context, _coins != null),
      icon: const Icon(Icons.close_rounded, color: WinTheme.purple),
    ),
    child: _coins != null ? _success() : _question(),
  );
  Widget _question() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            c.tr('A little story check', 'Проверим историю'),
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
      Heading(widget.book.title), gap,
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          widget.book.pages[widget.page].image!,
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
            button: true,
            child: InkWell(
              onTap: _busy || _wrong
                  ? null
                  : () => setState(() => _selected = i),
              borderRadius: BorderRadius.circular(19),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selected == i
                      ? (_wrong ? const Color(0xFFFFEFE8) : WinTheme.lavender)
                      : const Color(0xFFF8F5FD),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: _selected == i
                        ? (_wrong ? const Color(0xFFE99265) : WinTheme.purple)
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
                            : Icons.check_circle_rounded,
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
      Row(
        children: [
          const Art('mimi_face', width: 64, height: 66),
          const SizedBox(width: 8),
          Expanded(
            child: SoftPanel(
              padding: const EdgeInsets.all(12),
              child: Text(
                _hint
                    ? q.hint
                    : c.tr(
                        'You’ve got this. Think back to the story!',
                        'Ты справишься! Вспомни историю.',
                      ),
                style: const TextStyle(color: WinTheme.ink),
              ),
            ),
          ),
        ],
      ),
      gap,
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!),
        ),
      WinButton(
        _wrong
            ? c.tr('Try again', 'Попробовать ещё')
            : c.tr('Check answer', 'Проверить ответ'),
        onPressed: _selected == null || _busy ? null : _check,
        loading: _busy,
        icon: _wrong ? Icons.refresh_rounded : Icons.check_rounded,
      ),
      TextButton(
        onPressed: () => setState(() => _hint = !_hint),
        child: Text(c.tr('Need a hint?', 'Нужна подсказка?')),
      ),
    ],
  );
  Widget _success() => Celebration(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Heading(c.tr('You did it!', 'Получилось!'), large: true, center: true),
        gap,
        const FloatArt('mimi_celebrate', height: 280),
        gap,
        Heading(
          _coins! > 0
              ? c.tr('+$_coins coins', '+$_coins монет')
              : c.tr('Great remembering!', 'Отличная память!'),
          large: true,
          center: true,
        ),
        smallGap,
        Text(
          c.tr(
            'One more page. One little win.',
            'Ещё одна страница. Ещё одна победа.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        gap,
        SoftPanel(
          color: WinTheme.mint,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: WinTheme.green),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _coins! > 0
                      ? c.tr('Added to your coins', 'Монеты добавлены')
                      : c.tr(
                          'You already earned this page’s coins',
                          'Монеты за эту страницу уже получены',
                        ),
                  style: const TextStyle(
                    color: WinTheme.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        gap,
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.tr('Your next 100 coins', 'Следующие 100 монет'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              smallGap,
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (c.reading.totalPages % 10) / 10,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFDED0F8),
                ),
              ),
              smallGap,
              Text(
                c.tr(
                  '${c.reading.totalPages % 10} of 10 pages • 15 minutes of playtime',
                  '${c.reading.totalPages % 10} из 10 страниц • 15 минут отдыха',
                ),
              ),
            ],
          ),
        ),
        gap,
        WinButton(
          c.tr('Keep reading', 'Читать дальше'),
          onPressed: () => Navigator.pop(context, true),
        ),
        smallGap,
        WinButton(
          c.tr('Back to my books', 'К моим книгам'),
          secondary: true,
          icon: null,
          onPressed: () {
            Navigator.pop(context, false);
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}
