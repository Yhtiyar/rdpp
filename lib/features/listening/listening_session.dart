import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/local_store.dart';
import 'listening_book.dart';
import 'narration_player.dart';

enum ListeningPhase { page, question, complete }

class ListeningSession extends ChangeNotifier {
  ListeningSession({
    required this.book,
    required this.player,
    required this.store,
  });
  final ListeningBook book;
  final NarrationPlayer player;
  final LocalStore store;
  ListeningPhase phase = ListeningPhase.page;
  int pageIndex = 0, questionIndex = 0, attempts = 0;
  int? selected;
  String clipKind = 'prompt';
  final Set<int> heardPages = {};
  final Map<String, bool> answers = {};
  bool isPlaying = false, loading = false, promptHeard = false;
  bool autoAdvance = true, captions = false, completedEver = false;
  bool audioError = false, storageError = false, restored = false;
  Duration position = Duration.zero, duration = Duration.zero;
  Timer? _turn;
  int _epoch = 0, _savedSecond = -1;
  bool _disposed = false, loaded = false, loadError = false;
  Map<String, dynamic> _all = {};
  Future<void> _saving = Future.value();

  ListeningPage get page => book.pages[pageIndex];
  ListeningQuestion get question => book.questions[questionIndex];
  bool get waitingForTurn => _turn?.isActive ?? false;
  bool get guided => attempts >= 2;
  bool get canAnswer =>
      phase == ListeningPhase.question &&
      promptHeard &&
      !isPlaying &&
      !loading &&
      clipKind != 'feedback' &&
      !audioError;

  bool canAnswerChoice(int choice) {
    if (phase != ListeningPhase.question ||
        choice < 0 ||
        choice >= question.choices.length) {
      return false;
    }
    // Guidance already reveals the answer. Honor a tap on its green picture
    // immediately, even while the voice is still explaining what to tap.
    return canAnswer ||
        (guided &&
            clipKind == 'guided' &&
            choice == question.answer &&
            !audioError);
  }

  bool get canNext =>
      phase == ListeningPhase.page && heardPages.contains(pageIndex);
  String get audio => switch (phase) {
    ListeningPhase.page => page.audio,
    ListeningPhase.question => question.audio[clipKind]!,
    ListeningPhase.complete => book.completionAudio,
  };
  String get spokenText => switch (phase) {
    ListeningPhase.page => page.text,
    ListeningPhase.question => question.textFor(clipKind),
    ListeningPhase.complete => book.completionText,
  };

  Future<void> load() async {
    if (_disposed) return;
    try {
      final stored = await store.read();
      if (_disposed) return;
      _all = stored ?? {};
      loaded = true;
      loadError = false;
      final raw = _all[book.id];
      if (raw is! Map || raw['version'] != book.version) return;
      restored = true;
      final data = Map<String, dynamic>.from(raw);
      pageIndex = (data['page'] as int? ?? 0).clamp(0, book.pages.length - 1);
      questionIndex = (data['question'] as int? ?? 0).clamp(
        0,
        book.questions.length - 1,
      );
      phase = ListeningPhase.values.firstWhere(
        (p) => p.name == data['phase'],
        orElse: () => ListeningPhase.page,
      );
      heardPages.addAll(
        (data['heard'] as List? ?? []).whereType<int>().where(
          (p) => p >= 0 && p < book.pages.length,
        ),
      );
      answers.addAll(Map<String, bool>.from(data['answers'] as Map? ?? {}));
      attempts = (data['attempts'] as int? ?? 0).clamp(0, 2);
      clipKind = data['clipKind'] as String? ?? 'prompt';
      if (!['prompt', 'hint', 'guided', 'feedback'].contains(clipKind)) {
        clipKind = 'prompt';
      }
      promptHeard = data['promptHeard'] as bool? ?? false;
      position = Duration(
        milliseconds: (data['positionMs'] as int? ?? 0).clamp(0, 300000),
      );
      autoAdvance = data['autoAdvance'] as bool? ?? true;
      captions = data['captions'] as bool? ?? false;
      completedEver = data['completedEver'] as bool? ?? false;
      if (phase == ListeningPhase.question) {
        pageIndex = question.afterPage;
        if (clipKind == 'feedback') selected = question.answer;
      }
    } catch (_) {
      loadError = true;
    }
    _notify();
  }

  Map<String, dynamic> _snapshot() => {
    'version': book.version,
    'phase': phase.name,
    'page': pageIndex,
    'question': questionIndex,
    'heard': heardPages.toList(),
    'answers': answers,
    'attempts': attempts,
    'clipKind': clipKind,
    'promptHeard': promptHeard,
    'positionMs': position.inMilliseconds,
    'autoAdvance': autoAdvance,
    'captions': captions,
    'completedEver': completedEver,
  };

