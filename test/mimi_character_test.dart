import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/ui/mimi_character.dart';

void main() {
  group('MiMiCharacter', () {
    Widget scene(MiMiMood mood, {int id = 1, bool reduce = false}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: MiMiCharacter(mood: mood, size: 64, reactionId: id),
          ),
        );
    String asset(WidgetTester t) =>
        (t.widget<Image>(find.byKey(const ValueKey('mimi-frame'))).image
                as AssetImage)
            .assetName;
    testWidgets('should render each mood immediately with reduced motion', (
      t,
    ) async {
      for (final mood in MiMiMood.values) {
        await t.pumpWidget(scene(mood, reduce: true));
        expect(asset(t), contains('${mood.name}.webp'));
        expect(t.hasRunningAnimations, isFalse);
      }
    });
    testWidgets(
      'should animate a distinct frame sequence for celebration and encouragement',
      (t) async {
        for (final mood in [MiMiMood.celebrating, MiMiMood.encouraging]) {
          await t.pumpWidget(scene(mood, id: mood.index));
          final first = asset(t);
          await t.pump(const Duration(milliseconds: 300));
          expect(asset(t), isNot(first));
          await t.pump(const Duration(seconds: 1));
          expect(asset(t), contains('${mood.name}.webp'));
        }
      },
    );
    testWidgets(
      'should blink once for a new reaction and not replay on rebuild',
      (t) async {
        await t.pumpWidget(scene(MiMiMood.proud));
        await t.pump(const Duration(milliseconds: 260));
        expect(asset(t), contains('proud_blink'));
        await t.pump(const Duration(seconds: 1));
        await t.pumpWidget(scene(MiMiMood.proud));
        await t.pump(const Duration(milliseconds: 260));
        expect(asset(t), contains('proud.webp'));
        await t.pumpWidget(scene(MiMiMood.proud, id: 2));
        await t.pump(const Duration(milliseconds: 260));
        expect(asset(t), contains('proud_blink'));
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      },
    );
  });
}
