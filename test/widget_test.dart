import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PongApp smoke test renders main menu', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PongApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('THE PONG GAME!'), findsOneWidget);
    expect(find.text('Are you game?'), findsOneWidget);
    expect(find.text('1 PLAYER  (VS AI)'), findsOneWidget);
  });
}
