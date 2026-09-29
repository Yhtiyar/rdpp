import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/local_store.dart';
import 'package:readapp/features/listening/listening_book.dart';
import 'package:readapp/features/listening/listening_session.dart';
import 'package:readapp/features/listening/narration_player.dart';

class MemoryListeningStore implements LocalStore {
  Map<String, dynamic>? data;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('disk full');
    data = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }
}

class DelayedListeningStore extends MemoryListeningStore {
  final result = Completer<Map<String, dynamic>?>();
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> read() => result.future;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    writes++;
    await super.write(value);
  }
}

class FakeNarration implements NarrationPlayer {
  void Function()? finish;
  void Function(Duration)? tick;
  void Function(Object)? fail;
  final List<String> played = [];
  int stops = 0;
  @override
  Future<void> start(
    String asset, {
    required Duration position,
    required void Function(Duration) onPosition,
    required void Function(Duration) onDuration,
    required void Function() onComplete,
    required void Function(Object) onError,
  }) async {
    played.add(asset);
    finish = onComplete;
    tick = onPosition;
    fail = onError;
    onDuration(const Duration(seconds: 20));
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  void dispose() {}
}

ListeningBook fixture() => ListeningBook.fromJson(
  (jsonDecode(
        File('assets/toddler/catalog.json').readAsStringSync(),
      ) as List).first
      as Map<String, dynamic>,
);
Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MemoryListeningStore store;
  late FakeNarration audio;
  late ListeningSession s;
  setUp(() async {
    store = MemoryListeningStore();
    audio = FakeNarration();
    s = ListeningSession(book: fixture(), player: audio, store: store);
    await s.load();
    s.autoAdvance = false;
  });
  tearDown(() => s.dispose());
  Future<void> reachQuestion() async {
    for (var i = 0; i < 3; i++) {
      s.play();
      await flush();
      audio.finish!();
      await flush();
      s.next();
      await flush();
    }
  }

  test('page turns require completed audio; stale completion after pause does nothing', () async {
    s.next();
    expect(s.pageIndex, 0);
    s.play();
    await flush();
    final stale = audio.finish!;
    audio.tick!(const Duration(seconds: 6));
    s.pause();
    stale();
    await flush();
    expect(s.heardPages, isEmpty);
    expect(s.pageIndex, 0);
    expect(s.isPlaying, isFalse);
    s.play();
    await flush();
    audio.finish!();
    await flush();
    expect(s.heardPages, {0});
    s.next();
    expect(s.pageIndex, 1);
  });
  test(
    'picture answers unlock after prompt; two misses guide without punishment',
    () async {
      await reachQuestion();
      expect(s.phase, ListeningPhase.question);
      s.answer(1);
      expect(s.attempts, 0);
      audio.finish!();
      await flush();
      expect(s.canAnswer, isTrue);
      s.answer(1);
      await flush();
      expect(s.clipKind, 'hint');
      expect(s.canAnswer, isFalse);
      audio.finish!();
      await flush();
      s.answer(1);
      await flush();
      expect(s.clipKind, 'guided');
      audio.finish!();
      await flush();
      expect(s.guided, isTrue);
      s.answer(0);
      await flush();
      expect(s.answers[s.question.id], isTrue);
      audio.finish!();
      await flush();
      expect(s.questionIndex, 1);
      expect(s.phase, ListeningPhase.question);
    },
  );
  test('should accept the green answer during guidance and advance after one feedback', () async {
    await reachQuestion();
    audio.finish!();
    await flush();
    s.answer(1);
    await flush();
    audio.finish!();
    await flush();
    s.answer(1);
    await flush();
    expect(s.clipKind, 'guided');
    expect(s.isPlaying, isTrue);
    final lateGuidanceEnd = audio.finish!;
    final questionId = s.question.id;

    // The green picture is visible while the voice is still explaining it.
    s.answer(0);
    await flush();
    expect(s.clipKind, 'feedback');
    expect(s.answers[questionId], isTrue);
    final feedbackCount = audio.played.length;
    s.answer(0);
    lateGuidanceEnd();
    await flush();
    expect(audio.played.length, feedbackCount);
    expect(s.questionIndex, 0);
    expect(s.isPlaying, isTrue);

    audio.finish!();
    await flush();
    expect(s.questionIndex, 1);
    expect(s.clipKind, 'prompt');
    expect(s.answers, {questionId: true});
  });
  test(
    'restore preserves paused position and cannot create reading rewards',
    () async {
      s.play();
      await flush();
      audio.tick!(const Duration(seconds: 7));
      s.pause();
      await flush();
      final resumed = ListeningSession(
        book: fixture(),
        player: FakeNarration(),
        store: store,
      );
      await resumed.load();
      expect(resumed.position.inSeconds, 7);
      expect(resumed.isPlaying, isFalse);
      expect(store.data!.keys, ['frog']);
      expect(store.data!.toString(), isNot(contains('coins')));
      resumed.dispose();
    },
  );
  test(
    'revisiting a completed section requires both picture questions again',
    () async {
      await reachQuestion();
      for (var i = 0; i < 2; i++) {
        audio.finish!();
        await flush();
        s.answer(s.question.answer);
        await flush();
        audio.finish!();
        await flush();
      }
      expect(s.phase, ListeningPhase.page);
      expect(s.pageIndex, 3);
      expect(s.answers.length, 2);

      s.previous();
      s.next();
      await flush();
      expect(s.phase, ListeningPhase.question);
      expect(s.questionIndex, 0);
      expect(s.answers, isEmpty);
      expect(s.attempts, 0);
      expect(s.canAnswer, isFalse);
      s.next();
      expect(s.questionIndex, 0);

      audio.finish!();
      await flush();
      s.answer(s.question.answer);
      await flush();
      audio.finish!();
      await flush();
      expect(s.questionIndex, 1);
      expect(s.phase, ListeningPhase.question);

      // An interrupted repeat resumes at its second question, without skipping it.
      s.pause();
      await s.persist();
      final restoredAudio = FakeNarration();
      final restored = ListeningSession(
        book: s.book,
        player: restoredAudio,
        store: store,
      );
      await restored.load();
      expect(restored.questionIndex, 1);
      expect(restored.isPlaying, isFalse);
      restored.play();
      await flush();
      restoredAudio.finish!();
      await flush();
      restored.answer(restored.question.answer);
      await flush();
      restoredAudio.finish!();
      await flush();
      expect(restored.phase, ListeningPhase.page);
      expect(restored.pageIndex, 3);
      expect(restored.answers.length, 2);
      restored.dispose();
    },
  );
  test(
    'storage and audio failures remain recoverable and never auto advance',
    () async {
      store.fail = true;
      s.play();
      await flush();
      audio.fail!(StateError('decode'));
      await flush();
      expect(s.audioError, isTrue);
      expect(s.isPlaying, isFalse);
      expect(s.heardPages, isEmpty);
      s.play();
      await flush();
      audio.finish!();
      await flush();
      expect(s.storageError, isTrue);
      store.fail = false;
      await s.persist();
      expect(s.storageError, isFalse);
    },
  );
  test('late event after dispose cannot save or play another clip', () async {
    s.play();
    await flush();
    final stale = audio.finish!;
    s.dispose();
    stale();
    await flush();
    expect(audio.played.length, 1);
  });
  test(
    'closing or backgrounding during load never overwrites existing progress',
    () async {
      final delayed = DelayedListeningStore();
      delayed.data = {
        'kolobok': {'page': 4},
      };
      final session = ListeningSession(
        book: fixture(),
        player: FakeNarration(),
        store: delayed,
      );
      final loading = session.load();
      session.pause();
      session.dispose();
      await flush();
      expect(delayed.writes, 0);
      delayed.result.complete(delayed.data);
      await loading;
      expect(delayed.data, {
        'kolobok': {'page': 4},
      });
    },
  );

