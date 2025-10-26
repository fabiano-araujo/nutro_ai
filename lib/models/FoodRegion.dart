import 'Portion.dart';

class FoodRegion {
  final int? id;
  final String regionCode;
  final String languageCode;
  final int idFood;
  final String? description;
  final String translation;
  final int confirmationStatus;
  final List<Portion>? portions;

  FoodRegion({
    this.id,
    required this.regionCode,
    required this.languageCode,
    required this.idFood,
    this.description,
    required this.translation,
    this.confirmationStatus = 0,
    this.portions,
  });

  factory FoodRegion.fromJson(Map<String, dynamic> json) {
    return FoodRegion(
      id: json['id'],
      regionCode: json['region_code'] ?? json['regionCode'] ?? '',
      languageCode: json['language_code'] ?? json['languageCode'] ?? '',
      idFood: json['id_food'] ?? json['idFood'] ?? 0,
      description: json['description'],
      translation: json['translation'] ?? '',
      confirmationStatus: json['confirmation_status'] ?? json['confirmationStatus'] ?? 0,
      portions: (json['portion'] as List<dynamic>?)
          ?.map((p) => Portion.fromJson(p))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'region_code': regionCode,
      'language_code': languageCode,
      'id_food': idFood,
      if (description != null) 'description': description,
      'translation': translation,
      'confirmation_status': confirmationStatus,
      if (portions != null)
        'portion': portions!.map((p) => p.toJson()).toList(),
    };
  }

  FoodRegion copyWith({
    int? id,
    String? regionCode,
    String? languageCode,
    int? idFood,
    String? description,
    String? translation,
    int? confirmationStatus,
    List<Portion>? portions,
  }) {
    return FoodRegion(
      id: id ?? this.id,
      regionCode: regionCode ?? this.regionCode,
      languageCode: languageCode ?? this.languageCode,
      idFood: idFood ?? this.idFood,
      description: description ?? this.description,
      translation: translation ?? this.translation,
      confirmationStatus: confirmationStatus ?? this.confirmationStatus,
      portions: portions ?? this.portions,
    );
  }
}
