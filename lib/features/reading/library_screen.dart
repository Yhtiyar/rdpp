import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';
import 'book.dart';
import 'reader_screen.dart';

class LibraryContent extends StatefulWidget {
  const LibraryContent({super.key, required this.controller});
  final AppController controller;
  @override
  State<LibraryContent> createState() => _LibraryContentState();
}

class _LibraryContentState extends State<LibraryContent> {
  late String _language;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _language = c.locale;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Heading(
        c.tr(
          'A little reading.\nA world of wonder.',
          'Немного чтения.\nЦелый мир открытий.',
        ),
        large: true,
      ),
      smallGap,
      Text(
        c.tr(
          'Pick a story. Find your next little win.',
          'Выбери историю и сделай шаг вперёд.',
        ),
      ),
      const SizedBox(height: 24),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'en',
            label: Text(c.tr('English books', 'Книги на английском')),
          ),
          ButtonSegment(
            value: 'ru',
            label: Text(c.tr('Russian books', 'Книги на русском')),
          ),
        ],
        selected: {_language},
        onSelectionChanged: (v) => setState(() => _language = v.first),
        showSelectedIcon: false,
      ),
      const SizedBox(height: 22),
      ...c.books
          .where((b) => b.language == _language)
          .map((b) => BookTile(controller: c, book: b)),
      gap,
      SoftPanel(
        color: WinTheme.mint,
        child: Row(
          children: [
            const Art('mimi_face', width: 62, height: 65),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                c.tr(
                  'Big adventures are for every age. Read on your own or with a grown-up.',
                  'Большие приключения — для всех возрастов. Читай сам или со взрослым.',
                ),
                style: const TextStyle(
                  color: WinTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.controller, required this.book});
  final AppController controller;
  final Book book;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final count = c.reading.completedCount(book.id);
    final progress = count / book.pages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => openBook(context, c, book),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Image.asset(
                  book.cover,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      c.tr(
                        '${book.pages.length} pages',
                        '${book.pages.length} стр.',
                      ),
                      style: const TextStyle(
                        color: WinTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: Text(
                book.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: WinTheme.purple,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
        smallGap,
        Text(book.author),
        gap,
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: WinTheme.lavender,
          ),
        ),
        gap,
        WinButton(
          count == book.pages.length
              ? c.tr('Read again', 'Прочитать снова')
              : c.reading.position(book.id) > 0 || count > 0
              ? c.tr('Continue reading', 'Продолжить чтение')
              : c.tr('Open the story', 'Открыть историю'),
          onPressed: () => openBook(context, c, book),
          icon: Icons.auto_stories_rounded,
        ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(c.tr('About this book', 'Об этой книге')),
              content: SingleChildScrollView(child: Text(book.attribution)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(c.tr('Close', 'Закрыть')),
                ),
              ],
            ),
          ),
          child: Text(c.tr('Book credits', 'Об источнике книги')),
        ),
      ],
    );
  }
}

Future<void> openBook(
  BuildContext context,
  AppController controller,
  Book book,
) async {
  try {
    await controller.rememberBook(book.id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.error ??
                controller.tr(
                  'Could not save your place.',
                  'Не удалось сохранить место.',
                ),
          ),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ReaderScreen(controller: controller, book: book),
    ),
  );
}
