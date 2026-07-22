import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/hydration_recommendation.dart';

void main() {
  test('recommends 3.25 L for an 83 kg moderately active man', () {
    final recommendation = HydrationRecommendation.calculate(
      sex: 'male',
      age: 35,
      weightKg: 83,
      heightCm: 175,
      activityLevelIndex: 2,
    );

    expect(recommendation.milliliters, 3250);
    expect(recommendation.glasses, 13);
    expect(recommendation.isPersonalized, isTrue);
  });

  test('uses height and age through estimated energy expenditure', () {
    final smallerOlderProfile = HydrationRecommendation.calculate(
      sex: 'female',
      age: 65,
      weightKg: 60,
      heightCm: 155,
      activityLevelIndex: 4,
    );
    final tallerYoungerProfile = HydrationRecommendation.calculate(
      sex: 'female',
      age: 25,
      weightKg: 60,
      heightCm: 185,
      activityLevelIndex: 4,
    );

    expect(
      tallerYoungerProfile.milliliters,
      greaterThan(smallerOlderProfile.milliliters),
    );
  });

  test('falls back to 2 L when no profile data is registered', () {
    final recommendation = HydrationRecommendation.calculate();

    expect(recommendation.milliliters, 2000);
    expect(recommendation.glasses, 8);
    expect(recommendation.isPersonalized, isFalse);
  });
}
