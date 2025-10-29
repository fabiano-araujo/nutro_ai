import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../helpers/webview_helper.dart';
import '../widgets/macro_card.dart';
import '../widgets/macro_nutrient_row.dart';
import '../widgets/sub_nutrient_row.dart';
import '../widgets/micro_nutrient_row.dart';

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
  String? _currentServingUnit; // Store current unit

  InAppWebViewController? _webViewController;
  Food? _fullFoodData;
  String? _foodUrlToLoad;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final baseServingSize = widget.food.nutrients?.first.servingSize ?? 100.0;

    // Set default portion and calculate initial values
    final portions = widget.food.foodRegions?.first.portions;
    if (portions != null && portions.isNotEmpty) {
      final firstPortion = portions.first;
      _selectedPortionDescription = firstPortion.description;

      // Parse the first portion to get correct display and calculation values
      final parsed = _parsePortionDescription(firstPortion.description);
      final parsedSize = parsed['size'] as double;
      final parsedUnit = parsed['unit'] as String;

      // Calculate actual serving size using proportion
      final actualServingSize = baseServingSize * firstPortion.proportion;

      print('===== INIT FIRST PORTION =====');
      print('Description: ${firstPortion.description}');
      print('Parsed size (display): $parsedSize');
      print('Parsed unit (display): $parsedUnit');
      print('Proportion: ${firstPortion.proportion}');
      print('Base serving: $baseServingSize');
      print('Actual serving size (for macros): $actualServingSize');
      print('==============================');

      _currentServingSize = actualServingSize;
      _currentServingUnit = parsedUnit;
      _servingSizeController = TextEditingController(
        text: parsedSize.toInt().toString(),
      );
    } else {
      // No portions, use base values
      _currentServingSize = baseServingSize;
      _servingSizeController = TextEditingController(
        text: baseServingSize.toInt().toString(),
      );
    }

    // Prepare URL for loading
    if (widget.foodUrl != null && widget.foodUrl!.isNotEmpty) {
      _foodUrlToLoad = widget.foodUrl!.startsWith('http')
          ? widget.foodUrl!
          : 'https://mobile.fatsecret.com.br${widget.foodUrl}';

      print('Will load food data from: $_foodUrlToLoad');
      _isLoading = true; // Start loading
    }
  }

  @override
  void dispose() {
    _servingSizeController.dispose();
    super.dispose();
  }

  /// Parse portion description and extract serving size and unit
  /// Returns map with 'size' (double), 'unit' (String), and 'displayText' (String)
  Map<String, dynamic> _parsePortionDescription(String description) {
    print('===== PARSING PORTION DESCRIPTION =====');
    print('Original: $description');

    final trimmed = description.trim();

    // Check if it's g or ml (should show as just "g" or "ml" in list, servingSize 100)
    if (trimmed.toLowerCase() == 'g' || trimmed.toLowerCase() == 'ml') {
      print('Rule 1: Pure g/ml unit');
      print('Result: size=100, unit=$trimmed, display=$trimmed');
      return {'size': 100.0, 'unit': trimmed, 'displayText': trimmed};
    }

    // Check for "100 g" or "100 ml" format
    final mlGPattern = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(g|ml)$', caseSensitive: false);
    final mlGMatch = mlGPattern.firstMatch(trimmed);
    if (mlGMatch != null) {
      final size = double.tryParse(mlGMatch.group(1)?.replaceAll(',', '.') ?? '100') ?? 100.0;
      final unit = mlGMatch.group(2) ?? 'g';
      print('Rule 2: Number + g/ml format');
      print('Result: size=$size, unit=$unit, display=$unit');
      return {'size': size, 'unit': unit, 'displayText': unit};
    }

    // Check for number at the beginning (e.g., "1 médio", "8 fl oz")
    final numberPattern = RegExp(r'^(\d+(?:[.,]\d+)?)\s+(.+)$');
    final numberMatch = numberPattern.firstMatch(trimmed);
    if (numberMatch != null) {
      final numberStr = numberMatch.group(1)?.replaceAll(',', '.');
      final textPart = numberMatch.group(2)?.trim();

      if (numberStr != null && textPart != null && textPart.isNotEmpty) {
        final size = double.tryParse(numberStr) ?? 1.0;

        // Special case: if it's "1 something", remove the "1" from display
        if (size == 1.0) {
          print('Rule 3: Starting with "1" - removing from display');
          print('Result: size=$size, unit=$textPart, display=$textPart');
          return {'size': size, 'unit': textPart, 'displayText': textPart};
        } else {
          // Keep the number for display (e.g., "8 fl oz")
          print('Rule 4: Starting with number > 1 - keeping in display');
          print('Result: size=$size, unit=$textPart, display=$trimmed');
          return {'size': size, 'unit': textPart, 'displayText': trimmed};
        }
      }
    }

    // No pattern matched, return as is with size 1
    print('No rule matched - returning as is');
    print('Result: size=1, unit=$trimmed, display=$trimmed');
    return {'size': 1.0, 'unit': trimmed, 'displayText': trimmed};
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
      }
    } catch (e) {
      print('Error extracting food data: $e');
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
          _isLoading = false; // Stop loading on success

          // Update serving size and portions if available
          final baseServingSize = fullFood.nutrients?.first.servingSize ?? 100.0;
          final portions = fullFood.foodRegions?.first.portions;

          if (portions != null && portions.isNotEmpty) {
            final firstPortion = portions.first;
            _selectedPortionDescription = firstPortion.description;

            // Parse the first portion to get correct display and calculation values
            final parsed = _parsePortionDescription(firstPortion.description);
            final parsedSize = parsed['size'] as double;
            final parsedUnit = parsed['unit'] as String;

            // Calculate actual serving size using proportion
            final actualServingSize = baseServingSize * firstPortion.proportion;

            print('===== LOADED FIRST PORTION =====');
            print('Description: ${firstPortion.description}');
            print('Parsed size (display): $parsedSize');
            print('Parsed unit (display): $parsedUnit');
            print('Proportion: ${firstPortion.proportion}');
            print('Base serving: $baseServingSize');
            print('Actual serving size (for macros): $actualServingSize');
            print('================================');

            _currentServingSize = actualServingSize;
            _currentServingUnit = parsedUnit;
            _servingSizeController.text = parsedSize.toInt().toString();
          } else {
            // No portions, use base values
            _currentServingSize = baseServingSize;
            _servingSizeController.text = baseServingSize.toInt().toString();
          }
        });

        print('Food data loaded successfully: ${fullFood.name}');
      } catch (e) {
        print('Error parsing food data: $e');
        setState(() {
          _isLoading = false; // Stop loading on error
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
        _isLoading = false; // Stop loading even if no valid data
      });
    }
  }


  Food _convertToFullFood(Map<String, dynamic> data) {
    final foodData = data['food'] as Map<String, dynamic>?;
    final nutrientList = data['nutrient'] as List<dynamic>?;
    final portionList = data['portion'] as List<dynamic>?;

    print('===== CONVERTENDO FOOD DATA =====');
    print('Food: ${foodData?['name']}');
    print('Nutrient List: $nutrientList');
    print('Portion List: $portionList');

    // Convert nutrients
    List<Nutrient>? nutrients;
    if (nutrientList != null && nutrientList.isNotEmpty) {
      nutrients = nutrientList.map((n) {
        final nutrient = n as Map<String, dynamic>;

        // Parse serving size and unit
        double servingSize = (nutrient['serving_size'] as num?)?.toDouble() ?? 100.0;
        String servingUnit = (nutrient['serving_unit'] as String? ?? 'g').trim();

        print('===== PROCESSANDO NUTRIENT =====');
        print('Original serving_size: ${nutrient['serving_size']}');
        print('Original serving_unit: ${nutrient['serving_unit']}');

        // Process serving unit according to rules:
        // 1. If unit is "g" or "ml", set servingSize to 100
        // 2. If unit has a number (e.g., "1 xícara"), extract number to servingSize and remove it from unit
        if (servingUnit.toLowerCase() == 'g' || servingUnit.toLowerCase() == 'ml') {
          servingSize = 100.0;
          print('Rule 1 applied: Unit is g/ml, setting servingSize to 100');
        } else {
          // Try to extract number from beginning of unit
          final match = RegExp(r'^(\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(servingUnit);
          if (match != null) {
            final numberStr = match.group(1)?.replaceAll(',', '.');
            final unitPart = match.group(2)?.trim();

            if (numberStr != null && unitPart != null && unitPart.isNotEmpty) {
              servingSize = double.tryParse(numberStr) ?? servingSize;
              servingUnit = unitPart;
              print('Rule 2 applied: Extracted number $numberStr, unit is now "$servingUnit"');
            }
          }
        }

        print('Final servingSize: $servingSize');
        print('Final servingUnit: $servingUnit');
        print('================================');

        return Nutrient(
          idFood: foodData?['id_fatsecret'] ?? 0,
          servingSize: servingSize,
          servingUnit: servingUnit,
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
      print('===== PROCESSANDO PORTIONS =====');
      portions = portionList.map((p) {
        final portion = p as Map<String, dynamic>;
        print('Portion original - proportion: ${portion['proportion']}, description: ${portion['description']}');

        return Portion(
          idFoodRegion: 0, // This will be set by the database
          proportion: (portion['proportion'] as num?)?.toDouble() ?? 1.0,
          description: portion['description'] as String? ?? '',
        );
      }).toList();
      print('Total portions: ${portions.length}');
      print('================================');
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
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
          ),
        );
      },
    );
  }

  void _showPortionPicker() {
    final currentFood = _fullFoodData ?? widget.food;
    final portions = currentFood.foodRegions?.first.portions;
    if (portions == null || portions.isEmpty) return;

    // Get base serving size (usually 100g)
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
                final isSelected = _selectedPortionDescription == portion.description;

                // Parse the portion description
                final parsed = _parsePortionDescription(portion.description);
                final displayText = parsed['displayText'] as String;

                return InkWell(
                  onTap: () {
                    setState(() {
                      // Parse the description to get display values
                      final parsedSize = parsed['size'] as double;
                      final parsedUnit = parsed['unit'] as String;

                      // Calculate actual serving size using proportion (for macro calculations)
                      // The proportion is relative to baseServingSize (usually 100g)
                      final actualServingSize = baseServingSize * portion.proportion;

                      print('===== PORTION SELECTED =====');
                      print('Description: ${portion.description}');
                      print('Parsed size (display): $parsedSize');
                      print('Parsed unit (display): $parsedUnit');
                      print('Proportion: ${portion.proportion}');
                      print('Base serving: $baseServingSize');
                      print('Actual serving size (for macros): $actualServingSize');
                      print('============================');

                      _currentServingSize = actualServingSize;
                      _currentServingUnit = parsedUnit;
                      _selectedPortionDescription = portion.description;
                      _servingSizeController.text = parsedSize.toStringAsFixed(0);
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
                        Expanded(
                          child: Text(
                            displayText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                              size: 24,
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
              child: Opacity(
                opacity: 0.0,
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_foodUrlToLoad!)),
                  initialSettings: WebViewHelper.getOptimizedSettings(),
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

                  await _extractFullFoodData();
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print('[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
                },
                onReceivedError: (controller, request, error) {
                  print('WebView error: ${error.description}');
                  setState(() {
                    _isLoading = false; // Stop loading on WebView error
                  });
                },
                ),
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

              // Loading or Content
              if (_isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              else

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with circular image and title
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Square food image with rounded corners
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isDarkMode ? Color(0xFF2E2E2E) : Color(0xFFF3F4F6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
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
                                            style: TextStyle(fontSize: 40),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Text(
                                        currentFood.emoji,
                                        style: TextStyle(fontSize: 40),
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(width: 16),
                          // Food name and brand
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  currentFood.name,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (currentFood.brand != null) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    currentFood.brand!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: secondaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 8),

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
                                            _currentServingUnit ?? (_selectedPortionDescription != null
                                                ? _parsePortionDescription(_selectedPortionDescription!)['displayText'] as String
                                                : '${_currentServingSize.toStringAsFixed(0)} ${nutrient?.servingUnit ?? 'g'}'),
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

                    // Nutrition Facts - Macro Summary Card
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
                        child: Row(
                          children: [
                            Expanded(
                              child: MacroCard(
                                label: 'Cal',
                                fullName: 'Calories',
                                value: calories.toStringAsFixed(0),
                                unit: '',
                                color: AppTheme.primaryColor,
                                isDarkMode: isDarkMode,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: MacroCard(
                                label: 'P',
                                fullName: 'Proteins',
                                value: protein.toStringAsFixed(1),
                                unit: 'g',
                                color: Color(0xFF9575CD),
                                isDarkMode: isDarkMode,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: MacroCard(
                                label: 'C',
                                fullName: 'Carbs',
                                value: carbs.toStringAsFixed(1),
                                unit: 'g',
                                color: Color(0xFFA1887F),
                                isDarkMode: isDarkMode,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: MacroCard(
                                label: 'F',
                                fullName: 'Fats',
                                value: fat.toStringAsFixed(1),
                                unit: 'g',
                                color: Color(0xFF90A4AE),
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Detailed Nutrition Facts Card
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
                            MacroNutrientRow(
                              label: 'Calories',
                              value: '${calories.toStringAsFixed(0)} kcal',
                              isDarkMode: isDarkMode,
                            ),

                            SizedBox(height: 12),

                            // Protein
                            MacroNutrientRow(
                              label: 'Protein',
                              value: '${protein.toStringAsFixed(0)} g',
                              isDarkMode: isDarkMode,
                            ),

                            SizedBox(height: 12),

                            // Total Carbohydrates Group
                            MacroNutrientRow(
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
                                      SubNutrientRow(
                                        label: 'Dietary Fiber',
                                        value: '${_getScaledValue(nutrient?.dietaryFiber).toStringAsFixed(0)} g',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.sugars != null)
                                      SubNutrientRow(
                                        label: 'Sugars',
                                        value: '${_getScaledValue(nutrient?.sugars).toStringAsFixed(0)} g',
                                        isDarkMode: isDarkMode,
                                      ),
                                  ],
                                ),
                              ),

                            SizedBox(height: 12),

                            // Total Fat Group
                            MacroNutrientRow(
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
                                      SubNutrientRow(
                                        label: 'Saturated Fat',
                                        value: '${_getScaledValue(nutrient?.saturatedFat).toStringAsFixed(1)} g',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.transFat != null)
                                      SubNutrientRow(
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
                              MicroNutrientRow(
                                label: 'Cholesterol',
                                value: '${_getScaledValue(nutrient?.cholesterol).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.cholesterol != null)
                              SizedBox(height: 12),

                            if (nutrient?.sodium != null)
                              MicroNutrientRow(
                                label: 'Sodium',
                                value: '${_getScaledValue(nutrient?.sodium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.sodium != null)
                              SizedBox(height: 12),

                            if (nutrient?.potassium != null)
                              MicroNutrientRow(
                                label: 'Potassium',
                                value: '${_getScaledValue(nutrient?.potassium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.potassium != null)
                              SizedBox(height: 12),

                            if (nutrient?.calcium != null)
                              MicroNutrientRow(
                                label: 'Calcium',
                                value: '${_getScaledValue(nutrient?.calcium).toStringAsFixed(0)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.calcium != null)
                              SizedBox(height: 12),

                            if (nutrient?.iron != null)
                              MicroNutrientRow(
                                label: 'Iron',
                                value: '${_getScaledValue(nutrient?.iron).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.iron != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminD != null)
                              MicroNutrientRow(
                                label: 'Vitamin D',
                                value: '${_getScaledValue(nutrient?.vitaminD).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminD != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminA != null)
                              MicroNutrientRow(
                                label: 'Vitamin A',
                                value: '${_getScaledValue(nutrient?.vitaminA).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminA != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminC != null)
                              MicroNutrientRow(
                                label: 'Vitamin C',
                                value: '${_getScaledValue(nutrient?.vitaminC).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminC != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminB6 != null)
                              MicroNutrientRow(
                                label: 'Vitamin B6',
                                value: '${_getScaledValue(nutrient?.vitaminB6).toStringAsFixed(1)} mg',
                                isDarkMode: isDarkMode,
                              ),
                            if (nutrient?.vitaminB6 != null)
                              SizedBox(height: 12),

                            if (nutrient?.vitaminB12 != null)
                              MicroNutrientRow(
                                label: 'Vitamin B12',
                                value: '${_getScaledValue(nutrient?.vitaminB12).toStringAsFixed(1)} mcg',
                                isDarkMode: isDarkMode,
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 120), // Space for FAB
                  ],
                ),
              ),
            ],
          ),
            ),
          ),

          // Floating Action Button (hide during loading)
          if (!_isLoading)
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

