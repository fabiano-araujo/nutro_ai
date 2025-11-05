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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return Card(
      margin: EdgeInsets.only(top: 0, bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Items
          if (widget.meal.foods.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

          // Macros Summary
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 70,
              child: Row(
                children: [
                  // Calories - Container retangular maior
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 54,
                        padding: EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                              AppTheme.primaryColor.withValues(alpha: isDarkMode ? 0.12 : 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: isDarkMode ? 0.3 : 0.2),
                            width: 1,
                          ),
                        ),
                        child: _MacroCardModern(
                          label: context.tr.translate('calories'),
                          value: widget.meal.totalCalories.toStringAsFixed(0),
                          unit: 'kcal',
                          color: AppTheme.primaryColor,
                          isDarkMode: isDarkMode,
                          isMain: true,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // P, C, F - Quadrados menores
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Expanded(
                          child: _MacroCardModern(
                            label: context.tr.translate('protein'),
                            value: widget.meal.totalProtein.toStringAsFixed(1),
                            unit: 'g',
                            color: Color(0xFF9575CD),
                            isDarkMode: isDarkMode,
                            isMain: false,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _MacroCardModern(
                            label: context.tr.translate('carbs'),
                            value: widget.meal.totalCarbs.toStringAsFixed(1),
                            unit: 'g',
                            color: Color(0xFFA1887F),
                            isDarkMode: isDarkMode,
                            isMain: false,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _MacroCardModern(
                            label: context.tr.translate('fats'),
                            value: widget.meal.totalFat.toStringAsFixed(1),
                            unit: 'g',
                            color: Color(0xFF90A4AE),
                            isDarkMode: isDarkMode,
                            isMain: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Header - Nome da refeição com ícones (no final)
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nome da refeição com botão para expandir opções
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => showMealOptions = !showMealOptions),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            getMealTypeName(widget.meal.type),
                            style: AppTheme.headingSmall.copyWith(
                              color: secondaryTextColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            showMealOptions
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: secondaryTextColor,
                            size: 22,
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
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: secondaryTextColor,
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
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: secondaryTextColor,
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
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDarkMode ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.08))
                                : backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1.5)
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
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? AppTheme.primaryColor : secondaryTextColor,
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
    final backgroundColor =
        isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6);
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  children: [
                    // Food Image/Emoji
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: food.imageUrl != null
                            ? Image.network(
                                food.imageUrl!,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      food.emoji,
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: Text(
                                      food.emoji,
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  food.emoji,
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Food Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            food.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 1),
                          Text(
                            food.amount ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Calories + Expand
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${food.calories}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 2),
                            Text(
                              'kcal',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                          size: 18,
                          color: secondaryTextColor,
                        ),
                      ),
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

class _MacroCardModern extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isDarkMode;
  final bool isMain;

  const _MacroCardModern({
    Key? key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isDarkMode,
    required this.isMain,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isMain) {
      // Card principal para calorias
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(width: 2),
              Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Cards secundários para macros
      return Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDarkMode ? 0.25 : 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor,
                    height: 1,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppTheme.darkTextColor.withValues(alpha: 0.6)
                        : AppTheme.textPrimaryColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}
