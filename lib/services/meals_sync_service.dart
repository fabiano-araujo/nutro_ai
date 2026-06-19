import 'dart:convert';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';
import '../models/meal_model.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';

/// Modelo para resumo diário do servidor
class DailySummary {
  final int id;
  final int userId;
  final DateTime date;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final int calorieGoal;
  final int proteinGoal;
  final int carbsGoal;
  final int fatGoal;
  final int waterGlasses;
  final int waterGoal;
  final bool hitProtein;
  final bool hitCalories;
  final List<Meal> meals;

  DailySummary({
    required this.id,
    required this.userId,
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.waterGlasses,
    required this.waterGoal,
    required this.hitProtein,
    required this.hitCalories,
    required this.meals,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final mealsJson = json['meals'] as List<dynamic>? ?? [];
    final meals = mealsJson.map((mealJson) {
      final foodsJson = mealJson['foods'] as List<dynamic>? ?? [];
      final foods = foodsJson.map((foodJson) {
        return Food(
          id: foodJson['foodId'],
          name: foodJson['name'] ?? '',
          emoji: foodJson['emoji'] ?? '',
          amount: (foodJson['amount'] ?? 100).toString(),
          nutrients: [], // Nutrientes já calculados, não precisamos do modelo completo
          // Os valores já estão calculados, vamos usar getters customizados
        ).copyWithMacros(
          calories: _readInt(foodJson['calories']),
          protein: _readDouble(foodJson['protein']),
          carbs: _readDouble(foodJson['carbs']),
          fat: _readDouble(foodJson['fat']),
          fiber: _readDouble(foodJson['fiber']),
          servingSize: _readDouble(foodJson['amount'], fallback: 100),
          servingUnit: foodJson['unit']?.toString() ?? 'g',
        );
      }).toList();

      return Meal(
        id: mealJson['id'].toString(),
        type: _parseMealType(mealJson['type']),
        foods: foods,
        dateTime: mealJson['mealTime'] != null
            ? DateTime.parse(mealJson['mealTime'])
            : null,
        messageId: mealJson['messageId'],
      );
    }).toList();

    return DailySummary(
      id: _readInt(json['id']),
      userId: _readInt(json['userId']),
      date: DateTime.parse(json['date']),
      totalCalories: _readInt(json['totalCalories']),
      totalProtein: _readDouble(json['totalProtein']),
      totalCarbs: _readDouble(json['totalCarbs']),
      totalFat: _readDouble(json['totalFat']),
      totalFiber: _readDouble(json['totalFiber']),
      calorieGoal: _readInt(json['calorieGoal'], fallback: 2000),
      proteinGoal: _readInt(json['proteinGoal'], fallback: 150),
      carbsGoal: _readInt(json['carbsGoal'], fallback: 250),
      fatGoal: _readInt(json['fatGoal'], fallback: 67),
      waterGlasses: _readInt(json['waterGlasses']),
      waterGoal: _readInt(json['waterGoal'], fallback: 8),
      hitProtein: _readBool(json['hitProtein']),
      hitCalories: _readBool(json['hitCalories']),
      meals: meals,
    );
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ??
        fallback;
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return fallback;
  }

  static MealType _parseMealType(String? type) {
    switch (type) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      case 'freeMeal':
      default:
        return MealType.freeMeal;
    }
  }
}

/// Modelo para metas do usuário
class MealGoals {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String? fitnessGoal;

  MealGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fitnessGoal,
  });

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        if (fitnessGoal != null) 'fitnessGoal': fitnessGoal,
      };
}

/// Service para sincronização de refeições com o servidor
class MealsSyncService {
  static const String baseUrl = AppConstants.API_BASE_URL;

