import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import '../services/notification_service.dart';
import '../services/user_app_state_service.dart';

class MealTypeConfig {
  final String id;
  final String name;
  final String emoji;
  final int order;
  final String reminderTime;

  MealTypeConfig({
    required this.id,
    required this.name,
    required this.emoji,
    required this.order,
    String? reminderTime,
  }) : reminderTime = normalizeReminderTime(reminderTime) ??
            defaultReminderTime(id, order);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'order': order,
      'reminderTime': reminderTime,
    };
  }

  factory MealTypeConfig.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? '';
    final order = json['order'] ?? 0;
    return MealTypeConfig(
      id: id,
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '🍽️',
      order: order,
      reminderTime: json['reminderTime'] ?? json['time'],
    );
  }

  MealTypeConfig copyWith({
    String? id,
    String? name,
    String? emoji,
    int? order,
    String? reminderTime,
  }) {
    final nextId = id ?? this.id;
    final nextOrder = order ?? this.order;
    return MealTypeConfig(
      id: nextId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      order: nextOrder,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  static String defaultReminderTime(String id, int order) {
    switch (id) {
      case 'breakfast':
        return '07:00';
      case 'morning_snack':
        return '10:00';
      case 'lunch':
        return '12:00';
      case 'afternoon_snack':
        return '15:00';
      case 'dinner':
        return '19:00';
      case 'supper':
        return '21:00';
    }

    const fallbackTimes = [
      '07:00',
      '10:00',
      '12:00',
      '15:00',
      '19:00',
      '21:00',
      '22:00',
      '23:00',
    ];

    if (order >= 0 && order < fallbackTimes.length) {
      return fallbackTimes[order];
    }

    return '12:00';
  }

  static String? normalizeReminderTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class MealTypesProvider extends ChangeNotifier {
  List<MealTypeConfig> _mealTypes = [];
  static const String _storageKey = 'meal_types_config';
  static const String _pendingSyncKey = 'meal_types_pending_server_sync';
  bool _isLoaded = false;
  String? _token;
  int? _userId;
  bool _hasPendingServerSync = false;
  bool _isSyncingToServer = false;
  int _stateRevision = 0;
  Timer? _syncDebounce;
  final UserAppStateService _appStateService = UserAppStateService();

  List<MealTypeConfig> get mealTypes => List.unmodifiable(_mealTypes);
  bool get isLoaded => _isLoaded;
  bool get hasPendingServerSync => _hasPendingServerSync;
  bool get isSyncingToServer => _isSyncingToServer;

  MealTypesProvider() {
    _loadMealTypes();
  }

  /// Ensure meal types are loaded before using
  Future<void> ensureLoaded() async {
    if (!_isLoaded) {
      await _loadMealTypes();
    }
  }

  Future<void> setAuth(
    String token,
    int userId, {
    List<dynamic> serverMealTypes = const <dynamic>[],
  }) async {
    await ensureLoaded();
    _token = token;
    _userId = userId;
    await _loadPendingSyncFlag();

    if (serverMealTypes.isNotEmpty) {
      await applyServerSnapshot(serverMealTypes);
      return;
    }

    if (_hasPendingServerSync || _hasCustomMealTypes) {
      await syncPendingIfNeeded();
    }
  }

  void clearAuth() {
    _token = null;
    _userId = null;
    _syncDebounce?.cancel();
  }

  Future<void> applyServerSnapshot(List<dynamic> serverMealTypes) async {
    final parsed = serverMealTypes
        .whereType<Map>()
        .map((json) => MealTypeConfig.fromJson(json.cast<String, dynamic>()))
        .where((mealType) => mealType.id.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (parsed.isEmpty) {
      return;
    }

    _mealTypes = parsed;
    _stateRevision++;
    await _saveMealTypes(markPendingSync: false);
    _hasPendingServerSync = false;
    await _savePendingSyncFlag();
    notifyListeners();
  }

  // Load meal types from storage or use defaults
  Future<void> _loadMealTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(_storageKey);

      if (storedData != null && storedData.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(storedData);
        _mealTypes =
            jsonList.map((json) => MealTypeConfig.fromJson(json)).toList();

        // Sort by order
        _mealTypes.sort((a, b) => a.order.compareTo(b.order));
      } else {
        // Use default meal types
        _setDefaultMealTypes();
      }
      await _loadPendingSyncFlag();
    } catch (e) {
      print('Error loading meal types: $e');
      _setDefaultMealTypes();
    }
    _isLoaded = true;
    notifyListeners();
  }

  void _setDefaultMealTypes() {
    _mealTypes = _defaultMealTypes();
  }

  // Save meal types to storage
  Future<void> _saveMealTypes({bool markPendingSync = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(
        _mealTypes.map((mealType) => mealType.toJson()).toList(),
      );
      await prefs.setString(_storageKey, jsonString);
      if (markPendingSync) {
        _hasPendingServerSync = true;
        await _savePendingSyncFlag();
      }
      await NotificationService().syncScheduledNotifications();
    } catch (e) {
      print('Error saving meal types: $e');
    }
  }

  // Add a new meal type
  Future<void> addMealType(
    String name,
    String emoji, {
    String? reminderTime,
  }) async {
    final newOrder = _mealTypes.isEmpty
        ? 0
        : _mealTypes.map((m) => m.order).reduce((a, b) => a > b ? a : b) + 1;

    final newMealType = MealTypeConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      emoji: emoji,
      order: newOrder,
      reminderTime: reminderTime,
    );

    _mealTypes.add(newMealType);
    _mealTypes.sort((a, b) => a.order.compareTo(b.order));

    _stateRevision++;
    await _saveMealTypes();
    _scheduleSync();
    notifyListeners();
  }

  // Update a meal type
  Future<void> updateMealType(
    String id, {
    String? name,
    String? emoji,
    String? reminderTime,
  }) async {
    final index = _mealTypes.indexWhere((m) => m.id == id);
    if (index != -1) {
      _mealTypes[index] = _mealTypes[index].copyWith(
        name: name,
        emoji: emoji,
        reminderTime: reminderTime,
      );
      _stateRevision++;
      await _saveMealTypes();
      _scheduleSync();
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

    _stateRevision++;
    await _saveMealTypes();
    _scheduleSync();
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

    _stateRevision++;
    await _saveMealTypes();
    _scheduleSync();
    notifyListeners();
  }

  // Reset to default meal types
  Future<void> resetToDefaults() async {
    _setDefaultMealTypes();
    _stateRevision++;
    await _saveMealTypes();
    _scheduleSync();
    notifyListeners();
  }

  Future<void> setMealCount(int count) async {
    final normalizedCount = count.clamp(1, 8).toInt();
    if (_mealTypes.length == normalizedCount) {
      return;
    }

    _mealTypes = _mealTypesForCount(normalizedCount);
    _stateRevision++;
    await _saveMealTypes();
    _scheduleSync();
    notifyListeners();
  }

  List<MealTypeConfig> _mealTypesForCount(int count) {
    final defaultsById = {
      for (final mealType in _defaultMealTypes()) mealType.id: mealType,
    };

    final orderedIds = switch (count) {
      1 => const ['lunch'],
      2 => const ['lunch', 'dinner'],
      3 => const ['breakfast', 'lunch', 'dinner'],
      4 => const ['breakfast', 'lunch', 'afternoon_snack', 'dinner'],
      _ => const ['breakfast', 'lunch', 'afternoon_snack', 'dinner', 'supper'],
    };

    final mealTypes = orderedIds
        .map((id) => defaultsById[id])
        .whereType<MealTypeConfig>()
        .toList();

    var extraIndex = 1;
    while (mealTypes.length < count) {
      mealTypes.add(
        MealTypeConfig(
          id: 'extra_${mealTypes.length + 1}',
          name: 'Refeição extra $extraIndex',
          emoji: '🍽️',
          order: mealTypes.length,
        ),
      );
      extraIndex++;
    }

    return [
      for (var index = 0; index < mealTypes.length; index++)
        mealTypes[index].copyWith(order: index),
    ];
  }

  // Get meal type by id
  MealTypeConfig? getMealTypeById(String id) {
    try {
      return _mealTypes.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> toServerPayload() =>
      _mealTypes.map((mealType) => mealType.toJson()).toList();

  bool get _hasCustomMealTypes {
    final current = jsonEncode(toServerPayload());
    final defaults =
        _defaultMealTypes().map((mealType) => mealType.toJson()).toList();
    return current != jsonEncode(defaults);
  }

  List<MealTypeConfig> _defaultMealTypes() {
    return [
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

  Future<void> syncPendingIfNeeded() async {
    if (_token == null || _userId == null) return;
    if (!_hasPendingServerSync && !_hasCustomMealTypes) return;
    await _syncToServer();
  }

  void _scheduleSync() {
    if (_token == null || _userId == null) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), _syncToServer);
  }

  Future<void> _syncToServer() async {
    if (_isSyncingToServer || _token == null || _userId == null) return;

    _isSyncingToServer = true;
    final syncRevision = _stateRevision;
    notifyListeners();

    try {
      await _appStateService.syncAppState(
        token: _token!,
        mealTypes: toServerPayload(),
      );
      if (_stateRevision == syncRevision) {
        _hasPendingServerSync = false;
        await _savePendingSyncFlag();
      }
    } catch (e) {
      _hasPendingServerSync = true;
      await _savePendingSyncFlag();
      print('Error syncing meal types with server: $e');
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
