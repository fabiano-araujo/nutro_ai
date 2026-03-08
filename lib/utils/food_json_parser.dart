import 'dart:convert';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';

class FoodJsonParser {
  /// Detecta se há um JSON de alimentos na mensagem
  static bool containsFoodJson(String message) {
    try {
      // Normalizar mensagem para detecção mais rápida (remover quebras de linha)
      final normalized = message.replaceAll('\n', '').replaceAll('\r', '');

      // Procurar por padrões como: {"foods": ou {\"foods\":
      if (!normalized.contains('"foods"') &&
          !normalized.contains('\\"foods\\"')) {
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
        final trimmedStart = message.substring(firstNonWhitespace);

        if (trimmedStart.contains('"mealType"') ||
            trimmedStart.contains('\\"mealType\\"') ||
            trimmedStart.contains('"foods"') ||
            trimmedStart.contains('\\"foods\\"') ||
            trimmedStart.startsWith('{')) {
          return firstNonWhitespace;
        }
      }

      final inlineMealTypeMatch =
          RegExp(r'\{\s*\\?"mealType').firstMatch(message);
      if (inlineMealTypeMatch != null) {
        return inlineMealTypeMatch.start;
      }

      final inlineFoodsMatch = RegExp(r'\{\s*\\?"foods').firstMatch(message);
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
      // Fazer unescape se necessário
      String cleanMessage =
          message.contains('\\"') ? message.replaceAll('\\"', '"') : message;

      // Encontrar a posição inicial do JSON
      final foodsIndex = cleanMessage.indexOf('"foods"');
      if (foodsIndex == -1) return null;

      // Procurar para trás para encontrar o '{' inicial
      int startIndex = -1;
      for (int i = foodsIndex; i >= 0; i--) {
        if (cleanMessage[i] == '{') {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) return null;

      // Usar contador de chaves para encontrar o fechamento correto
      int braceCount = 0;
      int endIndex = -1;

      for (int i = startIndex; i < cleanMessage.length; i++) {
        if (cleanMessage[i] == '{') {
          braceCount++;
        } else if (cleanMessage[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            endIndex = i;
            break;
          }
        }
      }

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

      for (var foodData in foodsList) {
        if (foodData is! Map) continue;

        final name = foodData['name'] as String?;
        final portion = foodData['portion'] as String?;

        if (name == null) continue;

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
        final servingSize = _parseDouble(macros['serving_size']) ?? 100.0;
        final servingUnit = macros['serving_unit'] as String? ?? 'g';

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
          emoji: _getFoodEmoji(name),
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

  /// Helper para converter valores para double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Retorna um emoji apropriado baseado no nome do alimento
  static String _getFoodEmoji(String foodName) {
    final name = foodName.toLowerCase();

    // Carnes
    if (name.contains('chicken') || name.contains('frango')) return '🍗';
    if (name.contains('beef') || name.contains('carne')) return '🥩';
    if (name.contains('fish') || name.contains('peixe')) return '🐟';
    if (name.contains('pork') || name.contains('porco')) return '🥓';

    // Grãos e cereais
    if (name.contains('rice') || name.contains('arroz')) return '🍚';
    if (name.contains('bread') || name.contains('pão')) return '🍞';
    if (name.contains('pasta') || name.contains('macarrão')) return '🍝';
    if (name.contains('oats') || name.contains('aveia')) return '🥣';

    // Vegetais
    if (name.contains('salad') || name.contains('salada')) return '🥗';
    if (name.contains('broccoli') || name.contains('brócolis')) return '🥦';
    if (name.contains('carrot') || name.contains('cenoura')) return '🥕';
    if (name.contains('tomato') || name.contains('tomate')) return '🍅';

    // Frutas
    if (name.contains('apple') || name.contains('maçã')) return '🍎';
    if (name.contains('banana')) return '🍌';
    if (name.contains('orange') || name.contains('laranja')) return '🍊';
    if (name.contains('strawberry') || name.contains('morango')) return '🍓';

    // Laticínios
    if (name.contains('milk') || name.contains('leite')) return '🥛';
    if (name.contains('cheese') || name.contains('queijo')) return '🧀';
    if (name.contains('yogurt') || name.contains('iogurte')) return '🥛';

    // Ovos
    if (name.contains('egg') || name.contains('ovo')) return '🥚';

    // Bebidas
    if (name.contains('water') || name.contains('água')) return '💧';
    if (name.contains('juice') || name.contains('suco')) return '🧃';
    if (name.contains('coffee') || name.contains('café')) return '☕';

    // Snacks
    if (name.contains('nuts') ||
        name.contains('castanha') ||
        name.contains('amendoim')) return '🥜';
    if (name.contains('chocolate')) return '🍫';

    // Default
    return '🍽️';
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
}
