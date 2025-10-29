import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';
import '../models/FoodRegion.dart';
import '../models/Portion.dart';
import '../providers/daily_meals_provider.dart';
import '../theme/app_theme.dart';

class FoodPage extends StatefulWidget {
  final Food food;
  final String? foodUrl; // URL do FatSecret para carregar dados completos

  const FoodPage({
    Key? key,
    required this.food,
    this.foodUrl,
  }) : super(key: key);

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  late TextEditingController _servingSizeController;
  late double _currentServingSize;
  String? _selectedPortionDescription;

  InAppWebViewController? _webViewController;
  bool _isLoadingFullData = false;
  Food? _fullFoodData;
  String? _foodUrlToLoad;

  @override
  void initState() {
    super.initState();
    _currentServingSize = widget.food.nutrients?.first.servingSize ?? 100.0;
    _servingSizeController = TextEditingController(
      text: _currentServingSize.toInt().toString(),
    );

    // Set default portion description
    final portions = widget.food.foodRegions?.first.portions;
    if (portions != null && portions.isNotEmpty) {
      _selectedPortionDescription = portions.first.description;
    }

    // Prepare URL for loading
    if (widget.foodUrl != null && widget.foodUrl!.isNotEmpty) {
      _foodUrlToLoad = widget.foodUrl!.startsWith('http')
          ? widget.foodUrl!
          : 'https://mobile.fatsecret.com.br${widget.foodUrl}';

      print('Will load food data from: $_foodUrlToLoad');

      setState(() {
        _isLoadingFullData = true;
      });
    }
  }

  @override
  void dispose() {
    _servingSizeController.dispose();
    super.dispose();
  }

  Future<void> _extractFullFoodData() async {
    try {
      print('Starting food data extraction...');

      // Load the JavaScript file
      final script = await rootBundle.loadString('assets/nutrition_script_mobile_br.js');

      // Remove the main() call at the end to avoid sending to server
      final scriptWithoutMain = script.replaceAll(RegExp(r'main\(\);?\s*$'), '');

      // Modify the script to use the handler instead of calling main()
      final modifiedScript = '''
        console.log('[Flutter] ===== SCRIPT INJECTION START =====');
        console.log('[Flutter] typeof window:', typeof window);
        console.log('[Flutter] typeof document:', typeof document);
        console.log('[Flutter] typeof window.flutter_inappwebview:', typeof window.flutter_inappwebview);

        $scriptWithoutMain

        // Override to send data back to Flutter
        console.log('[Flutter] Script loaded, starting extraction...');
        console.log('[Flutter] Document ready state:', document.readyState);

        // Wait for document to be fully ready
        if (document.readyState === 'loading') {
          console.log('[Flutter] Document still loading, waiting...');
          document.addEventListener('DOMContentLoaded', function() {
            console.log('[Flutter] DOMContentLoaded event fired');
            extractAndSend();
          });
        } else {
          console.log('[Flutter] Document already ready, extracting now');
          extractAndSend();
        }

        function extractAndSend() {
          try {
            console.log('[Flutter] Calling processAllPortions...');
            let data = processAllPortions();

            if (!data) {
              console.error('[Flutter] processAllPortions returned null or undefined');
              window.flutter_inappwebview.callHandler('NUTRITION_DATA_HANDLER', null);
              return;
            }

            console.log('[Flutter] Data processed successfully');
            console.log('[Flutter] Data type:', typeof data);
            console.log('[Flutter] Data keys:', Object.keys(data));
            console.log('[Flutter] Full data:', JSON.stringify(data, null, 2));

            // Convert to JSON string
            let jsonString = JSON.stringify(data);
            console.log('[Flutter] JSON string length:', jsonString.length);

            // Send to Flutter
            console.log('[Flutter] Sending data to Flutter handler...');
            window.flutter_inappwebview.callHandler('NUTRITION_DATA_HANDLER', jsonString);
            console.log('[Flutter] Data sent successfully!');
          } catch(e) {
            console.error('[Flutter] Error during extraction:', e);
            console.error('[Flutter] Stack:', e.stack);
            window.flutter_inappwebview.callHandler('NUTRITION_DATA_HANDLER', null);
          }
        }
      ''';

      print('Script length: ${modifiedScript.length} characters');
      print('Injecting script...');

      if (_webViewController != null) {
        await _webViewController!.evaluateJavascript(source: modifiedScript);
        print('Script injected successfully');
      } else {
        print('ERROR: WebView controller is null!');
        setState(() {
          _isLoadingFullData = false;
        });
      }
    } catch (e) {
      print('Error extracting food data: $e');
      setState(() {
        _isLoadingFullData = false;
      });
    }
  }

