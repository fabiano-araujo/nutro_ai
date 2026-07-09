import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/controllers/nutrition_assistant_controller.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/models/meal_model.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:nutro_ai/services/daily_chat_sync_service.dart';
import 'package:nutro_ai/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyChatSyncService.instance.clearAuth();
  });

  tearDown(() {
    DailyChatSyncService.instance.clearAuth();
  });

  test('prunes food message pairs that no longer have diary meals', () async {
    final staleFoodTimestamp = DateTime(2026, 7, 8, 1, 11, 32, 746, 48);
    final controller = _controllerWithMessages([
      _msg(true, 'Goiaba',
          staleFoodTimestamp.subtract(const Duration(seconds: 1))),
      _msg(false, _foodJson('goiaba'), staleFoodTimestamp),
      _msg(true, 'quanto falta hoje?', DateTime(2026, 7, 8, 1, 12)),
      _msg(false, 'Ainda faltam 500 kcal.', DateTime(2026, 7, 8, 1, 12, 1)),
    ]);

    final pruned = await controller.pruneOrphanFoodDiaryMessagePairs(
      hasMealsForMessageId: (_) => false,
      isChatMealDeleted: (_) => true,
      now: DateTime(2026, 7, 8, 13),
      syncNow: false,
    );

    expect(pruned, isTrue);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.first['message'], 'quanto falta hoje?');
    controller.dispose();
  });

  test('keeps food message pair while matching diary meal exists', () async {
    final foodTimestamp = DateTime(2026, 7, 8, 1, 11, 32, 746, 48);
    final expectedMessageId = 'msg-${foodTimestamp.microsecondsSinceEpoch}';
    final controller = _controllerWithMessages([
      _msg(true, 'Goiaba', foodTimestamp.subtract(const Duration(seconds: 1))),
      _msg(false, _foodJson('goiaba'), foodTimestamp),
    ]);

    final pruned = await controller.pruneOrphanFoodDiaryMessagePairs(
      hasMealsForMessageId: (messageId) => messageId == expectedMessageId,
      isChatMealDeleted: (_) => false,
      now: DateTime(2026, 7, 8, 13),
      syncNow: false,
    );

    expect(pruned, isFalse);
    expect(controller.messages, hasLength(2));
    controller.dispose();
  });

  test('keeps recent orphan food message while diary auto-add can settle',
      () async {
    final foodTimestamp = DateTime(2026, 7, 8, 13, 10);
    final controller = _controllerWithMessages([
      _msg(true, 'Pao', foodTimestamp.subtract(const Duration(seconds: 30))),
      _msg(false, _foodJson('pao'), foodTimestamp),
    ]);

    final pruned = await controller.pruneOrphanFoodDiaryMessagePairs(
      hasMealsForMessageId: (_) => false,
      isChatMealDeleted: (_) => false,
      now: foodTimestamp.add(const Duration(seconds: 45)),
      gracePeriod: const Duration(minutes: 2),
      syncNow: false,
    );

    expect(pruned, isFalse);
    expect(controller.messages, hasLength(2));
    controller.dispose();
  });

  test('drops restored empty streaming assistant placeholder', () {
    final controller = _controllerWithMessages([
      _msg(true, 'Oi', DateTime(2026, 7, 8, 15, 54, 32)),
      {
        'isUser': false,
        'message': '',
        'timestamp': DateTime(2026, 7, 8, 15, 54, 33),
        'streaming': true,
      },
    ]);

    expect(controller.messages, hasLength(1));
    expect(controller.messages.single['isUser'], isTrue);
    expect(controller.messages.single['message'], 'Oi');
    controller.dispose();
  });

  test('writes tombstone when all orphan food messages are pruned', () async {
    final foodTimestamp = DateTime(2026, 7, 8, 1, 11, 32, 746, 48);
    final controller = _controllerWithMessages([
      _msg(true, 'Goiaba', foodTimestamp.subtract(const Duration(seconds: 1))),
      _msg(false, _foodJson('goiaba'), foodTimestamp),
    ]);

    await controller.pruneOrphanFoodDiaryMessagePairs(
      hasMealsForMessageId: (_) => false,
      isChatMealDeleted: (_) => true,
      now: DateTime(2026, 7, 8, 13),
      syncNow: false,
    );

    final data =
        await StorageService().getData('nutrition_chat_user_1_2026-07-08');
    expect(data?['deleted'], isTrue);
    expect(data?['messages'], isEmpty);
    controller.dispose();
  });

  test('add delete and return keeps deleted food chat from coming back',
      () async {
    final foodTimestamp = DateTime(2026, 7, 8, 1, 11, 32, 746, 48);
    final messageId = 'msg-${foodTimestamp.microsecondsSinceEpoch}';
    final controller = _controllerWithMessages([
      _msg(true, 'Goiaba', foodTimestamp.subtract(const Duration(seconds: 1))),
      _msg(false, _foodJson('goiaba'), foodTimestamp),
    ]);
    final mealsProvider = DailyMealsProvider();
    await mealsProvider.ready;
    mealsProvider.setSelectedDate(DateTime(2026, 7, 8));

    mealsProvider.addMeal(
      Meal(
        id: 'meal-from-chat',
        type: MealType.snack,
        messageId: messageId,
        foods: [_food('goiaba', calories: 68, protein: 2.6, carbs: 14)],
      ),
    );
    expect(mealsProvider.todayMeals, hasLength(1));

    var pruned = await controller.pruneOrphanFoodDiaryMessagePairs(
      hasMealsForMessageId: (id) =>
          mealsProvider.getMealsByMessageId(id).isNotEmpty,
      isChatMealDeleted: (id) => mealsProvider.isChatMealDeleted(
        id,
        date: DateTime(2026, 7, 8),
      ),
      now: DateTime(2026, 7, 8, 13),
      syncNow: false,
    );
    expect(pruned, isFalse);

    mealsProvider.deleteMeal('meal-from-chat', messageId: messageId);
    expect(mealsProvider.todayMeals, isEmpty);
    expect(
      mealsProvider.isChatMealDeleted(messageId, date: DateTime(2026, 7, 8)),
      isTrue,
    );

    pruned = await controller.pruneOrphanFoodDiaryMessagePairs(
      hasMealsForMessageId: (id) =>
          mealsProvider.getMealsByMessageId(id).isNotEmpty,
      isChatMealDeleted: (id) => mealsProvider.isChatMealDeleted(
        id,
        date: DateTime(2026, 7, 8),
      ),
      now: DateTime(2026, 7, 8, 13),
      syncNow: false,
    );
    expect(pruned, isTrue);

    await DailyChatSyncService.instance.restoreFromServer({
      '2026-07-08': {
        'messages': [
          _storedMsg(true, 'Goiaba',
              foodTimestamp.subtract(const Duration(seconds: 1))),
          _storedMsg(false, _foodJson('goiaba'), foodTimestamp),
        ],
        'updatedAt': '2026-07-08T01:12:00.000Z',
      },
    }, scope: 'user_1');

    final data =
        await StorageService().getData('nutrition_chat_user_1_2026-07-08');
    expect(data?['deleted'], isTrue);
    expect(data?['messages'], isEmpty);
    controller.dispose();
  });
}

