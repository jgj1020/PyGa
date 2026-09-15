import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/pyga_app.dart';

void main() {
  testWidgets('Login form rejects passwords shorter than eight characters', (tester) async {
    await tester.pumpWidget(const PyGaApp());
    expect(find.text('PyGa'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), '1234567');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '로그인'));
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pump();
    expect(find.text('비밀번호는 최소 8자입니다.'), findsOneWidget);
  });
}
