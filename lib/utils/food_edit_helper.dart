import '../models/Nutrient.dart';
import '../models/food_model.dart';
import 'food_emoji_resolver.dart';
import 'food_json_parser.dart';

/// Regras deterministicas compartilhadas pelos editores de alimento.
class FoodEditHelper {
  const FoodEditHelper._();

  static ({String? amount, String name}) parseDescription(
    String foodDescription,
    Food fallbackFood,
  ) {
    final description = foodDescription.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (description.isEmpty) {
      return (amount: fallbackFood.amount, name: fallbackFood.name);
    }

    final leadingAmountMatch = RegExp(
      r'^((?:\d+(?:[.,]\d+)?|\d+\s*/\s*\d+)\s*'
      r'(?:fl\s*oz|gramas?|g|mililitros?|ml|quilos?|kg|litros?|l|'
      r'copos?|xicaras?|fatias?|unidades?|colheres?|scoops?|cups?|'
      r'tbsp|tsp|oz)?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(description);

    if (leadingAmountMatch != null) {
      final amount = leadingAmountMatch.group(1)?.trim();
      var name = leadingAmountMatch.group(2)?.trim() ?? '';
      name = name.replaceFirst(
        RegExp(r'^(de|da|do|dos|das)\s+', caseSensitive: false),
        '',
      );
      if (name.isNotEmpty) {
        return (amount: amount, name: name);
      }
    }

    return (amount: fallbackFood.amount, name: description);
  }

  static Food applyDescriptionLocally(
    Food originalFood,
    String foodDescription,
  ) {
    final parsed = parseDescription(foodDescription, originalFood);
    final name = parsed.name.trim();
    if (name.isEmpty) return originalFood;

    return originalFood.copyWith(
      name: name,
      amount: parsed.amount ?? originalFood.amount,
      emoji: resolveFoodEmoji(name),
      source: FoodSource.ai,
      clearSourceId: true,
      clearAiNutrients: true,
    );
  }

  /// Aceita flexao simples de plural para que `ovo` e `ovos` continuem sendo
  /// tratados como o mesmo alimento numa edicao exclusiva de porcao.
  static bool sameFoodNameForServingEdit(String left, String right) {
    final normalizedLeft = _normalizeName(left);
    final normalizedRight = _normalizeName(right);
    if (normalizedLeft == normalizedRight) return true;

    final leftWords = normalizedLeft.split(' ');
    final rightWords = normalizedRight.split(' ');
    if (leftWords.length != rightWords.length) return false;

    for (var index = 0; index < leftWords.length; index++) {
      if (_simpleSingular(leftWords[index]) !=
          _simpleSingular(rightWords[index])) {
        return false;
      }
    }
    return true;
  }

  /// Recalcula todos os nutrientes quando a nova porcao continua na mesma
  /// unidade metrica da porcao atual. Retorna `null` quando nao e seguro
  /// escalar localmente e o chamador deve recorrer a uma nova estimativa.
  static Food? applyMetricServing({
    required Food food,
    required String name,
    required String amount,
  }) {
    final targetServing = FoodJsonParser.parseServingFromPortion(amount);
    if (targetServing == null ||
        (targetServing.unit != 'g' && targetServing.unit != 'ml')) {
      return null;
    }

    final nutrient = food.primaryNutrient;
    if (nutrient == null) return null;

    final currentServing = _currentMetricServing(food, nutrient);
    if (currentServing == null ||
        currentServing.unit != targetServing.unit ||
        currentServing.amount <= 0) {
      return null;
    }

    final ratio = targetServing.amount / currentServing.amount;

    double? scale(double? value) {
      if (value == null) return null;
      return (value * ratio * 10).roundToDouble() / 10;
    }

    double? scaleCalories(double? value) {
      if (value == null) return null;
      return (value * ratio).roundToDouble();
    }

    final updatedNutrient = nutrient.copyWith(
      servingSize: targetServing.amount,
      servingUnit: targetServing.unit,
      calories: scaleCalories(nutrient.calories),
      carbohydrate: scale(nutrient.carbohydrate),
      protein: scale(nutrient.protein),
      fat: scale(nutrient.fat),
      saturatedFat: scale(nutrient.saturatedFat),
      polyunsaturatedFat: scale(nutrient.polyunsaturatedFat),
      monounsaturatedFat: scale(nutrient.monounsaturatedFat),
      transFat: scale(nutrient.transFat),
      cholesterol: scale(nutrient.cholesterol),
      sodium: scale(nutrient.sodium),
      potassium: scale(nutrient.potassium),
      dietaryFiber: scale(nutrient.dietaryFiber),
      sugars: scale(nutrient.sugars),
      addedSugars: scale(nutrient.addedSugars),
      vitaminD: scale(nutrient.vitaminD),
      vitaminA: scale(nutrient.vitaminA),
      vitaminC: scale(nutrient.vitaminC),
      calcium: scale(nutrient.calcium),
      iron: scale(nutrient.iron),
      vitaminB6: scale(nutrient.vitaminB6),
      vitaminB12: scale(nutrient.vitaminB12),
    );
    final aiSnapshot = food.aiNutrients ??
        (food.source == FoodSource.ai ? food.nutrients : null);

    return food.copyWith(
      name: name,
      amount: amount,
      emoji: resolveFoodEmoji(name),
      nutrients: [updatedNutrient],
      source: FoodSource.manual,
      clearSourceId: true,
      aiNutrients: aiSnapshot,
    );
  }

  static ({double amount, String unit})? _currentMetricServing(
    Food food,
    Nutrient nutrient,
  ) {
    final nutrientUnit = _normalizeUnit(nutrient.servingUnit);
    if ((nutrientUnit == 'g' || nutrientUnit == 'ml') &&
        nutrient.servingSize > 0) {
      return (amount: nutrient.servingSize, unit: nutrientUnit);
    }

    final parsedAmount =
        FoodJsonParser.parseServingFromPortion(food.amount ?? '');
    if (parsedAmount == null ||
        (parsedAmount.unit != 'g' && parsedAmount.unit != 'ml')) {
      return null;
    }
    return parsedAmount;
  }

  static String _normalizeUnit(String value) {
    final normalized = _stripDiacritics(value.toLowerCase())
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized == 'g' || normalized.startsWith('grama')) return 'g';
    if (normalized == 'ml' || normalized.startsWith('mililitro')) return 'ml';
    return normalized;
  }

  static String _normalizeName(String value) {
    return _stripDiacritics(value.toLowerCase())
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _simpleSingular(String word) {
    if (word.length > 3 && word.endsWith('s')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  static String _stripDiacritics(String value) {
    return value
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }
}
