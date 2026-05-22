import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import '../models/Nutrient.dart';
import '../models/FoodRegion.dart';
import '../models/Portion.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/food_history_provider.dart';
import '../services/auth_service.dart';
import '../services/favorite_food_service.dart';
import '../services/ad_manager.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../helpers/webview_helper.dart';
import '../widgets/macro_nutrient_row.dart';
import '../widgets/sub_nutrient_row.dart';
import '../widgets/micro_nutrient_row.dart';
import '../utils/ui_utils.dart';

class FoodPage extends StatefulWidget {
  final Food food;
  final String? foodUrl; // URL do FatSecret para carregar dados completos
  final MealType? selectedMealType;

  const FoodPage({
    Key? key,
    required this.food,
    this.foodUrl,
    this.selectedMealType,
  }) : super(key: key);

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  late TextEditingController _servingSizeController;
  late double _currentServingSize;
  double _singlePortionSize = 100.0; // Grams for 1 unit of the selected portion
  String? _selectedPortionDescription;
  String? _currentServingUnit; // Store current unit
  late MealType _selectedMealType; // Current selected meal type

  InAppWebViewController? _webViewController;
  Food? _fullFoodData;
  String? _foodUrlToLoad;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize selected meal type
    _selectedMealType = widget.selectedMealType ?? MealType.breakfast;

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

      // Calculate the size for 1 unit of this portion
      // actualServingSize is for parsedSize units, so divide to get single unit size
      final singleUnitSize = parsedSize > 0
          ? (baseServingSize * firstPortion.proportion) / parsedSize
          : baseServingSize * firstPortion.proportion;

      print('===== INIT FIRST PORTION =====');
      print('Description: ${firstPortion.description}');
      print('Parsed size (display): $parsedSize');
      print('Parsed unit (display): $parsedUnit');
      print('Proportion: ${firstPortion.proportion}');
      print('Base serving: $baseServingSize');
      print('Single unit size: $singleUnitSize');
      print('Actual serving size (for macros): ${singleUnitSize * parsedSize}');
      print('==============================');

