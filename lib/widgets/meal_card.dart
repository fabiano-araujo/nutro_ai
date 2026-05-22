import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../screens/food_page.dart';
import '../providers/meal_types_provider.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/favorite_food_service.dart';
import '../i18n/language_controller.dart';

class MealCard extends StatefulWidget {
  final Meal meal;
  final VoidCallback? onEditFood;
  final Function(MealType)? onMealTypeChanged;
  final VoidCallback? onAddFood;
  final Function(Meal)? onMealUpdated;
  final VoidCallback? onDelete;
  final double topContentPadding;

  const MealCard({
    Key? key,
    required this.meal,
    this.onEditFood,
    this.onMealTypeChanged,
    this.onAddFood,
    this.onMealUpdated,
    this.onDelete,
    this.topContentPadding = 16,
  }) : super(key: key);

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  // State for editing
  late Meal _currentMeal;

  // Loading state per food index
  final Map<int, bool> _loadingFoods = {};

  // Modo simples (só kcal) vs detalhado (macros completos)
  bool _simpleView = true;

  @override
  void initState() {
    super.initState();
    _currentMeal = widget.meal;
  }

  @override
  void didUpdateWidget(MealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync quando o id muda (refeicao diferente) OU quando algum alimento
    // mudou de fonte/macros (ex.: _processWithFavorites aplicou favorito async).
    if (widget.meal.id != oldWidget.meal.id ||
        _foodsDiffer(widget.meal.foods, oldWidget.meal.foods)) {
      _currentMeal = widget.meal;
    }
  }

