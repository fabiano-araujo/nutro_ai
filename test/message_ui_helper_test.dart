import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/message_ui_helper.dart';

void main() {
  testWidgets('typing indicator dots visibly move while the reply loads',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: MessageUIHelper.buildTypingIndicator(
              color: Colors.teal,
            ),
          ),
        ),
      ),
    );

    final firstDot = find.byKey(
      const ValueKey('typing_indicator_dot_0'),
    );
    final secondDot = find.byKey(
      const ValueKey('typing_indicator_dot_1'),
    );
    expect(firstDot, findsOneWidget);
    expect(secondDot, findsOneWidget);

    final initialFirstY =
        tester.widget<Transform>(firstDot).transform.getTranslation().y;
    final initialSecondY =
        tester.widget<Transform>(secondDot).transform.getTranslation().y;
    await tester.pump(const Duration(milliseconds: 180));
    final animatedFirstY =
        tester.widget<Transform>(firstDot).transform.getTranslation().y;
    final animatedSecondY =
        tester.widget<Transform>(secondDot).transform.getTranslation().y;

    expect(
      animatedFirstY != initialFirstY || animatedSecondY != initialSecondY,
      isTrue,
    );
  });
}
