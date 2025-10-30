import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../models/FoodRegion.dart';
import 'food_page.dart';
import '../i18n/app_localizations_extension.dart';
import '../helpers/scraper_helper.dart';
import '../helpers/webview_helper.dart';
import '../providers/food_history_provider.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({Key? key}) : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScraperHelper _scraperHelper = ScraperHelper();
  late TabController _tabController;

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    final url =
        'https://mobile.fatsecret.com.br/calorias-nutrição/search?q=${Uri.encodeComponent(query)}';

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
    final calories = double.tryParse(
            (data['calorias'] ?? '0').toString().replaceAll(',', '.')) ??
        0.0;
    final protein = double.tryParse(
            (data['proteina'] ?? '0').toString().replaceAll(',', '.')) ??
        0.0;
    final carbs = double.tryParse(
            (data['carboidratos'] ?? '0').toString().replaceAll(',', '.')) ??
        0.0;
    final fat = double.tryParse(
            (data['gordura'] ?? '0').toString().replaceAll(',', '.')) ??
        0.0;

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
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

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
              Icons
                  .barcode_reader, // Ícone de código de barras com linhas horizontais
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
                color: isDarkMode
                    ? textColor.withValues(alpha: 0.15)
                    : textColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(80),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: context.tr.translate('what_did_you_eat'),
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? AppTheme.primaryColor.withValues(alpha: 1)
                        : AppTheme.primaryColor.withValues(alpha: 1),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
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
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: textColor,
                    unselectedLabelColor: secondaryTextColor,
                    labelStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    indicatorColor: AppTheme.primaryColor,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(text: 'Frequentes'),
                      Tab(text: context.tr.translate('recent')),
                      Tab(text: context.tr.translate('favorites')),
                    ],
                  ),
                  Container(
                    height: 1,
                    color: isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFFAFAFA),
                  ),
                ],
              ),
            ),

          // Content with WebView in Stack
          Expanded(
            child: Stack(
              children: [
                // WebView (sempre ativo mas invisível)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.0,
                    child: InAppWebView(
                      initialSettings: WebViewHelper.getOptimizedSettings(),
                      onWebViewCreated: _scraperHelper.onWebViewCreated,
                      onLoadStop: (controller, url) async {
                        _scraperHelper.onLoadFinished(controller, url);
                        // Wait a bit for the page to fully render
                        await Future.delayed(Duration(milliseconds: 500));
                        await _extractFoodData();
                      },
                    ),
                  ),
                ),

                // UI visível (por cima do WebView)
                Positioned.fill(
                  child: Container(
                    color: backgroundColor,
                    child: _isSearching
                        ? _buildSearchResults(isDarkMode, textColor,
                            secondaryTextColor, cardColor)
                        : Consumer<FoodHistoryProvider>(
                            builder: (context, historyProvider, child) {
                              return TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildFrequentList(
                                      historyProvider.frequents,
                                      isDarkMode,
                                      textColor,
                                      secondaryTextColor,
                                      cardColor),
                                  _buildRecentList(
                                      historyProvider.recents,
                                      isDarkMode,
                                      textColor,
                                      secondaryTextColor,
                                      cardColor),
                                  _buildFavoritesList(
                                      historyProvider.favorites,
                                      isDarkMode,
                                      textColor,
                                      secondaryTextColor,
                                      cardColor),
                                ],
                              );
                            },
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

  Widget _buildSearchResults(bool isDarkMode, Color textColor,
      Color secondaryTextColor, Color cardColor) {
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
      padding: EdgeInsets.zero,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return _buildFoodResultCard(
            item, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  String _buildSubtitle(Map<String, dynamic> item) {
    final calories = item['calorias'] ?? '0';
    final porcao = item['porcao'] ?? '100g';

    return '$calories kcal • $porcao';
  }

  Widget _buildFoodResultCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
  ) {
    return _FoodListItem(
      emoji: '🍽️',
      name: item['nome'] ?? 'Unknown',
      subtitle: _buildSubtitle(item),
      isDarkMode: isDarkMode,
      textColor: textColor,
      secondaryTextColor: secondaryTextColor,
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
    );
  }

  Widget _buildRecentList(List<Food> recentFoods, bool isDarkMode,
      Color textColor, Color secondaryTextColor, Color cardColor) {
    if (recentFoods.isEmpty) {
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
      padding: EdgeInsets.zero,
      itemCount: recentFoods.length,
      itemBuilder: (context, index) {
        final food = recentFoods[index];
        return _buildFoodCard(
            food, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  Widget _buildFavoritesList(List<Food> favoriteFoods, bool isDarkMode,
      Color textColor, Color secondaryTextColor, Color cardColor) {
    if (favoriteFoods.isEmpty) {
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
      padding: EdgeInsets.zero,
      itemCount: favoriteFoods.length,
      itemBuilder: (context, index) {
        final food = favoriteFoods[index];
        return _buildFoodCard(
            food, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  Widget _buildFrequentList(List<Food> frequentFoods, bool isDarkMode,
      Color textColor, Color secondaryTextColor, Color cardColor) {
    if (frequentFoods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 64,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Nenhum alimento frequente',
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
      padding: EdgeInsets.zero,
      itemCount: frequentFoods.length,
      itemBuilder: (context, index) {
        final food = frequentFoods[index];
        return _buildFoodCard(
            food, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  Widget _buildFoodCard(Food food, bool isDarkMode, Color textColor,
      Color secondaryTextColor, Color cardColor) {
    // Get serving size info
    final servingInfo = food.nutrients?.isNotEmpty == true
        ? '${food.nutrients!.first.servingSize.toStringAsFixed(0)}${food.nutrients!.first.servingUnit}'
        : '100g';
    final subtitle = '${food.calories} kcal • $servingInfo';

    return _FoodListItem(
      emoji: food.emoji,
      name: food.name,
      subtitle: subtitle,
      isDarkMode: isDarkMode,
      textColor: textColor,
      secondaryTextColor: secondaryTextColor,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodPage(food: food),
          ),
        );
      },
    );
  }
}

class _FoodListItem extends StatelessWidget {
  final String emoji;
  final String name;
  final String subtitle;
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryTextColor;
  final VoidCallback onTap;

  const _FoodListItem({
    Key? key,
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryTextColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    emoji,
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Name and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Add button
              Icon(
                Icons.add_circle_outline,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
