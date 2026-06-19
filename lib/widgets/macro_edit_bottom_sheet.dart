import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../utils/ui_utils.dart';

enum _MacroInputMode {
  percentage,
  gramsPerKg,
  grams,
}

Future<void> showMacroEditBottomSheet({
  required BuildContext context,
  NutritionGoalsProvider? provider,
}) {
  final resolvedProvider =
      provider ?? Provider.of<NutritionGoalsProvider>(context, listen: false);
  final theme = Theme.of(context);
  final isDarkMode = theme.brightness == Brightness.dark;
  final textColor =
      isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
  final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MacroEditBottomSheet(
      provider: resolvedProvider,
      theme: theme,
      isDarkMode: isDarkMode,
      textColor: textColor,
      cardColor: cardColor,
    ),
  );
}

class MacroEditBottomSheet extends StatefulWidget {
  const MacroEditBottomSheet({
    super.key,
    required this.provider,
    required this.theme,
    required this.isDarkMode,
    required this.textColor,
    required this.cardColor,
  });

  final NutritionGoalsProvider provider;
  final ThemeData theme;
  final bool isDarkMode;
  final Color textColor;
  final Color cardColor;

  @override
  State<MacroEditBottomSheet> createState() => _MacroEditBottomSheetState();
}

class _MacroEditBottomSheetState extends State<MacroEditBottomSheet> {
  late _MacroInputMode _selectedMode;

  late double _carbsPercentage;
  late double _proteinPercentage;
  late double _fatPercentage;

  late double _carbsGrams;
  late double _proteinGrams;
  late double _fatGrams;

  late double _carbsPerKg;
  late double _proteinPerKg;
  late double _fatPerKg;

  late final TextEditingController _carbsPercentageController;
  late final TextEditingController _proteinPercentageController;
  late final TextEditingController _fatPercentageController;
  late final TextEditingController _carbsGramsController;
  late final TextEditingController _proteinGramsController;
  late final TextEditingController _fatGramsController;
  late final TextEditingController _carbsPerKgController;
  late final TextEditingController _proteinPerKgController;
  late final TextEditingController _fatPerKgController;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.provider.useCalculatedGoals
        ? _MacroInputMode.percentage
        : _MacroInputMode.grams;

    _carbsPercentage = widget.provider.carbsPercentage.toDouble();
    _proteinPercentage = widget.provider.proteinPercentage.toDouble();
    _fatPercentage = widget.provider.fatPercentage.toDouble();

    _carbsGrams = widget.provider.carbsGoal.toDouble();
    _proteinGrams = widget.provider.proteinGoal.toDouble();
    _fatGrams = widget.provider.fatGoal.toDouble();

    final perKg = widget.provider.macroPerKgTargets;
    _carbsPerKg = perKg['carbs'] ?? 0;
    _proteinPerKg = perKg['protein'] ?? 0;
    _fatPerKg = perKg['fat'] ?? 0;

    _carbsPercentageController = TextEditingController();
    _proteinPercentageController = TextEditingController();
    _fatPercentageController = TextEditingController();
    _carbsGramsController = TextEditingController();
    _proteinGramsController = TextEditingController();
    _fatGramsController = TextEditingController();
    _carbsPerKgController = TextEditingController();
    _proteinPerKgController = TextEditingController();
    _fatPerKgController = TextEditingController();

