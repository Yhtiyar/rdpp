import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
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
  bool _atBottom = false;
  AppController get c => widget.controller;
  Book get book => widget.book;
  @override
  void initState() {
    super.initState();
    _page = c.reading.position(book.id).clamp(0, book.pages.length - 1);
    _scroll.addListener(_checkBottom);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBottom());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkBottom() {
    if (!_scroll.hasClients || !mounted) {
      return;
    }
    if (_scroll.position.maxScrollExtent - _scroll.offset <= 36 && !_atBottom) {
      setState(() => _atBottom = true);
      c.markRead(book, _page);
    }
  }

  Future<void> _go(int page) async {
    if (page < 0 || page >= book.pages.length) {
      return;
    }
    setState(() {
      _page = page;
      _atBottom = false;
    });
    _scroll.jumpTo(0);
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
    final next = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(controller: c, book: book, page: _page),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    if (next == true) {
      if (_page + 1 < book.pages.length) {
        _go(_page + 1);
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
                  onTap: () {
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
  );
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
  );
  @override
  Widget build(BuildContext context) {
    final page = book.pages[_page];
    final complete = c.reading.isComplete(book.id, _page);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: c.tr('Back to books', 'К книгам'),
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: _settings,
                    icon: const Icon(
                      Icons.text_fields_rounded,
                      color: WinTheme.purple,
                    ),
                  ),
                  IconButton(
                    tooltip: c.tr('Contents', 'Оглавление'),
                    onPressed: _contents,
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
                        '${(c.reading.completedCount(book.id) / book.pages.length * 100).round()}%',
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
                          c.reading.completedCount(book.id) / book.pages.length,
                      minHeight: 7,
                      backgroundColor: WinTheme.lavender,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _checkBottom(),
                  );
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                                      onPressed: () => Navigator.pop(context),
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
                        onPressed: _page > 0 ? () => _go(_page - 1) : null,
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
                        onPressed: _page + 1 < book.pages.length
                            ? () => _go(_page + 1)
                            : null,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                  if (complete)
                    WinButton(
                      c.tr(
                        _page + 1 == book.pages.length
                            ? 'Back to my books'
                            : 'Next page',
                        _page + 1 == book.pages.length
                            ? 'К моим книгам'
                            : 'Следующая страница',
                      ),
                      onPressed: () {
                        if (_page + 1 == book.pages.length) {
                          Navigator.pop(context);
                        } else {
                          _go(_page + 1);
                        }
                      },
                      icon: Icons.check_rounded,
                    )
                  else
                    WinButton(
                      _atBottom
                          ? c.tr(
                              'Check understanding  ·  +10 coins',
                              'Ответить на вопрос  ·  +10 монет',
                            )
                          : c.tr(
                              'Read to the end of this page',
                              'Дочитай страницу до конца',
                            ),
                      onPressed: _atBottom ? _quiz : null,
                      icon: _atBottom
                          ? Icons.auto_awesome_rounded
                          : Icons.south_rounded,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
