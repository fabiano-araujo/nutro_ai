import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../models/food_model.dart';
import '../services/user_app_state_service.dart';

class FoodHistoryProvider extends ChangeNotifier {
  List<Food> _favorites = [];
  List<Food> _recents = [];
  Map<String, int> _frequencyMap = {}; // foodId -> count
  String? _token;
  int? _userId;
  bool _hasPendingServerSync = false;
  bool _isSyncingToServer = false;
  int _stateRevision = 0;
  Timer? _syncDebounce;
  final UserAppStateService _appStateService = UserAppStateService();

  List<Food> get favorites => _favorites;
  List<Food> get recents => _recents;
  bool get hasPendingServerSync => _hasPendingServerSync;
  bool get isSyncingToServer => _isSyncingToServer;

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
  static const String _pendingSyncKey = 'food_history_pending_server_sync';

  FoodHistoryProvider() {
    _loadData();
  }

  Future<void> setAuth(
    String token,
    int userId, {
    Map<String, dynamic>? serverFoodHistory,
  }) async {
    _token = token;
    _userId = userId;
    await _loadPendingSyncFlag();

    if (_hasServerFoodHistory(serverFoodHistory)) {
      await applyServerSnapshot(serverFoodHistory!);
      return;
    }

    if (_hasPendingServerSync || _hasAnyLocalData) {
      await syncPendingIfNeeded();
    }
  }

  void clearAuth() {
    _token = null;
    _userId = null;
    _syncDebounce?.cancel();
  }

  Future<void> applyServerSnapshot(Map<String, dynamic> payload) async {
    _favorites = _parseFoodList(payload['favorites']);
    _recents = _parseFoodList(payload['recents']);
    _frequencyMap = _parseFrequencyMap(payload['frequency']);
    _stateRevision++;
    _hasPendingServerSync = false;
    await _saveAll(markPendingSync: false);
    await _savePendingSyncFlag();
    notifyListeners();
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

    await _loadPendingSyncFlag();

    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_favoritesKey, json);
    await _markPendingAndScheduleSync();
  }

  Future<void> _saveRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_recents.map((f) => f.toJson()).toList());
    await prefs.setString(_recentsKey, json);
    await _markPendingAndScheduleSync();
  }

  Future<void> _saveFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_frequencyMap);
    await prefs.setString(_frequencyKey, json);
    await _markPendingAndScheduleSync();
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
    _stateRevision++;
    await _markPendingAndScheduleSync();

    notifyListeners();
  }

  Map<String, dynamic> toServerPayload() => {
        'favorites': _favorites.map((food) => food.toJson()).toList(),
        'recents': _recents.map((food) => food.toJson()).toList(),
        'frequency': _frequencyMap,
      };

  bool get _hasAnyLocalData =>
      _favorites.isNotEmpty || _recents.isNotEmpty || _frequencyMap.isNotEmpty;

  bool _hasServerFoodHistory(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    return (payload['favorites'] is List &&
            (payload['favorites'] as List).isNotEmpty) ||
        (payload['recents'] is List && (payload['recents'] as List).isNotEmpty) ||
        (payload['frequency'] is Map &&
            (payload['frequency'] as Map).isNotEmpty);
  }

  List<Food> _parseFoodList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((json) => Food.fromJson(json.cast<String, dynamic>()))
        .where((food) => food.name.trim().isNotEmpty)
        .toList();
  }

  Map<String, int> _parseFrequencyMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, count) {
      final parsedCount =
          count is int ? count : int.tryParse(count?.toString() ?? '') ?? 0;
      return MapEntry(key.toString(), parsedCount);
    })..removeWhere((key, count) => key.trim().isEmpty || count <= 0);
  }

  Future<void> _saveAll({bool markPendingSync = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritesKey,
      jsonEncode(_favorites.map((f) => f.toJson()).toList()),
    );
    await prefs.setString(
      _recentsKey,
      jsonEncode(_recents.map((f) => f.toJson()).toList()),
    );
    await prefs.setString(_frequencyKey, jsonEncode(_frequencyMap));
    if (markPendingSync) {
      await _markPendingAndScheduleSync();
    }
  }

  Future<void> _markPendingAndScheduleSync() async {
    _stateRevision++;
    _hasPendingServerSync = true;
    await _savePendingSyncFlag();
    _scheduleSync();
  }

  Future<void> syncPendingIfNeeded() async {
    if (_token == null || _userId == null) return;
    if (!_hasPendingServerSync && !_hasAnyLocalData) return;
    await _syncToServer();
  }

  void _scheduleSync() {
    if (_token == null || _userId == null) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), () {
      _syncToServer();
    });
  }

  Future<void> _syncToServer() async {
    if (_isSyncingToServer || _token == null || _userId == null) return;

    _isSyncingToServer = true;
    final syncRevision = _stateRevision;
    notifyListeners();

    try {
      await _appStateService.syncAppState(
        token: _token!,
        foodHistory: toServerPayload(),
      );
      if (_stateRevision == syncRevision) {
        _hasPendingServerSync = false;
        await _savePendingSyncFlag();
      }
    } catch (e) {
      _hasPendingServerSync = true;
      await _savePendingSyncFlag();
      print('Error syncing food history with server: $e');
    } finally {
      _isSyncingToServer = false;
      notifyListeners();
    }
  }

  Future<void> _loadPendingSyncFlag() async {
    final prefs = await SharedPreferences.getInstance();
    _hasPendingServerSync = prefs.getBool(_pendingSyncKey) ?? false;
  }

  Future<void> _savePendingSyncFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSyncKey, _hasPendingServerSync);
  }
}
