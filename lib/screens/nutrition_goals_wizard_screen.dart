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

          ...DietType.values.where((type) => type != DietType.custom).map((dietType) {
            final provider = Provider.of<NutritionGoalsProvider>(context, listen: false);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildOptionCard(
                title: provider.getDietTypeName(dietType),
                subtitle: provider.getDietTypeDescription(dietType),
                isSelected: _selectedDietType == dietType,
                onTap: () => setState(() => _selectedDietType = dietType),
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

}
