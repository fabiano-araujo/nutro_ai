import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../models/FoodRegion.dart';
import 'food_page.dart';
import '../i18n/app_localizations_extension.dart';
import '../helpers/scraper_helper.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({Key? key}) : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScraperHelper _scraperHelper = ScraperHelper();
  late TabController _tabController;

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<Food> _recentFoods = [];
  List<Food> _favoriteFoods = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scraperHelper.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    final url = 'https://mobile.fatsecret.com.br/calorias-nutrição/search?q=${Uri.encodeComponent(query)}';

    // Carrega a URL
    await _scraperHelper.loadUrl(url);
  }

  Future<void> _extractFoodData() async {
    await _scraperHelper.extractContent(
      script: ScraperHelper.getFatSecretSearchResultsScript(),
      callback: (data) {
        if (data != null && data is String) {
          try {
            final List<dynamic> parsed = jsonDecode(data);
            final List<Map<String, dynamic>> results = [];

            for (var item in parsed) {
              if (item is Map) {
                results.add(Map<String, dynamic>.from(item));
              }
            }

            print('Found ${results.length} foods');
            setState(() {
              _searchResults = results;
              _isLoading = false;
            });
          } catch (e) {
            print('Error parsing JSON: $e');
            setState(() {
              _searchResults = [];
              _isLoading = false;
            });
          }
        } else {
          print('No data received from scraper');
          setState(() {
            _searchResults = [];
            _isLoading = false;
          });
        }
      },
      timeoutSeconds: 15,
    );
  }

  Food _convertToFood(Map<String, dynamic> data) {
    final calories = double.tryParse((data['calorias'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
    final protein = double.tryParse((data['proteina'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
    final carbs = double.tryParse((data['carboidratos'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
    final fat = double.tryParse((data['gordura'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0;

    return Food(
      name: data['nome'] ?? 'Unknown',
      brand: data['marca'],
      emoji: '🍽️',
      nutrients: [
        Nutrient(
          idFood: 0,
          servingSize: 100.0,
          servingUnit: 'g',
          calories: calories,
          protein: protein,
          carbohydrate: carbs,
          fat: fat,
        ),
      ],
      foodRegions: [
        FoodRegion(
          regionCode: 'BR',
          languageCode: 'pt',
          idFood: 0,
          translation: data['nome'] ?? 'Unknown',
          portions: [],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode
        ? Color(0xFFAEB7CE)
        : AppTheme.textSecondaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr.translate('search_food'),
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.barcode_reader,
              color: textColor,
            ),
            onPressed: () {
              // TODO: Implementar scan de código de barras
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Barcode scanner coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: context.tr.translate('what_did_you_eat'),
                  hintStyle: TextStyle(
                    color: secondaryTextColor.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.primaryColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: _onSearchSubmitted,
              ),
            ),
          ),

          // Tabs
          if (!_isSearching)
            Container(
              color: backgroundColor,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: secondaryTextColor,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: context.tr.translate('recent')),
                  Tab(text: context.tr.translate('favorites')),
                ],
              ),
            ),

          // Content with WebView in Stack
          Expanded(
            child: Stack(
              children: [
                // WebView (sempre ativo mas invisível)
                Positioned.fill(
                  child: InAppWebView(
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                    ),
                    onWebViewCreated: _scraperHelper.onWebViewCreated,
                    onLoadStop: (controller, url) async {
                      _scraperHelper.onLoadFinished(controller, url);
                      // Wait a bit for the page to fully render
                      await Future.delayed(Duration(milliseconds: 1500));
                      await _extractFoodData();
                    },
                  ),
                ),

                // UI visível (por cima do WebView)
                Positioned.fill(
                  child: Container(
                    color: backgroundColor,
                    child: _isSearching
                        ? _buildSearchResults(isDarkMode, textColor, secondaryTextColor, cardColor)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRecentList(isDarkMode, textColor, secondaryTextColor, cardColor),
                              _buildFavoritesList(isDarkMode, textColor, secondaryTextColor, cardColor),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDarkMode, Color textColor, Color secondaryTextColor, Color cardColor) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              context.tr.translate('searching'),
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              context.tr.translate('no_results_found'),
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return _buildFoodResultCard(item, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  Widget _buildFoodResultCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
  ) {
    final calories = item['calorias'] ?? '0';
    final protein = item['proteina'] ?? '0';
    final carbs = item['carboidratos'] ?? '0';
    final fat = item['gordura'] ?? '0';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          final food = _convertToFood(item);
          final foodUrl = item['link'] != null
              ? 'https://mobile.fatsecret.com.br${item['link']}'
              : null;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodPage(
                food: food,
                foodUrl: foodUrl,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food name
              Text(
                item['nome'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),

              // Brand
              if (item['marca'] != null && item['marca'].isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  item['marca'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],

              SizedBox(height: 8),

              // Description
              if (item['descricao'] != null && item['descricao'].isNotEmpty)
                Text(
                  item['descricao'],
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              SizedBox(height: 12),

              // Macros
              Row(
                children: [
                  _buildMacroChip('Cal', calories, 'kcal', Color(0xFF4CAF50), isDarkMode),
                  SizedBox(width: 8),
                  _buildMacroChip('P', protein, 'g', Color(0xFF9575CD), isDarkMode),
                  SizedBox(width: 8),
                  _buildMacroChip('C', carbs, 'g', Color(0xFFA1887F), isDarkMode),
                  SizedBox(width: 8),
                  _buildMacroChip('F', fat, 'g', Color(0xFF90A4AE), isDarkMode),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, String unit, Color color, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '$value$unit',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentList(bool isDarkMode, Color textColor, Color secondaryTextColor, Color cardColor) {
    if (_recentFoods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              context.tr.translate('no_recent_searches'),
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _recentFoods.length,
      itemBuilder: (context, index) {
        final food = _recentFoods[index];
        return _buildFoodCard(food, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  Widget _buildFavoritesList(bool isDarkMode, Color textColor, Color secondaryTextColor, Color cardColor) {
    if (_favoriteFoods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_outline,
              size: 64,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              context.tr.translate('no_favorite_foods'),
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _favoriteFoods.length,
      itemBuilder: (context, index) {
        final food = _favoriteFoods[index];
        return _buildFoodCard(food, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  Widget _buildFoodCard(Food food, bool isDarkMode, Color textColor, Color secondaryTextColor, Color cardColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodPage(food: food),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    food.emoji,
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Name and calories
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${food.calories} kcal',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
