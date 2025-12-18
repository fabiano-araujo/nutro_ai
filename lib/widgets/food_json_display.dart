import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meal_model.dart';
import '../utils/food_json_parser.dart';
import '../providers/daily_meals_provider.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import 'meal_card.dart';

/// Widget que exibe alimentos parseados do JSON da IA
/// Permite adicionar os alimentos a uma refeição do dia
class FoodJsonDisplay extends StatefulWidget {
  final String message;
  final bool isDarkMode;
  final DateTime selectedDate;

  const FoodJsonDisplay({
    Key? key,
    required this.message,
    required this.isDarkMode,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<FoodJsonDisplay> createState() => _FoodJsonDisplayState();
}

class _FoodJsonDisplayState extends State<FoodJsonDisplay> {
  late Meal _meal;
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    _parseMeal();
  }

  @override
  void didUpdateWidget(FoodJsonDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _parseMeal();
    }
  }

  void _parseMeal() {
    final jsonStr = FoodJsonParser.extractFoodJson(widget.message);
    if (jsonStr != null) {
      final foods = FoodJsonParser.parseFoodJson(jsonStr);
      if (foods != null && foods.isNotEmpty) {
        _meal = FoodJsonParser.createMealFromFoods(
          foods,
          type: MealType.freeMeal,
          dateTime: widget.selectedDate,
        );
        return;
      }
    }
    // Fallback para meal vazia
    _meal = Meal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MealType.freeMeal,
      foods: [],
      dateTime: widget.selectedDate,
    );
  }

  void _handleMealTypeChanged(MealType newType) {
    setState(() {
      _meal = _meal.copyWith(type: newType);
    });
  }

  void _handleMealUpdated(Meal updatedMeal) {
    setState(() {
      _meal = updatedMeal;
    });
  }

  void _addMealToDay() {
    if (_meal.foods.isEmpty) return;

    final mealsProvider = Provider.of<DailyMealsProvider>(context, listen: false);

    // Criar cópia da refeição com a data selecionada
    final mealToAdd = _meal.copyWith(
      dateTime: widget.selectedDate,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    mealsProvider.addMeal(mealToAdd);

    setState(() {
      _isAdded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.translate('meal_added_success')),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_meal.foods.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MealCard(
          meal: _meal,
          onMealTypeChanged: _handleMealTypeChanged,
          onMealUpdated: _handleMealUpdated,
          topContentPadding: 16,
        ),

        // Botão de adicionar refeição
        if (!_isAdded)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addMealToDay,
                icon: Icon(Icons.add_circle_outline, size: 20),
                label: Text(context.tr.translate('add_meal')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    context.tr.translate('meal_added'),
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
