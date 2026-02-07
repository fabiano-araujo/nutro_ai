import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../screens/food_page.dart';
import '../providers/meal_types_provider.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../i18n/language_controller.dart';

class MealCard extends StatefulWidget {
  final Meal meal;
  final VoidCallback? onEditFood;
  final Function(MealType)? onMealTypeChanged;
  final VoidCallback? onAddFood;
  final Function(Meal)? onMealUpdated;
  final double topContentPadding;

  const MealCard({
    Key? key,
    required this.meal,
    this.onEditFood,
    this.onMealTypeChanged,
    this.onAddFood,
    this.onMealUpdated,
    this.topContentPadding = 16,
  }) : super(key: key);

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  bool showMealOptions = false;

  // State for editing
  late Meal _currentMeal;

  // Loading state per food index
  final Map<int, bool> _loadingFoods = {};

  @override
  void initState() {
    super.initState();
    _currentMeal = widget.meal;
  }

  @override
  void didUpdateWidget(MealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.meal.id != oldWidget.meal.id) {
      _currentMeal = widget.meal;
    }
  }

  void _notifyMealUpdated() {
    widget.onMealUpdated?.call(_currentMeal);
  }

  /// Atualiza apenas nome e quantidade sem recalcular macros
  void _updateFoodSimple(int index, String name, String amount) {
    setState(() {
      final updatedFood = _currentMeal.foods[index].copyWith(
        name: name,
        amount: amount,
      );
      final List<Food> updatedFoods = List.from(_currentMeal.foods);
      updatedFoods[index] = updatedFood;
      _currentMeal = _currentMeal.copyWith(foods: updatedFoods);
    });
    _notifyMealUpdated();
  }

  /// Busca informações nutricionais da IA para um alimento a partir de sua descrição
  Future<void> _fetchNutritionFromAI(int index, String foodDescription) async {
    setState(() {
      _loadingFoods[index] = true;
    });

    try {
      final aiService = AIService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final languageController =
          Provider.of<LanguageController>(context, listen: false);

      final userId = authService.currentUser?.id.toString() ?? '';
      final languageCode =
          languageController.localeToString(languageController.currentLocale);

      // Prompt para interpretar a descrição livre do alimento
      final prompt = '''
Analise o seguinte alimento: "$foodDescription".
Retorne APENAS um JSON com as informações nutricionais.
Identifique o nome do alimento e a quantidade/porção a partir do texto.
Formato exato:
{"foods":[{"name":"Nome identificado","portion":"Quantidade identificada","macros":{"calories":0,"protein":0,"carbohydrate":0,"fat":0,"serving_size":0,"serving_unit":"g"}}]}
Não inclua texto adicional, apenas o JSON.
''';

      String fullResponse = '';

      await for (final chunk in aiService.getAnswerStream(
        prompt,
        languageCode: languageCode,
        quality: 'bom',
        userId: userId,
        agentType: 'nutrition',
      )) {
        fullResponse += chunk;
      }

      // Tentar parsear o JSON da resposta
      final jsonMatch =
          RegExp(r'\{[\s\S]*"foods"[\s\S]*\}').firstMatch(fullResponse);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final decoded = jsonDecode(jsonStr);

        if (decoded is Map && decoded.containsKey('foods')) {
          final foodsList = decoded['foods'] as List;
          if (foodsList.isNotEmpty) {
            final foodData = foodsList.first as Map<String, dynamic>;
            final macros = foodData['macros'] as Map<String, dynamic>?;
            final detectedName = foodData['name'] as String? ?? foodDescription;
            final detectedPortion = foodData['portion'] as String? ?? '';

            if (macros != null) {
              final newNutrient = Nutrient(
                idFood: 0,
                servingSize: _parseDouble(macros['serving_size']) ??
                    100, // Default fallback
                servingUnit: macros['serving_unit'] as String? ?? 'g',
                calories: _parseDouble(macros['calories']),
                protein: _parseDouble(macros['protein']),
                carbohydrate:
                    _parseDouble(macros['carbohydrate'] ?? macros['carbs']),
                fat: _parseDouble(macros['fat']),
                saturatedFat: _parseDouble(macros['saturated_fat']),
                transFat: _parseDouble(macros['trans_fat']),
                dietaryFiber: _parseDouble(macros['dietary_fiber']),
                sugars: _parseDouble(macros['sugars']),
                cholesterol: _parseDouble(macros['cholesterol']),
                sodium: _parseDouble(macros['sodium']),
                potassium: _parseDouble(macros['potassium']),
                calcium: _parseDouble(macros['calcium']),
                iron: _parseDouble(macros['iron']),
              );

              final updatedFood = _currentMeal.foods[index].copyWith(
                name: detectedName,
                amount: detectedPortion,
                emoji: _getFoodEmoji(detectedName),
                nutrients: [newNutrient],
              );

              setState(() {
                final List<Food> updatedFoods = List.from(_currentMeal.foods);
                updatedFoods[index] = updatedFood;
                _currentMeal = _currentMeal.copyWith(foods: updatedFoods);
                _loadingFoods[index] = false;
              });

              _notifyMealUpdated();
              return;
            }
          }
        }
      }

      // Se falhar, reverte para o texto original sem macros
      _updateFoodSimple(
          index,
          foodDescription.split(' ').length > 1
              ? foodDescription.split(' ').sublist(1).join(' ')
              : foodDescription,
          foodDescription.split(' ')[0]);
    } catch (e) {
      print('Erro ao buscar nutrição da IA: $e');
      // Em erro, apenas mantemos o loading false
    } finally {
      if (mounted) {
        setState(() {
          _loadingFoods[index] = false;
        });
      }
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _getFoodEmoji(String foodName) {
    final name = foodName.toLowerCase();
    if (name.contains('chicken') || name.contains('frango')) return '🍗';
    if (name.contains('beef') || name.contains('carne')) return '🥩';
    if (name.contains('fish') || name.contains('peixe')) return '🐟';
    if (name.contains('rice') || name.contains('arroz')) return '🍚';
    if (name.contains('bread') || name.contains('pão')) return '🍞';
    if (name.contains('salad') || name.contains('salada')) return '🥗';
    if (name.contains('egg') || name.contains('ovo')) return '🥚';
    if (name.contains('milk') || name.contains('leite')) return '🥛';
    if (name.contains('banana')) return '🍌';
    if (name.contains('apple') || name.contains('maçã')) return '🍎';
    return '🍽️';
  }

  /// Mostra o diálogo de edição para um alimento específico
  Future<void> _showEditFoodDialog(int index) async {
    final food = _currentMeal.foods[index];
    // Combinar quantidade e nome para edição única (ex: "150g Arroz branco")
    final initialText = '${food.amount ?? ''} ${food.name}'.trim();
    final descriptionController = TextEditingController(text: initialText);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Text(
                food.emoji,
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr.translate('edit_food'),
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo único de descrição
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: context.tr.translate('food_description'),
                  hintText: 'Ex: 150g de Arroz branco',
                  prefixIcon: Icon(Icons.edit, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? AppTheme.darkComponentColor
                      : Colors.grey[50],
                  helperText: 'A IA identificará o nome e a quantidade.',
                  helperMaxLines: 2,
                ),
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.darkTextColor
                      : AppTheme.textPrimaryColor,
                ),
                autofocus: true,
                maxLines: null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                context.tr.translate('cancel'),
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                final newDescription = descriptionController.text.trim();

                if (newDescription.isEmpty) return;

                // Se mudou algo, manda pra IA
                if (newDescription != initialText) {
                  _fetchNutritionFromAI(index, newDescription);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                context.tr.translate('save'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Mostra menu de opções de edição do card
  void _showEditOptionsMenu() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Opção: Editar todos os alimentos
              ListTile(
                leading: Icon(Icons.edit_note, color: AppTheme.primaryColor),
                title: Text(
                  context.tr.translate('edit_all_foods'),
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),
                subtitle: Text(
                  context.tr.translate('edit_all_foods_desc'),
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditAllFoodsDialog();
                },
              ),
              Divider(height: 1),
              // Opção: Adicionar alimento
              if (widget.onAddFood != null)
                ListTile(
                  leading: Icon(Icons.add_circle_outline, color: Colors.green),
                  title: Text(
                    context.tr.translate('add_food'),
                    style: TextStyle(
                      color: isDarkMode
                          ? AppTheme.darkTextColor
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onAddFood?.call();
                  },
                ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditAllFoodsDialog() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final controllers = <int, TextEditingController>{};

    // Criar controllers para cada alimento
    for (int i = 0; i < _currentMeal.foods.length; i++) {
      final food = _currentMeal.foods[i];
      // Valor inicial: "Quantidade Nome"
      final initialText = '${food.amount ?? ''} ${food.name}'.trim();
      controllers[i] = TextEditingController(text: initialText);
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.tr.translate('edit_all_foods'),
            style: TextStyle(
              color: isDarkMode
                  ? AppTheme.darkTextColor
                  : AppTheme.textPrimaryColor,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _currentMeal.foods.length,
              separatorBuilder: (_, __) => Divider(height: 16),
              itemBuilder: (context, index) {
                final food = _currentMeal.foods[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji e nome do alimento original (apenas para referência)
                    Row(
                      children: [
                        Text(food.emoji, style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            food.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Campo de edição única
                    TextField(
                      controller: controllers[index],
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Ex: 100g de Arroz',
                        fillColor: isDarkMode
                            ? AppTheme.darkComponentColor
                            : Colors.grey[50], // Add fill color
                        filled: true, // Enable filling
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                context.tr.translate('cancel'),
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _applyAllEdits(controllers);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                context.tr.translate('save_all'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    // Dispose controllers is tricky here if we pass them to _applyAllEdits and rely on them there,
    // but since we extract values immediately, we can dispose afterwards or let GC handle if attached to widget tree.
    // Better practice: create a StatefulWidget for the dialog content to handle controllers lifecycle properly,
    // or just let them be garbage collected since they are simple text controllers attached to the dialog.
    // For now, we won't manually dispose to avoid use-after-dispose issues if async operations access them,
    // though in this flow we read text immediately.
  }

  /// Aplica todas as edições de uma vez
  void _applyAllEdits(Map<int, TextEditingController> controllers) {
    for (int i = 0; i < _currentMeal.foods.length; i++) {
      final food = _currentMeal.foods[i];
      if (!controllers.containsKey(i)) continue;

      final newDescription = controllers[i]!.text.trim();
      final initialText = '${food.amount ?? ''} ${food.name}'.trim();

      if (newDescription.isEmpty) continue;

      // Se a descrição mudou, manda para a IA
      if (newDescription != initialText) {
        _fetchNutritionFromAI(i, newDescription);
      }
    }
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
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.65),
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
          if (_currentMeal.foods.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._currentMeal.foods.asMap().entries.map((entry) {
                    final index = entry.key;
                    final food = entry.value;
                    final isLoading = _loadingFoods[index] ?? false;

                    return Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: _FoodItem(
                        food: food,
                        isLoading: isLoading,
                        onEditClick: () => _showEditFoodDialog(index),
                        isDarkMode: isDarkMode,
                      ),
                    );
                  }),
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
                      (isDarkMode ? Colors.white : Colors.black)
                          .withValues(alpha: 0.05),
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
                    value: _currentMeal.totalCalories.toStringAsFixed(0),
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
                    value: _currentMeal.totalProtein.toStringAsFixed(1),
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
                    value: _currentMeal.totalCarbs.toStringAsFixed(1),
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
                    value: _currentMeal.totalFat.toStringAsFixed(1),
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
                            getMealTypeName(_currentMeal.type),
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
                    // Botão de editar com menu
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _showEditOptionsMenu,
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
                  final isSelected = option.type == _currentMeal.type;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.onMealTypeChanged?.call(option.type);
                          setState(() {
                            _currentMeal =
                                _currentMeal.copyWith(type: option.type);
                            showMealOptions = false;
                          });
                          _notifyMealUpdated();
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
  final bool isLoading;
  final VoidCallback? onEditClick;
  final bool isDarkMode;

  const _FoodItem({
    Key? key,
    required this.food,
    this.isLoading = false,
    this.onEditClick,
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
          child: Row(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
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
                        ),
                        // Indicador de loading
                        if (isLoading)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                      ],
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
              // Calories + Edit button
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
                  // Botão de editar (sempre visível)
                  InkWell(
                    onTap: isLoading ? null : onEditClick,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: secondaryTextColor.withValues(alpha: 0.5),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
