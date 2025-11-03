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
  double _weight = 70.0; // Always stored in kg internally
  double _height = 170.0; // Always stored in cm internally

  // Text controllers for inputs
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _weightPoundsController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // Step 1: Activity & Goal
  ActivityLevel _selectedActivityLevel = ActivityLevel.moderatelyActive;
  FitnessGoal _selectedFitnessGoal = FitnessGoal.maintainWeight;

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
        _selectedActivityLevel = provider.activityLevel;
        _selectedFitnessGoal = provider.fitnessGoal;

        // Initialize text controllers based on current units
        _ageController.text = _age.toString();
        _updateHeightController(provider);
        _updateWeightController(provider);
      });
    });
  }

  void _updateHeightController(NutritionGoalsProvider provider) {
    if (provider.heightUnit == HeightUnit.cm) {
      _heightController.text = _height.toStringAsFixed(0);
      _heightInchesController.clear();
    } else {
      final heightData = provider.heightInFeet();
      _heightController.text = heightData['feet'].toString();
      _heightInchesController.text = heightData['inches'].toString();
    }
  }

  void _updateWeightController(NutritionGoalsProvider provider) {
    switch (provider.weightUnit) {
      case WeightUnit.kg:
        _weightController.text = _weight.toStringAsFixed(1);
        _weightPoundsController.clear();
        break;
      case WeightUnit.lbs:
        _weightController.text = provider.weightInLbs().toStringAsFixed(1);
        _weightPoundsController.clear();
        break;
      case WeightUnit.stLbs:
        final weightData = provider.weightInStLbs();
        _weightController.text = weightData['stone'].toString();
        _weightPoundsController.text = weightData['pounds'].toString();
        break;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _weightPoundsController.dispose();
    _ageController.dispose();
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

    if (_currentStep < 2) {
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
        );
        break;
      case 1:
        // Save activity level
        provider.updateActivityAndGoals(
          activityLevel: _selectedActivityLevel,
        );
        break;
      case 2:
        // Save fitness goal e define diet type padrão (balanced)
        provider.updateActivityAndGoals(
          fitnessGoal: _selectedFitnessGoal,
        );
        provider.updateDietType(DietType.balanced);
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
        children: List.generate(3, (index) {
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
                if (index < 2) const SizedBox(width: 4),
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
          _buildAgeInput(theme, textColor, isDarkMode),
          const SizedBox(height: 24),

          // Height
          Consumer<NutritionGoalsProvider>(
            builder: (context, provider, child) {
              return _buildHeightInput(theme, textColor, isDarkMode, provider);
            },
          ),
          const SizedBox(height: 24),

          // Weight
          Consumer<NutritionGoalsProvider>(
            builder: (context, provider, child) {
              return _buildWeightInput(theme, textColor, isDarkMode, provider);
            },
          ),
          const SizedBox(height: 24),
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
                title: provider.getActivityLevelName(level, context),
                subtitle: provider.getActivityLevelDescription(level, context),
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
            icon: Icons.center_focus_strong,
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
                title: provider.getFitnessGoalName(goal, context),
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

  Widget _buildAgeInput(ThemeData theme, Color textColor, bool isDarkMode) {
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
            'Idade',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (value) {
                    final age = int.tryParse(value);
                    if (age != null && age >= 10 && age <= 100) {
                      setState(() => _age = age);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'anos',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeightInput(ThemeData theme, Color textColor, bool isDarkMode, NutritionGoalsProvider provider) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final isCm = provider.heightUnit == HeightUnit.cm;

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
            'Altura',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isCm) ...[
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (value) {
                      final height = double.tryParse(value);
                      if (height != null && height >= 100 && height <= 250) {
                        setState(() => _height = height);
                      }
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixText: "'",
                      suffixStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    onChanged: (value) {
                      final feet = int.tryParse(value) ?? 0;
                      final inches = int.tryParse(_heightInchesController.text) ?? 0;
                      final heightCm = NutritionGoalsProvider.heightToCm(feet, inches);
                      if (heightCm >= 100 && heightCm <= 250) {
                        setState(() => _height = heightCm);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _heightInchesController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixText: '"',
                      suffixStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    onChanged: (value) {
                      final feet = int.tryParse(_heightController.text) ?? 0;
                      final inches = int.tryParse(value) ?? 0;
                      final heightCm = NutritionGoalsProvider.heightToCm(feet, inches);
                      if (heightCm >= 100 && heightCm <= 250) {
                        setState(() => _height = heightCm);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  provider.toggleHeightUnit();
                  _updateHeightController(provider);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCm ? 'cm' : 'ft',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput(ThemeData theme, Color textColor, bool isDarkMode, NutritionGoalsProvider provider) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final String unitLabel;
    final bool showSecondField = provider.weightUnit == WeightUnit.stLbs;

    switch (provider.weightUnit) {
      case WeightUnit.kg:
        unitLabel = 'kg';
        break;
      case WeightUnit.lbs:
        unitLabel = 'lbs';
        break;
      case WeightUnit.stLbs:
        unitLabel = 'st & lbs';
        break;
    }

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
            'Peso',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!showSecondField) ...[
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (value) {
                      final weight = double.tryParse(value);
                      if (weight != null) {
                        if (provider.weightUnit == WeightUnit.kg) {
                          if (weight >= 30 && weight <= 200) {
                            setState(() => _weight = weight);
                          }
                        } else if (provider.weightUnit == WeightUnit.lbs) {
                          final weightKg = NutritionGoalsProvider.weightToKg(weight);
                          if (weightKg >= 30 && weightKg <= 200) {
                            setState(() => _weight = weightKg);
                          }
                        }
                      }
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixText: 'st',
                      suffixStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    onChanged: (value) {
                      final stone = int.tryParse(value) ?? 0;
                      final pounds = int.tryParse(_weightPoundsController.text) ?? 0;
                      final weightKg = NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
                      if (weightKg >= 30 && weightKg <= 200) {
                        setState(() => _weight = weightKg);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _weightPoundsController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixText: 'lbs',
                      suffixStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                    onChanged: (value) {
                      final stone = int.tryParse(_weightController.text) ?? 0;
                      final pounds = int.tryParse(value) ?? 0;
                      final weightKg = NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
                      if (weightKg >= 30 && weightKg <= 200) {
                        setState(() => _weight = weightKg);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  provider.toggleWeightUnit();
                  _updateWeightController(provider);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unitLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
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
                    : (_currentStep == 2 ? 'Concluir' : 'Próximo'),
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
        return 'Diminuir os requisitos calóricos em 20 %';
      case FitnessGoal.loseWeightSlowly:
        return 'Diminuir os requisitos calóricos em 10 %';
      case FitnessGoal.maintainWeight:
        return 'Não alterar os requisitos calóricos';
      case FitnessGoal.gainWeightSlowly:
        return 'Aumentar os requisitos calóricos em 10 %';
      case FitnessGoal.gainWeight:
        return 'Aumentar os requisitos calóricos em 20 %';
    }
  }
}
