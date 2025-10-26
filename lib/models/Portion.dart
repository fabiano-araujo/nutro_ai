class Portion {
  final int? id;
  final int idFoodRegion;
  final double proportion;
  final String description;

  Portion({
    this.id,
    required this.idFoodRegion,
    required this.proportion,
    required this.description,
  });

  factory Portion.fromJson(Map<String, dynamic> json) {
    return Portion(
      id: json['id'],
      idFoodRegion: json['id_food_region'] ?? json['idFoodRegion'] ?? 0,
      proportion: _toDouble(json['proportion']) ?? 0.0,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'id_food_region': idFoodRegion,
      'proportion': proportion,
      'description': description,
    };
  }

  Portion copyWith({
    int? id,
    int? idFoodRegion,
    double? proportion,
    String? description,
  }) {
    return Portion(
      id: id ?? this.id,
      idFoodRegion: idFoodRegion ?? this.idFoodRegion,
      proportion: proportion ?? this.proportion,
      description: description ?? this.description,
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
