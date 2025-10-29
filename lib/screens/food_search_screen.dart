import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../theme/app_theme.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../models/FoodRegion.dart';
import 'food_page.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({Key? key}) : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  InAppWebViewController? _webViewController;
  late TabController _tabController;

  bool _isSearching = false;
  bool _showWebView = false;
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
    super.dispose();
  }

  void _onSearchSubmitted(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    final url = 'https://mobile.fatsecret.com.br/calorias-nutrição/search?q=${Uri.encodeComponent(query)}';

    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  Future<void> _extractFoodData() async {
    if (_webViewController == null) return;

    const jsCode = '''
      (function() {
        const alimentos = [];
        const linhas = document.querySelectorAll('table.list tbody tr:not(.paging):not(:has(th))');

        linhas.forEach(linha => {
          const linkElement = linha.querySelector('a.inner-link');
          const descricoes = linha.querySelectorAll('.nowrap.small-text');

          if (linkElement) {
            const descricao = descricoes[0]?.textContent.trim() || '';
            const regex = /Calorias:\\s*(\\d+)kcal.*Gord:\\s*([\\d.]+)g.*Carbs:\\s*([\\d.]+)g.*Prot:\\s*([\\d.]+)g/;
            const match = descricao.match(regex);

            const alimento = {
              nome: linkElement.textContent.trim(),
              link: linkElement.getAttribute('href'),
              descricao: descricao,
              calorias: match ? match[1] : null,
              gordura: match ? match[2] : null,
              carboidratos: match ? match[3] : null,
              proteina: match ? match[4] : null
            };

            alimentos.push(alimento);
          }
        });

        return JSON.stringify(alimentos);
      })();
    ''';

    try {
      final result = await _webViewController!.evaluateJavascript(source: jsCode);

      if (result != null) {
        final List<dynamic> foodList = [];

        // Parse the result
        if (result is String) {
          final decoded = result;
          // Remove quotes if present
          final cleaned = decoded.replaceAll(RegExp(r'^"|"$'), '');
          if (cleaned.isNotEmpty && cleaned != 'null') {
            try {
              final parsed = Uri.decodeComponent(cleaned);
              // Parse JSON manually or use dart:convert if available
              setState(() {
                _searchResults = _parseJsonArray(parsed);
                _isLoading = false;
              });
            } catch (e) {
              print('Error parsing: $e');
              setState(() {
                _isLoading = false;
              });
            }
          } else {
            setState(() {
              _searchResults = [];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error extracting data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseJsonArray(String jsonString) {
    try {
      // Simple JSON array parser for the food data
      final List<Map<String, dynamic>> results = [];

      // Remove brackets and split by objects
      final cleaned = jsonString.trim();
      if (!cleaned.startsWith('[') || !cleaned.endsWith(']')) {
        return results;
      }

      final objectsString = cleaned.substring(1, cleaned.length - 1);
      final objects = <String>[];
      int braceCount = 0;
      int startIndex = 0;

      for (int i = 0; i < objectsString.length; i++) {
        if (objectsString[i] == '{') {
          if (braceCount == 0) startIndex = i;
          braceCount++;
        } else if (objectsString[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            objects.add(objectsString.substring(startIndex, i + 1));
          }
        }
      }

      for (final obj in objects) {
        final map = _parseJsonObject(obj);
        if (map.isNotEmpty) {
          results.add(map);
        }
      }

      return results;
    } catch (e) {
      print('Parse error: $e');
      return [];
    }
  }

  Map<String, dynamic> _parseJsonObject(String jsonObject) {
    final Map<String, dynamic> result = {};

    try {
      // Remove braces
      final content = jsonObject.substring(1, jsonObject.length - 1);

      // Split by comma, but not within quotes
      final pairs = <String>[];
      int quoteCount = 0;
      int startIndex = 0;

      for (int i = 0; i < content.length; i++) {
        if (content[i] == '"') {
          quoteCount++;
        } else if (content[i] == ',' && quoteCount % 2 == 0) {
          pairs.add(content.substring(startIndex, i));
          startIndex = i + 1;
        }
      }
      pairs.add(content.substring(startIndex));

      for (final pair in pairs) {
        final colonIndex = pair.indexOf(':');
        if (colonIndex > 0) {
          final key = pair.substring(0, colonIndex).trim().replaceAll('"', '');
          var value = pair.substring(colonIndex + 1).trim();

          // Remove quotes from value
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          }

          // Convert null string to actual null
          if (value == 'null') {
            result[key] = null;
          } else {
            result[key] = value;
          }
        }
      }
    } catch (e) {
      print('Object parse error: $e');
    }

    return result;
  }

  Food _convertToFood(Map<String, dynamic> data) {
    final calories = double.tryParse(data['calorias'] ?? '0') ?? 0.0;
    final protein = double.tryParse(data['proteina'] ?? '0') ?? 0.0;
    final carbs = double.tryParse(data['carboidratos'] ?? '0') ?? 0.0;
    final fat = double.tryParse(data['gordura'] ?? '0') ?? 0.0;

    return Food(
      name: data['nome'] ?? 'Unknown',
      emoji: '🍽️',
      nutrients: [
        Nutrient(
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
          'Search Food',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showWebView ? Icons.visibility_off : Icons.visibility,
              color: textColor,
            ),
            onPressed: () {
              setState(() {
                _showWebView = !_showWebView;
              });
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
                  hintText: 'What did you eat?',
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
                  Tab(text: 'Recent'),
                  Tab(text: 'Favorites'),
                ],
              ),
            ),

          // WebView (hidden by default)
          if (_showWebView)
            Container(
              height: 300,
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStop: (controller, url) async {
                  // Wait a bit for the page to fully render
                  await Future.delayed(Duration(milliseconds: 1500));
                  await _extractFoodData();
                },
              ),
            ),

          // Content
          Expanded(
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
              'Searching...',
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
              'No results found',
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
              'No recent searches',
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
              'No favorite foods',
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
