class Nutrient {
  final int? id;
  final int idFood;
  final double servingSize;
  final String servingUnit;
  final double? calories;
  final double? carbohydrate;
  final double? protein;
  final double? fat;
  final double? saturatedFat;
  final double? polyunsaturatedFat;
  final double? monounsaturatedFat;
  final double? transFat;
  final double? cholesterol;
  final double? sodium;
  final double? potassium;
  final double? dietaryFiber;
  final double? sugars;
  final double? addedSugars;
  final double? vitaminD;
  final double? vitaminA;
  final double? vitaminC;
  final double? calcium;
  final double? iron;
  final double? vitaminB6;
  final double? vitaminB12;

  Nutrient({
    this.id,
    required this.idFood,
    required this.servingSize,
    required this.servingUnit,
    this.calories,
    this.carbohydrate,
    this.protein,
    this.fat,
    this.saturatedFat,
    this.polyunsaturatedFat,
    this.monounsaturatedFat,
    this.transFat,
    this.cholesterol,
    this.sodium,
    this.potassium,
    this.dietaryFiber,
    this.sugars,
    this.addedSugars,
    this.vitaminD,
    this.vitaminA,
    this.vitaminC,
    this.calcium,
    this.iron,
    this.vitaminB6,
    this.vitaminB12,
  });

  factory Nutrient.fromJson(Map<String, dynamic> json) {
    return Nutrient(
      id: json['id'],
      idFood: json['id_food'] ?? json['idFood'] ?? 0,
      servingSize: _toDouble(json['serving_size'] ?? json['servingSize'] ?? 0) ?? 0.0,
      servingUnit: json['serving_unit'] ?? json['servingUnit'] ?? '',
      calories: _toDouble(json['calories']),
      carbohydrate: _toDouble(json['carbohydrate']),
      protein: _toDouble(json['protein']),
      fat: _toDouble(json['fat']),
      saturatedFat: _toDouble(json['saturated_fat'] ?? json['saturatedFat']),
      polyunsaturatedFat: _toDouble(json['polyunsaturated_fat'] ?? json['polyunsaturatedFat']),
      monounsaturatedFat: _toDouble(json['monounsaturated_fat'] ?? json['monounsaturatedFat']),
      transFat: _toDouble(json['trans_fat'] ?? json['transFat']),
      cholesterol: _toDouble(json['cholesterol']),
      sodium: _toDouble(json['sodium']),
      potassium: _toDouble(json['potassium']),
      dietaryFiber: _toDouble(json['dietary_fiber'] ?? json['dietaryFiber']),
      sugars: _toDouble(json['sugars']),
      addedSugars: _toDouble(json['added_sugars'] ?? json['addedSugars']),
      vitaminD: _toDouble(json['vitamin_d'] ?? json['vitaminD']),
      vitaminA: _toDouble(json['vitamin_a'] ?? json['vitaminA']),
      vitaminC: _toDouble(json['vitamin_c'] ?? json['vitaminC']),
      calcium: _toDouble(json['calcium']),
      iron: _toDouble(json['iron']),
      vitaminB6: _toDouble(json['vitamin_b6'] ?? json['vitaminB6']),
      vitaminB12: _toDouble(json['vitamin_b12'] ?? json['vitaminB12']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'id_food': idFood,
      'serving_size': servingSize,
      'serving_unit': servingUnit,
      if (calories != null) 'calories': calories,
      if (carbohydrate != null) 'carbohydrate': carbohydrate,
      if (protein != null) 'protein': protein,
      if (fat != null) 'fat': fat,
      if (saturatedFat != null) 'saturated_fat': saturatedFat,
      if (polyunsaturatedFat != null) 'polyunsaturated_fat': polyunsaturatedFat,
      if (monounsaturatedFat != null) 'monounsaturated_fat': monounsaturatedFat,
      if (transFat != null) 'trans_fat': transFat,
      if (cholesterol != null) 'cholesterol': cholesterol,
      if (sodium != null) 'sodium': sodium,
      if (potassium != null) 'potassium': potassium,
      if (dietaryFiber != null) 'dietary_fiber': dietaryFiber,
      if (sugars != null) 'sugars': sugars,
      if (addedSugars != null) 'added_sugars': addedSugars,
      if (vitaminD != null) 'vitamin_d': vitaminD,
      if (vitaminA != null) 'vitamin_a': vitaminA,
      if (vitaminC != null) 'vitamin_c': vitaminC,
      if (calcium != null) 'calcium': calcium,
      if (iron != null) 'iron': iron,
      if (vitaminB6 != null) 'vitamin_b6': vitaminB6,
      if (vitaminB12 != null) 'vitamin_b12': vitaminB12,
    };
  }

  Nutrient copyWith({
    int? id,
    int? idFood,
    double? servingSize,
    String? servingUnit,
    double? calories,
    double? carbohydrate,
    double? protein,
    double? fat,
    double? saturatedFat,
    double? polyunsaturatedFat,
    double? monounsaturatedFat,
    double? transFat,
    double? cholesterol,
    double? sodium,
    double? potassium,
    double? dietaryFiber,
    double? sugars,
    double? addedSugars,
    double? vitaminD,
    double? vitaminA,
    double? vitaminC,
    double? calcium,
    double? iron,
    double? vitaminB6,
    double? vitaminB12,
  }) {
    return Nutrient(
      id: id ?? this.id,
      idFood: idFood ?? this.idFood,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      carbohydrate: carbohydrate ?? this.carbohydrate,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      saturatedFat: saturatedFat ?? this.saturatedFat,
      polyunsaturatedFat: polyunsaturatedFat ?? this.polyunsaturatedFat,
      monounsaturatedFat: monounsaturatedFat ?? this.monounsaturatedFat,
      transFat: transFat ?? this.transFat,
      cholesterol: cholesterol ?? this.cholesterol,
      sodium: sodium ?? this.sodium,
      potassium: potassium ?? this.potassium,
      dietaryFiber: dietaryFiber ?? this.dietaryFiber,
      sugars: sugars ?? this.sugars,
      addedSugars: addedSugars ?? this.addedSugars,
      vitaminD: vitaminD ?? this.vitaminD,
      vitaminA: vitaminA ?? this.vitaminA,
      vitaminC: vitaminC ?? this.vitaminC,
      calcium: calcium ?? this.calcium,
      iron: iron ?? this.iron,
      vitaminB6: vitaminB6 ?? this.vitaminB6,
      vitaminB12: vitaminB12 ?? this.vitaminB12,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
