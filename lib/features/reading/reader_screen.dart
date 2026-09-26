import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import '../../ui/motion_spec.dart';
import 'book.dart';
import 'quiz_screen.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.controller, required this.book});
  final AppController controller;
  final Book book;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scroll = ScrollController();
  late int _page;
  bool _atBottom = false,
      _markingRead = false,
      _quizOpen = false,
      _changingPage = false;
  AppController get c => widget.controller;
  Book get book => widget.book;
  @override
  void initState() {
    super.initState();
    _page = c.reading.position(book.id).clamp(0, book.pages.length - 1);
    final batch = c.pendingBatch(book);
    if (!c.canOpenPage(book, _page)) {
      _page = batch?.startPage ?? 0;
    }
    _scroll.addListener(_checkBottom);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBottom());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkBottom() async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_scroll.hasClients ||
        _quizOpen ||
        _changingPage ||
        _markingRead ||
        _atBottom) {
      return;
    }
    if (_scroll.position.maxScrollExtent - _scroll.offset > 36) {
      return;
    }
    final page = _page;
    setState(() {
      _atBottom = true;
      _markingRead = true;
    });
    try {
      await c.markRead(book, page);
    } catch (_) {
      if (mounted) {
        setState(() => _atBottom = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              c.error ??
                  c.tr(
                    'Could not save reading progress. Try again.',
                    'Не удалось сохранить прогресс. Попробуй ещё раз.',
                  ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _markingRead = false);
      }
    }
  }

  Future<void> _go(int page) async {
    if (_changingPage || !c.canOpenPage(book, page)) {
      return;
    }
    setState(() {
      _changingPage = true;
      _page = page;
      _atBottom = false;
    });
    _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _page != page) return;
      setState(() => _changingPage = false);
      _checkBottom();
    });
    try {
      await c.savePosition(book, page);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(c.error!)));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBottom());
  }

  Future<void> _quiz() async {
    final batch = c.pendingBatch(book);
    if (_quizOpen || batch == null || !c.batchReady(book, batch)) {
      return;
    }
    _quizOpen = true;
    final next = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(controller: c, book: book, batch: batch),
      ),
    );
    _quizOpen = false;
    if (!mounted) {
      return;
    }
    setState(() {});
    if (c.progressFor(book, batch).needsReread) {
      await _go(batch.startPage);
    } else if (next == true) {
      if (batch.endPage < book.pages.length) {
        await _go(batch.endPage);
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _contents() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Heading(
                c.tr('Your place in the story', 'Твоё место в истории'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: book.pages.length,
                itemBuilder: (context, i) => ListTile(
                  selected: i == _page,
                  leading: Icon(
                    c.reading.isComplete(book.id, i)
                        ? Icons.check_circle
                        : Icons.auto_stories_outlined,
                    color: WinTheme.purple,
                  ),
                  title: Text(c.tr('Page ${i + 1}', 'Страница ${i + 1}')),
                  subtitle: Text(
                    book.pages[i].text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  enabled: c.canOpenPage(book, i),
                  onTap: !c.canOpenPage(book, i)
                      ? null
                      : () {
                          Navigator.pop(context);
                          _go(i);
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(_checkBottom);
  void _settings() => showModalBottomSheet<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Heading(c.tr('Make yourself comfortable', 'Читай с удобством')),
              gap,
              Row(
                children: [
                  const Text('Aa', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Slider(
                      value: c.textSize,
                      min: 17,
                      max: 30,
                      divisions: 13,
                      label: c.textSize.toInt().toString(),
                      onChanged: (v) {
                        update(() => c.textSize = v);
                        setState(() {});
                      },
                      onChangeEnd: (_) => c.save(),
                    ),
                  ),
                  const Text('Aa', style: TextStyle(fontSize: 28)),
                ],
              ),
              Text(c.tr('Text size', 'Размер текста')),
              gap,
              WinButton(
                c.tr('Done', 'Готово'),
                onPressed: () => Navigator.pop(context),
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(_checkBottom);
  @override
  Widget build(BuildContext context) {
    final page = book.pages[_page];
    final section = book.batchForPage(_page);
    final readPages = c.progressFor(book, section).readPages;
    final readCount = section.pageIndices
        .where((p) => readPages.contains(p) || c.reading.isComplete(book.id, p))
        .length;
    final pending = c.pendingBatch(book);
    final reviewOnly = pending == null || _page < pending.startPage;
    final ready = pending != null && c.batchReady(book, pending);
    final canNext =
        c.canOpenPage(book, _page + 1) &&
        !_markingRead &&
        !_changingPage &&
        (_atBottom || reviewOnly);
    return PopScope(
      canPop: !_markingRead,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: c.tr('Back to books', 'К книгам'),
                      onPressed: _markingRead
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: WinTheme.purple,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        c.tr('Reading', 'Чтение'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: WinTheme.purple,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: c.tr('Text size', 'Размер текста'),
                      onPressed: _markingRead ? null : _settings,
                      icon: const Icon(
                        Icons.text_fields_rounded,
                        color: WinTheme.purple,
                      ),
                    ),
                    IconButton(
                      tooltip: c.tr('Contents', 'Оглавление'),
                      onPressed: _markingRead ? null : _contents,
                      icon: const Icon(
                        Icons.list_rounded,
                        color: WinTheme.purple,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: WinTheme.ink,
                            ),
                          ),
                        ),
                        Text(
                          c.tr(
                            '${(c.reading.completedCount(book.id) / book.pages.length * 100).round()}% verified',
                            '${(c.reading.completedCount(book.id) / book.pages.length * 100).round()}% проверено',
                          ),
                          style: const TextStyle(
                            color: WinTheme.purple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    smallGap,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LinearProgressIndicator(
                        value:
                            c.reading.completedCount(book.id) /
                            book.pages.length,
                        minHeight: 7,
                        backgroundColor: WinTheme.lavender,
                      ),
                    ),
                    smallGap,
                    Semantics(
                      label: c.tr(
                        '$readCount of ${section.pageCount} pages read',
                        'Прочитано $readCount из ${section.pageCount} страниц',
                      ),
                      child: ExcludeSemantics(
                        child: Row(
                          children: [
                            ...section.pageIndices.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: AnimatedContainer(
                                  duration: MotionSpec.of(context).selection,
                                  width: 20,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color:
                                        readPages.contains(p) ||
                                            c.reading.isComplete(book.id, p)
                                        ? WinTheme.purple
                                        : WinTheme.lavender,
                                  ),
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                c.tr(
                                  '$readCount of ${section.pageCount} pages read',
                                  'Прочитано $readCount из ${section.pageCount} страниц',
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (_) {
                    final measuredPage = _page;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && measuredPage == _page) _checkBottom();
                    });
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_page),
                      tween: Tween(begin: 0, end: 1),
                      duration: MotionSpec.of(context).transition,
                      builder: (context, value, child) => Opacity(
                        opacity: MotionSpec.of(context).reduceMotion
                            ? 1
                            : value,
                        child: Transform.translate(
                          offset: Offset(
                            MotionSpec.of(context).reduceMotion
                                ? 0
                                : 10 * (1 - value),
                            0,
                          ),
                          child: child,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (page.image != null)
                            GestureDetector(
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          tooltip: c.tr('Close', 'Закрыть'),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          icon: const Icon(Icons.close),
                                        ),
                                      ),
                                      Flexible(
                                        child: InteractiveViewer(
                                          minScale: 1,
                                          maxScale: 4,
                                          child: Image.asset(page.image!),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              child: Semantics(
                                button: true,
                                label: c.tr(
                                  'Enlarge illustration',
                                  'Увеличить иллюстрацию',
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.asset(
                                    page.image!,
                                    height: 235,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SelectableText(
                            page.text,
                            style: TextStyle(
                              fontSize: c.textSize,
                              height: 1.7,
                              color: WinTheme.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          gap,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_stories_rounded,
                                size: 16,
                                color: WinTheme.muted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                c.tr(
                                  'Original page ${page.sourcePage}',
                                  'Страница оригинала: ${page.sourcePage}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEFDFF),
                  border: Border(top: BorderSide(color: WinTheme.lavender)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: c.tr('Previous page', 'Предыдущая страница'),
                          onPressed: _page > 0 && !_markingRead
                              ? () => _go(_page - 1)
                              : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Text(
                          c.tr(
                            'Page ${_page + 1} of ${book.pages.length}',
                            'Страница ${_page + 1} из ${book.pages.length}',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: WinTheme.ink,
                          ),
                        ),
                        IconButton(
                          tooltip: c.tr('Next page', 'Следующая страница'),
                          onPressed: canNext ? () => _go(_page + 1) : null,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),
                    if (!reviewOnly) ...[
                      Text(
                        c.tr(
                          'Pages ${pending.startPage + 1}–${pending.endPage} · ${pending.questions.length} questions after reading',
                          'Страницы ${pending.startPage + 1}–${pending.endPage} · ${pending.questions.length} вопроса после чтения',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: WinTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (c.progressFor(book, pending).needsReread)
                        Text(
                          c.tr(
                            'Read this section again for a fresh quiz.',
                            'Прочитай этот отрывок заново перед новой проверкой.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 8),
                    ],
                    WinButton(
                      reviewOnly
                          ? c.tr(
                              _page + 1 == book.pages.length
                                  ? 'Back to my books'
                                  : 'Next page',
                              _page + 1 == book.pages.length
                                  ? 'К моим книгам'
                                  : 'Следующая страница',
                            )
                          : ready
                          ? c.progressFor(book, pending).attempts.isEmpty
                                ? c.tr('Start test', 'Начать проверку')
                                : c.tr('Continue test', 'Продолжить проверку')
                          : _atBottom
                          ? c.tr('Next page', 'Следующая страница')
                          : c.tr(
                              'Read to the end of this page',
                              'Дочитай страницу до конца',
                            ),
                      onPressed: _markingRead
                          ? null
                          : reviewOnly
                          ? () {
                              if (_page + 1 == book.pages.length) {
                                Navigator.pop(context);
                              } else {
                                _go(_page + 1);
                              }
                            }
                          : ready
                          ? _quiz
                          : canNext
                          ? () => _go(_page + 1)
                          : null,
                      loading: _markingRead && !_quizOpen,
                      icon: ready
                          ? Icons.auto_awesome_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
