import '../models/diet_plan_model.dart';

/// Fair share of the day each meal type should carry, per macro.
/// Values are fractions of the day total (must sum to 1.0 across the meals
/// present in the plan — re-normalization is done at runtime).
class MealShare {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const MealShare({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Equal split: useful as a default when a meal type isn't in the table.
  factory MealShare.equal(int totalMeals) {
    final s = 1.0 / totalMeals;
    return MealShare(kcal: s, protein: s, carbs: s, fat: s);
  }
}

/// Result of a rebalance operation.
class RebalanceResult {
  /// The rebalanced diet plan with adjusted food portions.
  final DietPlan plan;

  /// True if every macro of the rebalanced plan is within `tolerance` of
  /// the target (default 1% — see [DietRebalancer.rebalance]).
  final bool isAccurate;

  /// Per-macro absolute deviations (actual - target) after rebalancing.
  final double deltaKcal;
  final double deltaProtein;
  final double deltaCarbs;
  final double deltaFat;

  /// Smallest and largest scaling factor that was applied to any single food.
  /// Useful to detect "weird" rebalances (e.g. one food scaled by 0.5x).
  final double minScaleApplied;
  final double maxScaleApplied;

  /// True when the linear system was singular and the helper fell back to
  /// proportional kcal scaling.
  final bool usedFallback;

  const RebalanceResult({
    required this.plan,
    required this.isAccurate,
    required this.deltaKcal,
    required this.deltaProtein,
    required this.deltaCarbs,
    required this.deltaFat,
    required this.minScaleApplied,
    required this.maxScaleApplied,
    required this.usedFallback,
  });
}

/// Adjusts food portions in a [DietPlan] so the sum of macros across all
/// meals matches the requested daily targets as closely as possible.
///
/// The model (e.g. Gemini Flash) usually picks good foods but lazy gram
/// amounts. Instead of asking the model to "verify and adjust" (which it
/// ignores), this helper fixes the arithmetic on our side.
///
/// Approach: constrained least-squares. Each food's grams are scaled by a
/// per-food factor x_i. We minimize the total distortion ||x - 1||² subject
/// to 4 linear constraints (one per macro). Each x_i is clamped to
/// [minScale, maxScale] (default 0.5x..2.0x) so we never turn a 100 g
/// portion into a 400 g portion.
///
/// If the constraints are infeasible within bounds, we fall back to
/// proportional kcal scaling (still better than the raw model output).
class DietRebalancer {
  static const double _defaultMinScale = 0.5;
  static const double _defaultMaxScale = 2.0;
  static const double _defaultTolerance = 0.01; // 1%

  /// Conventional shares of the day each meal type carries.
  /// Pulled from typical nutritionist guidance for a 5-meal day.
  /// Values that miss the table fall back to an equal split.
  static const Map<String, MealShare> _defaultMealShares = {
    'breakfast':
        MealShare(kcal: 0.22, protein: 0.20, carbs: 0.22, fat: 0.20),
    'morning_snack':
        MealShare(kcal: 0.10, protein: 0.10, carbs: 0.10, fat: 0.10),
    'lunch':
        MealShare(kcal: 0.28, protein: 0.30, carbs: 0.28, fat: 0.28),
    'afternoon_snack':
        MealShare(kcal: 0.12, protein: 0.10, carbs: 0.12, fat: 0.13),
    'snack':
        MealShare(kcal: 0.12, protein: 0.10, carbs: 0.12, fat: 0.13),
    'dinner':
        MealShare(kcal: 0.28, protein: 0.27, carbs: 0.28, fat: 0.27),
    'supper':
        MealShare(kcal: 0.10, protein: 0.13, carbs: 0.10, fat: 0.12),
  };

  /// Rebalance the plan to hit [targets].
  ///
  /// [minScale] / [maxScale] bound per-food gram scaling.
  /// [tolerance] is the relative gap below which a macro is considered hit.
  static RebalanceResult rebalance(
    DietPlan plan,
    DailyNutrition targets, {
    double minScale = _defaultMinScale,
    double maxScale = _defaultMaxScale,
    double tolerance = _defaultTolerance,
  }) {
    // Collect all foods in the order they appear so we can map back.
    final allFoods = <PlannedFood>[];
    for (final meal in plan.meals) {
      allFoods.addAll(meal.foods);
    }
    final n = allFoods.length;

    if (n == 0 || targets.calories <= 0) {
      final unchangedDelta = _delta(plan.totalNutrition, targets);
      return RebalanceResult(
        plan: plan,
        isAccurate: _withinTolerance(unchangedDelta, targets, tolerance),
        deltaKcal: unchangedDelta[0],
        deltaProtein: unchangedDelta[1],
        deltaCarbs: unchangedDelta[2],
        deltaFat: unchangedDelta[3],
        minScaleApplied: 1.0,
        maxScaleApplied: 1.0,
        usedFallback: false,
      );
    }

    // A[m][i] = contribution of food i to macro m.
    // m=0 kcal, m=1 protein, m=2 carbs, m=3 fat.
    final a = List<List<double>>.generate(4, (m) {
      return List<double>.generate(n, (i) {
        switch (m) {
          case 0:
            return allFoods[i].calories.toDouble();
          case 1:
            return allFoods[i].protein;
          case 2:
            return allFoods[i].carbs;
          default:
            return allFoods[i].fat;
        }
      });
    });

    final b = <double>[
      targets.calories.toDouble(),
      targets.protein,
      targets.carbs,
      targets.fat,
    ];

    // Sum of each row of A = current daily totals.
    final currentSums = a.map(_sum).toList();

    // Residual to close: r = b - A·1
    final residual = <double>[
      for (var m = 0; m < 4; m++) b[m] - currentSums[m],
    ];

    var usedFallback = false;
    List<double> scales;

    final lambda = _solveSymmetric4x4(_buildAAt(a, n), residual);
    if (lambda == null) {
      // Singular system. Fall back to proportional kcal scaling.
      usedFallback = true;
      final kcalRatio =
          currentSums[0] > 0 ? targets.calories / currentSums[0] : 1.0;
      scales = List<double>.filled(n, kcalRatio.clamp(minScale, maxScale));
    } else {
      // x_i = 1 + sum_m A[m][i] * lambda[m]
      scales = List<double>.generate(n, (i) {
        var xi = 1.0;
        for (var m = 0; m < 4; m++) {
          xi += a[m][i] * lambda[m];
        }
        return xi.clamp(minScale, maxScale).toDouble();
      });
    }

    // Track min/max scale actually applied.
    var minApplied = scales.first;
    var maxApplied = scales.first;
    for (final s in scales) {
      if (s < minApplied) minApplied = s;
      if (s > maxApplied) maxApplied = s;
    }

    // Apply scaling and rebuild the diet plan.
    final rebalancedPlan = _applyScales(plan, scales);
    final delta = _delta(rebalancedPlan.totalNutrition, targets);

    return RebalanceResult(
      plan: rebalancedPlan,
      isAccurate: _withinTolerance(delta, targets, tolerance),
      deltaKcal: delta[0],
      deltaProtein: delta[1],
      deltaCarbs: delta[2],
      deltaFat: delta[3],
      minScaleApplied: minApplied,
      maxScaleApplied: maxApplied,
      usedFallback: usedFallback,
    );
  }

  /// Like [rebalance], but ALSO normalizes the macro distribution across
  /// meals so no single meal carries a disproportionate share.
  ///
  /// Two-phase approach:
  ///   1. **Per-meal rebalance**: each meal is independently rebalanced to
  ///      its "fair share" of the day target (default shares in
  ///      [_defaultMealShares] — e.g. lunch ≈ 28% kcal, snack ≈ 12% kcal).
  ///      Phase 1 prevents the model's "245 g chicken in lunch" outliers.
  ///   2. **Day cleanup**: if any meal hit its scaling bounds and the day
  ///      total drifted, a final day-level pass closes the residual gap
  ///      while staying as close as possible to the already-balanced state.
  ///
  /// If [customShares] is provided it overrides the default table; otherwise
  /// any meal type not in the table gets an equal share among the present
  /// meals after re-normalization.
  static RebalanceResult rebalanceBalanced(
    DietPlan plan,
    DailyNutrition dayTargets, {
    Map<String, MealShare>? customShares,
    double minScale = _defaultMinScale,
    double maxScale = _defaultMaxScale,
    double tolerance = _defaultTolerance,
  }) {
    if (plan.meals.isEmpty || dayTargets.calories <= 0) {
      return rebalance(plan, dayTargets,
          minScale: minScale, maxScale: maxScale, tolerance: tolerance);
    }

    // 1) Build per-meal share table, re-normalized to the meals we actually
    //    have. If a meal type is missing from the table it gets an equal
    //    share of what's left after the known meals claim theirs.
    final shares = _normalizeMealShares(
      plan.meals,
      customShares ?? _defaultMealShares,
    );

    // 2) Per-meal independent rebalance. We wrap each meal in a
    //    single-meal DietPlan so we can reuse the existing solver.
    final rebuiltMeals = <PlannedMeal>[];
    var minApplied = double.infinity;
    var maxApplied = -double.infinity;
    var usedFallback = false;

    for (final meal in plan.meals) {
      final share = shares[meal.type] ?? MealShare.equal(plan.meals.length);
      final mealTarget = DailyNutrition(
        calories: (dayTargets.calories * share.kcal).round(),
        protein: dayTargets.protein * share.protein,
        carbs: dayTargets.carbs * share.carbs,
        fat: dayTargets.fat * share.fat,
      );

      final mealAsPlan = DietPlan(
        date: plan.date,
        totalNutrition: meal.mealTotals,
        meals: [meal],
      );

      final mealResult = rebalance(
        mealAsPlan,
        mealTarget,
        minScale: minScale,
        maxScale: maxScale,
        tolerance: tolerance,
      );

      rebuiltMeals.add(mealResult.plan.meals.first);
      if (mealResult.minScaleApplied < minApplied) {
        minApplied = mealResult.minScaleApplied;
      }
      if (mealResult.maxScaleApplied > maxApplied) {
        maxApplied = mealResult.maxScaleApplied;
      }
      if (mealResult.usedFallback) usedFallback = true;
    }

    final afterMealPhase = plan.copyWith(
      meals: rebuiltMeals,
      totalNutrition: _sumMealsAsDailyNutrition(rebuiltMeals),
    );

    // 3) Day-level cleanup in TWO sub-passes:
    //    a) Tight first: ±10% on each food so meal balance is preserved
    //       whenever phase 1 already closed the day total.
    //    b) If meaningful residuals remain (a macro still off by >3%), do
    //       a wider pass at ±25% to close the remaining gap. This second
    //       pass is needed when the raw model output was so lopsided that
    //       phase 1 couldn't even hit per-meal targets within 0.5x..2.0x
    //       — common with chicken-heavy / carb-light DeepSeek output.
    var cleanup = rebalance(
      afterMealPhase,
      dayTargets,
      minScale: 0.90,
      maxScale: 1.10,
      tolerance: tolerance,
    );
    final residualRatio = _maxRelativeResidual(cleanup, dayTargets);
    if (residualRatio > 0.03) {
      cleanup = rebalance(
        cleanup.plan,
        dayTargets,
        minScale: 0.75,
        maxScale: 1.30,
        tolerance: tolerance,
      );
    }

    if (cleanup.minScaleApplied < minApplied) {
      minApplied = cleanup.minScaleApplied;
    }
    if (cleanup.maxScaleApplied > maxApplied) {
      maxApplied = cleanup.maxScaleApplied;
    }
    if (cleanup.usedFallback) usedFallback = true;

    // Use cleanup result's deltas since it has the final day totals.
    return RebalanceResult(
      plan: cleanup.plan,
      isAccurate: cleanup.isAccurate,
      deltaKcal: cleanup.deltaKcal,
      deltaProtein: cleanup.deltaProtein,
      deltaCarbs: cleanup.deltaCarbs,
      deltaFat: cleanup.deltaFat,
      minScaleApplied: minApplied.isFinite ? minApplied : 1.0,
      maxScaleApplied: maxApplied.isFinite ? maxApplied : 1.0,
      usedFallback: usedFallback,
    );
  }

  /// Returns a share-per-meal-type table that:
  ///   - Pulls each known meal type from [base] (e.g. `_defaultMealShares`).
  ///   - Spreads what's left equally among unknown meal types.
  ///   - Re-normalizes every macro column to sum to 1.0 over the meals
  ///     actually present in the plan.
  ///
  /// This way the user can have a 3-meal plan (breakfast/lunch/dinner) and
  /// the shares automatically scale up to cover 100% of the day.
  static Map<String, MealShare> _normalizeMealShares(
    List<PlannedMeal> meals,
    Map<String, MealShare> base,
  ) {
    final mealTypes = meals.map((m) => m.type).toList();

    // First pass: pull known shares, accumulate unknown count.
    final result = <String, MealShare>{};
    final unknownTypes = <String>[];
    var knownKcal = 0.0;
    var knownProtein = 0.0;
    var knownCarbs = 0.0;
    var knownFat = 0.0;
    for (final type in mealTypes) {
      final share = base[type];
      if (share == null) {
        unknownTypes.add(type);
      } else {
        result[type] = share;
        knownKcal += share.kcal;
        knownProtein += share.protein;
        knownCarbs += share.carbs;
        knownFat += share.fat;
      }
    }

    // Distribute remainder equally across unknown meal types.
    if (unknownTypes.isNotEmpty) {
      final remainder = MealShare(
        kcal: ((1.0 - knownKcal) / unknownTypes.length).clamp(0.0, 1.0),
        protein: ((1.0 - knownProtein) / unknownTypes.length).clamp(0.0, 1.0),
        carbs: ((1.0 - knownCarbs) / unknownTypes.length).clamp(0.0, 1.0),
        fat: ((1.0 - knownFat) / unknownTypes.length).clamp(0.0, 1.0),
      );
      for (final type in unknownTypes) {
        result[type] = remainder;
      }
    }

    // Second pass: re-normalize each column so it sums to 1.0 over the
    // meals actually present. (Handles e.g. a 3-meal plan that drops 2.)
    var sumKcal = 0.0;
    var sumProtein = 0.0;
    var sumCarbs = 0.0;
    var sumFat = 0.0;
    for (final type in mealTypes) {
      final s = result[type]!;
      sumKcal += s.kcal;
      sumProtein += s.protein;
      sumCarbs += s.carbs;
      sumFat += s.fat;
    }
    if (sumKcal <= 0 || sumProtein <= 0 || sumCarbs <= 0 || sumFat <= 0) {
      // Degenerate input — fall back to equal split.
      final equal = MealShare.equal(mealTypes.length);
      return {for (final t in mealTypes) t: equal};
    }
    return {
      for (final type in mealTypes)
        type: MealShare(
          kcal: result[type]!.kcal / sumKcal,
          protein: result[type]!.protein / sumProtein,
          carbs: result[type]!.carbs / sumCarbs,
          fat: result[type]!.fat / sumFat,
        ),
    };
  }

  // ─── helpers ───────────────────────────────────────────────────────────

  /// Largest |dev|/target across the 4 macros of [result].
  /// Used by [rebalanceBalanced] to decide whether a second cleanup pass
  /// with wider bounds is needed.
  static double _maxRelativeResidual(
    RebalanceResult result,
    DailyNutrition target,
  ) {
    final values = <List<double>>[
      [result.deltaKcal.abs(), target.calories.toDouble()],
      [result.deltaProtein.abs(), target.protein],
      [result.deltaCarbs.abs(), target.carbs],
      [result.deltaFat.abs(), target.fat],
    ];
    var worst = 0.0;
    for (final pair in values) {
      if (pair[1] <= 0) continue;
      final ratio = pair[0] / pair[1];
      if (ratio > worst) worst = ratio;
    }
    return worst;
  }

  static double _sum(List<double> v) {
    var s = 0.0;
    for (final x in v) s += x;
    return s;
  }

  /// Builds the 4×4 symmetric matrix A · Aᵀ.
  static List<List<double>> _buildAAt(List<List<double>> a, int n) {
    return List<List<double>>.generate(4, (i) {
      return List<double>.generate(4, (j) {
        var s = 0.0;
        for (var k = 0; k < n; k++) {
          s += a[i][k] * a[j][k];
        }
        return s;
      });
    });
  }

  /// Solves a 4×4 linear system `m·x = b` via Gaussian elimination with
  /// partial pivoting. Returns null if the matrix is (numerically) singular.
  static List<double>? _solveSymmetric4x4(
    List<List<double>> m,
    List<double> b,
  ) {
    // Build augmented 4×5 matrix as a deep copy so we don't mutate inputs.
    final aug = List<List<double>>.generate(
      4,
      (i) => [m[i][0], m[i][1], m[i][2], m[i][3], b[i]],
    );

    for (var col = 0; col < 4; col++) {
      // Partial pivot.
      var pivot = col;
      for (var r = col + 1; r < 4; r++) {
        if (aug[r][col].abs() > aug[pivot][col].abs()) pivot = r;
      }
      if (pivot != col) {
        final tmp = aug[col];
        aug[col] = aug[pivot];
        aug[pivot] = tmp;
      }
      if (aug[col][col].abs() < 1e-9) return null;

      for (var r = col + 1; r < 4; r++) {
        final factor = aug[r][col] / aug[col][col];
        for (var c = col; c < 5; c++) {
          aug[r][c] -= factor * aug[col][c];
        }
      }
    }

    final x = List<double>.filled(4, 0);
    for (var i = 3; i >= 0; i--) {
      var s = aug[i][4];
      for (var j = i + 1; j < 4; j++) s -= aug[i][j] * x[j];
      x[i] = s / aug[i][i];
    }
    return x;
  }

  /// Applies the per-food scaling factors to the plan and recomputes meal
  /// and day totals from the scaled foods.
  static DietPlan _applyScales(DietPlan plan, List<double> scales) {
    var idx = 0;
    final rebuiltMeals = plan.meals.map((meal) {
      final newFoods = meal.foods.map((food) {
        final s = scales[idx++];
        return PlannedFood(
          name: food.name,
          emoji: food.emoji,
          amount: _roundAmount(food.amount * s),
          unit: food.unit,
          calories: (food.calories * s).round(),
          protein: _round1(food.protein * s),
          carbs: _round1(food.carbs * s),
          fat: _round1(food.fat * s),
        );
      }).toList();

      return meal.copyWith(
        foods: newFoods,
        mealTotals: _sumFoodsAsDailyNutrition(newFoods),
      );
    }).toList();

    return plan.copyWith(
      meals: rebuiltMeals,
      totalNutrition: _sumMealsAsDailyNutrition(rebuiltMeals),
    );
  }

  static DailyNutrition _sumFoodsAsDailyNutrition(List<PlannedFood> foods) {
    var kcal = 0;
    var p = 0.0, c = 0.0, f = 0.0;
    for (final food in foods) {
      kcal += food.calories;
      p += food.protein;
      c += food.carbs;
      f += food.fat;
    }
    return DailyNutrition(
      calories: kcal,
      protein: _round1(p),
      carbs: _round1(c),
      fat: _round1(f),
    );
  }

  static DailyNutrition _sumMealsAsDailyNutrition(List<PlannedMeal> meals) {
    var kcal = 0;
    var p = 0.0, c = 0.0, f = 0.0;
    for (final meal in meals) {
      kcal += meal.mealTotals.calories;
      p += meal.mealTotals.protein;
      c += meal.mealTotals.carbs;
      f += meal.mealTotals.fat;
    }
    return DailyNutrition(
      calories: kcal,
      protein: _round1(p),
      carbs: _round1(c),
      fat: _round1(f),
    );
  }

  /// Round to the nearest 5 g/ml when amount ≥ 50, otherwise to 1 g/ml unit.
  /// Avoids "fake precision" like 132.4 g of rice.
  static double _roundAmount(double v) {
    if (v <= 0) return 0;
    if (v >= 50) return (v / 5).round() * 5.0;
    return v.roundToDouble();
  }

  static double _round1(double v) {
    if (v.isNaN || v.isInfinite) return 0;
    return (v * 10).round() / 10;
  }

  static List<double> _delta(DailyNutrition actual, DailyNutrition target) {
    return <double>[
      actual.calories - target.calories.toDouble(),
      actual.protein - target.protein,
      actual.carbs - target.carbs,
      actual.fat - target.fat,
    ];
  }

  static bool _withinTolerance(
    List<double> delta,
    DailyNutrition target,
    double tolerance,
  ) {
    final macros = <double>[
      target.calories.toDouble(),
      target.protein,
      target.carbs,
      target.fat,
    ];
    for (var i = 0; i < 4; i++) {
      final t = macros[i];
      if (t <= 0) continue;
      if ((delta[i].abs() / t) > tolerance) return false;
    }
    return true;
  }
}

/// Convenience: relative L1 deviation across the 4 day macros.
/// Sum of |actual - target| / target. Same metric we used during the prompt
/// benchmark (lower = better; 0 = perfect).
double dietDayScore(DailyNutrition actual, DailyNutrition target) {
  final values = <List<double>>[
    [actual.calories.toDouble(), target.calories.toDouble()],
    [actual.protein, target.protein],
    [actual.carbs, target.carbs],
    [actual.fat, target.fat],
  ];
  var score = 0.0;
  for (final pair in values) {
    if (pair[1] <= 0) continue;
    score += (pair[0] - pair[1]).abs() / pair[1];
  }
  return score;
}

