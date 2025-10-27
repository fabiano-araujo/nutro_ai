import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CalculationFormula {
  mifflinStJeor,
  harrisBenedict,
  katchMcArdle,
}

enum ActivityLevel {
  sedentary, // Sedentário (pouco ou nenhum exercício)
  lightlyActive, // Levemente ativo (exercício leve 1-3 dias/semana)
  moderatelyActive, // Moderadamente ativo (exercício moderado 3-5 dias/semana)
  veryActive, // Muito ativo (exercício intenso 6-7 dias/semana)
  extremelyActive, // Extremamente ativo (exercício muito intenso, trabalho físico)
}

enum FitnessGoal {
  loseWeight, // Perder peso
  maintainWeight, // Manter peso
  gainWeight, // Ganhar peso
  gainMuscle, // Ganhar massa muscular
}

enum DietType {
  standard, // Padrão (40% carbs, 30% protein, 30% fat)
  balanced, // Equilibrada (50% carbs, 20% protein, 30% fat)
  ketogenic, // Cetogênica (5% carbs, 25% protein, 70% fat)
  lowCarb, // Low Carb (20% carbs, 40% protein, 40% fat)
  highProtein, // High Protein (30% carbs, 40% protein, 30% fat)
  custom, // Personalizada
}

class NutritionGoalsProvider extends ChangeNotifier {
  // Personal information
  String _sex = 'male'; // 'male' or 'female'
  int _age = 30;
  double _weight = 70.0; // kg
  double _height = 170.0; // cm
  double? _bodyFat; // optional, for Katch-McArdle formula

  // Activity and goals
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  FitnessGoal _fitnessGoal = FitnessGoal.maintainWeight;
  CalculationFormula _formula = CalculationFormula.mifflinStJeor;

  // Diet type and macros
  DietType _dietType = DietType.balanced;
  int _carbsPercentage = 50;
  int _proteinPercentage = 20;
  int _fatPercentage = 30;

  // Calculated or manual goals
  bool _useCalculatedGoals = true;
  int _manualCaloriesGoal = 2000;
  int _manualProteinGoal = 150;
  int _manualCarbsGoal = 250;
  int _manualFatGoal = 67;

  // Getters
  String get sex => _sex;
  int get age => _age;
  double get weight => _weight;
  double get height => _height;
  double? get bodyFat => _bodyFat;
  ActivityLevel get activityLevel => _activityLevel;
  FitnessGoal get fitnessGoal => _fitnessGoal;
  CalculationFormula get formula => _formula;
  DietType get dietType => _dietType;
  int get carbsPercentage => _carbsPercentage;
  int get proteinPercentage => _proteinPercentage;
  int get fatPercentage => _fatPercentage;
  bool get useCalculatedGoals => _useCalculatedGoals;

  // Calculated goals
  int get caloriesGoal => _useCalculatedGoals ? _calculateCalories() : _manualCaloriesGoal;
  int get proteinGoal => _useCalculatedGoals ? _calculateProtein() : _manualProteinGoal;
  int get carbsGoal => _useCalculatedGoals ? _calculateCarbs() : _manualCarbsGoal;
  int get fatGoal => _useCalculatedGoals ? _calculateFat() : _manualFatGoal;

  NutritionGoalsProvider() {
    _loadFromPreferences();
  }

  // Load saved preferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _sex = prefs.getString('nutrition_sex') ?? 'male';
      _age = prefs.getInt('nutrition_age') ?? 30;
      _weight = prefs.getDouble('nutrition_weight') ?? 70.0;
      _height = prefs.getDouble('nutrition_height') ?? 170.0;
      _bodyFat = prefs.getDouble('nutrition_bodyFat');

      final activityIndex = prefs.getInt('nutrition_activityLevel') ?? 2;
      _activityLevel = ActivityLevel.values[activityIndex];

      final goalIndex = prefs.getInt('nutrition_fitnessGoal') ?? 1;
      _fitnessGoal = FitnessGoal.values[goalIndex];

      final formulaIndex = prefs.getInt('nutrition_formula') ?? 0;
      _formula = CalculationFormula.values[formulaIndex];

      final dietIndex = prefs.getInt('nutrition_dietType') ?? 1;
      _dietType = DietType.values[dietIndex];

      _carbsPercentage = prefs.getInt('nutrition_carbsPercentage') ?? 50;
      _proteinPercentage = prefs.getInt('nutrition_proteinPercentage') ?? 20;
      _fatPercentage = prefs.getInt('nutrition_fatPercentage') ?? 30;

      _useCalculatedGoals = prefs.getBool('nutrition_useCalculated') ?? true;
      _manualCaloriesGoal = prefs.getInt('nutrition_manualCalories') ?? 2000;
      _manualProteinGoal = prefs.getInt('nutrition_manualProtein') ?? 150;
      _manualCarbsGoal = prefs.getInt('nutrition_manualCarbs') ?? 250;
      _manualFatGoal = prefs.getInt('nutrition_manualFat') ?? 67;

