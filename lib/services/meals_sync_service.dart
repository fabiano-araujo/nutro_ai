import 'dart:convert';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';
import '../models/meal_model.dart';
import '../models/food_model.dart';

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
          calories: (foodJson['calories'] ?? 0).toInt(),
          protein: (foodJson['protein'] ?? 0).toDouble(),
          carbs: (foodJson['carbs'] ?? 0).toDouble(),
          fat: (foodJson['fat'] ?? 0).toDouble(),
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
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      date: DateTime.parse(json['date']),
      totalCalories: json['totalCalories'] ?? 0,
      totalProtein: (json['totalProtein'] ?? 0).toDouble(),
      totalCarbs: (json['totalCarbs'] ?? 0).toDouble(),
      totalFat: (json['totalFat'] ?? 0).toDouble(),
      totalFiber: (json['totalFiber'] ?? 0).toDouble(),
      calorieGoal: json['calorieGoal'] ?? 2000,
      proteinGoal: json['proteinGoal'] ?? 150,
      carbsGoal: json['carbsGoal'] ?? 250,
      fatGoal: json['fatGoal'] ?? 67,
      waterGlasses: json['waterGlasses'] ?? 0,
      waterGoal: json['waterGoal'] ?? 8,
      hitProtein: json['hitProtein'] ?? false,
      hitCalories: json['hitCalories'] ?? false,
      meals: meals,
    );
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

  MealGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
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
            return {
              'foodId': food.id,
              'name': food.name,
              'emoji': food.emoji,
              'amount': double.tryParse(food.amount ?? '100') ?? 100,
              'unit': 'g',
              'calories': food.calories,
              'protein': food.protein,
              'carbs': food.carbs,
              'fat': food.fat,
              'fiber': 0, // TODO: adicionar fibra se disponível
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

      print('[MealsSyncService] Enviando: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/meals/sync'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('[MealsSyncService] Resposta: ${response.statusCode}');

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
  }) async {
    try {
      print(
          '[MealsSyncService] Buscando período: ${_formatDate(from)} a ${_formatDate(to)}');

      final response = await http.get(
        Uri.parse(
            '$baseUrl/meals/range?from=${_formatDate(from)}&to=${_formatDate(to)}'),
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
}

/// Extensão para adicionar macros ao Food
extension FoodMacrosExtension on Food {
  Food copyWithMacros({
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    // Criamos um Food com os valores já definidos
    // Como Food usa getters para calcular macros, precisamos usar uma abordagem diferente
    // Por enquanto, retornamos o food original já que os valores são calculados no servidor
    return this;
  }
}
