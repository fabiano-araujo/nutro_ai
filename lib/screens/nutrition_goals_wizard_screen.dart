import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';

class NutritionGoalsWizardScreen extends StatefulWidget {
  final int startStep;
  final bool fromProfile;

  const NutritionGoalsWizardScreen({
    Key? key,
    this.startStep = 0,
    this.fromProfile = false,
  }) : super(key: key);

  @override
  State<NutritionGoalsWizardScreen> createState() => _NutritionGoalsWizardScreenState();
}

class _NutritionGoalsWizardScreenState extends State<NutritionGoalsWizardScreen> {
  late int _currentStep;
  late PageController _pageController;

  // Step 0: Personal Info
  String _selectedSex = 'male';
  int _age = 30;
  double _weight = 70.0;
  double _height = 170.0;
  double? _bodyFat;

  // Step 1: Activity & Goal
  ActivityLevel _selectedActivityLevel = ActivityLevel.moderatelyActive;
  FitnessGoal _selectedFitnessGoal = FitnessGoal.maintainWeight;

  // Step 2: Diet Type
  DietType _selectedDietType = DietType.balanced;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.startStep;
    _pageController = PageController(initialPage: widget.startStep);

    // Load current values from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NutritionGoalsProvider>(context, listen: false);
      setState(() {
        _selectedSex = provider.sex;
        _age = provider.age;
        _weight = provider.weight;
        _height = provider.height;
        _bodyFat = provider.bodyFat;
        _selectedActivityLevel = provider.activityLevel;
        _selectedFitnessGoal = provider.fitnessGoal;
        _selectedDietType = provider.dietType;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Save current step data before moving forward
    _saveCurrentStep();

    // Se foi aberto do profile, salvar e voltar
    if (widget.fromProfile) {
      _saveAndFinish();
      return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndFinish();
    }
  }

  void _saveCurrentStep() {
    final provider = Provider.of<NutritionGoalsProvider>(context, listen: false);

    switch (_currentStep) {
      case 0:
        // Save personal info
        provider.updatePersonalInfo(
          sex: _selectedSex,
          age: _age,
          weight: _weight,
          height: _height,
          bodyFat: _bodyFat,
        );
        break;
      case 1:
        // Save activity level
        provider.updateActivityAndGoals(
          activityLevel: _selectedActivityLevel,
        );
        break;
      case 2:
        // Save fitness goal
        provider.updateActivityAndGoals(
          fitnessGoal: _selectedFitnessGoal,
        );
        break;
      case 3:
        // Save diet type
        provider.updateDietType(_selectedDietType);
        break;
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _saveAndFinish() {
    final provider = Provider.of<NutritionGoalsProvider>(context, listen: false);

    // Ensure calculated mode is enabled
    provider.setUseCalculatedGoals(true);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metas configuradas com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configurar Metas',
          style: AppTheme.headingLarge.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(theme, isDarkMode, textColor),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                _buildPersonalInfoStep(theme, isDarkMode, textColor),
                _buildActivityLevelStep(theme, isDarkMode, textColor),
                _buildFitnessGoalStep(theme, isDarkMode, textColor),
                _buildDietTypeStep(theme, isDarkMode, textColor),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(theme, isDarkMode, textColor),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme, bool isDarkMode, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: List.generate(4, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? AppTheme.primaryColor
                          : textColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 3) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalInfoStep(ThemeData theme, bool isDarkMode, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.person,
            title: 'Informações Pessoais',
            subtitle: 'Precisamos conhecer um pouco sobre você',
            theme: theme,
            textColor: textColor,
          ),
          const SizedBox(height: 32),

          // Sex selection
          Text(
            'Sexo',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSelectableCard(
                  icon: Icons.male,
                  label: 'Masculino',
                  isSelected: _selectedSex == 'male',
                  onTap: () => setState(() => _selectedSex = 'male'),
                  theme: theme,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSelectableCard(
                  icon: Icons.female,
                  label: 'Feminino',
                  isSelected: _selectedSex == 'female',
                  onTap: () => setState(() => _selectedSex = 'female'),
                  theme: theme,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Age
          _buildNumberInput(
            label: 'Idade',
            value: _age.toDouble(),
            unit: 'anos',
            min: 10,
            max: 100,
            onChanged: (value) => setState(() => _age = value.toInt()),
            theme: theme,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 24),

          // Height
          _buildNumberInput(
            label: 'Altura',
            value: _height,
            unit: 'cm',
            min: 100,
            max: 250,
            onChanged: (value) => setState(() => _height = value),
            theme: theme,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 24),

          // Weight
          _buildNumberInput(
            label: 'Peso',
            value: _weight,
            unit: 'kg',
            min: 30,
            max: 200,
            decimals: 1,
            onChanged: (value) => setState(() => _weight = value),
            theme: theme,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 24),

          // Body fat (optional)
          Text(
            'Percentual de Gordura Corporal (opcional)',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Necessário apenas para a fórmula Katch-McArdle',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Ex: 20',
              suffix: Text('%', style: TextStyle(color: textColor)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppTheme.primaryColor),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              setState(() => _bodyFat = parsed);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelStep(ThemeData theme, bool isDarkMode, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.directions_run,
            title: 'Nível de Atividade',
            subtitle: 'Como você se mantém ativo no dia a dia?',
            theme: theme,
            textColor: textColor,
          ),
          const SizedBox(height: 32),

          ...ActivityLevel.values.map((level) {
            final provider = Provider.of<NutritionGoalsProvider>(context, listen: false);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildOptionCard(
                title: provider.getActivityLevelName(level),
                subtitle: provider.getActivityLevelDescription(level),
                isSelected: _selectedActivityLevel == level,
                onTap: () => setState(() => _selectedActivityLevel = level),
                theme: theme,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFitnessGoalStep(ThemeData theme, bool isDarkMode, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.track_changes,
            title: 'Seu Objetivo',
            subtitle: 'O que você deseja alcançar?',
            theme: theme,
            textColor: textColor,
          ),
          const SizedBox(height: 32),

          ...FitnessGoal.values.map((goal) {
            final provider = Provider.of<NutritionGoalsProvider>(context, listen: false);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildOptionCard(
                title: provider.getFitnessGoalName(goal),
                subtitle: _getGoalDescription(goal),
                isSelected: _selectedFitnessGoal == goal,
                onTap: () => setState(() => _selectedFitnessGoal = goal),
                theme: theme,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDietTypeStep(ThemeData theme, bool isDarkMode, Color textColor) {
    final provider = Provider.of<NutritionGoalsProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.restaurant_menu,
            title: 'Tipo de Dieta',
            subtitle: 'Escolha o tipo de dieta que melhor se adapta a você',
            theme: theme,
            textColor: textColor,
          ),
          const SizedBox(height: 32),

          ...DietType.values.map((dietType) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildOptionCard(
                title: provider.getDietTypeName(dietType),
                subtitle: provider.getDietTypeDescription(dietType),
                isSelected: _selectedDietType == dietType,
                onTap: () {
                  setState(() => _selectedDietType = dietType);

                  // If custom is selected, open the macro edit dialog
                  if (dietType == DietType.custom) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _showCustomMacroDialog(theme, isDarkMode, textColor);
                    });
                  }
                },
                theme: theme,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : textColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? AppTheme.primaryColor : textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    int decimals = 0,
    required Function(double) onChanged,
    required ThemeData theme,
    required Color textColor,
    required bool isDarkMode,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  final newValue = value - (decimals > 0 ? 0.5 : 1);
                  if (newValue >= min) onChanged(newValue);
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: AppTheme.primaryColor,
                iconSize: 32,
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    decimals > 0 ? value.toStringAsFixed(decimals) : value.toStringAsFixed(0),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    unit,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  final newValue = value + (decimals > 0 ? 0.5 : 1);
                  if (newValue <= max) onChanged(newValue);
                },
                icon: const Icon(Icons.add_circle_outline),
                color: AppTheme.primaryColor,
                iconSize: 32,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * (decimals > 0 ? 2 : 1)).toInt(),
            activeColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected ? AppTheme.primaryColor : textColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme, bool isDarkMode, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0 && !widget.fromProfile)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: textColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Voltar',
                  style: TextStyle(color: textColor),
                ),
              ),
            ),
          if (_currentStep > 0 && !widget.fromProfile) const SizedBox(width: 12),
          Expanded(
            flex: (_currentStep == 0 || widget.fromProfile) ? 1 : 2,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.fromProfile
                    ? 'Salvar'
                    : (_currentStep == 3 ? 'Concluir' : 'Próximo'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGoalDescription(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return 'Déficit calórico de 500 kcal/dia';
      case FitnessGoal.maintainWeight:
        return 'Manter peso atual';
      case FitnessGoal.gainWeight:
        return 'Superávit calórico de 300 kcal/dia';
      case FitnessGoal.gainMuscle:
        return 'Superávit calórico de 500 kcal/dia';
    }
  }

  void _showCustomMacroDialog(ThemeData theme, bool isDarkMode, Color textColor) {
    final provider = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    showDialog(
      context: context,
      builder: (context) => _MacroEditDialog(
        provider: provider,
        theme: theme,
        isDarkMode: isDarkMode,
        textColor: textColor,
        cardColor: cardColor,
      ),
    );
  }
}

// Dialog widget for editing macronutrients (reused from nutrition_goals_screen)
class _MacroEditDialog extends StatefulWidget {
  final NutritionGoalsProvider provider;
  final ThemeData theme;
  final bool isDarkMode;
  final Color textColor;
  final Color cardColor;

  const _MacroEditDialog({
    required this.provider,
    required this.theme,
    required this.isDarkMode,
    required this.textColor,
    required this.cardColor,
  });

  @override
  State<_MacroEditDialog> createState() => _MacroEditDialogState();
}

class _MacroEditDialogState extends State<_MacroEditDialog> {
  bool _usePercentage = true;

  // Percentage mode
  late double _carbsPercentage;
  late double _proteinPercentage;
  late double _fatPercentage;

  // Grams mode
  late double _carbsGrams;
  late double _proteinGrams;
  late double _fatGrams;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize percentages
    _carbsPercentage = widget.provider.carbsPercentage.toDouble();
    _proteinPercentage = widget.provider.proteinPercentage.toDouble();
    _fatPercentage = widget.provider.fatPercentage.toDouble();

    // Initialize grams
    _carbsGrams = widget.provider.carbsGoal.toDouble();
    _proteinGrams = widget.provider.proteinGoal.toDouble();
    _fatGrams = widget.provider.fatGoal.toDouble();
  }

  void _validateAndUpdate() {
    if (_usePercentage) {
      _validatePercentages();
    } else {
      _validateGrams();
    }
  }

  void _validatePercentages() {
    final total = _carbsPercentage + _proteinPercentage + _fatPercentage;

    if ((total - 100).abs() > 0.1) {
      setState(() {
        _errorMessage = 'A soma das porcentagens deve ser 100% (atual: ${total.toStringAsFixed(0)}%)';
      });
      return;
    }

    // Update provider
    widget.provider.updateMacroPercentages(
      carbs: _carbsPercentage.round(),
      protein: _proteinPercentage.round(),
      fat: _fatPercentage.round(),
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Macronutrientes personalizados com sucesso!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _validateGrams() {
    final totalCalories = widget.provider.caloriesGoal;

    // Calculate calories from grams
    double carbsCalories = _carbsGrams * 4;
    double proteinCalories = _proteinGrams * 4;
    double fatCalories = _fatGrams * 9;
    double totalFromMacros = carbsCalories + proteinCalories + fatCalories;

    // Allow 1% tolerance (stricter validation)
    final difference = (totalFromMacros - totalCalories).abs();
    final tolerance = totalCalories * 0.01;

    if (difference > tolerance) {
      setState(() {
        _errorMessage = 'Total de calorias dos macros (${totalFromMacros.toStringAsFixed(0)}) deve ser igual à meta (${totalCalories} kcal). Use o botão "Ajustar" abaixo.';
      });
      return;
    }

    // Auto-adjust if there's a small difference (within tolerance)
    if (totalFromMacros != totalCalories && totalFromMacros > 0) {
      final factor = totalCalories / totalFromMacros;
      carbsCalories = _carbsGrams * 4 * factor;
      proteinCalories = _proteinGrams * 4 * factor;
      fatCalories = _fatGrams * 9 * factor;
      totalFromMacros = carbsCalories + proteinCalories + fatCalories;
    }

    // Calculate percentages from adjusted calories
    final carbsPercentage = ((carbsCalories / totalCalories) * 100).round();
    final proteinPercentage = ((proteinCalories / totalCalories) * 100).round();
    final fatPercentage = 100 - carbsPercentage - proteinPercentage;

    // Update provider
    widget.provider.updateMacroPercentages(
      carbs: carbsPercentage,
      protein: proteinPercentage,
      fat: fatPercentage,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Macronutrientes personalizados com sucesso!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _autoAdjust() {
    if (!_usePercentage) return;

    final total = _carbsPercentage + _proteinPercentage + _fatPercentage;

    if (total == 0) return;

    // Normalize to 100%
    setState(() {
      _carbsPercentage = (_carbsPercentage / total * 100);
      _proteinPercentage = (_proteinPercentage / total * 100);
      _fatPercentage = (_fatPercentage / total * 100);
      _errorMessage = null;
    });
  }

  void _autoAdjustGrams() {
    if (_usePercentage) return;

    final targetCalories = widget.provider.caloriesGoal;

    // Calculate current total calories
    final carbsCalories = _carbsGrams * 4;
    final proteinCalories = _proteinGrams * 4;
    final fatCalories = _fatGrams * 9;
    final totalCalories = carbsCalories + proteinCalories + fatCalories;

    if (totalCalories == 0) return;

    // Calculate proportional adjustment factor
    final factor = targetCalories / totalCalories;

    // Adjust all macros proportionally
    setState(() {
      _carbsGrams = (_carbsGrams * factor);
      _proteinGrams = (_proteinGrams * factor);
      _fatGrams = (_fatGrams * factor);
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPercentage = _carbsPercentage + _proteinPercentage + _fatPercentage;
    final isValid = (totalPercentage - 100).abs() < 0.1;

    return AlertDialog(
      backgroundColor: widget.cardColor,
      title: Text(
        'Personalizar Macronutrientes',
        style: TextStyle(color: widget.textColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle between percentage and grams
            Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.grey[800]
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Porcentagem',
                      isSelected: _usePercentage,
                      onTap: () => setState(() => _usePercentage = true),
                    ),
                  ),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Gramas',
                      isSelected: !_usePercentage,
                      onTap: () => setState(() => _usePercentage = false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_usePercentage) ...[
              // Percentage mode
              Text(
                'Meta de calorias: ${widget.provider.caloriesGoal} kcal',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              _buildPercentageSlider(
                label: 'Carboidratos',
                value: _carbsPercentage,
                color: const Color(0xFFA1887F),
                icon: Icons.grain,
                onChanged: (value) {
                  setState(() {
                    _carbsPercentage = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildPercentageSlider(
                label: 'Proteína',
                value: _proteinPercentage,
                color: const Color(0xFF9575CD),
                icon: Icons.fitness_center,
                onChanged: (value) {
                  setState(() {
                    _proteinPercentage = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildPercentageSlider(
                label: 'Gorduras',
                value: _fatPercentage,
                color: const Color(0xFF90A4AE),
                icon: Icons.water_drop,
                onChanged: (value) {
                  setState(() {
                    _fatPercentage = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Total display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isValid
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isValid ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: widget.theme.textTheme.bodyLarge?.copyWith(
                        color: widget.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${totalPercentage.toStringAsFixed(0)}%',
                          style: widget.theme.textTheme.bodyLarge?.copyWith(
                            color: isValid ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isValid) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _autoAdjust,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Ajustar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Grams mode
              Text(
                'Meta de calorias: ${widget.provider.caloriesGoal} kcal',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              _buildGramsInput(
                label: 'Carboidratos',
                value: _carbsGrams,
                color: const Color(0xFFA1887F),
                icon: Icons.grain,
                caloriesPerGram: 4,
                onChanged: (value) {
                  setState(() {
                    _carbsGrams = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildGramsInput(
                label: 'Proteína',
                value: _proteinGrams,
                color: const Color(0xFF9575CD),
                icon: Icons.fitness_center,
                caloriesPerGram: 4,
                onChanged: (value) {
                  setState(() {
                    _proteinGrams = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildGramsInput(
                label: 'Gorduras',
                value: _fatGrams,
                color: const Color(0xFF90A4AE),
                icon: Icons.water_drop,
                caloriesPerGram: 9,
                onChanged: (value) {
                  setState(() {
                    _fatGrams = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Total calories from macros
              _buildCaloriesSummary(),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: widget.textColor.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _validateAndUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : widget.textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPercentageSlider({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    final calories = (widget.provider.caloriesGoal * (value / 100)).round();
    final grams = label == 'Gorduras'
        ? (calories / 9).round()
        : (calories / 4).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(0)}% (${grams}g)',
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildGramsInput({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    required int caloriesPerGram,
    required ValueChanged<double> onChanged,
  }) {
    final calories = (value * caloriesPerGram).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: widget.textColor),
                decoration: InputDecoration(
                  suffixText: 'g',
                  hintText: value.toStringAsFixed(0),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.textColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (text) {
                  final parsed = double.tryParse(text);
                  if (parsed != null) {
                    onChanged(parsed);
                  }
                },
                controller: TextEditingController(
                  text: value.toStringAsFixed(0),
                )..selection = TextSelection.collapsed(
                  offset: value.toStringAsFixed(0).length,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${calories} kcal',
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaloriesSummary() {
    final carbsCalories = _carbsGrams * 4;
    final proteinCalories = _proteinGrams * 4;
    final fatCalories = _fatGrams * 9;
    final totalCalories = carbsCalories + proteinCalories + fatCalories;
    final targetCalories = widget.provider.caloriesGoal;
    final difference = (totalCalories - targetCalories).abs();
    final isClose = difference <= targetCalories * 0.01;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClose
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isClose ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total dos macros:',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor,
                ),
              ),
              Text(
                '${totalCalories.toStringAsFixed(0)} kcal',
                style: widget.theme.textTheme.bodyLarge?.copyWith(
                  color: isClose ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meta:',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '$targetCalories kcal',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          if (!isClose) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diferença: ${difference.toStringAsFixed(0)} kcal',
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: _autoAdjustGrams,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Ajustar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


