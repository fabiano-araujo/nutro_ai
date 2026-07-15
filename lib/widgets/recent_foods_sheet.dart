import 'package:flutter/material.dart';
import '../services/favorite_food_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../i18n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Bottom sheet com abas: Recentes, Favoritos, Refeições
/// Permite ao usuário selecionar alimentos ou refeições para inserir no chat.
class RecentFoodsSheet extends StatefulWidget {
  /// Callback quando um alimento individual é selecionado (insere texto no chat)
  final void Function(FavoriteFood food) onFoodSelected;

  /// Callback quando uma refeição inteira é selecionada (repete refeição)
  final void Function(RepeatableMeal meal) onMealSelected;

  /// Permite substituir a fonte de dados em testes de widget.
  final FavoriteFoodService? serviceOverride;

  const RecentFoodsSheet({
    super.key,
    required this.onFoodSelected,
    required this.onMealSelected,
    this.serviceOverride,
  });

  @override
  State<RecentFoodsSheet> createState() => _RecentFoodsSheetState();
}

class _RecentFoodsSheetState extends State<RecentFoodsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final DraggableScrollableController _sheetController;
  FavoriteFoodService? _service;
  int _activeTabIndex = 0;
  bool _isExpandingSheet = false;

  List<FavoriteFood> _recents = [];
  List<FavoriteFood> _favorites = [];
  List<RepeatableMeal> _meals = [];

  bool _loadingRecents = true;
  bool _loadingFavorites = true;
  bool _loadingMeals = true;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _initService();
  }

  void _handleTabChanged() {
    if (_activeTabIndex == _tabController.index) return;
    setState(() {
      _activeTabIndex = _tabController.index;
    });
  }

  void _expandSheetFromScroll() {
    if (_isExpandingSheet ||
        !_sheetController.isAttached ||
        _sheetController.size >= 0.98) {
      return;
    }

    _isExpandingSheet = true;
    _sheetController
        .animateTo(
      1.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    )
        .whenComplete(() {
      if (!mounted) return;
      _isExpandingSheet = false;
    });
  }

  void _initService() {
    if (widget.serviceOverride != null) {
      _service = widget.serviceOverride;
      _loadAll();
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token != null && token.isNotEmpty) {
      _service = FavoriteFoodService(token: token);
      _loadAll();
    } else {
      // Sem token: encerra loading imediatamente e mostra estado vazio
      setState(() {
        _loadingRecents = false;
        _loadingFavorites = false;
        _loadingMeals = false;
      });
    }
  }

  Future<void> _loadAll() async {
    _loadRecents();
    _loadFavorites();
    _loadMeals();
  }

  Future<void> _loadRecents() async {
    try {
      final data = await _service?.getRecents() ?? [];
      if (mounted)
        setState(() {
          _recents = data;
          _loadingRecents = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingRecents = false;
        });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final data = await _service?.getFavorites() ?? [];
      if (mounted)
        setState(() {
          _favorites = data;
          _loadingFavorites = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingFavorites = false;
        });
    }
  }

  Future<void> _loadMeals() async {
    try {
      final data = await _service?.getRepeatableMeals() ?? [];
      // Apenas refeições com mais de um alimento são consideradas "refeições"
      final filtered = data.where((m) => m.foods.length > 1).toList();
      if (mounted)
        setState(() {
          _meals = filtered;
          _loadingMeals = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingMeals = false;
        });
    }
  }

  // ============================================
  // Ações de exclusão / opções
  // ============================================

  Future<bool> _confirmDelete(String itemName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_tr('confirm_delete')),
          content: Text(
            _tr('delete_item_question', {'name': itemName}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC362E),
              ),
              child: Text(_tr('delete')),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _handleDeleteFood(FavoriteFood food,
      {required bool isRecent}) async {
    setState(() {
      if (isRecent) {
        _recents.removeWhere((f) => f.id == food.id);
      } else {
        _favorites.removeWhere((f) => f.id == food.id);
      }
    });

    final ok = isRecent
        ? await (_service?.deleteRecent(food.id) ?? Future.value(false))
        : await (_service?.deleteFavorite(food.id) ?? Future.value(false));

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (isRecent ? _tr('recent_deleted') : _tr('favorite_deleted'))
              : _tr('something_went_wrong'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDeleteMeal(RepeatableMeal meal) async {
    setState(() {
      _meals.removeWhere((m) => m.id == meal.id);
    });

    final ok = await (_service?.deleteMeal(meal.id) ?? Future.value(false));

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(ok ? _tr('meal_deleted') : _tr('something_went_wrong')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleFavoriteRecent(FavoriteFood food) async {
    final ok = await (_service?.addFavorite(food) ?? Future.value(false));
    if (!mounted) return;

    if (ok) {
      // Recarrega favoritos para refletir o novo item
      _loadFavorites();
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          ok ? _tr('added_to_favorites') : _tr('something_went_wrong'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFoodOptions(FavoriteFood food, {required bool isRecent}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDarkMode ? AppTheme.darkCardColor : AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final actions = <_OptionAction>[
          _OptionAction(
            label: _tr('add'),
            icon: Icons.add_rounded,
            onTap: () {
              Navigator.pop(ctx);
              widget.onFoodSelected(food);
              Navigator.pop(context);
            },
          ),
          if (isRecent)
            _OptionAction(
              label: _tr('add_to_favorites'),
              icon: Icons.favorite_rounded,
              onTap: () {
                Navigator.pop(ctx);
                _handleFavoriteRecent(food);
              },
            ),
          _OptionAction(
            label: isRecent ? _tr('delete') : _tr('remove_from_favorites'),
            icon: Icons.delete_outline_rounded,
            danger: true,
            onTap: () {
              Navigator.pop(ctx);
              _handleDeleteFood(food, isRecent: isRecent);
            },
          ),
        ];

        return _OptionsSheetContent(
          title: food.name,
          subtitle: _tr('options'),
          emoji: food.emoji ?? '🍽️',
          actions: actions,
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  void _showMealOptions(RepeatableMeal meal) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDarkMode ? AppTheme.darkCardColor : AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final title = meal.name?.isNotEmpty == true
            ? meal.name!
            : _localizedMealType(meal.type);
        final actions = <_OptionAction>[
          _OptionAction(
            label: _tr('repeat'),
            icon: Icons.replay_rounded,
            onTap: () {
              Navigator.pop(ctx);
              widget.onMealSelected(meal);
              Navigator.pop(context);
            },
          ),
          _OptionAction(
            label: _tr('delete'),
            icon: Icons.delete_outline_rounded,
            danger: true,
            onTap: () {
              Navigator.pop(ctx);
              _handleDeleteMeal(meal);
            },
          ),
        ];

        return _OptionsSheetContent(
          title: title,
          subtitle: _tr('options'),
          emoji: meal.typeEmoji,
          actions: actions,
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDarkMode ? const Color(0xFF151515) : AppTheme.backgroundColor;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final subtitleColor =
        isDarkMode ? Colors.grey[400] : AppTheme.textSecondaryColor;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.65, 1.0],
        expand: false,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: subtitleColor?.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('quick_add_food'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l10n.translate('values_per_serving'),
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.translate('close'),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.white,
                            foregroundColor: subtitleColor,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppTheme.onPrimaryFor(isDarkMode),
                        unselectedLabelColor: subtitleColor,
                        indicator: BoxDecoration(
                          color: isDarkMode
                              ? AppTheme.primaryColorDarkMode
                              : AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: isDarkMode ? 0.08 : 0.18,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(
                            child: _SheetTabLabel(
                              icon: Icons.history_rounded,
                              label: l10n.translate('recent'),
                            ),
                          ),
                          Tab(
                            child: _SheetTabLabel(
                              icon: Icons.favorite_rounded,
                              label: l10n.translate('favorites'),
                            ),
                          ),
                          Tab(
                            child: _SheetTabLabel(
                              icon: Icons.restaurant_menu_rounded,
                              label: l10n.translate('meals'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
                        if ((notification.scrollDelta ?? 0) > 0) {
                          _expandSheetFromScroll();
                        }
                        return false;
                      },
                      child: _buildActiveTabContent(
                        scrollController,
                        textColor,
                        subtitleColor,
                        isDarkMode,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTabContent(
    ScrollController scrollController,
    Color? textColor,
    Color? subtitleColor,
    bool isDarkMode,
  ) {
    switch (_activeTabIndex) {
      case 1:
        return _buildFoodList(
          _favorites,
          _loadingFavorites,
          textColor,
          subtitleColor,
          isDarkMode,
          scrollController: scrollController,
          isRecent: false,
        );
      case 2:
        return _buildMealList(
          textColor,
          subtitleColor,
          isDarkMode,
          scrollController,
        );
      case 0:
      default:
        return _buildFoodList(
          _recents,
          _loadingRecents,
          textColor,
          subtitleColor,
          isDarkMode,
          scrollController: scrollController,
          isRecent: true,
        );
    }
  }

  Widget _buildFoodList(
    List<FavoriteFood> foods,
    bool loading,
    Color? textColor,
    Color? subtitleColor,
    bool isDarkMode, {
    required ScrollController scrollController,
    required bool isRecent,
  }) {
    if (loading) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (foods.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          SizedBox(
            height: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRecent ? Icons.history : Icons.favorite_border,
                  size: 48,
                  color: subtitleColor,
                ),
                const SizedBox(height: 12),
                Text(
                  isRecent ? _tr('no_recent_foods') : _tr('no_saved_favorites'),
                  style: TextStyle(color: subtitleColor, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isRecent
                      ? _tr('recent_foods_empty_hint')
                      : _tr('favorite_foods_empty_hint'),
                  style: TextStyle(
                    color: subtitleColor?.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return _buildFoodTile(
          food,
          textColor,
          subtitleColor,
          isDarkMode,
          isRecent: isRecent,
        );
      },
    );
  }

  Widget _buildFoodTile(
    FavoriteFood food,
    Color? textColor,
    Color? subtitleColor,
    bool isDarkMode, {
    required bool isRecent,
  }) {
    final usageText = food.usageCount != null && food.usageCount! > 1
        ? _tr('used_times', {'count': food.usageCount.toString()})
        : _tr('ready_to_add');
    final servingText = _formatServing(food.baseAmount, food.baseUnit);

    return Dismissible(
      key: ValueKey('${isRecent ? 'recent' : 'favorite'}_${food.id}'),
      direction: DismissDirection.endToStart,
      background: _SwipeDeleteBackground(isDarkMode: isDarkMode),
      confirmDismiss: (_) => _confirmDelete(food.name),
      onDismissed: (_) => _handleDeleteFood(food, isRecent: isRecent),
      child: _RecentItemCard(
        isDarkMode: isDarkMode,
        onTap: () {
          widget.onFoodSelected(food);
          Navigator.pop(context);
        },
        onLongPress: () => _showFoodOptions(food, isRecent: isRecent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _EmojiBadge(
                  emoji: food.emoji ?? '🍽️',
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_tr('serving')} $servingText  •  $usageText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _QuickActionButton(
                  label: _tr('add'),
                  icon: Icons.add_rounded,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MacroSummaryBar(
              isDarkMode: isDarkMode,
              metrics: [
                _MacroMetricData(
                  label: _tr('calories'),
                  value: '${food.calories} kcal',
                  color: MacroTheme.caloriesColor,
                ),
                _MacroMetricData(
                  label: _tr('protein_full'),
                  value: '${_formatNumber(food.protein)} g',
                  color: MacroTheme.proteinColor,
                ),
                _MacroMetricData(
                  label: _tr('carbs'),
                  value: '${_formatNumber(food.carbs)} g',
                  color: MacroTheme.carbsColor,
                ),
                _MacroMetricData(
                  label: _tr('fat'),
                  value: '${_formatNumber(food.fat)} g',
                  color: MacroTheme.fatColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _tr(String key, [Map<String, String>? params]) {
    var text = AppLocalizations.of(context).translate(key);
    params?.forEach((key, value) {
      text = text.replaceAll('{$key}', value);
    });
    return text;
  }

  String _formatServing(double amount, String unit) {
    final normalizedUnit = unit.trim();
    final amountText = _formatNumber(amount);
    if (normalizedUnit.isEmpty) return amountText;
    return '$amountText $normalizedUnit';
  }

  String _formatNumber(double value) {
    if ((value - value.round()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  Widget _buildMealList(
    Color? textColor,
    Color? subtitleColor,
    bool isDarkMode,
    ScrollController scrollController,
  ) {
    if (_loadingMeals) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_meals.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          SizedBox(
            height: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 48, color: subtitleColor),
                const SizedBox(height: 12),
                Text(
                  _tr('no_registered_meals'),
                  style: TextStyle(color: subtitleColor, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _tr('repeatable_meals_empty_hint'),
                  style: TextStyle(
                    color: subtitleColor?.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      itemCount: _meals.length,
      itemBuilder: (context, index) {
        final meal = _meals[index];
        return _buildMealTile(meal, textColor, subtitleColor, isDarkMode);
      },
    );
  }

  Widget _buildMealTile(
    RepeatableMeal meal,
    Color? textColor,
    Color? subtitleColor,
    bool isDarkMode,
  ) {
    final dateStr = meal.date != null
        ? '${meal.date!.day.toString().padLeft(2, '0')}/${meal.date!.month.toString().padLeft(2, '0')}'
        : '';
    final title = meal.name?.isNotEmpty == true
        ? meal.name!
        : _localizedMealType(meal.type);
    final foodNames =
        meal.foodNames.isNotEmpty ? meal.foodNames : _tr('meal_foods_title');
    final details =
        dateStr.isEmpty ? foodNames : '$foodNames  •  ${_tr('date')} $dateStr';

    return Dismissible(
      key: ValueKey('meal_${meal.id}'),
      direction: DismissDirection.endToStart,
      background: _SwipeDeleteBackground(isDarkMode: isDarkMode),
      confirmDismiss: (_) => _confirmDelete(title),
      onDismissed: (_) => _handleDeleteMeal(meal),
      child: _RecentItemCard(
        isDarkMode: isDarkMode,
        onTap: () {
          widget.onMealSelected(meal);
          Navigator.pop(context);
        },
        onLongPress: () => _showMealOptions(meal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _EmojiBadge(
                  emoji: meal.typeEmoji,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _QuickActionButton(
                  label: _tr('repeat'),
                  icon: Icons.replay_rounded,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MacroSummaryBar(
              isDarkMode: isDarkMode,
              metrics: [
                _MacroMetricData(
                  label: _tr('calories'),
                  value: '${meal.calories} kcal',
                  color: MacroTheme.caloriesColor,
                ),
                _MacroMetricData(
                  label: _tr('protein_full'),
                  value: '${_formatNumber(meal.protein)} g',
                  color: MacroTheme.proteinColor,
                ),
                _MacroMetricData(
                  label: _tr('carbs'),
                  value: '${_formatNumber(meal.carbs)} g',
                  color: MacroTheme.carbsColor,
                ),
                _MacroMetricData(
                  label: _tr('fat'),
                  value: '${_formatNumber(meal.fat)} g',
                  color: MacroTheme.fatColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _localizedMealType(String type) {
    switch (type) {
      case 'breakfast':
      case 'lunch':
      case 'dinner':
      case 'snack':
      case 'free_meal':
        return _tr(type);
      case 'freeMeal':
        return _tr('free_meal');
      default:
        return type;
    }
  }
}

class _SheetTabLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SheetTabLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RecentItemCard extends StatelessWidget {
  final bool isDarkMode;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RecentItemCard({
    required this.isDarkMode,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.dividerColor.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  final String emoji;
  final bool isDarkMode;

  const _EmojiBadge({
    required this.emoji,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.07)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDarkMode;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final showLabel = MediaQuery.sizeOf(context).width >= 350;
    final backgroundColor =
        (isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor)
            .withValues(alpha: isDarkMode ? 0.18 : 0.12);
    final foregroundColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryDarkColor;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 40),
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 9.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: showLabel ? 18 : 21,
                color: foregroundColor,
              ),
              if (showLabel) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroMetricData {
  final String label;
  final String value;
  final Color color;

  const _MacroMetricData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _MacroSummaryBar extends StatelessWidget {
  final List<_MacroMetricData> metrics;
  final bool isDarkMode;

  const _MacroSummaryBar({
    required this.metrics,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.dividerColor.withValues(alpha: 0.9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.045)
            : AppTheme.surfaceColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            Expanded(
              child: _MacroMetric(
                data: metrics[index],
                isDarkMode: isDarkMode,
              ),
            ),
            if (index < metrics.length - 1)
              Container(
                width: 1,
                height: 27,
                color: dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _MacroMetric extends StatelessWidget {
  final _MacroMetricData data;
  final bool isDarkMode;

  const _MacroMetric({
    required this.data,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final valueColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Semantics(
      label: '${data.label}: ${data.value}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: data.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.value,
                maxLines: 1,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  final bool isDarkMode;

  const _SwipeDeleteBackground({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final color =
        isDarkMode ? const Color(0xFFB3261E) : const Color(0xFFDC362E);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

class _OptionAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  _OptionAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });
}

class _OptionsSheetContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final List<_OptionAction> actions;
  final bool isDarkMode;

  const _OptionsSheetContent({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.actions,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final subtitleColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _EmojiBadge(emoji: emoji, isDarkMode: isDarkMode),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 4),
            ...actions.map(
              (a) => _OptionTile(
                action: a,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _OptionAction action;
  final bool isDarkMode;

  const _OptionTile({
    required this.action,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final dangerColor =
        isDarkMode ? const Color(0xFFFF6B6B) : const Color(0xFFDC362E);
    final defaultColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final color = action.danger ? dangerColor : defaultColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              Icon(action.icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  action.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
