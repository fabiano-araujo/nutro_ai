import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/FoodAllergen.dart';
import '../models/FoodRegion.dart';
import '../models/Nutrient.dart';
import '../models/Portion.dart';
import '../models/food_model.dart';
import '../util/app_constants.dart';

void _catalogLog(String message) {
  debugPrint('[BarcodeFoodFlow] $message');
}

class OpenFoodFactsProduct {
  final String barcode;
  final String productName;
  final String? brand;
  final String? imageUrl;
  final String? quantity;
  final String? servingSize;
  final double? servingQuantity;
  final String? servingQuantityUnit;
  final Map<String, dynamic> nutriments;
  final List<String> allergensTags;
  final List<String> tracesTags;
  final String? allergensText;
  final String? tracesText;
  final List<String> ingredientsAnalysisTags;

  const OpenFoodFactsProduct({
    required this.barcode,
    required this.productName,
    this.brand,
    this.imageUrl,
    this.quantity,
    this.servingSize,
    this.servingQuantity,
    this.servingQuantityUnit,
    this.nutriments = const <String, dynamic>{},
    this.allergensTags = const <String>[],
    this.tracesTags = const <String>[],
    this.allergensText,
    this.tracesText,
    this.ingredientsAnalysisTags = const <String>[],
  });

  factory OpenFoodFactsProduct.fromApiJson(
    Map<String, dynamic> json,
    String fallbackBarcode,
  ) {
    final product = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : <String, dynamic>{};
    final barcode = _normalizeBarcode(product['code']) ??
        _normalizeBarcode(json['code']) ??
        fallbackBarcode;
    final name = _firstText(
      product['product_name_pt'],
      product['product_name'],
      product['product_name_en'],
      product['generic_name_pt'],
      product['generic_name'],
    );

    if (name == null) {
      _catalogLog(
        'OpenFoodFactsProduct.fromApiJson: missing_name barcode=$barcode',
      );
      throw const FormatException('Open Food Facts product has no name');
    }

    final brand = _firstBrand(product['brands']);
    final hasNutriments = product['nutriments'] is Map;
    _catalogLog(
      'OpenFoodFactsProduct.fromApiJson: barcode=$barcode name="$name" '
      'brand="${brand ?? '-'}" hasNutriments=$hasNutriments',
    );

    return OpenFoodFactsProduct(
      barcode: barcode,
      productName: name,
      brand: brand,
      imageUrl: _firstText(
        product['image_url'],
        product['image_front_url'],
        product['image_small_url'],
      ),
      quantity: _firstText(product['quantity']),
      servingSize: _firstText(product['serving_size']),
      servingQuantity: _toDouble(product['serving_quantity']),
      servingQuantityUnit: _firstText(product['serving_quantity_unit']),
      nutriments: product['nutriments'] is Map
          ? Map<String, dynamic>.from(product['nutriments'] as Map)
          : const <String, dynamic>{},
      allergensTags: _stringList(product['allergens_tags']),
      tracesTags: _stringList(product['traces_tags']),
      allergensText: _firstText(
        product['allergens'],
        product['allergens_from_ingredients'],
      ),
      tracesText: _firstText(
        product['traces'],
        product['traces_from_ingredients'],
      ),
      ingredientsAnalysisTags:
          _stringList(product['ingredients_analysis_tags']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'productName': productName,
      if (_hasText(brand)) 'brand': brand,
      if (_hasText(imageUrl)) 'imageUrl': imageUrl,
      if (_hasText(quantity)) 'quantity': quantity,
      if (_hasText(servingSize)) 'servingSize': servingSize,
      if (servingQuantity != null) 'servingQuantity': servingQuantity,
      if (_hasText(servingQuantityUnit))
        'servingQuantityUnit': servingQuantityUnit,
      'nutriments': nutriments,
      if (allergensTags.isNotEmpty) 'allergensTags': allergensTags,
      if (tracesTags.isNotEmpty) 'tracesTags': tracesTags,
      if (_hasText(allergensText)) 'allergensText': allergensText,
      if (_hasText(tracesText)) 'tracesText': tracesText,
      if (ingredientsAnalysisTags.isNotEmpty)
        'ingredientsAnalysisTags': ingredientsAnalysisTags,
    };
  }

  Food toFood({
    required String marketLocale,
    String language = '',
  }) {
    final nutrient = _buildNutrient();
    final portions = _buildPortions();
    final allergens = _buildAllergens();

    _catalogLog(
      'OpenFoodFactsProduct.toFood: barcode=$barcode name="$productName" '
      'origin=open_food_facts hasNutrient=${nutrient != null} '
      'portions=${portions.length} allergens=${allergens.length}',
    );

    return Food(
      name: productName,
      photo: imageUrl,
      brand: brand,
      isVegetarian: _dietStatus('vegetarian'),
      isVegan: _dietStatus('vegan'),
      emoji: '🍽️',
      nutrients: nutrient == null ? null : <Nutrient>[nutrient],
      foodRegions: [
        FoodRegion(
          regionCode: marketLocale,
          languageCode: language,
          idFood: 0,
          description: _buildDescription(),
          translation: productName,
          portions: portions,
        ),
      ],
      foodAllergens: allergens,
    );
  }

  String _buildDescription() {
    final values = <String>[
      productName,
      if (_hasText(brand)) brand!,
      if (_hasText(quantity)) quantity!,
    ];
    return values.join(' - ');
  }

  Nutrient? _buildNutrient() {
    final calories = _energyKcal100g();
    final carbohydrate = _nutrimentValue('carbohydrates');
    final protein = _nutrimentValue('proteins');
    final fat = _nutrimentValue('fat');
    final saturatedFat = _nutrimentValue('saturated-fat');
    final transFat = _nutrimentValue('trans-fat');
    final sugars = _nutrimentValue('sugars');
    final addedSugars = _nutrimentValue('added-sugars');
    final dietaryFiber = _nutrimentValue('fiber');
    final sodium = _nutrimentMg('sodium') ?? _saltToSodiumMg();
    final potassium = _nutrimentMg('potassium');
    final cholesterol = _nutrimentMg('cholesterol');
    final calcium = _nutrimentMg('calcium');
    final iron = _nutrimentMg('iron');

    final hasAnyValue = <double?>[
      calories,
      carbohydrate,
      protein,
      fat,
      saturatedFat,
      transFat,
      sugars,
      addedSugars,
      dietaryFiber,
      sodium,
      potassium,
      cholesterol,
      calcium,
      iron,
    ].any((value) => value != null);

    if (!hasAnyValue) return null;

    return Nutrient(
      idFood: 0,
      servingSize: 100,
      servingUnit: 'g',
      calories: calories,
      carbohydrate: carbohydrate,
      protein: protein,
      fat: fat,
      saturatedFat: saturatedFat,
      transFat: transFat,
      sugars: sugars,
      addedSugars: addedSugars,
      dietaryFiber: dietaryFiber,
      sodium: sodium,
      potassium: potassium,
      cholesterol: cholesterol,
      calcium: calcium,
      iron: iron,
    );
  }

  List<Portion> _buildPortions() {
    final portions = <Portion>[];
    final serving = _servingPortion();
    if (serving != null) {
      portions.add(serving);
    }

    portions.add(
      Portion(
        idFoodRegion: 0,
        description: '100 g',
        proportion: 1,
      ),
    );

    return portions;
  }

  Portion? _servingPortion() {
    final parsedServing = _parseQuantityAndUnit(servingSize);
    final quantity = parsedServing?.$1 ?? servingQuantity;
    final unit = parsedServing?.$2 ?? servingQuantityUnit;

    if (quantity == null || quantity <= 0 || !_hasText(unit)) {
      return null;
    }

    final normalizedUnit = unit!.trim().toLowerCase();
    if (normalizedUnit != 'g' && normalizedUnit != 'ml') {
      return null;
    }

    return Portion(
      idFoodRegion: 0,
      description: '${_formatNumber(quantity)} $normalizedUnit',
      proportion: quantity / 100,
    );
  }

  List<FoodAllergen> _buildAllergens() {
    final statuses = <AllergenType, AllergenStatus>{};

    void add(AllergenType? type, AllergenStatus status) {
      if (type == null) return;
      final current = statuses[type];
      if (current == AllergenStatus.contains) return;
      if (current == AllergenStatus.mayContain &&
          status == AllergenStatus.free) {
        return;
      }
      statuses[type] = status;
    }

    for (final tag in allergensTags) {
      add(_parseAllergen(tag), AllergenStatus.contains);
    }
    for (final token in _splitClaimText(allergensText)) {
      add(_parseAllergen(token), AllergenStatus.contains);
    }
    for (final tag in tracesTags) {
      add(_parseAllergen(tag), AllergenStatus.mayContain);
    }
    for (final token in _splitClaimText(tracesText)) {
      add(_parseAllergen(token), AllergenStatus.mayContain);
    }

    return statuses.entries
        .map(
          (entry) => FoodAllergen(
            idFood: 0,
            allergen: entry.key,
            status: entry.value,
          ),
        )
        .toList();
  }

  String? _dietStatus(String diet) {
    final tags =
        ingredientsAnalysisTags.map((tag) => tag.toLowerCase()).toSet();

    if (tags.contains('en:$diet')) return 'yes';
    if (tags.contains('en:non-$diet')) return 'no';
    if (tags.contains('en:$diet-status-unknown')) return 'maybe';
    return null;
  }

  double? _energyKcal100g() {
    final kcal = _nutrimentValue('energy-kcal');
    if (kcal != null) return kcal;

    final kj = _nutrimentValue('energy-kj') ?? _readNutriment('energy_100g');
    if (kj == null) return null;
    return kj / 4.184;
  }

  double? _nutrimentValue(String baseName) {
    return _readNutriment('${baseName}_100g') ??
        _readNutriment(baseName) ??
        _readNutriment('${baseName}_value');
  }

  double? _nutrimentMg(String baseName) {
    final value = _nutrimentValue(baseName);
    if (value == null) return null;

    final unit = _firstText(nutriments['${baseName}_unit'])?.toLowerCase();
    if (unit == 'mg') return value;
    if (unit == 'ug' || unit == 'µg') return value / 1000;
    return value * 1000;
  }

  double? _saltToSodiumMg() {
    final salt = _nutrimentValue('salt');
    if (salt == null) return null;
    return salt * 400;
  }

  double? _readNutriment(String key) {
    return _toDouble(nutriments[key]);
  }
}

class FoodCatalogService {
  static Future<OpenFoodFactsProduct?> getOpenFoodFactsProductByBarcode({
    required String barcode,
  }) async {
    final normalizedBarcode = _normalizeBarcode(barcode);
    if (normalizedBarcode == null) return null;

    _catalogLog(
      'OpenFoodFacts lookup: start barcode=$normalizedBarcode origin=device',
    );

    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$normalizedBarcode.json',
    ).replace(
      queryParameters: {
        'fields': [
          'code',
          'product_name',
          'product_name_pt',
          'product_name_en',
          'generic_name',
          'generic_name_pt',
          'brands',
          'image_url',
          'image_front_url',
          'image_small_url',
          'quantity',
          'serving_size',
          'serving_quantity',
          'serving_quantity_unit',
          'nutriments',
          'allergens',
          'allergens_from_ingredients',
          'allergens_tags',
          'traces',
          'traces_from_ingredients',
          'traces_tags',
          'ingredients_analysis_tags',
        ].join(','),
      },
    );

