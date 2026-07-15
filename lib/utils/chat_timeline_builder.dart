import '../models/meal_model.dart';

/// Item da linha do tempo do chat. Uma entrada representa uma mensagem
/// persistida ou um grupo de refeicoes cujo card original nao esta mais no
/// snapshot da conversa.
class ChatTimelineItem {
  final int? messageIndex;
  final List<Meal> meals;
  final DateTime timestamp;
  final int _stableOrder;

  const ChatTimelineItem._({
    required this.messageIndex,
    required this.meals,
    required this.timestamp,
    required int stableOrder,
  }) : _stableOrder = stableOrder;

  bool get isMessage => messageIndex != null;

  factory ChatTimelineItem.message({
    required int messageIndex,
    required DateTime timestamp,
  }) {
    return ChatTimelineItem._(
      messageIndex: messageIndex,
      meals: const <Meal>[],
      timestamp: timestamp,
      stableOrder: messageIndex,
    );
  }

  factory ChatTimelineItem.meals({
    required List<Meal> meals,
    required DateTime timestamp,
    required int stableOrder,
  }) {
    return ChatTimelineItem._(
      messageIndex: null,
      meals: List<Meal>.unmodifiable(meals),
      timestamp: timestamp,
      stableOrder: stableOrder,
    );
  }
}

class ChatTimelineBuilder {
  const ChatTimelineBuilder._();

  /// Mescla mensagens e refeicoes recuperadas sem tirar as mensagens de sua
  /// ordem original. IDs antigos no formato `msg-<micros>` carregam o horario
  /// exato do card e permitem recoloca-lo no ponto correto da conversa.
  static List<ChatTimelineItem> build({
    required List<Map<String, dynamic>> messages,
    required List<Meal> unrepresentedMeals,
  }) {
    final items = <ChatTimelineItem>[];
    DateTime? lastMessageTimestamp;

    for (var index = 0; index < messages.length; index++) {
      final timestamp = _readDate(messages[index]['timestamp']) ??
          lastMessageTimestamp ??
          DateTime.fromMillisecondsSinceEpoch(0);
      lastMessageTimestamp = timestamp;
      items.add(
        ChatTimelineItem.message(
          messageIndex: index,
          timestamp: timestamp,
        ),
      );
    }

    final groupedMeals = <String, List<Meal>>{};
    for (final meal in unrepresentedMeals) {
      final groupId = mealMessageGroupId(meal.messageId) ?? 'meal:${meal.id}';
      (groupedMeals[groupId] ??= <Meal>[]).add(meal);
    }

    var mealOrder = messages.length;
    for (final entry in groupedMeals.entries) {
      final meals = entry.value;
      if (meals.isEmpty) continue;
      final timestamp = messageTimestampFromId(entry.key) ??
          meals
              .map((meal) => meal.dateTime)
              .reduce((a, b) => a.isBefore(b) ? a : b);
      items.add(
        ChatTimelineItem.meals(
          meals: meals,
          timestamp: timestamp,
          stableOrder: mealOrder++,
        ),
      );
    }

    items.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      if (byTime != 0) return byTime;
      return a._stableOrder.compareTo(b._stableOrder);
    });
    return items;
  }

  static String? mealMessageGroupId(String? messageId) {
    final trimmed = messageId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final withoutMealSuffix = trimmed.split('#meal-').first;
    final legacyMatch =
        RegExp(r'^(msg-\d+)-\d+$').firstMatch(withoutMealSuffix);
    return legacyMatch?.group(1) ?? withoutMealSuffix;
  }

  static DateTime? messageTimestampFromId(String? messageId) {
    final groupId = mealMessageGroupId(messageId);
    if (groupId == null) return null;
    final match = RegExp(r'^msg-(\d+)$').firstMatch(groupId);
    final micros = int.tryParse(match?.group(1) ?? '');
    if (micros == null) return null;
    return DateTime.fromMicrosecondsSinceEpoch(micros);
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