  void _handleNutritionData(dynamic data) {
    print('===== CALLBACK RECEIVED =====');
    print('Data type: ${data.runtimeType}');
    print('Data is null: ${data == null}');
    if (data != null) {
      print('Data length: ${data.toString().length}');
      print('Data preview: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}');
    }
    print('============================');

    if (data != null && data is String && data.isNotEmpty) {
      try {
        print('Attempting to parse JSON data...');
        final Map<String, dynamic> parsed = jsonDecode(data);
        print('Parsed food data successfully');

        // Convert to Food model
        final fullFood = _convertToFullFood(parsed);

        setState(() {
          _fullFoodData = fullFood;
          _isLoadingFullData = false;

          // Update serving size and portions if available
          if (fullFood.nutrients != null && fullFood.nutrients!.isNotEmpty) {
            _currentServingSize = fullFood.nutrients!.first.servingSize;
            _servingSizeController.text = _currentServingSize.toInt().toString();
          }

          if (fullFood.foodRegions != null &&
              fullFood.foodRegions!.isNotEmpty &&
              fullFood.foodRegions!.first.portions != null &&
              fullFood.foodRegions!.first.portions!.isNotEmpty) {
            _selectedPortionDescription = fullFood.foodRegions!.first.portions!.first.description;
          }
        });

        print('Food data loaded successfully: ${fullFood.name}');
      } catch (e) {
        print('Error parsing food data: $e');
        setState(() {
          _isLoadingFullData = false;
        });
      }
    } else {
      print('===== NO VALID DATA =====');
      if (data == null) {
        print('Data is null');
      } else if (data is! String) {
        print('Data is not String, type: ${data.runtimeType}');
        print('Data value: $data');
      } else if (data.isEmpty) {
        print('Data is empty string');
      } else {
        print('Data is not empty but invalid: $data');
      }
      print('========================');

      setState(() {
        _isLoadingFullData = false;
      });
    }
  }


