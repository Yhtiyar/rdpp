import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/ui/mimi_reading_pose.dart';

void main() {
  test('one five-second cycle returns to the same complete pose', () {
    final start = ReadingPose.at(0);
    final end = ReadingPose.at(1);
    expect(end.paw, start.paw);
    expect(end.headAngle, closeTo(start.headAngle, 1e-10));
    expect(end.headDrop, closeTo(start.headDrop, 1e-10));
    expect(end.breath, closeTo(start.breath, 1e-10));
    expect(end.tailAngle, closeTo(start.tailAngle, 1e-10));
    expect(end.blink, start.blink);
    expect(end.page, start.page);
  });

  test('paw carries the page until a small flick releases it', () {
    for (final phase in [.45, .47, .49, .51, .53]) {
      final pose = ReadingPose.at(phase);
      expect(pose.holdingPage, isTrue);
      expect((pose.fingertip - pose.pageTip).distance, lessThan(.001));
      expect(pose.headDrop, greaterThan(2));
      expect(pose.paw.dy, lessThan(230));
    }
    expect(ReadingPose.at(.72).holdingPage, isFalse);
    expect(ReadingPose.at(.8).paw.dy, greaterThan(240));
  });

  test('head, supporting paw, and tail move during reading', () {
    final a = ReadingPose.at(.03);
    final b = ReadingPose.at(.2);
    expect(a.headAngle, isNot(b.headAngle));
    expect(a.support, isNot(b.support));
    expect(a.tailAngle, isNot(b.tailAngle));
  });

  test('no discontinuities at reach, contact, release, or loop boundaries', () {
    for (var i = 1; i <= 1000; i++) {
      final previous = ReadingPose.at((i - 1) / 1000);
      final next = ReadingPose.at(i / 1000);
      expect((next.paw - previous.paw).distance, lessThan(2));
      expect((next.headAngle - previous.headAngle).abs(), lessThan(.003));
      expect((next.headDrop - previous.headDrop).abs(), lessThan(.2));
    }
  });
}
