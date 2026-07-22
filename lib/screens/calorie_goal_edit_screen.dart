import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../utils/ui_utils.dart';

class CalorieGoalEditScreen extends StatefulWidget {
  const CalorieGoalEditScreen({
    super.key,
    required this.provider,
  });

  final NutritionGoalsProvider provider;

  @override
  State<CalorieGoalEditScreen> createState() => _CalorieGoalEditScreenState();
}

class _CalorieGoalEditScreenState extends State<CalorieGoalEditScreen> {
  late final TextEditingController _calorieController;

  @override
  void initState() {
    super.initState();
    _calorieController = TextEditingController(
      text: widget.provider.caloriesGoal.toString(),
    );
  }

  @override
  void dispose() {
    _calorieController.dispose();
    super.dispose();
  }

  int? get _calorieTarget {
    final value = int.tryParse(_calorieController.text.trim());
    if (value == null || value < 500 || value > 10000) {
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final target = _calorieTarget;
    final inferredGoal = target == null
        ? null
        : widget.provider.inferFitnessGoalForCalories(target);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          tooltip: context.tr.translate('back'),
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        title: Text(
          context.tr.translate('calorie_editor_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('calorie_editor_subtitle'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _mutedTextColor(isDarkMode),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildCalorieInputCard(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 14),
                    _buildCalculationBasisCard(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      accentColor: accentColor,
                    ),
                    if (target != null && inferredGoal != null) ...[
                      const SizedBox(height: 14),
                      _buildGoalPreviewCard(
                        theme: theme,
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                        target: target,
                        goal: inferredGoal,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildBottomAction(
              isDarkMode: isDarkMode,
              accentColor: accentColor,
              target: target,
              goal: inferredGoal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieInputCard({
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
    required Color accentColor,
  }) {
    final hasInvalidValue =
        _calorieController.text.trim().isNotEmpty && _calorieTarget == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('calorie_editor_daily_target'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _calorieController,
            autofocus: true,
            selectAllOnFocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              suffixText: 'kcal',
              suffixStyle: theme.textTheme.titleMedium?.copyWith(
                color: _mutedTextColor(isDarkMode),
                fontWeight: FontWeight.w700,
              ),
              filled: true,
              fillColor: isDarkMode
                  ? Colors.black.withValues(alpha: 0.14)
                  : AppTheme.surfaceColor.withValues(alpha: 0.65),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderColor(isDarkMode)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              errorText: hasInvalidValue
                  ? context.tr.translate('calorie_editor_invalid_value')
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationBasisCard({
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDarkMode ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.calculate_outlined,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.translate('calorie_editor_maintenance_label'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _mutedTextColor(isDarkMode),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.provider.maintenanceCalories} kcal',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr.translate('calorie_editor_maintenance_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _mutedTextColor(isDarkMode),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPreviewCard({
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
    required int target,
    required FitnessGoal goal,
  }) {
    final goalColor = _goalColor(goal);
    final delta = widget.provider.calorieDeltaPercentage(target);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: goalColor.withValues(alpha: isDarkMode ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: goalColor.withValues(alpha: isDarkMode ? 0.38 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('calorie_editor_result_title'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _mutedTextColor(isDarkMode),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: goalColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_goalIcon(goal), color: goalColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.tr.translate(_goalTranslationKey(goal)),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _buildDifferenceText(delta),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor.withValues(alpha: 0.76),
              height: 1.42,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.translate('calorie_editor_macros_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _mutedTextColor(isDarkMode),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction({
    required bool isDarkMode,
    required Color accentColor,
    required int? target,
    required FitnessGoal? goal,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor,
        border: Border(top: BorderSide(color: _borderColor(isDarkMode))),
      ),
      child: FilledButton.icon(
        onPressed:
            target == null || goal == null ? null : () => _save(target, goal),
        icon: const Icon(Icons.check_rounded),
        label: Text(
          context.tr.translate('calorie_editor_confirm'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: AppTheme.onColor(accentColor),
          disabledBackgroundColor: accentColor.withValues(alpha: 0.28),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _save(int target, FitnessGoal goal) {
    FocusScope.of(context).unfocus();
    widget.provider.updateManualCalorieGoal(
      calories: target,
      fitnessGoal: goal,
    );

    final navigatorContext = Navigator.of(context).context;
    final message = context.tr.translate('calorie_editor_saved');
    Navigator.pop(context);
    UIUtils.showPrimarySnackBar(navigatorContext, message);
  }

  String _buildDifferenceText(double delta) {
    if (delta.abs() < 0.5) {
      return context.tr.translate('calorie_editor_difference_neutral');
    }

    final directionKey = delta < 0
        ? 'calorie_editor_direction_below'
        : 'calorie_editor_direction_above';
    return context.tr
        .translate('calorie_editor_difference')
        .replaceAll('{percent}', delta.abs().round().toString())
        .replaceAll('{direction}', context.tr.translate(directionKey));
  }

  String _goalTranslationKey(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return 'calorie_editor_goal_lose_fast';
      case FitnessGoal.loseWeightSlowly:
        return 'calorie_editor_goal_lose_slowly';
      case FitnessGoal.maintainWeight:
        return 'calorie_editor_goal_maintain';
      case FitnessGoal.gainWeightSlowly:
        return 'calorie_editor_goal_gain_slowly';
      case FitnessGoal.gainWeight:
        return 'calorie_editor_goal_gain_fast';
    }
  }

  IconData _goalIcon(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return Icons.south_east_rounded;
      case FitnessGoal.loseWeightSlowly:
        return Icons.trending_down_rounded;
      case FitnessGoal.maintainWeight:
        return Icons.trending_flat_rounded;
      case FitnessGoal.gainWeightSlowly:
        return Icons.trending_up_rounded;
      case FitnessGoal.gainWeight:
        return Icons.north_east_rounded;
    }
  }

  Color _goalColor(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return const Color(0xFFFF7043);
      case FitnessGoal.loseWeightSlowly:
        return const Color(0xFFFFA726);
      case FitnessGoal.maintainWeight:
        return const Color(0xFF26A69A);
      case FitnessGoal.gainWeightSlowly:
        return const Color(0xFF7E57C2);
      case FitnessGoal.gainWeight:
        return const Color(0xFF5C6BC0);
    }
  }

  Color _mutedTextColor(bool isDarkMode) {
    return isDarkMode
        ? AppTheme.darkMutedTextColor
        : AppTheme.textSecondaryColor;
  }

  Color _borderColor(bool isDarkMode) {
    return isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.08);
  }
}
