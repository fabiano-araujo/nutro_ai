import 'dart:convert';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';
import 'food_emoji_resolver.dart';

class FoodJsonParser {
  /// Detecta se há um JSON de alimentos na mensagem
  static bool containsFoodJson(String message) {
    try {
      if (!hasFoodJsonSignal(message)) {
        return false;
      }

      // Validação rápida: tentar extrair e decodificar
      final jsonStr = extractFoodJson(message);
      if (jsonStr == null) return false;

      final decoded = jsonDecode(jsonStr);
      return decoded is Map &&
          decoded.containsKey('foods') &&
          decoded['foods'] is List;
    } catch (e) {
      return false;
    }
  }

  /// Detecta sinais fortes de payload nutricional sem exigir JSON completo.
  static bool hasFoodJsonSignal(String message) {
    final normalized = _normalizeJsonLikeText(message)
        .replaceAll('\n', '')
        .replaceAll('\r', '');

    return RegExp(r'"foods"\s*:').hasMatch(normalized) ||
        RegExp(r'"mealType"\s*:').hasMatch(normalized);
  }

  /// Detecta o início de um JSON de refeição ainda incompleto no stream.
  /// Isso permite esconder o payload bruto antes do JSON estar completo.
  static int? findFoodJsonCandidateStart(String message) {
    try {
      if (message.trim().isEmpty) return null;

      final completeJson = extractFoodJson(message);
      if (completeJson != null) {
        final completeStart = message.indexOf(completeJson);
        if (completeStart != -1) {
          return completeStart;
        }
      }

      final firstNonWhitespace = message.indexOf(RegExp(r'\S'));
      if (firstNonWhitespace != -1 && message[firstNonWhitespace] == '{') {
        final trimmedStart =
            _normalizeJsonLikeText(message.substring(firstNonWhitespace));

        if (trimmedStart.contains('"mealType"') ||
            trimmedStart.contains('"foods"') ||
            trimmedStart.startsWith('{')) {
          return firstNonWhitespace;
        }
      }

      final normalized = _normalizeJsonLikeText(message);

      final inlineMealTypeMatch =
          RegExp(r'\{\s*"mealType"').firstMatch(normalized);
      if (inlineMealTypeMatch != null) {
        return inlineMealTypeMatch.start;
      }

      final inlineFoodsMatch = RegExp(r'\{\s*"foods"').firstMatch(normalized);
      if (inlineFoodsMatch != null) {
        return inlineFoodsMatch.start;
      }

      final multilineJsonMatch = RegExp(r'[\r\n]\s*\{').firstMatch(message);
      if (multilineJsonMatch != null) {
        final matched = multilineJsonMatch.group(0)!;
        return multilineJsonMatch.start + matched.lastIndexOf('{');
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Remove da mensagem tanto o JSON completo quanto um candidato parcial em streaming.
  static String removeJsonCandidateFromMessage(String message) {
    try {
      final jsonStr = extractFoodJson(message);
      if (jsonStr != null) {
        return removeJsonFromMessage(message);
      }

      final candidateStart = findFoodJsonCandidateStart(message);
      if (candidateStart == null) return message;

      return message.substring(0, candidateStart).trimRight();
    } catch (e) {
      return message;
    }
  }

  /// Extrai o JSON de alimentos da mensagem
  static String? extractFoodJson(String message) {
    try {
      final cleanMessage = _normalizeJsonLikeText(message);

      // Encontrar a posição inicial do JSON
      final foodsIndex = _findFoodsKeyIndex(cleanMessage);
      if (foodsIndex == -1) return null;

      // Procurar para trás para encontrar o '{' inicial
      final startIndex = _findObjectStart(cleanMessage, foodsIndex);
      if (startIndex == -1) return null;

      // Usar contador de chaves para encontrar o fechamento correto
      final endIndex = _findObjectEnd(cleanMessage, startIndex);
      if (endIndex == -1) return null;

      return cleanMessage.substring(startIndex, endIndex + 1);
    } catch (e) {
      return null;
    }
  }

  /// Remove o JSON da mensagem, deixando apenas o texto
  static String removeJsonFromMessage(String message) {
    try {
      final jsonStr = extractFoodJson(message);
      if (jsonStr == null) return message;

      // Remover o JSON encontrado e também remover escapes se houver
      String cleaned = message.replaceAll(jsonStr, '');
      if (message.contains('\\"')) {
        // Se tinha escapes, também remover a versão original
        final originalJson = jsonStr.replaceAll('"', '\\"');
        cleaned = cleaned.replaceAll(originalJson, '');
      }
      if (cleaned == message) {
        final candidateStart = findFoodJsonCandidateStart(message);
        if (candidateStart != null) {
          cleaned = message.substring(0, candidateStart);
        }
      }
      return cleaned.trim();
    } catch (e) {
      return message;
    }
  }

  /// Extrai o mealType do JSON retornado pela IA
  static String? extractMealType(String jsonStr) {
    try {
      final normalizedJson = jsonStr
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final decoded = jsonDecode(normalizedJson);
      if (decoded is Map && decoded.containsKey('mealType')) {
        return decoded['mealType'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Converte o mealType da IA para MealType enum
  /// Suporta tanto tipos padrão quanto tipos personalizados do usuário
  static MealType mealTypeFromString(String? mealTypeStr) {
    if (mealTypeStr == null) return MealType.snack;

    final type = mealTypeStr.toLowerCase();

    // Tipos padrão do MealType enum
    if (type == 'breakfast') return MealType.breakfast;
    if (type == 'lunch') return MealType.lunch;
    if (type == 'dinner') return MealType.dinner;
    if (type == 'snack') return MealType.snack;
    if (type == 'freemeal' || type == 'free_meal') return MealType.freeMeal;

    // Tipos personalizados comuns mapeados para enum
    if (type.contains('breakfast') ||
        type.contains('cafe') ||
        type.contains('manhã')) {
      return MealType.breakfast;
    }
    if (type.contains('lunch') ||
        type.contains('almoço') ||
        type.contains('almoco')) {
      return MealType.lunch;
    }
    if (type.contains('dinner') || type.contains('jantar')) {
      return MealType.dinner;
    }
    if (type.contains('snack') ||
        type.contains('lanche') ||
        type.contains('afternoon') ||
        type.contains('tarde')) {
      return MealType.snack;
    }
    if (type.contains('supper') || type.contains('ceia')) {
      return MealType.snack; // Ceia mapeia para snack
    }

    // Fallback para snack
    return MealType.snack;
  }

  /// Parseia o JSON de alimentos e retorna uma lista de Food
  static List<Food>? parseFoodJson(String jsonStr) {
    try {
      // Normalizar JSON (remover quebras de linha e espaços extras)
      final normalizedJson = jsonStr
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final decoded = jsonDecode(normalizedJson);

      if (decoded is! Map || !decoded.containsKey('foods')) {
        return null;
      }

      final foodsList = decoded['foods'] as List;
      final foods = <Food>[];
      final seenFoods = <String>{};

      for (var foodData in foodsList) {
        if (foodData is! Map) continue;

        final name = foodData['name'] as String?;
        final portion = foodData['portion'] as String?;

        if (name == null) continue;

        final foodIdentity = _foodIdentity(name);
        if (!seenFoods.add(foodIdentity)) continue;

        // Tentar extrair macros de diferentes estruturas
        Map<String, dynamic>? macros;
        if (foodData.containsKey('macros')) {
          macros = foodData['macros'] as Map<String, dynamic>?;
        } else if (foodData.containsKey('nutrients')) {
          macros = foodData['nutrients'] as Map<String, dynamic>?;
        }

        if (macros == null) continue;

        // Limpar nomes de campos (remover espaços extras)
        final cleanMacros = <String, dynamic>{};
        macros.forEach((key, value) {
          cleanMacros[key.trim()] = value;
        });
        macros = cleanMacros;

        // Extrair valores nutricionais (com fallback para 0)
        final calories = _parseDouble(macros['calories']) ?? 0.0;
        final protein = _parseDouble(macros['protein']) ?? 0.0;
        final carbs =
            _parseDouble(macros['carbohydrate'] ?? macros['carbs']) ?? 0.0;
        final fat = _parseDouble(macros['fat']) ?? 0.0;

        // Extrair porção e unidade
        final parsedServing = parseServingFromPortion(portion);
        final servingSize = _parseDouble(macros['serving_size']) ??
            parsedServing?.amount ??
            100.0;
        final servingUnit =
            macros['serving_unit'] as String? ?? parsedServing?.unit ?? 'g';

        // Criar objeto Nutrient com os valores
        final nutrient = Nutrient(
          idFood: 0, // Temporário, pois não temos ID do banco ainda
          servingSize: servingSize,
          servingUnit: servingUnit,
          calories: calories,
          protein: protein,
          carbohydrate: carbs,
          fat: fat,
          saturatedFat:
              _parseDouble(macros['saturated_fat'] ?? macros['saturatedFat']),
          transFat: _parseDouble(macros['trans_fat'] ?? macros['transFat']),
          dietaryFiber:
              _parseDouble(macros['dietary_fiber'] ?? macros['dietaryFiber']),
          sugars: _parseDouble(macros['sugars']),
          cholesterol: _parseDouble(macros['cholesterol']),
          sodium: _parseDouble(macros['sodium']),
          potassium: _parseDouble(macros['potassium']),
          calcium: _parseDouble(macros['calcium']),
          iron: _parseDouble(macros['iron']),
          vitaminA: _parseDouble(macros['vitamin_a'] ?? macros['vitaminA']),
          vitaminC: _parseDouble(macros['vitamin_c'] ?? macros['vitaminC']),
          vitaminD: _parseDouble(macros['vitamin_d'] ?? macros['vitaminD']),
          vitaminB6: _parseDouble(macros['vitamin_b6'] ?? macros['vitaminB6']),
          vitaminB12:
              _parseDouble(macros['vitamin_b12'] ?? macros['vitaminB12']),
        );

        // Criar objeto Food
        final food = Food(
          name: name,
          emoji: resolveFoodEmoji(name),
          amount: portion ?? '${servingSize.toStringAsFixed(0)}$servingUnit',
          nutrients: [nutrient],
        );

        foods.add(food);
      }

      return foods.isEmpty ? null : foods;
    } catch (e) {
      return null;
    }
  }

  static String _foodIdentity(String name) {
    return name.trim().toLowerCase();
  }

  static ({double amount, String unit})? parseServingFromPortion(
    String? portion,
  ) {
    if (portion == null || portion.trim().isEmpty) return null;

    final normalized = _normalizePortionText(portion);
    final numberPattern = r'(\d+(?:[.,]\d+)?(?:\s*/\s*\d+(?:[.,]\d+)?)?)';
    final unitPattern =
        r'(fl\s*oz|gramas?|g|mililitros?|ml|quilos?|kg|litros?|l|copos?|xicaras?|fatias?|unidades?|colheres?|scoops?|cups?|tbsp|tsp)';
    final match = RegExp(
      '$numberPattern\\s*$unitPattern\\b',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (match == null) return null;

    final amount = _parseQuantity(match.group(1));
    if (amount == null || amount <= 0) return null;

    final unit = _normalizeServingUnit(match.group(2) ?? '');
    if (unit == null) return null;

    return (amount: amount * unit.multiplier, unit: unit.name);
  }

  static String _normalizePortionText(String value) {
    var normalized = value.toLowerCase().replaceAll(',', '.');
    final replacements = <String, String>{
      'meio': '0.5',
      'meia': '0.5',
      'um': '1',
      'uma': '1',
      'dois': '2',
      'duas': '2',
      'tres': '3',
      'quatro': '4',
      'cinco': '5',
    };

    normalized = _stripDiacritics(normalized);
    replacements.forEach((word, number) {
      normalized = normalized.replaceAll(RegExp('\\b$word\\b'), number);
    });

    return normalized;
  }

  static String _stripDiacritics(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    var result = value;
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  static double? _parseQuantity(String? raw) {
    if (raw == null) return null;
    final normalized = raw.replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      if (parts.length != 2) return null;
      final numerator = double.tryParse(parts[0]);
      final denominator = double.tryParse(parts[1]);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }

    return double.tryParse(normalized);
  }

  static ({String name, double multiplier})? _normalizeServingUnit(
    String rawUnit,
  ) {
    final unit = _stripDiacritics(rawUnit.toLowerCase())
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (unit == 'g' || unit.startsWith('grama')) {
      return (name: 'g', multiplier: 1.0);
    }
    if (unit == 'kg' || unit.startsWith('quilo')) {
      return (name: 'g', multiplier: 1000.0);
    }
    if (unit == 'ml' || unit.startsWith('mililitro')) {
      return (name: 'ml', multiplier: 1.0);
    }
    if (unit == 'l' || unit.startsWith('litro')) {
      return (name: 'ml', multiplier: 1000.0);
    }
    if (unit == 'oz') return (name: 'oz', multiplier: 1.0);
    if (unit == 'fl oz' || unit == 'floz') {
      return (name: 'fl oz', multiplier: 1.0);
    }
    if (unit.startsWith('copo')) return (name: 'copo', multiplier: 1.0);
    if (unit.startsWith('xicara') || unit == 'cup' || unit == 'cups') {
      return (name: 'xicara', multiplier: 1.0);
    }
    if (unit.startsWith('fatia')) return (name: 'fatia', multiplier: 1.0);
    if (unit.startsWith('unidade')) return (name: 'unidade', multiplier: 1.0);
    if (unit.startsWith('colher') || unit == 'tbsp' || unit == 'tsp') {
      return (name: 'colher', multiplier: 1.0);
    }
    if (unit.startsWith('scoop')) return (name: 'scoop', multiplier: 1.0);

    return null;
  }

  static String _normalizeJsonLikeText(String message) {
    return message
        .replaceAll('\\"', '"')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('„', '"')
        .replaceAll('‟', '"');
  }

  static int _findFoodsKeyIndex(String message) {
    return RegExp(r'"foods"\s*:').firstMatch(message)?.start ?? -1;
  }

  static int _findObjectStart(String message, int fromIndex) {
    for (var i = fromIndex; i >= 0; i--) {
      if (message[i] == '{') {
        return i;
      }
    }

    return -1;
  }

  static int _findObjectEnd(String message, int startIndex) {
    var braceCount = 0;
    var inString = false;
    var escaped = false;

    for (var i = startIndex; i < message.length; i++) {
      final char = message[i];

      if (escaped) {
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
      }

      if (!inString) {
        if (char == '{') {
          braceCount++;
        } else if (char == '}') {
          braceCount--;
          if (braceCount == 0) {
            return i;
          }
        }
      }
    }

    return -1;
  }

  /// Helper para converter valores para double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Cria uma Meal a partir de uma lista de Foods
  static Meal createMealFromFoods(List<Food> foods,
      {MealType type = MealType.freeMeal, DateTime? dateTime}) {
    return Meal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      foods: foods,
      dateTime: dateTime,
    );
  }

  /// Gera um resumo legivel do card de alimentos no formato
  /// "{kcal} kcal - {alimentos} - {tipo}". Retorna `null` se a mensagem
  /// nao contem um JSON valido de alimentos.
  static String? buildReadableFoodSummary(
    String message, {
    String Function(MealType type)? mealTypeNameResolver,
  }) {
    final jsonStr = extractFoodJson(message);
    if (jsonStr == null) return null;

    final foods = parseFoodJson(jsonStr);
    if (foods == null || foods.isEmpty) return null;

    final totalCalories =
        foods.fold<int>(0, (sum, food) => sum + food.calories);
    final foodNames = foods.map((f) => f.name).join(', ');

    final mealType = mealTypeFromString(extractMealType(jsonStr));
    final mealTypeName = mealTypeNameResolver?.call(mealType);

    final base = '$totalCalories kcal — $foodNames';
    return mealTypeName == null || mealTypeName.isEmpty
        ? base
        : '$base · $mealTypeName';
  }

  /// Retorna a mensagem com o JSON substituido por um resumo legivel do
  /// card. Util para copiar/ler em voz alta sem expor o JSON cru.
  static String toReadableMessage(
    String message, {
    String Function(MealType type)? mealTypeNameResolver,
  }) {
    final summary = buildReadableFoodSummary(
      message,
      mealTypeNameResolver: mealTypeNameResolver,
    );
    if (summary == null) return message;

    final cleanText = removeJsonCandidateFromMessage(message).trim();
    if (cleanText.isEmpty) return summary;
    return '$cleanText\n$summary';
  }
}
