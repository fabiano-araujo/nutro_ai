import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    barrierColor: Colors.black.withValues(alpha: 0.48),
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
      _formatNumber(_carbsPercentage),
    );
    _setControllerValue(
      _proteinPercentageController,
      _formatNumber(_proteinPercentage),
    );
    _setControllerValue(
      _fatPercentageController,
      _formatNumber(_fatPercentage),
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
      _fatGramsController,
      _formatNumber(_fatGrams, digits: 0),
    );
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

  void _selectMode(_MacroInputMode mode) {
    if (_selectedMode == mode) {
      return;
    }

    FocusScope.of(context).unfocus();
    final currentGrams = _previewGrams();

    setState(() {
      switch (mode) {
        case _MacroInputMode.percentage:
          final carbsCalories = (currentGrams['carbs'] ?? 0) * 4;
          final proteinCalories = (currentGrams['protein'] ?? 0) * 4;
          final fatCalories = (currentGrams['fat'] ?? 0) * 9;
          final totalCalories = carbsCalories + proteinCalories + fatCalories;

          if (totalCalories > 0) {
            _carbsPercentage = carbsCalories / totalCalories * 100;
            _proteinPercentage = proteinCalories / totalCalories * 100;
            _fatPercentage = 100 - _carbsPercentage - _proteinPercentage;
          }
          break;
        case _MacroInputMode.gramsPerKg:
          final safeWeight =
              widget.provider.weight > 0 ? widget.provider.weight : 1.0;
          _carbsPerKg = (currentGrams['carbs'] ?? 0) / safeWeight;
          _proteinPerKg = (currentGrams['protein'] ?? 0) / safeWeight;
          _fatPerKg = (currentGrams['fat'] ?? 0) / safeWeight;
          break;
        case _MacroInputMode.grams:
          _carbsGrams = currentGrams['carbs'] ?? 0;
          _proteinGrams = currentGrams['protein'] ?? 0;
          _fatGrams = currentGrams['fat'] ?? 0;
          break;
      }

      _selectedMode = mode;
      _errorMessage = null;
      _syncAllControllers();
    });
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

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.94,
          minChildSize: 0.62,
          maxChildSize: 0.97,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDailySummary(
                          previewGrams: previewGrams,
                          previewCalories: previewCalories,
                          targetCalories: targetCalories,
                          difference: difference,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 22),
                        _buildModeSelector(accentColor),
                        const SizedBox(height: 20),
                        if (isPercentageMode) ...[
                          _buildPresetSection(accentColor),
                          const SizedBox(height: 18),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Column(
                            key: ValueKey(_selectedMode),
                            children: _buildMacroFields(previewGrams),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (!isPercentageMode)
                          _buildManualTools(
                            accentColor: accentColor,
                            showBalanceAction: difference.abs() > 1 &&
                                widget.provider.caloriesGoal > 0,
                          ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _buildErrorBox(_errorMessage!),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildFooter(
                  accentColor: accentColor,
                  accentForegroundColor: accentForegroundColor,
                  bottomSafePadding: bottomSafePadding,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: widget.textColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 14, 14),
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
                      style: widget.theme.textTheme.titleLarge?.copyWith(
                        color: widget.textColor,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr.translate('macro_editor_subtitle'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.textColor.withValues(alpha: 0.62),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                key: const Key('macro-editor-close'),
                tooltip: context.tr.translate('cancel'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                color: widget.textColor,
                style: IconButton.styleFrom(
                  backgroundColor: _surfaceColor(),
                  minimumSize: const Size.square(44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailySummary({
    required Map<String, double> previewGrams,
    required double previewCalories,
    required double targetCalories,
    required double difference,
    required Color accentColor,
  }) {
    final toneColor = _differenceColor(difference);
    final differenceText =
        '${difference >= 0 ? '+' : ''}${difference.round()} kcal';

    return Semantics(
      container: true,
      label:
          '${context.tr.translate('macro_editor_new_target')}: ${previewCalories.round()} kcal',
      child: Container(
        key: const Key('macro-daily-summary'),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDarkMode
                ? [const Color(0xFF202A2A), const Color(0xFF1C2225)]
                : [const Color(0xFFF1FBF9), const Color(0xFFF7F9FC)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                accentColor.withValues(alpha: widget.isDarkMode ? 0.2 : 0.14),
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr.translate('macro_editor_new_target'),
                        style: widget.theme.textTheme.bodySmall?.copyWith(
                          color: widget.textColor.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${previewCalories.round()}'),
                              TextSpan(
                                text: ' kcal',
                                style:
                                    widget.theme.textTheme.titleSmall?.copyWith(
                                  color:
                                      widget.textColor.withValues(alpha: 0.68),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          style:
                              widget.theme.textTheme.headlineMedium?.copyWith(
                            color: widget.textColor,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${context.tr.translate('macro_editor_current_target')}: ${targetCalories.round()} kcal',
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: widget.textColor.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: toneColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            difference.abs() <= 1
                                ? Icons.check_rounded
                                : Icons.swap_vert_rounded,
                            color: toneColor,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            differenceText,
                            style: widget.theme.textTheme.labelSmall?.copyWith(
                              color: toneColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDistributionBar(previewGrams),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _buildMacroSummaryItem(
                    label: context.tr.translate('carbohydrates'),
                    grams: previewGrams['carbs'] ?? 0,
                    color: MacroTheme.carbsColor,
                  ),
                ),
                Expanded(
                  child: _buildMacroSummaryItem(
                    label: context.tr.translate('protein_full'),
                    grams: previewGrams['protein'] ?? 0,
                    color: MacroTheme.proteinColor,
                  ),
                ),
                Expanded(
                  child: _buildMacroSummaryItem(
                    label: context.tr.translate('fats'),
                    grams: previewGrams['fat'] ?? 0,
                    color: MacroTheme.fatColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionBar(Map<String, double> grams) {
    final carbsCalories = (grams['carbs'] ?? 0) * 4;
    final proteinCalories = (grams['protein'] ?? 0) * 4;
    final fatCalories = (grams['fat'] ?? 0) * 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 9,
        child: Row(
          children: [
            _buildDistributionSegment(carbsCalories, MacroTheme.carbsColor),
            _buildDistributionSegment(
              proteinCalories,
              MacroTheme.proteinColor,
            ),
            _buildDistributionSegment(fatCalories, MacroTheme.fatColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionSegment(double calories, Color color) {
    return Expanded(
      flex: (calories * 10).round().clamp(1, 1000000),
      child: ColoredBox(color: color),
    );
  }

  Widget _buildMacroSummaryItem({
    required String label,
    required double grams,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${grams.round()}g',
                maxLines: 1,
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.theme.textTheme.labelSmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.52),
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate('macro_editor_adjust_method'),
          style: widget.theme.textTheme.titleSmall?.copyWith(
            color: widget.textColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surfaceColor(),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModeTab(
                  key: const Key('macro-mode-percentage'),
                  mode: _MacroInputMode.percentage,
                  title: context.tr.translate('macro_mode_percentage_title'),
                  unit: context.tr.translate('macro_mode_percentage'),
                  icon: Icons.pie_chart_outline_rounded,
                  accentColor: accentColor,
                ),
              ),
              Expanded(
                child: _buildModeTab(
                  key: const Key('macro-mode-grams-per-kg'),
                  mode: _MacroInputMode.gramsPerKg,
                  title: context.tr.translate('macro_mode_grams_per_kg_title'),
                  unit: context.tr.translate('macro_mode_grams_per_kg'),
                  icon: Icons.monitor_weight_outlined,
                  accentColor: accentColor,
                ),
              ),
              Expanded(
                child: _buildModeTab(
                  key: const Key('macro-mode-grams'),
                  mode: _MacroInputMode.grams,
                  title: context.tr.translate('macro_mode_grams_title'),
                  unit: context.tr.translate('macro_mode_grams'),
                  icon: Icons.straighten_rounded,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color:
                accentColor.withValues(alpha: widget.isDarkMode ? 0.1 : 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 17, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _modeHint(_selectedMode),
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.7),
                    height: 1.25,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required Key key,
    required _MacroInputMode mode,
    required String title,
    required String unit,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedMode == mode;
    final foregroundColor =
        isSelected ? accentColor : widget.textColor.withValues(alpha: 0.58);

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        key: key,
        onTap: () => _selectMode(mode),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _panelColor() : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: widget.isDarkMode ? 0.18 : 0.055,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 5),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: foregroundColor.withValues(alpha: 0.72),
                        height: 1,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            Expanded(
              child: Text(
                context.tr.translate('macro_editor_presets_title'),
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  color: widget.textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip(
                label:
                    widget.provider.getDietTypeName(DietType.balanced, context),
                ratio: '50 • 20 • 30',
                selected: _matchesPreset(50, 20, 30),
                accentColor: accentColor,
                onTap: () => _applyPreset(DietType.balanced),
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                label: widget.provider
                    .getDietTypeName(DietType.highProtein, context),
                ratio: '30 • 40 • 30',
                selected: _matchesPreset(30, 40, 30),
                accentColor: accentColor,
                onTap: () => _applyPreset(DietType.highProtein),
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                label:
                    widget.provider.getDietTypeName(DietType.lowCarb, context),
                ratio: '20 • 40 • 40',
                selected: _matchesPreset(20, 40, 40),
                accentColor: accentColor,
                onTap: () => _applyPreset(DietType.lowCarb),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _matchesPreset(double carbs, double protein, double fat) {
    return (_carbsPercentage - carbs).abs() < 0.01 &&
        (_proteinPercentage - protein).abs() < 0.01 &&
        (_fatPercentage - fat).abs() < 0.01;
  }

  Widget _buildPresetChip({
    required String label,
    required String ratio,
    required bool selected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? accentColor.withValues(alpha: 0.12) : _panelColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color:
              selected ? accentColor.withValues(alpha: 0.38) : _borderColor(),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: [
              if (selected) ...[
                Icon(Icons.check_circle_rounded, size: 16, color: accentColor),
                const SizedBox(width: 6),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.textColor,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ratio,
                    style: widget.theme.textTheme.labelSmall?.copyWith(
                      color: widget.textColor.withValues(alpha: 0.52),
                      fontSize: 10,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMacroFields(Map<String, double> previewGrams) {
    switch (_selectedMode) {
      case _MacroInputMode.percentage:
        return [
          _buildMacroFieldCard(
            fieldKey: const Key('macro-carbs-percentage'),
            label: context.tr.translate('carbohydrates'),
            icon: MacroTheme.carbsIcon,
            accentColor: MacroTheme.carbsColor,
            controller: _carbsPercentageController,
            suffix: '%',
            helper:
                '${(previewGrams['carbs'] ?? 0).round()}g  •  ${((previewGrams['carbs'] ?? 0) * 4).round()} kcal',
            value: _carbsPercentage,
            step: 1,
            digits: 1,
            onChanged: (value) {
              setState(() {
                _carbsPercentage = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMacroFieldCard(
            fieldKey: const Key('macro-protein-percentage'),
            label: context.tr.translate('protein_full'),
            icon: MacroTheme.proteinIcon,
            accentColor: MacroTheme.proteinColor,
            controller: _proteinPercentageController,
            suffix: '%',
            helper:
                '${(previewGrams['protein'] ?? 0).round()}g  •  ${((previewGrams['protein'] ?? 0) * 4).round()} kcal',
            value: _proteinPercentage,
            step: 1,
            digits: 1,
            onChanged: (value) {
              setState(() {
                _proteinPercentage = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMacroFieldCard(
            fieldKey: const Key('macro-fat-percentage'),
            label: context.tr.translate('fats'),
            icon: MacroTheme.fatIcon,
            accentColor: MacroTheme.fatColor,
            controller: _fatPercentageController,
            suffix: '%',
            helper:
                '${(previewGrams['fat'] ?? 0).round()}g  •  ${((previewGrams['fat'] ?? 0) * 9).round()} kcal',
            value: _fatPercentage,
            step: 1,
            digits: 1,
            onChanged: (value) {
              setState(() {
                _fatPercentage = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildPercentageTotalCard(),
        ];
      case _MacroInputMode.gramsPerKg:
        return [
          _buildMacroFieldCard(
            fieldKey: const Key('macro-carbs-per-kg'),
            label: context.tr.translate('carbohydrates'),
            icon: MacroTheme.carbsIcon,
            accentColor: MacroTheme.carbsColor,
            controller: _carbsPerKgController,
            suffix: 'g/kg',
            helper:
                '${(previewGrams['carbs'] ?? 0).round()}g  •  ${((previewGrams['carbs'] ?? 0) * 4).round()} kcal',
            value: _carbsPerKg,
            step: 0.1,
            digits: 1,
            onChanged: (value) {
              setState(() {
                _carbsPerKg = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMacroFieldCard(
            fieldKey: const Key('macro-protein-per-kg'),
            label: context.tr.translate('protein_full'),
            icon: MacroTheme.proteinIcon,
            accentColor: MacroTheme.proteinColor,
            controller: _proteinPerKgController,
            suffix: 'g/kg',
            helper:
                '${(previewGrams['protein'] ?? 0).round()}g  •  ${((previewGrams['protein'] ?? 0) * 4).round()} kcal',
            value: _proteinPerKg,
            step: 0.1,
            digits: 1,
            onChanged: (value) {
              setState(() {
                _proteinPerKg = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMacroFieldCard(
            fieldKey: const Key('macro-fat-per-kg'),
            label: context.tr.translate('fats'),
            icon: MacroTheme.fatIcon,
            accentColor: MacroTheme.fatColor,
            controller: _fatPerKgController,
            suffix: 'g/kg',
            helper:
                '${(previewGrams['fat'] ?? 0).round()}g  •  ${((previewGrams['fat'] ?? 0) * 9).round()} kcal',
            value: _fatPerKg,
            step: 0.1,
            digits: 1,
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
            fieldKey: const Key('macro-carbs-grams'),
            label: context.tr.translate('carbohydrates'),
            icon: MacroTheme.carbsIcon,
            accentColor: MacroTheme.carbsColor,
            controller: _carbsGramsController,
            suffix: 'g',
            helper: '${(_carbsGrams * 4).round()} kcal',
            value: _carbsGrams,
            step: 5,
            digits: 0,
            onChanged: (value) {
              setState(() {
                _carbsGrams = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMacroFieldCard(
            fieldKey: const Key('macro-protein-grams'),
            label: context.tr.translate('protein_full'),
            icon: MacroTheme.proteinIcon,
            accentColor: MacroTheme.proteinColor,
            controller: _proteinGramsController,
            suffix: 'g',
            helper: '${(_proteinGrams * 4).round()} kcal',
            value: _proteinGrams,
            step: 5,
            digits: 0,
            onChanged: (value) {
              setState(() {
                _proteinGrams = value;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMacroFieldCard(
            fieldKey: const Key('macro-fat-grams'),
            label: context.tr.translate('fats'),
            icon: MacroTheme.fatIcon,
            accentColor: MacroTheme.fatColor,
            controller: _fatGramsController,
            suffix: 'g',
            helper: '${(_fatGrams * 9).round()} kcal',
            value: _fatGrams,
            step: 5,
            digits: 0,
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
    required Key fieldKey,
    required String label,
    required IconData icon,
    required Color accentColor,
    required TextEditingController controller,
    required String suffix,
    required String helper,
    required double value,
    required double step,
    required int digits,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: _panelColor(),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _borderColor()),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MacroTheme.iconBadge(
                icon: icon,
                color: accentColor,
                isDarkMode: widget.isDarkMode,
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.theme.textTheme.titleSmall?.copyWith(
                    color: widget.textColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    helper,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.theme.textTheme.labelSmall?.copyWith(
                      color: widget.textColor.withValues(alpha: 0.68),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _buildStepButton(
                icon: Icons.remove_rounded,
                color: accentColor,
                tooltip: '-${_formatNumber(step, digits: digits)} $suffix',
                onPressed: () => _stepValue(
                  controller: controller,
                  currentValue: value,
                  delta: -step,
                  digits: digits,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _buildMacroInputField(
                  fieldKey: fieldKey,
                  controller: controller,
                  suffix: suffix,
                  accentColor: accentColor,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 9),
              _buildStepButton(
                icon: Icons.add_rounded,
                color: accentColor,
                tooltip: '+${_formatNumber(step, digits: digits)} $suffix',
                onPressed: () => _stepValue(
                  controller: controller,
                  currentValue: value,
                  delta: step,
                  digits: digits,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      color: color,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _stepValue({
    required TextEditingController controller,
    required double currentValue,
    required double delta,
    required int digits,
    required ValueChanged<double> onChanged,
  }) {
    final nextValue =
        (currentValue + delta).clamp(0, double.infinity).toDouble();
    onChanged(nextValue);
    _setControllerValue(
      controller,
      _formatNumber(nextValue, digits: digits),
    );
  }

  Widget _buildMacroInputField({
    required Key fieldKey,
    required TextEditingController controller,
    required String suffix,
    required Color accentColor,
    required ValueChanged<double> onChanged,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
      ],
      textAlign: TextAlign.center,
      style: widget.theme.textTheme.titleMedium?.copyWith(
        color: widget.textColor,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        isDense: true,
        suffixText: suffix,
        suffixStyle: widget.theme.textTheme.titleSmall?.copyWith(
          color: widget.textColor.withValues(alpha: 0.5),
          fontWeight: FontWeight.w800,
        ),
        filled: true,
        fillColor: _surfaceColor(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _borderColor()),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      onChanged: (rawValue) {
        onChanged(_tryParseDouble(rawValue) ?? 0);
      },
    );
  }

  Widget _buildPercentageTotalCard() {
    final total = _percentageTotal();
    final isValid = (total - 100).abs() < 0.01;
    final toneColor = isValid ? _successColor() : _warningColor();
    final progress = (total / 100).clamp(0.0, 1.0);

    return Container(
      key: const Key('macro-percentage-total'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: toneColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.timelapse_rounded,
            color: toneColor,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.translate('macro_editor_total_percentage'),
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: widget.textColor.withValues(alpha: 0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(toneColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatNumber(total)}%',
                style: widget.theme.textTheme.titleMedium?.copyWith(
                  color: toneColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!isValid)
                InkWell(
                  onTap: _normalizePercentages,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, bottom: 2),
                    child: Text(
                      context.tr.translate('macro_editor_fix_total'),
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: toneColor,
                        fontWeight: FontWeight.w900,
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

  void _normalizePercentages() {
    final totalValue = _percentageTotal();
    if (totalValue <= 0) {
      return;
    }

    setState(() {
      _carbsPercentage = (_carbsPercentage / totalValue) * 100;
      _proteinPercentage = (_proteinPercentage / totalValue) * 100;
      _fatPercentage = 100 - _carbsPercentage - _proteinPercentage;
      _errorMessage = null;
      _syncAllControllers();
    });
  }

  Widget _buildManualTools({
    required Color accentColor,
    required bool showBalanceAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surfaceColor(),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: accentColor, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr.translate('macro_editor_switches_manual_mode'),
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.68),
                    height: 1.3,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (showBalanceAction) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('macro-fill-carbs'),
                onPressed: _fillRemainingCaloriesWithCarbs,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(
                  context.tr.translate('macro_editor_fill_remaining_carbs'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    final errorColor =
        widget.isDarkMode ? const Color(0xFFFF9C9C) : const Color(0xFFC83F49);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: errorColor, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: widget.theme.textTheme.bodySmall?.copyWith(
                color: errorColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter({
    required Color accentColor,
    required Color accentForegroundColor,
    required double bottomSafePadding,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + bottomSafePadding),
      decoration: BoxDecoration(
        color: widget.cardColor,
        border: Border(top: BorderSide(color: _borderColor())),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: widget.isDarkMode ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: widget.textColor.withValues(alpha: 0.68),
              minimumSize: const Size(86, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              context.tr.translate('cancel'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              key: const Key('macro-save'),
              onPressed: _canSave() ? _saveChanges : null,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  context.tr.translate('save_changes'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: accentForegroundColor,
                disabledBackgroundColor:
                    widget.textColor.withValues(alpha: 0.09),
                disabledForegroundColor:
                    widget.textColor.withValues(alpha: 0.36),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _differenceColor(double difference) {
    if (difference.abs() <= 1) {
      return _successColor();
    }
    if (difference > 0) {
      return _warningColor();
    }
    return widget.isDarkMode
        ? const Color(0xFF80CFF0)
        : const Color(0xFF247FA5);
  }

  Color _successColor() {
    return widget.isDarkMode
        ? const Color(0xFF7FE0B8)
        : const Color(0xFF168A68);
  }

  Color _warningColor() {
    return widget.isDarkMode
        ? const Color(0xFFFFCF7D)
        : const Color(0xFFB66A10);
  }

  Color _panelColor() {
    return widget.isDarkMode ? AppTheme.darkComponentColor : AppTheme.cardColor;
  }

  Color _surfaceColor() {
    return widget.isDarkMode
        ? Colors.white.withValues(alpha: 0.055)
        : const Color(0xFFF2F5F7);
  }

  Color _borderColor() {
    return widget.textColor.withValues(alpha: widget.isDarkMode ? 0.1 : 0.075);
  }
}
