import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_localizations_extension.dart';
import '../models/diet_plan_model.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../utils/fabiano_access.dart';
import 'nutrition_goals_wizard_screen.dart';

enum _BenchmarkStatus { pending, running, completed, failed }

class _DietBenchmarkEntry {
  _DietBenchmarkEntry({
    required this.modelId,
    required this.targetCalories,
  });

  final String modelId;
  final int targetCalories;
  _BenchmarkStatus status = _BenchmarkStatus.pending;
  DietPlan? plan;
  DietGenerationUsage? usage;
  String? error;
  DateTime? startedAt;
  DateTime? completedAt;
  bool fromCache = false;
  String? cacheSignature;

  int get generatedCalories => plan?.totalNutrition.calories ?? 0;
  int get calorieDifference => (generatedCalories - targetCalories).abs();
  double get differencePercent =>
      targetCalories <= 0 ? 0 : calorieDifference / targetCalories;
  double get score => (100 - (differencePercent * 100)).clamp(0, 100);
  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }
}

class DietBenchmarkScreen extends StatefulWidget {
  const DietBenchmarkScreen({Key? key}) : super(key: key);

  @override
  State<DietBenchmarkScreen> createState() => _DietBenchmarkScreenState();
}

class _DietBenchmarkScreenState extends State<DietBenchmarkScreen> {
  static const String _modelsPrefsKey = 'diet_benchmark_models';
  static const String _resultsPrefsKey = 'diet_benchmark_results_v1';

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _bulkModelsController = TextEditingController();
  final List<String> _models = [];
  final List<_DietBenchmarkEntry> _results = [];
  final Map<String, Map<String, dynamic>> _cachedResults = {};
  bool _isLoadingModels = true;
  bool _isRunning = false;
  String? _modelError;
  String? _modelImportMessage;
  String? _runError;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _bulkModelsController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModels = prefs.getStringList(_modelsPrefsKey);
    _loadCachedResultsFromPrefs(prefs);
    final predefinedModels = DietPlanProvider.dietGenerationModelOptions
        .map((option) => option['id']!)
        .toSet();
    final successfulCachedModels = _cachedResults.values
        .where((entry) => entry['status']?.toString() == 'completed')
        .map((entry) => entry['modelId']?.toString())
        .whereType<String>()
        .toSet();
    final storedModels = savedModels != null && savedModels.isNotEmpty
        ? savedModels
            .map((modelId) => modelId.trim())
            .where(_isValidModelId)
            .where(
              (modelId) =>
                  predefinedModels.contains(modelId) ||
                  successfulCachedModels.contains(modelId),
            )
            .toList()
        : const <String>[];
    final initialModels =
        storedModels.isNotEmpty ? storedModels : predefinedModels.toList();

    if (!mounted) return;
    setState(() {
      _models
        ..clear()
        ..addAll(initialModels);
      _isLoadingModels = false;
    });