    _syncAllControllers();
  }

  @override
  void dispose() {
    _carbsPercentageController.dispose();
    _proteinPercentageController.dispose();
    _fatPercentageController.dispose();
    _carbsGramsController.dispose();
    _proteinGramsController.dispose();
    _fatGramsController.dispose();
    _carbsPerKgController.dispose();
    _proteinPerKgController.dispose();
    _fatPerKgController.dispose();
    super.dispose();
  }

  void _syncAllControllers() {
    _setControllerValue(
      _carbsPercentageController,
      _formatNumber(_carbsPercentage, digits: 0),
    );
    _setControllerValue(
      _proteinPercentageController,
      _formatNumber(_proteinPercentage, digits: 0),
    );
    _setControllerValue(
      _fatPercentageController,
      _formatNumber(_fatPercentage, digits: 0),
    );
    _setControllerValue(
      _carbsGramsController,
      _formatNumber(_carbsGrams, digits: 0),
    );
    _setControllerValue(
      _proteinGramsController,
      _formatNumber(_proteinGrams, digits: 0),
    );
    _setControllerValue(
        _fatGramsController, _formatNumber(_fatGrams, digits: 0));
    _setControllerValue(_carbsPerKgController, _formatNumber(_carbsPerKg));
    _setControllerValue(_proteinPerKgController, _formatNumber(_proteinPerKg));
    _setControllerValue(_fatPerKgController, _formatNumber(_fatPerKg));
  }

  void _setControllerValue(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _formatNumber(double value, {int digits = 1}) {
    final useDigits = digits == 0 || value % 1 == 0 ? 0 : digits;
    return value.toStringAsFixed(useDigits);
  }

  double? _tryParseDouble(String rawValue) {
    final normalized = rawValue.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  Map<String, double> _previewGrams() {
    switch (_selectedMode) {
      case _MacroInputMode.percentage:
        return widget.provider.calculateMacroGramsFromPercentages(
          carbsPercentage: _carbsPercentage,
          proteinPercentage: _proteinPercentage,
          fatPercentage: _fatPercentage,
        );
      case _MacroInputMode.gramsPerKg:
        return widget.provider.calculateMacroGramsFromGramsPerKg(
          carbsPerKg: _carbsPerKg,
          proteinPerKg: _proteinPerKg,
          fatPerKg: _fatPerKg,
        );
      case _MacroInputMode.grams:
        return {
          'carbs': _carbsGrams,
          'protein': _proteinGrams,
          'fat': _fatGrams,
        };
    }
  }

  double _previewCalories() {
    final grams = _previewGrams();
    return (grams['carbs'] ?? 0) * 4 +
        (grams['protein'] ?? 0) * 4 +
        (grams['fat'] ?? 0) * 9;
  }

  double _percentageTotal() {
    return _carbsPercentage + _proteinPercentage + _fatPercentage;
  }

  bool _canSave() {
    if (_selectedMode == _MacroInputMode.percentage) {
      return (_percentageTotal() - 100).abs() < 0.01;
    }

    final grams = _previewGrams();
    return (grams['carbs'] ?? 0) > 0 &&
        (grams['protein'] ?? 0) > 0 &&
        (grams['fat'] ?? 0) > 0;
  }

  void _applyPreset(DietType dietType) {
    switch (dietType) {
      case DietType.balanced:
        _carbsPercentage = 50;
        _proteinPercentage = 20;
        _fatPercentage = 30;
        break;
      case DietType.highProtein:
        _carbsPercentage = 30;
        _proteinPercentage = 40;
        _fatPercentage = 30;
        break;
      case DietType.lowCarb:
        _carbsPercentage = 20;
        _proteinPercentage = 40;
        _fatPercentage = 40;
        break;
      default:
        return;
    }

    setState(() {
      _selectedMode = _MacroInputMode.percentage;
      _errorMessage = null;
      _syncAllControllers();
    });
  }

  void _fillRemainingCaloriesWithCarbs() {
    final targetCalories = widget.provider.caloriesGoal.toDouble();
    final nonCarbCalories = (_selectedMode == _MacroInputMode.gramsPerKg)
        ? (_proteinPerKg * widget.provider.weight * 4) +
            (_fatPerKg * widget.provider.weight * 9)
        : (_proteinGrams * 4) + (_fatGrams * 9);

    final remainingCarbCalories = targetCalories - nonCarbCalories;
    final double carbGrams =
        remainingCarbCalories <= 0 ? 0.0 : remainingCarbCalories / 4;

    setState(() {
      _errorMessage = null;

      if (_selectedMode == _MacroInputMode.gramsPerKg) {
        final safeWeight =
            widget.provider.weight <= 0 ? 1.0 : widget.provider.weight;
        _carbsPerKg = carbGrams / safeWeight;
      } else {
        _carbsGrams = carbGrams;
      }

      _syncAllControllers();
    });
  }

  void _saveChanges() {
    FocusScope.of(context).unfocus();

    if (_selectedMode == _MacroInputMode.percentage) {
      final total = _percentageTotal();
      if ((total - 100).abs() > 0.01) {
        setState(() {
          _errorMessage = context.tr.translate('macro_editor_percentage_error');
        });
        return;
      }

      widget.provider.updateMacroTargetsFromPercentages(
        carbsPercentage: _carbsPercentage,
        proteinPercentage: _proteinPercentage,
        fatPercentage: _fatPercentage,
      );
    } else if (_selectedMode == _MacroInputMode.gramsPerKg) {
      final grams = _previewGrams();
      if ((grams['carbs'] ?? 0) <= 0 ||
          (grams['protein'] ?? 0) <= 0 ||
          (grams['fat'] ?? 0) <= 0) {
        setState(() {
          _errorMessage = context.tr.translate('macro_editor_positive_error');
        });
        return;
      }

      widget.provider.updateMacroTargetsFromGramsPerKg(
        carbsPerKg: _carbsPerKg,
        proteinPerKg: _proteinPerKg,
        fatPerKg: _fatPerKg,
      );
    } else {
      if (_carbsGrams <= 0 || _proteinGrams <= 0 || _fatGrams <= 0) {
        setState(() {
          _errorMessage = context.tr.translate('macro_editor_positive_error');
        });
        return;
      }

      widget.provider.updateMacroTargetsFromGrams(
        carbsGrams: _carbsGrams,
        proteinGrams: _proteinGrams,
        fatGrams: _fatGrams,
      );
    }

    final navigatorContext = Navigator.of(context).context;
    final successMessage = context.tr.translate('macro_editor_saved');

    Navigator.pop(context);
    UIUtils.showPrimarySnackBar(navigatorContext, successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final bottomSafePadding = mediaQuery.padding.bottom;
    final previewGrams = _previewGrams();
    final previewCalories = _previewCalories();
    final targetCalories = widget.provider.caloriesGoal.toDouble();
    final difference = previewCalories - targetCalories;
    final isPercentageMode = _selectedMode == _MacroInputMode.percentage;
    final accentColor = widget.isDarkMode
        ? AppTheme.primaryColorDarkMode
        : AppTheme.primaryColor;
    final accentForegroundColor = AppTheme.onColor(accentColor);
    final dividerColor = _borderColor();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 10),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.textColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 18, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr.translate('edit_macronutrients'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  widget.theme.textTheme.titleLarge?.copyWith(
                                color: widget.textColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr.translate('macro_editor_subtitle'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  widget.theme.textTheme.bodyMedium?.copyWith(
                                color: widget.textColor.withValues(alpha: 0.68),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: context.tr.translate('cancel'),
                        child: IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: widget.textColor,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                widget.textColor.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: dividerColor,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTargetCard(
                          accentColor: accentColor,
                          previewCalories: previewCalories,
                          targetCalories: targetCalories,
                          difference: difference,
                        ),
                        const SizedBox(height: 18),
                        _buildModeSelector(accentColor),
                        const SizedBox(height: 18),
                        if (isPercentageMode) ...[
                          _buildPresetSection(accentColor),
                          const SizedBox(height: 18),
                        ],
                        ..._buildMacroFields(previewGrams),
                        const SizedBox(height: 18),
                        if (!isPercentageMode) ...[
                          _buildManualModeNotice(accentColor),
                          const SizedBox(height: 12),
                        ],
                        if (!isPercentageMode &&
                            difference.abs() > 1 &&
                            widget.provider.caloriesGoal > 0) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _fillRemainingCaloriesWithCarbs,
                              icon: const Icon(Icons.auto_fix_high_rounded,
                                  size: 18),
                              label: Text(
                                context.tr.translate(
                                  'macro_editor_fill_remaining_carbs',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (_errorMessage != null)
                          _buildErrorBox(_errorMessage!),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    16 + bottomSafePadding,
                  ),
                  decoration: BoxDecoration(
                    color: widget.cardColor,
                    border: Border(
                      top: BorderSide(
                        color: dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: BorderSide(
                              color: widget.textColor.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(context.tr.translate('cancel')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _canSave() ? _saveChanges : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: accentForegroundColor,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              context.tr.translate('save_changes'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTargetCard({
    required Color accentColor,
    required double previewCalories,
    required double targetCalories,
    required double difference,
  }) {
    final toneColor = difference.abs() <= 1
        ? AppTheme.successColor
        : difference > 0
            ? AppTheme.warningColor
            : AppTheme.infoColor;
    final modeLabel = context.tr.translate(
      widget.provider.useCalculatedGoals
          ? 'macro_editor_goal_mode_calculated'
          : 'macro_editor_goal_mode_manual',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.translate('macro_editor_current_target'),
                  style: widget.theme.textTheme.titleSmall?.copyWith(
                    color: widget.textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  modeLabel,
                  style: widget.theme.textTheme.labelSmall?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildCaloriesBlock(
                    label: context.tr.translate('macro_editor_current_target'),
                    value: targetCalories.round(),
                    color: widget.textColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 22,
                    color: widget.textColor.withValues(alpha: 0.38),
                  ),
                ),
                Expanded(
                  child: _buildCaloriesBlock(
                    label: context.tr.translate('macro_editor_new_target'),
                    value: previewCalories.round(),
                    color: toneColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  toneColor.withValues(alpha: widget.isDarkMode ? 0.14 : 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: toneColor.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Icon(
                  difference.abs() <= 1
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: toneColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr.translate('macro_editor_difference'),
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${difference >= 0 ? '+' : ''}${difference.round()} kcal',
                  style: widget.theme.textTheme.titleSmall?.copyWith(
                    color: toneColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesBlock({
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.theme.textTheme.bodySmall?.copyWith(
            color: widget.textColor.withValues(alpha: 0.62),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$value'),
                TextSpan(
                  text: ' kcal',
                  style: widget.theme.textTheme.titleSmall?.copyWith(
                    color: color.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            style: widget.theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(Color accentColor) {
    final selectedHint = _modeHint(_selectedMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate('macro_editor_adjust_method'),
          style: widget.theme.textTheme.titleSmall?.copyWith(
            color: widget.textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: _cardDecoration(radius: 20),
          child: Row(
            children: [
              Expanded(
                child: _buildModeSegment(
                  mode: _MacroInputMode.percentage,
                  title: context.tr.translate('macro_mode_percentage_title'),
                  unit: context.tr.translate('macro_mode_percentage'),
                  icon: Icons.percent_rounded,
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildModeSegment(
                  mode: _MacroInputMode.gramsPerKg,
                  title: context.tr.translate('macro_mode_grams_per_kg_title'),
                  unit: context.tr.translate('macro_mode_grams_per_kg'),
                  icon: Icons.monitor_weight_outlined,
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildModeSegment(
                  mode: _MacroInputMode.grams,
                  title: context.tr.translate('macro_mode_grams_title'),
                  unit: context.tr.translate('macro_mode_grams'),
                  icon: Icons.edit_note_rounded,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: widget.textColor.withValues(alpha: 0.56),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedHint,
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.68),
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSegment({
    required _MacroInputMode mode,
    required String title,
    required String unit,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedMode == mode;
    final foregroundColor = isSelected
        ? AppTheme.selectedPillTextColor(widget.isDarkMode)
        : widget.textColor.withValues(alpha: 0.74);
    final selectedBackground =
        AppTheme.selectedPillBackgroundColor(widget.isDarkMode);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? selectedBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: widget.isDarkMode ? 0.5 : 0.32)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? accentColor
                  : foregroundColor.withValues(alpha: 0.74),
              size: 18,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: widget.theme.textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                height: 1.08,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: foregroundColor.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modeHint(_MacroInputMode mode) {
    switch (mode) {
      case _MacroInputMode.percentage:
        return context.tr.translate('macro_mode_percentage_hint');
      case _MacroInputMode.gramsPerKg:
        return context.tr.translate('macro_mode_grams_per_kg_hint');
      case _MacroInputMode.grams:
        return context.tr.translate('macro_mode_grams_hint');
    }
  }

  Widget _buildPresetSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.tr.translate('macro_editor_presets_title'),
              style: widget.theme.textTheme.titleSmall?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                context.tr.translate('macro_editor_most_used'),
                style: widget.theme.textTheme.labelSmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip(
              label:
                  widget.provider.getDietTypeName(DietType.balanced, context),
              onTap: () => _applyPreset(DietType.balanced),
            ),
            _buildPresetChip(
              label: widget.provider
                  .getDietTypeName(DietType.highProtein, context),
              onTap: () => _applyPreset(DietType.highProtein),
            ),
            _buildPresetChip(
              label: widget.provider.getDietTypeName(DietType.lowCarb, context),
              onTap: () => _applyPreset(DietType.lowCarb),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      labelStyle: widget.theme.textTheme.bodySmall?.copyWith(
        color: widget.textColor,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: _panelColor(),
      side: BorderSide(
        color: _borderColor(),
      ),
    );
  }

  List<Widget> _buildMacroFields(Map<String, double> previewGrams) {
    switch (_selectedMode) {
      case _MacroInputMode.percentage:
        return [
          _buildMacroFieldCard(
            label: context.tr.translate('carbohydrates'),
            icon: MacroTheme.carbsIcon,
            accentColor: MacroTheme.carbsColor,
            controller: _carbsPercentageController,
            suffix: '%',
            helper:
                '${(previewGrams['carbs'] ?? 0).round()}g • ${((previewGrams['carbs'] ?? 0) * 4).round()} kcal',
            onChanged: (value) {
              setState(() {
                _carbsPercentage = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildMacroFieldCard(
            label: context.tr.translate('protein_full'),
            icon: MacroTheme.proteinIcon,
            accentColor: MacroTheme.proteinColor,
            controller: _proteinPercentageController,
            suffix: '%',
            helper:
                '${(previewGrams['protein'] ?? 0).round()}g • ${((previewGrams['protein'] ?? 0) * 4).round()} kcal',
            onChanged: (value) {
              setState(() {
                _proteinPercentage = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildMacroFieldCard(
            label: context.tr.translate('fats'),
            icon: MacroTheme.fatIcon,
            accentColor: MacroTheme.fatColor,
            controller: _fatPercentageController,
            suffix: '%',
            helper:
                '${(previewGrams['fat'] ?? 0).round()}g • ${((previewGrams['fat'] ?? 0) * 9).round()} kcal',
            onChanged: (value) {
              setState(() {
                _fatPercentage = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildPercentageTotalCard(),
        ];
      case _MacroInputMode.gramsPerKg:
        return [
          _buildMacroFieldCard(
            label: context.tr.translate('carbohydrates'),
            icon: MacroTheme.carbsIcon,
            accentColor: MacroTheme.carbsColor,
            controller: _carbsPerKgController,
            suffix: 'g/kg',
            helper:
                '${(previewGrams['carbs'] ?? 0).round()}g • ${((previewGrams['carbs'] ?? 0) * 4).round()} kcal',
            onChanged: (value) {
              setState(() {
                _carbsPerKg = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildMacroFieldCard(
            label: context.tr.translate('protein_full'),
            icon: MacroTheme.proteinIcon,
            accentColor: MacroTheme.proteinColor,
            controller: _proteinPerKgController,
            suffix: 'g/kg',
            helper:
                '${(previewGrams['protein'] ?? 0).round()}g • ${((previewGrams['protein'] ?? 0) * 4).round()} kcal',
            onChanged: (value) {
              setState(() {
                _proteinPerKg = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildMacroFieldCard(
            label: context.tr.translate('fats'),
            icon: MacroTheme.fatIcon,
            accentColor: MacroTheme.fatColor,
            controller: _fatPerKgController,
            suffix: 'g/kg',
            helper:
                '${(previewGrams['fat'] ?? 0).round()}g • ${((previewGrams['fat'] ?? 0) * 9).round()} kcal',
            onChanged: (value) {
              setState(() {
                _fatPerKg = value;
                _errorMessage = null;
              });
            },
          ),
        ];
      case _MacroInputMode.grams:
        return [
          _buildMacroFieldCard(
            label: context.tr.translate('carbohydrates'),
            icon: MacroTheme.carbsIcon,
            accentColor: MacroTheme.carbsColor,
            controller: _carbsGramsController,
            suffix: 'g',
            helper: '${(_carbsGrams * 4).round()} kcal',
            onChanged: (value) {
              setState(() {
                _carbsGrams = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildMacroFieldCard(
            label: context.tr.translate('protein_full'),
            icon: MacroTheme.proteinIcon,
            accentColor: MacroTheme.proteinColor,
            controller: _proteinGramsController,
            suffix: 'g',
            helper: '${(_proteinGrams * 4).round()} kcal',
            onChanged: (value) {
              setState(() {
                _proteinGrams = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildMacroFieldCard(
            label: context.tr.translate('fats'),
            icon: MacroTheme.fatIcon,
            accentColor: MacroTheme.fatColor,
            controller: _fatGramsController,
            suffix: 'g',
            helper: '${(_fatGrams * 9).round()} kcal',
            onChanged: (value) {
              setState(() {
                _fatGrams = value;
                _errorMessage = null;
              });
            },
          ),
        ];
    }
  }

  Widget _buildMacroFieldCard({
    required String label,
    required IconData icon,
    required Color accentColor,
    required TextEditingController controller,
    required String suffix,
    required String helper,
    required ValueChanged<double> onChanged,
  }) {
    final labelContent = Row(
      children: [
        MacroTheme.iconBadge(
          icon: icon,
          color: accentColor,
          isDarkMode: widget.isDarkMode,
          size: 44,
          iconSize: 22,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  color: widget.textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final inputField = _buildMacroInputField(
      controller: controller,
      suffix: suffix,
      accentColor: accentColor,
      onChanged: onChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = constraints.maxWidth < 300 || textScale > 1.2;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(radius: 20),
          child: useStackedLayout
              ? Column(
                  children: [
                    labelContent,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: inputField),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: labelContent),
                    const SizedBox(width: 12),
                    SizedBox(width: 104, child: inputField),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMacroInputField({
    required TextEditingController controller,
    required String suffix,
    required Color accentColor,
    required ValueChanged<double> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: widget.theme.textTheme.titleMedium?.copyWith(
        color: widget.textColor,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        suffixText: suffix,
        suffixStyle: widget.theme.textTheme.titleSmall?.copyWith(
          color: widget.textColor.withValues(alpha: 0.58),
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: widget.isDarkMode
            ? Colors.black.withValues(alpha: 0.12)
            : AppTheme.surfaceColor.withValues(alpha: 0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: widget.textColor.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 1.4),
        ),
      ),
      onChanged: (value) {
        final parsed = _tryParseDouble(value);
        if (parsed != null) {
          onChanged(parsed);
        }
      },
    );
  }

  Widget _buildPercentageTotalCard() {
    final total = _percentageTotal();
    final isValid = (total - 100).abs() < 0.01;
    final toneColor = isValid ? AppTheme.successColor : AppTheme.warningColor;
    final progress = (total / 100).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: toneColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.translate('macro_editor_total_percentage'),
                  style: widget.theme.textTheme.bodyMedium?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: widget.textColor.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(toneColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${total.round()}%',
                style: widget.theme.textTheme.titleLarge?.copyWith(
                  color: toneColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!isValid)
                TextButton(
                  onPressed: () {
                    final totalValue = _percentageTotal();
                    if (totalValue <= 0) {
                      return;
                    }

                    setState(() {
                      _carbsPercentage = (_carbsPercentage / totalValue) * 100;
                      _proteinPercentage =
                          (_proteinPercentage / totalValue) * 100;
                      _fatPercentage =
                          100 - _carbsPercentage - _proteinPercentage;
                      _errorMessage = null;
                      _syncAllControllers();
                    });
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.only(top: 2),
                  ),
                  child: Text(
                    context.tr.translate('macro_editor_fix_total'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualModeNotice(Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: widget.isDarkMode ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr.translate('macro_editor_switches_manual_mode'),
              style: widget.theme.textTheme.bodySmall?.copyWith(
                color: widget.textColor.withValues(alpha: 0.76),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: widget.theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _panelColor() {
    return widget.isDarkMode ? AppTheme.darkComponentColor : AppTheme.cardColor;
  }

  Color _borderColor() {
    return widget.textColor.withValues(alpha: widget.isDarkMode ? 0.1 : 0.08);
  }

  BoxDecoration _cardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: _panelColor(),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _borderColor()),
      boxShadow: AppTheme.profileCardShadow(widget.isDarkMode),
    );
  }
}
