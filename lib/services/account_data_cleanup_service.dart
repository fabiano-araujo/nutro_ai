import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/activity_tracking_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/essay_provider.dart';
import '../providers/food_history_provider.dart';
import '../providers/free_chat_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import 'daily_chat_sync_service.dart';
import 'storage_service.dart';

/// Providers e serviços que mantêm dados locais vinculados à conta atual.
class AccountCleanupDependencies {
  final StorageService storageService;
  final CreditProvider creditProvider;
  final EssayProvider essayProvider;
  final DailyMealsProvider dailyMealsProvider;
  final ActivityTrackingProvider activityTrackingProvider;
  final FoodHistoryProvider foodHistoryProvider;
  final DietPlanProvider dietPlanProvider;
  final FreeChatProvider freeChatProvider;
  final NutritionGoalsProvider nutritionGoalsProvider;
  final MealTypesProvider mealTypesProvider;
  final DailyChatSyncService dailyChatSyncService;

  const AccountCleanupDependencies({
    required this.storageService,
    required this.creditProvider,
    required this.essayProvider,
    required this.dailyMealsProvider,
    required this.activityTrackingProvider,
    required this.foodHistoryProvider,
    required this.dietPlanProvider,
    required this.freeChatProvider,
    required this.nutritionGoalsProvider,
    required this.mealTypesProvider,
    required this.dailyChatSyncService,
  });
}

class AccountDataCleanupService {
  const AccountDataCleanupService._();

  static AccountCleanupDependencies capture(BuildContext context) {
    return AccountCleanupDependencies(
      storageService: StorageService(),
      creditProvider: context.read<CreditProvider>(),
      essayProvider: context.read<EssayProvider>(),
      dailyMealsProvider: context.read<DailyMealsProvider>(),
      activityTrackingProvider: context.read<ActivityTrackingProvider>(),
      foodHistoryProvider: context.read<FoodHistoryProvider>(),
      dietPlanProvider: context.read<DietPlanProvider>(),
      freeChatProvider: context.read<FreeChatProvider>(),
      nutritionGoalsProvider: context.read<NutritionGoalsProvider>(),
      mealTypesProvider: context.read<MealTypesProvider>(),
      dailyChatSyncService: DailyChatSyncService.instance,
    );
  }

  /// Remove todos os dados locais vinculados à conta excluída ou desconectada.
  static Future<void> clearAllUserData(
    AccountCleanupDependencies deps,
  ) async {
    print(
        '[🔄 AUTH_DATA] ========== INICIANDO LIMPEZA DE DADOS DA CONTA ==========');

    try {
      print('[🔄 AUTH_DATA] 1/7 Limpando StorageService...');
      await deps.storageService.clearAllUserData();
      print('[🔄 AUTH_DATA] 1/7 ✅ StorageService limpo');

      print('[🔄 AUTH_DATA] 2/7 Limpando CreditProvider...');
      await deps.creditProvider.clearUserData();
      print('[🔄 AUTH_DATA] 2/7 ✅ CreditProvider limpo');

      print('[🔄 AUTH_DATA] 3/7 Limpando EssayProvider...');
      deps.essayProvider.clearUserData();
      print('[🔄 AUTH_DATA] 3/7 ✅ EssayProvider limpo');

      print('[🔄 AUTH_DATA] 4/7 Limpando DailyMealsProvider...');
      deps.dailyMealsProvider.clearAuth();
      await deps.dailyMealsProvider.clearAllData();
      print('[🔄 AUTH_DATA] 4/7 ✅ DailyMealsProvider limpo');

      await deps.activityTrackingProvider.clearAllData();

      print('[🔄 AUTH_DATA] 5/7 Limpando FoodHistoryProvider...');
      await deps.foodHistoryProvider.clearAll(markPendingSync: false);
      print('[🔄 AUTH_DATA] 5/7 ✅ FoodHistoryProvider limpo');

      print('[🔄 AUTH_DATA] 6/7 Limpando DietPlanProvider...');
      await deps.dietPlanProvider.clearAll();
      print('[🔄 AUTH_DATA] 6/7 ✅ DietPlanProvider limpo');

      print('[🔄 AUTH_DATA] 7/7 Limpando FreeChatProvider...');
      await deps.freeChatProvider.clearAll();
      print('[🔄 AUTH_DATA] 7/7 ✅ FreeChatProvider limpo');

      print('[🔄 AUTH_DATA] EXTRA: Limpando MealTypesProvider...');
      await deps.mealTypesProvider.clearAllData();
      print('[🔄 AUTH_DATA] EXTRA: ✅ MealTypesProvider limpo');

      print('[🔄 AUTH_DATA] EXTRA: Limpando NutritionGoalsProvider...');
      await deps.nutritionGoalsProvider.clearAllData();
      print('[🔄 AUTH_DATA] EXTRA: ✅ NutritionGoalsProvider limpo');

      print('[🔄 AUTH_DATA] ========== LIMPEZA DE DADOS CONCLUÍDA ==========');
    } catch (e) {
      print('[🔄 AUTH_DATA] ❌ ERRO durante limpeza de dados: $e');
    }
  }
}