  Food _convertToFullFood(Map<String, dynamic> data) {
    final foodData = data['food'] as Map<String, dynamic>?;
    final nutrientList = data['nutrient'] as List<dynamic>?;
    final portionList = data['portion'] as List<dynamic>?;

    // Convert nutrients
    List<Nutrient>? nutrients;
    if (nutrientList != null && nutrientList.isNotEmpty) {
      nutrients = nutrientList.map((n) {
        final nutrient = n as Map<String, dynamic>;
        return Nutrient(
          idFood: foodData?['id_fatsecret'] ?? 0,
          servingSize: (nutrient['serving_size'] as num?)?.toDouble() ?? 100.0,
          servingUnit: nutrient['serving_unit'] as String? ?? 'g',
          calories: (nutrient['calories'] as num?)?.toDouble(),
          protein: (nutrient['protein'] as num?)?.toDouble(),
          carbohydrate: (nutrient['carbohydrate'] as num?)?.toDouble(),
          fat: (nutrient['fat'] as num?)?.toDouble(),
          saturatedFat: (nutrient['saturated_fat'] as num?)?.toDouble(),
          transFat: (nutrient['trans_fat'] as num?)?.toDouble(),
          cholesterol: (nutrient['cholesterol'] as num?)?.toDouble(),
          sodium: (nutrient['sodium'] as num?)?.toDouble(),
          potassium: (nutrient['potassium'] as num?)?.toDouble(),
          dietaryFiber: (nutrient['dietary_fiber'] as num?)?.toDouble(),
          sugars: (nutrient['sugars'] as num?)?.toDouble(),
          vitaminA: (nutrient['vitamin_a'] as num?)?.toDouble(),
          vitaminC: (nutrient['vitamin_c'] as num?)?.toDouble(),
          vitaminD: (nutrient['vitamin_d'] as num?)?.toDouble(),
          calcium: (nutrient['calcium'] as num?)?.toDouble(),
          iron: (nutrient['iron'] as num?)?.toDouble(),
        );
      }).toList();
    }

    // Convert portions with reference to food region
    List<Portion>? portions;
    if (portionList != null && portionList.isNotEmpty) {
      portions = portionList.map((p) {
        final portion = p as Map<String, dynamic>;
        return Portion(
          idFoodRegion: 0, // This will be set by the database
          proportion: (portion['proportion'] as num?)?.toDouble() ?? 1.0,
          description: portion['description'] as String? ?? '',
        );
      }).toList();
    }

    // Create food region with portions
    final foodRegion = FoodRegion(
      regionCode: 'BR',
      languageCode: 'pt',
      idFood: foodData?['id_fatsecret'] ?? 0,
      translation: foodData?['name'] as String? ?? widget.food.name,
      portions: portions,
    );

    return Food(
      name: foodData?['name'] as String? ?? widget.food.name,
      brand: foodData?['brand'] as String?,
      emoji: widget.food.emoji,
      photo: foodData?['photo'] as String?,
      idFatsecret: foodData?['id_fatsecret'] as int?,
      nutrients: nutrients ?? widget.food.nutrients,
      foodRegions: [foodRegion],
    );
  }

  double _getScaledValue(double? value) {
    if (value == null) return 0.0;
    final currentFood = _fullFoodData ?? widget.food;
    final originalServing = currentFood.nutrients?.first.servingSize ?? 100.0;
    return (value / originalServing) * _currentServingSize;
  }

  void _updateServingSize(String value) {
    final newValue = double.tryParse(value);
    if (newValue != null && newValue > 0) {
      setState(() {
        _currentServingSize = newValue;
      });
    }
  }

