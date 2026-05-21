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
    if (widget.meal.id != oldWidget.meal.id) {
      _currentMeal = widget.meal;
    }
  }

  void _notifyMealUpdated() {
    widget.onMealUpdated?.call(_currentMeal);
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
            Padding(
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
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
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
                            color: isDarkMode ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _simpleView = false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      'Ver detalhes',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
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
                    ..._currentMeal.foods.map((food) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: _FoodItem(
                          food: food,
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

class _FoodItem extends StatelessWidget {
  final Food food;
  final bool isDarkMode;

  const _FoodItem({
    Key? key,
    required this.food,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
