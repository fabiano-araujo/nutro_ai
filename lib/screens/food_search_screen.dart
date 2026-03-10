import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../models/FoodRegion.dart';
import '../models/Portion.dart';
import '../models/meal_model.dart';
import 'food_page.dart';
import '../i18n/app_localizations_extension.dart';
import '../helpers/scraper_helper.dart';
import '../helpers/webview_helper.dart';
import '../providers/food_history_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../util/app_constants.dart';
import '../services/auth_service.dart';
import '../services/favorite_food_service.dart';

class FoodSearchScreen extends StatefulWidget {
  final MealType? selectedMealType;

  const FoodSearchScreen({Key? key, this.selectedMealType}) : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScraperHelper _scraperHelper = ScraperHelper();
  late TabController _tabController;
  MealType? _selectedMealType;

  bool _isSearching = false;
  List<Food> _apiResults = [];
  List<Map<String, dynamic>> _webResults = [];
  bool _isLoading = false;
  bool _isLoadingApi = false;
  bool _isLoadingWeb = false;

  List<FavoriteFood> _serverRecents = [];
  bool _loadingServerRecents = true;
  List<FavoriteFood> _serverFrequents = [];
  bool _loadingServerFrequents = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMealType = widget.selectedMealType;
    _loadServerData();
  }

  Future<void> _loadServerData() async {
    try {
      final token = Provider.of<AuthService>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        if (mounted) setState(() { _loadingServerRecents = false; _loadingServerFrequents = false; });
        return;
      }
      final svc = FavoriteFoodService(token: token);
      final results = await Future.wait([svc.getRecents(limit: 30), svc.getFrequents(limit: 30)]);
      if (mounted) setState(() {
        _serverRecents = results[0];
        _loadingServerRecents = false;
        _serverFrequents = results[1];
        _loadingServerFrequents = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loadingServerRecents = false; _loadingServerFrequents = false; });
    }
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
      _apiResults = [];
      _webResults = [];
      _isLoadingApi = true;
      _isLoadingWeb = !kIsWeb; // Only load web on mobile
    });

    // Search API
    _searchApi(query);

    // On mobile, also search via WebView
    if (!kIsWeb) {
      final url =
          'https://mobile.fatsecret.com.br/calorias-nutrição/search?q=${Uri.encodeComponent(query)}';
      await _scraperHelper.loadUrl(url);
    }
  }

  Future<void> _searchApi(String query) async {
    try {
      // Get device locale
      final locale = Localizations.localeOf(context);
      final languageCode = locale.languageCode; // e.g., "pt", "en", "es"
      final regionCode = locale.countryCode ?? languageCode.toUpperCase(); // e.g., "BR", "US"

      final uri = Uri.parse(
          '${AppConstants.DIET_API_BASE_URL}/food/search?q=${Uri.encodeComponent(query)}&region=$regionCode&language=&limit=${kIsWeb ? 20 : 3}&index=0');

      print('Searching API: $uri');
      final response = await http.get(uri);
      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Parsed ${data.length} items from API');
        final List<Food> foods = data.map((item) => _convertApiResultToFood(item)).toList();

        setState(() {
          _apiResults = foods;
          _isLoadingApi = false;
          _isLoading = kIsWeb ? false : _isLoadingWeb;
        });
      } else {
        setState(() {
          _isLoadingApi = false;
          _isLoading = kIsWeb ? false : _isLoadingWeb;
        });
      }
    } catch (e) {
      print('Error searching API: $e');
      setState(() {
        _isLoadingApi = false;
        _isLoading = kIsWeb ? false : _isLoadingWeb;
      });
    }
  }

  Food _convertApiResultToFood(Map<String, dynamic> data) {
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;
    final regionCode = locale.countryCode ?? languageCode.toUpperCase();

    final foodData = data['food'] as Map<String, dynamic>?;
    final portions = data['portion'] as List<dynamic>? ?? [];
    final nutrientList = foodData?['nutrient'] as List<dynamic>? ?? [];
    final nutrientData = nutrientList.isNotEmpty ? nutrientList.first as Map<String, dynamic>? : null;

    final calories = nutrientData != null ? (double.tryParse(nutrientData['calories']?.toString() ?? '0') ?? 0.0) : 0.0;
    final protein = nutrientData != null ? (double.tryParse(nutrientData['protein']?.toString() ?? '0') ?? 0.0) : 0.0;
    final carbs = nutrientData != null ? (double.tryParse(nutrientData['carbohydrate']?.toString() ?? '0') ?? 0.0) : 0.0;
    final fat = nutrientData != null ? (double.tryParse(nutrientData['fat']?.toString() ?? '0') ?? 0.0) : 0.0;

    return Food(
      id: foodData?['id'],
      name: data['translation'] ?? foodData?['name'] ?? 'Unknown',
      brand: foodData?['brand'],
      photo: foodData?['photo'],
      idFatsecret: foodData?['id_fatsecret'],
      emoji: '🍽️',
      nutrients: [
        Nutrient(
          idFood: foodData?['id'] ?? 0,
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
          regionCode: regionCode,
          languageCode: languageCode,
          idFood: foodData?['id'] ?? 0,
          translation: data['translation'] ?? foodData?['name'] ?? 'Unknown',
          portions: portions.map((p) => Portion(
            idFoodRegion: 0,
            description: p['description'] ?? '',
            proportion: double.tryParse(p['proportion']?.toString() ?? '1') ?? 1.0,
          )).toList(),
        ),
      ],
    );
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

            print('Found ${results.length} foods from web');
            setState(() {
              _webResults = results;
              _isLoadingWeb = false;
              _isLoading = _isLoadingApi;
            });
          } catch (e) {
            print('Error parsing JSON: $e');
            setState(() {
              _webResults = [];
              _isLoadingWeb = false;
              _isLoading = _isLoadingApi;
            });
          }
        } else {
          print('No data received from scraper');
          setState(() {
            _webResults = [];
            _isLoadingWeb = false;
            _isLoading = _isLoadingApi;
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
        title: _selectedMealType != null
            ? DropdownButton<MealType>(
                value: _selectedMealType,
                underline: SizedBox.shrink(),
                isDense: true,
                dropdownColor:
                    isDarkMode ? AppTheme.darkCardColor : Colors.white,
                icon: Icon(Icons.arrow_drop_down, color: textColor, size: 24),
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                items: MealType.values.map((mealType) {
                  final option = DailyMealsProvider.getMealTypeOption(mealType);
                  return DropdownMenuItem<MealType>(
                    value: mealType,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(option.emoji, style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(option.name, style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (MealType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedMealType = newValue;
                    });
                  }
                },
              )
            : Text(
                context.tr.translate('search_food'),
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          // Barcode scanner removed for now to improve intuitiveness
          // IconButton(
          //   icon: Icon(
          //     Icons.barcode_reader,
          //     color: textColor,
          //   ),
          //   onPressed: () { ... },
          // ),
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
                    dividerColor:
                        isDarkMode ? Color(0xFF48484A) : Color(0xFFD1D1D6),
                    dividerHeight: 1,
                    tabs: [
                      Tab(text: 'Frequentes'),
                      Tab(text: context.tr.translate('recent')),
                      Tab(text: context.tr.translate('favorites')),
                    ],
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
                                  _buildServerFrequentList(
                                      isDarkMode,
                                      textColor,
                                      secondaryTextColor,
                                      cardColor),
                                  _buildServerRecentList(
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
    final bool hasApiResults = _apiResults.isNotEmpty;
    final bool hasWebResults = _webResults.isNotEmpty;
    final bool isStillLoading = _isLoading || _isLoadingApi || _isLoadingWeb;

    // If everything is loading and no results yet
    if (isStillLoading && !hasApiResults && !hasWebResults) {
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

    // No results found
    if (!hasApiResults && !hasWebResults && !isStillLoading) {
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

    // Build list with sections
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // API Results section
        if (hasApiResults) ...[
          _buildSectionHeader(
            'Resultados do banco de dados',
            Icons.storage,
            isDarkMode,
            textColor,
          ),
          ..._apiResults.map((food) => _buildApiFoodCard(
                food,
                isDarkMode,
                textColor,
                secondaryTextColor,
                cardColor,
              )),
        ],

        // Still loading API
        if (_isLoadingApi && !hasApiResults)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Buscando no banco de dados...',
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // Web Results section (only on mobile)
        if (!kIsWeb && hasWebResults) ...[
          _buildSectionHeader(
            'Resultados da Internet',
            Icons.public,
            isDarkMode,
            textColor,
          ),
          ..._webResults.map((item) => _buildFoodResultCard(
                item,
                isDarkMode,
                textColor,
                secondaryTextColor,
                cardColor,
              )),
        ],

        // Still loading web results (only on mobile)
        if (!kIsWeb && _isLoadingWeb && !hasWebResults)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Buscando na internet...',
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, bool isDarkMode, Color textColor) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiFoodCard(
    Food food,
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
  ) {
    final servingInfo = food.nutrients?.isNotEmpty == true
        ? '${food.nutrients!.first.servingSize.toStringAsFixed(0)}${food.nutrients!.first.servingUnit}'
        : '100g';
    final subtitle = '${food.calories.toStringAsFixed(0)} kcal • $servingInfo';

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
            builder: (context) => FoodPage(
              food: food,
              selectedMealType: _selectedMealType,
            ),
          ),
        );
      },
      onAdd: () => _quickAddFood(food),
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
    final food = _convertToFood(item);
    return _FoodListItem(
      emoji: '🍽️',
      name: item['nome'] ?? 'Unknown',
      subtitle: _buildSubtitle(item),
      isDarkMode: isDarkMode,
      textColor: textColor,
      secondaryTextColor: secondaryTextColor,
      onTap: () {
        final foodUrl = item['link'] != null
            ? 'https://mobile.fatsecret.com.br${item['link']}'
            : null;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodPage(
              food: food,
              foodUrl: foodUrl,
              selectedMealType: _selectedMealType,
            ),
          ),
        );
      },
      onAdd: () => _quickAddFood(food),
    );
  }

  Widget _buildServerRecentList(bool isDarkMode, Color textColor,
      Color secondaryTextColor, Color cardColor) {
    if (_loadingServerRecents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_serverRecents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64,
                color: secondaryTextColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              context.tr.translate('no_recent_searches'),
              style: TextStyle(color: secondaryTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _serverRecents.length,
      itemBuilder: (context, index) {
        final recent = _serverRecents[index];
        final food = Food(
          name: recent.name,
          emoji: recent.emoji ?? '🍽️',
          nutrients: [
            Nutrient(
              idFood: 0,
              servingSize: recent.baseAmount,
              servingUnit: recent.baseUnit,
              calories: recent.calories.toDouble(),
              protein: recent.protein,
              carbohydrate: recent.carbs,
              fat: recent.fat,
            ),
          ],
          foodRegions: [],
        );
        return _buildFoodCard(food, isDarkMode, textColor, secondaryTextColor, cardColor);
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
              Icons.favorite_border,
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

  Widget _buildServerFrequentList(bool isDarkMode, Color textColor,
      Color secondaryTextColor, Color cardColor) {
    if (_loadingServerFrequents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_serverFrequents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64,
                color: secondaryTextColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Nenhum alimento frequente',
              style: TextStyle(color: secondaryTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _serverFrequents.length,
      itemBuilder: (context, index) {
        final recent = _serverFrequents[index];
        final food = Food(
          name: recent.name,
          emoji: recent.emoji ?? '🍽️',
          nutrients: [
            Nutrient(
              idFood: 0,
              servingSize: recent.baseAmount,
              servingUnit: recent.baseUnit,
              calories: recent.calories.toDouble(),
              protein: recent.protein,
              carbohydrate: recent.carbs,
              fat: recent.fat,
            ),
          ],
          foodRegions: [],
        );
        return _buildFoodCard(food, isDarkMode, textColor, secondaryTextColor, cardColor);
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
            builder: (context) => FoodPage(
              food: food,
              selectedMealType: _selectedMealType,
            ),
          ),
        );
      },
      onAdd: () => _quickAddFood(food),
    );
  }

  void _quickAddFood(Food food) {
    if (_selectedMealType == null) {
      _showMealTypeSelector(food);
      return;
    }
    _addFoodToMeal(food, _selectedMealType!);
  }

  void _addFoodToMeal(Food food, MealType mealType) {
    // Add to meal
    Provider.of<DailyMealsProvider>(context, listen: false)
        .addFoodToMeal(mealType, food);

    // Add to history (recents and frequency)
    final historyProvider = Provider.of<FoodHistoryProvider>(context, listen: false);
    historyProvider.addToRecents(food);
    historyProvider.incrementFrequency(food);

    // Get meal name
    final option = DailyMealsProvider.getMealTypeOption(mealType);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food.name} adicionado ao ${option.name}'),
        duration: Duration(seconds: 2),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _showMealTypeSelector(Food food) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecione a refeição',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16),
              ...MealType.values.map((mealType) {
                final option = DailyMealsProvider.getMealTypeOption(mealType);
                return ListTile(
                  leading: Text(option.emoji, style: TextStyle(fontSize: 24)),
                  title: Text(
                    option.name,
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _addFoodToMeal(food, mealType);
                  },
                );
              }).toList(),
            ],
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
  final VoidCallback? onAdd;

  const _FoodListItem({
    Key? key,
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryTextColor,
    required this.onTap,
    this.onAdd,
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
              GestureDetector(
                onTap: onAdd,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.add_circle,
                    color: AppTheme.primaryColor,
                    size: 28,
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
