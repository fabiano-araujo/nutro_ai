import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';
import '../utils/food_json_parser.dart';
import '../providers/daily_meals_provider.dart';
import '../utils/ai_interaction_helper.dart';
import '../services/auth_service.dart';
import '../services/favorite_food_service.dart';
import '../services/ad_manager.dart';
import 'meal_card.dart';

/// Widget que exibe alimentos parseados do JSON da IA
/// Permite adicionar os alimentos a uma refeição do dia
class FoodJsonDisplay extends StatefulWidget {
  final String message;
  final bool isDarkMode;
  final DateTime selectedDate;
  final String? messageId; // ID da mensagem do chat para vinculação
  final VoidCallback?
      onDeleteMessage; // Callback para excluir a mensagem do chat

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
  List<Meal> _meals = const [];
  bool _isAdded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _parseMeals();
    // Adicionar automaticamente após o frame atual para garantir acesso ao contexto
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final mealsProvider =
          Provider.of<DailyMealsProvider>(context, listen: false);
      await mealsProvider.ready;
      if (!mounted) return;

      // Verificar se já existe uma refeição com este messageId no provider
      if (widget.messageId != null) {
        final existingMeals =
            mealsProvider.getMealsByMessageId(widget.messageId!);
        if (existingMeals.isNotEmpty) {
          // Já foi adicionado anteriormente, apenas atualizar o estado local
          setState(() {
            _isAdded = true;
            _meals = existingMeals;
          });
          return;
        }
      }

