import 'package:flutter/material.dart';
import '../models/meal_model.dart';
import '../utils/food_json_parser.dart';
import 'meal_card.dart';

/// Widget que detecta e exibe alimentos em formato JSON nas mensagens da IA
class FoodJsonDisplay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Verificar se há JSON de alimentos na mensagem
    if (!FoodJsonParser.containsFoodJson(message)) {
      return SizedBox.shrink();
    }

    // Extrair JSON e parsear alimentos
    final jsonStr = FoodJsonParser.extractFoodJson(message);
    if (jsonStr == null) {
      return SizedBox.shrink();
    }

    final foods = FoodJsonParser.parseFoodJson(jsonStr);
    if (foods == null || foods.isEmpty) {
      return SizedBox.shrink();
    }

    // Criar uma refeição temporária apenas para exibição
    final meal = FoodJsonParser.createMealFromFoods(
      foods,
      type: MealType.freeMeal,
      dateTime: selectedDate,
    );

    // Apenas mostrar o MealCard (sem adicionar automaticamente)
    return MealCard(
      meal: meal,
      topContentPadding: 12,
      onMealTypeChanged: (newType) {
        // Não faz nada - apenas visualização
      },
      onEditFood: () {
        // Ícone de edição para indicação visual
      },
    );
  }
}