  void _showMealTypeSelector(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Meal Type',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Meal types list
              ...MealType.values.map((mealType) {
                final option = DailyMealsProvider.getMealTypeOption(mealType);

                return InkWell(
                  onTap: () {
                    // Use full data if available
                    final currentFood = _fullFoodData ?? widget.food;

                    // Create a Food object with the current serving size
                    final nutrient = currentFood.nutrients?.first;
                    final originalServing = nutrient?.servingSize ?? 100.0;
                    final scaleFactor = _currentServingSize / originalServing;

                    // Create a new Food with scaled nutrients
                    final scaledFood = currentFood.copyWith(
                      nutrients: currentFood.nutrients?.map((n) => n.copyWith(
                        servingSize: _currentServingSize,
                        calories: (n.calories ?? 0) * scaleFactor,
                        protein: (n.protein ?? 0) * scaleFactor,
                        carbohydrate: (n.carbohydrate ?? 0) * scaleFactor,
                        fat: (n.fat ?? 0) * scaleFactor,
                        saturatedFat: n.saturatedFat != null ? n.saturatedFat! * scaleFactor : null,
                        transFat: n.transFat != null ? n.transFat! * scaleFactor : null,
                        cholesterol: n.cholesterol != null ? (n.cholesterol! * scaleFactor).toDouble() : null,
                        sodium: n.sodium != null ? (n.sodium! * scaleFactor).toDouble() : null,
                        potassium: n.potassium != null ? (n.potassium! * scaleFactor).toDouble() : null,
                        dietaryFiber: n.dietaryFiber != null ? n.dietaryFiber! * scaleFactor : null,
                        sugars: n.sugars != null ? n.sugars! * scaleFactor : null,
                        vitaminA: n.vitaminA != null ? n.vitaminA! * scaleFactor : null,
                        vitaminC: n.vitaminC != null ? n.vitaminC! * scaleFactor : null,
                        vitaminD: n.vitaminD != null ? n.vitaminD! * scaleFactor : null,
                        vitaminB6: n.vitaminB6 != null ? n.vitaminB6! * scaleFactor : null,
                        vitaminB12: n.vitaminB12 != null ? n.vitaminB12! * scaleFactor : null,
                        calcium: n.calcium != null ? (n.calcium! * scaleFactor).toDouble() : null,
                        iron: n.iron != null ? n.iron! * scaleFactor : null,
                      )).toList(),
                    );

                    // Add to meal
                    Provider.of<DailyMealsProvider>(context, listen: false)
                        .addFoodToMeal(mealType, scaledFood);

                    // Close both dialogs
                    Navigator.pop(context); // Close meal type selector
                    Navigator.pop(context); // Close food page

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${currentFood.name} added to ${option.name}'),
                        duration: Duration(seconds: 2),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? AppTheme.darkBorderColor
                            : AppTheme.dividerColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          option.emoji,
                          style: TextStyle(fontSize: 24),
                        ),
                        SizedBox(width: 12),
                        Text(
                          option.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showPortionPicker() {
    final currentFood = _fullFoodData ?? widget.food;
    final portions = currentFood.foodRegions?.first.portions;
    if (portions == null || portions.isEmpty) return;

    final nutrient = currentFood.nutrients?.first;
    final baseServingSize = nutrient?.servingSize ?? 100.0;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
        final textColor = isDarkMode
            ? AppTheme.darkTextColor
            : AppTheme.textPrimaryColor;

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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Portion',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Portions list
              ...portions.map((portion) {
                final portionSize = baseServingSize * portion.proportion;
                final isSelected = _selectedPortionDescription == portion.description;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _currentServingSize = portionSize;
                      _selectedPortionDescription = portion.description;
                      _servingSizeController.text = portionSize.toStringAsFixed(0);
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : (isDarkMode
                                ? AppTheme.darkBorderColor
                                : AppTheme.dividerColor),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          portion.description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: textColor,
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;
    final cardColor = isDarkMode
        ? AppTheme.darkCardColor
        : Colors.white;
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;
    final secondaryTextColor = isDarkMode
        ? Color(0xFFAEB7CE)
        : AppTheme.textSecondaryColor;

    // Use full data if loaded, otherwise use initial data
    final currentFood = _fullFoodData ?? widget.food;
    final nutrient = currentFood.nutrients?.first;
    final calories = _getScaledValue(nutrient?.calories);
    final protein = _getScaledValue(nutrient?.protein);
    final carbs = _getScaledValue(nutrient?.carbohydrate);
    final fat = _getScaledValue(nutrient?.fat);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // WebView (invisível, por baixo de tudo)
          if (_foodUrlToLoad != null)
            Positioned.fill(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_foodUrlToLoad!)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  print('WebView created for food details');

                  // Register handler for JavaScript communication
                  controller.addJavaScriptHandler(
                    handlerName: 'NUTRITION_DATA_HANDLER',
                    callback: (args) {
                      print('JavaScript handler called with ${args.length} args');
                      if (args.isNotEmpty) {
                        _handleNutritionData(args[0]);
                      }
                    },
                  );
                },
                onLoadStop: (controller, url) async {
                  print('===== PAGE LOADED =====');
                  print('URL: $url');

                  // Check if page is ready
                  try {
                    final hasNutritionFacts = await controller.evaluateJavascript(source: 'document.querySelector(".nutrition_facts") !== null');
                    print('Has nutrition_facts element: $hasNutritionFacts');

                    if (hasNutritionFacts == true) {
                      final nfClass = await controller.evaluateJavascript(source: 'document.querySelector(".nutrition_facts").className');
                      print('Nutrition facts class: $nfClass');
                    }
                  } catch (e) {
                    print('Error checking page: $e');
                  }

                  print('Waiting 3 seconds before extraction...');
                  await Future.delayed(Duration(milliseconds: 3000));
                  await _extractFullFoodData();
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print('[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
                },
                onReceivedError: (controller, request, error) {
                  print('WebView error: ${error.description}');
                  if (request.isForMainFrame ?? false) {
                    setState(() {
                      _isLoadingFullData = false;
                    });
                  }
                },
              ),
            ),

          // Main Content (por cima do WebView)
          Positioned.fill(
            child: Container(
              color: backgroundColor,
              child: CustomScrollView(
            slivers: [
              // Top App Bar
              SliverAppBar(
                expandedHeight: 0,
                floating: false,
                pinned: true,
                backgroundColor: backgroundColor,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.star_outline, color: textColor),
                    onPressed: () {
                      // TODO: Add to favorites
                    },
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Image
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: currentFood.imageUrl != null
                              ? Image.network(
                                  currentFood.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        currentFood.emoji,
                                        style: TextStyle(fontSize: 80),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    currentFood.emoji,
                                    style: TextStyle(fontSize: 80),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Headline and Brand
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentFood.name,
                            style: AppTheme.headingLarge.copyWith(
                              color: textColor,
                              fontSize: 32,
                            ),
                          ),
                          if (currentFood.brand != null) ...[
                            SizedBox(height: 4),
                            Text(
                              currentFood.brand!,
                              style: AppTheme.bodyLarge.copyWith(
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Serving Size Selector
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Serving Size field
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 12, bottom: 8),
                                  child: Text(
                                    'Serving Size',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ),
                                TextField(
                                  controller: _servingSizeController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDarkMode
                                            ? AppTheme.darkBorderColor
                                            : AppTheme.dividerColor,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDarkMode
                                            ? AppTheme.darkBorderColor
                                            : AppTheme.dividerColor,
                                        width: 2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  onChanged: _updateServingSize,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          // Unit field
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 12, bottom: 8),
                                  child: Text(
                                    'Unit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: _showPortionPicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDarkMode
                                            ? AppTheme.darkBorderColor
                                            : AppTheme.dividerColor,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedPortionDescription ?? 'Container (${_currentServingSize.toStringAsFixed(0)}${nutrient?.servingUnit ?? 'g'})',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.unfold_more,
                                          color: secondaryTextColor,
                                          size: 20,
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

                    SizedBox(height: 24),

                    // Macro Breakdown Card
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Macro Breakdown',
                              style: AppTheme.headingSmall.copyWith(
                                color: textColor,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pie Chart
                                _MacroPieChart(
                                  protein: protein,
                                  carbs: carbs,
                                  fat: fat,
                                  calories: calories,
                                  isDarkMode: isDarkMode,
                                ),
                                SizedBox(width: 24),
                                // Macro Labels
                                Expanded(
                                  child: Column(
                                    children: [
                                      _MacroRow(
                                        label: 'Protein',
                                        value: '${protein.toStringAsFixed(1)}g',
                                        color: Color(0xFF9575CD),
                                        isDarkMode: isDarkMode,
                                      ),
                                      SizedBox(height: 12),
                                      _MacroRow(
                                        label: 'Carbs',
                                        value: '${carbs.toStringAsFixed(1)}g',
                                        color: Color(0xFFA1887F),
                                        isDarkMode: isDarkMode,
                                      ),
                                      SizedBox(height: 12),
                                      _MacroRow(
                                        label: 'Fat',
                                        value: '${fat.toStringAsFixed(1)}g',
                                        color: Color(0xFF90A4AE),
                                        isDarkMode: isDarkMode,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Nutrition Facts Card
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode
                                ? AppTheme.darkBorderColor
                                : AppTheme.dividerColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Macronutrients Section
                            Text(
                              'Macronutrients',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),

                            Divider(
                              color: isDarkMode ? Colors.white24 : Colors.black12,
                              height: 24,
                              thickness: 1,
                            ),

                            // Calories
                            _MacroNutrientRow(
                              label: 'Calories',
                              value: '${calories.toStringAsFixed(0)} kcal',
                              isDarkMode: isDarkMode,
                            ),

                            SizedBox(height: 12),

                            // Protein
                            _MacroNutrientRow(
                              label: 'Protein',
                              value: '${protein.toStringAsFixed(0)} g',
                              isDarkMode: isDarkMode,
                            ),

                            SizedBox(height: 12),

                            // Total Carbohydrates Group
                            _MacroNutrientRow(
                              label: 'Total Carbohydrates',
                              value: '${carbs.toStringAsFixed(0)} g',
                              isDarkMode: isDarkMode,
                            ),
                            if (nutrient?.dietaryFiber != null || nutrient?.sugars != null)
                              Container(
                                margin: EdgeInsets.only(left: 0, top: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Color(0xFFA1887F).withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    if (nutrient?.dietaryFiber != null)
                                      _SubNutrientRow(
                                        label: 'Dietary Fiber',
                                        value: '${_getScaledValue(nutrient?.dietaryFiber).toStringAsFixed(0)} g',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.sugars != null)
                                      _SubNutrientRow(
                                        label: 'Sugars',
                                        value: '${_getScaledValue(nutrient?.sugars).toStringAsFixed(0)} g',
                                        isDarkMode: isDarkMode,
                                      ),
                                  ],
                                ),
                              ),

                            SizedBox(height: 12),

                            // Total Fat Group
                            _MacroNutrientRow(
                              label: 'Total Fat',
                              value: '${fat.toStringAsFixed(0)} g',
                              isDarkMode: isDarkMode,
                            ),
                            if (nutrient?.saturatedFat != null || nutrient?.transFat != null)
                              Container(
                                margin: EdgeInsets.only(left: 0, top: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Color(0xFF9575CD).withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    if (nutrient?.saturatedFat != null)
                                      _SubNutrientRow(
                                        label: 'Saturated Fat',
                                        value: '${_getScaledValue(nutrient?.saturatedFat).toStringAsFixed(1)} g',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.transFat != null)
                                      _SubNutrientRow(
                                        label: 'Trans Fat',
                                        value: '${_getScaledValue(nutrient?.transFat).toStringAsFixed(0)} g',
                                        isDarkMode: isDarkMode,
                                      ),
                                  ],
                                ),
                              ),

                            SizedBox(height: 24),

                            // Micronutrients Section
                            Text(
                              'Micronutrients',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),

                            Divider(
                              color: isDarkMode ? Colors.white24 : Colors.black12,
                              height: 24,
                              thickness: 1,
                            ),

                            // Micronutrients List
                            if (nutrient?.cholesterol != null)
                              _MicroNutrientRow(
                                label: 'Cholesterol',
                                value: '${_getScaledValue(nutrient?.cholesterol).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.cholesterol != null)
                              SizedBox(height: 12),

                            if (nutrient?.sodium != null)
                              _MicroNutrientRow(
                                label: 'Sodium',
                                value: '${_getScaledValue(nutrient?.sodium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.sodium != null)
                              SizedBox(height: 12),

                            if (nutrient?.potassium != null)
                              _MicroNutrientRow(
                                label: 'Potassium',
                                value: '${_getScaledValue(nutrient?.potassium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.potassium != null)
                              SizedBox(height: 12),

                            if (nutrient?.calcium != null)
                              _MicroNutrientRow(
                                label: 'Calcium',
                                value: '${_getScaledValue(nutrient?.calcium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.calcium != null)
                              SizedBox(height: 12),

                            if (nutrient?.iron != null)
                              _MicroNutrientRow(
                                label: 'Iron',
                                value: '${_getScaledValue(nutrient?.iron).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.iron != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminD != null)
                              _MicroNutrientRow(
                                label: 'Vitamin D',
                                value: '${_getScaledValue(nutrient?.vitaminD).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminD != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminA != null)
                              _MicroNutrientRow(
                                label: 'Vitamin A',
                                value: '${_getScaledValue(nutrient?.vitaminA).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminA != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminC != null)
                              _MicroNutrientRow(
                                label: 'Vitamin C',
                                value: '${_getScaledValue(nutrient?.vitaminC).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminC != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminB6 != null)
                              _MicroNutrientRow(
                                label: 'Vitamin B6',
                                value: '${_getScaledValue(nutrient?.vitaminB6).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminB6 != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminB12 != null)
                              _MicroNutrientRow(
                                label: 'Vitamin B12',
                                value: '${_getScaledValue(nutrient?.vitaminB12).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
            ],
          ),
            ),
          ),

          // Loading indicator overlay
          if (_isLoadingFullData)
            Positioned.fill(
              child: Container(
                color: backgroundColor.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading complete nutrition data...',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Action Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withValues(alpha: 0.0),
                    backgroundColor,
                  ],
                ),
              ),
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  _showMealTypeSelector(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                ),
                child: Text(
                  'Add to Meal',
                  style: AppTheme.buttonText.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Macro Pie Chart Widget
class _MacroPieChart extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double calories;
  final bool isDarkMode;

  const _MacroPieChart({
    Key? key,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate percentages (calories from macros)
    final proteinCal = protein * 4;
    final carbsCal = carbs * 4;
    final fatCal = fat * 9;
    final total = proteinCal + carbsCal + fatCal;

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(120, 120),
            painter: _PieChartPainter(
              proteinPercent: total > 0 ? proteinCal / total : 0,
              carbsPercent: total > 0 ? carbsCal / total : 0,
              fatPercent: total > 0 ? fatCal / total : 0,
              isDarkMode: isDarkMode,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  calories.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  'Calories',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? Color(0xFFAEB7CE)
                        : AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pie Chart Painter
class _PieChartPainter extends CustomPainter {
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;
  final bool isDarkMode;

  _PieChartPainter({
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    // Background circle
    final bgPaint = Paint()
      ..color = (isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Draw segments
    double startAngle = -math.pi / 2;

    // Protein segment
    if (proteinPercent > 0) {
      final proteinPaint = Paint()
        ..color = Color(0xFF9575CD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * proteinPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        proteinPaint,
      );
      startAngle += sweepAngle;
    }

    // Carbs segment
    if (carbsPercent > 0) {
      final carbsPaint = Paint()
        ..color = Color(0xFFA1887F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * carbsPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        carbsPaint,
      );
      startAngle += sweepAngle;
    }

    // Fat segment
    if (fatPercent > 0) {
      final fatPaint = Paint()
        ..color = Color(0xFF90A4AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final sweepAngle = 2 * math.pi * fatPercent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        fatPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Macro Row Widget
class _MacroRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDarkMode;

  const _MacroRow({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            color: isDarkMode
                ? AppTheme.darkTextColor
                : AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Macronutrient Row Widget (for main nutrients)
class _MacroNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _MacroNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// Sub-Nutrient Row Widget (for indented items)
class _SubNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _SubNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = isDarkMode
        ? Color(0xFF9CA3AF)
        : Color(0xFF6B7280);

    return Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Micronutrient Row Widget (for minerals and vitamins - without bold)
class _MicroNutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;

  const _MicroNutrientRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppTheme.darkTextColor
        : AppTheme.textPrimaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
