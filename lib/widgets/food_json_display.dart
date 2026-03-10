import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';
import '../utils/food_json_parser.dart';
import '../providers/daily_meals_provider.dart';
import '../utils/ai_interaction_helper.dart';
import '../services/auth_service.dart';
import '../services/favorite_food_service.dart';
import 'meal_card.dart';

/// Widget que exibe alimentos parseados do JSON da IA
/// Permite adicionar os alimentos a uma refeição do dia
class FoodJsonDisplay extends StatefulWidget {
  final String message;
  final bool isDarkMode;
  final DateTime selectedDate;
  final String? messageId; // ID da mensagem do chat para vinculação
  final VoidCallback? onDeleteMessage; // Callback para excluir a mensagem do chat

  const FoodJsonDisplay({
    Key? key,
    required this.message,
    required this.isDarkMode,
    required this.selectedDate,
    this.messageId,
    this.onDeleteMessage,
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
      if (!mounted) return;

      // Verificar se já existe uma refeição com este messageId no provider
      if (widget.messageId != null) {
        final mealsProvider = Provider.of<DailyMealsProvider>(context, listen: false);
        final existingMeal = mealsProvider.getMealByMessageId(widget.messageId!);
        if (existingMeal != null) {
          // Já foi adicionado anteriormente, apenas atualizar o estado local
          setState(() {
            _isAdded = true;
            _meal = existingMeal;
          });
          return;
        }
      }

      // Só adiciona se ainda não foi adicionado
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

    // Extrair tipo de refeição do JSON da IA (ou usar fallback por horário)
    final mealTypeStr = jsonStr != null ? FoodJsonParser.extractMealType(jsonStr) : null;
    final mealType = mealTypeStr != null
        ? FoodJsonParser.mealTypeFromString(mealTypeStr)
        : AIInteractionHelper.getMealTypeByTime();

    if (jsonStr != null) {
      final foods = FoodJsonParser.parseFoodJson(jsonStr);
      if (foods != null && foods.isNotEmpty) {
        _meal = FoodJsonParser.createMealFromFoods(
          foods,
          type: mealType,
          dateTime: widget.selectedDate,
        );
        return;
      }
    }
    // Fallback para meal vazia
    _meal = Meal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: mealType,
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

  void _handleDelete() {
    if (!_isAdded) return;

    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);

    mealsProvider.deleteMeal(_meal.id);

    // Chamar callback para excluir a mensagem do chat também
    widget.onDeleteMessage?.call();

    if (mounted) {
      setState(() {
        _isAdded = false;
        // Limpar a refeição para esconder o card
        _meal = _meal.copyWith(foods: []);
      });
    }
  }

  void _addMealToDay() {
    if (_meal.foods.isEmpty || _isAdded) return;

    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);

    // Criar cópia da refeição com a data selecionada e messageId
    final mealToAdd = _meal.copyWith(
      dateTime: widget.selectedDate,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      messageId: widget.messageId,
    );

    mealsProvider.addMeal(mealToAdd);

    if (mounted) {
      setState(() {
        _isAdded = true;
        _meal = mealToAdd;
      });
    }

    // Fire-and-forget: salva nos recentes e aplica macros dos favoritos
    _processWithFavorites(mealToAdd);
  }

  /// Envia os alimentos para o servidor, salva nos recentes e, se houver
  /// match com favoritos, atualiza os macros da refeição já adicionada.
  Future<void> _processWithFavorites(Meal meal) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      if (token == null || token.isEmpty) return;

      // Monta payload para o endpoint /favorites/process-ai
      final foods = meal.foods.map((food) {
        final nutrient = food.nutrients?.isNotEmpty == true
            ? food.nutrients!.first
            : null;
        return {
          'name': food.name,
          'emoji': food.emoji,
          'portion': food.amount,
          'amount': nutrient?.servingSize ?? 100.0,
          'unit': nutrient?.servingUnit ?? 'g',
          'macros': {
            'calories': food.calories,
            'protein': food.protein,
            'carbohydrate': food.carbs,
            'fat': food.fat,
            'fiber': nutrient?.dietaryFiber ?? 0,
          },
        };
      }).toList();

      final service = FavoriteFoodService(token: token);
      final processed = await service.processAiResponse(foods);
      if (processed == null || !mounted) return;

      // Verifica se algum alimento teve macros substituídos pelos favoritos
      final hasMatch = processed.any((f) => f['fromFavorite'] == true);
      if (!hasMatch) return;

      // Reconstrói a lista de Food com os macros atualizados
      final updatedFoods = List.generate(meal.foods.length, (i) {
        if (i >= processed.length) return meal.foods[i];
        final p = processed[i];
        if (p['fromFavorite'] != true) return meal.foods[i];

        final macros = p['macros'] as Map<String, dynamic>;
        final original = meal.foods[i];
        final originalNutrient = original.nutrients?.isNotEmpty == true
            ? original.nutrients!.first
            : null;

        final updatedNutrient = Nutrient(
          idFood: originalNutrient?.idFood ?? 0,
          servingSize: originalNutrient?.servingSize ?? 100.0,
          servingUnit: originalNutrient?.servingUnit ?? 'g',
          calories: (macros['calories'] as num?)?.toDouble(),
          protein: (macros['protein'] as num?)?.toDouble(),
          carbohydrate: (macros['carbohydrate'] as num?)?.toDouble(),
          fat: (macros['fat'] as num?)?.toDouble(),
          dietaryFiber: (macros['fiber'] as num?)?.toDouble(),
        );

        return original.copyWith(nutrients: [updatedNutrient]);
      });

      final updatedMeal = meal.copyWith(foods: updatedFoods);

      if (!mounted) return;
      final mealsProvider =
          Provider.of<DailyMealsProvider>(context, listen: false);
      mealsProvider.updateMeal(updatedMeal);

      if (mounted) {
        setState(() {
          _meal = updatedMeal;
        });
      }
    } catch (e) {
      // Silencioso — não bloqueia o usuário se o post-processing falhar
      debugPrint('[FoodJsonDisplay] Erro no processamento de favoritos: $e');
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
          onDelete: _isAdded ? _handleDelete : null,
          topContentPadding: 16,
        ),
      ],
    );
  }
}