NutritionAssistantController _controllerWithMessages(
  List<Map<String, dynamic>> messages,
) {
  return NutritionAssistantController(
    speechMixin: _FakeSpeechRef(),
    ttsRef: _FakeTtsRef(),
    showWelcomeMessage: false,
    storageScope: 'user_1',
    initialDate: DateTime(2026, 7, 8),
    initialMessages: messages,
  );
}

Map<String, dynamic> _msg(bool isUser, String message, DateTime timestamp) {
  return {
    'isUser': isUser,
    'message': message,
    'timestamp': timestamp,
  };
}

Map<String, dynamic> _storedMsg(
  bool isUser,
  String message,
  DateTime timestamp,
) {
  return {
    'isUser': isUser,
    'message': message,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}

String _foodJson(String name) {
  return '''
{"mealType":"snack","foods":[{"name":"$name","portion":"1 unidade","macros":{"calories":68,"protein":2.6,"carbohydrate":14,"fat":0.6}}]}
''';
}

Food _food(
  String name, {
  double calories = 100,
  double protein = 4,
  double carbs = 18,
  double fat = 2,
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
      ),
    ],
  );
}

class _FakeSpeechRef implements NutritionAssistantSpeechMixinRef {
  @override
  bool get isListening => false;

  @override
  Future<void> releaseAudioResources() async {}

  @override
  Future<void> stopListening() async {}
}

class _FakeTtsRef implements TextToSpeechMixinRef {
  @override
  bool get isSpeaking => false;

  @override
  Future<void> speak(String text) async {}

  @override
  void stopSpeech() {}
}