  Future<void> persist() {
    if (!loaded) return Future<void>.value();
    _all[book.id] = _snapshot();
    final value = jsonDecode(jsonEncode(_all)) as Map<String, dynamic>;
    _saving = _saving.then((_) async {
      try {
        await store.write(value);
        storageError = false;
      } catch (_) {
        storageError = true;
      }
      _notify();
    });
    return _saving;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _cancel() {
    ++_epoch;
    _turn?.cancel();
    _turn = null;
    isPlaying = false;
    loading = false;
    unawaited(player.stop());
  }

  void play({bool replay = false}) {
    if (_disposed || !loaded) return;
    _cancel();
    if (replay || (duration > Duration.zero && position >= duration)) {
      position = Duration.zero;
    }
    if (replay && phase == ListeningPhase.question && clipKind != 'feedback') {
      clipKind = guided ? 'guided' : 'prompt';
    }
    audioError = false;
    isPlaying = true;
    loading = true;
    final epoch = _epoch;
    bool active() => !_disposed && epoch == _epoch && isPlaying;
    _notify();
    unawaited(
      player
          .start(
            audio,
            position: position,
            onPosition: (value) {
              if (!active()) return;
              position = value;
              if (value.inSeconds ~/ 2 != _savedSecond) {
                _savedSecond = value.inSeconds ~/ 2;
                unawaited(persist());
              }
              _notify();
            },
            onDuration: (value) {
              if (active()) {
                duration = value;
                _notify();
              }
            },
            onComplete: () {
              if (active()) _finished();
            },
            onError: (_) {
              if (!active()) return;
              _cancel();
              audioError = true;
              unawaited(persist());
              _notify();
            },
          )
          .then((_) {
            if (active()) {
              loading = false;
              _notify();
            }
          }),
    );
  }

  void pause() {
    if (_disposed) return;
    _cancel();
    unawaited(persist());
    _notify();
  }

  void _finished() {
    isPlaying = false;
    loading = false;
    position = Duration.zero;
    if (phase == ListeningPhase.page) {
      heardPages.add(pageIndex);
      if (autoAdvance) {
        final epoch = _epoch;
        _turn = Timer(const Duration(milliseconds: 1200), () {
          if (!_disposed && epoch == _epoch) next();
        });
      }
    } else if (phase == ListeningPhase.question) {
      if (clipKind == 'feedback') {
        _advanceQuestion();
        return;
      }
      promptHeard = true;
    }
    unawaited(persist());
    _notify();
  }

  void _resetClip() {
    position = Duration.zero;
    duration = Duration.zero;
    audioError = false;
    _savedSecond = -1;
  }

  void next() {
    if (_disposed || !canNext) return;
    _cancel();
    _resetClip();
    final index = book.questions.indexWhere((q) => q.afterPage == pageIndex);
    if (index >= 0) {
      // A replay is another chance to play, including previously answered games.
      for (final question in book.questions.where(
        (q) => q.afterPage == pageIndex,
      )) {
        answers.remove(question.id);
      }
      phase = ListeningPhase.question;
      questionIndex = index;
      _resetQuestion();
    } else if (pageIndex < book.pages.length - 1) {
      pageIndex++;
    } else {
      phase = ListeningPhase.complete;
      completedEver = true;
    }
    unawaited(persist());
    play();
  }

  void previous() {
    if (_disposed || phase != ListeningPhase.page || pageIndex == 0) return;
    _cancel();
    _resetClip();
    pageIndex--;
    unawaited(persist());
    play();
  }

  void _resetQuestion() {
    attempts = 0;
    selected = null;
    promptHeard = false;
    clipKind = 'prompt';
  }

  void answer(int choice) {
    if (!canAnswerChoice(choice)) return;
    selected = choice;
    if (choice == question.answer) {
      answers[question.id] = guided;
      clipKind = 'feedback';
    } else {
      attempts = (attempts + 1).clamp(0, 2);
      clipKind = guided ? 'guided' : 'hint';
    }
    promptHeard = false;
    _resetClip();
    unawaited(persist());
    play();
  }

  void _advanceQuestion() {
    _cancel();
    _resetClip();
    if (questionIndex + 1 < book.questions.length &&
        book.questions[questionIndex + 1].afterPage == pageIndex) {
      questionIndex++;
      _resetQuestion();
    } else if (pageIndex + 1 < book.pages.length) {
      pageIndex++;
      phase = ListeningPhase.page;
      _resetQuestion();
    } else {
      phase = ListeningPhase.complete;
      completedEver = true;
    }
    unawaited(persist());
    play();
  }

  void setOptions({bool? turnPages, bool? showCaptions}) {
    if (turnPages != null) autoAdvance = turnPages;
    if (showCaptions != null) captions = showCaptions;
    unawaited(persist());
    _notify();
  }

  void restart() {
    _cancel();
    _resetClip();
    _resetQuestion();
    phase = ListeningPhase.page;
    pageIndex = 0;
    questionIndex = 0;
    heardPages.clear();
    answers.clear();
    unawaited(persist());
    play();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _cancel();
    unawaited(persist());
    _disposed = true;
    player.dispose();
    super.dispose();
  }
}
