import 'Nutrient.dart';
import 'FoodRegion.dart';
import 'FoodAllergen.dart';

/// Origem dos macros exibidos no card.
/// - [favorite]: alimento favorito do usuario (prioridade maxima).
/// - [manual]: macros personalizados pelo usuario neste alimento.
/// - [recent]: alimento ja usado antes pelo usuario.
/// - [catalog]: alimento encontrado no banco/catalogo nutricional.
/// - [ai]: estimativa gerada pela IA (fallback).
enum FoodSource { favorite, manual, recent, catalog, ai }

FoodSource foodSourceFromString(String? value) {
  switch (value) {
    case 'favorite':
      return FoodSource.favorite;
    case 'manual':
    case 'custom':
    case 'personalized':
      return FoodSource.manual;
    case 'recent':
      return FoodSource.recent;
    case 'catalog':
      return FoodSource.catalog;
    default:
      return FoodSource.ai;
  }
}

String foodSourceToString(FoodSource source) {
  switch (source) {
    case FoodSource.favorite:
      return 'favorite';
    case FoodSource.manual:
      return 'manual';
    case FoodSource.recent:
      return 'recent';
    case FoodSource.catalog:
      return 'catalog';
    case FoodSource.ai:
      return 'ai';
  }
}

class Food {
  // Database fields from Prisma schema
  final int? id;
  final String name;
  final String? photo;
  final int? idFatsecret;
  final String? brand;
  final String? isVegetarian;
  final String? isVegan;

  // Legacy/UI fields for backward compatibility
  final String? amount;
  final String emoji;

  // Origem dos macros (favorito > manual > recente > catalogo > IA)
  final FoodSource source;
  final int? sourceId;

  // Snapshot dos macros originais da IA, preservado quando o usuario troca
  // a fonte (favorito/recente/manual) para permitir voltar ao valor da IA.
  final List<Nutrient>? aiNutrients;

  // Relationships
  final List<Nutrient>? nutrients;
  final List<FoodRegion>? foodRegions;
  final List<FoodAllergen>? foodAllergens;

  Food({
    this.id,
    required this.name,
    this.photo,
    this.idFatsecret,
    this.brand,
    this.isVegetarian,
    this.isVegan,
    this.amount,
    this.emoji = '🍽️',
    this.source = FoodSource.ai,
    this.sourceId,
    this.aiNutrients,
    this.nutrients,
    this.foodRegions,
    this.foodAllergens,
  });

  // Computed properties for backward compatibility
  Nutrient? get primaryNutrient {
    final values = nutrients;
    if (values == null || values.isEmpty) return null;
    return values.first;
  }

  int get calories {
    return primaryNutrient?.calories?.toInt() ?? 0;
  }

  double get protein {
    return primaryNutrient?.protein ?? 0.0;
  }

  double get carbs {
    return primaryNutrient?.carbohydrate ?? 0.0;
  }

  double get fat {
    return primaryNutrient?.fat ?? 0.0;
  }

  String? get imageUrl => photo;

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'],
      name: json['name'] ?? '',
      photo: json['photo'],
      idFatsecret: json['id_fatsecret'] ?? json['idFatsecret'],
      brand: json['brand'],
      isVegetarian: json['is_vegetarian'] ?? json['isVegetarian'],
      isVegan: json['is_vegan'] ?? json['isVegan'],
      amount: json['amount'],
      emoji: json['emoji'] ?? '🍽️',
      source: foodSourceFromString(json['source'] as String?),
      sourceId: json['sourceId'] as int?,
      aiNutrients: (json['ai_nutrient'] ?? json['aiNutrient']) is List
          ? ((json['ai_nutrient'] ?? json['aiNutrient']) as List<dynamic>)
              .map((n) => Nutrient.fromJson(n))
              .toList()
          : null,
      nutrients: (json['nutrient'] as List<dynamic>?)
          ?.map((n) => Nutrient.fromJson(n))
          .toList(),
      foodRegions: (json['food_region'] as List<dynamic>?)
          ?.map((fr) => FoodRegion.fromJson(fr))
          .toList(),
      foodAllergens: (json['food_allergen'] as List<dynamic>?)
          ?.map((fa) => FoodAllergen.fromJson(fa))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (photo != null) 'photo': photo,
      if (idFatsecret != null) 'id_fatsecret': idFatsecret,
      if (brand != null) 'brand': brand,
      if (isVegetarian != null) 'is_vegetarian': isVegetarian,
      if (isVegan != null) 'is_vegan': isVegan,
      if (amount != null) 'amount': amount,
      'emoji': emoji,
      'source': foodSourceToString(source),
      if (sourceId != null) 'sourceId': sourceId,
      if (aiNutrients != null)
        'ai_nutrient': aiNutrients!.map((n) => n.toJson()).toList(),
      if (nutrients != null)
        'nutrient': nutrients!.map((n) => n.toJson()).toList(),
      if (foodRegions != null)
        'food_region': foodRegions!.map((fr) => fr.toJson()).toList(),
      if (foodAllergens != null)
        'food_allergen': foodAllergens!.map((fa) => fa.toJson()).toList(),
    };
  }

  Food copyWith({
    int? id,
    String? name,
    String? photo,
    int? idFatsecret,
    String? brand,
    String? isVegetarian,
    String? isVegan,
    String? amount,
    String? emoji,
    FoodSource? source,
    int? sourceId,
    bool clearSourceId = false,
    bool clearAiNutrients = false,
    List<Nutrient>? aiNutrients,
    List<Nutrient>? nutrients,
    List<FoodRegion>? foodRegions,
    List<FoodAllergen>? foodAllergens,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      photo: photo ?? this.photo,
      idFatsecret: idFatsecret ?? this.idFatsecret,
      brand: brand ?? this.brand,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      amount: amount ?? this.amount,
      emoji: emoji ?? this.emoji,
      source: source ?? this.source,
      sourceId: clearSourceId ? null : sourceId ?? this.sourceId,
      aiNutrients: clearAiNutrients ? null : aiNutrients ?? this.aiNutrients,
      nutrients: nutrients ?? this.nutrients,
      foodRegions: foodRegions ?? this.foodRegions,
      foodAllergens: foodAllergens ?? this.foodAllergens,
    );
  }
}
