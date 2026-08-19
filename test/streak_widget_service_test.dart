import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/streak_widget_service.dart';

void main() {
  group('StreakWidgetSnapshot', () {
    test('serializes the current day, calories, goal and streak', () {
      final snapshot = StreakWidgetSnapshot(
        calories: 845,
        calorieGoal: 2100,
        streak: 3,
        date: DateTime(2026, 8, 11, 22, 30),
      );

      expect(snapshot.toPlatformMap(), {
        'calories': 845,
        'calorieGoal': 2100,
        'streak': 3,
        'date': '2026-08-11',
      });
    });

    test('keeps native widget values inside safe bounds', () {
      final snapshot = StreakWidgetSnapshot(
        calories: -50,
        calorieGoal: 0,
        streak: -2,
        date: DateTime(2026, 1, 2),
      );

      expect(snapshot.toPlatformMap(), {
        'calories': 0,
        'calorieGoal': 1,
        'streak': 0,
        'date': '2026-01-02',
      });
    });
  });

  group('shouldOfferStreakWidgetIntro', () {
    final now = DateTime(2026, 8, 11, 20);

    test('offers after the first explicit food starts streak day one', () {
      expect(
        shouldOfferStreakWidgetIntro(
          previousMealAdditionVersion: 4,
          mealAdditionVersion: 5,
          lastMealAdditionDate: DateTime(2026, 8, 11),
          now: now,
          localRegistrationStreak: 1,
        ),
        isTrue,
      );
    });

    test('does not offer for reloads, old additions or continuing streaks', () {
      expect(
        shouldOfferStreakWidgetIntro(
          previousMealAdditionVersion: 5,
          mealAdditionVersion: 5,
          lastMealAdditionDate: DateTime(2026, 8, 11),
          now: now,
          localRegistrationStreak: 1,
        ),
        isFalse,
      );
      expect(
        shouldOfferStreakWidgetIntro(
          previousMealAdditionVersion: 4,
          mealAdditionVersion: 5,
          lastMealAdditionDate: DateTime(2026, 8, 10),
          now: now,
          localRegistrationStreak: 1,
        ),
        isFalse,
      );
      expect(
        shouldOfferStreakWidgetIntro(
          previousMealAdditionVersion: 4,
          mealAdditionVersion: 5,
          lastMealAdditionDate: DateTime(2026, 8, 11),
          now: now,
          localRegistrationStreak: 2,
        ),
        isFalse,
      );
    });
  });
}
