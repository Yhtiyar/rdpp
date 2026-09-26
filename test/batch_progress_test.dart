import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/batch_progress.dart';

void main() {
  group('BatchProgress', () {
    test('should allow two attempts and move past an exhausted question', () {
      final p = BatchProgress();
      p.recordAnswer(correct: false, questionCount: 4);
      expect(p.questionIndex, 0);
      expect(p.attemptsLeft, 1);
      p.recordAnswer(correct: false, questionCount: 4);
      expect(p.questionIndex, 1);
      expect(p.errors, 2);
      expect(p.passed, isFalse);
    });
    test('should preserve attempts and reset the batch on its third error', () {
      final p = BatchProgress()..readPages.addAll([3, 4, 5]);
      p.recordAnswer(correct: false, questionCount: 4);
      final restored = BatchProgress.fromJson(p.toJson());
      expect(restored.attemptsLeft, 1);
      restored.recordAnswer(correct: false, questionCount: 4);
      restored.recordAnswer(correct: false, questionCount: 4);
      expect(restored.needsReread, isTrue);
      expect(restored.readPages, isEmpty);
      expect(restored.errors, 0);
      expect(restored.questionIndex, 0);
    });
    test(
      'should require all questions to pass and reset an exhausted quiz',
      () {
        final p = BatchProgress();
        p.recordAnswer(correct: false, questionCount: 4);
        p.recordAnswer(correct: false, questionCount: 4);
        for (var i = 0; i < 3; i++) {
          p.recordAnswer(correct: true, questionCount: 4);
        }
        expect(p.passed, isFalse);
        expect(p.needsReread, isTrue);
      },
    );
    test(
      'should pass after four correct answers, including a corrected answer',
      () {
        final p = BatchProgress();
        p.recordAnswer(correct: false, questionCount: 4);
        for (var i = 0; i < 4; i++) {
          p.recordAnswer(correct: true, questionCount: 4);
        }
        expect(p.passed, isTrue);
        expect(p.errors, 1);
        expect(BatchProgress.fromJson(p.toJson()).passed, isTrue);
      },
    );
  });
}
