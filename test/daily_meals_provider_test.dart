import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/models/meal_model.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tracks explicit local meal additions without firing on date changes',
      () async {
    final provider = DailyMealsProvider();
    await provider.ready;

    provider.setSelectedDate(DateTime(2026, 6, 18));

    expect(provider.mealAdditionVersion, 0);
    expect(provider.lastMealAdditionDate, isNull);

    provider.addMeal(
      Meal(
        id: 'meal-1',
        type: MealType.breakfast,
        foods: [_food('pao')],
      ),
    );

    expect(provider.mealAdditionVersion, 1);
    expect(provider.lastMealAdditionDate, DateTime(2026, 6, 18));

    provider.setSelectedDate(DateTime(2026, 6, 17));

    expect(provider.mealAdditionVersion, 1);
    expect(provider.lastMealAdditionDate, DateTime(2026, 6, 18));

    provider.addFoodToMeal(MealType.lunch, _food('arroz'));

    expect(provider.mealAdditionVersion, 2);
    expect(provider.lastMealAdditionDate, DateTime(2026, 6, 17));
  });

  test('does not count stored meals as new additions', () async {
    final storedMeal = Meal(
      id: 'stored-meal',
      type: MealType.lunch,
      foods: [_food('feijao')],
      dateTime: DateTime(2026, 6, 17, 12),
    );

    SharedPreferences.setMockInitialValues({
      'daily_meals': jsonEncode({
        '2026-06-17': [storedMeal.toJson()],
      }),
    });

    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 6, 17));

    expect(provider.todayMeals, hasLength(1));
    expect(provider.mealAdditionVersion, 0);
    expect(provider.lastMealAdditionDate, isNull);
  });

  test('restores chat snapshots offline without counting a new meal', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    final selectedDate = DateTime(2026, 7, 8);
    final originalCardTime = DateTime(2026, 7, 7, 13, 42, 15);
    provider.setSelectedDate(selectedDate);

    await provider.restoreMealsFromChatSnapshot(selectedDate, [
      Meal(
        id: 'snapshot-meal',
        type: MealType.lunch,
        foods: [_food('frango')],
        dateTime: originalCardTime,
        messageId: 'msg-${originalCardTime.microsecondsSinceEpoch}',
      ),
    ]);

    expect(provider.todayMeals, hasLength(1));
    expect(provider.mealAdditionVersion, 0);
    expect(
        provider.todayMeals.single.dateTime, DateTime(2026, 7, 8, 13, 42, 15));

    await provider.restoreMealsFromChatSnapshot(selectedDate, [
      provider.todayMeals.single,
    ]);
    expect(provider.todayMeals, hasLength(1));
  });

  test('preserves the chat card time when adding it to a selected day',
      () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'timed-meal',
        type: MealType.snack,
        foods: [_food('banana')],
        dateTime: DateTime(2026, 1, 1, 16, 25, 30),
        messageId: 'msg-1',
      ),
    );

    expect(
        provider.todayMeals.single.dateTime, DateTime(2026, 7, 8, 16, 25, 30));
  });

  test('updates chat meal totals by message id when card id changes', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'chat-message-1',
        foods: [
          _food('goiaba', calories: 136, protein: 5.2, carbs: 28, fat: 1.8)
        ],
      ),
    );

    expect(provider.totalCalories, 136);
    expect(provider.totalProtein, 5.2);

    provider.updateMeal(
      Meal(
        id: 'reparsed-card-id',
        type: MealType.snack,
        messageId: 'chat-message-1',
        foods: [
          _food('goiaba', calories: 68, protein: 2.6, carbs: 14, fat: 0.6)
        ],
      ),
    );

    expect(provider.totalCalories, 68);
    expect(provider.totalProtein, 2.6);
    expect(provider.totalCarbs, 14);
    expect(provider.totalFat, 0.6);
    expect(provider.todayMeals.single.id, 'stored-meal-id');
  });

  test('aggregates and restores fiber from local meal persistence', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    final selectedDate = DateTime(2026, 7, 9);
    provider.setSelectedDate(selectedDate);

    final meal = Meal(
      id: 'fiber-meal',
      type: MealType.lunch,
      foods: [
        _food('feijao', fiber: 6.4),
        _food('arroz integral', fiber: 2.1),
      ],
    );
    provider.addMeal(meal);

    expect(meal.totalFiber, 8.5);
    expect(provider.totalFiber, 8.5);
    expect(provider.getMacrosForDate(selectedDate)['fiber'], 8.5);
    expect(provider.getNutritionSnapshotForDate(selectedDate)['fiber'], 8.5);

    await pumpEventQueue();
    final reloaded = DailyMealsProvider();
    await reloaded.ready;
    reloaded.setSelectedDate(selectedDate);

    expect(reloaded.todayMeals, hasLength(1));
    expect(reloaded.todayMeals.single.totalFiber, 8.5);
    expect(reloaded.totalFiber, 8.5);
  });

  test('matches chat meals when message index changes', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000000-4#meal-0',
        foods: [
          _food('goiaba', calories: 136, protein: 5.2, carbs: 28, fat: 1.8)
        ],
      ),
    );

    expect(provider.getMealsByMessageId('msg-1800000000000000'), hasLength(1));
    expect(provider.getMealsByMessageId('msg-1800000000000000').single.id,
        'stored-meal-id');

    provider.addMeal(
      Meal(
        id: 'reparsed-card-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000000#meal-0',
        foods: [
          _food('goiaba', calories: 68, protein: 2.6, carbs: 14, fat: 0.6)
        ],
      ),
    );

    expect(provider.todayMeals, hasLength(1));
    expect(provider.totalCalories, 68);
    expect(provider.todayMeals.single.id, 'reparsed-card-id');
  });

  test('deletes chat meal by message id when card id changes', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000001-4#meal-0',
        foods: [
          _food('goiaba', calories: 136, protein: 5.2, carbs: 28, fat: 1.8)
        ],
      ),
    );

    provider.deleteMeal(
      'reparsed-card-id',
      messageId: 'msg-1800000000000001#meal-0',
    );

    expect(provider.todayMeals, isEmpty);
    expect(provider.totalCalories, 0);
    expect(provider.totalProtein, 0);
    expect(provider.hasMealsOn(DateTime(2026, 7, 8)), isFalse);
  });

  test('does not match a different meal ordinal in the same chat message',
      () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000002-4#meal-1',
        foods: [
          _food('banana', calories: 105, protein: 1.3, carbs: 27, fat: 0.4)
        ],
      ),
    );

    provider.deleteMeal(
      'reparsed-card-id',
      messageId: 'msg-1800000000000002#meal-0',
    );

    expect(provider.todayMeals, hasLength(1));
    expect(provider.todayMeals.single.id, 'stored-meal-id');
    expect(provider.totalCalories, 105);
  });

  test('keeps deleted chat meal blocked after provider reload', () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    provider.addMeal(
      Meal(
        id: 'stored-meal-id',
        type: MealType.snack,
        messageId: 'msg-1800000000000003#meal-0',
        foods: [
          _food('pao', calories: 80, protein: 3, carbs: 15, fat: 1),
        ],
      ),
    );

    provider.deleteMeal(
      'stored-meal-id',
      messageId: 'msg-1800000000000003#meal-0',
    );
    await Future<void>.delayed(Duration.zero);

    final reloaded = DailyMealsProvider();
    await reloaded.ready;
    reloaded.setSelectedDate(DateTime(2026, 7, 8));

    expect(
      reloaded.isChatMealDeleted(
        'msg-1800000000000003#meal-0',
        date: DateTime(2026, 7, 8),
      ),
      isTrue,
    );

    reloaded.addMeal(
      Meal(
        id: 'auto-added-again',
        type: MealType.snack,
        messageId: 'msg-1800000000000003#meal-0',
        foods: [
          _food('pao', calories: 80, protein: 3, carbs: 15, fat: 1),
        ],
      ),
    );

    expect(reloaded.todayMeals, isEmpty);
    expect(reloaded.totalCalories, 0);
  });

  test('filters stale cached meals that were already deleted', () async {
    final staleMeal = Meal(
      id: 'stale-meal',
      type: MealType.breakfast,
      messageId: 'msg-1800000000000004#meal-0',
      foods: [
        _food('pao', calories: 80, protein: 3, carbs: 15, fat: 1),
      ],
      dateTime: DateTime(2026, 7, 8, 8),
    );

    SharedPreferences.setMockInitialValues({
      'daily_meals': jsonEncode({
        '2026-07-08': [staleMeal.toJson()],
      }),
      'daily_meals_deleted_chat_meal_ids': jsonEncode({
        '2026-07-08': ['msg-1800000000000004#meal-0'],
      }),
    });

    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));

    expect(provider.todayMeals, isEmpty);
    expect(provider.totalCalories, 0);
    expect(
      provider.isChatMealDeleted(
        'msg-1800000000000004#meal-0',
        date: DateTime(2026, 7, 8),
      ),
      isTrue,
    );
  });

  test('reload replaces a chat card and keeps unrelated meals intact',
      () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));
    const messageId = 'msg-1800000000000005';

    provider.addMeal(
      Meal(
        id: 'original-chat-meal',
        type: MealType.breakfast,
        messageId: messageId,
        foods: [
          _food('pao frances', calories: 130),
          _food('ovo adicionado pelo usuario', calories: 122),
        ],
      ),
    );
    provider.addMeal(
      Meal(
        id: 'unrelated-manual-meal',
        type: MealType.dinner,
        foods: [_food('salada', calories: 50)],
      ),
    );
    final additionVersionBeforeReload = provider.mealAdditionVersion;

    provider.replaceChatMealsForMessage(messageId, [
      Meal(
        id: 'regenerated-card-id',
        type: MealType.breakfast,
        messageId: messageId,
        foods: [_food('pao branco', calories: 130)],
      ),
    ]);

    final reloadedCard = provider.getMealsByMessageId(messageId);
    expect(reloadedCard, hasLength(1));
    expect(reloadedCard.single.id, 'original-chat-meal');
    expect(reloadedCard.single.foods, hasLength(1));
    expect(reloadedCard.single.foods.single.name, 'pao branco');
    expect(provider.todayMeals, hasLength(2));
    expect(
      provider.todayMeals.any((meal) => meal.id == 'unrelated-manual-meal'),
      isTrue,
    );
    expect(provider.totalCalories, 180);
    expect(provider.mealAdditionVersion, additionVersionBeforeReload);
  });

  test('reload removes obsolete meals from a multi-meal chat response',
      () async {
    final provider = DailyMealsProvider();
    await provider.ready;
    provider.setSelectedDate(DateTime(2026, 7, 8));
    const messageId = 'msg-1800000000000006';

    provider.addMeal(
      Meal(
        id: 'old-breakfast',
        type: MealType.breakfast,
        messageId: '$messageId#meal-0',
        foods: [_food('pao', calories: 130)],
      ),
    );
    provider.addMeal(
      Meal(
        id: 'old-snack',
        type: MealType.snack,
        messageId: '$messageId#meal-1',
        foods: [_food('banana', calories: 105)],
      ),
    );

    provider.replaceChatMealsForMessage(messageId, [
      Meal(
        id: 'new-breakfast',
        type: MealType.breakfast,
        messageId: messageId,
        foods: [_food('cuscuz', calories: 180)],
      ),
    ]);

    expect(provider.getMealsByMessageId(messageId), hasLength(1));
    expect(provider.getMealsByMessageId(messageId).single.messageId, messageId);
    expect(provider.getMealsByMessageId(messageId).single.foods.single.name,
        'cuscuz');
    expect(provider.todayMeals, hasLength(1));
    expect(provider.totalCalories, 180);
  });
}

Food _food(
  String name, {
  double calories = 100,
  double protein = 4,
  double carbs = 18,
  double fat = 2,
  double fiber = 0,
}) {
  return Food(
    id: name.hashCode,
    name: name,
    nutrients: [
      Nutrient(
        idFood: name.hashCode,
        servingSize: 1,
        servingUnit: 'un',
        calories: calories,
        protein: protein,
        carbohydrate: carbs,
        fat: fat,
        dietaryFiber: fiber,
      ),
    ],
  );
}
