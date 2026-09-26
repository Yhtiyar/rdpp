import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/ui/mimi_reading.dart';

void main() {
  group('MiMiReading', () {
    Widget scene({bool reduce = false, bool enabled = true}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: TickerMode(enabled: enabled, child: const MiMiReading()),
      ),
    );
    double turn(WidgetTester t) =>
        t
                .widget<AnimatedBuilder>(
                  find.byKey(const ValueKey('reading-page-turn')),
                )
                .animation
            is Animation<double>
        ? (t
                      .widget<AnimatedBuilder>(
                        find.byKey(const ValueKey('reading-page-turn')),
                      )
                      .animation
                  as Animation<double>)
              .value
        : -1;

    testWidgets(
      'should use the welcome kitten and turn one page every five seconds',
      (t) async {
        await t.pumpWidget(scene());
        expect(
          (t.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
          'assets/art/mimi_reading.webp',
        );
        await t.pump(const Duration(milliseconds: 4900));
        expect(turn(t), 0);
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 350));
        expect(turn(t), inExclusiveRange(0, 1));
        await t.pump(const Duration(milliseconds: 650));
        expect(turn(t), 1);
        await t.pump(const Duration(milliseconds: 3999));
        expect(t.hasRunningAnimations, isFalse);
        await t.pump(const Duration(milliseconds: 1));
        await t.pump(const Duration(milliseconds: 350));
        expect(turn(t), inExclusiveRange(0, 1));
        await t.pumpWidget(const SizedBox());
      },
    );
    testWidgets('should preserve the cadence through ordinary rebuilds', (
      t,
    ) async {
      await t.pumpWidget(scene());
      await t.pump(const Duration(seconds: 4));
      await t.pumpWidget(scene());
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 350));
      expect(turn(t), inExclusiveRange(0, 1));
      await t.pumpWidget(const SizedBox());
    });
    testWidgets('should stay still with reduced motion or hidden tickers', (
      t,
    ) async {
      for (final reduced in [true, false]) {
        await t.pumpWidget(scene(reduce: reduced, enabled: reduced));
        await t.pump(const Duration(seconds: 12));
        expect(t.hasRunningAnimations, isFalse);
        expect(turn(t), anyOf(0, 1));
        await t.pumpWidget(const SizedBox());
      }
    });
    testWidgets(
      'should cancel turns when app hides and restart the interval when resumed',
      (t) async {
        await t.pumpWidget(scene());
        await t.pump(const Duration(seconds: 5));
        await t.pump(const Duration(milliseconds: 350));
        expect(turn(t), inExclusiveRange(0, 1));
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await t.pump(const Duration(seconds: 12));
        expect(t.hasRunningAnimations, isFalse);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pump(const Duration(seconds: 4));
        expect(t.hasRunningAnimations, isFalse);
        await t.pumpWidget(const SizedBox());
      },
    );
  });
}
