import 'package:flutter/material.dart';
import '../services/favorite_food_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Bottom sheet com abas: Recentes, Favoritos, Refeições
/// Permite ao usuário selecionar alimentos ou refeições para inserir no chat.
class RecentFoodsSheet extends StatefulWidget {
  /// Callback quando um alimento individual é selecionado (insere texto no chat)
  final void Function(FavoriteFood food) onFoodSelected;

  /// Callback quando uma refeição inteira é selecionada (repete refeição)
  final void Function(RepeatableMeal meal) onMealSelected;

  const RecentFoodsSheet({
    super.key,
    required this.onFoodSelected,
    required this.onMealSelected,
  });

  @override
  State<RecentFoodsSheet> createState() => _RecentFoodsSheetState();
}

class _RecentFoodsSheetState extends State<RecentFoodsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FavoriteFoodService? _service;

  List<FavoriteFood> _recents = [];
  List<FavoriteFood> _favorites = [];
  List<RepeatableMeal> _meals = [];

  bool _loadingRecents = true;
  bool _loadingFavorites = true;
  bool _loadingMeals = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initService();
  }

  void _initService() {
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
      if (mounted) setState(() { _recents = data; _loadingRecents = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingRecents = false; });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final data = await _service?.getFavorites() ?? [];
      if (mounted) setState(() { _favorites = data; _loadingFavorites = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingFavorites = false; });
    }
  }

  Future<void> _loadMeals() async {
    try {
      final data = await _service?.getRepeatableMeals() ?? [];
      if (mounted) setState(() { _meals = data; _loadingMeals = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingMeals = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final subtitleColor = isDarkMode ? Colors.grey[400] : AppTheme.textSecondaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: isDarkMode ? Colors.white : AppTheme.primaryColor,
            unselectedLabelColor: subtitleColor,
            indicatorColor: isDarkMode ? Colors.white : AppTheme.primaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(icon: Icon(Icons.history, size: 20), text: 'Recentes'),
              Tab(icon: Icon(Icons.favorite, size: 20), text: 'Favoritos'),
              Tab(icon: Icon(Icons.restaurant_menu, size: 20), text: 'Refeições'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFoodList(_recents, _loadingRecents, textColor, subtitleColor, isDarkMode, isRecent: true),
                _buildFoodList(_favorites, _loadingFavorites, textColor, subtitleColor, isDarkMode, isRecent: false),
                _buildMealList(textColor, subtitleColor, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodList(
    List<FavoriteFood> foods,
    bool loading,
    Color? textColor,
    Color? subtitleColor,
    bool isDarkMode, {
    required bool isRecent,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (foods.isEmpty) {
      return Center(
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
              isRecent
                  ? 'Nenhum alimento recente'
                  : 'Nenhum favorito salvo',
              style: TextStyle(color: subtitleColor, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              isRecent
                  ? 'Seus alimentos aparecerão aqui após registrar refeições'
                  : 'Favorite alimentos para acessá-los rapidamente',
              style: TextStyle(color: subtitleColor?.withOpacity(0.7), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return _buildFoodTile(food, textColor, subtitleColor, isDarkMode);
      },
    );
  }

  Widget _buildFoodTile(
    FavoriteFood food,
    Color? textColor,
    Color? subtitleColor,
    bool isDarkMode,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            food.emoji ?? '🍽️',
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
      title: Text(
        food.name,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${food.baseAmount.toStringAsFixed(0)}${food.baseUnit} · ${food.macrosSummary}',
        style: TextStyle(color: subtitleColor, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (food.usageCount != null && food.usageCount! > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF333333) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${food.usageCount}x',
                style: TextStyle(color: subtitleColor, fontSize: 11),
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.add_circle_outline, color: subtitleColor, size: 22),
        ],
      ),
      onTap: () {
        widget.onFoodSelected(food);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildMealList(Color? textColor, Color? subtitleColor, bool isDarkMode) {
    if (_loadingMeals) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_meals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 48, color: subtitleColor),
            const SizedBox(height: 12),
            Text(
              'Nenhuma refeição registrada',
              style: TextStyle(color: subtitleColor, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Suas refeições aparecerão aqui para repetir',
              style: TextStyle(color: subtitleColor?.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(meal.typeEmoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
      title: Text(
        meal.name ?? meal.type,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.foodNames,
            style: TextStyle(color: subtitleColor, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${meal.calories}cal · ${meal.protein.toStringAsFixed(0)}p · ${meal.carbs.toStringAsFixed(0)}c · ${meal.fat.toStringAsFixed(0)}g${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
            style: TextStyle(color: subtitleColor?.withOpacity(0.7), fontSize: 11),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Icon(Icons.replay, color: subtitleColor, size: 22),
      onTap: () {
        widget.onMealSelected(meal);
        Navigator.pop(context);
      },
    );
  }
}
