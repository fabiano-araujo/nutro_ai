import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/food_model.dart';

class FoodHistoryProvider extends ChangeNotifier {
  List<Food> _favorites = [];
  List<Food> _recents = [];
  Map<String, int> _frequencyMap = {}; // foodId -> count

  List<Food> get favorites => _favorites;
  List<Food> get recents => _recents;

  List<Food> get frequents {
    // Sort foods by frequency count
    final frequentFoods = <Food>[];
    final sortedEntries = _frequencyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries.take(20)) {
      final food = _findFoodById(entry.key);
      if (food != null) {
        frequentFoods.add(food);
      }
    }
    return frequentFoods;
  }

  static const String _favoritesKey = 'food_favorites';
  static const String _recentsKey = 'food_recents';
  static const String _frequencyKey = 'food_frequency';

  FoodHistoryProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load favorites
    final favoritesJson = prefs.getString(_favoritesKey);
    if (favoritesJson != null) {
      final List<dynamic> decoded = jsonDecode(favoritesJson);
      _favorites = decoded.map((json) => Food.fromJson(json)).toList();
    }

    // Load recents
    final recentsJson = prefs.getString(_recentsKey);
    if (recentsJson != null) {
      final List<dynamic> decoded = jsonDecode(recentsJson);
      _recents = decoded.map((json) => Food.fromJson(json)).toList();
    }

    // Load frequency map
    final frequencyJson = prefs.getString(_frequencyKey);
    if (frequencyJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(frequencyJson);
      _frequencyMap = decoded.map((key, value) => MapEntry(key, value as int));
    }

    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_favoritesKey, json);
  }

  Future<void> _saveRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_recents.map((f) => f.toJson()).toList());
    await prefs.setString(_recentsKey, json);
  }

  Future<void> _saveFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_frequencyMap);
    await prefs.setString(_frequencyKey, json);
  }

  // Favorites
  bool isFavorite(Food food) {
    final foodId = _getFoodId(food);
    return _favorites.any((f) => _getFoodId(f) == foodId);
  }

  Future<void> toggleFavorite(Food food) async {
    final foodId = _getFoodId(food);

    if (isFavorite(food)) {
      _favorites.removeWhere((f) => _getFoodId(f) == foodId);
    } else {
      _favorites.insert(0, food);
    }

    await _saveFavorites();
    notifyListeners();
  }

  // Recents
  Future<void> addToRecents(Food food) async {
    final foodId = _getFoodId(food);

    // Remove if already exists
    _recents.removeWhere((f) => _getFoodId(f) == foodId);

    // Add to beginning
    _recents.insert(0, food);

    // Keep only last 50
    if (_recents.length > 50) {
      _recents = _recents.take(50).toList();
    }

    await _saveRecents();
    notifyListeners();
  }

  // Frequency tracking
  Future<void> incrementFrequency(Food food) async {
    final foodId = _getFoodId(food);
    _frequencyMap[foodId] = (_frequencyMap[foodId] ?? 0) + 1;

    await _saveFrequency();
    notifyListeners();
  }

  // Helper methods
  String _getFoodId(Food food) {
    // Use idFatsecret if available, otherwise use name as ID
    if (food.idFatsecret != null) {
      return 'fs_${food.idFatsecret}';
    }
    return 'name_${food.name}';
  }

  Food? _findFoodById(String foodId) {
    // Try to find in recents first (most likely to have full data)
    for (final food in _recents) {
      if (_getFoodId(food) == foodId) return food;
    }
    // Try favorites
    for (final food in _favorites) {
      if (_getFoodId(food) == foodId) return food;
    }
    return null;
  }

  // Clear all data
  Future<void> clearAll() async {
    _favorites.clear();
    _recents.clear();
    _frequencyMap.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
    await prefs.remove(_recentsKey);
    await prefs.remove(_frequencyKey);

    notifyListeners();
  }
}
