import 'Nutrient.dart';
import 'FoodRegion.dart';
import 'FoodAllergen.dart';

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
    this.nutrients,
    this.foodRegions,
    this.foodAllergens,
  });

  // Computed properties for backward compatibility
  int get calories {
    if (nutrients != null && nutrients!.isNotEmpty) {
      return nutrients!.first.calories?.toInt() ?? 0;
    }
    return 0;
  }

  double get protein {
    if (nutrients != null && nutrients!.isNotEmpty) {
      return nutrients!.first.protein ?? 0.0;
    }
    return 0.0;
  }

  double get carbs {
    if (nutrients != null && nutrients!.isNotEmpty) {
      return nutrients!.first.carbohydrate ?? 0.0;
    }
    return 0.0;
  }

  double get fat {
    if (nutrients != null && nutrients!.isNotEmpty) {
      return nutrients!.first.fat ?? 0.0;
    }
    return 0.0;
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
      nutrients: nutrients ?? this.nutrients,
      foodRegions: foodRegions ?? this.foodRegions,
      foodAllergens: foodAllergens ?? this.foodAllergens,
    );
  }
}
