import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/ui/mimi_reading.dart';

void main() {
  Widget scene({bool reduce = false, bool enabled = true}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: TickerMode(enabled: enabled, child: const MiMiReading()),
    ),
  );
  AnimationController cycle(WidgetTester t) =>
      t
              .widget<AnimatedBuilder>(
                find.byKey(const ValueKey('reading-cycle')),
              )
              .animation
          as AnimationController;

  testWidgets(
    'one coordinated five-second loop repeats without a second timer',
    (t) async {
      await t.pumpWidget(scene());
      await t.pump();
      await t.pump(const Duration(milliseconds: 2300));
      expect(cycle(t).value, closeTo(.46, .001));
      expect(cycle(t).duration, const Duration(seconds: 5));
      await t.pump(const Duration(seconds: 5));
      expect(cycle(t).value, closeTo(.46, .001));
      await t.pumpWidget(const SizedBox());
      expect(t.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('ordinary rebuilds preserve the pose and cadence', (t) async {
    await t.pumpWidget(scene());
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(scene());
    expect(cycle(t).value, closeTo(.4, .001));
    await t.pump(const Duration(milliseconds: 500));
    expect(cycle(t).value, closeTo(.5, .001));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion and disabled tickers stop the whole rig', (
    t,
  ) async {
    for (final reduced in [true, false]) {
      await t.pumpWidget(scene(reduce: reduced, enabled: reduced));
      await t.pump(const Duration(seconds: 12));
      expect(t.hasRunningAnimations, isFalse);
      expect(cycle(t).value, 0);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'hiding during a turn cancels motion and resuming restarts safely',
    (t) async {
      await t.pumpWidget(scene());
      await t.pump(const Duration(milliseconds: 2500));
      expect(t.hasRunningAnimations, isTrue);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await t.pump(const Duration(seconds: 12));
      expect(t.hasRunningAnimations, isFalse);
      expect(cycle(t).value, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(cycle(t).value, closeTo(.2, .001));
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a covered route pauses and resets the entire scene', (t) async {
    await t.pumpWidget(scene());
    await t.pump(const Duration(seconds: 1));
    final context = t.element(find.byType(MiMiReading));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered')),
      ),
    );
    await t.pumpAndSettle();
    expect(t.hasRunningAnimations, isFalse);
    Navigator.of(context).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpWidget(const SizedBox());
  });
}
