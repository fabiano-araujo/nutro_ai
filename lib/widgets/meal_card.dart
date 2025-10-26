import 'package:flutter/material.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../screens/food_page.dart';

class MealCard extends StatefulWidget {
  final Meal meal;
  final VoidCallback? onEditFood;
  final Function(MealType)? onMealTypeChanged;
  final VoidCallback? onAddFood;

  const MealCard({
    Key? key,
    required this.meal,
    this.onEditFood,
    this.onMealTypeChanged,
    this.onAddFood,
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

  List<MealTypeOption> get mealOptions => [
        MealTypeOption(
          type: MealType.breakfast,
          name: context.tr.translate('breakfast'),
          emoji: '🌅',
        ),
        MealTypeOption(
          type: MealType.lunch,
          name: context.tr.translate('lunch'),
          emoji: '🌞',
        ),
        MealTypeOption(
          type: MealType.dinner,
          name: context.tr.translate('dinner'),
          emoji: '🌙',
        ),
        MealTypeOption(
          type: MealType.snack,
          name: context.tr.translate('snack'),
          emoji: '🍎',
        ),
      ];

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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Food Items - Always visible at top
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              children: [
                ...widget.meal.foods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final food = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
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

          // Header - Click to show meal options
          InkWell(
            onTap: () => setState(() => showMealOptions = !showMealOptions),
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        getMealTypeName(widget.meal.type),
                        style: AppTheme.headingSmall.copyWith(
                          color: textColor,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        showMealOptions
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: secondaryTextColor,
                        size: 20,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${widget.meal.totalCalories}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Meal Options - Show when clicked
          if (showMealOptions)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppTheme.darkComponentColor
                    : Color(0xFFF7F9FC),
              ),
              child: Column(
                children: mealOptions.map((option) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        widget.onMealTypeChanged?.call(option.type);
                        setState(() => showMealOptions = false);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              option.emoji,
                              style: TextStyle(fontSize: 24),
                            ),
                            SizedBox(width: 12),
                            Text(
                              option.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Macros Summary
          Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MacroCard(
                    label: 'P',
                    fullName: context.tr.translate('protein'),
                    value: widget.meal.totalProtein.toStringAsFixed(1),
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
                    value: widget.meal.totalCarbs.toStringAsFixed(1),
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
                    value: widget.meal.totalFat.toStringAsFixed(1),
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
    final backgroundColor =
        isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6);
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodPage(food: food),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
              children: [
                // Left side: Icon + Name + Edit Icon
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white10 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isDarkMode
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: food.imageUrl != null
                              ? Image.network(
                                  food.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        food.emoji,
                                        style: TextStyle(fontSize: 24),
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: Text(
                                        food.emoji,
                                        style: TextStyle(fontSize: 24),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    food.emoji,
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    food.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (onEdit != null) ...[
                                  SizedBox(width: 4),
                                  InkWell(
                                    onTap: onEdit,
                                    child: Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              food.amount ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Right side: Calories + Expand Icon
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${food.calories}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(width: 2),
                            Text(
                              'kcal',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(width: 8),
                    InkWell(
                      onTap: onToggle,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
