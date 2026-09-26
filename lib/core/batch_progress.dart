/// Persisted progress for one reading batch; closing a route grants no retries.
class BatchProgress {
  BatchProgress();
  factory BatchProgress.fromJson(Map<String, dynamic> json) => BatchProgress()
    ..readPages.addAll(List<int>.from(json['readPages'] as List? ?? []))
    ..attempts.addAll(List<int>.from(json['attempts'] as List? ?? []))
    ..correctQuestions.addAll(
      List<int>.from(json['correctQuestions'] as List? ?? []),
    )
    ..questionIndex = json['questionIndex'] as int? ?? 0
    ..errors = json['errors'] as int? ?? 0
    ..passed = json['passed'] as bool? ?? false
    ..needsReread = json['needsReread'] as bool? ?? false;

  static const maxAttempts = 2;
  static const maxErrors = 3;
  final Set<int> readPages = {};
  final List<int> attempts = [];
  final Set<int> correctQuestions = {};
  int questionIndex = 0, errors = 0;
  bool passed = false, needsReread = false;
  int get attemptsLeft =>
      maxAttempts -
      (questionIndex < attempts.length ? attempts[questionIndex] : 0);

  void recordAnswer({required bool correct, required int questionCount}) {
    if (passed || needsReread || questionIndex >= questionCount) {
      throw StateError('The quiz is not ready for an answer.');
    }
    while (attempts.length < questionCount) {
      attempts.add(0);
    }
    if (attemptsLeft <= 0) {
      throw StateError('No attempts remaining.');
    }
    attempts[questionIndex]++;
    if (correct) {
      correctQuestions.add(questionIndex);
    } else {
      errors++;
    }
    if (errors >= maxErrors) {
      reset();
      return;
    }
    if (correct || attemptsLeft == 0) {
      questionIndex++;
    }
    if (questionIndex == questionCount) {
      if (correctQuestions.length == questionCount) {
        passed = true;
      } else {
        reset();
      }
    }
  }

  void reset() {
    readPages.clear();
    attempts.clear();
    correctQuestions.clear();
    questionIndex = 0;
    errors = 0;
    passed = false;
    needsReread = true;
  }

  Map<String, dynamic> toJson() => {
    'readPages': readPages.toList(),
    'attempts': List<int>.from(attempts),
    'correctQuestions': correctQuestions.toList(),
    'questionIndex': questionIndex,
    'errors': errors,
    'passed': passed,
    'needsReread': needsReread,
  };
}

enum BatchAnswerOutcome { correct, wrong, exhausted, completed, reset }

class BatchAnswerResult {
  const BatchAnswerResult(this.outcome, {this.coins = 0});
  final BatchAnswerOutcome outcome;
  final int coins;
}
