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
  static const int _profileStep = 0;
  static const int _activityStep = 1;
  static const int _goalStep = 2;
  static const int _stepCount = 3;

  late int _currentStep;
  late PageController _pageController;

  // Personal info state
  String _selectedSex = '';
  int _age = 30;
  double _weight = 70.0; // Always stored in kg internally
  double _height = 170.0; // Always stored in cm internally
  bool _hasFilledAge = false;
  bool _hasFilledHeight = false;
  bool _hasFilledWeight = false;

  // Text controllers for inputs
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _heightInchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _weightPoundsController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final FocusNode _ageFocusNode = FocusNode();
  final FocusNode _heightFocusNode = FocusNode();
  final FocusNode _heightInchesFocusNode = FocusNode();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _weightPoundsFocusNode = FocusNode();

  // Activity and goal state
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
    for (final node in [
      _ageFocusNode,
      _heightFocusNode,
      _heightInchesFocusNode,
      _weightFocusNode,
      _weightPoundsFocusNode,
    ]) {
      node.addListener(_handleProfileInputFocusChanged);
    }

    final initialStep = _resolveInitialStep(widget.startStep);
    _currentStep = initialStep;
    _pageController = PageController(initialPage: initialStep);

    // Load current values from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<NutritionGoalsProvider>(context, listen: false);
      setState(() {
        _selectedSex = provider.hasExplicitSex ? provider.sex : '';
        _age = provider.age;
        _weight = provider.weight;
        _height = provider.height;
        _selectedActivityLevel = provider.activityLevel;
        _selectedFitnessGoal = provider.fitnessGoal;
        _hasFilledAge = provider.hasExplicitAge;
        _hasFilledHeight = provider.hasExplicitHeight;
        _hasFilledWeight = provider.hasExplicitWeight;

        // Initialize text controllers based on current units
        _ageController.text = provider.hasExplicitAge ? _age.toString() : '';
        if (provider.hasExplicitHeight) {
          _updateHeightController(provider);
        } else {
          _heightController.clear();
          _heightInchesController.clear();
        }
        if (provider.hasExplicitWeight) {
          _updateWeightController(provider);
        } else {
          _weightController.clear();
          _weightPoundsController.clear();
        }
      });
    });
  }

  int _resolveInitialStep(int startStep) {
    switch (startStep) {
      case 1:
        return _activityStep;
      case 2:
        return _goalStep;
      case 0:
      default:
        return _profileStep;
    }
  }

  bool get _isLastStep => _currentStep == _goalStep;
  bool get _isProfilePersonalInfoFlow =>
      widget.fromProfile && widget.startStep == 0;
  bool get _isSingleEditMode =>
      widget.fromProfile && !_isProfilePersonalInfoFlow;
  bool get _hasSelectedSex =>
      _selectedSex == 'male' || _selectedSex == 'female';
  bool get _isProfileStepComplete =>
      _hasSelectedSex && _hasFilledAge && _hasFilledHeight && _hasFilledWeight;
  bool get _canContinueCurrentStep =>
      _currentStep != _profileStep || _isProfileStepComplete;
  bool get _isAgeInputActive => _ageFocusNode.hasFocus;
  bool get _isHeightInputActive =>
      _heightFocusNode.hasFocus || _heightInchesFocusNode.hasFocus;
  bool get _isWeightInputActive =>
      _weightFocusNode.hasFocus || _weightPoundsFocusNode.hasFocus;

  void _handleProfileInputFocusChanged() {
    if (mounted) setState(() {});
  }

  String _translateOrFallback(String key, String fallback) {
    final translated = context.tr.translate(key);
    return translated == key ? fallback : translated;
  }

  Color _profileInputColor({
    required ThemeData theme,
    required bool isDarkMode,
    required bool isActive,
    required bool hasValue,
  }) {
    if (isActive || hasValue) {
      return _accentColor(theme).withValues(alpha: isDarkMode ? 0.22 : 0.11);
    }

    return isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFF5F7FA);
  }

  bool get _shouldFinishAfterCurrentStep {
    if (_isSingleEditMode) return true;
    if (_isProfilePersonalInfoFlow) return _currentStep == _profileStep;
    return _isLastStep;
  }

  bool get _canGoBack {
    if (_isSingleEditMode) return false;
    if (_isProfilePersonalInfoFlow) return false;
    return _currentStep > _profileStep;
  }

  double get _progressValue {
    if (_isSingleEditMode) return 1.0;
    if (_isProfilePersonalInfoFlow) return 1.0;
    return ((_currentStep + 1) / _stepCount).clamp(0.0, 1.0).toDouble();
  }

  void _updateHeightController(NutritionGoalsProvider provider) {
    if (provider.heightUnit == HeightUnit.cm) {
      _heightController.text = _height.toStringAsFixed(0);
      _heightInchesController.clear();
    } else {
      final totalInches = (_height / 2.54).round();
      _heightController.text = (totalInches ~/ 12).toString();
      _heightInchesController.text = (totalInches % 12).toString();
    }
  }

  void _updateWeightController(NutritionGoalsProvider provider) {
    switch (provider.weightUnit) {
      case WeightUnit.kg:
        _weightController.text = _weight.toStringAsFixed(1);
        _weightPoundsController.clear();
        break;
      case WeightUnit.lbs:
        _weightController.text = (_weight * 2.20462).toStringAsFixed(1);
        _weightPoundsController.clear();
        break;
      case WeightUnit.stLbs:
        final totalLbs = (_weight * 2.20462).round();
        _weightController.text = (totalLbs ~/ 14).toString();
        _weightPoundsController.text = (totalLbs % 14).toString();
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
    _ageFocusNode.dispose();
    _heightFocusNode.dispose();
    _heightInchesFocusNode.dispose();
    _weightFocusNode.dispose();
    _weightPoundsFocusNode.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Save current step data before moving forward
    _saveCurrentStep();

    if (_shouldFinishAfterCurrentStep) {
      _saveAndFinish();
      return;
    }

    setState(() => _currentStep++);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _saveCurrentStep() {
    final provider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);

    switch (_currentStep) {
      case _profileStep:
        provider.updatePersonalInfo(
          sex: _selectedSex,
          age: _age,
          height: _height,
          weight: _weight,
        );
        break;
      case _activityStep:
        provider.updateActivityAndGoals(
          activityLevel: _selectedActivityLevel,
        );
        break;
      case _goalStep:
        provider.updateActivityAndGoals(
          fitnessGoal: _selectedFitnessGoal,
        );
        provider.updateDietType(DietType.aiRecommended);
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

  void _skipSetup() {
    Navigator.pop(context);
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
    final textColor = isDarkMode ? Colors.white : Colors.black;
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
                  _buildPersonalProfileStep(theme, isDarkMode, textColor),
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
    final progressBackground =
        isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.black12;

    final showProfileBadge = _currentStep == _profileStep;

    return SizedBox(
      height: showProfileBadge ? 86 : 58,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
        child: Column(
          children: [
            if (showProfileBadge)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 0, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildProfileBadgeHeader(theme: theme),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: _accentColor(theme),
                    size: 30,
                  ),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      minHeight: 8,
                      backgroundColor: progressBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _accentColor(theme),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _skipSetup,
                  style: TextButton.styleFrom(
                    foregroundColor: _accentColor(theme),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.tr.translate('skip_setup'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return const SizedBox(height: 8);
  }

  Widget _buildPersonalProfileStep(
      ThemeData theme, bool isDarkMode, Color textColor) {
    return _buildStepBody(
      header: null,
      children: [
        _buildProfileQuestion(
          context.tr.translate('goal_setup_sex_title'),
          theme: theme,
          textColor: textColor,
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildProfileChoicePill(
                label: context.tr.translate('male'),
                isSelected: _selectedSex == 'male',
                onTap: () => setState(() => _selectedSex = 'male'),
                theme: theme,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
              const SizedBox(width: 12),
              _buildProfileChoicePill(
                label: context.tr.translate('female'),
                isSelected: _selectedSex == 'female',
                onTap: () => setState(() => _selectedSex = 'female'),
                theme: theme,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            ],
          ),
        ),
        _buildProgressiveSection(
          visible: _hasSelectedSex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 34),
              _buildProfileQuestion(
                context.tr.translate('goal_setup_age_title'),
                theme: theme,
                textColor: textColor,
              ),
              const SizedBox(height: 14),
              _buildAgeInput(
                theme,
                textColor,
                isDarkMode,
                showLabel: false,
                showSlider: false,
                profileStyle: true,
              ),
            ],
          ),
        ),
        _buildProgressiveSection(
          visible: _hasSelectedSex && _hasFilledAge,
          child: Consumer<NutritionGoalsProvider>(
            builder: (context, provider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 34),
                  _buildProfileQuestion(
                    context.tr.translate('goal_setup_height_title'),
                    theme: theme,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 14),
                  _buildHeightInput(
                    theme,
                    textColor,
                    isDarkMode,
                    provider,
                    showLabel: false,
                    showSlider: false,
                    profileStyle: true,
                  ),
                ],
              );
            },
          ),
        ),
        _buildProgressiveSection(
          visible: _hasSelectedSex && _hasFilledAge && _hasFilledHeight,
          child: Consumer<NutritionGoalsProvider>(
            builder: (context, provider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 34),
                  _buildProfileQuestion(
                    context.tr.translate('goal_setup_weight_title'),
                    theme: theme,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 14),
                  _buildWeightInput(
                    theme,
                    textColor,
                    isDarkMode,
                    provider,
                    showLabel: false,
                    showSlider: false,
                    profileStyle: true,
                  ),
                ],
              );
            },
          ),
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
    required Widget? header,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (header != null) ...[
                      header,
                      const SizedBox(height: 24),
                    ],
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
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: _accentColor(theme).withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _accentColor(theme).withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            icon,
            color: _accentColor(theme),
            size: 34,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: textColor.withValues(alpha: 0.62),
            height: 1.32,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBadgeHeader({
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: _accentColor(theme),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _translateOrFallback(
          'goal_setup_profile_badge',
          'Objetivo & perfil',
        ),
        style: theme.textTheme.labelLarge?.copyWith(
          color: _onAccentColor(theme),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildProfileQuestion(
    String title, {
    required ThemeData theme,
    required Color textColor,
  }) {
    return Text(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: textColor.withValues(alpha: 0.82),
        fontWeight: FontWeight.w700,
        height: 1.16,
      ),
    );
  }

  Widget _buildProfileChoicePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final foregroundColor = isSelected ? _onAccentColor(theme) : textColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minWidth: 156, minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor(theme)
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF5F7FA)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? _accentColor(theme)
                : _subtleBorderColor(isDarkMode),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressiveSection({
    required bool visible,
    required Widget child,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: visible ? child : const SizedBox.shrink(key: ValueKey('hidden')),
      ),
    );
  }

  InputDecoration _numberInputDecoration({
    required ThemeData theme,
    required bool isDarkMode,
    String? suffixText,
    bool profileStyle = false,
  }) {
    if (profileStyle) {
      return InputDecoration(
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        suffixText: suffixText,
        suffixStyle: theme.textTheme.titleLarge?.copyWith(
          color: (isDarkMode ? Colors.white : AppTheme.textPrimaryColor)
              .withValues(alpha: 0.58),
          fontWeight: FontWeight.w700,
        ),
      );
    }

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
    bool profileStyle = false,
    bool isActive = false,
  }) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final foregroundColor =
        profileStyle && isActive ? _onAccentColor(theme) : _accentColor(theme);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        constraints: BoxConstraints(
          minWidth: profileStyle ? 92 : 58,
          minHeight: profileStyle ? 44 : 46,
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: profileStyle ? 20 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: profileStyle && isActive
              ? _accentColor(theme)
              : (profileStyle ? Colors.transparent : _surfaceColor(isDarkMode)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: profileStyle
                ? _accentColor(theme).withValues(alpha: 0.58)
                : _subtleBorderColor(isDarkMode),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: profileStyle ? foregroundColor : textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _formatHeightForUnit(HeightUnit unit, double heightCm) {
    if (unit == HeightUnit.cm) {
      return '${heightCm.round()} cm';
    }

    final totalInches = (heightCm / 2.54).round();
    return '${totalInches ~/ 12}\' ${totalInches % 12}"';
  }

  String _formatWeightForUnit(WeightUnit unit, double weightKg) {
    switch (unit) {
      case WeightUnit.kg:
        return '${weightKg.toStringAsFixed(1)} kg';
      case WeightUnit.lbs:
        return '${(weightKg * 2.20462).toStringAsFixed(1)} lbs';
      case WeightUnit.stLbs:
        final totalLbs = (weightKg * 2.20462).round();
        return '${totalLbs ~/ 14} st ${totalLbs % 14} lbs';
    }
  }

  Widget _buildAgeInput(
    ThemeData theme,
    Color textColor,
    bool isDarkMode, {
    bool showLabel = true,
    bool showSlider = true,
    bool profileStyle = false,
  }) {
    return Container(
      padding: profileStyle
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
          : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: profileStyle
            ? _profileInputColor(
                theme: theme,
                isDarkMode: isDarkMode,
                isActive: _isAgeInputActive,
                hasValue: _hasFilledAge,
              )
            : _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(profileStyle ? 24 : 18),
        border: Border.all(
          color: profileStyle
              ? _accentColor(theme)
                  .withValues(alpha: _isAgeInputActive ? 0.32 : 0.12)
              : _subtleBorderColor(isDarkMode),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              context.tr.translate('age'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  focusNode: _ageFocusNode,
                  keyboardType: TextInputType.number,
                  style: (profileStyle
                          ? theme.textTheme.displaySmall
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: profileStyle ? TextAlign.start : TextAlign.center,
                  decoration: _numberInputDecoration(
                    theme: theme,
                    isDarkMode: isDarkMode,
                    profileStyle: profileStyle,
                  ),
                  onChanged: (value) {
                    final age = int.tryParse(value);
                    if (age != null && age >= 10 && age <= 100) {
                      setState(() {
                        _age = age;
                        _hasFilledAge = true;
                      });
                    } else {
                      setState(() => _hasFilledAge = false);
                    }
                  },
                ),
              ),
              if (!profileStyle) ...[
                const SizedBox(width: 12),
                Text(
                  context.tr.translate('years'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          if (showSlider) ...[
            const SizedBox(height: 14),
            Slider(
              value: _age.toDouble().clamp(10.0, 100.0).toDouble(),
              min: 10,
              max: 100,
              divisions: 90,
              label: '$_age',
              activeColor: _accentColor(theme),
              inactiveColor: _inputFillColor(isDarkMode),
              onChanged: (value) {
                setState(() {
                  _age = value.round();
                  _hasFilledAge = true;
                  _ageController.text = _age.toString();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeightInput(
    ThemeData theme,
    Color textColor,
    bool isDarkMode,
    NutritionGoalsProvider provider, {
    bool showLabel = true,
    bool showSlider = true,
    bool profileStyle = false,
  }) {
    final isCm = provider.heightUnit == HeightUnit.cm;

    return Container(
      padding: profileStyle
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
          : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: profileStyle
            ? _profileInputColor(
                theme: theme,
                isDarkMode: isDarkMode,
                isActive: _isHeightInputActive,
                hasValue: _hasFilledHeight,
              )
            : _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(profileStyle ? 24 : 18),
        border: Border.all(
          color: profileStyle
              ? _accentColor(theme)
                  .withValues(alpha: _isHeightInputActive ? 0.32 : 0.12)
              : _subtleBorderColor(isDarkMode),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              context.tr.translate('height'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (isCm) ...[
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    focusNode: _heightFocusNode,
                    keyboardType: TextInputType.number,
                    style: (profileStyle
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign:
                        profileStyle ? TextAlign.start : TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      profileStyle: profileStyle,
                    ),
                    onChanged: (value) {
                      final height = double.tryParse(value);
                      if (height != null && height >= 100 && height <= 250) {
                        setState(() {
                          _height = height;
                          _hasFilledHeight = true;
                        });
                      } else {
                        setState(() => _hasFilledHeight = false);
                      }
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _heightController,
                    focusNode: _heightFocusNode,
                    keyboardType: TextInputType.number,
                    style: (profileStyle
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign:
                        profileStyle ? TextAlign.start : TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: "'",
                      profileStyle: profileStyle,
                    ),
                    onChanged: (value) {
                      final feet = int.tryParse(value) ?? 0;
                      final inches =
                          int.tryParse(_heightInchesController.text) ?? 0;
                      final heightCm =
                          NutritionGoalsProvider.heightToCm(feet, inches);
                      if (heightCm >= 100 && heightCm <= 250) {
                        setState(() {
                          _height = heightCm;
                          _hasFilledHeight = true;
                        });
                      } else {
                        setState(() => _hasFilledHeight = false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _heightInchesController,
                    focusNode: _heightInchesFocusNode,
                    keyboardType: TextInputType.number,
                    style: (profileStyle
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign:
                        profileStyle ? TextAlign.start : TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: '"',
                      profileStyle: profileStyle,
                    ),
                    onChanged: (value) {
                      final feet = int.tryParse(_heightController.text) ?? 0;
                      final inches = int.tryParse(value) ?? 0;
                      final heightCm =
                          NutritionGoalsProvider.heightToCm(feet, inches);
                      if (heightCm >= 100 && heightCm <= 250) {
                        setState(() {
                          _height = heightCm;
                          _hasFilledHeight = true;
                        });
                      } else {
                        setState(() => _hasFilledHeight = false);
                      }
                    },
                  ),
                ),
              ],
              if (!profileStyle ||
                  _hasFilledHeight ||
                  _isHeightInputActive) ...[
                const SizedBox(width: 12),
                _buildUnitToggle(
                  label: isCm ? 'cm' : 'ft',
                  onTap: () {
                    provider.toggleHeightUnit();
                    if (_hasFilledHeight) {
                      _updateHeightController(provider);
                    } else {
                      _heightController.clear();
                      _heightInchesController.clear();
                    }
                  },
                  theme: theme,
                  isDarkMode: isDarkMode,
                  profileStyle: profileStyle,
                  isActive: _isHeightInputActive,
                ),
              ],
            ],
          ),
          if (showSlider) ...[
            const SizedBox(height: 14),
            Slider(
              value: _height.clamp(100.0, 250.0).toDouble(),
              min: 100,
              max: 250,
              divisions: 150,
              label: _formatHeightForUnit(provider.heightUnit, _height),
              activeColor: _accentColor(theme),
              inactiveColor: _inputFillColor(isDarkMode),
              onChanged: (value) {
                setState(() {
                  _height = value.roundToDouble();
                  _hasFilledHeight = true;
                  _updateHeightController(provider);
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightInput(
    ThemeData theme,
    Color textColor,
    bool isDarkMode,
    NutritionGoalsProvider provider, {
    bool showLabel = true,
    bool showSlider = true,
    bool profileStyle = false,
  }) {
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
      padding: profileStyle
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
          : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: profileStyle
            ? _profileInputColor(
                theme: theme,
                isDarkMode: isDarkMode,
                isActive: _isWeightInputActive,
                hasValue: _hasFilledWeight,
              )
            : _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(profileStyle ? 24 : 18),
        border: Border.all(
          color: profileStyle
              ? _accentColor(theme)
                  .withValues(alpha: _isWeightInputActive ? 0.32 : 0.12)
              : _subtleBorderColor(isDarkMode),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              context.tr.translate('weight'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (!showSecondField) ...[
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    focusNode: _weightFocusNode,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: (profileStyle
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign:
                        profileStyle ? TextAlign.start : TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      profileStyle: profileStyle,
                    ),
                    onChanged: (value) {
                      final weight = double.tryParse(value);
                      if (weight != null) {
                        if (provider.weightUnit == WeightUnit.kg) {
                          if (weight >= 30 && weight <= 200) {
                            setState(() {
                              _weight = weight;
                              _hasFilledWeight = true;
                            });
                          } else {
                            setState(() => _hasFilledWeight = false);
                          }
                        } else if (provider.weightUnit == WeightUnit.lbs) {
                          final weightKg =
                              NutritionGoalsProvider.weightToKg(weight);
                          if (weightKg >= 30 && weightKg <= 200) {
                            setState(() {
                              _weight = weightKg;
                              _hasFilledWeight = true;
                            });
                          } else {
                            setState(() => _hasFilledWeight = false);
                          }
                        }
                      } else {
                        setState(() => _hasFilledWeight = false);
                      }
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _weightController,
                    focusNode: _weightFocusNode,
                    keyboardType: TextInputType.number,
                    style: (profileStyle
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign:
                        profileStyle ? TextAlign.start : TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: 'st',
                      profileStyle: profileStyle,
                    ),
                    onChanged: (value) {
                      final stone = int.tryParse(value) ?? 0;
                      final pounds =
                          int.tryParse(_weightPoundsController.text) ?? 0;
                      final weightKg =
                          NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
                      if (weightKg >= 30 && weightKg <= 200) {
                        setState(() {
                          _weight = weightKg;
                          _hasFilledWeight = true;
                        });
                      } else {
                        setState(() => _hasFilledWeight = false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _weightPoundsController,
                    focusNode: _weightPoundsFocusNode,
                    keyboardType: TextInputType.number,
                    style: (profileStyle
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign:
                        profileStyle ? TextAlign.start : TextAlign.center,
                    decoration: _numberInputDecoration(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      suffixText: 'lbs',
                      profileStyle: profileStyle,
                    ),
                    onChanged: (value) {
                      final stone = int.tryParse(_weightController.text) ?? 0;
                      final pounds = int.tryParse(value) ?? 0;
                      final weightKg =
                          NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
                      if (weightKg >= 30 && weightKg <= 200) {
                        setState(() {
                          _weight = weightKg;
                          _hasFilledWeight = true;
                        });
                      } else {
                        setState(() => _hasFilledWeight = false);
                      }
                    },
                  ),
                ),
              ],
              if (!profileStyle ||
                  _hasFilledWeight ||
                  _isWeightInputActive) ...[
                const SizedBox(width: 12),
                _buildUnitToggle(
                  label: unitLabel,
                  onTap: () {
                    provider.toggleWeightUnit();
                    if (_hasFilledWeight) {
                      _updateWeightController(provider);
                    } else {
                      _weightController.clear();
                      _weightPoundsController.clear();
                    }
                  },
                  theme: theme,
                  isDarkMode: isDarkMode,
                  profileStyle: profileStyle,
                  isActive: _isWeightInputActive,
                ),
              ],
            ],
          ),
          if (showSlider) ...[
            const SizedBox(height: 14),
            Slider(
              value: _weight.clamp(30.0, 200.0).toDouble(),
              min: 30,
              max: 200,
              divisions: 340,
              label: _formatWeightForUnit(provider.weightUnit, _weight),
              activeColor: _accentColor(theme),
              inactiveColor: _inputFillColor(isDarkMode),
              onChanged: (value) {
                setState(() {
                  _weight = double.parse(value.toStringAsFixed(1));
                  _hasFilledWeight = true;
                  _updateWeightController(provider);
                });
              },
            ),
          ],
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : _subtleBorderColor(isDarkMode),
            width: isSelected ? 0 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedForeground.withValues(alpha: 0.16)
                    : _inputFillColor(isDarkMode),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected
                      ? selectedForeground.withValues(alpha: 0.2)
                      : _subtleBorderColor(isDarkMode),
                ),
              ),
              child: Icon(
                icon,
                size: 21,
                color: foregroundColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
    final isFinishStep = _shouldFinishAfterCurrentStep;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkBackgroundColor
            : AppTheme.backgroundColor,
      ),
      child: Row(
        children: [
          if (_canGoBack)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  backgroundColor: _surfaceColor(isDarkMode),
                  padding: const EdgeInsets.symmetric(vertical: 18),
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
          if (_canGoBack) const SizedBox(width: 12),
          Expanded(
            flex: _canGoBack ? 2 : 1,
            child: ElevatedButton(
              onPressed: _canContinueCurrentStep ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor(theme),
                foregroundColor: _onAccentColor(theme),
                disabledBackgroundColor:
                    _surfaceColor(isDarkMode).withValues(alpha: 0.72),
                disabledForegroundColor: textColor.withValues(alpha: 0.42),
                minimumSize: const Size.fromHeight(62),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      isFinishStep
                          ? (widget.fromProfile
                              ? context.tr.translate('save')
                              : context.tr.translate('finish'))
                          : context.tr.translate('continue'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    isFinishStep
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 26,
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