  test(
    'read failure prevents playback and writes until a successful retry',
    () async {
      final delayed = DelayedListeningStore();
      final player = FakeNarration();
      final session = ListeningSession(
        book: fixture(),
        player: player,
        store: delayed,
      );
      final loading = session.load();
      delayed.result.completeError(StateError('read failed'));
      await loading;
      session.play();
      session.pause();
      await session.persist();
      expect(player.played, isEmpty);
      expect(delayed.writes, 0);
      session.dispose();
    },
  );
  test('paused page-turn delay cannot move to another page', () async {
    s.autoAdvance = true;
    s.play();
    await flush();
    audio.finish!();
    expect(s.waitingForTurn, isTrue);
    s.pause();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(s.pageIndex, 0);
    expect(s.isPlaying, isFalse);
  });

  test(
    'restoring a hint remains paused and continues the same question',
    () async {
      await reachQuestion();
      audio.finish!();
      await flush();
      s.answer(1);
      await flush();
      audio.tick!(const Duration(seconds: 2));
      s.pause();
      await flush();
      final restoredAudio = FakeNarration();
      final restored = ListeningSession(
        book: fixture(),
        player: restoredAudio,
        store: store,
      );
      await restored.load();
      expect(restored.phase, ListeningPhase.question);
      expect(restored.clipKind, 'hint');
      expect(restored.attempts, 1);
      expect(restored.position.inSeconds, 2);
      expect(restored.isPlaying, isFalse);
      restored.play();
      await flush();
      restoredAudio.finish!();
      await flush();
      expect(restored.canAnswer, isTrue);
      restored.dispose();
    },
  );

  test(
    'a new text edition resets old positions and preserves other books',
    () async {
      final book = fixture();
      final otherBook = <String, dynamic>{
        'version': 1,
        'page': 4,
        'completedEver': true,
      };
      store.data = {
        book.id: {
          'version': book.version - 1,
          'phase': 'question',
          'page': 9,
          'question': 5,
          'heard': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          'answers': {'old-question': true},
          'positionMs': 7000,
        },
        'other-book': otherBook,
      };
      final updated = ListeningSession(
        book: book,
        player: FakeNarration(),
        store: store,
      );
      await updated.load();
      expect(updated.pageIndex, 0);
      expect(updated.phase, ListeningPhase.page);
      expect(updated.heardPages, isEmpty);
      expect(updated.answers, isEmpty);
      expect(updated.position, Duration.zero);
      await updated.persist();
      expect((store.data![book.id] as Map)['version'], book.version);
      expect(store.data!['other-book'], otherBook);
      updated.dispose();
    },
  );

  test(
    'complete story earns one durable star after every required question',
    () async {
      s.play();
      await flush();
      var turns = 0;
      final turnLimit = s.book.pages.length + s.book.questions.length * 2 + 5;
      while (s.phase != ListeningPhase.complete && turns++ < turnLimit) {
        if (s.phase == ListeningPhase.page) {
          audio.finish!();
          await flush();
          s.next();
        } else {
          audio.finish!();
          await flush();
          if (s.canAnswer) s.answer(s.question.answer);
        }
        await flush();
      }
      expect(s.phase, ListeningPhase.complete);
      expect(s.heardPages.length, s.book.pages.length);
      expect(s.answers.length, s.book.questions.length);
      expect(s.completedEver, isTrue);
      s.restart();
      await flush();
      expect(s.pageIndex, 0);
      expect(s.answers, isEmpty);
      expect(s.completedEver, isTrue);
    },
  );
}
