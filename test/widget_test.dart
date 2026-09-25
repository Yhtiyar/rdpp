import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/app.dart';
import 'package:readapp/core/app_controller.dart';
import 'package:readapp/core/local_store.dart';

class MemoryStore implements LocalStore {
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    data = value;
  }
}

void main() {
  group('LittlewinsApp', () {
    testWidgets('should show the supplied welcome flow and age choices', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController(MemoryStore());
      await tester.pumpWidget(LittlewinsApp(controller: c));
      expect(find.text('Little steps.\nReal growth.'), findsOneWidget);
      await tester.tap(find.text('Set up for my child'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Choose your child’s age'), findsOneWidget);
      expect(find.text('Ages 4–6'), findsOneWidget);
    });
  });
}
