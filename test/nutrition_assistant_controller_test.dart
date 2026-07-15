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

  test('never prunes an old food turn without an explicit deletion tombstone',
      () async {
    final foodTimestamp = DateTime(2026, 7, 8, 8);
    final controller = _controllerWithMessages([
      _msg(true, '200 g de cuscuz',
          foodTimestamp.subtract(const Duration(seconds: 2))),
      _msg(false, _foodJson('cuscuz'), foodTimestamp),
    ]);

    final pruned = await controller.pruneOrphanFoodDiaryMessagePairs(
      hasMealsForMessageId: (_) => false,
      isChatMealDeleted: (_) => false,
      now: foodTimestamp.add(const Duration(days: 30)),
      syncNow: false,
    );

    expect(pruned, isFalse);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.first['message'], '200 g de cuscuz');
    controller.dispose();
  });

  test('persists meal snapshot with the user message that generated it',
      () async {
    final userTimestamp = DateTime(2026, 7, 8, 12);
    final assistantTimestamp = userTimestamp.add(const Duration(seconds: 1));
    final messageId = 'msg-${assistantTimestamp.microsecondsSinceEpoch}';
    final controller = _controllerWithMessages([
      _msg(true, '150 g de frango', userTimestamp),
      _msg(false, _foodJson('frango'), assistantTimestamp),
    ]);

    controller.persistMealSnapshotsForMessage(
      messageId: messageId,
      meals: [
        Meal(
          id: 'meal-frango',
          type: MealType.lunch,
          foods: [_food('frango', calories: 248, protein: 46)],
          dateTime: assistantTimestamp,
          messageId: messageId,
        ),
      ],
    );
    await controller.flushDailyChatState();

    final assistant = controller.messages[1];
    expect(assistant['id'], messageId);
    expect(assistant['sourceUserMessage'], '150 g de frango');
    expect(assistant['sourceUserMessageId'], controller.messages.first['id']);
    expect(assistant['mealSnapshots'], hasLength(1));

    final stored =
        await StorageService().getData('nutrition_chat_user_1_2026-07-08');
    final storedAssistant = (stored!['messages'] as List)[1] as Map;
    expect(storedAssistant['sourceUserMessage'], '150 g de frango');
    expect(storedAssistant['mealSnapshots'], hasLength(1));
    controller.dispose();
  });

  test('recovers a legacy meal card after its real nearby user message', () {
    final userTimestamp = DateTime(2026, 7, 8, 9);
    final cardTimestamp = userTimestamp.add(const Duration(seconds: 2));
    final nextTimestamp = userTimestamp.add(const Duration(minutes: 10));
    final messageId = 'msg-${cardTimestamp.microsecondsSinceEpoch}';
    final controller = _controllerWithMessages([
      _msg(true, 'pão com café', userTimestamp),
      _msg(true, 'quanto falta?', nextTimestamp),
    ]);

    controller.recoverLegacyMealSnapshotMessages([
      Meal(
        id: 'legacy-meal',
        type: MealType.breakfast,
        foods: [_food('pão', calories: 70)],
        dateTime: DateTime(2026, 7, 8),
        messageId: messageId,
      ),
    ]);

    expect(controller.messages, hasLength(3));
    expect(controller.messages[0]['message'], 'pão com café');
    expect(controller.messages[1]['id'], messageId);
    expect(controller.messages[1]['mealSnapshots'], hasLength(1));
    expect(controller.messages[1]['sourceUserMessage'], 'pão com café');
    expect(controller.messages[2]['message'], 'quanto falta?');
    controller.dispose();
  });

  test('reconstructs a factual user bubble when the legacy prompt was lost',
      () {
    final cardTimestamp = DateTime(2026, 7, 8, 9);
    final messageId = 'msg-${cardTimestamp.microsecondsSinceEpoch}';
    final controller = _controllerWithMessages([
      _msg(true, 'mensagem muito posterior',
          cardTimestamp.add(const Duration(hours: 1))),
    ]);

    controller.recoverLegacyMealSnapshotMessages([
      Meal(
        id: 'legacy-meal',
        type: MealType.breakfast,
        foods: [
          _food('pão', calories: 70),
          _food('café', calories: 2),
        ],
        dateTime: DateTime(2026, 7, 8),
        messageId: messageId,
      ),
    ]);

    expect(controller.messages, hasLength(3));
    expect(controller.messages[0]['isUser'], isTrue);
    expect(controller.messages[0]['message'], 'pão, café');
    expect(controller.messages[0]['sourceUserReconstructed'], isTrue);
    expect(controller.messages[1]['id'], messageId);
    expect(controller.messages[1]['replyToMessageId'],
        controller.messages[0]['id']);
    expect(controller.messages[2]['message'], 'mensagem muito posterior');
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

  test('changes the visible date before saving the previous conversation',
      () async {
    final selectedDate = DateTime(2026, 7, 7);
    final previousMessages = [
      _msg(true, 'Goiaba', DateTime(2026, 7, 8, 12)),
      _msg(false, _foodJson('goiaba'), DateTime(2026, 7, 8, 12, 0, 1)),
    ];
    await StorageService().saveData(
      'nutrition_chat_user_1_2026-07-07',
      {
        'messages': [
          _storedMsg(true, 'Cuscuz', DateTime(2026, 7, 7, 10)),
          _storedMsg(
              false, 'Refeição registrada.', DateTime(2026, 7, 7, 10, 0, 1)),
        ],
      },
    );
    final controller = _controllerWithMessages(previousMessages);

    final dateChange = controller.changeSelectedDate(selectedDate);

    expect(controller.selectedDate, selectedDate);
    expect(controller.messages, isEmpty);
    expect(controller.isLoadingMessages, isTrue);

    await dateChange;

    expect(controller.selectedDate, selectedDate);
    expect(controller.messages, hasLength(2));
    expect(controller.messages.first['message'], 'Cuscuz');
    final savedPrevious =
        await StorageService().getData('nutrition_chat_user_1_2026-07-08');
    expect(savedPrevious?['messages'], hasLength(previousMessages.length));
    expect(controller.isLoadingMessages, isFalse);
    controller.dispose();
  });

  test('keeps the latest day when date loads overlap', () async {
    await StorageService().saveData(
      'nutrition_chat_user_1_2026-07-07',
      {
        'messages': [
          _storedMsg(true, 'Mensagem do dia 7', DateTime(2026, 7, 7, 10)),
        ],
      },
    );
    await StorageService().saveData(
      'nutrition_chat_user_1_2026-07-06',
      {
        'messages': [
          _storedMsg(true, 'Mensagem do dia 6', DateTime(2026, 7, 6, 10)),
        ],
      },
    );
    final controller = _controllerWithMessages([
      _msg(true, 'Mensagem do dia 8', DateTime(2026, 7, 8, 10)),
    ]);

    final firstChange = controller.changeSelectedDate(DateTime(2026, 7, 7));
    final latestChange = controller.changeSelectedDate(DateTime(2026, 7, 6));
    await Future.wait([firstChange, latestChange]);

    expect(controller.selectedDate, DateTime(2026, 7, 6));
    expect(controller.messages, hasLength(1));
    expect(controller.messages.single['message'], 'Mensagem do dia 6');
    expect(controller.isLoadingMessages, isFalse);
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