    try {
      final headers = <String, String>{'Accept': 'application/json'};
      if (!kIsWeb) {
        headers['User-Agent'] = 'NutroAI/1.0 (mobile app)';
      }

      final response = await http.get(uri, headers: headers);
      _catalogLog(
        'OpenFoodFacts lookup: response barcode=$normalizedBarcode '
        'status=${response.statusCode}',
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Open Food Facts lookup failed (${response.statusCode}): ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 1) {
        _catalogLog(
          'OpenFoodFacts lookup: not_found barcode=$normalizedBarcode '
          'bodyStatus=${decoded is Map ? decoded['status'] : 'invalid_json'}',
        );
        return null;
      }

      final product =
          OpenFoodFactsProduct.fromApiJson(decoded, normalizedBarcode);
      _catalogLog(
        'OpenFoodFacts lookup: found barcode=$normalizedBarcode '
        'name="${product.productName}" brand="${product.brand ?? '-'}" '
        'nutriments=${product.nutriments.length}',
      );
      return product;
    } catch (e) {
      debugPrint('Open Food Facts lookup error: $e');
      _catalogLog(
        'OpenFoodFacts lookup: error barcode=$normalizedBarcode error=$e',
      );
      return null;
    }
  }

  static Future<Food?> getFoodByBarcode({
    required String barcode,
    required String marketLocale,
    String language = '',
  }) async {
    _catalogLog(
      'Server barcode lookup: start barcode=$barcode market=$marketLocale '
      'language=$language',
    );

    final uri = Uri.parse(
      '${AppConstants.DIET_API_BASE_URL}/food/barcode/${Uri.encodeComponent(barcode)}',
    ).replace(
      queryParameters: {
        'marketLocale': marketLocale,
        'region': marketLocale,
        'language': language,
      },
    );

    try {
      final response = await http.get(uri);
      _catalogLog(
        'Server barcode lookup: response barcode=$barcode '
        'status=${response.statusCode}',
      );
      if (response.statusCode == 404) {
        _catalogLog('Server barcode lookup: not_found barcode=$barcode');
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Food barcode lookup failed (${response.statusCode}): ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final foodRegionData = decoded['foodRegion'];
      if (foodRegionData is Map<String, dynamic>) {
        _catalogLog(
          'Server barcode lookup: hit barcode=$barcode '
          'source=${decoded['source'] ?? 'server'}',
        );
        return foodFromFoodRegionJson(
          foodRegionData,
          source: 'server_barcode:${decoded['source'] ?? 'unknown'}',
        );
      }

      if (decoded['food'] is Map<String, dynamic>) {
        _catalogLog(
            'Server barcode lookup: hit legacy payload barcode=$barcode');
        return foodFromFoodRegionJson(
          decoded,
          source: 'server_barcode:legacy_payload',
        );
      }

      _catalogLog('Server barcode lookup: invalid_payload barcode=$barcode');
      return null;
    } catch (e) {
      debugPrint('Food barcode lookup error: $e');
      _catalogLog('Server barcode lookup: error barcode=$barcode error=$e');
      return null;
    }
  }

  static Future<Food?> resolveOpenFoodFactsBarcode({
    required OpenFoodFactsProduct product,
    required String marketLocale,
    String language = '',
  }) async {
    _catalogLog(
      'OpenFoodFacts resolve: post barcode=${product.barcode} '
      'market=$marketLocale name="${product.productName}"',
    );

    final food = product.toFood(
      marketLocale: marketLocale,
      language: language,
    );
    final uri = Uri.parse('${AppConstants.DIET_API_BASE_URL}/food/barcode')
        .replace(queryParameters: {
      'region': marketLocale,
      'language': language,
      'source': 'open_food_facts',
    });

    final decoded = await _postFoodRequestForJson(
        uri,
        {
          'barcode': product.barcode,
          'marketLocale': marketLocale,
          'openFoodFactsProduct': product.toJson(),
          'foodRequest': buildFoodRequest(food),
        },
        logContext: 'OpenFoodFacts resolve');

    if (decoded == null) return null;
    _catalogLog(
      'OpenFoodFacts resolve: backend_result barcode=${product.barcode} '
      'created=${decoded['created']} matched=${decoded['matched']} '
      'source=${decoded['source'] ?? '-'}',
    );
    final foodRegionData = decoded['foodRegion'];
    if (foodRegionData is Map<String, dynamic>) {
      return foodFromFoodRegionJson(
        foodRegionData,
        source:
            'open_food_facts_backend:${decoded['source'] ?? (decoded['created'] == true ? 'created' : 'existing')}',
      );
    }

    _catalogLog(
      'OpenFoodFacts resolve: invalid_backend_payload barcode=${product.barcode}',
    );
    return null;
  }

  static Future<void> saveFood({
    required Food food,
    required String region,
    String language = '',
    String source = 'mobile',
  }) async {
    final uri = Uri.parse('${AppConstants.DIET_API_BASE_URL}/food/script')
        .replace(queryParameters: {
      'region': region,
      'language': language,
      'source': source,
    });

    _catalogLog('Save food: post name="${food.name}" region=$region');
    await _postFoodRequest(
      uri,
      buildFoodRequest(food),
      logContext: 'Save food',
    );
  }

  static Future<void> saveBarcodeFood({
    required String barcode,
    required String marketLocale,
    required Food food,
    String language = '',
    String source = 'mobile',
  }) async {
    final uri = Uri.parse('${AppConstants.DIET_API_BASE_URL}/food/barcode')
        .replace(queryParameters: {
      'region': marketLocale,
      'language': language,
      'source': source,
    });

    _catalogLog(
      'Save barcode food: post barcode=$barcode market=$marketLocale '
      'name="${food.name}" source=$source',
    );
    await _postFoodRequest(
        uri,
        {
          'barcode': barcode,
          'marketLocale': marketLocale,
          'foodRequest': buildFoodRequest(food),
        },
        logContext: 'Save barcode food');
  }

  static Map<String, dynamic> buildFoodRequest(Food food) {
    final foodRegion =
        food.foodRegions?.isNotEmpty == true ? food.foodRegions!.first : null;
    final nutrients = food.nutrients ?? const <Nutrient>[];
    final portions = foodRegion?.portions ?? const <Portion>[];
    final allergens = food.foodAllergens ?? const <FoodAllergen>[];

    final requestPortions = portions
        .map((portion) => {
              'proportion': portion.proportion,
              'description': portion.description,
            })
        .where((portion) => (portion['description'] as String).isNotEmpty)
        .toList();

    if (requestPortions.isEmpty && nutrients.isNotEmpty) {
      final nutrient = nutrients.first;
      requestPortions.add({
        'proportion': 1.0,
        'description':
            '${_formatNumber(nutrient.servingSize)} ${nutrient.servingUnit}'
                .trim(),
      });
    }

    return {
      'food': {
        if (food.id != null) 'id': food.id,
        'name': food.name,
        if (_hasText(food.photo)) 'photo': food.photo,
        if (food.idFatsecret != null) 'id_fatsecret': food.idFatsecret,
        if (_hasText(food.brand)) 'brand': food.brand,
        if (_hasText(food.isVegetarian))
          'is_vegetarian': _normalizeDietValue(food.isVegetarian),
        if (_hasText(food.isVegan))
          'is_vegan': _normalizeDietValue(food.isVegan),
      },
      'description': foodRegion?.description ?? food.name,
      'portion': requestPortions,
      'nutrient': nutrients.map(_nutrientToRequestJson).toList(),
      if (allergens.isNotEmpty)
        'allergens': allergens.map(_allergenToRequestJson).toList(),
    };
  }

  static Food foodFromFoodRegionJson(
    Map<String, dynamic> foodRegionData, {
    String source = 'unknown',
  }) {
    final foodData = foodRegionData['food'] is Map<String, dynamic>
        ? foodRegionData['food'] as Map<String, dynamic>
        : <String, dynamic>{};

    final nutrientList = foodData['nutrient'] is List
        ? (foodData['nutrient'] as List)
            .whereType<Map>()
            .map((item) => Nutrient.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <Nutrient>[];
    final allergenList = foodData['food_allergen'] is List
        ? (foodData['food_allergen'] as List)
            .whereType<Map>()
            .map((item) =>
                FoodAllergen.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <FoodAllergen>[];
    final portions = foodRegionData['portion'] is List
        ? (foodRegionData['portion'] as List)
            .whereType<Map>()
            .map((item) => Portion.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <Portion>[];

    final foodRegion = FoodRegion.fromJson({
      ...foodRegionData,
      'portion': portions.map((portion) => portion.toJson()).toList(),
    });

    final food = Food(
      id: foodData['id'],
      name: foodRegionData['translation'] ?? foodData['name'] ?? '',
      photo: foodData['photo'],
      idFatsecret: foodData['id_fatsecret'],
      brand: foodData['brand'],
      isVegetarian: foodData['is_vegetarian'],
      isVegan: foodData['is_vegan'],
      emoji: '🍽️',
      nutrients: nutrientList.isEmpty ? null : nutrientList,
      foodRegions: [foodRegion],
      foodAllergens: allergenList,
    );

    _catalogLog(
      'Food factory: source=$source id=${food.id ?? '-'} '
      'name="${food.name}" brand="${food.brand ?? '-'}" '
      'nutrients=${nutrientList.length} portions=${portions.length} '
      'allergens=${allergenList.length}',
    );

    return food;
  }

  static Future<void> _postFoodRequest(
    Uri uri,
    Map<String, dynamic> body, {
    String logContext = 'Food POST',
  }) async {
    await _postFoodRequestForJson(uri, body, logContext: logContext);
  }

  static Future<Map<String, dynamic>?> _postFoodRequestForJson(
    Uri uri,
    Map<String, dynamic> body, {
    String logContext = 'Food POST',
  }) async {
    try {
      _catalogLog('$logContext: request uri=$uri');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      _catalogLog('$logContext: response status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Food catalog save failed (${response.statusCode}): ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        _catalogLog(
          '$logContext: decoded source=${decoded['source'] ?? '-'} '
          'created=${decoded['created'] ?? '-'} matched=${decoded['matched'] ?? '-'}',
        );
        return decoded;
      }

      _catalogLog('$logContext: decoded non_map_payload');
      return null;
    } catch (e) {
      debugPrint('Food catalog save error: $e');
      _catalogLog('$logContext: error=$e');
      return null;
    }
  }

  static Map<String, dynamic> _nutrientToRequestJson(Nutrient nutrient) {
    final json = nutrient.toJson();
    json.remove('id');
    json['id_food'] = nutrient.idFood;
    return json;
  }

  static Map<String, dynamic> _allergenToRequestJson(FoodAllergen allergen) {
    final json = allergen.toJson();
    json.remove('id');
    json['id_food'] = allergen.idFood;
    return json;
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _normalizeDietValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'true':
      case 'yes':
        return 'yes';
      case 'false':
      case 'no':
        return 'no';
      case 'maybe':
      case 'may_not':
      case 'may not':
        return 'maybe';
      default:
        return value ?? '';
    }
  }

  static String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
}

String? _normalizeBarcode(dynamic value) {
  final normalized = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? _firstText(dynamic first,
    [dynamic second, dynamic third, dynamic fourth, dynamic fifth]) {
  for (final value in <dynamic>[first, second, third, fourth, fifth]) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

String? _firstBrand(dynamic value) {
  final text = _firstText(value);
  if (text == null) return null;
  return text.split(',').first.trim();
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  final text = _firstText(value);
  if (text == null) return const <String>[];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<String> _splitClaimText(String? value) {
  final text = value?.toLowerCase().replaceAll(';', ',') ?? '';
  if (text.trim().isEmpty) return const <String>[];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

AllergenType? _parseAllergen(String value) {
  final text = _normalizeClaim(value);

  if (text.contains('peanut') || text.contains('amendoim')) {
    return AllergenType.peanuts;
  }
  if (text.contains('sesame') || text.contains('gergelim')) {
    return AllergenType.sesame;
  }
  if (text.contains('gluten') || text.contains('gluten')) {
    return AllergenType.gluten;
  }
  if (text.contains('lactose')) {
    return AllergenType.lactose;
  }
  if (text.contains('milk') ||
      text.contains('leite') ||
      text.contains('dairy')) {
    return AllergenType.milk;
  }
  if (text.contains('egg') || text.contains('ovo')) {
    return AllergenType.egg;
  }
  if (text.contains('soy') || text.contains('soja')) {
    return AllergenType.soy;
  }
  if (text.contains('fish') || text.contains('peixe')) {
    return AllergenType.fish;
  }
  if (text.contains('shellfish') ||
      text.contains('crustacean') ||
      text.contains('mollusc') ||
      text.contains('camarao')) {
    return AllergenType.shellfish;
  }
  if (text.contains('nut') ||
      text.contains('noz') ||
      text.contains('nozes') ||
      text.contains('castanha')) {
    return AllergenType.nuts;
  }

  return null;
}

String _normalizeClaim(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'õ': 'o',
    'ô': 'o',
    'ú': 'u',
    'ç': 'c',
  };

  var text = value.toLowerCase();
  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  return text;
}

(double, String)? _parseQuantityAndUnit(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;

  final match =
      RegExp(r'([0-9]+(?:[,.][0-9]+)?)\s*([a-zA-Z]+)').firstMatch(text);
  if (match == null) return null;

  final quantity = _toDouble(match.group(1));
  final unit = match.group(2)?.toLowerCase();
  if (quantity == null || unit == null || unit.isEmpty) return null;

  return (quantity, unit);
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}
