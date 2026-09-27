import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/ui/mimi_reading_painter.dart';
import 'package:readapp/ui/mimi_reading_pose.dart';

void main() {
  // Real mesh vertices at the tip, rim, and base of each ear. MiMi's right ear
  // is on the left of the image and reaches the source artwork's top edge.
  const ears = [
    [(44, 0), (43, 1), (42, 3), (41, 5), (49, 6), (55, 12), (37, 20)],
    [(103, 18), (109, 19), (110, 24), (108, 33), (98, 37), (92, 28)],
  ];
  Offset vertex(Float32List points, (int, int) index) {
    final offset = (index.$2 * 129 + index.$1) * 2;
    return Offset(points[offset], points[offset + 1]);
  }

  test('both ears retain their shape throughout the entire reading loop', () {
    final rest = ReadingKittenPainter.bodyVertices(ReadingPose.at(0));
    for (var step = 0; step <= 200; step++) {
      final phase = step / 200;
      final moving = ReadingKittenPainter.bodyVertices(ReadingPose.at(phase));
      for (var ear = 0; ear < ears.length; ear++) {
        for (var a = 0; a < ears[ear].length; a++) {
          for (var b = a + 1; b < ears[ear].length; b++) {
            final original =
                (vertex(rest, ears[ear][a]) - vertex(rest, ears[ear][b]))
                    .distance;
            final current =
                (vertex(moving, ears[ear][a]) - vertex(moving, ears[ear][b]))
                    .distance;
            expect(
              current,
              closeTo(original, .001),
              reason:
                  'Ear $ear stretches at phase $phase between vertices $a and $b',
            );
          }
        }
      }
    }
  });

  test(
    'the right ear tip moves with the head instead of staying on the frame',
    () {
      final rest = ReadingKittenPainter.bodyVertices(ReadingPose.at(0));
      final turn = ReadingKittenPainter.bodyVertices(ReadingPose.at(.53));
      expect(
        (vertex(turn, ears.first.first) - vertex(rest, ears.first.first))
            .distance,
        greaterThan(10),
      );
    },
  );
}
