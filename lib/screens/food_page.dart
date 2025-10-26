import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/food_model.dart';
import '../theme/app_theme.dart';

class FoodPage extends StatefulWidget {
  final Food food;

  const FoodPage({
    Key? key,
    required this.food,
  }) : super(key: key);

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  late TextEditingController _servingSizeController;
  late double _currentServingSize;

  @override
  void initState() {
    super.initState();
    _currentServingSize = widget.food.nutrients?.first.servingSize ?? 100.0;
    _servingSizeController = TextEditingController(
      text: _currentServingSize.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _servingSizeController.dispose();
    super.dispose();
  }

  double _getScaledValue(double? value) {
    if (value == null) return 0.0;
    final originalServing = widget.food.nutrients?.first.servingSize ?? 100.0;
    return (value / originalServing) * _currentServingSize;
  }

  void _updateServingSize(String value) {
    final newValue = double.tryParse(value);
    if (newValue != null && newValue > 0) {
      setState(() {
        _currentServingSize = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;
    final cardColor = isDarkMode
        ? AppTheme.darkCardColor
        : Colors.white;
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode
        ? Color(0xFFAEB7CE)
        : AppTheme.textSecondaryColor;

    final nutrient = widget.food.nutrients?.first;
    final calories = _getScaledValue(nutrient?.calories);
    final protein = _getScaledValue(nutrient?.protein);
    final carbs = _getScaledValue(nutrient?.carbohydrate);
    final fat = _getScaledValue(nutrient?.fat);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            slivers: [
              // Top App Bar
              SliverAppBar(
                expandedHeight: 0,
                floating: false,
                pinned: true,
                backgroundColor: backgroundColor,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.star_outline, color: textColor),
                    onPressed: () {
                      // TODO: Add to favorites
                    },
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Image
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: widget.food.imageUrl != null
                              ? Image.network(
                                  widget.food.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        widget.food.emoji,
                                        style: TextStyle(fontSize: 80),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    widget.food.emoji,
                                    style: TextStyle(fontSize: 80),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Headline and Brand
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.food.name,
                            style: AppTheme.headingLarge.copyWith(
                              color: textColor,
                              fontSize: 32,
                            ),
                          ),
                          if (widget.food.brand != null) ...[
                            SizedBox(height: 4),
                            Text(
                              widget.food.brand!,
                              style: AppTheme.bodyLarge.copyWith(
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Serving Size Selector
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Serving Size field
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 12, bottom: 8),
                                  child: Text(
                                    'Serving Size',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ),
                                TextField(
                                  controller: _servingSizeController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDarkMode
                                            ? AppTheme.darkBorderColor
                                            : AppTheme.dividerColor,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDarkMode
                                            ? AppTheme.darkBorderColor
                                            : AppTheme.dividerColor,
                                        width: 2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  onChanged: _updateServingSize,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          // Unit field
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 12, bottom: 8),
                                  child: Text(
                                    'Unit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDarkMode
                                          ? AppTheme.darkBorderColor
                                          : AppTheme.dividerColor,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Container (${_currentServingSize.toStringAsFixed(0)}${nutrient?.servingUnit ?? 'g'})',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.unfold_more,
                                        color: secondaryTextColor,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Macro Breakdown Card
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Macro Breakdown',
                              style: AppTheme.headingSmall.copyWith(
                                color: textColor,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pie Chart
                                _MacroPieChart(
                                  protein: protein,
                                  carbs: carbs,
                                  fat: fat,
                                  calories: calories,
                                  isDarkMode: isDarkMode,
                                ),
                                SizedBox(width: 24),
                                // Macro Labels
                                Expanded(
                                  child: Column(
                                    children: [
                                      _MacroRow(
                                        label: 'Protein',
                                        value: '${protein.toStringAsFixed(1)}g',
                                        color: Color(0xFF9575CD),
                                        isDarkMode: isDarkMode,
                                      ),
                                      SizedBox(height: 12),
                                      _MacroRow(
                                        label: 'Carbs',
                                        value: '${carbs.toStringAsFixed(1)}g',
                                        color: Color(0xFFA1887F),
                                        isDarkMode: isDarkMode,
                                      ),
                                      SizedBox(height: 12),
                                      _MacroRow(
                                        label: 'Fat',
                                        value: '${fat.toStringAsFixed(1)}g',
                                        color: Color(0xFF90A4AE),
                                        isDarkMode: isDarkMode,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Nutrition Facts Card
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode
                                ? AppTheme.darkBorderColor
                                : AppTheme.dividerColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Macronutrients Section
                            Text(
                              'Macronutrients',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),

                            Divider(
                              color: isDarkMode ? Colors.white24 : Colors.black12,
                              height: 24,
                              thickness: 1,
                            ),

                            // Calories
                            _MacroNutrientRow(
                              label: 'Calories',
                              value: '${calories.toStringAsFixed(0)} kcal',
                              isDarkMode: isDarkMode,
                            ),

                            SizedBox(height: 12),

                            // Protein
                            _MacroNutrientRow(
                              label: 'Protein',
                              value: '${protein.toStringAsFixed(0)} g',
                              isDarkMode: isDarkMode,
                            ),

                            SizedBox(height: 12),

                            // Total Carbohydrates Group
                            _MacroNutrientRow(
                              label: 'Total Carbohydrates',
                              value: '${carbs.toStringAsFixed(0)} g',
                              isDarkMode: isDarkMode,
                            ),
                            if (nutrient?.dietaryFiber != null)
                              _SubNutrientRow(
                                label: 'Dietary Fiber',
                                value: '${_getScaledValue(nutrient?.dietaryFiber).toStringAsFixed(0)} g',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.sugars != null)
                              _SubNutrientRow(
                                label: 'Sugars',
                                value: '${_getScaledValue(nutrient?.sugars).toStringAsFixed(0)} g',
                                isDarkMode: isDarkMode,
                              ),

                            SizedBox(height: 12),

                            // Total Fat Group
                            _MacroNutrientRow(
                              label: 'Total Fat',
                              value: '${fat.toStringAsFixed(0)} g',
                              isDarkMode: isDarkMode,
                            ),
                            if (nutrient?.saturatedFat != null)
                              _SubNutrientRow(
                                label: 'Saturated Fat',
                                value: '${_getScaledValue(nutrient?.saturatedFat).toStringAsFixed(1)} g',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.transFat != null)
                              _SubNutrientRow(
                                label: 'Trans Fat',
                                value: '${_getScaledValue(nutrient?.transFat).toStringAsFixed(0)} g',
                                isDarkMode: isDarkMode,
                              ),

                            SizedBox(height: 24),

                            // Micronutrients Section
                            Text(
                              'Micronutrients',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),

                            Divider(
                              color: isDarkMode ? Colors.white24 : Colors.black12,
                              height: 24,
                              thickness: 1,
                            ),

                            // Micronutrients List
                            if (nutrient?.cholesterol != null)
                              _MicroNutrientRow(
                                label: 'Cholesterol',
                                value: '${_getScaledValue(nutrient?.cholesterol).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.cholesterol != null)
                              SizedBox(height: 12),

                            if (nutrient?.sodium != null)
                              _MicroNutrientRow(
                                label: 'Sodium',
                                value: '${_getScaledValue(nutrient?.sodium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.sodium != null)
                              SizedBox(height: 12),

                            if (nutrient?.potassium != null)
                              _MicroNutrientRow(
                                label: 'Potassium',
                                value: '${_getScaledValue(nutrient?.potassium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.potassium != null)
                              SizedBox(height: 12),

                            if (nutrient?.calcium != null)
                              _MicroNutrientRow(
                                label: 'Calcium',
                                value: '${_getScaledValue(nutrient?.calcium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.calcium != null)
                              SizedBox(height: 12),

                            if (nutrient?.iron != null)
                              _MicroNutrientRow(
                                label: 'Iron',
                                value: '${_getScaledValue(nutrient?.iron).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.iron != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminD != null)
                              _MicroNutrientRow(
                                label: 'Vitamin D',
                                value: '${_getScaledValue(nutrient?.vitaminD).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminD != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminA != null)
                              _MicroNutrientRow(
                                label: 'Vitamin A',
                                value: '${_getScaledValue(nutrient?.vitaminA).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminA != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminC != null)
                              _MicroNutrientRow(
                                label: 'Vitamin C',
                                value: '${_getScaledValue(nutrient?.vitaminC).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminC != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminB6 != null)
                              _MicroNutrientRow(
                                label: 'Vitamin B6',
                                value: '${_getScaledValue(nutrient?.vitaminB6).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminB6 != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminB12 != null)
                              _MicroNutrientRow(
                                label: 'Vitamin B12',
                                value: '${_getScaledValue(nutrient?.vitaminB12).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
            ],
          ),

          // Floating Action Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withValues(alpha: 0.0),
                    backgroundColor,
                  ],
                ),
              ),
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add to meal
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                ),
                child: Text(
                  'Add to Meal',
                  style: AppTheme.buttonText.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Macro Pie Chart Widget
class _MacroPieChart extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double calories;
  final bool isDarkMode;

  const _MacroPieChart({
    Key? key,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate percentages (calories from macros)
    final proteinCal = protein * 4;
    final carbsCal = carbs * 4;
    final fatCal = fat * 9;
    final total = proteinCal + carbsCal + fatCal;

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(120, 120),
            painter: _PieChartPainter(
              proteinPercent: total > 0 ? proteinCal / total : 0,
              carbsPercent: total > 0 ? carbsCal / total : 0,
              fatPercent: total > 0 ? fatCal / total : 0,
              isDarkMode: isDarkMode,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  calories.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  'Calories',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Color(0xFFAEB7CE)
                        : AppTheme.textSecondaryColor,
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

// Pie Chart Painter
class _PieChartPainter extends CustomPainter {
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;
  final bool isDarkMode;

  _PieChartPainter({
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    // Background circle
    final bgPaint = Paint()
      ..color = (isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Draw segments
    double startAngle = -math.pi / 2;

    // Protein segment
    if (proteinPercent > 0) {
      final proteinPaint = Paint()
        ..color = Color(0xFF9575CD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * proteinPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        proteinPaint,
      );
      startAngle += sweepAngle;
    }

    // Carbs segment
    if (carbsPercent > 0) {
      final carbsPaint = Paint()
        ..color = Color(0xFFA1887F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * carbsPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        carbsPaint,
      );
      startAngle += sweepAngle;
    }

    // Fat segment
    if (fatPercent > 0) {
      final fatPaint = Paint()
        ..color = Color(0xFF90A4AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * fatPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        fatPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Macro Row Widget
class _MacroRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDarkMode;

  const _MacroRow({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            color: isDarkMode
                ? AppTheme.darkTextColor
                : AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Macronutrient Row Widget (for main nutrients)
class _MacroNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _MacroNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// Sub-Nutrient Row Widget (for indented items)
class _SubNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _SubNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = isDarkMode
        ? Color(0xFF9CA3AF)
        : Color(0xFF6B7280);

    return Padding(
      padding: EdgeInsets.only(left: 24, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Micronutrient Row Widget (for minerals and vitamins - without bold)
class _MicroNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _MicroNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
