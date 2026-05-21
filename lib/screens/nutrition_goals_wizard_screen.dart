import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../utils/ui_utils.dart';

class NutritionGoalsWizardScreen extends StatefulWidget {
  final int startStep;
  final bool fromProfile;

  const NutritionGoalsWizardScreen({
    Key? key,
    this.startStep = 0,
    this.fromProfile = false,
  }) : super(key: key);

  @override
  State<NutritionGoalsWizardScreen> createState() =>
      _NutritionGoalsWizardScreenState();
}

class _NutritionGoalsWizardScreenState
    extends State<NutritionGoalsWizardScreen> {
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

  Color _accentColor(ThemeData theme) => theme.colorScheme.primary;
  Color _onAccentColor(ThemeData theme) => theme.colorScheme.onPrimary;
  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);
  Color _inputFillColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;
  Color _subtleBorderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white12 : Colors.black12;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.startStep;
    _pageController = PageController(initialPage: widget.startStep);

    // Load current values from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<NutritionGoalsProvider>(context, listen: false);
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
    final provider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);

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
    final provider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
    final navigatorContext = Navigator.of(context).context;

    // Ensure calculated mode is enabled
    provider.setUseCalculatedGoals(true);
    provider.syncPendingIfNeeded();

    final successMessage = provider.hasPendingServerSync
        ? context.tr.translate('goals_saved_locally_pending_sync')
        : context.tr.translate('goals_configured_successfully');

    Navigator.pop(context);
    UIUtils.showPrimarySnackBar(navigatorContext, successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalHeader(theme, isDarkMode, textColor),
            _buildProgressIndicator(theme, isDarkMode, textColor),
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
            _buildNavigationButtons(theme, isDarkMode, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalHeader(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.close,
                color: textColor,
              ),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text(
                  context.tr.translate('configure_goals'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _surfaceColor(isDarkMode),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _subtleBorderColor(isDarkMode)),
                ),
                child: Text(
                  '${_currentStep + 1}/3',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? _accentColor(theme)
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

  Widget _buildPersonalInfoStep(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return _buildStepBody(
      header: _buildStepHeader(
        icon: Icons.person_outline,
        title: context.tr.translate('personal_info_title'),
        subtitle: context.tr.translate('personal_info_subtitle'),
        theme: theme,
        isDarkMode: isDarkMode,
        textColor: textColor,
      ),
      children: [
        Text(
          context.tr.translate('sex'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectableCard(
                icon: Icons.male,
                label: context.tr.translate('male'),
                isSelected: _selectedSex == 'male',
                onTap: () => setState(() => _selectedSex = 'male'),
                theme: theme,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSelectableCard(
                icon: Icons.female,
                label: context.tr.translate('female'),
                isSelected: _selectedSex == 'female',
                onTap: () => setState(() => _selectedSex = 'female'),
                theme: theme,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAgeInput(theme, textColor, isDarkMode),
        const SizedBox(height: 12),
        Consumer<NutritionGoalsProvider>(
          builder: (context, provider, child) {
            return _buildHeightInput(theme, textColor, isDarkMode, provider);
          },
        ),
        const SizedBox(height: 12),
        Consumer<NutritionGoalsProvider>(
          builder: (context, provider, child) {
            return _buildWeightInput(theme, textColor, isDarkMode, provider);
          },
        ),
      ],
    );
  }

  Widget _buildActivityLevelStep(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return _buildStepBody(
      header: _buildStepHeader(
        icon: Icons.directions_run,
        title: context.tr.translate('activity_level'),
        subtitle: context.tr.translate('activity_level_subtitle'),
        theme: theme,
        isDarkMode: isDarkMode,
        textColor: textColor,
      ),
      children: ActivityLevel.values.map((level) {
        final provider =
            Provider.of<NutritionGoalsProvider>(context, listen: false);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildOptionCard(
            icon: _getActivityIcon(level),
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
    );
  }

  Widget _buildFitnessGoalStep(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return _buildStepBody(
      header: _buildStepHeader(
        icon: Icons.flag_outlined,
        title: context.tr.translate('your_goal'),
        subtitle: context.tr.translate('your_goal_subtitle'),
        theme: theme,
        isDarkMode: isDarkMode,
        textColor: textColor,
      ),
      children: FitnessGoal.values.map((goal) {
        final provider =
            Provider.of<NutritionGoalsProvider>(context, listen: false);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildOptionCard(
            icon: _getFitnessGoalIcon(goal),
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
    );
  }

  Widget _buildStepBody({
    required Widget header,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _surfaceColor(isDarkMode),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _subtleBorderColor(isDarkMode)),
          ),
          child: Icon(
            icon,
            color: textColor.withValues(alpha: 0.82),
            size: 22,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.getSoftTextColor(isDarkMode),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: textColor.withValues(alpha: 0.62),
            height: 1.35,
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
    final accentColor = _accentColor(theme);
    final selectedForeground = _onAccentColor(theme);
    final foregroundColor = isSelected ? selectedForeground : textColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? accentColor : _subtleBorderColor(isDarkMode),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: foregroundColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _numberInputDecoration({
    required ThemeData theme,
    required bool isDarkMode,
    String? suffixText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: _subtleBorderColor(isDarkMode)),
    );

    return InputDecoration(
      filled: true,
      fillColor: _inputFillColor(isDarkMode),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: _accentColor(theme),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      suffixText: suffixText,
      suffixStyle: theme.textTheme.bodyMedium?.copyWith(
        color: (isDarkMode ? Colors.white : AppTheme.textPrimaryColor)
            .withValues(alpha: 0.58),
      ),
    );
  }

  Widget _buildUnitToggle({
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        constraints: const BoxConstraints(minWidth: 58, minHeight: 46),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _subtleBorderColor(isDarkMode)),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAgeInput(ThemeData theme, Color textColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('age'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  decoration: _numberInputDecoration(
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                  onChanged: (value) {
                    final age = int.tryParse(value);
                    if (age != null && age >= 10 && age <= 100) {
                      setState(() => _age = age);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.tr.translate('years'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeightInput(ThemeData theme, Color textColor, bool isDarkMode,
      NutritionGoalsProvider provider) {
    final isCm = provider.heightUnit == HeightUnit.cm;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('height'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isCm) ...[
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
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
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: "'",
                    ),
                    onChanged: (value) {
                      final feet = int.tryParse(value) ?? 0;
                      final inches =
                          int.tryParse(_heightInchesController.text) ?? 0;
                      final heightCm =
                          NutritionGoalsProvider.heightToCm(feet, inches);
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
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: '"',
                    ),
                    onChanged: (value) {
                      final feet = int.tryParse(_heightController.text) ?? 0;
                      final inches = int.tryParse(value) ?? 0;
                      final heightCm =
                          NutritionGoalsProvider.heightToCm(feet, inches);
                      if (heightCm >= 100 && heightCm <= 250) {
                        setState(() => _height = heightCm);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 12),
              _buildUnitToggle(
                label: isCm ? 'cm' : 'ft',
                onTap: () {
                  provider.toggleHeightUnit();
                  _updateHeightController(provider);
                },
                theme: theme,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput(ThemeData theme, Color textColor, bool isDarkMode,
      NutritionGoalsProvider provider) {
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('weight'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!showSecondField) ...[
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                    ),
                    onChanged: (value) {
                      final weight = double.tryParse(value);
                      if (weight != null) {
                        if (provider.weightUnit == WeightUnit.kg) {
                          if (weight >= 30 && weight <= 200) {
                            setState(() => _weight = weight);
                          }
                        } else if (provider.weightUnit == WeightUnit.lbs) {
                          final weightKg =
                              NutritionGoalsProvider.weightToKg(weight);
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
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: 'st',
                    ),
                    onChanged: (value) {
                      final stone = int.tryParse(value) ?? 0;
                      final pounds =
                          int.tryParse(_weightPoundsController.text) ?? 0;
                      final weightKg =
                          NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
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
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: 'lbs',
                    ),
                    onChanged: (value) {
                      final stone = int.tryParse(_weightController.text) ?? 0;
                      final pounds = int.tryParse(value) ?? 0;
                      final weightKg =
                          NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
                      if (weightKg >= 30 && weightKg <= 200) {
                        setState(() => _weight = weightKg);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 12),
              _buildUnitToggle(
                label: unitLabel,
                onTap: () {
                  provider.toggleWeightUnit();
                  _updateWeightController(provider);
                },
                theme: theme,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final accentColor = _accentColor(theme);
    final selectedForeground = _onAccentColor(theme);
    final foregroundColor = isSelected ? selectedForeground : textColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? accentColor : _subtleBorderColor(isDarkMode),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedForeground.withValues(alpha: 0.12)
                    : _inputFillColor(isDarkMode),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected
                      ? selectedForeground.withValues(alpha: 0.18)
                      : _subtleBorderColor(isDarkMode),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: foregroundColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.64),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked_rounded,
              color: foregroundColor.withValues(alpha: isSelected ? 1 : 0.35),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkBackgroundColor
            : AppTheme.backgroundColor,
      ),
      child: Row(
        children: [
          if (_currentStep > 0 && !widget.fromProfile)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  backgroundColor: _surfaceColor(isDarkMode),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: _subtleBorderColor(isDarkMode)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, size: 18, color: textColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tr.translate('back'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_currentStep > 0 && !widget.fromProfile)
            const SizedBox(width: 12),
          Expanded(
            flex: (_currentStep == 0 || widget.fromProfile) ? 1 : 2,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor(theme),
                foregroundColor: _onAccentColor(theme),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.fromProfile
                          ? context.tr.translate('save')
                          : (_currentStep == 2
                              ? context.tr.translate('finish')
                              : context.tr.translate('next')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    widget.fromProfile || _currentStep == 2
                        ? Icons.check
                        : Icons.arrow_forward,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return Icons.weekend_outlined;
      case ActivityLevel.lightlyActive:
        return Icons.directions_walk;
      case ActivityLevel.moderatelyActive:
        return Icons.directions_run;
      case ActivityLevel.veryActive:
        return Icons.fitness_center;
      case ActivityLevel.extremelyActive:
        return Icons.local_fire_department_outlined;
    }
  }

  IconData _getFitnessGoalIcon(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return Icons.trending_down;
      case FitnessGoal.loseWeightSlowly:
        return Icons.south_east;
      case FitnessGoal.maintainWeight:
        return Icons.balance_outlined;
      case FitnessGoal.gainWeightSlowly:
        return Icons.north_east;
      case FitnessGoal.gainWeight:
        return Icons.trending_up;
    }
  }

  String _getGoalDescription(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return context.tr.translate('goal_desc_lose_weight');
      case FitnessGoal.loseWeightSlowly:
        return context.tr.translate('goal_desc_lose_weight_slowly');
      case FitnessGoal.maintainWeight:
        return context.tr.translate('goal_desc_maintain_weight');
      case FitnessGoal.gainWeightSlowly:
        return context.tr.translate('goal_desc_gain_weight_slowly');
      case FitnessGoal.gainWeight:
        return context.tr.translate('goal_desc_gain_weight');
    }
  }
}