  /// Sincronizar refeições de um dia
  static Future<DailySummary?> syncDay({
    required String token,
    required DateTime date,
    required List<Meal> meals,
    required int waterGlasses,
    required MealGoals goals,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      print('[MealsSyncService] Sincronizando dia: ${_formatDate(date)}');
      print('[MealsSyncService] Refeições: ${meals.length}');

      final mealsJson = meals.map((meal) {
        return {
          'type': meal.type.toString().split('.').last,
          'name': null,
          'mealTime': meal.dateTime.toIso8601String(),
          'messageId': meal.messageId,
          'foods': meal.foods.map((food) {
            final nutrient = food.primaryNutrient;
            return {
              'foodId': food.id,
              'name': food.name,
              'emoji': food.emoji,
              'amount': nutrient?.servingSize ??
                  double.tryParse(food.amount ?? '100') ??
                  100,
              'unit': nutrient?.servingUnit ?? 'g',
              'calories': food.calories,
              'protein': food.protein,
              'carbs': food.carbs,
              'fat': food.fat,
              'fiber': nutrient?.dietaryFiber ?? 0,
            };
          }).toList(),
        };
      }).toList();

      final body = {
        'date': _formatDate(date),
        'meals': mealsJson,
        'waterGlasses': waterGlasses,
        'goals': goals.toJson(),
      };

      final requestBody = jsonEncode(body);
      final foodCount = meals.fold<int>(
        0,
        (count, meal) => count + meal.foods.length,
      );
      print(
          '[MEALS_SYNC_PERF] request_prepared elapsedMs=${stopwatch.elapsedMilliseconds} date=${_formatDate(date)} meals=${meals.length} foods=$foodCount bytes=${requestBody.length} preview=${_preview(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/meals/sync'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      print(
          '[MEALS_SYNC_PERF] response_received elapsedMs=${stopwatch.elapsedMilliseconds} status=${response.statusCode} bytes=${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print('[MealsSyncService] Sincronização bem-sucedida');
          return DailySummary.fromJson(data['data']);
        }
      }

      print('[MealsSyncService] Erro na sincronização: ${response.body}');
      return null;
    } catch (e) {
      print('[MealsSyncService] Erro ao sincronizar: $e');
      return null;
    } finally {
      print(
          '[MEALS_SYNC_PERF] sync_day_done elapsedMs=${stopwatch.elapsedMilliseconds} date=${_formatDate(date)}');
    }
  }

  /// Buscar refeições de um dia específico
  static Future<DailySummary?> getDaySummary({
    required String token,
    required DateTime date,
  }) async {
    try {
      print('[MealsSyncService] Buscando dia: ${_formatDate(date)}');

      final response = await http.get(
        Uri.parse('$baseUrl/meals/day/${_formatDate(date)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return DailySummary.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      print('[MealsSyncService] Erro ao buscar dia: $e');
      return null;
    }
  }

  /// Buscar refeições de um período
  static Future<List<DailySummary>> getMealsRange({
    required String token,
    required DateTime from,
    required DateTime to,
    bool summaryOnly = false,
  }) async {
    try {
      print(
          '[MealsSyncService] Buscando período: ${_formatDate(from)} a ${_formatDate(to)}');

      final query = <String, String>{
        'from': _formatDate(from),
        'to': _formatDate(to),
        if (summaryOnly) 'summaryOnly': 'true',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/meals/range').replace(queryParameters: query),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final summaries = (data['data'] as List<dynamic>)
              .map((item) => DailySummary.fromJson(item))
              .toList();
          print('[MealsSyncService] ${summaries.length} dias encontrados');
          return summaries;
        }
      }

      return [];
    } catch (e) {
      print('[MealsSyncService] Erro ao buscar período: $e');
      return [];
    }
  }

  /// Buscar histórico de macros
  static Future<List<Map<String, dynamic>>> getMacrosHistory({
    required String token,
    int days = 30,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/meals/history?days=$days'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      return [];
    } catch (e) {
      print('[MealsSyncService] Erro ao buscar histórico: $e');
      return [];
    }
  }

  /// Atualizar água do dia
  static Future<bool> updateWater({
    required String token,
    required DateTime date,
    required int waterGlasses,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/meals/water'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': _formatDate(date),
          'waterGlasses': waterGlasses,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[MealsSyncService] Erro ao atualizar água: $e');
      return false;
    }
  }

  /// Buscar estatísticas do usuário
  static Future<Map<String, dynamic>?> getUserStats({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/meals/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }

      return null;
    } catch (e) {
      print('[MealsSyncService] Erro ao buscar estatísticas: $e');
      return null;
    }
  }

  /// Formatar data para a API (YYYY-MM-DD)
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _preview(String value, {int maxChars = 240}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars)}...';
  }
}

/// Extensão para adicionar macros ao Food
extension FoodMacrosExtension on Food {
  Food copyWithMacros({
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    double servingSize = 100,
    String servingUnit = 'g',
  }) {
    final nutrient = Nutrient(
      idFood: id ?? 0,
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories.toDouble(),
      protein: protein,
      carbohydrate: carbs,
      fat: fat,
      dietaryFiber: fiber,
    );

    return copyWith(nutrients: [nutrient]);
  }
}
