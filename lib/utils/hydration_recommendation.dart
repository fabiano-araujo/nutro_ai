import 'dart:math' as math;

/// Calculates a practical daily hydration target for a healthy adult.
///
/// The estimate combines the WHO body-weight/energy rules of thumb with the
/// National Academies' sex-specific adequate intake from beverages. Activity
/// receives a small additional allowance because sweat loss is not represented
/// reliably by a habitual activity category alone.
class HydrationRecommendation {
  const HydrationRecommendation({
    required this.milliliters,
    required this.glasses,
    required this.isPersonalized,
  });

  static const int millilitersPerGlass = 250;

  final int milliliters;
  final int glasses;
  final bool isPersonalized;

  static HydrationRecommendation calculate({
    String? sex,
    int? age,
    double? weightKg,
    double? heightCm,
    int? activityLevelIndex,
  }) {
    final normalizedSex = sex?.trim().toLowerCase();
    final validWeight =
        weightKg != null && weightKg >= 30 && weightKg <= 300 ? weightKg : null;
    final validHeight = heightCm != null && heightCm >= 120 && heightCm <= 230
        ? heightCm
        : null;
    final validAge = age != null && age >= 18 && age <= 100 ? age : null;
    final validActivity = activityLevelIndex != null &&
            activityLevelIndex >= 0 &&
            activityLevelIndex <= 4
        ? activityLevelIndex
        : null;

    final candidates = <double>[2000];

    // Adequate intake from beverages: 3.0 L for men and 2.2 L for women.
    if (normalizedSex == 'male') {
      candidates.add(3000);
    } else if (normalizedSex == 'female') {
      candidates.add(2200);
    }

    // WHO reference used for adults: about 30 mL/kg/day.
    if (validWeight != null) {
      candidates.add(validWeight * 30);
    }

    // The 1 mL/kcal reference lets age, height, sex, weight, and habitual
    // activity all influence the estimate through energy expenditure.
    if (validWeight != null &&
        validHeight != null &&
        validAge != null &&
        validActivity != null &&
        (normalizedSex == 'male' || normalizedSex == 'female')) {
      final sexOffset = normalizedSex == 'male' ? 5 : -161;
      final restingEnergy = (10 * validWeight) +
          (6.25 * validHeight) -
          (5 * validAge) +
          sexOffset;
      const activityMultipliers = [1.2, 1.375, 1.55, 1.725, 1.9];
      candidates.add(restingEnergy * activityMultipliers[validActivity]);
    }

    const activityAllowances = [0, 125, 250, 500, 750];
    final activityAllowance =
        validActivity == null ? 0 : activityAllowances[validActivity];
    final rawMilliliters = candidates.reduce(math.max) + activityAllowance;
    final roundedGlasses =
        (rawMilliliters / millilitersPerGlass).ceil().clamp(6, 20);

    return HydrationRecommendation(
      milliliters: roundedGlasses * millilitersPerGlass,
      glasses: roundedGlasses,
      isPersonalized: normalizedSex != null ||
          validAge != null ||
          validWeight != null ||
          validHeight != null ||
          validActivity != null,
    );
  }
}
