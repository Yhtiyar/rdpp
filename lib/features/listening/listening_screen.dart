import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/components.dart';
import '../../ui/illustrated_icon.dart';
import '../../ui/mimi_character.dart';
import '../../ui/motion_spec.dart';
import '../../ui/theme.dart';
import 'listening_book.dart';
import 'listening_session.dart';
import 'listening_store.dart';
import 'narration_player.dart';

final Set<NavigatorState> _openingStories = {};

Future<void> openListeningBook(
  BuildContext context,
  String bookId, {
  Future<List<ListeningBook>> Function()? loadBooks,
  ListeningSession Function(ListeningBook)? sessionFactory,
}) async {
  final navigator = Navigator.of(context);
  if (!_openingStories.add(navigator)) return;
  try {
    final books = await (loadBooks ?? ListeningCatalog.load)();
    final book = books.firstWhere((b) => b.id == bookId);
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListeningScreen(book: book, session: sessionFactory?.call(book)),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the story. Please try again.'),
        ),
      );
    }
  } finally {
    _openingStories.remove(navigator);
  }
}

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key, required this.book, this.session});
  final ListeningBook book;
  final ListeningSession? session;
  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with WidgetsBindingObserver {
  late final ListeningSession s =
      widget.session ??
      ListeningSession(
        book: widget.book,
        player: AssetNarrationPlayer(playbackRate: widget.book.playbackRate),
        store: ListeningPreferencesStore(),
      );
  bool _ready = false;
  ListeningBook get book => widget.book;
  String tr(String en, String ru) => book.tr(en, ru);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    await s.load();
    if (!mounted) return;
    setState(() => _ready = true);
    // Saved sessions always resume paused, including an interrupted question.
    if (!s.restored &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed)) {
      s.play();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (_ready &&
        (s.isPlaying || s.waitingForTurn) &&
        (!current || !TickerMode.valuesOf(context).enabled)) {
      s.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) s.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.dispose();
    super.dispose();
  }

  Future<void> _options() async {
    s.pause();
    final restart = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Make yourself cosy', 'Устроимся поудобнее'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Turn pages for me', 'Листать автоматически')),
                  value: s.autoAdvance,
                  onChanged: (value) => s.setOptions(turnPages: value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Show story words', 'Показывать текст')),
                  value: s.captions,
                  onChanged: (value) => s.setOptions(showCaptions: value),
                ),
                const SizedBox(height: 16),
                WinButton(
                  tr('Back to the story', 'Вернуться к сказке'),
                  onPressed: () => Navigator.pop(context),
                  illustration: Illustration.book,
                ),
                const SizedBox(height: 12),
                WinButton(
                  tr('Start from beginning', 'Начать сначала'),
                  onPressed: () => Navigator.pop(context, true),
                  secondary: true,
                  icon: Icons.restart_alt_rounded,
                ),
                const SizedBox(height: 12),
                Text(book.adaptationNote),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(tr('Book credits', 'Об источнике книги')),
                  children: [Text(book.attribution)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && restart == true) s.restart();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFFCF6),
    body: SafeArea(
      child: !_ready
          ? const Center(child: CircularProgressIndicator())
          : s.loadError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(
                        'Your story place couldn’t be loaded.',
                        'Не удалось открыть сохранённую сказку.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    WinButton(
                      tr('Try again', 'Попробовать снова'),
                      onPressed: _load,
                      icon: Icons.refresh_rounded,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('Back to my books', 'К моим книжкам')),
                    ),
                  ],
                ),
              ),
            )
          : ListenableBuilder(
              listenable: s,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 680;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                s.pause();
                                Navigator.pop(context);
                              },
                              tooltip: tr('Close story', 'Закрыть сказку'),
                              icon: const Icon(Icons.close_rounded),
                              color: WinTheme.muted,
                            ),
                            Expanded(
                              child: Text(
                                tr('STORYTIME', 'ВРЕМЯ СКАЗКИ'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: WinTheme.purple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _options,
                              tooltip: tr(
                                'Listening options',
                                'Настройки сказки',
                              ),
                              icon: const Icon(Icons.tune_rounded),
                              color: WinTheme.muted,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: _PageTrail(
                          count: book.pages.length,
                          heard: s.heardPages,
                          current: s.pageIndex,
                        ),
                      ),
                      if (s.storageError)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TextButton.icon(
                            onPressed: s.persist,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              tr(
                                'Your place couldn’t be saved. Retry',
                                'Не удалось сохранить место. Повторить',
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MotionSpec.of(context).transition,
                          child: KeyedSubtree(
                            key: ValueKey(
                              '${s.phase}:${s.pageIndex}:${s.questionIndex}',
                            ),
                            child: switch (s.phase) {
                              ListeningPhase.page => _story(compact),
                              ListeningPhase.question => _question(compact),
                              ListeningPhase.complete => _complete(compact),
                            },
                          ),
                        ),
                      ),
                      if (s.audioError)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            tr(
                              'Tap play to try the voice again.',
                              'Нажми «играть», чтобы послушать ещё раз.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: WinTheme.purple,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (s.phase != ListeningPhase.complete)
                        _controls(compact),
                    ],
                  );
                },
              ),
            ),
    ),
  );

  Widget _story(bool compact) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 4 : 12),
          child: Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: WinTheme.ink,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 24 : 30,
              height: 1.12,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: AspectRatio(
                aspectRatio:
                    s.page.imageAspectRatio ?? (book.id == 'frog' ? 1.36 : .82),
                child: Semantics(
                  label: tr(
                    'Story illustration, page ${s.pageIndex + 1}',
                    'Иллюстрация, страница ${s.pageIndex + 1}',
                  ),
                  image: true,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EFDE),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          offset: Offset(0, 5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      s.page.image,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (s.captions)
          SizedBox(
            height: compact ? 86 : 116,
            child: SingleChildScrollView(
              key: ValueKey(s.page.id),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                s.page.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: WinTheme.ink,
                  fontSize: 17,
                  height: 1.45,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _question(bool compact) {
    final correct = s.clipKind == 'feedback';
    final mood = correct
        ? MiMiMood.proud
        : s.attempts > 0
        ? MiMiMood.encouraging
        : MiMiMood.thinking;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        children: [
          Text(
            correct
                ? tr('You found it!', 'Ты нашёл!')
                : s.guided
                ? tr('Let’s find it together', 'Найдём вместе')
                : tr('Your turn, little explorer', 'Твой ход, малыш'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 23 : 28,
              fontWeight: FontWeight.w900,
              color: WinTheme.ink,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          MiMiCharacter(
            mood: mood,
            size: compact ? 90 : 130,
            reactionId: '${s.question.id}:${s.attempts}:${s.clipKind}',
            idle: false,
          ),
          const SizedBox(height: 10),
          Text(
            s.question.prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WinTheme.ink,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 17 : 20,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < s.question.choices.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: _PictureAnswer(
                    choice: s.question.choices[i],
                    enabled: s.canAnswerChoice(i),
                    correct: (correct || s.guided) && i == s.question.answer,
                    selected: s.selected == i,
                    onTap: () => s.answer(i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (s.captions && s.clipKind != 'prompt')
            Text(
              s.spokenText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: WinTheme.muted),
            ),
        ],
      ),
    );
  }

  Widget _complete(bool compact) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 12),
        Text(
          tr(
            'A whole story.\nA little star.',
            'Целая сказка.\nТвоя звёздочка.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: WinTheme.ink,
            fontSize: compact ? 29 : 35,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            MiMiCharacter(
              mood: MiMiMood.celebrating,
              size: compact ? 180 : 240,
              reactionId: book.id,
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDB7),
                shape: BoxShape.circle,
              ),
              child: const Art('star', width: 54, height: 54),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          book.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          tr('Story star collected', 'Звёздочка за сказку получена'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        WinButton(
          tr('Listen again', 'Послушать снова'),
          onPressed: s.restart,
          icon: Icons.replay_rounded,
        ),
        const SizedBox(height: 12),
        WinButton(
          tr('Back to my books', 'К моим книжкам'),
          secondary: true,
          onPressed: () {
            s.pause();
            Navigator.pop(context);
          },
          illustration: Illustration.book,
        ),
        const SizedBox(height: 10),
        IconButton(
          onPressed: () => s.isPlaying ? s.pause() : s.play(replay: true),
          tooltip: s.isPlaying
              ? tr('Pause story', 'Пауза')
              : tr('Hear celebration', 'Послушать поздравление'),
          icon: Icon(
            s.isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
          ),
          color: WinTheme.purple,
        ),
      ],
    ),
  );

  Widget _controls(bool compact) {
    final active = s.isPlaying || s.waitingForTurn;
    final isPage = s.phase == ListeningPhase.page;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, compact ? 12 : 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SpeakingBars(active: s.isPlaying && !s.loading),
                const SizedBox(width: 9),
                Text(
                  s.loading
                      ? tr('Getting cosy…', 'Сейчас начнём…')
                      : s.isPlaying
                      ? tr('Listen closely', 'Слушаем сказку')
                      : s.waitingForTurn
                      ? tr('Turning the page…', 'Перелистываем…')
                      : s.canAnswer
                      ? tr('Tap a picture', 'Нажми на картинку')
                      : tr('Ready when you are', 'Продолжим, когда захочешь'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WinTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (isPage)
                _roundControl(
                  Icons.arrow_back_rounded,
                  tr('Previous page', 'Предыдущая страница'),
                  s.pageIndex > 0 ? s.previous : null,
                ),
              _roundControl(
                Icons.replay_rounded,
                isPage
                    ? tr('Replay page', 'Повторить страницу')
                    : tr('Repeat question', 'Повторить вопрос'),
                () => s.play(replay: true),
              ),
              _roundControl(
                active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                active
                    ? tr('Pause story', 'Пауза')
                    : tr('Play story', 'Играть'),
                () => active ? s.pause() : s.play(),
                primary: true,
              ),
              if (isPage)
                _roundControl(
                  Icons.arrow_forward_rounded,
                  tr('Next page', 'Следующая страница'),
                  s.canNext ? s.next : null,
                ),
            ],
          ),
          if (isPage)
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Text(
                tr(
                  'PAGE ${s.pageIndex + 1} OF ${book.pages.length}',
                  'СТРАНИЦА ${s.pageIndex + 1} ИЗ ${book.pages.length}',
                ),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w900,
                  color: WinTheme.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundControl(
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    bool primary = false,
  }) => Container(
    width: primary ? 78 : 54,
    height: primary ? 78 : 54,
    decoration: BoxDecoration(
      color: primary ? WinTheme.purple : WinTheme.lavender,
      borderRadius: BorderRadius.circular(primary ? 29 : 20),
      boxShadow: primary
          ? const [BoxShadow(color: Color(0xFF5523C9), offset: Offset(0, 5))]
          : null,
    ),
    child: IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon, size: primary ? 42 : 27),
      color: primary ? Colors.white : WinTheme.purple,
      disabledColor: const Color(0xFFC8BDDB),
    ),
  );
}

class _PageTrail extends StatelessWidget {
  const _PageTrail({
    required this.count,
    required this.heard,
    required this.current,
  });
  final int count, current;
  final Set<int> heard;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      children: [
        for (
          var i = current ~/ 3 * 3;
          i < math.min(count, (current ~/ 3 + 1) * 3);
          i++
        )
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: MotionSpec.of(context).transition,
                height: 5,
                decoration: BoxDecoration(
                  color: heard.contains(i)
                      ? WinTheme.green
                      : i == current
                      ? WinTheme.purple
                      : const Color(0xFFECE4DA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _PictureAnswer extends StatelessWidget {
  const _PictureAnswer({
    required this.choice,
    required this.enabled,
    required this.correct,
    required this.selected,
    required this.onTap,
  });
  final PictureChoice choice;
  final bool enabled, correct, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = correct
        ? WinTheme.green
        : selected
        ? const Color(0xFFD09A39)
        : const Color(0xFFDAD0E9);
    return Semantics(
      button: true,
      enabled: enabled,
      label: choice.label,
      onTap: enabled ? onTap : null,
      selected: selected,
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: correct && selected && !MotionSpec.of(context).reduceMotion
              ? 1.035
              : 1,
          duration: MotionSpec.of(context).reaction,
          child: AnimatedContainer(
            duration: MotionSpec.of(context).selection,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: color, offset: const Offset(0, 5))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onTap : null,
                borderRadius: BorderRadius.circular(19),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: .86,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: _ChoiceArt(choice: choice),
                        ),
                        if (correct)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: WinTheme.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceArt extends StatelessWidget {
  const _ChoiceArt({required this.choice});
  final PictureChoice choice;
  @override
  Widget build(BuildContext context) {
    if (choice.cell == null) {
      return Image.asset(choice.image, fit: BoxFit.contain);
    }
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) => ClipRect(
          child: OverflowBox(
            maxWidth: box.maxWidth * 3,
            maxHeight: box.maxWidth * 2,
            alignment: Alignment(
              (choice.cell! % 3) - 1.0,
              choice.cell! < 3 ? -1 : 1,
            ),
            child: Image.asset(
              choice.image,
              width: box.maxWidth * 3,
              height: box.maxWidth * 2,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeakingBars extends StatefulWidget {
  const _SpeakingBars({required this.active});
  final bool active;
  @override
  State<_SpeakingBars> createState() => _SpeakingBarsState();
}

class _SpeakingBarsState extends State<_SpeakingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  void _configure() {
    if (widget.active && !MotionSpec.of(context).reduceMotion) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(_SpeakingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _motion,
      builder: (_, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 3,
            height: widget.active
                ? 7 + 10 * (math.sin(_motion.value * math.pi * 2 + i) + 1) / 2
                : 5,
            decoration: BoxDecoration(
              color: WinTheme.purple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ),
  );
}
