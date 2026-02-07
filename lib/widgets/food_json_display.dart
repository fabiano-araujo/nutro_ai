import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meal_model.dart';
import '../utils/food_json_parser.dart';
import '../providers/daily_meals_provider.dart';
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

class _FoodJsonDisplayState extends State<FoodJsonDisplay>
    with AutomaticKeepAliveClientMixin {
  late Meal _meal;
  bool _isAdded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _parseMeal();
    // Adicionar automaticamente após o frame atual para garantir acesso ao contexto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isAdded) {
        _addMealToDay();
      }
    });
  }

  @override
  void didUpdateWidget(FoodJsonDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _parseMeal();
      // Não adicionamos automaticamente na atualização para evitar duplicatas em streaming
      // ou atualizações parciais, assumindo que a criação inicial captura a intenção.
      // Se necessário, lógica adicional pode ser implementada aqui.
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
    // TODO: Considerar atualizar a refeição no provider se ela já foi adicionada
  }

  void _addMealToDay() {
    if (_meal.foods.isEmpty || _isAdded) return;

    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);

    // Criar cópia da refeição com a data selecionada
    final mealToAdd = _meal.copyWith(
      dateTime: widget.selectedDate,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    mealsProvider.addMeal(mealToAdd);

    if (mounted) {
      setState(() {
        _isAdded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
      ],
    );
  }
}
