import 'dart:convert';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';

/// Modelo simplificado de alimento favorito/recente
class FavoriteFood {
  final int id;
  final String name;
  final String? emoji;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double baseAmount;
  final String baseUnit;
  final int? usageCount;
  final DateTime? lastUsedAt;

  FavoriteFood({
    required this.id,
    required this.name,
    this.emoji,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.baseAmount = 100,
    this.baseUnit = 'g',
    this.usageCount,
    this.lastUsedAt,
  });

  factory FavoriteFood.fromJson(Map<String, dynamic> json) {
    return FavoriteFood(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      emoji: json['emoji'],
      calories: json['calories'] ?? 0,
      protein: (json['protein'] is String
              ? double.tryParse(json['protein'])
              : json['protein']?.toDouble()) ??
          0.0,
      carbs: (json['carbs'] is String
              ? double.tryParse(json['carbs'])
              : json['carbs']?.toDouble()) ??
          0.0,
      fat: (json['fat'] is String
              ? double.tryParse(json['fat'])
              : json['fat']?.toDouble()) ??
          0.0,
      fiber: (json['fiber'] is String
              ? double.tryParse(json['fiber'])
              : json['fiber']?.toDouble()) ??
          0.0,
      baseAmount: (json['baseAmount'] is String
              ? double.tryParse(json['baseAmount'])
              : json['baseAmount']?.toDouble()) ??
          100.0,
      baseUnit: json['baseUnit'] ?? 'g',
      usageCount: json['usageCount'],
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'])
          : null,
    );
  }

  /// Formata macros como texto curto
  String get macrosSummary =>
      '${calories}cal · ${protein.toStringAsFixed(0)}p · ${carbs.toStringAsFixed(0)}c · ${fat.toStringAsFixed(0)}g';
}

/// Modelo de refeição repetível
class RepeatableMeal {
  final int id;
  final String type;
  final String? name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime? date;
  final List<RepeatableMealFood> foods;

  RepeatableMeal({
    required this.id,
    required this.type,
    this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.date,
    required this.foods,
  });

  factory RepeatableMeal.fromJson(Map<String, dynamic> json) {
    final foodsJson = json['foods'] as List<dynamic>? ?? [];
    return RepeatableMeal(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'freeMeal',
      name: json['name'],
      calories: json['calories'] ?? 0,
      protein: (json['protein'] is String
              ? double.tryParse(json['protein'])
              : json['protein']?.toDouble()) ??
          0.0,
      carbs: (json['carbs'] is String
              ? double.tryParse(json['carbs'])
              : json['carbs']?.toDouble()) ??
          0.0,
      fat: (json['fat'] is String
              ? double.tryParse(json['fat'])
              : json['fat']?.toDouble()) ??
          0.0,
      date: json['dailySummary']?['date'] != null
          ? DateTime.tryParse(json['dailySummary']['date'])
          : null,
      foods: foodsJson
          .map((f) => RepeatableMealFood.fromJson(f))
          .toList(),
    );
  }

  String get foodNames => foods.map((f) => f.name).join(', ');

  String get typeEmoji {
    switch (type) {
      case 'breakfast':
        return '☀️';
      case 'lunch':
        return '🍽️';
      case 'dinner':
        return '🌙';
      case 'snack':
        return '🍎';
      default:
        return '🍴';
    }
  }
}

class RepeatableMealFood {
  final String name;
  final String? emoji;
  final double amount;
  final String unit;
  final int calories;

  RepeatableMealFood({
    required this.name,
    this.emoji,
    required this.amount,
    required this.unit,
    required this.calories,
  });

  factory RepeatableMealFood.fromJson(Map<String, dynamic> json) {
    return RepeatableMealFood(
      name: json['name'] ?? '',
      emoji: json['emoji'],
      amount: (json['amount'] is String
              ? double.tryParse(json['amount'])
              : json['amount']?.toDouble()) ??
          100.0,
      unit: json['unit'] ?? 'g',
      calories: json['calories'] ?? 0,
    );
  }
}

/// Serviço para favoritos, recentes e refeições repetíveis
class FavoriteFoodService {
  static const String _baseUrl = AppConstants.DIET_API_BASE_URL;

  final String token;

  FavoriteFoodService({required this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ============================================
  // FAVORITOS
  // ============================================

  Future<List<FavoriteFood>> getFavorites() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/favorites'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        return list.map((j) => FavoriteFood.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      print('[FavoriteFoodService] Erro ao buscar favoritos: $e');
      return [];
    }
  }

  Future<List<FavoriteFood>> searchFavorites(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/favorites/search?q=${Uri.encodeComponent(query)}'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        return list.map((j) => FavoriteFood.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      print('[FavoriteFoodService] Erro ao buscar favoritos: $e');
      return [];
    }
  }

  Future<bool> addFavorite(FavoriteFood food) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/favorites'),
        headers: _headers,
        body: jsonEncode({
          'name': food.name,
          'emoji': food.emoji,
          'calories': food.calories,
          'protein': food.protein,
          'carbs': food.carbs,
          'fat': food.fat,
          'fiber': food.fiber,
          'baseAmount': food.baseAmount,
          'baseUnit': food.baseUnit,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FavoriteFoodService] Erro ao adicionar favorito: $e');
      return false;
    }
  }

  Future<bool> deleteFavorite(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/favorites/$id'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FavoriteFoodService] Erro ao deletar favorito: $e');
      return false;
    }
  }

  // ============================================
  // RECENTES
  // ============================================

  Future<List<FavoriteFood>> getFrequents({int limit = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/favorites/frequents?limit=$limit'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        return list.map((j) => FavoriteFood.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      print('[FavoriteFoodService] Erro ao buscar frequentes: $e');
      return [];
    }
  }

  Future<List<FavoriteFood>> getRecents({int limit = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/favorites/recents?limit=$limit'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        return list.map((j) => FavoriteFood.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      print('[FavoriteFoodService] Erro ao buscar recentes: $e');
      return [];
    }
  }

  // ============================================
  // REFEIÇÕES REPETÍVEIS
  // ============================================

  Future<List<RepeatableMeal>> getRepeatableMeals({int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/meals/repeatable?limit=$limit'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        return list.map((j) => RepeatableMeal.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      print('[FavoriteFoodService] Erro ao buscar refeições repetíveis: $e');
      return [];
    }
  }

  // ============================================
  // PÓS-PROCESSAMENTO IA
  // ============================================

  /// Envia os alimentos da IA para o servidor substituir macros pelos favoritos
  /// e auto-salvar nos recentes. Retorna a lista processada (ou null em erro).
  Future<List<Map<String, dynamic>>?> processAiResponse(
      List<Map<String, dynamic>> foods) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/favorites/process-ai'),
        headers: _headers,
        body: jsonEncode({'foods': foods}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      print('[FavoriteFoodService] Erro ao processar resposta da IA: $e');
      return null;
    }
  }

  Future<bool> repeatMeal(int mealId, String targetDate) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/meals/repeat'),
        headers: _headers,
        body: jsonEncode({
          'mealId': mealId,
          'targetDate': targetDate,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FavoriteFoodService] Erro ao repetir refeição: $e');
      return false;
    }
  }
}