  bool _foodsDiffer(List<Food> a, List<Food> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.name != y.name) return true;
      if (x.source != y.source) return true;
      if (x.sourceId != y.sourceId) return true;
      if (x.calories != y.calories) return true;
      if (x.protein != y.protein) return true;
      if (x.carbs != y.carbs) return true;
      if (x.fat != y.fat) return true;
    }
    return false;
  }

  void _notifyMealUpdated() {
    widget.onMealUpdated?.call(_currentMeal);
  }

  /// Substitui um alimento pela versao trazida do bottom sheet de fontes
  /// (favorito, recente ou IA) e propaga a atualizacao para o provider.
  void _replaceFood(int index, Food newFood) {
    if (index < 0 || index >= _currentMeal.foods.length) return;
    final newFoods = List<Food>.from(_currentMeal.foods);
    newFoods[index] = newFood;
    setState(() {
      _currentMeal = _currentMeal.copyWith(foods: newFoods);
    });
    _notifyMealUpdated();
  }

  /// Mostra BottomSheet para selecionar o tipo de refeição
  void _showMealTypeBottomSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final secondaryTextColor =
        isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: secondaryTextColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Text(
              context.tr.translate('select_meal_type'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
            SizedBox(height: 16),
            // Meal options
            ...getMealOptions(context).map((option) {
              final isSelected = option.type == _currentMeal.type;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      widget.onMealTypeChanged?.call(option.type);
                      setState(() {
                        _currentMeal = _currentMeal.copyWith(type: option.type);
                      });
                      _notifyMealUpdated();
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15)
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08))
                            : (isDarkMode
                                ? AppTheme.darkComponentColor
                                : Color(0xFFF5F7FA)),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3),
                                width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            option.emoji,
                            style: TextStyle(fontSize: 24),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : secondaryTextColor,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
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

      // Prompt simples - o servidor injeta instruções de idioma automaticamente
      final prompt = '$foodDescription';

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

  /// Constrói a descrição do alimento evitando duplicação
  /// Ex: Se amount="2 ovos mexidos" e name="Ovos mexidos", retorna apenas "2 ovos mexidos"
  String _buildFoodDescription(String? amount, String name) {
    final amountStr = (amount ?? '').trim();
    final nameStr = name.trim();

    if (amountStr.isEmpty) return nameStr;
    if (nameStr.isEmpty) return amountStr;

    // Verifica se amount já contém o nome (case-insensitive)
    if (amountStr.toLowerCase().contains(nameStr.toLowerCase())) {
      return amountStr;
    }

    // Verifica se o nome já contém o amount (caso inverso)
    if (nameStr.toLowerCase().contains(amountStr.toLowerCase())) {
      return nameStr;
    }

    return '$amountStr $nameStr';
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

  /// Abre diretamente a edição de todos os alimentos
  void _showEditOptionsMenu() {
    _showEditAllFoodsBottomSheet();
  }

  /// Mostra menu de mais opções (excluir, etc)
  void _showMoreOptionsMenu() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
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
              // Opção: Excluir refeição
              if (widget.onDelete != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Color(0xFFE57373),
                  ),
                  title: Text(
                    context.tr.translate('delete_meal'),
                    style: TextStyle(
                      color: Color(0xFFE57373),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    context.tr.translate('delete_meal_confirm'),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete();
                  },
                ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Confirma a exclusão da refeição
  Future<void> _confirmDelete() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          context.tr.translate('delete_meal'),
          style: TextStyle(
            color:
                isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor,
          ),
        ),
        content: Text(
          context.tr.translate('delete_meal_confirm'),
          style: TextStyle(
            color: isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              context.tr.translate('cancel'),
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr.translate('delete'),
              style: TextStyle(color: Color(0xFFE57373)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete?.call();
    }
  }

  Future<void> _showEditAllFoodsBottomSheet() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final editableFoods = List<Food>.from(_currentMeal.foods);
    final controllers = <TextEditingController>[];

    // Criar controllers para cada alimento
    for (final food in editableFoods) {
      final initialText = _buildFoodDescription(food.amount, food.name);
      controllers.add(TextEditingController(text: initialText));
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(top: 12, bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Lista de alimentos
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        itemCount: editableFoods.length,
                        itemBuilder: (context, index) {
                          final food = editableFoods[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controllers[index],
                                    autofocus: index == 0,
                                    decoration: InputDecoration(
                                      prefixIcon: Padding(
                                        padding:
                                            EdgeInsets.only(left: 12, right: 8),
                                        child: Text(
                                          food.emoji,
                                          style: TextStyle(fontSize: 22),
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          BoxConstraints(minWidth: 0),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: isDarkMode
                                          ? AppTheme.darkComponentColor
                                          : Color(0xFFF8F9FA),
                                    ),
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: isDarkMode
                                          ? AppTheme.darkTextColor
                                          : AppTheme.textPrimaryColor,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Tooltip(
                                  message: context.tr.translate('remove'),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      onTap: () {
                                        final removedController =
                                            controllers.removeAt(index);
                                        removedController.dispose();
                                        setSheetState(() {
                                          editableFoods.removeAt(index);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Color(0xFFE57373).withValues(
                                              alpha: isDarkMode ? 0.18 : 0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Color(0xFFE57373).withValues(
                                                alpha:
                                                    isDarkMode ? 0.32 : 0.18),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 24,
                                          color: Color(0xFFE57373),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Botões
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(
                                  color: isDarkMode
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                context.tr.translate('cancel'),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _applyAllEdits(editableFoods, controllers);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(sheetContext).colorScheme.primary,
                                foregroundColor: Theme.of(sheetContext)
                                    .colorScheme
                                    .onPrimary,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Theme.of(sheetContext)
                                        .colorScheme
                                        .onPrimary,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    context.tr.translate('save'),
                                    style: TextStyle(
                                      color: Theme.of(sheetContext)
                                          .colorScheme
                                          .onPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    for (final controller in controllers) {
      controller.dispose();
    }
  }

  /// Aplica todas as edições de uma vez
  void _applyAllEdits(
    List<Food> editedFoods,
    List<TextEditingController> controllers,
  ) {
    final changedDescriptions = <int, String>{};

    for (int i = 0; i < editedFoods.length; i++) {
      final newDescription = controllers[i].text.trim();
      final initialText =
          _buildFoodDescription(editedFoods[i].amount, editedFoods[i].name);

      if (newDescription.isEmpty) continue;

      // Se a descrição mudou, manda para a IA depois de aplicar remoções.
      if (newDescription != initialText) {
        changedDescriptions[i] = newDescription;
      }
    }

    setState(() {
      _currentMeal = _currentMeal.copyWith(foods: List<Food>.from(editedFoods));
    });
    _notifyMealUpdated();

    for (final entry in changedDescriptions.entries) {
      _fetchNutritionFromAI(entry.key, entry.value);
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

  /// Macro compacto inline - com label visível para melhor compreensão
  Widget _buildCompactMacro({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool isDarkMode,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                letterSpacing: 0.2,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.75),
                    height: 1.1,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final double topPadding =
        widget.topContentPadding < 0 ? 0 : widget.topContentPadding;

    final card = Container(
      margin: EdgeInsets.only(top: 0, bottom: 12),
      // Sutil — borda fina + cantos arredondados para indicar que é um card,
      // mas sem balão pesado (estilo ChatGPT)
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MODO SIMPLES: linha única + botão "Ver detalhes"
          if (_simpleView) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _simpleView = false),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, topPadding == 0 ? 14 : topPadding, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _currentMeal.totalCalories.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentMeal.foods.isEmpty
                                  ? getMealTypeName(_currentMeal.type)
                                  : '${_currentMeal.foods.map((f) => f.name).join(' · ')} · ${getMealTypeName(_currentMeal.type)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Ver detalhes',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // MODO DETALHADO: layout completo original
          if (!_simpleView) ...[
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
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: _FoodItem(
                          food: food,
                          isDarkMode: isDarkMode,
                          onSwap: (newFood) => _replaceFood(index, newFood),
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

            SizedBox(height: 8),

            // Macros Summary - com toggle simples/detalhado
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _simpleView
                        ? Row(
                            children: [
                              Text(
                                _currentMeal.totalCalories.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'kcal',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildCompactMacro(
                                label: context.tr.translate('calories'),
                                value: _currentMeal.totalCalories
                                    .toStringAsFixed(0),
                                unit: 'kcal',
                                color: MacroTheme.caloriesColor,
                                isDarkMode: isDarkMode,
                              ),
                              _buildCompactMacro(
                                label: context.tr.translate('protein'),
                                value: _currentMeal.totalProtein
                                    .toStringAsFixed(1),
                                unit: 'g',
                                color: MacroTheme.proteinColor,
                                isDarkMode: isDarkMode,
                              ),
                              _buildCompactMacro(
                                label: context.tr.translate('carbs'),
                                value:
                                    _currentMeal.totalCarbs.toStringAsFixed(1),
                                unit: 'g',
                                color: MacroTheme.carbsColor,
                                isDarkMode: isDarkMode,
                              ),
                              _buildCompactMacro(
                                label: context.tr.translate('fats'),
                                value: _currentMeal.totalFat.toStringAsFixed(1),
                                unit: 'g',
                                color: MacroTheme.fatColor,
                                isDarkMode: isDarkMode,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            // Header - Nome da refeição com ícones (no final)
            Container(
              padding: EdgeInsets.fromLTRB(16, 0, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nome da refeição com botão para abrir BottomSheet
                  Expanded(
                    child: InkWell(
                      onTap: _showMealTypeBottomSheet,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.06)
                              : primaryColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : primaryColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.restaurant_menu_rounded,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.78)
                                    : primaryColor,
                                size: 17,
                              ),
                            ),
                            SizedBox(width: 9),
                            Flexible(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${context.tr.translate('meal')}: ',
                                      style: TextStyle(
                                        color: secondaryTextColor.withValues(
                                            alpha: 0.62),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text: getMealTypeName(_currentMeal.type),
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                                .withValues(alpha: 0.9)
                                            : AppTheme.textPrimaryColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.expand_more_rounded,
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : primaryColor.withValues(alpha: 0.75),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Ícones de ação
                  Row(
                    children: [
                      // Recolher para modo simples
                      Tooltip(
                        message: 'Ocultar detalhes',
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => setState(() => _simpleView = true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 20,
                                color:
                                    secondaryTextColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Botão de editar com menu
                      Tooltip(
                        message: context.tr.translate('edit_foods'),
                        child: Material(
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
                                color:
                                    secondaryTextColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: context.tr.translate('more_options'),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showMoreOptionsMenu,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.more_vert_rounded,
                                size: 18,
                                color:
                                    secondaryTextColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ], // fim de if (!_simpleView)
        ],
      ),
    );

    // Se tem callback de delete, envolve com Dismissible para swipe-to-delete e swipe-to-edit
    if (widget.onDelete != null) {
      return Dismissible(
        key: Key('meal_${_currentMeal.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Swipe para direita = Editar
            _showEditOptionsMenu();
            return false; // Não dismissar, apenas abrir edição
          } else {
            // Swipe para esquerda = Deletar
            return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor:
                        isDarkMode ? AppTheme.darkCardColor : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      context.tr.translate('delete_meal'),
                      style: TextStyle(
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    content: Text(
                      context.tr.translate('delete_meal_confirm'),
                      style: TextStyle(
                        color: isDarkMode
                            ? Color(0xFFAEB7CE)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          context.tr.translate('cancel'),
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          context.tr.translate('delete'),
                          style: TextStyle(color: Color(0xFFE57373)),
                        ),
                      ),
                    ],
                  ),
                ) ??
                false;
          }
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            widget.onDelete?.call();
          }
        },
        // Background para swipe direita (editar)
        background: Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                context.tr.translate('edit'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // SecondaryBackground para swipe esquerda (deletar)
        secondaryBackground: Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Color(0xFFE57373),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr.translate('delete'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
        child: card,
      );
    }

    return card;
  }
}

class _FoodItem extends StatefulWidget {
  final Food food;
  final bool isDarkMode;
  final ValueChanged<Food>? onSwap;

  const _FoodItem({
    Key? key,
    required this.food,
    required this.isDarkMode,
    this.onSwap,
  }) : super(key: key);

  @override
  State<_FoodItem> createState() => _FoodItemState();
}

class _FoodItemState extends State<_FoodItem> {
  bool _loadingAlternatives = false;

  ({IconData icon, Color color, String label}) _sourceMeta(
      BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    switch (widget.food.source) {
      case FoodSource.favorite:
        return (
          icon: Icons.star_rounded,
          color: const Color(0xFFFFB300),
          label: 'Favorito',
        );
      case FoodSource.recent:
        return (
          icon: Icons.history_rounded,
          color: primary,
          label: 'Recente',
        );
      case FoodSource.ai:
        return (
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF14B8A6),
          label: 'IA',
        );
    }
  }

  Food _applyAlternativeMacros(Map<String, dynamic> alt, FoodSource source) {
    final original = widget.food;
    final originalNutrient = original.nutrients?.isNotEmpty == true
        ? original.nutrients!.first
        : null;

    final baseAmount = (alt['baseAmount'] is num)
        ? (alt['baseAmount'] as num).toDouble()
        : double.tryParse('${alt['baseAmount']}') ?? 100.0;
    final foodAmount = originalNutrient?.servingSize ?? 100.0;
    final ratio = baseAmount > 0 ? foodAmount / baseAmount : 1.0;

    double parse(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final calories = (parse(alt['calories']) * ratio).round().toDouble();
    final protein = (parse(alt['protein']) * ratio * 10).roundToDouble() / 10;
    final carbs = (parse(alt['carbs']) * ratio * 10).roundToDouble() / 10;
    final fat = (parse(alt['fat']) * ratio * 10).roundToDouble() / 10;
    final fiber = (parse(alt['fiber']) * ratio * 10).roundToDouble() / 10;

    final updatedNutrient = Nutrient(
      idFood: originalNutrient?.idFood ?? 0,
      servingSize: originalNutrient?.servingSize ?? 100.0,
      servingUnit: originalNutrient?.servingUnit ?? 'g',
      calories: calories,
      protein: protein,
      carbohydrate: carbs,
      fat: fat,
      dietaryFiber: fiber,
    );

    return original.copyWith(
      nutrients: [updatedNutrient],
      source: source,
      sourceId: alt['id'] as int?,
    );
  }

  Future<void> _openSourcePicker() async {
    if (_loadingAlternatives) return;

    setState(() => _loadingAlternatives = true);

    Map<String, dynamic>? alternatives;
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = auth.token;
      if (token != null && token.isNotEmpty) {
        final service = FavoriteFoodService(token: token);
        alternatives = await service.getAlternatives(widget.food.name);
      }
    } catch (e) {
      debugPrint('[_FoodItem] erro ao buscar alternativas: $e');
    }

    if (!mounted) return;
    setState(() => _loadingAlternatives = false);

    final favorite = alternatives?['favorite'] as Map<String, dynamic>?;
    final recent = alternatives?['recent'] as Map<String, dynamic>?;
    final currentSource = widget.food.source;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = widget.isDarkMode;
        final bg = isDark ? AppTheme.darkCardColor : Colors.white;
        final textColor = isDark ? Colors.white : AppTheme.textPrimaryColor;
        final secondary =
            isDark ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: secondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(widget.food.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.food.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Escolha a fonte dos macros',
                style: TextStyle(
                    fontSize: 12, color: secondary.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 16),

              // Favorito
              if (favorite != null)
                _SourceOption(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFB300),
                  title: 'Seu favorito',
                  subtitle: _macrosSummary(favorite),
                  selected: currentSource == FoodSource.favorite,
                  isDarkMode: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSwap?.call(
                      _applyAlternativeMacros(favorite, FoodSource.favorite),
                    );
                  },
                ),

              // Recente
              if (recent != null)
                _SourceOption(
                  icon: Icons.history_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  title: 'Recente',
                  subtitle: _macrosSummary(recent),
                  selected: currentSource == FoodSource.recent,
                  isDarkMode: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSwap?.call(
                      _applyAlternativeMacros(recent, FoodSource.recent),
                    );
                  },
                ),

              // IA atual (sempre presente como referencia)
              _SourceOption(
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFF14B8A6),
                title: 'Estimativa da IA',
                subtitle:
                    '${widget.food.calories} kcal · ${widget.food.protein.toStringAsFixed(1)}p · ${widget.food.carbs.toStringAsFixed(1)}c · ${widget.food.fat.toStringAsFixed(1)}g',
                selected: currentSource == FoodSource.ai,
                isDarkMode: isDark,
                onTap: () => Navigator.pop(ctx),
              ),

              const SizedBox(height: 12),

              // Caso nao tenha favorito/recente, oferece cadastrar
              if (favorite == null && recent == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Voce ainda nao tem versoes salvas para ${widget.food.name}. Edite o alimento para salvar como favorito.',
                    style: TextStyle(
                        fontSize: 12, color: secondary.withValues(alpha: 0.8)),
                  ),
                ),

              const SizedBox(height: 8),
              _SourceOption(
                icon: Icons.tune_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
                title: 'Editar manualmente',
                subtitle: 'Digite os macros manualmente',
                selected: false,
                isDarkMode: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  _openManualMacroEditor();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFoodPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodPage(food: widget.food),
      ),
    );
  }

  Future<void> _openManualMacroEditor() async {
    final food = widget.food;
    final caloriesCtrl =
        TextEditingController(text: food.calories.toString());
    final proteinCtrl =
        TextEditingController(text: food.protein.toStringAsFixed(1));
    final carbsCtrl =
        TextEditingController(text: food.carbs.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: food.fat.toStringAsFixed(1));

    final originalNutrient = food.nutrients?.isNotEmpty == true
        ? food.nutrients!.first
        : null;
    final fiberCtrl = TextEditingController(
      text: (originalNutrient?.dietaryFiber ?? 0).toStringAsFixed(1),
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = widget.isDarkMode;
        final bg = isDark ? AppTheme.darkCardColor : Colors.white;
        final textColor = isDark ? Colors.white : AppTheme.textPrimaryColor;
        final secondary =
            isDark ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: secondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(food.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        food.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Edite os macros manualmente',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MacroField(
                        controller: caloriesCtrl,
                        label: context.tr.translate('calories'),
                        suffix: 'kcal',
                        color: MacroTheme.caloriesColor,
                        icon: MacroTheme.caloriesIcon,
                        isDarkMode: isDark,
                        allowDecimal: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MacroField(
                        controller: proteinCtrl,
                        label: context.tr.translate('protein'),
                        suffix: 'g',
                        color: MacroTheme.proteinColor,
                        icon: MacroTheme.proteinIcon,
                        isDarkMode: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MacroField(
                        controller: carbsCtrl,
                        label: context.tr.translate('carbs'),
                        suffix: 'g',
                        color: MacroTheme.carbsColor,
                        icon: MacroTheme.carbsIcon,
                        isDarkMode: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MacroField(
                        controller: fatCtrl,
                        label: context.tr.translate('fat'),
                        suffix: 'g',
                        color: MacroTheme.fatColor,
                        icon: MacroTheme.fatIcon,
                        isDarkMode: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MacroField(
                  controller: fiberCtrl,
                  label: context.tr.translate('fiber'),
                  suffix: 'g',
                  color: secondary,
                  icon: Icons.eco_rounded,
                  isDarkMode: isDark,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: secondary.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Text(
                          context.tr.translate('cancel'),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          double parse(String v) {
                            final cleaned = v.replaceAll(',', '.').trim();
                            return double.tryParse(cleaned) ?? 0.0;
                          }

                          final updatedNutrient = (originalNutrient ??
                                  Nutrient(
                                    idFood: 0,
                                    servingSize: 100.0,
                                    servingUnit: 'g',
                                  ))
                              .copyWith(
                            calories: parse(caloriesCtrl.text),
                            protein: parse(proteinCtrl.text),
                            carbohydrate: parse(carbsCtrl.text),
                            fat: parse(fatCtrl.text),
                            dietaryFiber: parse(fiberCtrl.text),
                          );

                          Navigator.pop(ctx);
                          widget.onSwap?.call(
                            food.copyWith(nutrients: [updatedNutrient]),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          context.tr.translate('save'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    caloriesCtrl.dispose();
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
    fiberCtrl.dispose();
  }

  String _macrosSummary(Map<String, dynamic> data) {
    final cal = data['calories'] ?? 0;
    double parse(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final p = parse(data['protein']);
    final c = parse(data['carbs']);
    final f = parse(data['fat']);
    final base = data['baseAmount'] ?? 100;
    final unit = data['baseUnit'] ?? 'g';
    return '$cal kcal · ${p.toStringAsFixed(1)}p · ${c.toStringAsFixed(1)}c · ${f.toStringAsFixed(1)}g  (por $base$unit)';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final food = widget.food;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final meta = _sourceMeta(context);
    final rowBg = isDarkMode
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.black.withValues(alpha: 0.018);
    final rowBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.045);
    final iconBg = meta.color.withValues(alpha: isDarkMode ? 0.16 : 0.10);
    final iconBorder = meta.color.withValues(alpha: isDarkMode ? 0.24 : 0.16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openSourcePicker,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rowBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Tooltip(
                message: context.tr.translate('edit'),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    onTap: _openFoodPage,
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: iconBorder),
                      ),
                      child: Text(
                        food.emoji,
                        style: const TextStyle(fontSize: 25),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              // Food Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Badge de fonte (toca para abrir bottom sheet de troca)
                        _SourceBadge(
                          icon: meta.icon,
                          color: meta.color,
                          label: meta.label,
                          loading: _loadingAlternatives,
                          isDarkMode: isDarkMode,
                          onTap: _openSourcePicker,
                        ),
                      ],
                    ),
                    if ((food.amount ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        food.amount ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor.withValues(alpha: 0.78),
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Calories + Edit button
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${food.calories}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor.withValues(alpha: 0.82),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.58),
                        height: 1,
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

/// Chip pequeno que mostra a fonte (favorito/recente/IA) e abre o bottom sheet
/// de troca quando tocado.
class _SourceBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool loading;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const _SourceBadge({
    Key? key,
    required this.icon,
    required this.color,
    required this.label,
    required this.loading,
    required this.isDarkMode,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = color.withValues(alpha: isDarkMode ? 0.18 : 0.10);
    final borderColor = color.withValues(alpha: 0.30);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha de opcao no bottom sheet do seletor de fonte.
class _SourceOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _SourceOption({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final secondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: isDarkMode ? 0.15 : 0.08)
                  : (isDarkMode
                      ? AppTheme.darkComponentColor
                      : const Color(0xFFF5F7FA)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.4)
                    : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final Color color;
  final IconData icon;
  final bool isDarkMode;
  final bool allowDecimal;

  const _MacroField({
    Key? key,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.color,
    required this.icon,
    required this.isDarkMode,
    this.allowDecimal = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final secondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final bg = isDarkMode
        ? AppTheme.darkComponentColor
        : const Color(0xFFF5F7FA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(
                      decimal: allowDecimal),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
