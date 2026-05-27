import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
        });

        _notifyMealUpdated();
        return;
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
        foodDescription,
        languageCode: languageCode,
        quality: 'bom',
        userId: userId,
        agentType: 'nutrition',
      )) {
        fullResponse += chunk;
      }

      final jsonMatch =
          RegExp(r'\{[\s\S]*"foods"[\s\S]*\}').firstMatch(fullResponse);
      if (jsonMatch == null) return null;

      final decoded = jsonDecode(jsonMatch.group(0)!);
      if (decoded is! Map || !decoded.containsKey('foods')) return null;

      final foodsList = decoded['foods'] as List;
      if (foodsList.isEmpty || foodsList.first is! Map) return null;

      final foodData = Map<String, dynamic>.from(foodsList.first as Map);
      final macros = foodData['macros'] as Map<String, dynamic>?;
      if (macros == null) return null;

      final detectedName =
          foodData['name'] as String? ?? originalFood.name;
      final detectedPortion = foodData['portion'] as String? ?? '';
      final newNutrient = Nutrient(
        idFood: 0,
        servingSize: _parseDouble(macros['serving_size']) ?? 100,
        servingUnit: macros['serving_unit'] as String? ?? 'g',
        calories: _parseDouble(macros['calories']),
        protein: _parseDouble(macros['protein']),
        carbohydrate: _parseDouble(macros['carbohydrate'] ?? macros['carbs']),
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

      return originalFood.copyWith(
        name: detectedName,
        amount: detectedPortion.isEmpty ? originalFood.amount : detectedPortion,
        emoji: _getFoodEmoji(detectedName),
        nutrients: [newNutrient],
        source: FoodSource.ai,
        clearSourceId: true,
        clearAiNutrients: true,
      );
    } catch (e) {
      print('Erro ao gerar nutrição da IA: $e');
      return null;
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

    for (int i = 0; i < editedFoods.length && i < descriptions.length; i++) {
      final newDescription = descriptions[i].trim();
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

  /// Retorna o emoji configurado para o tipo de refeição atual,
  /// caindo em 🍽️ se não houver match.
  String _getMealEmoji() {
    try {
      final provider = Provider.of<MealTypesProvider>(context, listen: false);
      for (final config in provider.mealTypes) {
        if (_getMealTypeFromId(config.id) == _currentMeal.type) {
          return config.emoji;
        }
      }
    } catch (_) {}
    return '🍽️';
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
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          unit,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            height: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final double topPadding =
        widget.topContentPadding < 0 ? 0 : widget.topContentPadding;

    // Mesmo visual do _MealCard da tela "Minha Dieta": Material com
    // elevation 2 + sombra preta 10%, radius 16 e borda fina interna.
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final card = Container(
      margin: const EdgeInsets.only(top: 0, bottom: 12),
      child: Material(
        // Colapsado: transparente (herda a cor do chat) sem sombra.
        // Expandido: fundo branco/dark card + elevação como o card da Minha Dieta.
        color: _simpleView ? Colors.transparent : cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: _simpleView ? 0 : 2,
        shadowColor: _simpleView
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeOut,
              sizeCurve: Curves.easeInOut,
              crossFadeState: _simpleView
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              // ── RECOLHIDO: linha única estilo balão (como era antes) ──
              firstChild: Material(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _currentMeal.totalCalories
                                        .toStringAsFixed(0),
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
              // ── EXPANDIDO: calorias + macros em cima, spinner embaixo, lista ──
              // Tap em qualquer área "vazia" colapsa o card de volta.
              secondChild: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _simpleView = true),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linha 1: Calorias grandes + Spinner da refeição (à direita)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            16, topPadding == 0 ? 12 : topPadding, 16, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Calorias grandes (mesma tipografia do colapsado)
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
                            const SizedBox(width: 16),
                            // Spinner real do tipo de refeição (ocupa o resto)
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showMealTypeBottomSheet,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.fromLTRB(12, 8, 6, 8),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.black
                                              .withValues(alpha: 0.025),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _getMealEmoji(),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            getMealTypeName(_currentMeal.type),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode
                                                  ? AppTheme.darkTextColor
                                                  : AppTheme.textPrimaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 22,
                                          color: secondaryTextColor.withValues(
                                              alpha: 0.7),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Linha 2: Macros + ícones de editar/menu ao lado
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildCompactMacro(
                                    icon: MacroTheme.proteinIcon,
                                    value: _currentMeal.totalProtein
                                        .toStringAsFixed(1),
                                    unit: 'g prot',
                                    color: MacroTheme.proteinColor,
                                    isDarkMode: isDarkMode,
                                  ),
                                  _buildCompactMacro(
                                    icon: MacroTheme.carbsIcon,
                                    value: _currentMeal.totalCarbs
                                        .toStringAsFixed(1),
                                    unit: 'g carb',
                                    color: MacroTheme.carbsColor,
                                    isDarkMode: isDarkMode,
                                  ),
                                  _buildCompactMacro(
                                    icon: MacroTheme.fatIcon,
                                    value: _currentMeal.totalFat
                                        .toStringAsFixed(1),
                                    unit: 'g gord',
                                    color: MacroTheme.fatColor,
                                    isDarkMode: isDarkMode,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Ícone de editar
                            Tooltip(
                              message: context.tr.translate('edit_foods'),
                              child: IconButton(
                                onPressed: _showEditOptionsMenu,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color:
                                      secondaryTextColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Menu de ações
                            IconButton(
                              onPressed: _showMoreOptionsMenu,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color:
                                    secondaryTextColor.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      if (_currentMeal.foods.isNotEmpty) ...[
                        // Divisor com gradiente
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
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
                        // Lista de alimentos
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._currentMeal.foods
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final food = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _FoodItem(
                                    food: food,
                                    isDarkMode: isDarkMode,
                                    onRegenerateWithAI:
                                        _generateFoodNutritionFromAI,
                                    onSwap: (newFood) =>
                                        _replaceFood(index, newFood),
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
  final String name;
  final String amount;

  const _FoodDetailsEditResult({
    required this.name,
    required this.amount,
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
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.food.name);
    _amountController = TextEditingController(text: widget.food.amount ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
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
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    _close(
      _FoodDetailsEditResult(
        name: name,
        amount: _amountController.text.trim(),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required String helper,
    required IconData icon,
  }) {
    final isDark = widget.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isDark ? AppTheme.darkBorderColor : AppTheme.dividerColor;

    return InputDecoration(
      labelText: label,
      helperText: helper,
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
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: textColor),
                  decoration: _inputDecoration(
                    context: context,
                    label: context.tr.translate('food_name'),
                    helper: context.tr.translate('edit_food_info'),
                    icon: Icons.restaurant_menu_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  style: TextStyle(color: textColor),
                  decoration: _inputDecoration(
                    context: context,
                    label: context.tr.translate('serving'),
                    helper: context.tr.translate('edit_amount_helper'),
                    icon: Icons.scale_rounded,
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
    String baseUnit,
  ) {
    final amountFromLabel = _extractAmountFromText(food.amount);
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

    return (amount: 100.0, unit: baseUnit.isEmpty ? 'g' : baseUnit);
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

  ({double amount, String unit})? _extractAmountFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final normalized = text.toLowerCase().replaceAll(',', '.');
    final matches = RegExp(r'(\d+(?:\.\d+)?)\s*(g|ml|oz|fl\s*oz)\b')
        .allMatches(normalized)
        .toList();
    if (matches.isEmpty) return null;

    final match = matches.last;
    final amount = double.tryParse(match.group(1) ?? '');
    final unit = _normalizeUnit(match.group(2));
    if (amount == null || amount <= 0 || unit.isEmpty) return null;

    return (amount: amount, unit: unit);
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
        return 'FatSecret';
      case 'open_food_facts':
        return 'Open Food Facts';
      case 'user':
        return 'Usuários';
      default:
        return 'Banco Nutro';
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

  String _catalogOptionSubtitle(Map<String, dynamic> suggestion) {
    final source = _readText(suggestion['sourceLabel']) ?? 'Banco Nutro';
    final servingProportion = _parseNumeric(suggestion['servingProportion']);
    final ratio = servingProportion > 0 ? servingProportion : 1.0;
    final servingDescription = _readText(suggestion['servingDescription']) ??
        _formatServingAmount(
          _parseNumeric(suggestion['servingAmount']),
          _readText(suggestion['servingUnit']) ?? 'g',
        );
    final baseServing = _formatServingAmount(
      _parseNumeric(suggestion['baseAmount']),
      _readText(suggestion['baseUnit']) ?? 'g',
    );

    final servingSummary = _formatMacroSummary(
      calories: _parseNumeric(suggestion['calories']) * ratio,
      protein: _parseNumeric(suggestion['protein']) * ratio,
      carbs: _parseNumeric(suggestion['carbs']) * ratio,
      fat: _parseNumeric(suggestion['fat']) * ratio,
    );

    if (ratio == 1.0) {
      return '$source · $servingSummary (por $baseServing)';
    }

    return '$source · $servingSummary (por $servingDescription)\n'
        'Base: ${_macrosSummary(suggestion)}';
  }

  String _currentFoodMacrosSummary({Food? food}) {
    final sourceFood = food ?? widget.food;
    return _formatMacroSummary(
      calories: sourceFood.calories.toDouble(),
      protein: sourceFood.protein,
      carbs: sourceFood.carbs,
      fat: sourceFood.fat,
    );
  }

  Future<void> _openSourcePicker({Food? foodOverride}) async {
    if (_loadingAlternatives) return;

    final sourceFood = foodOverride ?? widget.food;
    setState(() => _loadingAlternatives = true);

    Map<String, dynamic>? alternatives;
    List<Map<String, dynamic>> catalogSuggestions = const [];
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = auth.token;
      if (token != null && token.isNotEmpty) {
        final service = FavoriteFoodService(token: token);
        alternatives = await service.getAlternatives(sourceFood.name);
      }
      catalogSuggestions = await _fetchCatalogSuggestions(food: sourceFood);
    } catch (e) {
      debugPrint('[_FoodItem] erro ao buscar alternativas: $e');
    }

    if (!mounted) return;
    setState(() => _loadingAlternatives = false);

    final favorite = alternatives?['favorite'] as Map<String, dynamic>?;
    final recent = alternatives?['recent'] as Map<String, dynamic>?;
    final currentSource = sourceFood.source;
    var showAllCatalogSuggestions = false;

    final action = await showModalBottomSheet<_FoodSourcePickerResult>(
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

        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.82;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final visibleCatalogSuggestions = showAllCatalogSuggestions
                ? catalogSuggestions
                : catalogSuggestions.take(3).toList();
            final hiddenCatalogCount =
                catalogSuggestions.length - visibleCatalogSuggestions.length;

            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: SingleChildScrollView(
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
                              name: sourceFood.name,
                              emoji: sourceFood.emoji,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sourceFood.name,
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
                              fontSize: 12,
                              color: secondary.withValues(alpha: 0.85)),
                        ),
                        const SizedBox(height: 16),

                        _SourceOption(
                          icon: Icons.edit_note_rounded,
                          iconColor: primary,
                          title: 'Editar nome e porção',
                          subtitle: (sourceFood.amount ?? '').trim().isEmpty
                              ? context.tr.translate('serving')
                              : sourceFood.amount!,
                          selected: false,
                          isDarkMode: isDark,
                          onTap: () => Navigator.pop(
                            ctx,
                            const _FoodSourcePickerResult(
                              _FoodSourceAction.editDetails,
                            ),
                          ),
                        ),

                        // Favorito
                        if (favorite != null)
                          _SourceOption(
                            icon: Icons.star_rounded,
                            iconColor: const Color(0xFFFFB300),
                            title: 'Seu favorito',
                            subtitle: _macrosSummary(favorite),
                            selected: currentSource == FoodSource.favorite,
                            isDarkMode: isDark,
                            onTap: () => Navigator.pop(
                              ctx,
                              const _FoodSourcePickerResult(
                                _FoodSourceAction.favorite,
                              ),
                            ),
                          ),

                        if (currentSource == FoodSource.manual)
                          _SourceOption(
                            icon: Icons.tune_rounded,
                            iconColor: primary,
                            title: 'Personalizado',
                            subtitle:
                                '${_currentFoodMacrosSummary(food: sourceFood)} · editado manualmente',
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
                          _SourceOption(
                            icon: Icons.history_rounded,
                            iconColor: primary,
                            title: 'Recente',
                            subtitle: _macrosSummary(recent),
                            selected: currentSource == FoodSource.recent,
                            isDarkMode: isDark,
                            onTap: () => Navigator.pop(
                              ctx,
                              const _FoodSourcePickerResult(
                                _FoodSourceAction.recent,
                              ),
                            ),
                          ),

                        // IA atual (sempre presente como referencia). Quando ja se
                        // trocou para outra fonte, usa o snapshot original em
                        // aiNutrients para mostrar e restaurar os valores da IA.
                        Builder(builder: (_) {
                          final aiNut =
                              sourceFood.aiNutrients?.isNotEmpty == true
                                  ? sourceFood.aiNutrients!.first
                                  : null;
                          final aiCalories = currentSource == FoodSource.ai
                              ? sourceFood.calories
                              : (aiNut?.calories?.toInt() ??
                                  sourceFood.calories);
                          final aiProtein = currentSource == FoodSource.ai
                              ? sourceFood.protein
                              : (aiNut?.protein ?? sourceFood.protein);
                          final aiCarbs = currentSource == FoodSource.ai
                              ? sourceFood.carbs
                              : (aiNut?.carbohydrate ?? sourceFood.carbs);
                          final aiFat = currentSource == FoodSource.ai
                              ? sourceFood.fat
                              : (aiNut?.fat ?? sourceFood.fat);
                          return _SourceOption(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: const Color(0xFF14B8A6),
                            title: 'Estimativa da IA',
                            subtitle:
                                '$aiCalories kcal · ${aiProtein.toStringAsFixed(1)}p · ${aiCarbs.toStringAsFixed(1)}c · ${aiFat.toStringAsFixed(1)}g',
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

                        if (catalogSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Outras sugestões',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: secondary.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...visibleCatalogSuggestions.map((suggestion) {
                            final suggestionId = _parseInt(suggestion['id']);
                            return _SourceOption(
                              icon: Icons.storage_rounded,
                              iconColor: const Color(0xFF2563EB),
                              title: _catalogOptionTitle(
                                suggestion,
                                food: sourceFood,
                              ),
                              subtitle: _catalogOptionSubtitle(suggestion),
                              selected: currentSource == FoodSource.catalog &&
                                  sourceFood.sourceId == suggestionId,
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

                        const SizedBox(height: 12),

                        // Caso nao tenha nenhuma fonte salva, oferece cadastrar.
                        if (favorite == null &&
                            currentSource != FoodSource.manual &&
                            recent == null &&
                            catalogSuggestions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Voce ainda nao tem versoes salvas ou outras sugestoes para ${sourceFood.name}. Edite o alimento para salvar como favorito.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: secondary.withValues(alpha: 0.8)),
                            ),
                          ),

                        if (currentSource != FoodSource.manual) ...[
                          const SizedBox(height: 8),
                          _SourceOption(
                            icon: Icons.tune_rounded,
                            iconColor: primary,
                            title: 'Editar manualmente',
                            subtitle: 'Digite os macros manualmente',
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
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // Executa a acao escolhida apos o source picker fechar completamente.
    // Isso evita que dois bottom sheets fiquem animando ao mesmo tempo,
    // que causa o erro `_dependents.isEmpty` em InheritedElement quando o
    // segundo modal eh fechado.
    if (!mounted || action == null) return;

    switch (action.action) {
      case _FoodSourceAction.editDetails:
        await _openFoodDetailsEditor(food: sourceFood);
        break;
      case _FoodSourceAction.favorite:
        if (favorite != null) {
          widget.onSwap?.call(
            _applyAlternativeMacros(
              favorite,
              FoodSource.favorite,
              food: sourceFood,
            ),
          );
        }
        break;
      case _FoodSourceAction.recent:
        if (recent != null) {
          widget.onSwap?.call(
            _applyAlternativeMacros(
              recent,
              FoodSource.recent,
              food: sourceFood,
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
              food: sourceFood,
            ),
          );
        }
        break;
      case _FoodSourceAction.ai:
        final restored = _restoreAiMacros(food: sourceFood);
        if (restored != null) {
          widget.onSwap?.call(restored);
        }
        break;
      case _FoodSourceAction.manual:
        await _openManualMacroEditor();
        break;
    }
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
    final updatedFood = await showModalBottomSheet<Food>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return _ManualMacroEditorSheet(
          food: food,
          isDarkMode: widget.isDarkMode,
        );
      },
    );

    if (!mounted || updatedFood == null) return;
    widget.onSwap?.call(updatedFood);
  }

  String _macrosSummary(Map<String, dynamic> data) {
    final summary = _formatMacroSummary(
      calories: _parseNumeric(data['calories']),
      protein: _parseNumeric(data['protein']),
      carbs: _parseNumeric(data['carbs']),
      fat: _parseNumeric(data['fat']),
    );
    final base = _parseNumeric(data['baseAmount']);
    final unit = _readText(data['baseUnit']) ?? 'g';
    return '$summary  (por ${_formatServingAmount(base, unit)})';
  }

  String _formatMacroSummary({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    return '${_formatNumber(calories, decimals: 0)} kcal · '
        '${protein.toStringAsFixed(1)}p · '
        '${carbs.toStringAsFixed(1)}c · '
        '${fat.toStringAsFixed(1)}g';
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
                          loading: _loadingAlternatives,
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
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
  }

  @override
  void dispose() {
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