    if (savedModels != null && savedModels.length != initialModels.length) {
      await prefs.setStringList(_modelsPrefsKey, initialModels);
    }
  }

  Future<void> _saveModels() async {
    final prefs = await SharedPreferences.getInstance();
    final successfulModelIds = _results
        .where((entry) => entry.status == _BenchmarkStatus.completed)
        .map((entry) => entry.modelId)
        .toSet();
    final predefinedModelIds = DietPlanProvider.dietGenerationModelOptions
        .map((option) => option['id']!)
        .toSet();

    final persistableModels = _models
        .where(
          (modelId) =>
              predefinedModelIds.contains(modelId) ||
              successfulModelIds.contains(modelId),
        )
        .toList();

    await prefs.setStringList(_modelsPrefsKey, persistableModels);
  }

  void _loadCachedResultsFromPrefs(SharedPreferences prefs) {
    final rawCache = prefs.getString(_resultsPrefsKey);
    _cachedResults.clear();
    if (rawCache == null || rawCache.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawCache);
      if (decoded is! Map) {
        return;
      }

      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map) {
          _cachedResults[entry.key.toString()] =
              Map<String, dynamic>.from(value);
        }
      }
    } catch (error) {
      debugPrint('DietBenchmarkScreen: erro ao carregar cache: $error');
    }
  }

  Future<void> _saveCachedResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resultsPrefsKey, jsonEncode(_cachedResults));
  }

  Future<void> _clearResults() async {
    if (_isRunning) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resultsPrefsKey);
    setState(() {
      _cachedResults.clear();
      _results.clear();
    });
  }

  bool _isValidModelId(String modelId) {
    return DietPlanProvider.dietGenerationModelOptions.any(
          (option) => option['id'] == modelId,
        ) ||
        DietPlanProvider.isValidOpenRouterModelId(modelId);
  }

  void _addModel(String modelId) {
    final normalized = modelId.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (!_isValidModelId(normalized)) {
      setState(() {
        _modelError = context.tr.translate('benchmark_invalid_model');
      });
      return;
    }

    if (_models.contains(normalized)) {
      setState(() {
        _modelError = context.tr.translate('benchmark_model_already_added');
      });
      return;
    }

    setState(() {
      _models.add(normalized);
      _modelController.clear();
      _modelError = null;
    });
  }

  void _addModelList() {
    if (_bulkModelsController.text.trim().isEmpty) {
      final singleModelId = _modelController.text.trim();
      if (singleModelId.isNotEmpty) {
        _addModel(singleModelId);
        return;
      }
    }

    final candidates = _bulkModelsController.text
        .split(RegExp(r'[,;\n\r]+'))
        .map((modelId) => modelId.trim())
        .where((modelId) => modelId.isNotEmpty)
        .toList();

    if (candidates.isEmpty) {
      setState(() {
        _modelError = context.tr.translate('benchmark_bulk_empty');
        _modelImportMessage = null;
      });
      return;
    }

    final addedModels = <String>[];
    var ignoredCount = 0;

    for (final modelId in candidates) {
      if (!_isValidModelId(modelId) ||
          _models.contains(modelId) ||
          addedModels.contains(modelId)) {
        ignoredCount++;
        continue;
      }
      addedModels.add(modelId);
    }

    setState(() {
      _models.addAll(addedModels);
      if (addedModels.isNotEmpty) {
        _bulkModelsController.clear();
      }
      _modelError = addedModels.isEmpty
          ? context.tr.translate('benchmark_invalid_model')
          : null;
      _modelImportMessage =
          '${context.tr.translate('benchmark_bulk_added')}: ${addedModels.length}. '
          '${context.tr.translate('benchmark_bulk_ignored')}: $ignoredCount.';
    });
  }

  void _removeModel(String modelId) {
    if (_isRunning) return;
    setState(() {
      _models.remove(modelId);
      _results.removeWhere((entry) => entry.modelId == modelId);
      _cachedResults.removeWhere(
        (_, cached) => cached['modelId']?.toString() == modelId,
      );
    });
    _saveModels();
    _saveCachedResults();
  }

  Future<void> _runBenchmark() async {
    if (_isRunning || _models.isEmpty) {
      return;
    }

    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated ||
        authService.currentUser == null ||
        !canAccessDietBenchmark(authService.currentUser)) {
      setState(() {
        _runError = context.tr.translate('benchmark_restricted');
      });
      return;
    }

    final dietProvider = context.read<DietPlanProvider>();
    final nutritionGoals = context.read<NutritionGoalsProvider>();
    final mealTypesProvider = context.read<MealTypesProvider>();

    try {
      if (!dietProvider.isAuthenticated) {
        await dietProvider.setAuth(
          authService.token ?? '',
          authService.currentUser!.id,
        );
      }
      await Future.wait([
        dietProvider.ensureLoaded(),
        nutritionGoals.ensureLoaded(),
        mealTypesProvider.ensureLoaded(),
      ]);

      if (!nutritionGoals.hasConfiguredGoals) {
        setState(() {
          _runError = context.tr.translate('benchmark_configure_goals_first');
        });
        return;
      }

      final locale = Localizations.localeOf(context);
      final languageCode =
          '${locale.languageCode}_${locale.countryCode ?? locale.languageCode.toUpperCase()}';
      final userId = authService.currentUser!.id.toString();
      final selectedDate = dietProvider.selectedDate;
      final mealTypes = mealTypesProvider.mealTypes;
      final targetCalories = nutritionGoals.caloriesGoal;
      final benchmarkSignature = _buildBenchmarkSignature(
        dietProvider: dietProvider,
        nutritionGoals: nutritionGoals,
        mealTypes: mealTypes,
        languageCode: languageCode,
      );

      setState(() {
        _isRunning = true;
        _runError = null;
        _results
          ..clear()
          ..addAll(_models.map((modelId) {
            return _entryFromCache(
                  signature: benchmarkSignature,
                  modelId: modelId,
                  targetCalories: targetCalories,
                ) ??
                (_DietBenchmarkEntry(
                  modelId: modelId,
                  targetCalories: targetCalories,
                )..cacheSignature = benchmarkSignature);
          }));
      });

      for (final entry in _results) {
        if (entry.status == _BenchmarkStatus.completed) {
          continue;
        }

        if (!mounted) return;
        setState(() {
          entry.status = _BenchmarkStatus.running;
          entry.startedAt = DateTime.now();
        });

        try {
          final result = await dietProvider.generateDietBenchmarkPlan(
            selectedDate,
            nutritionGoals,
            modelId: entry.modelId,
            mealTypes: mealTypes,
            userId: userId,
            languageCode: languageCode,
          );

          if (!mounted) return;
          setState(() {
            entry.plan = result.plan;
            entry.usage = result.usage;
            entry.status = _BenchmarkStatus.completed;
            entry.completedAt = DateTime.now();
          });
          await _cacheEntry(benchmarkSignature, entry);
          await _saveModels();
        } catch (error) {
          await _removeCachedEntry(benchmarkSignature, entry.modelId);
          if (!mounted) return;
          setState(() {
            entry.error = error.toString();
            entry.status = _BenchmarkStatus.failed;
            entry.completedAt = DateTime.now();
          });
          await _saveModels();
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _runError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  String _buildBenchmarkSignature({
    required DietPlanProvider dietProvider,
    required NutritionGoalsProvider nutritionGoals,
    required List<MealTypeConfig> mealTypes,
    required String languageCode,
  }) {
    return jsonEncode({
      'promptVersion': 3,
      'languageCode': languageCode,
      'targets': {
        'calories': nutritionGoals.caloriesGoal,
        'protein': nutritionGoals.proteinGoal,
        'carbs': nutritionGoals.carbsGoal,
        'fat': nutritionGoals.fatGoal,
      },
      'mealTypes': mealTypes
          .map((mealType) => {
                'id': mealType.id,
                'name': mealType.name,
              })
          .toList(),
      'preferences': _benchmarkPreferencesSignature(dietProvider.preferences),
    });
  }

  Map<String, dynamic> _benchmarkPreferencesSignature(
    DietPreferences preferences,
  ) {
    return {
      'foodRestrictions': preferences.foodRestrictions,
      'favoriteFoods': preferences.favoriteFoods,
      'avoidedFoods': preferences.avoidedFoods,
      'routineConsiderations': preferences.routineConsiderations,
      'hasReviewedRestrictions': preferences.hasReviewedRestrictions,
      'hasReviewedFoodPreferences': preferences.hasReviewedFoodPreferences,
      'hasReviewedRoutineNeeds': preferences.hasReviewedRoutineNeeds,
      'hungriestMealTime': preferences.hungriestMealTime,
    };
  }

  String _cacheKey(String signature, String modelId) {
    final encodedSignature = base64Url.encode(utf8.encode(signature));
    final encodedModel = base64Url.encode(utf8.encode(modelId));
    return '$encodedSignature:$encodedModel';
  }

  _DietBenchmarkEntry? _entryFromCache({
    required String signature,
    required String modelId,
    required int targetCalories,
  }) {
    final cached = _cachedResults[_cacheKey(signature, modelId)];
    if (cached == null) {
      return null;
    }

    try {
      final cachedStatus = cached['status']?.toString();
      if (cachedStatus != null && cachedStatus != 'completed') {
        return null;
      }

      final planData = cached['plan'];
      if (planData is! Map) {
        return null;
      }

      final completedAt = DateTime.tryParse(
        cached['completedAt']?.toString() ?? '',
      );
      final durationMs = cached['durationMs'] is int
          ? cached['durationMs'] as int
          : int.tryParse(cached['durationMs']?.toString() ?? '');

      final entry = _DietBenchmarkEntry(
        modelId: modelId,
        targetCalories: targetCalories,
      )
        ..plan = DietPlan.fromJson(Map<String, dynamic>.from(planData))
        ..usage = _readCachedUsage(cached['usage'])
        ..status = _BenchmarkStatus.completed
        ..fromCache = true
        ..cacheSignature = signature
        ..completedAt = completedAt;

      if (completedAt != null && durationMs != null && durationMs > 0) {
        entry.startedAt =
            completedAt.subtract(Duration(milliseconds: durationMs));
      }

      return entry;
    } catch (error) {
      debugPrint('DietBenchmarkScreen: cache inválido para $modelId: $error');
      return null;
    }
  }

  Future<void> _cacheEntry(
    String signature,
    _DietBenchmarkEntry entry,
  ) async {
    final plan = entry.plan;
    if (plan == null || entry.status != _BenchmarkStatus.completed) {
      return;
    }

    final completedAt = entry.completedAt ?? DateTime.now();
    entry.cacheSignature = signature;
    _cachedResults[_cacheKey(signature, entry.modelId)] = {
      'status': 'completed',
      'modelId': entry.modelId,
      'signature': signature,
      'targetCalories': entry.targetCalories,
      'completedAt': completedAt.toIso8601String(),
      'durationMs': entry.duration?.inMilliseconds,
      if (entry.usage != null) 'usage': entry.usage!.toJson(),
      'plan': plan.toJson(),
    };
    await _saveCachedResults();
  }

  Future<void> _removeCachedEntry(String signature, String modelId) async {
    final removed =
        _cachedResults.remove(_cacheKey(signature, modelId)) != null;
    if (removed) {
      await _saveCachedResults();
    }
  }

  Future<void> _clearEntryCache(_DietBenchmarkEntry entry) async {
    final signature = entry.cacheSignature;
    if (signature == null || _isRunning) {
      return;
    }

    await _removeCachedEntry(signature, entry.modelId);
    if (!mounted) return;

    setState(() {
      entry
        ..status = _BenchmarkStatus.pending
        ..plan = null
        ..usage = null
        ..error = null
        ..startedAt = null
        ..completedAt = null
        ..fromCache = false;
    });
    await _saveModels();
  }

  DietGenerationUsage? _readCachedUsage(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    return DietGenerationUsage.fromJson(Map<String, dynamic>.from(raw));
  }

  List<_DietBenchmarkEntry> get _rankedResults {
    final completed = _results
        .where((entry) => entry.status == _BenchmarkStatus.completed)
        .toList()
      ..sort((a, b) => a.calorieDifference.compareTo(b.calorieDifference));
    final rest = _results
        .where((entry) => entry.status != _BenchmarkStatus.completed)
        .toList();
    return [...completed, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (!canAccessDietBenchmark(authService.currentUser)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr.translate('diet_benchmark_title')),
        ),
        body: _buildRestrictedState(isDarkMode),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.translate('diet_benchmark_title')),
        actions: [
          IconButton(
            tooltip: context.tr.translate('benchmark_clear_results'),
            onPressed: _isRunning || _results.isEmpty ? null : _clearResults,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingModels
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _buildTargetSection(isDarkMode),
                  const SizedBox(height: 14),
                  _buildModelSection(isDarkMode),
                  const SizedBox(height: 14),
                  _buildRunSection(isDarkMode),
                  const SizedBox(height: 14),
                  _buildResultsSection(isDarkMode),
                ],
              ),
      ),
    );
  }

  Widget _buildRestrictedState(bool isDarkMode) {
    final color = isDarkMode ? Colors.white70 : Colors.black54;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 44, color: color),
            const SizedBox(height: 14),
            Text(
              context.tr.translate('benchmark_restricted'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSection(bool isDarkMode) {
    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionGoals, child) {
        if (!nutritionGoals.hasConfiguredGoals) {
          return _panel(
            isDarkMode: isDarkMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  context.tr.translate('benchmark_target_title'),
                  Icons.flag_outlined,
                  isDarkMode,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr.translate('benchmark_configure_goals_first'),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NutritionGoalsWizardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune),
                  label: Text(context.tr.translate('configure_goals')),
                ),
              ],
            ),
          );
        }

        return _panel(
          isDarkMode: isDarkMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                context.tr.translate('benchmark_target_title'),
                Icons.flag_outlined,
                isDarkMode,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metricTile(
                    icon: Icons.local_fire_department,
                    label: context.tr.translate('calories'),
                    value: '${nutritionGoals.caloriesGoal}',
                    suffix: 'kcal',
                    color: MacroTheme.caloriesColor,
                    isDarkMode: isDarkMode,
                  ),
                  _metricTile(
                    icon: Icons.fitness_center,
                    label: context.tr.translate('protein'),
                    value: '${nutritionGoals.proteinGoal}',
                    suffix: 'g',
                    color: MacroTheme.proteinColor,
                    isDarkMode: isDarkMode,
                  ),
                  _metricTile(
                    icon: Icons.grain,
                    label: context.tr.translate('carbohydrates'),
                    value: '${nutritionGoals.carbsGoal}',
                    suffix: 'g',
                    color: MacroTheme.carbsColor,
                    isDarkMode: isDarkMode,
                  ),
                  _metricTile(
                    icon: Icons.water_drop_outlined,
                    label: context.tr.translate('fat'),
                    value: '${nutritionGoals.fatGoal}',
                    suffix: 'g',
                    color: MacroTheme.fatColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelSection(bool isDarkMode) {
    final predefinedModels = DietPlanProvider.dietGenerationModelOptions;
    final dietProvider = context.watch<DietPlanProvider>();

    return _panel(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            context.tr.translate('benchmark_models_title'),
            Icons.psychology_alt_outlined,
            isDarkMode,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _modelController,
            enabled: !_isRunning,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: context.tr.translate('openrouter_model_id_hint'),
              hintText: 'google/gemini-3-flash-preview',
              errorText: _modelError,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: context.tr.translate('benchmark_add_model'),
                onPressed:
                    _isRunning ? null : () => _addModel(_modelController.text),
                icon: const Icon(Icons.add),
              ),
            ),
            onChanged: (_) {
              if (_modelError != null) {
                setState(() => _modelError = null);
              }
            },
            onSubmitted: _isRunning ? null : _addModel,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bulkModelsController,
            enabled: !_isRunning,
            autocorrect: false,
            enableSuggestions: false,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: context.tr.translate('benchmark_bulk_models_label'),
              hintText: context.tr.translate('benchmark_bulk_models_hint'),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_modelError != null || _modelImportMessage != null) {
                setState(() {
                  _modelError = null;
                  _modelImportMessage = null;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isRunning ? null : _addModelList,
              icon: const Icon(Icons.playlist_add),
              label: Text(context.tr.translate('benchmark_add_model_list')),
            ),
          ),
          if (_modelImportMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _modelImportMessage!,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.star_outline, size: 18),
                label: Text(context.tr.translate('benchmark_add_current')),
                onPressed: _isRunning
                    ? null
                    : () => _addModel(dietProvider.dietGenerationModel),
              ),
              ...predefinedModels.map(
                (option) => ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(option['name']!),
                  onPressed: _isRunning ? null : () => _addModel(option['id']!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_models.isEmpty)
            Text(
              context.tr.translate('benchmark_no_models'),
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            )
          else
            Column(
              children: _models
                  .map(
                    (modelId) => _modelListItem(modelId, isDarkMode),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRunSection(bool isDarkMode) {
    return _panel(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _isRunning || _models.isEmpty ? null : _runBenchmark,
            icon: _isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(
              _isRunning
                  ? context.tr.translate('benchmark_running')
                  : context.tr.translate('benchmark_run_all'),
            ),
          ),
          if (_runError != null) ...[
            const SizedBox(height: 10),
            Text(
              _runError!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsSection(bool isDarkMode) {
    if (_results.isEmpty) {
      return _panel(
        isDarkMode: isDarkMode,
        child: Text(
          context.tr.translate('benchmark_empty_results'),
          style: TextStyle(
            color: isDarkMode ? Colors.white54 : Colors.black45,
          ),
        ),
      );
    }

    final ranked = _rankedResults;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context.tr.translate('benchmark_results_title'),
          Icons.leaderboard_outlined,
          isDarkMode,
        ),
        const SizedBox(height: 10),
        ...List.generate(ranked.length, (index) {
          final entry = ranked[index];
          final isBest =
              index == 0 && entry.status == _BenchmarkStatus.completed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _resultCard(
              entry,
              rank:
                  entry.status == _BenchmarkStatus.completed ? index + 1 : null,
              isBest: isBest,
              isDarkMode: isDarkMode,
            ),
          );
        }),
      ],
    );
  }

  Widget _modelListItem(String modelId, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF242424) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.memory,
            size: 18,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              modelId,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr.translate('remove'),
            onPressed: _isRunning ? null : () => _removeModel(modelId),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(
    _DietBenchmarkEntry entry, {
    required int? rank,
    required bool isBest,
    required bool isDarkMode,
  }) {
    final borderColor = isBest
        ? Colors.green
        : isDarkMode
            ? Colors.white12
            : Colors.black12;
    final generated = entry.plan?.totalNutrition;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isBest ? 1.5 : 1),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.modelId,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (entry.status == _BenchmarkStatus.completed)
                IconButton(
                  tooltip: context.tr.translate('benchmark_clear_model_cache'),
                  onPressed: _isRunning ? null : () => _clearEntryCache(entry),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  visualDensity: VisualDensity.compact,
                ),
              _statusBadge(entry, rank, isBest, isDarkMode),
            ],
          ),
          const SizedBox(height: 10),
          if (entry.status == _BenchmarkStatus.running) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(context.tr.translate('benchmark_model_running')),
          ] else if (entry.status == _BenchmarkStatus.failed) ...[
            Text(
              entry.error ?? context.tr.translate('benchmark_model_failed'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ] else if (generated != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _smallStat(
                  context.tr.translate('benchmark_target_short'),
                  '${entry.targetCalories} kcal',
                  isDarkMode,
                ),
                _smallStat(
                  context.tr.translate('benchmark_generated_short'),
                  '${entry.generatedCalories} kcal',
                  isDarkMode,
                ),
                _smallStat(
                  context.tr.translate('benchmark_difference_short'),
                  '${entry.calorieDifference} kcal',
                  isDarkMode,
                ),
                _smallStat(
                  context.tr.translate('benchmark_score_short'),
                  entry.score.toStringAsFixed(1),
                  isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (entry.score / 100).clamp(0, 1),
              minHeight: 6,
              borderRadius: BorderRadius.circular(20),
              backgroundColor: isDarkMode ? Colors.white10 : Colors.black12,
              color: isBest ? Colors.green : AppTheme.primaryColor,
            ),
            const SizedBox(height: 10),
            Text(
              '${context.tr.translate('protein')}: ${generated.protein.toStringAsFixed(0)}g  '
              '${context.tr.translate('carbohydrates')}: ${generated.carbs.toStringAsFixed(0)}g  '
              '${context.tr.translate('fat')}: ${generated.fat.toStringAsFixed(0)}g',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            if (entry.usage != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallStat(
                    context.tr.translate('benchmark_total_tokens_short'),
                    '${entry.usage!.totalTokens}',
                    isDarkMode,
                  ),
                  _smallStat(
                    context.tr.translate('benchmark_input_tokens_short'),
                    '${entry.usage!.promptTokens}',
                    isDarkMode,
                  ),
                  _smallStat(
                    context.tr.translate('benchmark_output_tokens_short'),
                    '${entry.usage!.completionTokens}',
                    isDarkMode,
                  ),
                  _smallStat(
                    context.tr.translate('benchmark_cost_short'),
                    _formatCost(entry.usage!.costCredits),
                    isDarkMode,
                  ),
                  if ((entry.usage!.cachedTokens ?? 0) > 0)
                    _smallStat(
                      context.tr.translate('benchmark_cached_tokens_short'),
                      '${entry.usage!.cachedTokens}',
                      isDarkMode,
                    ),
                ],
              ),
            ] else if (entry.status == _BenchmarkStatus.completed) ...[
              const SizedBox(height: 8),
              Text(
                context.tr.translate('benchmark_usage_unavailable'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
            if (entry.duration != null) ...[
              const SizedBox(height: 6),
              Text(
                '${context.tr.translate('benchmark_duration')}: ${entry.duration!.inSeconds}s',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
            if (entry.fromCache) ...[
              const SizedBox(height: 4),
              Text(
                context.tr.translate('benchmark_cached_result'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _showGeneratedDiet(entry),
                icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
                label:
                    Text(context.tr.translate('benchmark_view_generated_diet')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showGeneratedDiet(_DietBenchmarkEntry entry) {
    final plan = entry.plan;
    if (plan == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDarkMode = theme.brightness == Brightness.dark;
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final secondaryTextColor = isDarkMode ? Colors.white60 : Colors.black54;
        final cardColor =
            isDarkMode ? const Color(0xFF242424) : const Color(0xFFF7F7F7);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr
                              .translate('benchmark_generated_diet_title'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr.translate('close'),
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.modelId,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _smallStat(
                        context.tr.translate('calories'),
                        '${plan.totalNutrition.calories} kcal',
                        isDarkMode,
                      ),
                      _smallStat(
                        context.tr.translate('protein'),
                        '${plan.totalNutrition.protein.toStringAsFixed(0)}g',
                        isDarkMode,
                      ),
                      _smallStat(
                        context.tr.translate('carbohydrates'),
                        '${plan.totalNutrition.carbs.toStringAsFixed(0)}g',
                        isDarkMode,
                      ),
                      _smallStat(
                        context.tr.translate('fat'),
                        '${plan.totalNutrition.fat.toStringAsFixed(0)}g',
                        isDarkMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...plan.meals.map(
                    (meal) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  meal.name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                meal.time,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _nutritionSummary(meal.mealTotals),
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...meal.foods.map(
                            (food) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                _foodSummary(food),
                                style: TextStyle(
                                  color: textColor,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _nutritionSummary(DailyNutrition nutrition) {
    return '${nutrition.calories} kcal | '
        '${context.tr.translate('protein')} ${nutrition.protein.toStringAsFixed(0)}g | '
        '${context.tr.translate('carbohydrates')} ${nutrition.carbs.toStringAsFixed(0)}g | '
        '${context.tr.translate('fat')} ${nutrition.fat.toStringAsFixed(0)}g';
  }

  String _foodSummary(PlannedFood food) {
    final amount = food.amount == food.amount.roundToDouble()
        ? food.amount.round().toString()
        : food.amount.toStringAsFixed(1);
    return '- ${food.name}: $amount ${food.unit} '
        '(${food.calories} kcal, '
        'P ${food.protein.toStringAsFixed(1)}g, '
        'C ${food.carbs.toStringAsFixed(1)}g, '
        'G ${food.fat.toStringAsFixed(1)}g)';
  }

  String _formatCost(double? cost) {
    if (cost == null) {
      return '-';
    }

    if (cost == 0) {
      return '0 cr';
    }

    if (cost < 0.000001) {
      return '${cost.toStringAsExponential(2)} cr';
    }

    return '${cost.toStringAsFixed(6)} cr';
  }

  Widget _statusBadge(
    _DietBenchmarkEntry entry,
    int? rank,
    bool isBest,
    bool isDarkMode,
  ) {
    String label;
    Color color;

    switch (entry.status) {
      case _BenchmarkStatus.pending:
        label = context.tr.translate('benchmark_pending');
        color = Colors.grey;
        break;
      case _BenchmarkStatus.running:
        label = context.tr.translate('benchmark_running_short');
        color = Colors.blue;
        break;
      case _BenchmarkStatus.failed:
        label = context.tr.translate('benchmark_failed');
        color = Colors.red;
        break;
      case _BenchmarkStatus.completed:
        label =
            isBest ? context.tr.translate('benchmark_best') : '#${rank ?? '-'}';
        color = isBest
            ? Colors.green
            : isDarkMode
                ? Colors.white70
                : Colors.black87;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _smallStat(String label, String value, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
    required String suffix,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value$suffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDarkMode ? Colors.white : Colors.black87),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel({
    required bool isDarkMode,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1B1B1B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }
}