      notifyListeners();
    } catch (e) {
      print('Error loading nutrition goals: $e');
    }
  }

  // Save to preferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('nutrition_sex', _sex);
      await prefs.setInt('nutrition_age', _age);
      await prefs.setDouble('nutrition_weight', _weight);
      await prefs.setDouble('nutrition_height', _height);
      if (_bodyFat != null) {
        await prefs.setDouble('nutrition_bodyFat', _bodyFat!);
      } else {
        await prefs.remove('nutrition_bodyFat');
      }

      await prefs.setInt('nutrition_activityLevel', _activityLevel.index);
      await prefs.setInt('nutrition_fitnessGoal', _fitnessGoal.index);
      await prefs.setInt('nutrition_formula', _formula.index);
      await prefs.setInt('nutrition_dietType', _dietType.index);

      await prefs.setInt('nutrition_carbsPercentage', _carbsPercentage);
      await prefs.setInt('nutrition_proteinPercentage', _proteinPercentage);
      await prefs.setInt('nutrition_fatPercentage', _fatPercentage);

      await prefs.setBool('nutrition_useCalculated', _useCalculatedGoals);
      await prefs.setInt('nutrition_manualCalories', _manualCaloriesGoal);
      await prefs.setInt('nutrition_manualProtein', _manualProteinGoal);
      await prefs.setInt('nutrition_manualCarbs', _manualCarbsGoal);
      await prefs.setInt('nutrition_manualFat', _manualFatGoal);
    } catch (e) {
      print('Error saving nutrition goals: $e');
    }
  }

  // Update personal information
  void updatePersonalInfo({
    String? sex,
    int? age,
    double? weight,
    double? height,
    double? bodyFat,
  }) {
    if (sex != null) _sex = sex;
    if (age != null) _age = age;
    if (weight != null) _weight = weight;
    if (height != null) _height = height;
    if (bodyFat != null) _bodyFat = bodyFat;

    _saveToPreferences();
    notifyListeners();
  }

  // Update activity and goals
  void updateActivityAndGoals({
    ActivityLevel? activityLevel,
    FitnessGoal? fitnessGoal,
    CalculationFormula? formula,
  }) {
    if (activityLevel != null) _activityLevel = activityLevel;
    if (fitnessGoal != null) _fitnessGoal = fitnessGoal;
    if (formula != null) _formula = formula;

    _saveToPreferences();
    notifyListeners();
  }

  // Update diet type and macros
  void updateDietType(DietType dietType) {
    _dietType = dietType;

    // Set default macro percentages for each diet type
    switch (dietType) {
      case DietType.standard:
        _carbsPercentage = 40;
        _proteinPercentage = 30;
        _fatPercentage = 30;
        break;
      case DietType.balanced:
        _carbsPercentage = 50;
        _proteinPercentage = 20;
        _fatPercentage = 30;
        break;
      case DietType.ketogenic:
        _carbsPercentage = 5;
        _proteinPercentage = 25;
        _fatPercentage = 70;
        break;
      case DietType.lowCarb:
        _carbsPercentage = 20;
        _proteinPercentage = 40;
        _fatPercentage = 40;
        break;
      case DietType.highProtein:
        _carbsPercentage = 30;
        _proteinPercentage = 40;
        _fatPercentage = 30;
        break;
      case DietType.custom:
        // Keep current percentages
        break;
    }

    _saveToPreferences();
    notifyListeners();
  }

  // Update custom macro percentages
  void updateMacroPercentages({
    required int carbs,
    required int protein,
    required int fat,
  }) {
    // Ensure they add up to 100%
    final total = carbs + protein + fat;
    if (total != 100) {
      print('Warning: Macro percentages do not add up to 100%');
      return;
    }

    _carbsPercentage = carbs;
    _proteinPercentage = protein;
    _fatPercentage = fat;
    _dietType = DietType.custom;

    _saveToPreferences();
    notifyListeners();
  }

  // Toggle between calculated and manual goals
  void setUseCalculatedGoals(bool value) {
    _useCalculatedGoals = value;
    _saveToPreferences();
    notifyListeners();
  }

  // Update manual goals
  void updateManualGoals({
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
  }) {
    if (calories != null) _manualCaloriesGoal = calories;
    if (protein != null) _manualProteinGoal = protein;
    if (carbs != null) _manualCarbsGoal = carbs;
    if (fat != null) _manualFatGoal = fat;

    _saveToPreferences();
    notifyListeners();
  }

  // Calculate BMR using selected formula
  double _calculateBMR() {
    switch (_formula) {
      case CalculationFormula.mifflinStJeor:
        return _calculateMifflinStJeor();
      case CalculationFormula.harrisBenedict:
        return _calculateHarrisBenedict();
      case CalculationFormula.katchMcArdle:
        return _calculateKatchMcArdle();
    }
  }

  // Mifflin-St Jeor formula (most accurate for most people)
  double _calculateMifflinStJeor() {
    if (_sex == 'male') {
      return (10 * _weight) + (6.25 * _height) - (5 * _age) + 5;
    } else {
      return (10 * _weight) + (6.25 * _height) - (5 * _age) - 161;
    }
  }

  // Harris-Benedict formula (revised)
  double _calculateHarrisBenedict() {
    if (_sex == 'male') {
      return 88.362 + (13.397 * _weight) + (4.799 * _height) - (5.677 * _age);
    } else {
      return 447.593 + (9.247 * _weight) + (3.098 * _height) - (4.330 * _age);
    }
  }

  // Katch-McArdle formula (requires body fat percentage)
  double _calculateKatchMcArdle() {
    if (_bodyFat == null) {
      // Fall back to Mifflin-St Jeor if body fat not provided
      return _calculateMifflinStJeor();
    }
    final leanMass = _weight * (1 - _bodyFat! / 100);
    return 370 + (21.6 * leanMass);
  }

  // Get activity multiplier
  double _getActivityMultiplier() {
    switch (_activityLevel) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.lightlyActive:
        return 1.375;
      case ActivityLevel.moderatelyActive:
        return 1.55;
      case ActivityLevel.veryActive:
        return 1.725;
      case ActivityLevel.extremelyActive:
        return 1.9;
    }
  }

  // Calculate TDEE (Total Daily Energy Expenditure)
  double _calculateTDEE() {
    return _calculateBMR() * _getActivityMultiplier();
  }

  // Calculate calorie goal based on fitness goal
  int _calculateCalories() {
    final tdee = _calculateTDEE();

    switch (_fitnessGoal) {
      case FitnessGoal.loseWeight:
        return (tdee - 500).round(); // 500 calorie deficit
      case FitnessGoal.maintainWeight:
        return tdee.round();
      case FitnessGoal.gainWeight:
        return (tdee + 300).round(); // 300 calorie surplus
      case FitnessGoal.gainMuscle:
        return (tdee + 500).round(); // 500 calorie surplus
    }
  }

  // Calculate protein goal in grams
  int _calculateProtein() {
    final calories = _calculateCalories();
    final proteinCalories = calories * (_proteinPercentage / 100);
    return (proteinCalories / 4).round(); // 4 calories per gram of protein
  }

  // Calculate carbs goal in grams
  int _calculateCarbs() {
    final calories = _calculateCalories();
    final carbsCalories = calories * (_carbsPercentage / 100);
    return (carbsCalories / 4).round(); // 4 calories per gram of carbs
  }

  // Calculate fat goal in grams
  int _calculateFat() {
    final calories = _calculateCalories();
    final fatCalories = calories * (_fatPercentage / 100);
    return (fatCalories / 9).round(); // 9 calories per gram of fat
  }

  // Helper methods for UI
  String getActivityLevelName(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Sedentário';
      case ActivityLevel.lightlyActive:
        return 'Levemente Ativo';
      case ActivityLevel.moderatelyActive:
        return 'Moderadamente Ativo';
      case ActivityLevel.veryActive:
        return 'Muito Ativo';
      case ActivityLevel.extremelyActive:
        return 'Extremamente Ativo';
    }
  }

  String getActivityLevelDescription(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Pouco ou nenhum exercício';
      case ActivityLevel.lightlyActive:
        return 'Exercício leve 1-3 dias/semana';
      case ActivityLevel.moderatelyActive:
        return 'Exercício moderado 3-5 dias/semana';
      case ActivityLevel.veryActive:
        return 'Exercício intenso 6-7 dias/semana';
      case ActivityLevel.extremelyActive:
        return 'Exercício muito intenso, trabalho físico';
    }
  }

  String getFitnessGoalName(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return 'Perder Peso';
      case FitnessGoal.maintainWeight:
        return 'Manter Peso';
      case FitnessGoal.gainWeight:
        return 'Ganhar Peso';
      case FitnessGoal.gainMuscle:
        return 'Ganhar Massa Muscular';
    }
  }

  String getFormulaName(CalculationFormula formula) {
    switch (formula) {
      case CalculationFormula.mifflinStJeor:
        return 'Mifflin-St Jeor';
      case CalculationFormula.harrisBenedict:
        return 'Harris-Benedict';
      case CalculationFormula.katchMcArdle:
        return 'Katch-McArdle';
    }
  }

  String getDietTypeName(DietType type) {
    switch (type) {
      case DietType.standard:
        return 'Padrão';
      case DietType.balanced:
        return 'Equilibrada';
      case DietType.ketogenic:
        return 'Cetogênica';
      case DietType.lowCarb:
        return 'Low Carb';
      case DietType.highProtein:
        return 'High Protein';
      case DietType.custom:
        return 'Personalizada';
    }
  }

  String getDietTypeDescription(DietType type) {
    switch (type) {
      case DietType.standard:
        return '40% Carbs, 30% Proteína, 30% Gordura';
      case DietType.balanced:
        return '50% Carbs, 20% Proteína, 30% Gordura';
      case DietType.ketogenic:
        return '5% Carbs, 25% Proteína, 70% Gordura';
      case DietType.lowCarb:
        return '20% Carbs, 40% Proteína, 40% Gordura';
      case DietType.highProtein:
        return '30% Carbs, 40% Proteína, 30% Gordura';
      case DietType.custom:
        return '$_carbsPercentage% Carbs, $_proteinPercentage% Proteína, $_fatPercentage% Gordura';
    }
  }
}
