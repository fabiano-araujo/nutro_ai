enum AllergenType {
  all,
  egg,
  fish,
  gluten,
  lactose,
  milk,
  nuts,
  peanuts,
  sesame,
  shellfish,
  soy,
}

enum AllergenStatus {
  free,        // free from (não contém)
  contains,    // contains (contém)
  mayContain,  // may contain (pode conter)
}

class FoodAllergen {
  final int? id;
  final int idFood;
  final AllergenType allergen;
  final AllergenStatus status;

  FoodAllergen({
    this.id,
    required this.idFood,
    required this.allergen,
    required this.status,
  });

  factory FoodAllergen.fromJson(Map<String, dynamic> json) {
    return FoodAllergen(
      id: json['id'],
      idFood: json['id_food'] ?? json['idFood'] ?? 0,
      allergen: _parseAllergen(json['allergen']),
      status: _parseStatus(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'id_food': idFood,
      'allergen': _allergenToString(allergen),
      'status': _statusToString(status),
    };
  }

  FoodAllergen copyWith({
    int? id,
    int? idFood,
    AllergenType? allergen,
    AllergenStatus? status,
  }) {
    return FoodAllergen(
      id: id ?? this.id,
      idFood: idFood ?? this.idFood,
      allergen: allergen ?? this.allergen,
      status: status ?? this.status,
    );
  }

  static AllergenType _parseAllergen(dynamic value) {
    if (value == null) return AllergenType.all;

    final allergenMap = {
      'all': AllergenType.all,
      'egg': AllergenType.egg,
      'fish': AllergenType.fish,
      'gluten': AllergenType.gluten,
      'lactose': AllergenType.lactose,
      'milk': AllergenType.milk,
      'nuts': AllergenType.nuts,
      'peanuts': AllergenType.peanuts,
      'sesame': AllergenType.sesame,
      'shellfish': AllergenType.shellfish,
      'soy': AllergenType.soy,
    };

    return allergenMap[value.toString().toLowerCase()] ?? AllergenType.all;
  }

  static AllergenStatus _parseStatus(dynamic value) {
    if (value == null) return AllergenStatus.free;

    final statusMap = {
      'free': AllergenStatus.free,
      'contains': AllergenStatus.contains,
      'may_contain': AllergenStatus.mayContain,
      'mayContain': AllergenStatus.mayContain,
    };

    return statusMap[value.toString()] ?? AllergenStatus.free;
  }

  static String _allergenToString(AllergenType allergen) {
    return allergen.toString().split('.').last;
  }

  static String _statusToString(AllergenStatus status) {
    switch (status) {
      case AllergenStatus.free:
        return 'free';
      case AllergenStatus.contains:
        return 'contains';
      case AllergenStatus.mayContain:
        return 'may_contain';
    }
  }
}
