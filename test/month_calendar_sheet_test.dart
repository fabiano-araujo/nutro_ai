import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:nutro_ai/widgets/month_calendar_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('keeps month paging anchored when moving forward and back',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final visibleMonths = <DateTime>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendarSheet(
            selectedDate: DateTime(2026, 5, 15),
            hasMeals: (_) => false,
            onDaySelected: (_) {},
            onVisibleMonthChanged: visibleMonths.add,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(
      visibleMonths.map((date) => DateTime(date.year, date.month)).toList(),
      [
        DateTime(2026, 5),
        DateTime(2026, 6),
        DateTime(2026, 5),
        DateTime(2026, 6),
      ],
    );
  });

  test('uses server summaries when checking if a date has meals', () async {
    SharedPreferences.setMockInitialValues({
      'daily_meal_summaries': jsonEncode({
        '2026-05-10': {
          'totalCalories': 450,
          'totalProtein': 28,
          'totalCarbs': 45,
          'totalFat': 12,
          'totalFiber': 5,
          'waterGlasses': 0,
          'waterGoal': 8,
          'goals': {
            'calories': 2000,
            'protein': 150,
            'carbs': 250,
            'fat': 67,
          },
          'hitProtein': false,
          'hitCalories': false,
          'hasMealData': true,
        },
      }),
    });

    final provider = DailyMealsProvider();
    await provider.ready;

    expect(provider.hasMealsOn(DateTime(2026, 5, 10)), isTrue);
    expect(provider.hasMealsOn(DateTime(2026, 5, 11)), isFalse);
  });
}
