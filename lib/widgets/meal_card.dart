import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../screens/food_page.dart';
import '../providers/meal_types_provider.dart';

class MealCard extends StatefulWidget {
  final Meal meal;
  final VoidCallback? onEditFood;
  final Function(MealType)? onMealTypeChanged;
  final VoidCallback? onAddFood;
  final double topContentPadding;

  const MealCard({
    Key? key,
    required this.meal,
    this.onEditFood,
    this.onMealTypeChanged,
    this.onAddFood,
    this.topContentPadding = 16,
  }) : super(key: key);

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  bool showMealOptions = false;
  final Map<int, bool> expandedFoods = {};

  void toggleFood(int index) {
    setState(() {
      expandedFoods[index] = !(expandedFoods[index] ?? false);
    });
  }

  List<MealTypeOption> getMealOptions(BuildContext context) {
    final provider = Provider.of<MealTypesProvider>(context, listen: false);
    return provider.mealTypes.map((config) {
      return MealTypeOption(
        type: _getMealTypeFromId(config.id),
        name: config.name,
        emoji: config.emoji,
      );
    }).toList();
  }

  MealType _getMealTypeFromId(String id) {
    // Map custom IDs to MealType enum
    switch (id) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
      case 'morning_snack':
      case 'afternoon_snack':
        return MealType.snack;
      default:
        return MealType.freeMeal;
    }
  }

  String getMealTypeName(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return context.tr.translate('breakfast');
      case MealType.lunch:
        return context.tr.translate('lunch');
      case MealType.dinner:
        return context.tr.translate('dinner');
      case MealType.snack:
        return context.tr.translate('snack');
      case MealType.freeMeal:
        return context.tr.translate('free_meal');
    }
  }

  Widget _buildMacroCardGradient({
    required String icon,
    required String label,
    required String value,
    required String unit,
    required Color startColor,
    required Color endColor,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor.withValues(alpha: isDarkMode ? 0.2 : 0.1),
            endColor.withValues(alpha: isDarkMode ? 0.12 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: startColor.withValues(alpha: isDarkMode ? 0.2 : 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.65),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final double topPadding =
        widget.topContentPadding < 0 ? 0 : widget.topContentPadding;

    return Card(
      margin: EdgeInsets.only(top: 0, bottom: 12),
      elevation: 1.5,
      shadowColor: isDarkMode
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Items
          if (widget.meal.foods.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.meal.foods.asMap().entries.map((entry) {
                    final index = entry.key;
                    final food = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: _FoodItem(
                        food: food,
                        isExpanded: expandedFoods[index] ?? false,
                        onToggle: () => toggleFood(index),
                        onEdit: widget.onEditFood,
                        isDarkMode: isDarkMode,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

          // Divisor sutil
          if (widget.meal.foods.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SizedBox(height: 12),

          // Macros Summary
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildMacroCardGradient(
                    icon: '🔥',
                    label: 'Cal',
                    value: widget.meal.totalCalories.toStringAsFixed(0),
                    unit: 'kcal',
                    startColor: const Color(0xFFFF6B9D),
                    endColor: const Color(0xFFFFA06B),
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMacroCardGradient(
                    icon: '💪',
                    label: 'Prot',
                    value: widget.meal.totalProtein.toStringAsFixed(1),
                    unit: 'g',
                    startColor: const Color(0xFF9575CD),
                    endColor: const Color(0xFFBA68C8),
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMacroCardGradient(
                    icon: '🌾',
                    label: 'Carb',
                    value: widget.meal.totalCarbs.toStringAsFixed(1),
                    unit: 'g',
                    startColor: const Color(0xFFFFB74D),
                    endColor: const Color(0xFFFF9800),
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMacroCardGradient(
                    icon: '🥑',
                    label: 'Gord',
                    value: widget.meal.totalFat.toStringAsFixed(1),
                    unit: 'g',
                    startColor: const Color(0xFF4DB6AC),
                    endColor: const Color(0xFF26A69A),
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
          ),

          // Header - Nome da refeição com ícones (no final)
          Container(
            padding: EdgeInsets.fromLTRB(16, 2, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nome da refeição com botão para expandir opções
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => showMealOptions = !showMealOptions),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            getMealTypeName(widget.meal.type),
                            style: TextStyle(
                              color: secondaryTextColor.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            showMealOptions
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: secondaryTextColor.withValues(alpha: 0.5),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Ícones de ação
                Row(
                  children: [
                    if (widget.onEditFood != null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onEditFood,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: secondaryTextColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // More options action
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: secondaryTextColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Meal Options - Show when clicked
          if (showMealOptions)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppTheme.darkComponentColor
                    : Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: getMealOptions(context).map((option) {
                  final isSelected = option.type == widget.meal.type;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.onMealTypeChanged?.call(option.type);
                          setState(() => showMealOptions = false);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode
                                    ? AppTheme.primaryColor
                                        .withValues(alpha: 0.15)
                                    : AppTheme.primaryColor
                                        .withValues(alpha: 0.08))
                                : backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.3),
                                    width: 1.5)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(
                                option.emoji,
                                style: TextStyle(fontSize: 22),
                              ),
                              SizedBox(width: 12),
                              Text(
                                option.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          if (showMealOptions) SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FoodItem extends StatelessWidget {
  final Food food;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final bool isDarkMode;

  const _FoodItem({
    Key? key,
    required this.food,
    required this.isExpanded,
    required this.onToggle,
    this.onEdit,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodPage(food: food),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            children: [
              Row(
                children: [
                  // Food Image/Emoji
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Text(
                      food.emoji,
                      style: TextStyle(fontSize: 28),
                    ),
                  ),
                  SizedBox(width: 10),
                  // Food Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1),
                        Text(
                          food.amount ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor.withValues(alpha: 0.75),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Calories + Expand
                  Row(
                    children: [
                      Text(
                        '${food.calories}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(width: 1),
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(width: 6),
                      InkWell(
                        onTap: onToggle,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: secondaryTextColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Expanded Macros for individual food
              if (isExpanded)
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MacroCard(
                          label: 'P',
                          fullName: context.tr.translate('protein'),
                          value: food.protein.toStringAsFixed(1),
                          unit: 'g',
                          color: Color(0xFF9575CD),
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _MacroCard(
                          label: 'C',
                          fullName: context.tr.translate('carbs'),
                          value: food.carbs.toStringAsFixed(1),
                          unit: 'g',
                          color: Color(0xFFA1887F),
                          isDarkMode: isDarkMode,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _MacroCard(
                          label: 'F',
                          fullName: context.tr.translate('fats'),
                          value: food.fat.toStringAsFixed(1),
                          unit: 'g',
                          color: Color(0xFF90A4AE),
                          isDarkMode: isDarkMode,
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
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String fullName;
  final String value;
  final String unit;
  final Color color;
  final bool isDarkMode;

  const _MacroCard({
    Key? key,
    required this.label,
    required this.fullName,
    required this.value,
    required this.unit,
    required this.color,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            fullName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(height: 0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