      _singlePortionSize = singleUnitSize;
      _currentServingSize = singleUnitSize * parsedSize;
      _currentServingUnit = parsedUnit;
      _servingSizeController = TextEditingController(
        text: parsedSize.toInt().toString(),
      );
    } else {
      // No portions, use base values (unit is grams, so 1g = 1g)
      _singlePortionSize = 1.0; // Each unit in the field represents 1g
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
    final mlGPattern =
        RegExp(r'^(\d+(?:[.,]\d+)?)\s*(g|ml)$', caseSensitive: false);
    final mlGMatch = mlGPattern.firstMatch(trimmed);
    if (mlGMatch != null) {
      final size =
          double.tryParse(mlGMatch.group(1)?.replaceAll(',', '.') ?? '100') ??
              100.0;
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
      final script =
          await rootBundle.loadString('assets/nutrition_script_mobile_br.js');

      // Remove the main() call at the end to avoid sending to server
      final scriptWithoutMain =
          script.replaceAll(RegExp(r'main\(\);?\s*$'), '');

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
      print(
          'Data preview: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}');
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
          final baseServingSize =
              fullFood.nutrients?.first.servingSize ?? 100.0;
          final portions = fullFood.foodRegions?.first.portions;

          if (portions != null && portions.isNotEmpty) {
            final firstPortion = portions.first;
            _selectedPortionDescription = firstPortion.description;

            // Parse the first portion to get correct display and calculation values
            final parsed = _parsePortionDescription(firstPortion.description);
            final parsedSize = parsed['size'] as double;
            final parsedUnit = parsed['unit'] as String;

            // Calculate the size for 1 unit of this portion
            final singleUnitSize = parsedSize > 0
                ? (baseServingSize * firstPortion.proportion) / parsedSize
                : baseServingSize * firstPortion.proportion;

            print('===== LOADED FIRST PORTION =====');
            print('Description: ${firstPortion.description}');
            print('Parsed size (display): $parsedSize');
            print('Parsed unit (display): $parsedUnit');
            print('Proportion: ${firstPortion.proportion}');
            print('Base serving: $baseServingSize');
            print('Single unit size: $singleUnitSize');
            print(
                'Actual serving size (for macros): ${singleUnitSize * parsedSize}');
            print('================================');

            _singlePortionSize = singleUnitSize;
            _currentServingSize = singleUnitSize * parsedSize;
            _currentServingUnit = parsedUnit;
            _servingSizeController.text = parsedSize.toInt().toString();
          } else {
            // No portions, use base values (unit is grams, so 1g = 1g)
            _singlePortionSize = 1.0;
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
        double servingSize =
            (nutrient['serving_size'] as num?)?.toDouble() ?? 100.0;
        String servingUnit =
            (nutrient['serving_unit'] as String? ?? 'g').trim();

        print('===== PROCESSANDO NUTRIENT =====');
        print('Original serving_size: ${nutrient['serving_size']}');
        print('Original serving_unit: ${nutrient['serving_unit']}');

        // Process serving unit according to rules:
        // 1. If unit is "g" or "ml", set servingSize to 100
        // 2. If unit has a number (e.g., "1 xícara"), extract number to servingSize and remove it from unit
        if (servingUnit.toLowerCase() == 'g' ||
            servingUnit.toLowerCase() == 'ml') {
          servingSize = 100.0;
          print('Rule 1 applied: Unit is g/ml, setting servingSize to 100');
        } else {
          // Try to extract number from beginning of unit
          final match =
              RegExp(r'^(\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(servingUnit);
          if (match != null) {
            final numberStr = match.group(1)?.replaceAll(',', '.');
            final unitPart = match.group(2)?.trim();

            if (numberStr != null && unitPart != null && unitPart.isNotEmpty) {
              servingSize = double.tryParse(numberStr) ?? servingSize;
              servingUnit = unitPart;
              print(
                  'Rule 2 applied: Extracted number $numberStr, unit is now "$servingUnit"');
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
        print(
            'Portion original - proportion: ${portion['proportion']}, description: ${portion['description']}');

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
        // Multiply the entered quantity by the single portion size
        _currentServingSize = newValue * _singlePortionSize;
      });
    }
  }

  Widget _buildMacroCardCompact({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _addToMeal(MealType mealType) {
    // Use full data if available
    final currentFood = _fullFoodData ?? widget.food;

    // Create a Food object with the current serving size
    final nutrient = currentFood.nutrients?.first;
    final originalServing = nutrient?.servingSize ?? 100.0;
    final scaleFactor = _currentServingSize / originalServing;

    // Create a new Food with scaled nutrients
    final scaledFood = currentFood.copyWith(
      nutrients: currentFood.nutrients
          ?.map((n) => n.copyWith(
                servingSize: _currentServingSize,
                calories: (n.calories ?? 0) * scaleFactor,
                protein: (n.protein ?? 0) * scaleFactor,
                carbohydrate: (n.carbohydrate ?? 0) * scaleFactor,
                fat: (n.fat ?? 0) * scaleFactor,
                saturatedFat: n.saturatedFat != null
                    ? n.saturatedFat! * scaleFactor
                    : null,
                transFat: n.transFat != null ? n.transFat! * scaleFactor : null,
                cholesterol: n.cholesterol != null
                    ? (n.cholesterol! * scaleFactor).toDouble()
                    : null,
                sodium: n.sodium != null
                    ? (n.sodium! * scaleFactor).toDouble()
                    : null,
                potassium: n.potassium != null
                    ? (n.potassium! * scaleFactor).toDouble()
                    : null,
                dietaryFiber: n.dietaryFiber != null
                    ? n.dietaryFiber! * scaleFactor
                    : null,
                sugars: n.sugars != null ? n.sugars! * scaleFactor : null,
                vitaminA: n.vitaminA != null ? n.vitaminA! * scaleFactor : null,
                vitaminC: n.vitaminC != null ? n.vitaminC! * scaleFactor : null,
                vitaminD: n.vitaminD != null ? n.vitaminD! * scaleFactor : null,
                vitaminB6:
                    n.vitaminB6 != null ? n.vitaminB6! * scaleFactor : null,
                vitaminB12:
                    n.vitaminB12 != null ? n.vitaminB12! * scaleFactor : null,
                calcium: n.calcium != null
                    ? (n.calcium! * scaleFactor).toDouble()
                    : null,
                iron: n.iron != null ? n.iron! * scaleFactor : null,
              ))
          .toList(),
    );

    // Add to meal
    Provider.of<DailyMealsProvider>(context, listen: false)
        .addFoodToMeal(mealType, scaledFood);

    // Add to history (recents and frequency)
    final historyProvider =
        Provider.of<FoodHistoryProvider>(context, listen: false);
    historyProvider.addToRecents(scaledFood);
    historyProvider.incrementFrequency(scaledFood);

    // Get meal name
    final option = DailyMealsProvider.getMealTypeOption(mealType);
    final navigatorContext = Navigator.of(context).context;
    final successMessage = '${currentFood.name} added to ${option.name}';

    // Close food page
    Navigator.pop(context);

    // Show success message
    UIUtils.showPrimarySnackBar(navigatorContext, successMessage);

    // Conta + tenta mostrar intersticial após N refeições
    AdManager.notifyMealRegistered();
    AdManager.maybeShowMealDoneInterstitial();
  }

  void _showMealTypeSelector(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final subtleBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
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
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Meal types list
                ...MealType.values.map((mealType) {
                  final option = DailyMealsProvider.getMealTypeOption(mealType);

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pop(context);
                      _addToMeal(mealType);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: subtleBorder, width: 1),
                      ),
                      child: Row(
                        children: [
                          Text(option.emoji,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Text(
                            option.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
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

    // If no portions are available, inform the user instead of doing nothing
    if (portions == null || portions.isEmpty) {
      UIUtils.showPrimarySnackBar(
        context,
        'Porções alternativas não disponíveis para este alimento',
      );
      return;
    }

    // Get base serving size (usually 100g)
    final nutrient = currentFood.nutrients?.first;
    final baseServingSize = nutrient?.servingSize ?? 100.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
        final textColor =
            isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
        final subtleBorder = isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08);
        final primaryColor =
            isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
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
                    'Select Portion',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Portions list
              ...portions.map((portion) {
                final isSelected =
                    _selectedPortionDescription == portion.description;

                // Parse the portion description
                final parsed = _parsePortionDescription(portion.description);
                final displayText = parsed['displayText'] as String;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      // Parse the description to get display values
                      final parsedSize = parsed['size'] as double;
                      final parsedUnit = parsed['unit'] as String;

                      // Calculate the size for 1 unit of this portion
                      final singleUnitSize = parsedSize > 0
                          ? (baseServingSize * portion.proportion) / parsedSize
                          : baseServingSize * portion.proportion;

                      print('===== PORTION SELECTED =====');
                      print('Description: ${portion.description}');
                      print('Parsed size (display): $parsedSize');
                      print('Parsed unit (display): $parsedUnit');
                      print('Proportion: ${portion.proportion}');
                      print('Base serving: $baseServingSize');
                      print('Single unit size: $singleUnitSize');
                      print(
                          'Actual serving size (for macros): ${singleUnitSize * parsedSize}');
                      print('============================');

                      _singlePortionSize = singleUnitSize;
                      _currentServingSize = singleUnitSize * parsedSize;
                      _currentServingUnit = parsedUnit;
                      _selectedPortionDescription = portion.description;
                      _servingSizeController.text =
                          parsedSize.toStringAsFixed(0);
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? primaryColor : subtleBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayText,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_circle,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final secondaryTextColor =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final subtleBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final onPrimary = isDarkMode ? Colors.black : Colors.white;

    // Use full data if loaded, otherwise use initial data
    final currentFood = _fullFoodData ?? widget.food;
    final nutrient = currentFood.nutrients?.first;
    final calories = _getScaledValue(nutrient?.calories);
    final protein = _getScaledValue(nutrient?.protein);
    final carbs = _getScaledValue(nutrient?.carbohydrate);
    final fat = _getScaledValue(nutrient?.fat);

    // Whether alternative portions exist (controls Unit field interactivity)
    final availablePortions = currentFood.foodRegions?.first.portions;
    final hasPortions =
        availablePortions != null && availablePortions.isNotEmpty;

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
                        print(
                            'JavaScript handler called with ${args.length} args');
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
                      final hasNutritionFacts = await controller.evaluateJavascript(
                          source:
                              'document.querySelector(".nutrition_facts") !== null');
                      print('Has nutrition_facts element: $hasNutritionFacts');

                      if (hasNutritionFacts == true) {
                        final nfClass = await controller.evaluateJavascript(
                            source:
                                'document.querySelector(".nutrition_facts").className');
                        print('Nutrition facts class: $nfClass');
                      }
                    } catch (e) {
                      print('Error checking page: $e');
                    }

                    await _extractFullFoodData();
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    print(
                        '[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
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
                    scrolledUnderElevation: 0,
                    centerTitle: true,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: widget.selectedMealType != null
                        ? DropdownButton<MealType>(
                            value: _selectedMealType,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            dropdownColor: isDarkMode
                                ? AppTheme.darkCardColor
                                : Colors.white,
                            icon: Icon(Icons.arrow_drop_down,
                                color: textColor, size: 22),
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            items: MealType.values.map((mealType) {
                              final option =
                                  DailyMealsProvider.getMealTypeOption(
                                      mealType);
                              return DropdownMenuItem<MealType>(
                                value: mealType,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(option.emoji,
                                        style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Text(
                                      option.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
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
                        : null,
                    actions: [
                      Consumer<FoodHistoryProvider>(
                        builder: (context, historyProvider, child) {
                          final currentFood = _fullFoodData ?? widget.food;
                          final isFavorited =
                              historyProvider.isFavorite(currentFood);

                          return IconButton(
                            icon: Icon(
                              isFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorited ? Colors.red : textColor,
                            ),
                            onPressed: () async {
                              historyProvider.toggleFavorite(currentFood);

                              // Sincroniza com o servidor
                              final token = Provider.of<AuthService>(context,
                                      listen: false)
                                  .token;
                              if (token == null || token.isEmpty) return;
                              final svc = FavoriteFoodService(token: token);

                              if (!isFavorited) {
                                // Estava desfavoritado → agora favoritando
                                final nutrient =
                                    currentFood.nutrients?.isNotEmpty == true
                                        ? currentFood.nutrients!.first
                                        : null;
                                await svc.addFavorite(FavoriteFood(
                                  id: 0,
                                  name: currentFood.name,
                                  emoji: currentFood.emoji,
                                  calories: currentFood.calories,
                                  protein: currentFood.protein,
                                  carbs: currentFood.carbs,
                                  fat: currentFood.fat,
                                  fiber: nutrient?.dietaryFiber ?? 0,
                                  baseAmount: nutrient?.servingSize ?? 100,
                                  baseUnit: nutrient?.servingUnit ?? 'g',
                                ));
                              } else {
                                // Estava favoritado → desfavoritando
                                final results =
                                    await svc.searchFavorites(currentFood.name);
                                if (results.isNotEmpty) {
                                  await svc.deleteFavorite(results.first.id);
                                }
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  // Loading or Content
                  if (_isLoading)
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
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
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: isDarkMode
                                        ? const Color(0xFF2E2E2E)
                                        : const Color(0xFFF3F4F6),
                                    border: Border.all(
                                      color: subtleBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: currentFood.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: currentFood.imageUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Center(
                                              child: Text(
                                                currentFood.emoji,
                                                style: const TextStyle(
                                                    fontSize: 34),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) => Center(
                                              child: Text(
                                                currentFood.emoji,
                                                style: const TextStyle(
                                                    fontSize: 34),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              currentFood.emoji,
                                              style: const TextStyle(
                                                  fontSize: 34),
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                // Food name and brand
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        currentFood.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (currentFood.brand != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          currentFood.brand!,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4, bottom: 8),
                                        child: Text(
                                          'Serving Size',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ),
                                      TextField(
                                        controller: _servingSizeController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.transparent,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                              color: subtleBorder,
                                              width: 1,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                              color: subtleBorder,
                                              width: 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4, bottom: 8),
                                        child: Text(
                                          'Unit',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: hasPortions
                                            ? _showPortionPicker
                                            : () {
                                                UIUtils.showPrimarySnackBar(
                                                  context,
                                                  'Porções alternativas não disponíveis para este alimento',
                                                );
                                              },
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: subtleBorder,
                                              width: 1,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _currentServingUnit ??
                                                      (_selectedPortionDescription !=
                                                              null
                                                          ? _parsePortionDescription(
                                                                      _selectedPortionDescription!)[
                                                                  'displayText']
                                                              as String
                                                          : '${_currentServingSize.toStringAsFixed(0)} ${nutrient?.servingUnit ?? 'g'}'),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: hasPortions
                                                        ? textColor
                                                        : secondaryTextColor,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                Icons.unfold_more,
                                                color: secondaryTextColor
                                                    .withValues(
                                                        alpha: hasPortions
                                                            ? 1.0
                                                            : 0.4),
                                                size: 18,
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
                            child: Card(
                              margin: EdgeInsets.zero,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: subtleBorder),
                              ),
                              color: isDarkMode
                                  ? AppTheme.darkCardColor
                                  : AppTheme.cardColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 12),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildMacroCardCompact(
                                          icon: MacroTheme.caloriesIcon,
                                          value: calories.toStringAsFixed(0),
                                          unit: 'kcal',
                                          color: MacroTheme.caloriesColor,
                                          isDarkMode: isDarkMode,
                                        ),
                                      ),
                                      VerticalDivider(
                                        color: subtleBorder,
                                        width: 1,
                                        thickness: 1,
                                        indent: 4,
                                        endIndent: 4,
                                      ),
                                      Expanded(
                                        child: _buildMacroCardCompact(
                                          icon: MacroTheme.proteinIcon,
                                          value:
                                              '${protein.toStringAsFixed(1)}g',
                                          unit: 'Proteína',
                                          color: MacroTheme.proteinColor,
                                          isDarkMode: isDarkMode,
                                        ),
                                      ),
                                      VerticalDivider(
                                        color: subtleBorder,
                                        width: 1,
                                        thickness: 1,
                                        indent: 4,
                                        endIndent: 4,
                                      ),
                                      Expanded(
                                        child: _buildMacroCardCompact(
                                          icon: MacroTheme.carbsIcon,
                                          value:
                                              '${carbs.toStringAsFixed(1)}g',
                                          unit: 'Carboidrato',
                                          color: MacroTheme.carbsColor,
                                          isDarkMode: isDarkMode,
                                        ),
                                      ),
                                      VerticalDivider(
                                        color: subtleBorder,
                                        width: 1,
                                        thickness: 1,
                                        indent: 4,
                                        endIndent: 4,
                                      ),
                                      Expanded(
                                        child: _buildMacroCardCompact(
                                          icon: MacroTheme.fatIcon,
                                          value: '${fat.toStringAsFixed(1)}g',
                                          unit: 'Gordura',
                                          color: MacroTheme.fatColor,
                                          isDarkMode: isDarkMode,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 24),

                          // Detailed Nutrition Facts Card
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? AppTheme.darkCardColor
                                    : AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: subtleBorder,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Macronutrients Section
                                    Text(
                                      'Macronutrients',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),

                                    Divider(
                                      color: subtleBorder,
                                      height: 22,
                                      thickness: 1,
                                    ),

                                    // Calories
                                    MacroNutrientRow(
                                      label: 'Calories',
                                      value:
                                          '${calories.toStringAsFixed(0)} kcal',
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
                                    if (nutrient?.dietaryFiber != null ||
                                        nutrient?.sugars != null)
                                      Container(
                                        margin:
                                            EdgeInsets.only(left: 0, top: 8),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: MacroTheme.carbsColor
                                                  .withValues(alpha: 0.3),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            if (nutrient?.dietaryFiber != null)
                                              SubNutrientRow(
                                                label: 'Dietary Fiber',
                                                value:
                                                    '${_getScaledValue(nutrient?.dietaryFiber).toStringAsFixed(0)} g',
                                                isDarkMode: isDarkMode,
                                              ),
                                            if (nutrient?.sugars != null)
                                              SubNutrientRow(
                                                label: 'Sugars',
                                                value:
                                                    '${_getScaledValue(nutrient?.sugars).toStringAsFixed(0)} g',
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
                                    if (nutrient?.saturatedFat != null ||
                                        nutrient?.transFat != null)
                                      Container(
                                        margin:
                                            EdgeInsets.only(left: 0, top: 8),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: MacroTheme.fatColor
                                                  .withValues(alpha: 0.3),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            if (nutrient?.saturatedFat != null)
                                              SubNutrientRow(
                                                label: 'Saturated Fat',
                                                value:
                                                    '${_getScaledValue(nutrient?.saturatedFat).toStringAsFixed(1)} g',
                                                isDarkMode: isDarkMode,
                                              ),
                                            if (nutrient?.transFat != null)
                                              SubNutrientRow(
                                                label: 'Trans Fat',
                                                value:
                                                    '${_getScaledValue(nutrient?.transFat).toStringAsFixed(0)} g',
                                                isDarkMode: isDarkMode,
                                              ),
                                          ],
                                        ),
                                      ),

                                    SizedBox(height: 24),

                                    // Micronutrients Section
                                    Text(
                                      'Micronutrients',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),

                                    Divider(
                                      color: subtleBorder,
                                      height: 22,
                                      thickness: 1,
                                    ),

                                    // Micronutrients List
                                    if (nutrient?.cholesterol != null)
                                      MicroNutrientRow(
                                        label: 'Cholesterol',
                                        value:
                                            '${_getScaledValue(nutrient?.cholesterol).toStringAsFixed(0)} mg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.cholesterol != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.sodium != null)
                                      MicroNutrientRow(
                                        label: 'Sodium',
                                        value:
                                            '${_getScaledValue(nutrient?.sodium).toStringAsFixed(0)} mg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.sodium != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.potassium != null)
                                      MicroNutrientRow(
                                        label: 'Potassium',
                                        value:
                                            '${_getScaledValue(nutrient?.potassium).toStringAsFixed(0)} mg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.potassium != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.calcium != null)
                                      MicroNutrientRow(
                                        label: 'Calcium',
                                        value:
                                            '${_getScaledValue(nutrient?.calcium).toStringAsFixed(0)} mg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.calcium != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.iron != null)
                                      MicroNutrientRow(
                                        label: 'Iron',
                                        value:
                                            '${_getScaledValue(nutrient?.iron).toStringAsFixed(1)} mg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.iron != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.vitaminD != null)
                                      MicroNutrientRow(
                                        label: 'Vitamin D',
                                        value:
                                            '${_getScaledValue(nutrient?.vitaminD).toStringAsFixed(1)} mcg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.vitaminD != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.vitaminA != null)
                                      MicroNutrientRow(
                                        label: 'Vitamin A',
                                        value:
                                            '${_getScaledValue(nutrient?.vitaminA).toStringAsFixed(1)} mcg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.vitaminA != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.vitaminC != null)
                                      MicroNutrientRow(
                                        label: 'Vitamin C',
                                        value:
                                            '${_getScaledValue(nutrient?.vitaminC).toStringAsFixed(1)} mg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.vitaminC != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.vitaminB6 != null)
                                      MicroNutrientRow(
                                        label: 'Vitamin B6',
                                        value:
                                            '${_getScaledValue(nutrient?.vitaminB6).toStringAsFixed(1)} mg',
                                        isDarkMode: isDarkMode,
                                      ),
                                    if (nutrient?.vitaminB6 != null)
                                      SizedBox(height: 12),

                                    if (nutrient?.vitaminB12 != null)
                                      MicroNutrientRow(
                                        label: 'Vitamin B12',
                                        value:
                                            '${_getScaledValue(nutrient?.vitaminB12).toStringAsFixed(1)} mcg',
                                        isDarkMode: isDarkMode,
                                      ),
                                  ],
                                ),
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
                color: backgroundColor,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.selectedMealType != null) {
                        _addToMeal(_selectedMealType);
                      } else {
                        _showMealTypeSelector(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Add to Meal',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: onPrimary,
                      ),
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
