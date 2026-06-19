import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
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
import '../util/app_constants.dart';
import '../i18n/language_controller.dart';
import '../utils/food_json_parser.dart';
import '../widgets/food_icon.dart';
import '../utils/food_emoji_resolver.dart';

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
  final Map<int, String> _pendingFoodDescriptions = {};

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

  /// Busca informações nutricionais da IA para um alimento a partir de sua descrição
  Future<void> _fetchNutritionFromAI(int index, String foodDescription) async {
    setState(() {
      _loadingFoods[index] = true;
      _pendingFoodDescriptions[index] = foodDescription;
    });

    try {
      final updatedFood = await _generateFoodNutritionFromAI(
        _currentMeal.foods[index],
        foodDescription,
      );

      if (updatedFood != null) {
        setState(() {
          final List<Food> updatedFoods = List.from(_currentMeal.foods);
          updatedFoods[index] = updatedFood;
          _currentMeal = _currentMeal.copyWith(foods: updatedFoods);
          _loadingFoods[index] = false;
          _pendingFoodDescriptions.remove(index);
        });

        _notifyMealUpdated();
        return;
      }

      print('IA nao retornou macros validos para: $foodDescription');
    } catch (e) {
      print('Erro ao buscar nutrição da IA: $e');
      // Em erro, apenas mantemos o loading false
    } finally {
      if (mounted) {
        setState(() {
          _loadingFoods[index] = false;
          _pendingFoodDescriptions.remove(index);
        });
      }
    }
  }

  Future<Food?> _regenerateFoodNutritionForItem(
    int index,
    Food food,
    String foodDescription,
  ) async {
    setState(() {
      _loadingFoods[index] = true;
      _pendingFoodDescriptions[index] = foodDescription;
    });

    try {
      final updatedFood =
          await _generateFoodNutritionFromAI(food, foodDescription);
      if (updatedFood != null && mounted && index < _currentMeal.foods.length) {
        setState(() {
          final updatedFoods = List<Food>.from(_currentMeal.foods);
          updatedFoods[index] = updatedFood;
          _currentMeal = _currentMeal.copyWith(foods: updatedFoods);
        });
        _notifyMealUpdated();
      }
      return updatedFood;
    } finally {
      if (mounted) {
        setState(() {
          _loadingFoods[index] = false;
          _pendingFoodDescriptions.remove(index);
        });
      }
    }
  }

  Future<Food?> _generateFoodNutritionFromAI(
    Food originalFood,
    String foodDescription,
  ) async {
    try {
      final aiService = AIService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final languageController =
          Provider.of<LanguageController>(context, listen: false);

      final userId = authService.currentUser?.id.toString() ?? '';
      final languageCode =
          languageController.localeToString(languageController.currentLocale);

      String fullResponse = '';

      await for (final chunk in aiService.getAnswerStream(
        _buildFoodLoggingPrompt(foodDescription),
        languageCode: languageCode,
        quality: 'bom',
        userId: userId,
        agentType: 'nutrition',
      )) {
        fullResponse += chunk;
      }

      final parsedDescription =
          _parseEditedFoodDescription(foodDescription, originalFood);
      final requestedName = parsedDescription.name;
      final requestedAmount = parsedDescription.amount;
      final mealEntries = FoodJsonParser.parseMealEntriesFromMessage(
        fullResponse,
        fallbackMealType: _currentMeal.type,
      );
      final generatedFoods = mealEntries
          .expand((entry) => entry.foods)
          .where((food) => _hasUsableGeneratedNutrition(food.primaryNutrient))
          .toList();
      if (generatedFoods.isEmpty) return null;

      final generatedFood = generatedFoods.first;
      final generatedNutrients = generatedFood.nutrients;
      final generatedNutrient = generatedFood.primaryNutrient;
      if (generatedNutrients == null ||
          generatedNutrients.isEmpty ||
          generatedNutrient == null) {
        return null;
      }

      if (_editedAmountChanged(requestedAmount, originalFood.amount) &&
          _sameNutritionValues(
              originalFood.primaryNutrient, generatedNutrient)) {
        print('IA retornou macros antigos para: $foodDescription');
        return null;
      }

      var detectedName = generatedFood.name.trim();
      if (detectedName.isEmpty) {
        detectedName = requestedName;
      }
      if (_sameEditedFoodName(detectedName, originalFood.name) &&
          !_sameEditedFoodName(requestedName, originalFood.name)) {
        detectedName = requestedName;
      }
      final detectedPortion = (generatedFood.amount ?? '').trim();

      return originalFood.copyWith(
        name: detectedName,
        amount: detectedPortion.isEmpty
            ? (requestedAmount ?? originalFood.amount)
            : detectedPortion,
        emoji: _getFoodEmoji(detectedName),
        nutrients: generatedNutrients,
        source: FoodSource.ai,
        clearSourceId: true,
        clearAiNutrients: true,
      );
    } catch (e) {
      print('Erro ao gerar nutrição da IA: $e');
      return null;
    }
  }

  String _buildFoodLoggingPrompt(String foodDescription) {
    return 'Prompt intent: food_logging\nUser: ${foodDescription.trim()}';
  }

  bool _hasUsableGeneratedNutrition(Nutrient? nutrient) {
    if (nutrient == null) return false;
    final calories = nutrient.calories ?? 0;
    final protein = nutrient.protein ?? 0;
    final carbs = nutrient.carbohydrate ?? 0;
    final fat = nutrient.fat ?? 0;
    return calories > 0 || protein > 0 || carbs > 0 || fat > 0;
  }

  bool _editedAmountChanged(String? requestedAmount, String? originalAmount) {
    final requested = (requestedAmount ?? '').trim();
    if (requested.isEmpty) return false;
    return _normalizeEditedFoodText(requested) !=
        _normalizeEditedFoodText(originalAmount ?? '');
  }

  bool _sameNutritionValues(Nutrient? left, Nutrient? right) {
    if (left == null || right == null) return false;

    bool same(num? a, num? b) {
      final leftValue = (a ?? 0).toDouble();
      final rightValue = (b ?? 0).toDouble();
      return (leftValue - rightValue).abs() < 0.01;
    }

    return same(left.calories, right.calories) &&
        same(left.protein, right.protein) &&
        same(left.carbohydrate, right.carbohydrate) &&
        same(left.fat, right.fat);
  }

  ({String? amount, String name}) _parseEditedFoodDescription(
    String foodDescription,
    Food fallbackFood,
  ) {
    final description = foodDescription.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (description.isEmpty) {
      return (amount: fallbackFood.amount, name: fallbackFood.name);
    }

    final leadingAmountMatch = RegExp(
      r'^((?:\d+(?:[.,]\d+)?|\d+\s*/\s*\d+)\s*'
      r'(?:fl\s*oz|gramas?|g|mililitros?|ml|quilos?|kg|litros?|l|'
      r'copos?|xicaras?|fatias?|unidades?|colheres?|scoops?|cups?|'
      r'tbsp|tsp|oz)?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(description);

    if (leadingAmountMatch != null) {
      final amount = leadingAmountMatch.group(1)?.trim();
      var name = leadingAmountMatch.group(2)?.trim() ?? '';
      name = name.replaceFirst(
        RegExp(r'^(de|da|do|dos|das)\s+', caseSensitive: false),
        '',
      );
      if (name.isNotEmpty) {
        return (amount: amount, name: name);
      }
    }

    return (amount: fallbackFood.amount, name: description);
  }

  Food _applyEditedFoodDescriptionLocally(
    Food originalFood,
    String foodDescription,
  ) {
    final parsed = _parseEditedFoodDescription(foodDescription, originalFood);
    final name = parsed.name.trim();
    if (name.isEmpty) return originalFood;

    return originalFood.copyWith(
      name: name,
      amount: parsed.amount ?? originalFood.amount,
      emoji: _getFoodEmoji(name),
      source: FoodSource.ai,
      clearSourceId: true,
      clearAiNutrients: true,
    );
  }

  bool _sameEditedFoodName(String left, String right) {
    return _normalizeEditedFoodText(left) == _normalizeEditedFoodText(right);
  }

  String _normalizeEditedFoodText(String value) {
    return _stripEditedFoodDiacritics(value)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _stripEditedFoodDiacritics(String value) {
    return value
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
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
    return resolveFoodEmoji(foodName);
  }

  /// Abre diretamente a edição de todos os alimentos
  void _showEditOptionsMenu() {
    _showEditAllFoodsBottomSheet();
  }

  /// Menu único de ações da refeição (editar alimentos, recolher, excluir).
  void _showMoreOptionsMenu() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconNeutral =
        isDarkMode ? Colors.white.withValues(alpha: 0.78) : Colors.grey[700];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      shape: const RoundedRectangleBorder(
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
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Editar alimentos
              ListTile(
                leading: Icon(Icons.edit_outlined, color: iconNeutral),
                title: Text(context.tr.translate('edit_foods')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditOptionsMenu();
                },
              ),
              // Excluir refeição
              if (widget.onDelete != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFE57373),
                  ),
                  title: Text(
                    context.tr.translate('delete_meal'),
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete();
                  },
                ),
              const SizedBox(height: 8),
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
    final result = await showModalBottomSheet<_EditAllFoodsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return _EditAllFoodsSheet(
          foods: _currentMeal.foods,
          isDarkMode: isDarkMode,
          buildFoodDescription: _buildFoodDescription,
        );
      },
    );

    if (!mounted || result == null) return;
    _applyAllEdits(result.foods, result.descriptions);
  }

  /// Aplica todas as edições de uma vez
  void _applyAllEdits(
    List<Food> editedFoods,
    List<String> descriptions,
  ) {
    final changedDescriptions = <int, String>{};
    final updatedFoods = List<Food>.from(editedFoods);

    for (int i = 0; i < editedFoods.length && i < descriptions.length; i++) {
      final newDescription = descriptions[i].trim();
      final initialText =
          _buildFoodDescription(editedFoods[i].amount, editedFoods[i].name);

      if (newDescription.isEmpty) continue;

      // Se a descrição mudou, manda para a IA depois de aplicar remoções.
      if (newDescription != initialText) {
        updatedFoods[i] =
            _applyEditedFoodDescriptionLocally(editedFoods[i], newDescription);
        changedDescriptions[i] = newDescription;
      }
    }

    setState(() {
      _currentMeal = _currentMeal.copyWith(foods: updatedFoods);
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

  /// Macro horizontal (ícone ao lado + valor colorido + unidade).
  Widget _buildCompactMacro({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isDarkMode,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MacroTheme.iconBadge(
          icon: icon,
          color: color,
          isDarkMode: isDarkMode,
          size: 24,
          iconSize: 14,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealTypeSelector({
    required bool isDarkMode,
    required Color secondaryTextColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showMealTypeBottomSheet,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    getMealTypeName(_currentMeal.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? AppTheme.darkTextColor
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 24,
                color: secondaryTextColor.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _skeletonBaseColor(bool isDarkMode) =>
      isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;

  Color _skeletonHighlightColor(bool isDarkMode) =>
      isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

  Widget _buildSkeletonBlock(
    bool isDarkMode, {
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Shimmer.fromColors(
      baseColor: _skeletonBaseColor(isDarkMode),
      highlightColor: _skeletonHighlightColor(isDarkMode),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildMealLoadingCard({
    required bool isDarkMode,
    required double topPadding,
  }) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: AppTheme.standardCardElevation(isDarkMode),
        shadowColor: AppTheme.standardCardShadowColor(isDarkMode),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: AppTheme.standardCardBorder(isDarkMode),
          ),
          padding: EdgeInsets.fromLTRB(
              16, topPadding == 0 ? 16 : topPadding, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSkeletonBlock(
                    isDarkMode,
                    width: 72,
                    height: 28,
                    radius: 8,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Center(
                      child: _buildSkeletonBlock(
                        isDarkMode,
                        width: 128,
                        height: 24,
                        radius: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSkeletonBlock(
                    isDarkMode,
                    width: 34,
                    height: 34,
                    radius: 17,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildSkeletonBlock(
                      isDarkMode,
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSkeletonBlock(
                      isDarkMode,
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSkeletonBlock(
                      isDarkMode,
                      width: double.infinity,
                      height: 18,
                      radius: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (isDarkMode ? Colors.white : Colors.black)
                          .withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildFoodItemLoadingSkeleton(isDarkMode: isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItemLoadingSkeleton({
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSkeletonBlock(
            isDarkMode,
            width: 40,
            height: 40,
            radius: 12,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSkeletonBlock(
                  isDarkMode,
                  width: double.infinity,
                  height: 15,
                  radius: 6,
                ),
                const SizedBox(height: 6),
                _buildSkeletonBlock(
                  isDarkMode,
                  width: 94,
                  height: 11,
                  radius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildSkeletonBlock(
            isDarkMode,
            width: 48,
            height: 13,
            radius: 6,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final double topPadding =
        widget.topContentPadding < 0 ? 0 : widget.topContentPadding;
    final loadingWholeCard =
        _currentMeal.foods.length == 1 && _loadingFoods[0] == true;

    if (loadingWholeCard) {
      return _buildMealLoadingCard(
        isDarkMode: isDarkMode,
        topPadding: topPadding,
      );
    }

    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final card = Container(
      margin: const EdgeInsets.only(top: 0, bottom: 12),
      child: Material(
        color: isDarkMode
            ? cardColor
            : (_simpleView ? Colors.transparent : cardColor),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: _simpleView ? 0 : AppTheme.standardCardElevation(isDarkMode),
        shadowColor: AppTheme.standardCardShadowColor(isDarkMode),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: AppTheme.standardCardBorder(isDarkMode),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              layoutBuilder: (currentChild, previousChildren) {
                return currentChild ?? const SizedBox.shrink();
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              // ── RECOLHIDO: linha única estilo balão (como era antes) ──
              child: _simpleView
                  ? KeyedSubtree(
                      key: const ValueKey('meal-card-collapsed'),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _simpleView = false),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                16, topPadding == 0 ? 14 : topPadding, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            _currentMeal.totalCalories
                                                .toStringAsFixed(0),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'Ver detalhes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  // ── EXPANDIDO: calorias + macros em cima, spinner embaixo, lista ──
                  // Tap em qualquer área "vazia" colapsa o card de volta.
                  : KeyedSubtree(
                      key: const ValueKey('meal-card-expanded'),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _simpleView = true),
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Linha 1: Calorias grandes + Spinner da refeição (à direita)
                              Padding(
                                padding: EdgeInsets.fromLTRB(16,
                                    topPadding == 0 ? 12 : topPadding, 16, 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Calorias grandes (mesma tipografia do colapsado)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          _currentMeal.totalCalories
                                              .toStringAsFixed(0),
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            height: 1,
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
                                    const SizedBox(width: 18),
                                    // Seletor real do tipo de refeição.
                                    Expanded(
                                      child: _buildMealTypeSelector(
                                        isDarkMode: isDarkMode,
                                        secondaryTextColor: secondaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: _showMoreOptionsMenu,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      icon: Icon(
                                        Icons.more_horiz_rounded,
                                        size: 22,
                                        color: secondaryTextColor.withValues(
                                            alpha: 0.78),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Linha 2: macros sem cartões, só alinhados.
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactMacro(
                                        icon: MacroTheme.proteinIcon,
                                        value: _currentMeal.totalProtein
                                            .toStringAsFixed(1),
                                        unit: 'g prot',
                                        color: MacroTheme.proteinColor,
                                        isDarkMode: isDarkMode,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildCompactMacro(
                                        icon: MacroTheme.carbsIcon,
                                        value: _currentMeal.totalCarbs
                                            .toStringAsFixed(1),
                                        unit: 'g carb',
                                        color: MacroTheme.carbsColor,
                                        isDarkMode: isDarkMode,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildCompactMacro(
                                        icon: MacroTheme.fatIcon,
                                        value: _currentMeal.totalFat
                                            .toStringAsFixed(1),
                                        unit: 'g gord',
                                        color: MacroTheme.fatColor,
                                        isDarkMode: isDarkMode,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_currentMeal.foods.isNotEmpty) ...[
                                // Divisor com gradiente
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        (isDarkMode
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.08),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Lista de alimentos
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ..._currentMeal.foods
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final index = entry.key;
                                        final food = entry.value;
                                        final isFoodLoading =
                                            _loadingFoods[index] == true;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: isFoodLoading
                                              ? _buildFoodItemLoadingSkeleton(
                                                  isDarkMode: isDarkMode,
                                                )
                                              : _FoodItem(
                                                  food: food,
                                                  isDarkMode: isDarkMode,
                                                  onRegenerateWithAI: (food,
                                                          description) =>
                                                      _regenerateFoodNutritionForItem(
                                                    index,
                                                    food,
                                                    description,
                                                  ),
                                                  onSwap: (newFood) =>
                                                      _replaceFood(
                                                          index, newFood),
                                                ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ), // fim do Container interno (com borda)
      ), // fim do Material (elevation)
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

class _EditAllFoodsResult {
  final List<Food> foods;
  final List<String> descriptions;

  const _EditAllFoodsResult({
    required this.foods,
    required this.descriptions,
  });
}

class _EditAllFoodsSheet extends StatefulWidget {
  final List<Food> foods;
  final bool isDarkMode;
  final String Function(String? amount, String name) buildFoodDescription;

  const _EditAllFoodsSheet({
    Key? key,
    required this.foods,
    required this.isDarkMode,
    required this.buildFoodDescription,
  }) : super(key: key);

  @override
  State<_EditAllFoodsSheet> createState() => _EditAllFoodsSheetState();
}

class _EditAllFoodsSheetState extends State<_EditAllFoodsSheet> {
  late final List<Food> _editableFoods;
  final List<TextEditingController> _controllers = [];
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _editableFoods = List<Food>.from(widget.foods);
    for (final food in _editableFoods) {
      _controllers.add(
        TextEditingController(
          text: widget.buildFoodDescription(food.amount, food.name),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _close([_EditAllFoodsResult? result]) {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  void _save() {
    _close(
      _EditAllFoodsResult(
        foods: List<Food>.from(_editableFoods),
        descriptions:
            _controllers.map((controller) => controller.text).toList(),
      ),
    );
  }

  void _removeFood(int index) {
    if (index < 0 || index >= _editableFoods.length) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final removedController = _controllers.removeAt(index);
    setState(() {
      _editableFoods.removeAt(index);
    });
    removedController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _editableFoods.length,
                  itemBuilder: (context, index) {
                    final food = _editableFoods[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controllers[index],
                              autofocus: index == 0,
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                  padding:
                                      const EdgeInsets.only(left: 12, right: 8),
                                  child: FoodIcon(
                                    name: food.name,
                                    emoji: food.emoji,
                                    size: 24,
                                  ),
                                ),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 0),
                                contentPadding: const EdgeInsets.symmetric(
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
                                    color: colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: isDarkMode
                                    ? AppTheme.darkComponentColor
                                    : const Color(0xFFF8F9FA),
                              ),
                              style: TextStyle(
                                fontSize: 17,
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textPrimaryColor,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Tooltip(
                            message: context.tr.translate('remove'),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => _removeFood(index),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE57373).withValues(
                                      alpha: isDarkMode ? 0.18 : 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE57373).withValues(
                                        alpha: isDarkMode ? 0.32 : 0.18,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _close,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                              color: colorScheme.onPrimary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr.translate('save'),
                              style: TextStyle(
                                color: colorScheme.onPrimary,
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
          ),
        ),
      ),
    );
  }
}

enum _FoodSourceAction {
  editDetails,
  favorite,
  recent,
  catalog,
  ai,
  manual,
}

class _FoodSourcePickerResult {
  final _FoodSourceAction action;
  final Map<String, dynamic>? data;

  const _FoodSourcePickerResult(this.action, [this.data]);
}

class _FoodDetailsEditResult {
  final String description;

  const _FoodDetailsEditResult({
    required this.description,
  });
}

class _FoodDetailsEditSheet extends StatefulWidget {
  final Food food;
  final bool isDarkMode;

  const _FoodDetailsEditSheet({
    Key? key,
    required this.food,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<_FoodDetailsEditSheet> createState() => _FoodDetailsEditSheetState();
}

class _FoodDetailsEditSheetState extends State<_FoodDetailsEditSheet> {
  late final TextEditingController _descriptionController;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: _buildFoodDescription(widget.food.amount, widget.food.name),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _buildFoodDescription(String? amount, String name) {
    final amountStr = (amount ?? '').trim();
    final nameStr = name.trim();

    if (amountStr.isEmpty) return nameStr;
    if (nameStr.isEmpty) return amountStr;

    if (amountStr.toLowerCase().contains(nameStr.toLowerCase())) {
      return amountStr;
    }
    if (nameStr.toLowerCase().contains(amountStr.toLowerCase())) {
      return nameStr;
    }

    return '$amountStr $nameStr';
  }

  void _close([_FoodDetailsEditResult? result]) {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  void _save() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;

    _close(
      _FoodDetailsEditResult(
        description: description,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
  }) {
    final isDark = widget.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor =
        isDark ? AppTheme.darkBorderColor : AppTheme.dividerColor;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark ? AppTheme.darkComponentColor : const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isDark ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimaryColor;
    final secondary =
        isDark ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SafeArea(
            top: false,
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
                    FoodIcon(
                      name: widget.food.name,
                      emoji: widget.food.emoji,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr.translate('edit_food'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  style: TextStyle(color: textColor),
                  decoration: _inputDecoration(
                    context: context,
                    label: context.tr.translate('food_and_amount'),
                    icon: Icons.restaurant_menu_rounded,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _close,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          context.tr.translate('save'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodItem extends StatefulWidget {
  final Food food;
  final bool isDarkMode;
  final ValueChanged<Food>? onSwap;
  final Future<Food?> Function(Food food, String description)?
      onRegenerateWithAI;

  const _FoodItem({
    Key? key,
    required this.food,
    required this.isDarkMode,
    this.onSwap,
    this.onRegenerateWithAI,
  }) : super(key: key);

  @override
  State<_FoodItem> createState() => _FoodItemState();
}

class _FoodItemState extends State<_FoodItem> {
  bool _sourcePickerOpen = false;

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
      case FoodSource.manual:
        return (
          icon: Icons.tune_rounded,
          color: primary,
          label: 'Personalizado',
        );
      case FoodSource.recent:
        return (
          icon: Icons.history_rounded,
          color: primary,
          label: 'Recente',
        );
      case FoodSource.catalog:
        return (
          icon: Icons.storage_rounded,
          color: const Color(0xFF2563EB),
          label: 'Fonte',
        );
      case FoodSource.ai:
        return (
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF14B8A6),
          label: 'IA',
        );
    }
  }

  Food _applyAlternativeMacros(
    Map<String, dynamic> alt,
    FoodSource source, {
    Food? food,
  }) {
    final original = food ?? widget.food;
    final originalNutrient = original.nutrients?.isNotEmpty == true
        ? original.nutrients!.first
        : null;

    final parsedBaseAmount = _parseNumeric(alt['baseAmount']);
    final baseAmount = parsedBaseAmount > 0 ? parsedBaseAmount : 100.0;
    final baseUnit = _normalizeUnit(_readText(alt['baseUnit']) ?? 'g');
    final targetServing = _targetServingForAlternative(
      original,
      originalNutrient,
      baseAmount,
      baseUnit,
    );
    final ratio = baseAmount > 0 ? targetServing.amount / baseAmount : 1.0;

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
      servingSize: targetServing.amount,
      servingUnit: targetServing.unit,
      calories: calories,
      protein: protein,
      carbohydrate: carbs,
      fat: fat,
      dietaryFiber: fiber,
    );

    // Snapshot dos macros da IA na primeira troca, para permitir voltar depois.
    final aiSnapshot = original.aiNutrients ??
        (original.source == FoodSource.ai ? original.nutrients : null);

    return original.copyWith(
      nutrients: [updatedNutrient],
      source: source,
      sourceId: alt['id'] as int?,
      aiNutrients: aiSnapshot,
    );
  }

  ({double amount, String unit}) _targetServingForAlternative(
    Food food,
    Nutrient? originalNutrient,
    double baseAmount,
    String baseUnit,
  ) {
    final amountFromLabel = _extractAmountFromText(
      food.amount,
      preferredUnit: baseUnit,
    );
    if (amountFromLabel != null &&
        _areComparableUnits(amountFromLabel.unit, baseUnit)) {
      return _convertServingToUnit(amountFromLabel, baseUnit);
    }

    final originalUnit = _normalizeUnit(originalNutrient?.servingUnit ?? '');
    if (originalNutrient != null &&
        originalNutrient.servingSize > 0 &&
        _areComparableUnits(originalUnit, baseUnit)) {
      return _convertServingToUnit(
        (amount: originalNutrient.servingSize, unit: originalUnit),
        baseUnit,
      );
    }

    final fallbackAmount = baseAmount > 0 ? baseAmount : 100.0;
    return (amount: fallbackAmount, unit: baseUnit.isEmpty ? 'g' : baseUnit);
  }

  ({double amount, String unit}) _convertServingToUnit(
    ({double amount, String unit}) serving,
    String targetUnit,
  ) {
    final sourceUnit = _normalizeUnit(serving.unit);
    final normalizedTarget = _normalizeUnit(targetUnit);
    if (sourceUnit == normalizedTarget || normalizedTarget.isEmpty) {
      return serving;
    }

    if (sourceUnit == 'oz' && normalizedTarget == 'g') {
      return (amount: serving.amount * 28.3495, unit: normalizedTarget);
    }
    if (sourceUnit == 'g' && normalizedTarget == 'oz') {
      return (amount: serving.amount / 28.3495, unit: normalizedTarget);
    }
    if (sourceUnit == 'fl oz' && normalizedTarget == 'ml') {
      return (amount: serving.amount * 29.5735, unit: normalizedTarget);
    }
    if (sourceUnit == 'ml' && normalizedTarget == 'fl oz') {
      return (amount: serving.amount / 29.5735, unit: normalizedTarget);
    }

    return serving;
  }

  ({double amount, String unit})? _extractAmountFromText(
    String? text, {
    String? preferredUnit,
  }) {
    if (text == null || text.trim().isEmpty) return null;
    final normalized = _stripDiacritics(text.toLowerCase())
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'\s+'), ' ');
    final matches = RegExp(
      r'(\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?)\s*'
      r'(fl\s*oz|gramas?|g|mililitros?|ml|quilos?|kg|litros?|l|copos?|xicaras?|fatias?|unidades?|colheres?|scoops?|cups?|tbsp|tsp|oz)\b',
    ).allMatches(normalized).toList();
    final servings = matches
        .map((match) {
          final amount = _parseQuantity(match.group(1));
          final unit = _normalizeServingToken(match.group(2));
          if (amount == null || amount <= 0 || unit == null) return null;
          return (
            amount: amount * unit.multiplier,
            unit: unit.name,
          );
        })
        .whereType<({double amount, String unit})>()
        .toList();

    final normalizedPreferred = _normalizeUnit(preferredUnit ?? '');
    if (normalizedPreferred.isNotEmpty) {
      for (final serving in servings.reversed) {
        if (_areComparableUnits(serving.unit, normalizedPreferred)) {
          return serving;
        }
      }
    }

    if (servings.isNotEmpty) return servings.last;

    final parsed = FoodJsonParser.parseServingFromPortion(text);
    if (parsed == null) return null;
    if (normalizedPreferred.isNotEmpty &&
        !_areComparableUnits(parsed.unit, normalizedPreferred)) {
      return null;
    }

    return (amount: parsed.amount, unit: parsed.unit);
  }

  double? _parseQuantity(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      if (parts.length != 2) return null;
      final numerator = double.tryParse(parts[0]);
      final denominator = double.tryParse(parts[1]);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }
    return double.tryParse(normalized);
  }

  ({String name, double multiplier})? _normalizeServingToken(String? raw) {
    final unit = _stripDiacritics((raw ?? '').toLowerCase())
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (unit == 'g' || unit.startsWith('grama')) {
      return (name: 'g', multiplier: 1);
    }
    if (unit == 'kg' || unit.startsWith('quilo')) {
      return (name: 'g', multiplier: 1000);
    }
    if (unit == 'ml' || unit.startsWith('mililitro')) {
      return (name: 'ml', multiplier: 1);
    }
    if (unit == 'l' || unit.startsWith('litro')) {
      return (name: 'ml', multiplier: 1000);
    }
    if (unit == 'oz') return (name: 'oz', multiplier: 1);
    if (unit == 'fl oz' || unit == 'floz') {
      return (name: 'fl oz', multiplier: 1);
    }
    if (unit.startsWith('copo')) return (name: 'copo', multiplier: 1);
    if (unit.startsWith('xicara') || unit == 'cup' || unit == 'cups') {
      return (name: 'xicara', multiplier: 1);
    }
    if (unit.startsWith('fatia')) return (name: 'fatia', multiplier: 1);
    if (unit.startsWith('unidade')) return (name: 'unidade', multiplier: 1);
    if (unit.startsWith('colher') || unit == 'tbsp' || unit == 'tsp') {
      return (name: 'colher', multiplier: 1);
    }
    if (unit.startsWith('scoop')) return (name: 'scoop', multiplier: 1);

    return null;
  }

  String _stripDiacritics(String value) {
    return value
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  /// Reconstrói o food com os macros originais da IA preservados em
  /// [Food.aiNutrients]. Retorna null se não houver snapshot.
  Food? _restoreAiMacros({Food? food}) {
    final original = food ?? widget.food;
    final snapshot = original.aiNutrients;
    if (snapshot == null || snapshot.isEmpty) return null;
    return original.copyWith(
      nutrients: snapshot,
      source: FoodSource.ai,
      sourceId: null,
      clearSourceId: true,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCatalogSuggestions({
    Food? food,
  }) async {
    final sourceFood = food ?? widget.food;
    final query = sourceFood.name.trim();
    if (query.isEmpty) return const [];

    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;
    final regionCode = locale.countryCode ?? languageCode.toUpperCase();
    final uri = Uri.parse('${AppConstants.DIET_API_BASE_URL}/food/search')
        .replace(queryParameters: {
      'q': query,
      'region': regionCode,
      'language': '',
      'limit': '8',
      'index': '0',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint(
        '[_FoodItem] busca de fontes do banco falhou: ${response.statusCode}',
      );
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];

    final suggestions = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final item in decoded) {
      if (item is! Map) continue;
      final suggestion = _catalogSuggestionFromApi(
        Map<String, dynamic>.from(item),
        sourceFood,
      );
      if (suggestion == null) continue;

      final dedupeKey = [
        suggestion['name'],
        suggestion['brand'],
        suggestion['sourceLabel'],
        suggestion['calories'],
        suggestion['protein'],
        suggestion['carbs'],
        suggestion['fat'],
      ].join('|').toLowerCase();
      if (!seen.add(dedupeKey)) continue;

      suggestions.add(suggestion);
      if (suggestions.length >= 8) break;
    }

    return suggestions;
  }

  Map<String, dynamic>? _catalogSuggestionFromApi(
    Map<String, dynamic> data,
    Food food,
  ) {
    final foodData = data['food'] is Map
        ? Map<String, dynamic>.from(data['food'] as Map)
        : const <String, dynamic>{};
    final nutrientList =
        foodData['nutrient'] is List ? foodData['nutrient'] as List : const [];
    if (nutrientList.isEmpty || nutrientList.first is! Map) return null;

    final nutrient = Map<String, dynamic>.from(nutrientList.first as Map);
    final calories = _parseNumeric(nutrient['calories']);
    final protein = _parseNumeric(nutrient['protein']);
    final carbs = _parseNumeric(nutrient['carbohydrate']);
    final fat = _parseNumeric(nutrient['fat']);

    if (calories <= 0 && protein <= 0 && carbs <= 0 && fat <= 0) {
      return null;
    }

    final baseAmount = _parseNumeric(nutrient['serving_size']);
    final baseUnit = _normalizeUnit(_readText(nutrient['serving_unit']) ?? 'g');
    final normalizedBaseAmount = baseAmount > 0 ? baseAmount : 100.0;
    final name = _readText(data['translation']) ??
        _readText(foodData['name']) ??
        food.name;
    final portion = _preferredCatalogPortion(data['portion']);
    final servingProportion = portion == null
        ? 1.0
        : (_parseNumeric(portion['proportion']) > 0
            ? _parseNumeric(portion['proportion'])
            : 1.0);
    final servingDescription = _readText(portion?['description']);

    return {
      'id': _parseInt(data['id']) ?? _parseInt(foodData['id']),
      'foodId': _parseInt(foodData['id']),
      'name': name,
      if (_readText(foodData['brand']) != null) 'brand': foodData['brand'],
      'sourceLabel': _catalogSourceLabel(data['catalog_source']),
      'catalogSource': data['catalog_source'],
      'baseAmount': normalizedBaseAmount,
      'baseUnit': baseUnit.isEmpty ? 'g' : baseUnit,
      'servingDescription': servingDescription,
      'servingProportion': servingProportion,
      'servingAmount': normalizedBaseAmount * servingProportion,
      'servingUnit': baseUnit.isEmpty ? 'g' : baseUnit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': _parseNumeric(nutrient['dietary_fiber']),
    };
  }

  Map<String, dynamic>? _preferredCatalogPortion(dynamic rawPortions) {
    if (rawPortions is! List || rawPortions.isEmpty) return null;

    final portions = rawPortions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => _parseNumeric(item['proportion']) > 0)
        .toList();
    if (portions.isEmpty) return null;

    for (final portion in portions) {
      final proportion = _parseNumeric(portion['proportion']);
      final description = _readText(portion['description'])?.toLowerCase();
      final isBasePortion = proportion == 1.0 &&
          (description == null ||
              RegExp(r'^100\s*(g|ml)$').hasMatch(description));
      if (!isBasePortion) return portion;
    }

    return portions.first;
  }

  double _parseNumeric(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String)
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  String _normalizeUnit(dynamic value) {
    final unit =
        value?.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final trimmed = unit?.trim() ?? '';
    if (trimmed == 'floz') return 'fl oz';
    return trimmed;
  }

  bool _areComparableUnits(String left, String right) {
    final normalizedLeft = _normalizeUnit(left);
    final normalizedRight = _normalizeUnit(right);
    if (normalizedLeft == normalizedRight) return true;
    return _unitFamily(normalizedLeft) == _unitFamily(normalizedRight);
  }

  String _unitFamily(String unit) {
    switch (_normalizeUnit(unit)) {
      case 'g':
      case 'oz':
        return 'weight';
      case 'ml':
      case 'fl oz':
        return 'volume';
      default:
        return unit;
    }
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _readText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _catalogSourceLabel(dynamic value) {
    switch (value?.toString()) {
      case 'fatsecret':
      case 'open_food_facts':
        return 'Internet';
      case 'user':
        return 'Usuários';
      default:
        return 'Internet';
    }
  }

  String _catalogOptionTitle(
    Map<String, dynamic> suggestion, {
    Food? food,
  }) {
    final name = _readText(suggestion['name']) ?? (food ?? widget.food).name;
    final brand = _readText(suggestion['brand']);
    return brand == null ? name : '$name · $brand';
  }

  _SourceMacroValues _catalogOptionMacros(Map<String, dynamic> suggestion) {
    final servingProportion = _parseNumeric(suggestion['servingProportion']);
    final ratio = servingProportion > 0 ? servingProportion : 1.0;

    return _SourceMacroValues(
      calories: _parseNumeric(suggestion['calories']) * ratio,
      protein: _parseNumeric(suggestion['protein']) * ratio,
      carbs: _parseNumeric(suggestion['carbs']) * ratio,
      fat: _parseNumeric(suggestion['fat']) * ratio,
    );
  }

  String _catalogOptionFooter(Map<String, dynamic> suggestion) {
    final servingDescription = _readText(suggestion['servingDescription']) ??
        _formatServingAmount(
          _parseNumeric(suggestion['servingAmount']),
          _readText(suggestion['servingUnit']) ?? 'g',
        );

    return servingDescription;
  }

  String _catalogOptionSubtitle(Map<String, dynamic> suggestion) {
    return '${_sourceMacroSubtitle(_catalogOptionMacros(suggestion))} · ${_catalogOptionFooter(suggestion)}';
  }

  _SourceMacroValues _macroValuesFromMap(Map<String, dynamic> data) {
    return _SourceMacroValues(
      calories: _parseNumeric(data['calories']),
      protein: _parseNumeric(data['protein']),
      carbs: _parseNumeric(data['carbs']),
      fat: _parseNumeric(data['fat']),
    );
  }

  String _macroServingFooter(Map<String, dynamic> data) {
    final base = _parseNumeric(data['baseAmount']);
    final unit = _readText(data['baseUnit']) ?? 'g';
    return 'por ${_formatServingAmount(base, unit)}';
  }

  String _sourceMacroSubtitle(
    _SourceMacroValues values, {
    String? suffix,
  }) {
    final summary = '${_formatNumber(values.calories, decimals: 0)} kcal · '
        '${values.protein.toStringAsFixed(1)}p · '
        '${values.carbs.toStringAsFixed(1)}c · '
        '${values.fat.toStringAsFixed(1)}g';
    final suffixText = suffix?.trim();
    return suffixText == null || suffixText.isEmpty
        ? summary
        : '$summary · $suffixText';
  }

  _SourceMacroValues _currentFoodMacros({Food? food}) {
    final sourceFood = food ?? widget.food;
    return _SourceMacroValues(
      calories: sourceFood.calories.toDouble(),
      protein: sourceFood.protein,
      carbs: sourceFood.carbs,
      fat: sourceFood.fat,
    );
  }

  Future<void> _openSourcePicker({Food? foodOverride}) async {
    if (_sourcePickerOpen) return;

    _sourcePickerOpen = true;

    final effectiveFood = foodOverride ?? widget.food;
    final currentSource = effectiveFood.source;
    Map<String, dynamic>? favorite;
    Map<String, dynamic>? recent;
    List<Map<String, dynamic>> catalogSuggestions = const [];
    var sourcesLoading = true;
    var sourceLoadStarted = false;
    var sheetClosed = false;
    var showAllCatalogSuggestions = false;

    Map<String, dynamic>? readAlternative(
      Map<String, dynamic>? source,
      String key,
    ) {
      final value = source?[key];
      return value is Map ? Map<String, dynamic>.from(value) : null;
    }

    Future<Map<String, dynamic>?> loadSavedAlternatives() async {
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final token = auth.token;
        if (token == null || token.isEmpty) return null;

        final service = FavoriteFoodService(token: token);
        return await service.getAlternatives(effectiveFood.name);
      } catch (e) {
        debugPrint('[_FoodItem] erro ao buscar favoritos/recentes: $e');
        return null;
      }
    }

    Future<List<Map<String, dynamic>>> loadCatalogSuggestions() async {
      try {
        return await _fetchCatalogSuggestions(food: effectiveFood);
      } catch (e) {
        debugPrint('[_FoodItem] erro ao buscar sugestoes do catalogo: $e');
        return const [];
      }
    }

    Future<void> loadSources(StateSetter setSheetState) async {
      final savedAlternativesFuture = loadSavedAlternatives();
      final catalogSuggestionsFuture = loadCatalogSuggestions();

      final loadedAlternatives = await savedAlternativesFuture;
      final loadedCatalogSuggestions = await catalogSuggestionsFuture;

      if (!mounted || sheetClosed) return;

      try {
        setSheetState(() {
          favorite = readAlternative(loadedAlternatives, 'favorite');
          recent = readAlternative(loadedAlternatives, 'recent');
          catalogSuggestions = loadedCatalogSuggestions;
          sourcesLoading = false;
        });
      } catch (_) {
        // The sheet can be dismissed while network requests are still finishing.
      }
    }

    _FoodSourcePickerResult? action;

    try {
      action = await showModalBottomSheet<_FoodSourcePickerResult>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) {
          final isDark = widget.isDarkMode;
          final bg = isDark ? AppTheme.darkCardColor : Colors.white;
          final textColor = isDark ? Colors.white : AppTheme.textPrimaryColor;
          final secondary =
              isDark ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
          final primary = Theme.of(ctx).colorScheme.primary;
          final headerIconBg = isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF5F7FA);
          final headerBorder = isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05);

          final mediaQuery = MediaQuery.of(ctx);
          final availableSheetHeight =
              mediaQuery.size.height - mediaQuery.padding.top - 12;
          final targetSheetHeight = mediaQuery.size.height * 0.88;
          final sheetHeight = targetSheetHeight > availableSheetHeight
              ? availableSheetHeight
              : targetSheetHeight;

          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              if (!sourceLoadStarted) {
                sourceLoadStarted = true;
                Future.microtask(() => loadSources(setSheetState));
              }

              final visibleCatalogSuggestions = showAllCatalogSuggestions
                  ? catalogSuggestions
                  : catalogSuggestions.take(3).toList();
              final hiddenCatalogCount =
                  catalogSuggestions.length - visibleCatalogSuggestions.length;

              return Container(
                height: sheetHeight,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: secondary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: headerIconBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: headerBorder),
                              ),
                              child: Center(
                                child: FoodIcon(
                                  name: effectiveFood.name,
                                  emoji: effectiveFood.emoji,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    effectiveFood.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (effectiveFood.amount ?? '').trim().isEmpty
                                        ? context.tr.translate('serving')
                                        : effectiveFood.amount!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondary.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tooltip(
                              message: 'Editar nome e porção',
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: () => Navigator.pop(
                                    ctx,
                                    const _FoodSourcePickerResult(
                                      _FoodSourceAction.editDetails,
                                    ),
                                  ),
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: headerIconBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: headerBorder),
                                    ),
                                    child: Icon(
                                      Icons.edit_note_rounded,
                                      color: secondary.withValues(alpha: 0.86),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Favorito
                        if (favorite != null)
                          Builder(builder: (_) {
                            final favoriteData = favorite!;
                            return _SourceOption(
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFFFFB300),
                              title: 'Seu favorito',
                              subtitle: _sourceMacroSubtitle(
                                _macroValuesFromMap(favoriteData),
                                suffix: _macroServingFooter(favoriteData),
                              ),
                              macros: _macroValuesFromMap(favoriteData),
                              footer: _macroServingFooter(favoriteData),
                              selected: currentSource == FoodSource.favorite,
                              isDarkMode: isDark,
                              onTap: () => Navigator.pop(
                                ctx,
                                const _FoodSourcePickerResult(
                                  _FoodSourceAction.favorite,
                                ),
                              ),
                            );
                          }),

                        if (currentSource == FoodSource.manual)
                          _SourceOption(
                            icon: Icons.tune_rounded,
                            iconColor: primary,
                            title: 'Personalizado',
                            subtitle: _sourceMacroSubtitle(
                              _currentFoodMacros(food: effectiveFood),
                              suffix: 'editado manualmente',
                            ),
                            macros: _currentFoodMacros(food: effectiveFood),
                            footer: 'editado manualmente',
                            selected: true,
                            isDarkMode: isDark,
                            onTap: () => Navigator.pop(
                              ctx,
                              const _FoodSourcePickerResult(
                                _FoodSourceAction.manual,
                              ),
                            ),
                          ),

                        // Recente
                        if (recent != null)
                          Builder(builder: (_) {
                            final recentData = recent!;
                            return _SourceOption(
                              icon: Icons.history_rounded,
                              iconColor: primary,
                              title: 'Recente',
                              subtitle: _sourceMacroSubtitle(
                                _macroValuesFromMap(recentData),
                                suffix: _macroServingFooter(recentData),
                              ),
                              macros: _macroValuesFromMap(recentData),
                              footer: _macroServingFooter(recentData),
                              selected: currentSource == FoodSource.recent,
                              isDarkMode: isDark,
                              onTap: () => Navigator.pop(
                                ctx,
                                const _FoodSourcePickerResult(
                                  _FoodSourceAction.recent,
                                ),
                              ),
                            );
                          }),

                        // IA atual (sempre presente como referencia). Quando ja se
                        // trocou para outra fonte, usa o snapshot original em
                        // aiNutrients para mostrar e restaurar os valores da IA.
                        Builder(builder: (_) {
                          final aiNut =
                              effectiveFood.aiNutrients?.isNotEmpty == true
                                  ? effectiveFood.aiNutrients!.first
                                  : null;
                          final aiCalories = currentSource == FoodSource.ai
                              ? effectiveFood.calories
                              : (aiNut?.calories?.toInt() ??
                                  effectiveFood.calories);
                          final aiProtein = currentSource == FoodSource.ai
                              ? effectiveFood.protein
                              : (aiNut?.protein ?? effectiveFood.protein);
                          final aiCarbs = currentSource == FoodSource.ai
                              ? effectiveFood.carbs
                              : (aiNut?.carbohydrate ?? effectiveFood.carbs);
                          final aiFat = currentSource == FoodSource.ai
                              ? effectiveFood.fat
                              : (aiNut?.fat ?? effectiveFood.fat);
                          final aiMacros = _SourceMacroValues(
                            calories: aiCalories.toDouble(),
                            protein: aiProtein,
                            carbs: aiCarbs,
                            fat: aiFat,
                          );
                          return _SourceOption(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: const Color(0xFF14B8A6),
                            title: 'Estimativa da IA',
                            subtitle: _sourceMacroSubtitle(aiMacros),
                            macros: aiMacros,
                            selected: currentSource == FoodSource.ai,
                            isDarkMode: isDark,
                            onTap: () => Navigator.pop(
                              ctx,
                              currentSource == FoodSource.ai
                                  ? null
                                  : const _FoodSourcePickerResult(
                                      _FoodSourceAction.ai,
                                    ),
                            ),
                          );
                        }),

                        if (currentSource != FoodSource.manual) ...[
                          const SizedBox(height: 8),
                          _SourceOption(
                            icon: Icons.tune_rounded,
                            iconColor: primary,
                            title: 'Editar manualmente',
                            subtitle: 'Digite os macros manualmente',
                            macros: null,
                            footer: null,
                            selected: false,
                            isDarkMode: isDark,
                            onTap: () => Navigator.pop(
                              ctx,
                              const _FoodSourcePickerResult(
                                _FoodSourceAction.manual,
                              ),
                            ),
                          ),
                        ],

                        if (sourcesLoading ||
                            catalogSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                'Sugestões da Internet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: secondary.withValues(alpha: 0.9),
                                ),
                              ),
                              if (sourcesLoading) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primary.withValues(alpha: 0.82),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (sourcesLoading)
                            _InternetSuggestionsLoading(isDarkMode: isDark),
                          if (!sourcesLoading) ...[
                            ...visibleCatalogSuggestions.map((suggestion) {
                              final suggestionId = _parseInt(suggestion['id']);
                              return _SourceOption(
                                icon: Icons.public_rounded,
                                iconColor: const Color(0xFF2563EB),
                                title: _catalogOptionTitle(
                                  suggestion,
                                  food: effectiveFood,
                                ),
                                subtitle: _catalogOptionSubtitle(suggestion),
                                macros: _catalogOptionMacros(suggestion),
                                footer: _catalogOptionFooter(suggestion),
                                selected: currentSource == FoodSource.catalog &&
                                    effectiveFood.sourceId == suggestionId,
                                isDarkMode: isDark,
                                onTap: () => Navigator.pop(
                                  ctx,
                                  _FoodSourcePickerResult(
                                    _FoodSourceAction.catalog,
                                    suggestion,
                                  ),
                                ),
                              );
                            }),
                            if (catalogSuggestions.length > 3)
                              _SourceMoreButton(
                                isDarkMode: isDark,
                                label: showAllCatalogSuggestions
                                    ? 'Ver menos'
                                    : 'Ver mais ($hiddenCatalogCount)',
                                icon: showAllCatalogSuggestions
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                onTap: () {
                                  setSheetState(() {
                                    showAllCatalogSuggestions =
                                        !showAllCatalogSuggestions;
                                  });
                                },
                              ),
                          ],
                        ],

                        const SizedBox(height: 12),

                        // Caso nao tenha nenhuma fonte salva, oferece cadastrar.
                        if (!sourcesLoading &&
                            favorite == null &&
                            currentSource != FoodSource.manual &&
                            recent == null &&
                            catalogSuggestions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Voce ainda nao tem versoes salvas ou outras sugestoes para ${effectiveFood.name}. Edite o alimento para salvar como favorito.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: secondary.withValues(alpha: 0.8)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      sheetClosed = true;
      _sourcePickerOpen = false;
    }

    // Executa a acao escolhida apos o source picker fechar completamente.
    // Isso evita que dois bottom sheets fiquem animando ao mesmo tempo,
    // que causa o erro `_dependents.isEmpty` em InheritedElement quando o
    // segundo modal eh fechado.
    if (!mounted || action == null) return;

    switch (action.action) {
      case _FoodSourceAction.editDetails:
        await _openFoodDetailsEditor(food: effectiveFood);
        break;
      case _FoodSourceAction.favorite:
        final selectedFavorite = favorite;
        if (selectedFavorite != null) {
          widget.onSwap?.call(
            _applyAlternativeMacros(
              selectedFavorite,
              FoodSource.favorite,
              food: effectiveFood,
            ),
          );
        }
        break;
      case _FoodSourceAction.recent:
        final selectedRecent = recent;
        if (selectedRecent != null) {
          widget.onSwap?.call(
            _applyAlternativeMacros(
              selectedRecent,
              FoodSource.recent,
              food: effectiveFood,
            ),
          );
        }
        break;
      case _FoodSourceAction.catalog:
        final suggestion = action.data;
        if (suggestion != null) {
          widget.onSwap?.call(
            _applyAlternativeMacros(
              suggestion,
              FoodSource.catalog,
              food: effectiveFood,
            ),
          );
        }
        break;
      case _FoodSourceAction.ai:
        final restored = _restoreAiMacros(food: effectiveFood);
        if (restored != null) {
          widget.onSwap?.call(restored);
        }
        break;
      case _FoodSourceAction.manual:
        await _openManualMacroEditor(food: effectiveFood);
        break;
    }
  }

  Future<void> _openFoodDetailsEditor({Food? food}) async {
    final sourceFood = food ?? widget.food;
    final result = await showModalBottomSheet<_FoodDetailsEditResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return _FoodDetailsEditSheet(
          food: sourceFood,
          isDarkMode: widget.isDarkMode,
        );
      },
    );

    if (!mounted || result == null) return;

    final newDescription = result.description.trim();
    if (newDescription.isEmpty) return;

    final oldName = sourceFood.name.trim();
    final oldAmount = (sourceFood.amount ?? '').trim();
    final oldDescription = _buildFoodDescription(oldAmount, oldName);
    if (_normalizeFoodDescription(newDescription) ==
        _normalizeFoodDescription(oldDescription)) {
      return;
    }

    final localFood =
        _applyEditedFoodDescriptionLocally(sourceFood, newDescription);
    widget.onSwap?.call(localFood);

    final regeneratedFood =
        await widget.onRegenerateWithAI?.call(localFood, newDescription);
    if (!mounted) return;

    if (regeneratedFood != null) {
      await _openSourcePicker(foodOverride: regeneratedFood);
    }
  }

  String _normalizeFoodDescription(String value) {
    return _stripDiacritics(value)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  ({String? amount, String name}) _parseEditedFoodDescription(
    String foodDescription,
    Food fallbackFood,
  ) {
    final description = foodDescription.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (description.isEmpty) {
      return (amount: fallbackFood.amount, name: fallbackFood.name);
    }

    final leadingAmountMatch = RegExp(
      r'^((?:\d+(?:[.,]\d+)?|\d+\s*/\s*\d+)\s*'
      r'(?:fl\s*oz|gramas?|g|mililitros?|ml|quilos?|kg|litros?|l|'
      r'copos?|xicaras?|fatias?|unidades?|colheres?|scoops?|cups?|'
      r'tbsp|tsp|oz)?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(description);

    if (leadingAmountMatch != null) {
      final amount = leadingAmountMatch.group(1)?.trim();
      var name = leadingAmountMatch.group(2)?.trim() ?? '';
      name = name.replaceFirst(
        RegExp(r'^(de|da|do|dos|das)\s+', caseSensitive: false),
        '',
      );
      if (name.isNotEmpty) {
        return (amount: amount, name: name);
      }
    }

    return (amount: fallbackFood.amount, name: description);
  }

  Food _applyEditedFoodDescriptionLocally(
    Food originalFood,
    String foodDescription,
  ) {
    final parsed = _parseEditedFoodDescription(foodDescription, originalFood);
    final name = parsed.name.trim();
    if (name.isEmpty) return originalFood;

    return originalFood.copyWith(
      name: name,
      amount: parsed.amount ?? originalFood.amount,
      emoji: resolveFoodEmoji(name),
      source: FoodSource.ai,
      clearSourceId: true,
      clearAiNutrients: true,
    );
  }

  String _buildFoodDescription(String? amount, String name) {
    final amountStr = (amount ?? '').trim();
    final nameStr = name.trim();

    if (amountStr.isEmpty) return nameStr;
    if (nameStr.isEmpty) return amountStr;

    if (amountStr.toLowerCase().contains(nameStr.toLowerCase())) {
      return amountStr;
    }
    if (nameStr.toLowerCase().contains(amountStr.toLowerCase())) {
      return nameStr;
    }

    return '$amountStr $nameStr';
  }

  void _openFoodPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodPage(food: widget.food),
      ),
    );
  }

  Future<void> _openManualMacroEditor({Food? food}) async {
    final sourceFood = food ?? widget.food;
    final updatedFood = await showModalBottomSheet<Food>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return _ManualMacroEditorSheet(
          food: sourceFood,
          isDarkMode: widget.isDarkMode,
        );
      },
    );

    if (!mounted || updatedFood == null) return;
    widget.onSwap?.call(updatedFood);
  }

  String _formatServingAmount(double amount, String unit) {
    final normalizedAmount = amount > 0 ? amount : 100.0;
    final normalizedUnit =
        _normalizeUnit(unit).isEmpty ? 'g' : _normalizeUnit(unit);
    return '${_formatNumber(normalizedAmount)}$normalizedUnit';
  }

  String _formatNumber(double value, {int decimals = 1}) {
    if (value.roundToDouble() == value) return value.toInt().toString();
    return value.toStringAsFixed(decimals);
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
    final iconBg = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openSourcePicker,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Tooltip(
                message: context.tr.translate('edit'),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _openFoodPage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FoodIcon(
                        name: food.name,
                        emoji: food.emoji,
                        size: 27,
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
                    // Nome com largura total (sem competir com badge ao lado)
                    Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Linha inferior: quantidade + indicador inline da fonte
                    Row(
                      children: [
                        if ((food.amount ?? '').trim().isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              food.amount ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    secondaryTextColor.withValues(alpha: 0.78),
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              width: 2.5,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color:
                                    secondaryTextColor.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                        _SourceInlineBadge(
                          icon: meta.icon,
                          color: meta.color,
                          label: meta.label,
                          loading: false,
                          onTap: _openSourcePicker,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Calories (mais compacto)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${food.calories}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor.withValues(alpha: 0.78),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.55),
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

/// Indicador inline da fonte (sem caixa) — usado dentro da linha da quantidade.
/// Mantém o nome do alimento livre da pressão visual de um chip ao lado.
class _SourceInlineBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _SourceInlineBadge({
    Key? key,
    required this.icon,
    required this.color,
    required this.label,
    required this.loading,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final iconColor = color.withValues(alpha: isDarkMode ? 0.62 : 0.68);
    final labelColor =
        secondaryTextColor.withValues(alpha: isDarkMode ? 0.72 : 0.82);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                )
              else
                Icon(icon, size: 10.5, color: iconColor),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                  height: 1.1,
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
class _SourceMacroValues {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const _SourceMacroValues({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class _SourceMacroLine extends StatelessWidget {
  final _SourceMacroValues values;
  final String? footer;
  final bool isDarkMode;

  const _SourceMacroLine({
    required this.values,
    required this.footer,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final footerText = footer?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SourceMetaLine(
          calories: values.calories.round().toString(),
          footer: footerText,
          textColor: textColor,
          mutedColor: secondary,
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SourceMacroTextToken(
                label: 'P',
                value: values.protein.toStringAsFixed(1),
                color: MacroTheme.proteinColor,
                textColor: textColor,
                mutedColor: secondary,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 14),
              _SourceMacroTextToken(
                label: 'C',
                value: values.carbs.toStringAsFixed(1),
                color: MacroTheme.carbsColor,
                textColor: textColor,
                mutedColor: secondary,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 14),
              _SourceMacroTextToken(
                label: 'G',
                value: values.fat.toStringAsFixed(1),
                color: MacroTheme.fatColor,
                textColor: textColor,
                mutedColor: secondary,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceMetaLine extends StatelessWidget {
  final String calories;
  final String? footer;
  final Color textColor;
  final Color mutedColor;

  const _SourceMetaLine({
    required this.calories,
    required this.footer,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          calories,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'kcal',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: mutedColor,
            height: 1,
          ),
        ),
        if (footer != null && footer!.isNotEmpty) ...[
          const SizedBox(width: 7),
          Text(
            '·',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mutedColor.withValues(alpha: 0.78),
              height: 1,
            ),
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: mutedColor.withValues(alpha: 0.9),
                height: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceMacroTextToken extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;
  final Color mutedColor;
  final bool isDarkMode;

  const _SourceMacroTextToken({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
    required this.mutedColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDarkMode ? 0.17 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1,
          ),
        ),
        Text(
          'g',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: mutedColor,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _InternetSuggestionsLoading extends StatelessWidget {
  final bool isDarkMode;

  const _InternetSuggestionsLoading({
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => _InternetSuggestionLoadingCard(
          isDarkMode: isDarkMode,
          showSpinner: index == 0,
        ),
      ),
    );
  }
}

class _InternetSuggestionLoadingCard extends StatelessWidget {
  final bool isDarkMode;
  final bool showSpinner;

  const _InternetSuggestionLoadingCard({
    required this.isDarkMode,
    required this.showSpinner,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = isDarkMode
        ? Colors.white.withValues(alpha: 0.045)
        : const Color(0xFFF8F8FA);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.black.withValues(alpha: 0.035);
    final iconBg = primary.withValues(alpha: isDarkMode ? 0.18 : 0.1);
    final iconColor = primary.withValues(alpha: 0.78);
    final lineColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final strongLineColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.black.withValues(alpha: 0.09);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: showSpinner
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(
                        Icons.public_rounded,
                        size: 20,
                        color: iconColor,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SourceLoadingLine(
                    width: 168,
                    height: 15,
                    color: strongLineColor,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SourceLoadingLine(
                        width: 58,
                        height: 12,
                        color: lineColor,
                      ),
                      const SizedBox(width: 10),
                      _SourceLoadingLine(
                        width: 74,
                        height: 12,
                        color: lineColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _SourceLoadingLine(
                        width: 46,
                        height: 10,
                        color: lineColor,
                      ),
                      const SizedBox(width: 12),
                      _SourceLoadingLine(
                        width: 46,
                        height: 10,
                        color: lineColor,
                      ),
                      const SizedBox(width: 12),
                      _SourceLoadingLine(
                        width: 46,
                        height: 10,
                        color: lineColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceLoadingLine extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _SourceLoadingLine({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final _SourceMacroValues? macros;
  final String? footer;
  final bool selected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _SourceOption({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.macros,
    this.footer,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final secondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final optionBg = selected
        ? iconColor.withValues(alpha: isDarkMode ? 0.13 : 0.08)
        : (isDarkMode
            ? Colors.white.withValues(alpha: 0.045)
            : const Color(0xFFF8F8FA));
    final optionBorder = selected
        ? iconColor.withValues(alpha: isDarkMode ? 0.58 : 0.34)
        : (isDarkMode
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.black.withValues(alpha: 0.035));
    final iconBg = iconColor.withValues(alpha: isDarkMode ? 0.2 : 0.12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: optionBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: optionBorder,
                width: selected ? 1.35 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 21, color: iconColor),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                height: 1.05,
                              ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 7),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: iconColor,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (macros != null)
                        _SourceMacroLine(
                          values: macros!,
                          footer: footer,
                          isDarkMode: isDarkMode,
                        )
                      else
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: secondary.withValues(alpha: 0.9),
                            height: 1.15,
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

class _SourceMoreButton extends StatelessWidget {
  final bool isDarkMode;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SourceMoreButton({
    Key? key,
    required this.isDarkMode,
    required this.label,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = isDarkMode
        ? Colors.white.withValues(alpha: 0.05)
        : primary.withValues(alpha: 0.06);
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : primary.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: isDarkMode ? 0.18 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: primary),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primary,
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

class _ManualMacroEditorSheet extends StatefulWidget {
  final Food food;
  final bool isDarkMode;

  const _ManualMacroEditorSheet({
    Key? key,
    required this.food,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<_ManualMacroEditorSheet> createState() =>
      _ManualMacroEditorSheetState();
}

class _ManualMacroEditorSheetState extends State<_ManualMacroEditorSheet> {
  late final TextEditingController _caloriesCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _fiberCtrl;
  bool _closing = false;
  bool _updatingCalories = false;

  Nutrient? get _originalNutrient => widget.food.nutrients?.isNotEmpty == true
      ? widget.food.nutrients!.first
      : null;

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    final originalNutrient = _originalNutrient;
    _caloriesCtrl = TextEditingController(text: food.calories.toString());
    _proteinCtrl = TextEditingController(text: food.protein.toStringAsFixed(1));
    _carbsCtrl = TextEditingController(text: food.carbs.toStringAsFixed(1));
    _fatCtrl = TextEditingController(text: food.fat.toStringAsFixed(1));
    _fiberCtrl = TextEditingController(
      text: (originalNutrient?.dietaryFiber ?? 0).toStringAsFixed(1),
    );
    _proteinCtrl.addListener(_recalculateCaloriesFromMacros);
    _carbsCtrl.addListener(_recalculateCaloriesFromMacros);
    _fatCtrl.addListener(_recalculateCaloriesFromMacros);
  }

  @override
  void dispose() {
    _proteinCtrl.removeListener(_recalculateCaloriesFromMacros);
    _carbsCtrl.removeListener(_recalculateCaloriesFromMacros);
    _fatCtrl.removeListener(_recalculateCaloriesFromMacros);
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  double _parse(String value) {
    final cleaned = value.replaceAll(',', '.').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  void _recalculateCaloriesFromMacros() {
    if (_updatingCalories) return;

    final calories = ((_parse(_proteinCtrl.text) * 4) +
            (_parse(_carbsCtrl.text) * 4) +
            (_parse(_fatCtrl.text) * 9))
        .round()
        .toString();
    if (_caloriesCtrl.text == calories) return;

    _updatingCalories = true;
    _caloriesCtrl.value = TextEditingValue(
      text: calories,
      selection: TextSelection.collapsed(offset: calories.length),
    );
    _updatingCalories = false;
  }

  void _close([Food? result]) {
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  void _save() {
    final updatedNutrient = (_originalNutrient ??
            Nutrient(
              idFood: 0,
              servingSize: 100.0,
              servingUnit: 'g',
            ))
        .copyWith(
      calories: _parse(_caloriesCtrl.text),
      protein: _parse(_proteinCtrl.text),
      carbohydrate: _parse(_carbsCtrl.text),
      fat: _parse(_fatCtrl.text),
      dietaryFiber: _parse(_fiberCtrl.text),
    );
    final aiSnapshot = widget.food.aiNutrients ??
        (widget.food.source == FoodSource.ai ? widget.food.nutrients : null);

    _close(
      widget.food.copyWith(
        nutrients: [updatedNutrient],
        source: FoodSource.manual,
        clearSourceId: true,
        aiNutrients: aiSnapshot,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final food = widget.food;
    final bg = isDark ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimaryColor;
    final secondary =
        isDark ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  FoodIcon(name: food.name, emoji: food.emoji, size: 26),
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
                      controller: _caloriesCtrl,
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
                      controller: _proteinCtrl,
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
                      controller: _carbsCtrl,
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
                      controller: _fatCtrl,
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
                controller: _fiberCtrl,
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
                      onPressed: _close,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
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
                          color: colorScheme.onPrimary,
                        ),
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
    final bg =
        isDarkMode ? AppTheme.darkComponentColor : const Color(0xFFF5F7FA);
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : const Color(0xFFE0E4EC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MacroTheme.iconBadge(
                icon: icon,
                color: color,
                isDarkMode: isDarkMode,
                size: 18,
                iconSize: 10,
              ),
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
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: allowDecimal),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
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
