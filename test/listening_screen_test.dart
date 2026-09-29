import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/features/listening/listening_screen.dart';
import 'package:readapp/features/listening/listening_book.dart';
import 'package:readapp/features/listening/listening_session.dart';
import 'package:readapp/ui/theme.dart';

import 'listening_session_test.dart' as fixture;

void main() {
  testWidgets(
    'start from beginning resets the run and plays after closing options',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final book = fixture.fixture();
      final audio = fixture.FakeNarration();
      final otherBook = {'page': 4, 'completedEver': true};
      final store = fixture.MemoryListeningStore()
        ..data = {
          'other-book': otherBook,
          book.id: {
            'version': book.version,
            'phase': 'question',
            'page': 2,
            'question': 1,
            'heard': [0, 1, 2],
            'answers': {book.questions.first.id: false},
            'attempts': 2,
            'clipKind': 'guided',
            'positionMs': 3000,
            'completedEver': true,
            'autoAdvance': false,
            'captions': true,
          },
        };
      final session = ListeningSession(book: book, player: audio, store: store);
      await tester.pumpWidget(
        MaterialApp(
          theme: WinTheme.data,
          home: ListeningScreen(book: book, session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Listening options'));
      await tester.pumpAndSettle();
      final restart = find.text('Start from beginning');
      expect(restart, findsOneWidget);
      await tester.ensureVisible(restart);
      await tester.tap(restart);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BottomSheet), findsNothing);
      expect(session.phase, ListeningPhase.page);
      expect(session.pageIndex, 0);
      expect(session.questionIndex, 0);
      expect(session.position, Duration.zero);
      expect(session.attempts, 0);
      expect(session.heardPages, isEmpty);
      expect(session.answers, isEmpty);
      expect(session.isPlaying, isTrue);
      expect(session.canNext, isFalse);
      expect(session.completedEver, isTrue);
      expect(session.autoAdvance, isFalse);
      expect(session.captions, isTrue);
      expect(audio.played, [book.pages.first.audio]);
      expect(store.data!['other-book'], otherBook);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'should accept one tap on the green picture while guidance is speaking',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final book = fixture.fixture();
        final question = book.questions.first;
        final audio = fixture.FakeNarration();
        final store = fixture.MemoryListeningStore()
          ..data = {
            book.id: {
              'version': book.version,
              'phase': 'question',
              'page': question.afterPage,
              'question': 0,
              'heard': [0, 1, 2],
              'promptHeard': true,
            },
          };
        final session = ListeningSession(
          book: book,
          player: audio,
          store: store,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: WinTheme.data,
            home: ListeningScreen(book: book, session: session),
          ),
        );
        await tester.pumpAndSettle();
        final wrong = find.bySemanticsLabel(
          question.choices[1 - question.answer].label,
        );
        await tester.tap(wrong);
        await tester.pump();
        audio.finish!();
        await tester.pump();
        await tester.tap(wrong);
        await tester.pump();
        expect(session.clipKind, 'guided');
        expect(session.isPlaying, isTrue);

        await tester.tap(
          find.bySemanticsLabel(question.choices[question.answer].label),
        );
        await tester.pump();
        expect(session.clipKind, 'feedback');
        expect(session.answers[question.id], isTrue);
        audio.finish!();
        await tester.pump();
        expect(session.questionIndex, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'compact listening page offers large pause/replay controls and no skip before hearing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = fixture.FakeNarration();
      final session = ListeningSession(
        book: fixture.fixture(),
        player: audio,
        store: fixture.MemoryListeningStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: WinTheme.data,
          home: ListeningScreen(book: session.book, session: session),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Pause story'), findsOneWidget);
      expect(find.byTooltip('Replay page'), findsOneWidget);
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_forward_rounded),
      );
      expect(next.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Pause story'));
      await tester.pump();
      expect(find.byTooltip('Play story'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('covering a story pauses narration and returning stays paused', (
    tester,
  ) async {
    final audio = fixture.FakeNarration();
    final session = ListeningSession(
      book: fixture.fixture(),
      player: audio,
      store: fixture.MemoryListeningStore(),
    );
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: ListeningScreen(book: session.book, session: session),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(session.isPlaying, isTrue);
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(session.isPlaying, isFalse);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(session.isPlaying, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'repeated entry taps while catalog loads push only one listening route',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      late BuildContext entryContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Builder(
            builder: (context) {
              entryContext = context;
              return const Scaffold(body: Text('Library'));
            },
          ),
        ),
      );
      final pending = Completer<List<ListeningBook>>();
      var loads = 0;
      Future<List<ListeningBook>> load() {
        loads++;
        return pending.future;
      }

      final first = openListeningBook(
        entryContext,
        'frog',
        loadBooks: load,
        sessionFactory: (book) => ListeningSession(
          book: book,
          player: fixture.FakeNarration(),
          store: fixture.MemoryListeningStore(),
        ),
      );
      final second = openListeningBook(
        entryContext,
        'frog',
        loadBooks: load,
        sessionFactory: (book) => ListeningSession(
          book: book,
          player: fixture.FakeNarration(),
          store: fixture.MemoryListeningStore(),
        ),
      );
      expect(loads, 1);
      pending.complete([fixture.fixture()]);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ListeningScreen), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await first;
      await second;
    },
  );
  testWidgets(
    'a delayed load that finishes behind another route stays silent',
    (tester) async {
      final store = fixture.DelayedListeningStore();
      final audio = fixture.FakeNarration();
      final session = ListeningSession(
        book: fixture.fixture(),
        player: audio,
        store: store,
      );
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: ListeningScreen(book: session.book, session: session),
        ),
      );
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      store.result.complete(null);
      await tester.pump();
      await tester.pump();
      expect(audio.played, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