      // Só adiciona se ainda não foi adicionado
      if (!_isAdded) {
        _addMealsToDay();
      }
    });
  }

  @override
  void didUpdateWidget(FoodJsonDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _parseMeals();
      // Não adicionamos automaticamente na atualização para evitar duplicatas em streaming
      // ou atualizações parciais, assumindo que a criação inicial captura a intenção.
      // Se necessário, lógica adicional pode ser implementada aqui.
    }
  }

  void _parseMeals() {
    final fallbackMealType = AIInteractionHelper.getMealTypeByTime();
    final entries = FoodJsonParser.parseMealEntriesFromMessage(
      widget.message,
      fallbackMealType: fallbackMealType,
    );

    if (entries.isEmpty) {
      _meals = [
        Meal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: fallbackMealType,
          foods: const [],
          dateTime: widget.selectedDate,
        ),
      ];
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _meals = List.generate(entries.length, (index) {
      final entry = entries[index];
      return FoodJsonParser.createMealFromFoods(
        entry.foods,
        type: entry.mealType,
        dateTime: widget.selectedDate,
      ).copyWith(id: 'parsed-$timestamp-$index');
    });
  }

  void _handleMealTypeChanged(int index, MealType newType) {
    if (index < 0 || index >= _meals.length) return;

    setState(() {
      _meals = List<Meal>.from(_meals)
        ..[index] = _meals[index].copyWith(type: newType);
    });
  }

  void _handleMealUpdated(int index, Meal updatedMeal) {
    if (index < 0 || index >= _meals.length) return;
    final shouldDeleteMessage = updatedMeal.foods.isEmpty && _meals.length == 1;

    if (_isAdded) {
      final mealsProvider =
          Provider.of<DailyMealsProvider>(context, listen: false);

      if (updatedMeal.foods.isEmpty) {
        mealsProvider.deleteMeal(updatedMeal.id);
      } else {
        mealsProvider.updateMeal(updatedMeal);
      }
    }

    if (!mounted) return;

    setState(() {
      final updatedMeals = List<Meal>.from(_meals);
      if (updatedMeal.foods.isEmpty) {
        updatedMeals.removeAt(index);
        if (updatedMeals.isEmpty) {
          _isAdded = false;
        }
      } else {
        updatedMeals[index] = updatedMeal;
      }
      _meals = updatedMeals;
    });

    if (shouldDeleteMessage) {
      widget.onDeleteMessage?.call();
    }
  }

  void _handleDelete(int index) {
    if (!_isAdded) return;
    if (index < 0 || index >= _meals.length) return;

    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
    final meal = _meals[index];

    mealsProvider.deleteMeal(meal.id);

    if (mounted) {
      setState(() {
        final updatedMeals = List<Meal>.from(_meals)..removeAt(index);
        _meals = updatedMeals;
        _isAdded = updatedMeals.isNotEmpty;
      });
    }

    if (_meals.isEmpty) {
      widget.onDeleteMessage?.call();
    }
  }

  void _addMealsToDay() {
    if (_meals.every((meal) => meal.foods.isEmpty) || _isAdded) return;

    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final addedMeals = <Meal>[];

    for (var i = 0; i < _meals.length; i++) {
      final meal = _meals[i];
      if (meal.foods.isEmpty) continue;

      // Criar cópia da refeição com a data selecionada e messageId
      final mealToAdd = meal.copyWith(
        dateTime: widget.selectedDate,
        id: '$timestamp-$i',
        messageId: _messageIdForMeal(i),
      );

      mealsProvider.addMeal(mealToAdd);
      addedMeals.add(mealToAdd);

      // Conta cada refeição registrada, mas o intersticial é tentado uma vez.
      AdManager.notifyMealRegistered();
    }

    if (mounted) {
      setState(() {
        _isAdded = true;
        _meals = addedMeals;
      });
    }

    AdManager.maybeShowMealDoneInterstitial();

    // Fire-and-forget: salva nos recentes e aplica macros dos favoritos
    for (final meal in addedMeals) {
      _processWithFavorites(meal);
    }
  }

  String? _messageIdForMeal(int index) {
    final messageId = widget.messageId;
    if (messageId == null || messageId.isEmpty) {
      return null;
    }
    if (_meals.length == 1) {
      return messageId;
    }
    return '$messageId#meal-$index';
  }

  /// Envia os alimentos para o servidor, salva nos recentes e, se houver
  /// match com favoritos ou recentes, atualiza os macros e marca a fonte
  /// (favorito > recente > IA) na refeicao ja adicionada.
  Future<void> _processWithFavorites(Meal meal) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = authService.token;
      if (token == null || token.isEmpty) return;

      // Monta payload para o endpoint /favorites/process-ai
      final foods = meal.foods.map((food) {
        final nutrient =
            food.nutrients?.isNotEmpty == true ? food.nutrients!.first : null;
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

      // Reconstroi a lista de Food com source + macros (quando aplicavel).
      // Mesmo sem match (source = ai) atualizamos para gravar a fonte no Food.
      final updatedFoods = List.generate(meal.foods.length, (i) {
        if (i >= processed.length) return meal.foods[i];
        final p = processed[i];
        final source = foodSourceFromString(p['source'] as String?);
        final sourceId = p['sourceId'] as int?;
        final original = meal.foods[i];

        if (source == FoodSource.ai) {
          return original.copyWith(source: source, sourceId: sourceId);
        }

        final macros = p['macros'] as Map<String, dynamic>?;
        if (macros == null) {
          return original.copyWith(source: source, sourceId: sourceId);
        }

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

        // Preserva os macros originais da IA para permitir voltar via
        // "Estimativa da IA" no source picker (ver meal_card.dart).
        final aiSnapshot = original.aiNutrients ?? original.nutrients;

        return original.copyWith(
          nutrients: [updatedNutrient],
          source: source,
          sourceId: sourceId,
          aiNutrients: aiSnapshot,
        );
      });

      final updatedMeal = meal.copyWith(foods: updatedFoods);

      if (!mounted) return;
      final mealsProvider =
          Provider.of<DailyMealsProvider>(context, listen: false);
      mealsProvider.updateMeal(updatedMeal);

      if (mounted) {
        setState(() {
          _meals = _meals
              .map((current) =>
                  current.id == updatedMeal.id ? updatedMeal : current)
              .toList();
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
    final visibleMeals = _meals.where((meal) => meal.foods.isNotEmpty).toList();
    if (visibleMeals.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(visibleMeals.length, (index) {
        final meal = visibleMeals[index];
        final sourceIndex = _meals.indexWhere((item) => item.id == meal.id);
        final mealIndex = sourceIndex == -1 ? index : sourceIndex;

        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
          child: MealCard(
            key: ValueKey('food-json-meal-${meal.id}'),
            meal: meal,
            onMealTypeChanged: (newType) =>
                _handleMealTypeChanged(mealIndex, newType),
            onMealUpdated: (updatedMeal) =>
                _handleMealUpdated(mealIndex, updatedMeal),
            onDelete: _isAdded ? () => _handleDelete(mealIndex) : null,
            topContentPadding: 16,
          ),
        );
      }),
    );
  }
}
