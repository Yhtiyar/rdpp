import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/core/batch_progress.dart';
import 'package:readapp/core/sound_service.dart';
import 'package:readapp/features/reading/quiz_feedback_panel.dart';
import 'package:readapp/ui/celebration.dart';
import 'package:readapp/ui/components.dart';
import 'package:readapp/ui/motion_spec.dart';

void main() {
  group('Accessible feedback', () {
    testWidgets(
      'should preserve optional motion when accessibility navigation is enabled without reduced motion',
      (t) async {
        await t.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                accessibleNavigation: true,
                disableAnimations: false,
              ),
              child: Text('Accessible'),
            ),
          ),
        );
        expect(
          MotionSpec.of(t.element(find.text('Accessible'))).reduceMotion,
          isFalse,
        );
      },
    );

    testWidgets(
      'should keep Russian feedback and keyboard action reachable at 200 percent',
      (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var next = 0;
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: SceneScaffold(
                bottom: QuizFeedbackPanel(
                  outcome: BatchAnswerOutcome.correct,
                  message: 'Правильно! Ты заметил эту деталь! Здесь объяснение из истории.',
                  actionLabel: 'Следующий вопрос',
                  onContinue: () => next++,
                ),
                child: const Text(
                  'Вопрос и варианты остаются доступны при прокрутке.',
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final semantics = t
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.liveRegion == true);
        expect(semantics.length, 1);
        final action = find.text('Следующий вопрос');
        expect(t.getRect(action).bottom, lessThanOrEqualTo(640));
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(next, 1);
      },
    );
    testWidgets('should run no particle ticker under reduced motion', (
      t,
    ) async {
      await t.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Celebration(child: Text('Saved')),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 20));
      expect(t.hasRunningAnimations, isFalse);
      final context = t.element(find.text('Saved'));
      expect(MotionSpec.of(context).reward, Duration.zero);
    });
    testWidgets('should stay silent when created while the app is hidden', (
      t,
    ) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      var calls = 0;
      final sounds = SoundService(
        playback: (asset) async {
          calls++;
        },
      );
      await sounds.playCue(FeedbackCue.correct, enabled: true);
      expect(calls, 0);
      await sounds.dispose();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    testWidgets('should keep muted and blocked audio optional', (t) async {
      var calls = 0;
      final sounds = SoundService(
        playback: (asset) async {
          calls++;
          throw StateError('browser blocked');
        },
      );
      await sounds.playCue(FeedbackCue.correct, enabled: false);
      expect(calls, 0);
      await sounds.playCue(FeedbackCue.correct, enabled: true);
      expect(calls, 1);
      expect(t.takeException(), isNull);
      await sounds.dispose();
    });
  });
}
