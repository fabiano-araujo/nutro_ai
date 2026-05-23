import 'dart:math' as math;

import '../providers/daily_meals_provider.dart';
import '../providers/streak_provider.dart';

/// Retorna o maior valor entre o streak vindo do backend e o cálculo local
/// baseado nas refeições registradas (mesma fonte de dados do calendário).
/// Garante consistência visual quando o auto check-in do servidor ainda não
/// reflete os registros recentes.
int effectiveRegistrationStreak(
  StreakProvider streakProvider,
  DailyMealsProvider mealsProvider,
) {
  return math.max(
    streakProvider.registrationStreak,
    mealsProvider.getCurrentRegistrationStreak(),
  );
}
