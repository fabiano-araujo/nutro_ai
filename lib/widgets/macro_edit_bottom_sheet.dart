import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/app_localizations_extension.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';

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

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.translate('macro_editor_saved')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewGrams = _previewGrams();
    final previewCalories = _previewCalories();
    final targetCalories = widget.provider.caloriesGoal.toDouble();
    final difference = previewCalories - targetCalories;
    final isPercentageMode = _selectedMode == _MacroInputMode.percentage;
    final accentColor = widget.isDarkMode
        ? AppTheme.primaryColorDarkMode
        : AppTheme.primaryColor;

    return Container(
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
                padding: const EdgeInsets.fromLTRB(24, 0, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('edit_macronutrients'),
                            style:
                                widget.theme.textTheme.headlineSmall?.copyWith(
                              color: widget.textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr.translate('macro_editor_subtitle'),
                            style: widget.theme.textTheme.bodyMedium?.copyWith(
                              color: widget.textColor.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: widget.textColor),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: widget.textColor.withValues(alpha: 0.08),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                      if (_errorMessage != null) _buildErrorBox(_errorMessage!),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: widget.cardColor,
                  border: Border(
                    top: BorderSide(
                      color: widget.textColor.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: widget.textColor.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(context.tr.translate('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _canSave() ? _saveChanges : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          context.tr.translate('save_changes'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }

  Widget _buildTargetCard({
    required Color accentColor,
    required double previewCalories,
    required double targetCalories,
    required double difference,
  }) {
    final toneColor = difference.abs() <= 1
        ? Colors.green
        : difference > 0
            ? Colors.orange
            : accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: widget.isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: widget.isDarkMode ? 0.24 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('macro_editor_current_target'),
            style: widget.theme.textTheme.bodySmall?.copyWith(
              color: widget.textColor.withValues(alpha: 0.68),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  label: context.tr.translate('macro_editor_goal_mode_label'),
                  value: context.tr.translate(
                    widget.provider.useCalculatedGoals
                        ? 'macro_editor_goal_mode_calculated'
                        : 'macro_editor_goal_mode_manual',
                  ),
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  label: context.tr.translate('macro_editor_current_target'),
                  value: '${targetCalories.round()} kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  label: context.tr.translate('macro_editor_new_target'),
                  value: '${previewCalories.round()} kcal',
                  valueColor: toneColor,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  label: context.tr.translate('macro_editor_difference'),
                  value:
                      '${difference >= 0 ? '+' : ''}${difference.round()} kcal',
                  valueColor: toneColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBlock({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: widget.theme.textTheme.bodySmall?.copyWith(
            color: widget.textColor.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: widget.theme.textTheme.titleMedium?.copyWith(
            color: valueColor ?? widget.textColor,
            fontWeight: FontWeight.w700,
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
          context.tr.translate('adjust_percentages_or_grams'),
          style: widget.theme.textTheme.titleSmall?.copyWith(
            color: widget.textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                mode: _MacroInputMode.percentage,
                label: context.tr.translate('macro_mode_percentage'),
                hint: context.tr.translate('macro_mode_percentage_hint'),
                accentColor: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeCard(
                mode: _MacroInputMode.gramsPerKg,
                label: context.tr.translate('macro_mode_grams_per_kg'),
                hint: context.tr.translate('macro_mode_grams_per_kg_hint'),
                accentColor: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeCard(
                mode: _MacroInputMode.grams,
                label: context.tr.translate('macro_mode_grams'),
                hint: context.tr.translate('macro_mode_grams_hint'),
                accentColor: accentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required _MacroInputMode mode,
    required String label,
    required String hint,
    required Color accentColor,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: widget.isDarkMode ? 0.22 : 0.14)
              : widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? accentColor
                : widget.textColor.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: widget.theme.textTheme.bodySmall?.copyWith(
                color: widget.textColor.withValues(alpha: 0.64),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
      side: BorderSide(
        color: widget.textColor.withValues(alpha: 0.1),
      ),
    );
  }

  List<Widget> _buildMacroFields(Map<String, double> previewGrams) {
    switch (_selectedMode) {
      case _MacroInputMode.percentage:
        return [
          _buildMacroFieldCard(
            label: context.tr.translate('carbohydrates'),
            icon: Icons.grain_rounded,
            accentColor: const Color(0xFFB08968),
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
            icon: Icons.fitness_center_rounded,
            accentColor: const Color(0xFF8E6CEF),
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
            icon: Icons.water_drop_rounded,
            accentColor: const Color(0xFF7DA0B6),
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
            icon: Icons.grain_rounded,
            accentColor: const Color(0xFFB08968),
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
            icon: Icons.fitness_center_rounded,
            accentColor: const Color(0xFF8E6CEF),
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
            icon: Icons.water_drop_rounded,
            accentColor: const Color(0xFF7DA0B6),
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
            icon: Icons.grain_rounded,
            accentColor: const Color(0xFFB08968),
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
            icon: Icons.fitness_center_rounded,
            accentColor: const Color(0xFF8E6CEF),
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
            icon: Icons.water_drop_rounded,
            accentColor: const Color(0xFF7DA0B6),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.textColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: widget.theme.textTheme.titleSmall?.copyWith(
                    color: widget.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  helper,
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.textColor.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: widget.theme.textTheme.titleMedium?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: suffix,
                filled: true,
                fillColor: widget.cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: widget.textColor.withValues(alpha: 0.12),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageTotalCard() {
    final total = _percentageTotal();
    final isValid = (total - 100).abs() < 0.01;
    final toneColor = isValid ? Colors.green : Colors.orange;

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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${total.round()}%',
                  style: widget.theme.textTheme.titleLarge?.copyWith(
                    color: toneColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
                  _proteinPercentage = (_proteinPercentage / totalValue) * 100;
                  _fatPercentage = 100 - _carbsPercentage - _proteinPercentage;
                  _errorMessage = null;
                  _syncAllControllers();
                });
              },
              child: Text(
                context.tr.translate('macro_editor_fix_total'),
              ),
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
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
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
}
