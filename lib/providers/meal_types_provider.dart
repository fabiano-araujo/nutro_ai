import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MealTypeConfig {
  final String id;
  final String name;
  final String emoji;
  final int order;

  MealTypeConfig({
    required this.id,
    required this.name,
    required this.emoji,
    required this.order,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'order': order,
    };
  }

  factory MealTypeConfig.fromJson(Map<String, dynamic> json) {
    return MealTypeConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '🍽️',
      order: json['order'] ?? 0,
    );
  }

  MealTypeConfig copyWith({
    String? id,
    String? name,
    String? emoji,
    int? order,
  }) {
    return MealTypeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      order: order ?? this.order,
    );
  }
}

class MealTypesProvider extends ChangeNotifier {
  List<MealTypeConfig> _mealTypes = [];
  static const String _storageKey = 'meal_types_config';

  List<MealTypeConfig> get mealTypes => List.unmodifiable(_mealTypes);

  MealTypesProvider() {
    _loadMealTypes();
  }

  // Load meal types from storage or use defaults
  Future<void> _loadMealTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(_storageKey);

      if (storedData != null && storedData.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(storedData);
        _mealTypes = jsonList
            .map((json) => MealTypeConfig.fromJson(json))
            .toList();

        // Sort by order
        _mealTypes.sort((a, b) => a.order.compareTo(b.order));
      } else {
        // Use default meal types
        _setDefaultMealTypes();
      }
    } catch (e) {
      print('Error loading meal types: $e');
      _setDefaultMealTypes();
    }
    notifyListeners();
  }

  void _setDefaultMealTypes() {
    _mealTypes = [
      MealTypeConfig(
        id: 'breakfast',
        name: 'Café da Manhã',
        emoji: '🍳',
        order: 0,
      ),
      MealTypeConfig(
        id: 'lunch',
        name: 'Almoço',
        emoji: '🍽️',
        order: 1,
      ),
      MealTypeConfig(
        id: 'afternoon_snack',
        name: 'Lanche da Tarde',
        emoji: '🍎',
        order: 2,
      ),
      MealTypeConfig(
        id: 'dinner',
        name: 'Jantar',
        emoji: '🍝',
        order: 3,
      ),
      MealTypeConfig(
        id: 'supper',
        name: 'Ceia',
        emoji: '🥛',
        order: 4,
      ),
    ];
  }

  // Save meal types to storage
  Future<void> _saveMealTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(
        _mealTypes.map((mealType) => mealType.toJson()).toList(),
      );
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving meal types: $e');
    }
  }

  // Add a new meal type
  Future<void> addMealType(String name, String emoji) async {
    final newOrder = _mealTypes.isEmpty
        ? 0
        : _mealTypes.map((m) => m.order).reduce((a, b) => a > b ? a : b) + 1;

    final newMealType = MealTypeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      emoji: emoji,
      order: newOrder,
    );

    _mealTypes.add(newMealType);
    _mealTypes.sort((a, b) => a.order.compareTo(b.order));

    await _saveMealTypes();
    notifyListeners();
  }

  // Update a meal type
  Future<void> updateMealType(String id, {String? name, String? emoji}) async {
    final index = _mealTypes.indexWhere((m) => m.id == id);
    if (index != -1) {
      _mealTypes[index] = _mealTypes[index].copyWith(
        name: name,
        emoji: emoji,
      );
      await _saveMealTypes();
      notifyListeners();
    }
  }

  // Delete a meal type
  Future<void> deleteMealType(String id) async {
    _mealTypes.removeWhere((m) => m.id == id);

    // Reorder remaining items
    for (int i = 0; i < _mealTypes.length; i++) {
      _mealTypes[i] = _mealTypes[i].copyWith(order: i);
    }

    await _saveMealTypes();
    notifyListeners();
  }

  // Reorder meal types
  Future<void> reorderMealTypes(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _mealTypes.removeAt(oldIndex);
    _mealTypes.insert(newIndex, item);

    // Update order values
    for (int i = 0; i < _mealTypes.length; i++) {
      _mealTypes[i] = _mealTypes[i].copyWith(order: i);
    }

    await _saveMealTypes();
    notifyListeners();
  }

  // Reset to default meal types
  Future<void> resetToDefaults() async {
    _setDefaultMealTypes();
    await _saveMealTypes();
    notifyListeners();
  }

  // Get meal type by id
  MealTypeConfig? getMealTypeById(String id) {
    try {
      return _mealTypes.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
}
