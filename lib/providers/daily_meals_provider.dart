import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/meal_model.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../services/meals_sync_service.dart';

class DailyMealsSyncSnapshot {
  final DateTime date;
  final List<Meal> meals;
  final int waterGlasses;
  final MealGoals goals;

  DailyMealsSyncSnapshot({
    required this.date,
    required List<Meal> meals,
    required this.waterGlasses,
    required this.goals,
  }) : meals = List.unmodifiable(meals);
}

class DailyMealsProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  final Map<String, List<Meal>> _mealsByDate = {};
  final Map<String, int> _waterByDate = {};
  final Map<String, _StoredDailySummary> _serverSummariesByDate = {};
  final Map<String, Set<String>> _deletedChatMealIdsByDate = {};
  final Set<String> _pendingSyncDateKeys = {};
  final Map<String, int> _localRevisionByDate = {};
  final Set<String> _loadedDetailDateKeys = {};
  final Set<String> _loadingDetailDateKeys = {};
  final Set<String> _loadedSummaryMonthKeys = {};
  late final Future<void> _initialLoadFuture;
  bool _isLoaded = false;
  static const int _initialSummaryLookbackDays = 90;
  static const String _deletedChatMealsPrefsKey =
      'daily_meals_deleted_chat_meal_ids';

  // Goals (can be customized by user later)
  int caloriesGoal = 2000;
  int proteinGoal = 150;
  int carbsGoal = 250;
  int fatsGoal = 67;
  int waterGoal = 8; // Default 8 glasses
  String? fitnessGoal;

  // ========== SYNC WITH SERVER ==========
  String? _userId;
  String? _token;
  Timer? _syncDebounce;
  bool _isSyncing = false;
  bool _syncRequestedWhileSyncing = false;
  bool _isLoadingFromServer = false;
  int _mealAdditionVersion = 0;
  DateTime? _lastMealAdditionDate;

  /// Callback disparado após sync bem-sucedido do dia atual.
  /// Usado para auto check-in de streak (ver main_navigation.dart).
  void Function()? onTodaySynced;

  // Getters para estado de sync
  bool get isSyncing => _isSyncing;
  bool get isLoadingFromServer => _isLoadingFromServer;
  bool get isAuthenticated => _userId != null && _token != null;
  bool get isLoaded => _isLoaded;
  Future<void> get ready => _initialLoadFuture;
  bool get hasAnyLocalMealData => getLocalSyncSnapshots().isNotEmpty;
  int get mealAdditionVersion => _mealAdditionVersion;
  DateTime? get lastMealAdditionDate => _lastMealAdditionDate;

  DailyMealsProvider() {
    _initialLoadFuture = _loadFromPreferences();
  }

  /// Define credenciais de autenticação e carrega dados do servidor
  Future<void> setAuth(String userId, String token) async {
    print('[🔄 AUTH_DATA] DailyMealsProvider.setAuth() - userId: $userId');
    _userId = userId;
    _token = token;
    print(
        '[🔄 AUTH_DATA] DailyMealsProvider.setAuth() - Carregando dados do servidor...');
    await _loadFromServer();
    if (_pendingSyncDateKeys.isNotEmpty) {
      _scheduleSync();
    }
    print(
        '[🔄 AUTH_DATA] DailyMealsProvider.setAuth() - ✅ Carregamento concluído');
  }

  /// Limpa credenciais de autenticação
  void clearAuth() {
    print('[🔄 AUTH_DATA] DailyMealsProvider.clearAuth() - Limpando auth...');
    _userId = null;
    _token = null;
    _syncDebounce?.cancel();
    print('[🔄 AUTH_DATA] DailyMealsProvider.clearAuth() - ✅ Auth limpo');
  }

  /// Carrega resumos leves e somente os detalhes do dia selecionado.
  Future<void> _loadFromServer() async {
    if (_userId == null || _token == null) return;
    if (_isLoadingFromServer) return;

    _isLoadingFromServer = true;
    print('[DailyMealsProvider] Carregando resumo leve do servidor...');

    try {
      final now = DateTime.now();
      await _loadServerSummariesRange(
        from: now.subtract(const Duration(days: _initialSummaryLookbackDays)),
        to: now,
      );

      await _loadDayDetailsFromServer(_selectedDate, force: true);
    } catch (e) {
      print('[DailyMealsProvider] Erro ao carregar do servidor: $e');
    } finally {
      _isLoadingFromServer = false;
      notifyListeners();
    }
  }

  Future<void> _loadServerSummariesRange({
    required DateTime from,
    required DateTime to,
  }) async {
    if (_token == null) return;

    final summaries = await MealsSyncService.getMealsRange(
      token: _token!,
      from: from,
      to: to,
      summaryOnly: true,
    );

    for (final summary in summaries) {
      _applyServerSummary(summary, includeMeals: false);
    }
    _markSummaryMonthsLoaded(from, to);

    unawaited(_saveToPreferences());
    print(
        '[DailyMealsProvider] ${summaries.length} resumo(s) diário(s) carregado(s)');
  }

  Future<void> ensureMonthSummariesLoaded(DateTime visibleMonth) async {
    if (_token == null) return;

    final monthKey = _monthKey(visibleMonth);
    if (_loadedSummaryMonthKeys.contains(monthKey)) return;

    final start = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final end = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);
    _loadedSummaryMonthKeys.add(monthKey);

    try {
      await _loadServerSummariesRange(from: start, to: end);
      notifyListeners();
    } catch (e) {
      _loadedSummaryMonthKeys.remove(monthKey);
      print('[DailyMealsProvider] Erro ao carregar mês $monthKey: $e');
    }
  }

  Future<void> _loadDayDetailsFromServer(
    DateTime date, {
    bool force = false,
  }) async {
    if (_token == null) return;

    final dateKey = _formatDate(date);
    if (!force && _loadedDetailDateKeys.contains(dateKey)) return;
    if (_loadingDetailDateKeys.contains(dateKey)) return;

    final startRevision = _revisionForDateKey(dateKey);
    _loadingDetailDateKeys.add(dateKey);
    try {
      final summary = await MealsSyncService.getDaySummary(
        token: _token!,
        date: date,
      );
      if (summary == null) {
        _loadedDetailDateKeys.add(dateKey);
        return;
      }

      if (_hasPendingLocalChanges(dateKey) ||
          _revisionForDateKey(dateKey) != startRevision) {
        return;
      }

      _applyServerSummary(summary, includeMeals: true);
      _loadedDetailDateKeys.add(dateKey);
      unawaited(_saveToPreferences());
      notifyListeners();
    } catch (e) {
      print('[DailyMealsProvider] Erro ao carregar dia $dateKey: $e');
    } finally {
      _loadingDetailDateKeys.remove(dateKey);
    }
  }

  bool _applyServerSummary(
    DailySummary summary, {
    required bool includeMeals,
    bool allowPendingLocalOverride = false,
  }) {
    final dateKey = _formatDate(summary.date);
    if (_hasPendingLocalChanges(dateKey) && !allowPendingLocalOverride) {
      return false;
    }

    _serverSummariesByDate[dateKey] = _StoredDailySummary.fromServer(summary);
    _waterByDate[dateKey] = summary.waterGlasses;

    if (includeMeals) {
      _mealsByDate[dateKey] = _normalizeMeals(summary.meals)
          .where((meal) => !_isChatMealDeletedForDate(dateKey, meal.messageId))
          .toList();
    }

    return true;
  }

  int _revisionForDateKey(String dateKey) => _localRevisionByDate[dateKey] ?? 0;

  bool _hasPendingLocalChanges(String dateKey) =>
      _pendingSyncDateKeys.contains(dateKey);

  void _markDateLocallyModified(String dateKey) {
    _serverSummariesByDate.remove(dateKey);
    _pendingSyncDateKeys.add(dateKey);
    _localRevisionByDate[dateKey] = _revisionForDateKey(dateKey) + 1;
  }

  void _markDateSynced(String dateKey) {
    _pendingSyncDateKeys.remove(dateKey);
  }

  void _recordMealAddition(DateTime date) {
    _mealAdditionVersion++;
    _lastMealAdditionDate = DateTime(date.year, date.month, date.day);
  }

  /// Agenda sincronização com debounce de 3 segundos
  void _scheduleSync() {
    if (_userId == null || _token == null) return;

    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), () {
      _syncToServer();
    });
  }

  void _syncNowOrSchedule() {
    if (_userId == null || _token == null) return;

    _syncDebounce?.cancel();
    unawaited(_syncToServer());
  }

  /// Sincroniza dados do dia selecionado com o servidor
  Future<void> _syncToServer() async {
    if (_userId == null || _token == null) return;
    if (_isSyncing) {
      _syncRequestedWhileSyncing = true;
      return;
    }

    _isSyncing = true;
    _syncRequestedWhileSyncing = false;
    print('[DailyMealsProvider] Sincronizando com servidor...');

    final pendingDateKeys = _pendingSyncDateKeys.toList()..sort();
    final dateKey = pendingDateKeys.isNotEmpty
        ? pendingDateKeys.first
        : _formatDate(_selectedDate);
    final syncDate = DateTime.tryParse(dateKey) ?? _selectedDate;
    final startRevision = _revisionForDateKey(dateKey);
    bool synced = false;

    try {
      final meals = _mealsByDate[dateKey] ?? [];
      final water = _waterByDate[dateKey] ?? 0;

      final summary = await MealsSyncService.syncDay(
        token: _token!,
        date: syncDate,
        meals: meals,
        waterGlasses: water,
        goals: MealGoals(
          calories: caloriesGoal,
          protein: proteinGoal,
          carbs: carbsGoal,
          fat: fatsGoal,
          fitnessGoal: fitnessGoal,
        ),
      );

      if (summary == null) {
        print('[DailyMealsProvider] Sincronização não concluída');
      } else {
        if (_revisionForDateKey(dateKey) == startRevision) {
          _applyServerSummary(
            summary,
            includeMeals: summary.meals.isNotEmpty,
            allowPendingLocalOverride: true,
          );
          _markDateSynced(dateKey);
          _loadedDetailDateKeys.add(dateKey);
          await _saveToPreferences();
          synced = true;
          print('[DailyMealsProvider] Sincronização concluída');
        } else {
          _syncRequestedWhileSyncing = true;
          print(
              '[DailyMealsProvider] Resposta de sync ignorada; há edição local mais recente');
        }
      }
    } catch (e) {
      print('[DailyMealsProvider] Erro ao sincronizar: $e');
    } finally {
      final shouldRunAgain = _syncRequestedWhileSyncing;
      _syncRequestedWhileSyncing = false;
      _isSyncing = false;
      notifyListeners();
      if (shouldRunAgain || _pendingSyncDateKeys.isNotEmpty) {
        _scheduleSync();
      }
    }

    if (synced && _isSameDay(syncDate, DateTime.now())) {
      onTodaySynced?.call();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Força sincronização imediata (para uso manual)
  Future<void> forceSync() async {
    _syncDebounce?.cancel();
    await _syncToServer();
  }

  List<DailyMealsSyncSnapshot> getLocalSyncSnapshots() {
    final dateKeys = <String>{
      ..._mealsByDate.keys,
      ..._waterByDate.keys,
    }.toList()
      ..sort();

    final snapshots = <DailyMealsSyncSnapshot>[];
    for (final dateKey in dateKeys) {
      final meals = List<Meal>.from(_mealsByDate[dateKey] ?? const <Meal>[]);
      final hasMealData = meals.any((meal) => meal.foods.isNotEmpty);
      final waterGlasses = _waterByDate[dateKey] ?? 0;
      if (!hasMealData && waterGlasses <= 0) {
        continue;
      }

      final date = DateTime.tryParse(dateKey);
      if (date == null) {
        continue;
      }

      final summary = _hasPendingLocalChanges(dateKey)
          ? null
          : _serverSummariesByDate[dateKey];
      snapshots.add(
        DailyMealsSyncSnapshot(
          date: date,
          meals: meals,
          waterGlasses: waterGlasses,
          goals: summary?.goals ??
              MealGoals(
                calories: caloriesGoal,
                protein: proteinGoal,
                carbs: carbsGoal,
                fat: fatsGoal,
                fitnessGoal: fitnessGoal,
              ),
        ),
      );
    }

    return snapshots;
  }

  Future<int> syncSnapshotsToServer(
    String token,
    List<DailyMealsSyncSnapshot> snapshots, {
    bool skipServerConflicts = true,
  }) async {
    var synced = 0;
    for (final snapshot in snapshots) {
      final dateKey = _formatDate(snapshot.date);
      final serverSummary = _hasPendingLocalChanges(dateKey)
          ? null
          : _serverSummariesByDate[dateKey];
      final hasServerData = serverSummary != null &&
          (serverSummary.hasMealData || serverSummary.waterGlasses > 0);
      if (skipServerConflicts && hasServerData) {
        continue;
      }

      final startRevision = _revisionForDateKey(dateKey);
      final summary = await MealsSyncService.syncDay(
        token: token,
        date: snapshot.date,
        meals: snapshot.meals,
        waterGlasses: snapshot.waterGlasses,
        goals: snapshot.goals,
      );
      if (summary == null) {
        throw Exception('Falha ao sincronizar refeições de $dateKey');
      }

      if (_revisionForDateKey(dateKey) == startRevision) {
        _applyServerSummary(
          summary,
          includeMeals: summary.meals.isNotEmpty,
          allowPendingLocalOverride: true,
        );
        _markDateSynced(dateKey);
        _loadedDetailDateKeys.add(dateKey);
      }
      synced++;
    }

    if (synced > 0) {
      await _saveToPreferences();
      notifyListeners();
    }
    return synced;
  }

  DateTime get selectedDate => _selectedDate;

  /// Retorna true se houver algum alimento registrado na data informada.
  bool hasMealsOn(DateTime date) {
    final dateKey = _formatDate(date);
    final meals = _mealsByDate[dateKey];
    if (meals != null) {
      for (final meal in meals) {
        if (meal.foods.isNotEmpty) return true;
      }
    }

    if (_hasPendingLocalChanges(dateKey)) return false;
    return _serverSummariesByDate[dateKey]?.hasMealData ?? false;
  }

  bool hasNutritionDataOn(DateTime date) {
    final dateKey = _formatDate(date);
    final summary = _hasPendingLocalChanges(dateKey)
        ? null
        : _serverSummariesByDate[dateKey];
    if (summary != null) {
      return summary.hasMealData ||
          summary.totalCalories > 0 ||
          summary.totalProtein > 0 ||
          summary.totalCarbs > 0 ||
          summary.totalFat > 0;
    }
    return hasMealsOn(date);
  }

  /// Retorna true se a meta de proteína foi batida na data informada.
  bool hasHitProteinGoalOn(DateTime date, {int? proteinTarget}) {
    final dateKey = _formatDate(date);
    final summary = _hasPendingLocalChanges(dateKey)
        ? null
        : _serverSummariesByDate[dateKey];
    if (summary != null) {
      final target = proteinTarget ?? summary.goals.protein;
      return summary.totalProtein > 0 && summary.totalProtein >= target;
    }

    final protein = getMacrosForDate(date)['protein'] ?? 0;
    return protein > 0 && protein >= (proteinTarget ?? proteinGoal);
  }

  /// Retorna true se a meta de calorias foi batida na data informada.
  ///
  /// Para objetivos de perda, ficar abaixo da meta conta como sucesso, com uma
  /// margem para passar um pouco. Para ganho, passar da meta conta como
  /// sucesso, com uma margem para ficar um pouco abaixo. Para manutenção, usa
  /// a faixa completa para mais e para menos.
  bool hasHitCalorieGoalOn(
    DateTime date, {
    int? calorieGoal,
    bool allowBelowGoal = true,
    bool allowAboveGoal = true,
    double margin = 0.1,
  }) {
    final dateKey = _formatDate(date);
    final summary = _hasPendingLocalChanges(dateKey)
        ? null
        : _serverSummariesByDate[dateKey];
    final calories = summary?.totalCalories ?? getCaloriesForDate(date);
    final target = calorieGoal ?? summary?.goals.calories ?? caloriesGoal;
    if (calories <= 0 || target <= 0) return false;

    final lowerBound = target * (1 - margin);
    final upperBound = target * (1 + margin);

    if (allowBelowGoal && allowAboveGoal) {
      return calories >= lowerBound && calories <= upperBound;
    }
    if (allowBelowGoal) {
      return calories <= upperBound;
    }
    if (allowAboveGoal) {
      return calories >= lowerBound;
    }
    return false;
  }

  int getCurrentProteinGoalStreak({int? proteinTarget}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime cursor = hasHitProteinGoalOn(today, proteinTarget: proteinTarget)
        ? today
        : today.subtract(const Duration(days: 1));

    int count = 0;
    while (hasHitProteinGoalOn(cursor, proteinTarget: proteinTarget) &&
        count < 365) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int getCurrentCalorieGoalStreak({
    int? calorieGoal,
    bool allowBelowGoal = true,
    bool allowAboveGoal = true,
    double margin = 0.1,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool hit(DateTime date) => hasHitCalorieGoalOn(
          date,
          calorieGoal: calorieGoal,
          allowBelowGoal: allowBelowGoal,
          allowAboveGoal: allowAboveGoal,
          margin: margin,
        );

    DateTime cursor =
        hit(today) ? today : today.subtract(const Duration(days: 1));

    int count = 0;
    while (hit(cursor) && count < 365) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Conta dias consecutivos com refeições registradas (a partir de hoje, ou
  /// ontem se hoje ainda não tem registro). Usado para manter o contador da
  /// tela de Sequência consistente com o calendário, mesmo quando o backend
  /// ainda não processou o check-in do dia.
  int getCurrentRegistrationStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime cursor =
        hasMealsOn(today) ? today : today.subtract(const Duration(days: 1));

    int count = 0;
    while (hasMealsOn(cursor) && count < 365) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  List<Meal> get todayMeals {
    final dateKey = _formatDate(_selectedDate);
    return _mealsByDate[dateKey] ?? [];
  }

  List<Meal> getMealsForDate(DateTime date) {
    final dateKey = _formatDate(date);
    return List<Meal>.unmodifiable(_mealsByDate[dateKey] ?? const <Meal>[]);
  }

  Map<String, dynamic> getNutritionSnapshotForDate(DateTime date) {
    final dateKey = _formatDate(date);
    final summary = _hasPendingLocalChanges(dateKey)
        ? null
        : _serverSummariesByDate[dateKey];
    final meals = _mealsByDate[dateKey] ?? const <Meal>[];
    final localCalories =
        meals.fold<int>(0, (sum, meal) => sum + meal.totalCalories);
    final localProtein =
        meals.fold<double>(0, (sum, meal) => sum + meal.totalProtein);
    final localCarbs =
        meals.fold<double>(0, (sum, meal) => sum + meal.totalCarbs);
    final localFat = meals.fold<double>(0, (sum, meal) => sum + meal.totalFat);
    final hasLocalMealData = meals.any((meal) => meal.foods.isNotEmpty) ||
        localCalories > 0 ||
        localProtein > 0 ||
        localCarbs > 0 ||
        localFat > 0;
    final goals = summary?.goals ??
        MealGoals(
          calories: caloriesGoal,
          protein: proteinGoal,
          carbs: carbsGoal,
          fat: fatsGoal,
        );

    return {
      'date': date,
      'hasServerSummary': summary != null,
      'hasData': summary?.hasMealData ?? hasLocalMealData,
      'calories': summary?.totalCalories ?? localCalories,
      'protein': summary?.totalProtein ?? localProtein,
      'carbs': summary?.totalCarbs ?? localCarbs,
      'fat': summary?.totalFat ?? localFat,
      'fiber': summary?.totalFiber ?? getMacrosForDate(date)['fiber'] ?? 0.0,
      'waterGlasses': _waterByDate[dateKey] ?? summary?.waterGlasses ?? 0,
      'waterGoal': summary?.waterGoal ?? waterGoal,
      'calorieGoal': goals.calories,
      'proteinGoal': goals.protein,
      'carbsGoal': goals.carbs,
      'fatGoal': goals.fat,
    };
  }

  // Get meals by type — agrega todos os foods das refeicoes deste tipo
  // (uteis quando ha varias entradas do chat para o mesmo tipo no dia).
  Meal? getMealByType(MealType type) {
    final matching = todayMeals.where((m) => m.type == type).toList();
    if (matching.isEmpty) {
      return Meal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        foods: [],
      );
    }
    if (matching.length == 1) return matching.first;

    // Refeicao virtual agregada (so para exibicao na tela de refeicoes do dia).
    final allFoods = <Food>[];
    for (final m in matching) {
      allFoods.addAll(m.foods);
    }
    return Meal(
      id: 'aggregate:${type.name}:${_formatDate(_selectedDate)}',
      type: type,
      foods: allFoods,
      dateTime: matching.first.dateTime,
    );
  }

  /// Lista todas as refeicoes deste tipo no dia (cada uma com seu messageId).
  /// Usado quando precisamos preservar a identidade individual de cada card
  /// do chat (ex.: aplicar edicao em uma refeicao especifica).
  List<Meal> getMealsByType(MealType type) {
    return todayMeals.where((m) => m.type == type).toList();
  }

  // Daily totals
  int get totalCalories =>
      todayMeals.fold(0, (sum, meal) => sum + meal.totalCalories);
  double get totalProtein =>
      todayMeals.fold(0.0, (sum, meal) => sum + meal.totalProtein);
  double get totalCarbs =>
      todayMeals.fold(0.0, (sum, meal) => sum + meal.totalCarbs);
  double get totalFat =>
      todayMeals.fold(0.0, (sum, meal) => sum + meal.totalFat);

  // Remaining values
  int get caloriesRemaining => caloriesGoal - totalCalories;
  int get proteinRemaining => proteinGoal - totalProtein.toInt();
  int get carbsRemaining => carbsGoal - totalCarbs.toInt();
  int get fatsRemaining => fatsGoal - totalFat.toInt();

  // Water tracking
  int get todayWaterGlasses {
    final dateKey = _formatDate(_selectedDate);
    return _waterByDate[dateKey] ?? 0;
  }

  int getWaterGlassesForDate(DateTime date) {
    final dateKey = _formatDate(date);
    return _waterByDate[dateKey] ?? 0;
  }

  void addWater() {
    _changeWaterForDate(_selectedDate, 1);
  }

  void removeWater() {
    _changeWaterForDate(_selectedDate, -1);
  }

  void addWaterForDate(DateTime date) {
    _changeWaterForDate(date, 1);
  }

  void removeWaterForDate(DateTime date) {
    _changeWaterForDate(date, -1);
  }

  void _changeWaterForDate(DateTime date, int delta) {
    final dateKey = _formatDate(date);
    final current = _waterByDate[dateKey] ?? 0;
    final next = (current + delta).clamp(0, 999).toInt();
    if (next == current) return;

    _waterByDate[dateKey] = next;
    _markDateLocallyModified(dateKey);
    _saveWaterToPreferences();
    _scheduleSync(); // Sync com servidor
    notifyListeners();
  }

  int getWaterForDate(DateTime date) {
    final dateKey = _formatDate(date);
    return _waterByDate[dateKey] ?? 0;
  }

  // Load meals from SharedPreferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _loadDeletedChatMealsFromPreferences(prefs);

      // Load meals by date
      final mealsJson = prefs.getString('daily_meals');
      if (mealsJson != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(mealsJson);
        _mealsByDate.clear();

        decodedMap.forEach((dateKey, mealsListJson) {
          final List<dynamic> mealsList = mealsListJson as List<dynamic>;
          _mealsByDate[dateKey] = _normalizeMeals(
            mealsList
                .map(
                  (mealJson) => Meal.fromJson(mealJson as Map<String, dynamic>),
                )
                .toList(),
          )
              .where(
                (meal) => !_isChatMealDeletedForDate(dateKey, meal.messageId),
              )
              .toList();
        });
        _loadedDetailDateKeys
          ..clear()
          ..addAll(_mealsByDate.keys);
      }

      // Load goals
      caloriesGoal = prefs.getInt('meals_calories_goal') ?? 2000;
      proteinGoal = prefs.getInt('meals_protein_goal') ?? 150;
      carbsGoal = prefs.getInt('meals_carbs_goal') ?? 250;
      fatsGoal = prefs.getInt('meals_fats_goal') ?? 67;
      waterGoal = prefs.getInt('water_goal') ?? 8;
      fitnessGoal = prefs.getString('meals_fitness_goal');

      // Load water data
      final waterJson = prefs.getString('water_by_date');
      if (waterJson != null) {
        final Map<String, dynamic> decodedWater = jsonDecode(waterJson);
        _waterByDate.clear();
        decodedWater.forEach((key, value) {
          _waterByDate[key] = value as int;
        });
      }

      final summariesJson = prefs.getString('daily_meal_summaries');
      if (summariesJson != null) {
        final Map<String, dynamic> decodedSummaries = jsonDecode(summariesJson);
        _serverSummariesByDate.clear();
        decodedSummaries.forEach((dateKey, value) {
          if (value is Map<String, dynamic>) {
            _serverSummariesByDate[dateKey] =
                _StoredDailySummary.fromJson(value);
          } else if (value is Map) {
            _serverSummariesByDate[dateKey] =
                _StoredDailySummary.fromJson(Map<String, dynamic>.from(value));
          }
        });
        _loadedSummaryMonthKeys
          ..clear()
          ..addAll(_serverSummariesByDate.keys.map(_monthKeyFromDateKey));
      }

      final pendingDatesJson =
          prefs.getString('daily_meals_pending_sync_dates');
      _pendingSyncDateKeys.clear();
      if (pendingDatesJson != null) {
        final decodedPendingDates = jsonDecode(pendingDatesJson);
        if (decodedPendingDates is List) {
          _pendingSyncDateKeys.addAll(
            decodedPendingDates.map((value) => value.toString()),
          );
        }
      } else {
        final dateKeys = <String>{..._mealsByDate.keys, ..._waterByDate.keys};
        for (final dateKey in dateKeys) {
          final meals = _mealsByDate[dateKey] ?? const <Meal>[];
          final hasMeals = meals.any((meal) => meal.foods.isNotEmpty);
          final hasWater = (_waterByDate[dateKey] ?? 0) > 0;
          if ((hasMeals || hasWater) &&
              !_serverSummariesByDate.containsKey(dateKey)) {
            _pendingSyncDateKeys.add(dateKey);
          }
        }
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error loading daily meals: $e');
      _isLoaded = true;
    }
  }

  // Save meals to SharedPreferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert meals map to JSON
      final Map<String, dynamic> mealsToSave = {};
      _mealsByDate.forEach((dateKey, mealsList) {
        mealsToSave[dateKey] = mealsList.map((meal) => meal.toJson()).toList();
      });

      await prefs.setString('daily_meals', jsonEncode(mealsToSave));
      await prefs.setString(
        _deletedChatMealsPrefsKey,
        jsonEncode(_encodeDeletedChatMealIds()),
      );

      final Map<String, dynamic> summariesToSave = {};
      _serverSummariesByDate.forEach((dateKey, summary) {
        summariesToSave[dateKey] = summary.toJson();
      });
      await prefs.setString(
        'daily_meal_summaries',
        jsonEncode(summariesToSave),
      );
      await prefs.setString(
        'daily_meals_pending_sync_dates',
        jsonEncode(_pendingSyncDateKeys.toList()..sort()),
      );
      await prefs.setString('water_by_date', jsonEncode(_waterByDate));

      // Save goals
      await prefs.setInt('meals_calories_goal', caloriesGoal);
      await prefs.setInt('meals_protein_goal', proteinGoal);
      await prefs.setInt('meals_carbs_goal', carbsGoal);
      await prefs.setInt('meals_fats_goal', fatsGoal);
      await prefs.setInt('water_goal', waterGoal);
      if (fitnessGoal == null) {
        await prefs.remove('meals_fitness_goal');
      } else {
        await prefs.setString('meals_fitness_goal', fitnessGoal!);
      }
    } catch (e) {
      print('Error saving daily meals: $e');
    }
  }

  Future<void> _saveWaterToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('water_by_date', jsonEncode(_waterByDate));
      await prefs.setString(
        'daily_meals_pending_sync_dates',
        jsonEncode(_pendingSyncDateKeys.toList()..sort()),
      );
      await prefs.setInt('water_goal', waterGoal);
    } catch (e) {
      print('Error saving water data: $e');
    }
  }

  void _loadDeletedChatMealsFromPreferences(SharedPreferences prefs) {
    _deletedChatMealIdsByDate.clear();

    final deletedJson = prefs.getString(_deletedChatMealsPrefsKey);
    if (deletedJson == null || deletedJson.trim().isEmpty) return;

    final decoded = jsonDecode(deletedJson);
    if (decoded is! Map) return;

    decoded.forEach((dateKey, value) {
      if (value is List) {
        final deletedIds = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet();
        if (deletedIds.isNotEmpty) {
          _deletedChatMealIdsByDate[dateKey.toString()] = deletedIds;
        }
      }
    });
  }

  Map<String, List<String>> _encodeDeletedChatMealIds() {
    final encoded = <String, List<String>>{};
    _deletedChatMealIdsByDate.forEach((dateKey, deletedIds) {
      if (deletedIds.isEmpty) return;
      encoded[dateKey] = deletedIds.toList()..sort();
    });
    return encoded;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _monthKeyFromDateKey(String dateKey) {
    return dateKey.length >= 7 ? dateKey.substring(0, 7) : dateKey;
  }

  void _markSummaryMonthsLoaded(DateTime from, DateTime to) {
    var cursor = DateTime(from.year, from.month, 1);
    final end = DateTime(to.year, to.month, 1);
    while (!cursor.isAfter(end)) {
      _loadedSummaryMonthKeys.add(_monthKey(cursor));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
    unawaited(_loadDayDetailsFromServer(_selectedDate));
  }

  /// Busca uma refeição pelo messageId (ID da mensagem do chat que a gerou)
  Meal? getMealByMessageId(String messageId) {
    final matches = getMealsByMessageId(messageId);
    return matches.isEmpty ? null : matches.first;
  }

  /// Busca todas as refeições vinculadas ao mesmo card/mensagem do chat.
  /// Mensagens com múltiplas refeições usam IDs sufixados por card.
  List<Meal> getMealsByMessageId(String messageId) {
    final dateKey = _formatDate(_selectedDate);
    final meals = _mealsByDate[dateKey];
    if (meals == null) return const [];

    return meals
        .where((m) => _matchesChatMessageGroup(m.messageId, messageId))
        .toList(growable: false);
  }

  bool isChatMealDeleted(String? messageId, {DateTime? date}) {
    final dateKey = _formatDate(date ?? _selectedDate);
    return _isChatMealDeletedForDate(dateKey, messageId);
  }

  bool _isChatMealDeletedForDate(String dateKey, String? messageId) {
    final deletedIds = _deletedChatMealIdsByDate[dateKey];
    if (deletedIds == null || deletedIds.isEmpty) return false;

    final identity = _chatMealIdentity(messageId);
    if (identity == null) return false;
    if (deletedIds.contains(identity)) return true;

    final groupId = _chatMessageGroupId(messageId);
    return groupId != null && deletedIds.contains(groupId);
  }

  void _markChatMealDeletedForDate(String dateKey, String? messageId) {
    final identity = _chatMealIdentity(messageId);
    if (identity == null) return;

    (_deletedChatMealIdsByDate[dateKey] ??= <String>{}).add(identity);
  }

  bool _matchesChatMessageGroup(String? mealMessageId, String messageId) {
    final mealGroupId = _chatMessageGroupId(mealMessageId);
    final targetGroupId = _chatMessageGroupId(messageId);
    if (mealGroupId == null || targetGroupId == null) {
      return false;
    }

    return mealGroupId == targetGroupId;
  }

  String? _chatMessageGroupId(String? messageId) {
    final trimmed = messageId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final withoutMealSuffix = trimmed.split('#meal-').first;
    final legacyMatch =
        RegExp(r'^(msg-\d+)-\d+$').firstMatch(withoutMealSuffix);
    if (legacyMatch != null) {
      return legacyMatch.group(1);
    }

    return withoutMealSuffix;
  }

  int? _chatMealOrdinal(String? messageId) {
    final trimmed = messageId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final match = RegExp(r'#meal-(\d+)$').firstMatch(trimmed);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String? _chatMealIdentity(String? messageId) {
    final groupId = _chatMessageGroupId(messageId);
    if (groupId == null) return null;

    final ordinal = _chatMealOrdinal(messageId);
    if (ordinal == null) return groupId;
    return '$groupId#meal-$ordinal';
  }

  int _findMealIndexByMessageId(List<Meal> meals, String? messageId) {
    final targetIdentity = _chatMealIdentity(messageId);
    if (targetIdentity == null) return -1;

    final specificIndex = meals
        .indexWhere((m) => _chatMealIdentity(m.messageId) == targetIdentity);
    if (specificIndex != -1) return specificIndex;

    if (_chatMealOrdinal(messageId) != null) return -1;

    final targetGroupId = _chatMessageGroupId(messageId);
    if (targetGroupId == null) return -1;

    return meals
        .indexWhere((m) => _chatMessageGroupId(m.messageId) == targetGroupId);
  }

  /// Adiciona uma refeição completa ao dia selecionado
  void addMeal(Meal meal) {
    final dateKey = _formatDate(_selectedDate);
    _mealsByDate[dateKey] ??= [];

    final meals = _mealsByDate[dateKey]!;
    final normalizedMeal = _normalizeMeal(
      meal.copyWith(dateTime: _selectedDate),
    );
    if (_isChatMealDeletedForDate(dateKey, normalizedMeal.messageId)) {
      return;
    }

    // Refeicoes vindas do chat (com messageId) sao SEMPRE entradas
    // independentes — cada card do chat = sua propria refeicao. Isso evita
    // que ao recarregar o app o card de uma mensagem mostre alimentos de
    // outra mensagem mesclada do mesmo tipo de refeicao.
    if (normalizedMeal.messageId != null) {
      final existingByMessageId =
          _findMealIndexByMessageId(meals, normalizedMeal.messageId);
      if (existingByMessageId != -1) {
        // Mesmo messageId ja existe — atualiza no lugar (sem duplicar).
        meals[existingByMessageId] = normalizedMeal;
        _markDateLocallyModified(dateKey);
        _saveToPreferences();
        _scheduleSync();
        notifyListeners();
        return;
      }

      // Card de chat novo — adiciona como refeicao separada, sem merge.
      meals.add(normalizedMeal);
      _markDateLocallyModified(dateKey);
      if (normalizedMeal.foods.isNotEmpty) {
        _recordMealAddition(_selectedDate);
      }
      _saveToPreferences();
      _scheduleSync();
      notifyListeners();
      return;
    }

    // Sem messageId (entrada manual via tela de refeicoes): mantem o
    // comportamento legado de merge por tipo de refeicao.
    final existingIndex =
        meals.indexWhere((m) => m.type == normalizedMeal.type);

    if (existingIndex != -1) {
      final existingMeal = meals[existingIndex];
      final mergedFoods = List<Food>.from(existingMeal.foods)
        ..addAll(normalizedMeal.foods);
      meals[existingIndex] = _normalizeMeal(
        existingMeal.copyWith(foods: mergedFoods),
      );
    } else {
      meals.add(normalizedMeal);
    }

    _markDateLocallyModified(dateKey);
    if (normalizedMeal.foods.isNotEmpty) {
      _recordMealAddition(_selectedDate);
    }
    _saveToPreferences();
    _scheduleSync(); // Sync com servidor
    notifyListeners();
  }

  void addFoodToMeal(MealType type, Food food) {
    final dateKey = _formatDate(_selectedDate);
    _mealsByDate[dateKey] ??= [];

    final meals = _mealsByDate[dateKey]!;
    final mealIndex = meals.indexWhere((m) => m.type == type);

    if (mealIndex != -1) {
      // Meal exists, add food to it
      final updatedFoods = List<Food>.from(meals[mealIndex].foods)..add(food);
      meals[mealIndex] = meals[mealIndex].copyWith(foods: updatedFoods);
    } else {
      // Create new meal with this food
      meals.add(Meal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        foods: [food],
      ));
    }

    _markDateLocallyModified(dateKey);
    _recordMealAddition(_selectedDate);
    _saveToPreferences();
    _scheduleSync(); // Sync com servidor
    notifyListeners();
  }

  void removeFoodFromMeal(MealType type, Food food) {
    final dateKey = _formatDate(_selectedDate);
    final meals = _mealsByDate[dateKey];
    if (meals == null) return;

    final mealIndex = meals.indexWhere((m) => m.type == type);
    if (mealIndex == -1) return;

    final previousLength = meals[mealIndex].foods.length;
    final updatedFoods = List<Food>.from(meals[mealIndex].foods)
      ..removeWhere((f) => f.id == food.id);
    if (updatedFoods.length == previousLength) return;

    if (updatedFoods.isEmpty) {
      _markChatMealDeletedForDate(dateKey, meals[mealIndex].messageId);
      // Remove meal if no foods left
      meals.removeAt(mealIndex);
    } else {
      meals[mealIndex] = meals[mealIndex].copyWith(foods: updatedFoods);
    }

    _markDateLocallyModified(dateKey);
    _saveToPreferences();
    _syncNowOrSchedule(); // Sync com servidor
    notifyListeners();
  }

  /// Substitui uma refeição existente (mesmo id) mantendo posição na lista
  void updateMeal(Meal updatedMeal) {
    if (updatedMeal.foods.isEmpty) {
      deleteMeal(updatedMeal.id, messageId: updatedMeal.messageId);
      return;
    }

    final dateKey = _formatDate(_selectedDate);
    final meals = _mealsByDate[dateKey];
    if (meals == null) return;

    final index = _findMealIndexForUpdate(meals, updatedMeal);
    if (index == -1) return;

    final existingMeal = meals[index];
    meals[index] = _normalizeMeal(
      updatedMeal.copyWith(
        id: existingMeal.id,
        dateTime: existingMeal.dateTime,
        messageId: existingMeal.messageId ?? updatedMeal.messageId,
      ),
    );
    _markDateLocallyModified(dateKey);
    _saveToPreferences();
    _scheduleSync();
    notifyListeners();
  }

  int _findMealIndexForUpdate(List<Meal> meals, Meal updatedMeal) {
    final byId = meals.indexWhere((m) => m.id == updatedMeal.id);
    if (byId != -1) return byId;

    final messageId = updatedMeal.messageId;
    if (messageId == null || messageId.isEmpty) return -1;

    return _findMealIndexByMessageId(meals, messageId);
  }

  List<Meal> _normalizeMeals(List<Meal> meals) {
    final normalizedMeals =
        meals.map(_normalizeMeal).where((meal) => meal.foods.isNotEmpty);
    final mergedByIdentity = <String, Meal>{};

    for (final meal in normalizedMeals) {
      final identity = _mealIdentity(meal);
      final existing = mergedByIdentity[identity];
      if (existing == null) {
        mergedByIdentity[identity] = meal;
        continue;
      }

      mergedByIdentity[identity] = _normalizeMeal(
        existing.copyWith(
          foods: [...existing.foods, ...meal.foods],
          messageId: existing.messageId ?? meal.messageId,
        ),
      );
    }

    return mergedByIdentity.values.toList();
  }

  Meal _normalizeMeal(Meal meal) {
    if (meal.foods.length < 2) return meal;

    final seenFoods = <String>{};
    final dedupedFoods = <Food>[];

    for (final food in meal.foods) {
      final signature = _foodIdentity(food);
      if (seenFoods.add(signature)) {
        dedupedFoods.add(food);
      }
    }

    if (dedupedFoods.length == meal.foods.length) return meal;
    return meal.copyWith(foods: dedupedFoods);
  }

  String _foodIdentity(Food food) {
    return food.name.trim().toLowerCase();
  }

  String _mealIdentity(Meal meal) {
    if (meal.messageId != null && meal.messageId!.isNotEmpty) {
      return 'message:${_chatMealIdentity(meal.messageId) ?? meal.messageId}';
    }

    final foodNames = meal.foods.map(_foodIdentity).toList()..sort();
    return '${meal.type.name}:${foodNames.join('|')}';
  }

  /// Remove uma refeição completa pelo ID
  void deleteMeal(String mealId, {String? messageId}) {
    final dateKey = _formatDate(_selectedDate);
    final meals = _mealsByDate[dateKey];
    if (meals == null) return;

    var mealIndex = meals.indexWhere((m) => m.id == mealId);
    if (mealIndex == -1) {
      mealIndex = _findMealIndexByMessageId(meals, messageId);
    }
    if (mealIndex == -1) return;

    final removedMeal = meals.removeAt(mealIndex);
    _markChatMealDeletedForDate(
      dateKey,
      removedMeal.messageId ?? messageId,
    );

    _markDateLocallyModified(dateKey);
    notifyListeners();
    unawaited(_saveToPreferences());
    _scheduleSync(); // Sync debounced para manter a UI responsiva.
  }

  /// Remove uma refeição pelo tipo
  void deleteMealByType(MealType type) {
    final dateKey = _formatDate(_selectedDate);
    final meals = _mealsByDate[dateKey];
    if (meals == null) return;

    final removedMessageIds = meals
        .where((m) => m.type == type)
        .map((m) => m.messageId)
        .whereType<String>()
        .toList();
    final previousLength = meals.length;
    meals.removeWhere((m) => m.type == type);
    if (meals.length == previousLength) return;

    for (final messageId in removedMessageIds) {
      _markChatMealDeletedForDate(dateKey, messageId);
    }
    _markDateLocallyModified(dateKey);
    notifyListeners();
    unawaited(_saveToPreferences());
    _scheduleSync(); // Sync debounced para manter a UI responsiva.
  }

  void updateGoals({
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    String? fitnessGoal,
  }) {
    if (calories != null) caloriesGoal = calories;
    if (protein != null) proteinGoal = protein;
    if (carbs != null) carbsGoal = carbs;
    if (fats != null) fatsGoal = fats;
    if (fitnessGoal != null) this.fitnessGoal = fitnessGoal;
    _markDateLocallyModified(_formatDate(_selectedDate));
    _saveToPreferences();
    _scheduleSync(); // Sync com servidor
    notifyListeners();
  }

  // Get meal type display info
  static MealTypeOption getMealTypeOption(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return const MealTypeOption(
          type: MealType.breakfast,
          name: 'Café da Manhã',
          emoji: '🍳',
        );
      case MealType.lunch:
        return const MealTypeOption(
          type: MealType.lunch,
          name: 'Almoço',
          emoji: '🍽️',
        );
      case MealType.dinner:
        return const MealTypeOption(
          type: MealType.dinner,
          name: 'Jantar',
          emoji: '🍝',
        );
      case MealType.snack:
        return const MealTypeOption(
          type: MealType.snack,
          name: 'Lanche',
          emoji: '🥤',
        );
      case MealType.freeMeal:
        return const MealTypeOption(
          type: MealType.freeMeal,
          name: 'Refeição Livre',
          emoji: '🍴',
        );
    }
  }

  // Load sample data for testing
  void loadSampleData() {
    final dateKey = _formatDate(_selectedDate);
    _markDateLocallyModified(dateKey);

    // Create sample foods with complete nutrient data
    final eggs = Food(
      id: 1,
      name: 'Ovos Mexidos',
      emoji: '🍳',
      nutrients: [
        Nutrient(
          idFood: 1,
          servingSize: 100,
          servingUnit: 'g',
          calories: 148,
          protein: 10.0,
          carbohydrate: 1.1,
          fat: 11.0,
          saturatedFat: 3.3,
          cholesterol: 373,
          sodium: 142,
          potassium: 138,
          dietaryFiber: 0,
          sugars: 0.4,
          vitaminA: 160,
          vitaminD: 2.0,
          vitaminB12: 0.9,
          calcium: 56,
          iron: 1.2,
        ),
      ],
    );

    final rice = Food(
      id: 2,
      name: 'Arroz Integral',
      emoji: '🍚',
      nutrients: [
        Nutrient(
          idFood: 2,
          servingSize: 100,
          servingUnit: 'g',
          calories: 112,
          protein: 2.6,
          carbohydrate: 23.5,
          fat: 0.9,
          saturatedFat: 0.2,
          cholesterol: 0,
          sodium: 1,
          potassium: 43,
          dietaryFiber: 1.8,
          sugars: 0.4,
          vitaminB6: 0.15,
          calcium: 10,
          iron: 0.4,
        ),
      ],
    );

    final chicken = Food(
      id: 3,
      name: 'Peito de Frango Grelhado',
      emoji: '🍗',
      nutrients: [
        Nutrient(
          idFood: 3,
          servingSize: 100,
          servingUnit: 'g',
          calories: 165,
          protein: 31.0,
          carbohydrate: 0,
          fat: 3.6,
          saturatedFat: 1.0,
          cholesterol: 85,
          sodium: 74,
          potassium: 256,
          dietaryFiber: 0,
          sugars: 0,
          vitaminB6: 0.6,
          vitaminB12: 0.3,
          calcium: 15,
          iron: 1.0,
        ),
      ],
    );

    final beans = Food(
      id: 4,
      name: 'Feijão Preto',
      emoji: '🫘',
      nutrients: [
        Nutrient(
          idFood: 4,
          servingSize: 100,
          servingUnit: 'g',
          calories: 132,
          protein: 8.9,
          carbohydrate: 23.7,
          fat: 0.5,
          saturatedFat: 0.1,
          cholesterol: 0,
          sodium: 1,
          potassium: 355,
          dietaryFiber: 8.7,
          sugars: 0.3,
          vitaminB6: 0.1,
          calcium: 27,
          iron: 2.1,
        ),
      ],
    );

    final banana = Food(
      id: 5,
      name: 'Banana',
      emoji: '🍌',
      nutrients: [
        Nutrient(
          idFood: 5,
          servingSize: 100,
          servingUnit: 'g',
          calories: 89,
          protein: 1.1,
          carbohydrate: 22.8,
          fat: 0.3,
          saturatedFat: 0.1,
          cholesterol: 0,
          sodium: 1,
          potassium: 358,
          dietaryFiber: 2.6,
          sugars: 12.2,
          vitaminC: 8.7,
          vitaminB6: 0.4,
          calcium: 5,
          iron: 0.3,
        ),
      ],
    );

    final salmon = Food(
      id: 6,
      name: 'Salmão Grelhado',
      emoji: '🐟',
      nutrients: [
        Nutrient(
          idFood: 6,
          servingSize: 100,
          servingUnit: 'g',
          calories: 206,
          protein: 22.0,
          carbohydrate: 0,
          fat: 13.0,
          saturatedFat: 3.1,
          cholesterol: 55,
          sodium: 59,
          potassium: 363,
          dietaryFiber: 0,
          sugars: 0,
          vitaminD: 11.0,
          vitaminB6: 0.6,
          vitaminB12: 3.2,
          calcium: 9,
          iron: 0.3,
        ),
      ],
    );

    final broccoli = Food(
      id: 7,
      name: 'Brócolis',
      emoji: '🥦',
      nutrients: [
        Nutrient(
          idFood: 7,
          servingSize: 100,
          servingUnit: 'g',
          calories: 34,
          protein: 2.8,
          carbohydrate: 6.6,
          fat: 0.4,
          saturatedFat: 0.1,
          cholesterol: 0,
          sodium: 33,
          potassium: 316,
          dietaryFiber: 2.6,
          sugars: 1.7,
          vitaminC: 89.2,
          vitaminA: 31,
          vitaminB6: 0.2,
          calcium: 47,
          iron: 0.7,
        ),
      ],
    );

    // Create meals with these foods
    _mealsByDate[dateKey] = [
      // Breakfast
      Meal(
        id: '1',
        type: MealType.breakfast,
        foods: [eggs, banana],
        dateTime: DateTime.now().copyWith(hour: 8, minute: 0),
      ),
      // Lunch
      Meal(
        id: '2',
        type: MealType.lunch,
        foods: [rice, beans, chicken, broccoli],
        dateTime: DateTime.now().copyWith(hour: 12, minute: 30),
      ),
      // Dinner
      Meal(
        id: '3',
        type: MealType.dinner,
        foods: [salmon, rice, broccoli],
        dateTime: DateTime.now().copyWith(hour: 19, minute: 0),
      ),
    ];

    notifyListeners();
  }

  void clearAllMeals() {
    final dateKey = _formatDate(_selectedDate);
    final meals = _mealsByDate[dateKey] ?? const <Meal>[];
    for (final meal in meals) {
      _markChatMealDeletedForDate(dateKey, meal.messageId);
    }
    _mealsByDate[dateKey] = [];
    _markDateLocallyModified(dateKey);
    _saveToPreferences();
    _syncNowOrSchedule(); // Sync com servidor
    notifyListeners();
  }

  // ========== HISTORICAL DATA METHODS ==========

  /// Get calories for a specific date
  int getCaloriesForDate(DateTime date) {
    final dateKey = _formatDate(date);
    final meals = _mealsByDate[dateKey] ?? [];
    return meals.fold(0, (sum, meal) => sum + meal.totalCalories);
  }

  /// Get macros for a specific date
  Map<String, double> getMacrosForDate(DateTime date) {
    final dateKey = _formatDate(date);
    final meals = _mealsByDate[dateKey] ?? [];
    return {
      'protein': meals.fold(0.0, (sum, meal) => sum + meal.totalProtein),
      'carbs': meals.fold(0.0, (sum, meal) => sum + meal.totalCarbs),
      'fat': meals.fold(0.0, (sum, meal) => sum + meal.totalFat),
      'fiber': meals.fold(0.0, (sum, meal) {
        double fiberSum = 0;
        for (var food in meal.foods) {
          final nutrients = food.nutrients;
          if (nutrients != null && nutrients.isNotEmpty) {
            fiberSum += nutrients.first.dietaryFiber ?? 0;
          }
        }
        return sum + fiberSum;
      }),
    };
  }

  /// Get historical calories data for the last N days
  List<Map<String, dynamic>> getCaloriesHistory(
    int days, {
    MealGoals? fallbackGoals,
  }) {
    return getNutritionHistory(days, fallbackGoals: fallbackGoals)
        .map(
          (day) => {
            'date': day['date'],
            'calories': day['calories'],
            'calorieGoal': day['calorieGoal'],
            'hasData': day['hasData'],
          },
        )
        .toList();
  }

  /// Get historical macros data for the last N days
  List<Map<String, dynamic>> getMacrosHistory(
    int days, {
    MealGoals? fallbackGoals,
  }) {
    return getNutritionHistory(days, fallbackGoals: fallbackGoals)
        .map(
          (day) => {
            'date': day['date'],
            'protein': day['protein'],
            'carbs': day['carbs'],
            'fat': day['fat'],
            'fiber': day['fiber'],
            'proteinGoal': day['proteinGoal'],
            'carbsGoal': day['carbsGoal'],
            'fatGoal': day['fatGoal'],
            'hasData': day['hasData'],
          },
        )
        .toList();
  }

  /// Get historical nutrition data using server daily goals when available.
  List<Map<String, dynamic>> getNutritionHistory(
    int days, {
    MealGoals? fallbackGoals,
  }) {
    final List<Map<String, dynamic>> history = [];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = _formatDate(date);
      final summary = _hasPendingLocalChanges(dateKey)
          ? null
          : _serverSummariesByDate[dateKey];
      final macros = summary == null ? getMacrosForDate(date) : null;
      final goals = summary?.goals ?? _fallbackGoals(fallbackGoals);
      final calories = summary?.totalCalories ?? getCaloriesForDate(date);
      final protein = summary?.totalProtein ?? macros!['protein']!;
      final carbs = summary?.totalCarbs ?? macros!['carbs']!;
      final fat = summary?.totalFat ?? macros!['fat']!;
      final fiber = summary?.totalFiber ?? macros!['fiber']!;
      final waterGlasses = _waterByDate[dateKey] ?? summary?.waterGlasses ?? 0;
      final hasMealData = summary?.hasMealData ??
          (calories > 0 || protein > 0 || carbs > 0 || fat > 0);

      history.add({
        'date': date,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'waterGlasses': waterGlasses,
        'waterGoal': summary?.waterGoal ?? waterGoal,
        'calorieGoal': goals.calories,
        'proteinGoal': goals.protein,
        'carbsGoal': goals.carbs,
        'fatGoal': goals.fat,
        'hasData': hasMealData,
        'hasAnyData': hasMealData || waterGlasses > 0,
      });
    }

    return history;
  }

  MealGoals _fallbackGoals(MealGoals? fallbackGoals) {
    return fallbackGoals ??
        MealGoals(
          calories: caloriesGoal,
          protein: proteinGoal,
          carbs: carbsGoal,
          fat: fatsGoal,
        );
  }

  /// Get average calories for the last N days (only counting days with data)
  double getAverageCalories(int days) {
    final history = getCaloriesHistory(days);
    final daysWithData = history.where((d) => d['hasData'] == true).toList();
    if (daysWithData.isEmpty) return 0;

    final total =
        daysWithData.fold<int>(0, (sum, d) => sum + (d['calories'] as int));
    return total / daysWithData.length;
  }

  /// Get average macros for the last N days (only counting days with data)
  Map<String, double> getAverageMacros(int days) {
    final history = getMacrosHistory(days);
    final daysWithData = history.where((d) => d['hasData'] == true).toList();

    if (daysWithData.isEmpty) {
      return {'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0};
    }

    final count = daysWithData.length;
    return {
      'protein': daysWithData.fold<double>(
              0, (sum, d) => sum + (d['protein'] as double)) /
          count,
      'carbs': daysWithData.fold<double>(
              0, (sum, d) => sum + (d['carbs'] as double)) /
          count,
      'fat':
          daysWithData.fold<double>(0, (sum, d) => sum + (d['fat'] as double)) /
              count,
      'fiber': daysWithData.fold<double>(
              0, (sum, d) => sum + (d['fiber'] as double)) /
          count,
    };
  }

  /// Get total days with logged meals
  int getTotalDaysLogged() {
    int count = 0;
    for (var meals in _mealsByDate.values) {
      if (meals.isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  /// Get total meals logged
  int getTotalMealsLogged() {
    int count = 0;
    for (var meals in _mealsByDate.values) {
      count += meals.length;
    }
    return count;
  }

  /// Check if today has any meals logged
  bool get hasTodayMeals {
    return totalCalories > 0;
  }

  /// Limpa todos os dados de refeições e água (usado no logout)
  Future<void> clearAllData() async {
    print(
        '[🔄 AUTH_DATA] DailyMealsProvider.clearAllData() - Iniciando limpeza...');
    print(
        '[🔄 AUTH_DATA] DailyMealsProvider.clearAllData() - Refeições antes: ${_mealsByDate.length} dias');
    print(
        '[🔄 AUTH_DATA] DailyMealsProvider.clearAllData() - Água antes: ${_waterByDate.length} dias');

    _mealsByDate.clear();
    _waterByDate.clear();
    _serverSummariesByDate.clear();
    _deletedChatMealIdsByDate.clear();
    _pendingSyncDateKeys.clear();
    _localRevisionByDate.clear();
    _loadedDetailDateKeys.clear();
    _loadingDetailDateKeys.clear();
    _loadedSummaryMonthKeys.clear();

    // Limpar do SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final removedMeals = await prefs.remove('daily_meals');
      final removedWater = await prefs.remove('water_by_date');
      final removedSummaries = await prefs.remove('daily_meal_summaries');
      final removedDeletedChatMeals =
          await prefs.remove(_deletedChatMealsPrefsKey);
      final removedPendingDates =
          await prefs.remove('daily_meals_pending_sync_dates');
      print(
          '[🔄 AUTH_DATA] DailyMealsProvider.clearAllData() - SharedPreferences removido: meals=$removedMeals, water=$removedWater, summaries=$removedSummaries, deletedChatMeals=$removedDeletedChatMeals, pendingDates=$removedPendingDates');

      // Verificar se foi removido
      final checkMeals = prefs.getString('daily_meals');
      final checkWater = prefs.getString('water_by_date');
      print(
          '[🔄 AUTH_DATA] DailyMealsProvider.clearAllData() - Verificação: meals=${checkMeals == null ? "NULL (OK)" : "TEM DADOS!"}, water=${checkWater == null ? "NULL (OK)" : "TEM DADOS!"}');

      print(
          '[🔄 AUTH_DATA] DailyMealsProvider.clearAllData() - ✅ Todos os dados de refeições foram limpos');
    } catch (e) {
      print('[🔄 AUTH_DATA] DailyMealsProvider.clearAllData() - ❌ ERRO: $e');
    }

    notifyListeners();
  }
}

class _StoredDailySummary {
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final int waterGlasses;
  final int waterGoal;
  final MealGoals goals;
  final bool hitProtein;
  final bool hitCalories;
  final bool hasMealData;

  const _StoredDailySummary({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    required this.waterGlasses,
    required this.waterGoal,
    required this.goals,
    required this.hitProtein,
    required this.hitCalories,
    required this.hasMealData,
  });

  factory _StoredDailySummary.fromServer(DailySummary summary) {
    return _StoredDailySummary(
      totalCalories: summary.totalCalories,
      totalProtein: summary.totalProtein,
      totalCarbs: summary.totalCarbs,
      totalFat: summary.totalFat,
      totalFiber: summary.totalFiber,
      waterGlasses: summary.waterGlasses,
      waterGoal: summary.waterGoal,
      goals: MealGoals(
        calories: summary.calorieGoal,
        protein: summary.proteinGoal,
        carbs: summary.carbsGoal,
        fat: summary.fatGoal,
      ),
      hitProtein: summary.hitProtein,
      hitCalories: summary.hitCalories,
      hasMealData: summary.meals.isNotEmpty ||
          summary.totalCalories > 0 ||
          summary.totalProtein > 0 ||
          summary.totalCarbs > 0 ||
          summary.totalFat > 0,
    );
  }

  factory _StoredDailySummary.fromJson(Map<String, dynamic> json) {
    final goalsJson = json['goals'];
    final goalsMap = goalsJson is Map
        ? Map<String, dynamic>.from(goalsJson)
        : const <String, dynamic>{};

    return _StoredDailySummary(
      totalCalories: _readInt(json['totalCalories']),
      totalProtein: _readDouble(json['totalProtein']),
      totalCarbs: _readDouble(json['totalCarbs']),
      totalFat: _readDouble(json['totalFat']),
      totalFiber: _readDouble(json['totalFiber']),
      waterGlasses: _readInt(json['waterGlasses']),
      waterGoal: _readInt(json['waterGoal'], fallback: 8),
      goals: MealGoals(
        calories: _readInt(goalsMap['calories'], fallback: 2000),
        protein: _readInt(goalsMap['protein'], fallback: 150),
        carbs: _readInt(goalsMap['carbs'], fallback: 250),
        fat: _readInt(goalsMap['fat'], fallback: 67),
      ),
      hitProtein: _readBool(json['hitProtein']),
      hitCalories: _readBool(json['hitCalories']),
      hasMealData: _readBool(json['hasMealData']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'totalFiber': totalFiber,
      'waterGlasses': waterGlasses,
      'waterGoal': waterGoal,
      'goals': goals.toJson(),
      'hitProtein': hitProtein,
      'hitCalories': hitCalories,
      'hasMealData': hasMealData,
    };
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ??
        fallback;
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }
}
