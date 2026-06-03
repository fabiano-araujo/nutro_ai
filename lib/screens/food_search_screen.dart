import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/food_model.dart';
import '../models/Nutrient.dart';
import '../models/FoodRegion.dart';
import '../models/Portion.dart';
import '../models/FoodAllergen.dart';
import '../models/meal_model.dart';
import 'barcode_scanner_screen.dart';
import 'food_page.dart';
import '../i18n/app_localizations_extension.dart';
import '../helpers/scraper_helper.dart';
import '../helpers/webview_helper.dart';
import '../providers/food_history_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../util/app_constants.dart';
import '../services/auth_service.dart';
import '../services/favorite_food_service.dart';
import '../services/food_catalog_service.dart';
import '../services/ad_manager.dart';
import '../utils/product_barcode_utils.dart';
import '../utils/ui_utils.dart';
import '../widgets/native_ad_widget.dart';

class FoodSearchScreen extends StatefulWidget {
  final MealType? selectedMealType;

  const FoodSearchScreen({Key? key, this.selectedMealType}) : super(key: key);

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  static const String _fatSecretBarcodeDemoUrl =
      'https://platform.fatsecret.com/api-demo#barcode-api';
  static const Set<String> _fatSecretBarcodeMarkets = {
    'AR',
    'AU',
    'AT',
    'BY',
    'BE',
    'BR',
    'BG',
    'CA',
    'CL',
    'CN',
    'CO',
    'CR',
    'CZ',
    'DK',
    'EC',
    'EG',
    'EE',
    'FI',
    'FR',
    'DE',
    'HK',
    'IN',
    'ID',
    'IE',
    'IL',
    'IT',
    'JP',
    'KZ',
    'KR',
    'LV',
    'LT',
    'MY',
    'MX',
    'MD',
    'NL',
    'NZ',
    'NO',
    'PE',
    'PH',
    'PL',
    'PT',
    'RO',
    'RU',
    'SA',
    'SG',
    'ZA',
    'ES',
    'SE',
    'CH',
    'TW',
    'TR',
    'UA',
    'AE',
    'GB',
    'US',
    'VE',
  };
  static const Map<String, String> _barcodeMarketFallbackByLanguage = {
    'ar': 'AE',
    'de': 'DE',
    'en': 'US',
    'es': 'ES',
    'fr': 'FR',
    'id': 'ID',
    'it': 'IT',
    'ja': 'JP',
    'ko': 'KR',
    'nl': 'NL',
    'nb': 'NO',
    'no': 'NO',
    'pl': 'PL',
    'pt': 'BR',
    'ru': 'RU',
    'sv': 'SE',
    'tr': 'TR',
    'uk': 'UA',
    'zh': 'CN',
  };

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
  bool _activeSearchIsBarcode = false;
  bool _autoOpenBarcodeResult = false;
  bool _isOpeningBarcodeResult = false;
  bool _barcodeDemoSearchSubmitted = false;
  bool _barcodeCaptchaDetected = false;
  bool _barcodeCaptchaRetrySubmitted = false;
  bool _barcodeDemoTemporaryError = false;
  bool _isExtractingBarcodeDemoFood = false;
  Timer? _barcodeDemoExtractionTimer;
  int _barcodeDemoExtractionAttempts = 0;
  int _barcodeDemoConsecutiveErrors = 0;
  int? _barcodeDemoRetryMinutes;
  String? _pendingBarcode;
  String? _pendingBarcodeMarket;

  List<FavoriteFood> _serverRecents = [];
  bool _loadingServerRecents = true;
  List<FavoriteFood> _serverFrequents = [];
  bool _loadingServerFrequents = true;
  List<FavoriteFood> _serverFavorites = [];
  bool _loadingServerFavorites = true;

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
        if (mounted)
          setState(() {
            _loadingServerRecents = false;
            _loadingServerFrequents = false;
            _loadingServerFavorites = false;
          });
        return;
      }
      final svc = FavoriteFoodService(token: token);
      final results = await Future.wait([
        svc.getRecents(limit: 30),
        svc.getFrequents(limit: 30),
        svc.getFavorites(),
      ]);
      if (mounted)
        setState(() {
          _serverRecents = results[0];
          _loadingServerRecents = false;
          _serverFrequents = results[1];
          _loadingServerFrequents = false;
          _serverFavorites = results[2];
          _loadingServerFavorites = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingServerRecents = false;
          _loadingServerFrequents = false;
          _loadingServerFavorites = false;
        });
    }
  }

  @override
  void dispose() {
    _barcodeDemoExtractionTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    _scraperHelper.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) async {
    final searchQuery = query.trim();
    if (searchQuery.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _apiResults = [];
      _webResults = [];
      _isLoadingApi = true;
      _isLoadingWeb = !kIsWeb; // Only load web on mobile
      _activeSearchIsBarcode = false;
      _autoOpenBarcodeResult = false;
      _isOpeningBarcodeResult = false;
      _barcodeDemoSearchSubmitted = false;
      _barcodeCaptchaDetected = false;
      _barcodeCaptchaRetrySubmitted = false;
      _barcodeDemoTemporaryError = false;
      _isExtractingBarcodeDemoFood = false;
      _barcodeDemoConsecutiveErrors = 0;
      _barcodeDemoRetryMinutes = null;
      _pendingBarcode = null;
      _pendingBarcodeMarket = null;
    });

    // Search API
    _searchApi(searchQuery);

    // On mobile, also search via WebView
    if (!kIsWeb) {
      final url = _buildFatSecretSearchUrl(searchQuery);
      await _setWebViewSettings(WebViewHelper.getOptimizedSettings());
      await _scraperHelper.loadUrl(url);
    }
  }

  void _onBarcodeSubmitted(String rawBarcode) async {
    final barcode = _normalizeBarcode(rawBarcode);

    if (barcode == null) {
      UIUtils.showPrimarySnackBar(
        context,
        context.tr.translate('invalid_barcode_message'),
      );
      return;
    }

    _searchController.text = barcode;
    final marketCode = _getDeviceBarcodeMarketCode();
    debugPrint(
      '[BarcodeFoodFlow] FoodSearch: barcode_submitted '
      'raw="$rawBarcode" normalized=$barcode market=$marketCode',
    );

    setState(() {
      _isLoading = !kIsWeb;
      _isSearching = true;
      _apiResults = [];
      _webResults = [];
      _isLoadingApi = false;
      _isLoadingWeb = !kIsWeb;
      _activeSearchIsBarcode = true;
      _autoOpenBarcodeResult = true;
      _isOpeningBarcodeResult = false;
      _barcodeDemoSearchSubmitted = false;
      _barcodeCaptchaDetected = false;
      _barcodeCaptchaRetrySubmitted = false;
      _barcodeDemoTemporaryError = false;
      _isExtractingBarcodeDemoFood = false;
      _barcodeDemoConsecutiveErrors = 0;
      _barcodeDemoRetryMinutes = null;
      _pendingBarcode = barcode;
      _pendingBarcodeMarket = marketCode;
    });

    final savedFood = await FoodCatalogService.getFoodByBarcode(
      barcode: barcode,
      marketLocale: marketCode,
      language: '',
    );
    if (!mounted) return;

    if (savedFood != null) {
      debugPrint(
        '[BarcodeFoodFlow] FoodSearch: opening barcode result from server cache '
        'barcode=$barcode name="${savedFood.name}"',
      );
      _openFoodPageForSavedBarcodeFood(
        savedFood,
        catalogSource: 'barcode_cache',
      );
      return;
    }

    final openFoodFactsProduct =
        await FoodCatalogService.getOpenFoodFactsProductByBarcode(
      barcode: barcode,
    );
    if (!mounted) return;

    if (openFoodFactsProduct != null) {
      debugPrint(
        '[BarcodeFoodFlow] FoodSearch: Open Food Facts product found '
        'barcode=$barcode name="${openFoodFactsProduct.productName}"',
      );
      final resolvedFood = await FoodCatalogService.resolveOpenFoodFactsBarcode(
        product: openFoodFactsProduct,
        marketLocale: marketCode,
        language: '',
      );
      if (!mounted) return;

      _openFoodPageForSavedBarcodeFood(
        resolvedFood ??
            openFoodFactsProduct.toFood(
              marketLocale: marketCode,
              language: '',
            ),
        catalogSource: 'open_food_facts',
      );
      return;
    }

    debugPrint(
      '[BarcodeFoodFlow] FoodSearch: Open Food Facts not found, '
      'falling back to FatSecret barcode=$barcode',
    );

    if (kIsWeb) {
      setState(() {
        _isLoading = false;
        _isLoadingWeb = false;
      });
      return;
    }

    await _setWebViewSettings(WebViewHelper.getDefaultSettings());
    await _scraperHelper.loadUrl(
      _buildFatSecretBarcodeDemoUrl(cacheBust: true),
    );
  }

  String _buildFatSecretSearchUrl(String query) {
    return 'https://mobile.fatsecret.com.br/calorias-nutri%C3%A7%C3%A3o/search?q=${Uri.encodeComponent(query.trim())}';
  }

  String _buildFatSecretBarcodeDemoUrl({bool cacheBust = false}) {
    if (!cacheBust) return _fatSecretBarcodeDemoUrl;

    return 'https://platform.fatsecret.com/api-demo?nutro_retry=${DateTime.now().millisecondsSinceEpoch}#barcode-api';
  }

  String? _normalizeBarcode(String rawBarcode) {
    return ProductBarcodeUtils.normalizeUnknownProductBarcode(rawBarcode);
  }

  String _getDeviceBarcodeMarketCode() {
    final locale = Localizations.localeOf(context);
    final countryCode = locale.countryCode?.toUpperCase();
    final normalizedCountryCode = countryCode == 'UK' ? 'GB' : countryCode;

    if (normalizedCountryCode != null &&
        _fatSecretBarcodeMarkets.contains(normalizedCountryCode)) {
      return normalizedCountryCode;
    }

    return _barcodeMarketFallbackByLanguage[
            locale.languageCode.toLowerCase()] ??
        'US';
  }

  Future<void> _fillFatSecretBarcodeDemo(
    InAppWebViewController controller,
  ) async {
    final barcode = _pendingBarcode;
    if (barcode == null || barcode.isEmpty) {
      _finishBarcodeDemoLoad();
      return;
    }

    try {
      final shouldSubmit = !_barcodeDemoSearchSubmitted;
      _barcodeDemoSearchSubmitted = true;

      await controller.evaluateJavascript(
        source: _buildFillFatSecretBarcodeScript(
          barcode: barcode,
          marketCode: _pendingBarcodeMarket ?? _getDeviceBarcodeMarketCode(),
          submitSearch: shouldSubmit,
        ),
      );

      if (shouldSubmit) {
        _startBarcodeDemoExtractionPolling(controller);
      }
    } catch (e) {
      print('Error filling FatSecret barcode demo: $e');
    }

    _finishBarcodeDemoLoad();
  }

  String _buildFillFatSecretBarcodeScript({
    required String barcode,
    required String marketCode,
    required bool submitSearch,
  }) {
    final barcodeJson = jsonEncode(barcode);
    final marketJson = jsonEncode(marketCode);
    final submitSearchJson = jsonEncode(submitSearch);

    return '''
(function() {
  const targetBarcode = $barcodeJson;
  const targetMarket = $marketJson;
  const shouldSubmit = $submitSearchJson;

  function dispatch(element, eventName) {
    element.dispatchEvent(new Event(eventName, { bubbles: true }));
  }

  function setValue(element, value) {
    if (!element) return false;
    element.value = value;
    dispatch(element, 'input');
    dispatch(element, 'change');
    dispatch(element, 'keyup');
    return true;
  }

  try {
    if (window.location.hash !== '#barcode-api') {
      window.history.replaceState(null, '', '#barcode-api');
    }
  } catch (e) {}

  const barcodeTab = document.querySelector('#nav-barcode-tab');
  if (barcodeTab && !barcodeTab.classList.contains('active')) {
    barcodeTab.click();
  }

  const tabContent = document.querySelector('#nav-tabContent');
  if (tabContent) {
    tabContent.classList.remove('collapse');
    tabContent.style.display = 'block';
  }

  const barcodePane = document.querySelector('#barcode-api');
  if (barcodePane) {
    document.querySelectorAll('#nav-tabContent > .tab-pane').forEach(function(pane) {
      pane.classList.remove('active', 'show');
    });
    barcodePane.classList.add('active', 'show');
    barcodePane.style.display = 'block';
  }

  const market = document.querySelector('#barcode_market');
  const barcodeInput = document.querySelector('#barcode_number');
  const searchButton = document.querySelector('#barcode_search_button');
  let marketSet = false;
  let barcodeSet = false;
  let searchQueued = false;

  if (market) {
    const hasTargetMarket = Array.from(market.options).some(function(option) {
      return option.value === targetMarket;
    });
    if (hasTargetMarket) {
      marketSet = setValue(market, targetMarket);
    }
  }

  if (barcodeInput) {
    barcodeSet = setValue(barcodeInput, targetBarcode);
    setTimeout(function() {
      barcodeInput.scrollIntoView({ block: 'center' });
    }, 100);
  }

  if (shouldSubmit && marketSet && barcodeSet && searchButton) {
    searchQueued = true;
    setTimeout(function() {
      searchButton.click();
    }, 250);
  }

  return {
    marketSet: marketSet,
    barcodeSet: barcodeSet,
    searchQueued: searchQueued,
    targetMarket: targetMarket,
    targetBarcode: targetBarcode,
    hasMarketField: Boolean(market),
    hasBarcodeField: Boolean(barcodeInput),
    hasSearchButton: Boolean(searchButton)
  };
})();
''';
  }

  void _startBarcodeDemoExtractionPolling(InAppWebViewController controller) {
    _barcodeDemoExtractionTimer?.cancel();
    _barcodeDemoExtractionAttempts = 0;
    _barcodeDemoExtractionTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (timer) async {
        if (!mounted || !_activeSearchIsBarcode || _isOpeningBarcodeResult) {
          timer.cancel();
          return;
        }

        if (!_barcodeCaptchaDetected) {
          _barcodeDemoExtractionAttempts++;
        }

        if (_barcodeDemoExtractionAttempts > 35) {
          timer.cancel();
          return;
        }

        await _extractFatSecretBarcodeDemoFood(controller);
      },
    );
  }

  Future<void> _extractFatSecretBarcodeDemoFood(
    InAppWebViewController controller,
  ) async {
    if (_isExtractingBarcodeDemoFood) return;
    _isExtractingBarcodeDemoFood = true;

    try {
      final result = await controller.evaluateJavascript(
        source: _buildExtractFatSecretBarcodeDemoFoodScript(),
      );

      if (result == null) return;

      final rawJson = result.toString();
      if (rawJson.isEmpty || rawJson == 'null') return;

      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) return;

      if (decoded['temporaryErrorDetected'] == true) {
        await _handleBarcodeDemoTemporaryError(
          controller,
          Map<String, dynamic>.from(decoded),
        );
        return;
      }

      if (decoded['captchaDetected'] == true) {
        _setBarcodeCaptchaDetected(true);
        return;
      }

      final wasWaitingForCaptcha = _barcodeCaptchaDetected;
      if (wasWaitingForCaptcha) {
        _setBarcodeCaptchaDetected(false, waitingForResult: true);
      }

      if (decoded['ready'] != true) {
        final barcode = _pendingBarcode;
        final shouldSubmitSolvedCaptcha = wasWaitingForCaptcha ||
            (decoded['captchaSolved'] == true &&
                decoded['barcodeFormReady'] == true);
        if (shouldSubmitSolvedCaptcha &&
            !_barcodeCaptchaRetrySubmitted &&
            barcode != null &&
            barcode.isNotEmpty) {
          _barcodeCaptchaRetrySubmitted = true;
          _barcodeDemoExtractionAttempts = 0;
          await controller.evaluateJavascript(
            source: _buildFillFatSecretBarcodeScript(
              barcode: barcode,
              marketCode:
                  _pendingBarcodeMarket ?? _getDeviceBarcodeMarketCode(),
              submitSearch: true,
            ),
          );
        }
        return;
      }

      final food = _convertFatSecretBarcodeDemoDataToFood(
        Map<String, dynamic>.from(decoded),
      );

      if (food == null) return;

      _barcodeDemoConsecutiveErrors = 0;
      _openFoodPageForExtractedBarcodeFood(food);
    } catch (e) {
      print('Error extracting FatSecret barcode demo food: $e');
    } finally {
      _isExtractingBarcodeDemoFood = false;
    }
  }

  Future<void> _handleBarcodeDemoTemporaryError(
    InAppWebViewController controller,
    Map<String, dynamic> decoded,
  ) async {
    _barcodeDemoConsecutiveErrors++;
    _barcodeDemoExtractionTimer?.cancel();
    final retryMinutes = _readBarcodeDemoInt(decoded['temporaryRetryMinutes']);

    if (_barcodeDemoConsecutiveErrors >= 2) {
      if (!mounted) return;
      setState(() {
        _barcodeDemoTemporaryError = true;
        _barcodeCaptchaDetected = false;
        _barcodeDemoRetryMinutes = retryMinutes;
        _isLoading = false;
        _isLoadingWeb = false;
        _isLoadingApi = false;
      });
      return;
    }

    _barcodeDemoSearchSubmitted = false;
    _barcodeCaptchaDetected = false;
    _barcodeCaptchaRetrySubmitted = false;
    _barcodeDemoExtractionAttempts = 0;
    _barcodeDemoRetryMinutes = null;

    if (mounted) {
      setState(() {
        _barcodeDemoTemporaryError = false;
        _isLoading = true;
        _isLoadingWeb = true;
        _isLoadingApi = false;
      });
    }

    try {
      try {
        await controller.evaluateJavascript(
          source:
              "try { window.sessionStorage.clear(); window.localStorage.clear(); } catch (e) {}",
        );
        await InAppWebViewController.clearAllCache(includeDiskFiles: true);
      } catch (e) {
        print('Error clearing FatSecret barcode demo cache: $e');
      }

      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(_buildFatSecretBarcodeDemoUrl(cacheBust: true)),
        ),
      );
    } catch (e) {
      print('Error reloading FatSecret barcode demo: $e');
      if (!mounted) return;
      setState(() {
        _barcodeDemoTemporaryError = true;
        _isLoading = false;
        _isLoadingWeb = false;
        _isLoadingApi = false;
      });
    }
  }

  void _setBarcodeCaptchaDetected(
    bool detected, {
    bool waitingForResult = false,
  }) {
    if (!mounted) return;

    if (detected) {
      _barcodeDemoExtractionAttempts = 0;
      _barcodeCaptchaRetrySubmitted = false;
    }

    if (_barcodeCaptchaDetected == detected &&
        (!waitingForResult || _isLoadingWeb)) {
      return;
    }

    setState(() {
      _barcodeCaptchaDetected = detected;
      if (detected) {
        _isLoading = false;
        _isLoadingWeb = false;
        _isLoadingApi = false;
      } else if (waitingForResult) {
        _isLoading = true;
        _isLoadingWeb = true;
      }
    });
  }

  String _buildExtractFatSecretBarcodeDemoFoodScript() {
    return '''
(function() {
  function clean(value) {
    return (value || '').replace(/\\s+/g, ' ').trim();
  }

  function text(selector, base) {
    const element = (base || document).querySelector(selector);
    return element ? clean(element.innerText || element.textContent) : null;
  }

  function isVisible(element) {
    if (!element) return false;
    const style = window.getComputedStyle(element);
    if (
      style.display === 'none' ||
      style.visibility === 'hidden' ||
      style.opacity === '0'
    ) {
      return false;
    }
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function captchaResponseValue() {
    const captchaResponse = document.querySelector(
      'textarea[name="g-recaptcha-response"], #g-recaptcha-response'
    );
    return captchaResponse ? clean(captchaResponse.value) : '';
  }

  function isCaptchaSolved() {
    return captchaResponseValue().length > 0;
  }

  function isBarcodeFormReady() {
    const market = document.querySelector('#barcode_market');
    const barcodeInput = document.querySelector('#barcode_number');
    const searchButton = document.querySelector('#barcode_search_button');
    return Boolean(
      market &&
      clean(market.value).length > 0 &&
      barcodeInput &&
      clean(barcodeInput.value).length > 0 &&
      searchButton
    );
  }

  function detectCaptcha() {
    if (isCaptchaSolved()) {
      return false;
    }

    const captchaFrames = Array.from(document.querySelectorAll('iframe'))
      .some((frame) => {
        const source = [
          frame.getAttribute('src') || '',
          frame.getAttribute('title') || '',
          frame.getAttribute('name') || ''
        ].join(' ');
        return /recaptcha|captcha/i.test(source) && isVisible(frame);
      });
    const captchaWidgets = Array.from(
      document.querySelectorAll('.g-recaptcha, [data-sitekey]')
    ).some(isVisible);
    const bodyText = clean(document.body ? document.body.innerText : '');
    const captchaText = /n[aã]o sou um rob[oô]|i'?m not a robot|not a robot|recaptcha/i
      .test(bodyText);

    return captchaFrames || captchaWidgets || captchaText;
  }

  function detectTemporaryError() {
    const bodyText = clean(document.body ? document.body.innerText : '');
    const retryMatch = bodyText.match(/try again in\\s+(\\d+)\\s+minutes?/i);
    const retryMinutes = retryMatch ? Number(retryMatch[1]) : null;

    if (/form was expired or invalid|form expired|expired or invalid/i.test(bodyText)) {
      return { type: 'form_expired', retryMinutes: retryMinutes };
    }
    if (/exceeded our request allowance|request allowance|try again in\\s+\\d+\\s+minutes/i.test(bodyText)) {
      return { type: 'rate_limited', retryMinutes: retryMinutes };
    }
    if (/unexpected error occurred/i.test(bodyText)) {
      return { type: 'unexpected', retryMinutes: retryMinutes };
    }
    return null;
  }

  function parseNumber(value) {
    const match = clean(value).replace(',', '.').match(/-?\\d+(?:\\.\\d+)?/);
    return match ? Number(match[0]) : null;
  }

  function normalizeLabel(value) {
    return clean(value)
      .toLowerCase()
      .replace(/\\*/g, '')
      .replace(/\\s+/g, ' ');
  }

  function findNutrientValue(nutritionFacts, labels) {
    const wanted = labels.map(normalizeLabel);
    const labelElements = Array.from(
      nutritionFacts.querySelectorAll('.nutrient.left, .nutrient.black.left, .nutrient.sub.left')
    );

    for (const labelElement of labelElements) {
      const label = normalizeLabel(labelElement.innerText || labelElement.textContent);
      if (!wanted.some((candidate) => label === candidate || label.includes(candidate))) {
        continue;
      }

      let valueElement = labelElement.nextElementSibling;
      while (
        valueElement &&
        !(valueElement.classList.contains('value') && valueElement.classList.contains('left'))
      ) {
        valueElement = valueElement.nextElementSibling;
      }

      return valueElement
        ? parseNumber(valueElement.innerText || valueElement.textContent)
        : null;
    }

    return null;
  }

  function findAddedSugars(nutritionFacts) {
    const element = Array.from(nutritionFacts.querySelectorAll('.nutrient.left'))
      .find((item) => /added sugars/i.test(clean(item.innerText || item.textContent)));
    return element ? parseNumber(element.innerText || element.textContent) : null;
  }

  function parseMacroBreakdown(panel) {
    function item(selector) {
      const element = panel.querySelector(selector);
      if (!element) return null;

      const textValue = clean(element.innerText || element.textContent);
      const percent = parseNumber(textValue.match(/\\d+%/)?.[0] || '');
      const amount = parseNumber(element.querySelector('.fw-bold')?.innerText || textValue);
      return { percent: percent, amount: amount, text: textValue };
    }

    return {
      fat: item('li.fat'),
      carbs: item('li.carb'),
      protein: item('li.protein')
    };
  }

  function parseNutrition(panel) {
    const nutritionFacts = panel.querySelector('.nutrition_facts');
    if (!nutritionFacts) return null;

    return {
      servingSize: text('.serving_size_value', nutritionFacts),
      calories: parseNumber(text('.hero_value', nutritionFacts)),
      fat: findNutrientValue(nutritionFacts, ['Total Fat']),
      saturatedFat: findNutrientValue(nutritionFacts, ['Saturated Fat']),
      transFat: findNutrientValue(nutritionFacts, ['Trans Fat']),
      polyunsaturatedFat: findNutrientValue(nutritionFacts, ['Polyunsaturated Fat']),
      monounsaturatedFat: findNutrientValue(nutritionFacts, ['Monounsaturated Fat']),
      cholesterol: findNutrientValue(nutritionFacts, ['Cholesterol']),
      sodium: findNutrientValue(nutritionFacts, ['Sodium']),
      carbohydrate: findNutrientValue(nutritionFacts, ['Total Carbohydrate']),
      dietaryFiber: findNutrientValue(nutritionFacts, ['Dietary Fiber']),
      sugars: findNutrientValue(nutritionFacts, ['Sugars']),
      addedSugars: findAddedSugars(nutritionFacts),
      protein: findNutrientValue(nutritionFacts, ['Protein']),
      vitaminD: findNutrientValue(nutritionFacts, ['Vitamin D']),
      calcium: findNutrientValue(nutritionFacts, ['Calcium']),
      iron: findNutrientValue(nutritionFacts, ['Iron']),
      potassium: findNutrientValue(nutritionFacts, ['Potassium'])
    };
  }

  function parseClaims(root) {
    const claims = {
      freeFrom: [],
      mayContain: [],
      suitableFor: [],
      mayNotBeSuitableFor: []
    };

    const rows = Array.from(root.querySelectorAll('.row'));
    for (const row of rows) {
      const rowText = clean(row.innerText || row.textContent);
      const items = Array.from(row.querySelectorAll('li'))
        .map((item) => clean(item.innerText || item.textContent))
        .filter(Boolean);

      if (/this food is free from/i.test(rowText)) {
        claims.freeFrom.push(...items);
      } else if (/this food may contain/i.test(rowText)) {
        claims.mayContain.push(...items);
      } else if (/this food is suitable for/i.test(rowText)) {
        const value = rowText
          .replace(/this food is suitable for/i, '')
          .replace(/diets?/i, '');
        if (clean(value)) claims.suitableFor.push(clean(value));
      } else if (/this food may not be suitable for/i.test(rowText)) {
        const value = rowText
          .replace(/this food may not be suitable for/i, '')
          .replace(/diets?/i, '');
        if (clean(value)) claims.mayNotBeSuitableFor.push(clean(value));
      }
    }

    return claims;
  }

  function readFoodId() {
    const input =
      document.querySelector('.barcode-search-result input[name="FoodID"]') ||
      document.querySelector('.barcode-results input[name="FoodID"]') ||
      document.querySelector('form[action="/api-demo/foods-get"] input[name="FoodID"]') ||
      document.querySelector('input[name="FoodID"]');
    return input ? parseNumber(input.value) : null;
  }

  function openFirstBarcodeResultIfNeeded() {
    const form =
      document.querySelector('.barcode-search-result form[action="/api-demo/foods-get"]') ||
      document.querySelector('.barcode-results form[action="/api-demo/foods-get"]') ||
      document.querySelector('form[action="/api-demo/foods-get"]');
    if (!form || form.dataset.codexOpened === 'true') return false;

    form.dataset.codexOpened = 'true';
    const trigger = form.querySelector('[data-submit-trigger="true"]') ||
      form.querySelector('a') ||
      form.querySelector('button');
    if (trigger) {
      trigger.click();
      return true;
    }

    form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    return true;
  }

  const root =
    document.querySelector('.demo-item-content') ||
    document.querySelector('.demo-item-display') ||
    document.querySelector('.barcode-results');

  if (detectCaptcha()) {
    return JSON.stringify({
      barcodeFormReady: isBarcodeFormReady(),
      captchaDetected: true,
      captchaSolved: false,
      ready: false,
      temporaryErrorDetected: false
    });
  }

  const temporaryError = detectTemporaryError();
  if (temporaryError) {
    return JSON.stringify({
      barcodeFormReady: isBarcodeFormReady(),
      captchaDetected: false,
      captchaSolved: isCaptchaSolved(),
      ready: false,
      temporaryErrorDetected: true,
      temporaryErrorType: temporaryError.type,
      temporaryRetryMinutes: temporaryError.retryMinutes
    });
  }

  if (!root || !root.querySelector('.nutrition_facts')) {
    const openedResult = openFirstBarcodeResultIfNeeded();
    return JSON.stringify({
      barcodeFormReady: isBarcodeFormReady(),
      captchaDetected: false,
      captchaSolved: isCaptchaSolved(),
      openedResult: openedResult,
      ready: false,
      temporaryErrorDetected: false
    });
  }

  const panels = Array.from(root.querySelectorAll('.accordion-collapse'))
    .filter((panel) => panel.querySelector('.nutrition_facts'));
  const servingPanels = panels.length ? panels : [root];

  const servings = servingPanels
    .map((panel) => ({
      active: panel.classList.contains('show') || panels.length === 0,
      description: text('.serving_size_value', panel) ||
        text('#FoodServingOptions .bold', root),
      summary: clean(panel.querySelector('.border.bg-light')?.innerText || ''),
      macroBreakdown: parseMacroBreakdown(panel),
      nutrients: parseNutrition(panel)
    }))
    .filter((serving) => serving.nutrients);

  if (!servings.length) {
    return JSON.stringify({
      barcodeFormReady: isBarcodeFormReady(),
      captchaDetected: false,
      captchaSolved: isCaptchaSolved(),
      ready: false,
      temporaryErrorDetected: false
    });
  }
  servings.sort((a, b) => Number(b.active) - Number(a.active));

  const result = {
    barcodeFormReady: isBarcodeFormReady(),
    captchaDetected: false,
    captchaSolved: isCaptchaSolved(),
    foodId: readFoodId(),
    brand: text('.brand-name', root),
    name: text('.food-name', root),
    ready: true,
    selectedServing: text('#FoodServingOptions .bold', root),
    claims: parseClaims(root),
    servings: servings,
    temporaryErrorDetected: false
  };

  return JSON.stringify(result);
})();
''';
  }

  Food? _convertFatSecretBarcodeDemoDataToFood(Map<String, dynamic> data) {
    final name = _readBarcodeDemoString(data['name']);
    if (name == null || name.isEmpty) return null;

    final foodId = _readBarcodeDemoInt(data['foodId']);
    final brand = _readBarcodeDemoString(data['brand']);
    final claims = data['claims'] is Map
        ? Map<String, dynamic>.from(data['claims'] as Map)
        : <String, dynamic>{};
    final servings = (data['servings'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];

    if (servings.isEmpty) return null;

    final nutrients = <Nutrient>[];
    for (final serving in servings) {
      final nutrientData = serving['nutrients'] is Map
          ? Map<String, dynamic>.from(serving['nutrients'] as Map)
          : <String, dynamic>{};
      final parsedServing = _parseBarcodeDemoServingSize(
        _readBarcodeDemoString(serving['description']) ??
            _readBarcodeDemoString(nutrientData['servingSize']),
      );

      nutrients.add(
        Nutrient(
          idFood: 0,
          servingSize: parsedServing['size'] as double,
          servingUnit: parsedServing['unit'] as String,
          calories: _readBarcodeDemoDouble(nutrientData['calories']),
          carbohydrate: _readBarcodeDemoDouble(nutrientData['carbohydrate']),
          protein: _readBarcodeDemoDouble(nutrientData['protein']),
          fat: _readBarcodeDemoDouble(nutrientData['fat']),
          saturatedFat: _readBarcodeDemoDouble(nutrientData['saturatedFat']),
          transFat: _readBarcodeDemoDouble(nutrientData['transFat']),
          polyunsaturatedFat:
              _readBarcodeDemoDouble(nutrientData['polyunsaturatedFat']),
          monounsaturatedFat:
              _readBarcodeDemoDouble(nutrientData['monounsaturatedFat']),
          cholesterol: _readBarcodeDemoDouble(nutrientData['cholesterol']),
          sodium: _readBarcodeDemoDouble(nutrientData['sodium']),
          potassium: _readBarcodeDemoDouble(nutrientData['potassium']),
          dietaryFiber: _readBarcodeDemoDouble(nutrientData['dietaryFiber']),
          sugars: _readBarcodeDemoDouble(nutrientData['sugars']),
          addedSugars: _readBarcodeDemoDouble(nutrientData['addedSugars']),
          vitaminD: _readBarcodeDemoDouble(nutrientData['vitaminD']),
          calcium: _readBarcodeDemoDouble(nutrientData['calcium']),
          iron: _readBarcodeDemoDouble(nutrientData['iron']),
        ),
      );
    }

    final baseCalories = nutrients.first.calories;
    final portions = <Portion>[];
    for (var index = 0; index < servings.length; index++) {
      final serving = servings[index];
      final nutrientData = serving['nutrients'] is Map
          ? Map<String, dynamic>.from(serving['nutrients'] as Map)
          : <String, dynamic>{};
      final description = _readBarcodeDemoString(serving['description']) ??
          _readBarcodeDemoString(nutrientData['servingSize']) ??
          nutrients[index].servingUnit;
      final servingCalories = nutrients[index].calories;
      final proportion = baseCalories != null &&
              baseCalories > 0 &&
              servingCalories != null &&
              servingCalories > 0
          ? servingCalories / baseCalories
          : index == 0
              ? 1.0
              : 1.0;

      portions.add(
        Portion(
          idFoodRegion: 0,
          proportion: proportion,
          description: description,
        ),
      );
    }

    final locale = Localizations.localeOf(context);

    return Food(
      name: name,
      brand: brand,
      idFatsecret: foodId,
      isVegetarian: _readBarcodeDemoDietStatus(claims, 'vegetarian'),
      isVegan: _readBarcodeDemoDietStatus(claims, 'vegan'),
      nutrients: nutrients,
      foodRegions: [
        FoodRegion(
          regionCode: _pendingBarcodeMarket ?? _getDeviceBarcodeMarketCode(),
          languageCode: locale.languageCode,
          idFood: 0,
          translation: name,
          portions: portions,
        ),
      ],
      foodAllergens: _convertBarcodeDemoClaimsToAllergens(claims),
    );
  }

  String? _readBarcodeDemoString(dynamic value) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text == null || text.isEmpty || text == '-') return null;
    return text;
  }

  double? _readBarcodeDemoDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final normalized = value.toString().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  int? _readBarcodeDemoInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final match = RegExp(r'\d+').firstMatch(value.toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  Map<String, dynamic> _parseBarcodeDemoServingSize(String? servingSize) {
    final fallback = <String, dynamic>{'size': 100.0, 'unit': 'g'};
    final text = _readBarcodeDemoString(servingSize);
    if (text == null) return fallback;

    final match = RegExp(r'^(\d+(?:[.,]\d+)?(?:/\d+(?:[.,]\d+)?)?)\s*(.*)$')
        .firstMatch(text);
    if (match == null) return {'size': 1.0, 'unit': text};

    final rawSize = match.group(1)?.replaceAll(',', '.');
    final unit = (match.group(2)?.trim().isNotEmpty == true)
        ? match.group(2)!.trim()
        : 'unidade';

    double size = 1.0;
    if (rawSize != null && rawSize.contains('/')) {
      final parts = rawSize.split('/');
      final numerator = double.tryParse(parts[0]) ?? 1.0;
      final denominator = double.tryParse(parts[1]) ?? 1.0;
      size = denominator == 0 ? 1.0 : numerator / denominator;
    } else {
      size = double.tryParse(rawSize ?? '') ?? 1.0;
    }

    return {'size': size, 'unit': unit};
  }

  List<FoodAllergen> _convertBarcodeDemoClaimsToAllergens(
    Map<String, dynamic> claims,
  ) {
    final allergens = <FoodAllergen>[];

    void addAll(dynamic values, AllergenStatus status) {
      if (values is! List) return;
      for (final value in values) {
        final allergen = _parseBarcodeDemoAllergen(value);
        if (allergen == null) continue;
        allergens.add(
          FoodAllergen(
            idFood: 0,
            allergen: allergen,
            status: status,
          ),
        );
      }
    }

    addAll(claims['freeFrom'], AllergenStatus.free);
    addAll(claims['mayContain'], AllergenStatus.mayContain);

    return allergens;
  }

  AllergenType? _parseBarcodeDemoAllergen(dynamic value) {
    final text = value?.toString().toLowerCase() ?? '';

    if (text.contains('shellfish')) return AllergenType.shellfish;
    if (text.contains('peanut')) return AllergenType.peanuts;
    if (text.contains('sesame')) return AllergenType.sesame;
    if (text.contains('gluten')) return AllergenType.gluten;
    if (text.contains('lactose')) return AllergenType.lactose;
    if (text.contains('milk')) return AllergenType.milk;
    if (text.contains('nuts')) return AllergenType.nuts;
    if (text.contains('fish')) return AllergenType.fish;
    if (text.contains('egg')) return AllergenType.egg;
    if (text.contains('soy')) return AllergenType.soy;

    return null;
  }

  String? _readBarcodeDemoDietStatus(
    Map<String, dynamic> claims,
    String diet,
  ) {
    bool containsDiet(dynamic values) {
      if (values is! List) return false;
      return values.any(
        (value) => value.toString().toLowerCase().contains(diet),
      );
    }

    if (containsDiet(claims['suitableFor'])) return 'true';
    if (containsDiet(claims['mayNotBeSuitableFor'])) return 'may_not';
    return null;
  }

  void _openFoodPageForExtractedBarcodeFood(Food food) {
    if (!mounted || _isOpeningBarcodeResult) return;
    _openBarcodeFoodPage(food, catalogSource: 'fatsecret');
  }

  void _openFoodPageForSavedBarcodeFood(
    Food food, {
    String? catalogSource,
  }) {
    if (!mounted || _isOpeningBarcodeResult) return;
    _openBarcodeFoodPage(food, catalogSource: catalogSource);
  }

  void _openBarcodeFoodPage(
    Food food, {
    String? catalogSource,
  }) {
    _barcodeDemoExtractionTimer?.cancel();
    _isOpeningBarcodeResult = true;
    _autoOpenBarcodeResult = false;
    _barcodeCaptchaDetected = false;
    _barcodeCaptchaRetrySubmitted = false;
    _barcodeDemoTemporaryError = false;
    _barcodeDemoConsecutiveErrors = 0;
    _barcodeDemoRetryMinutes = null;
    debugPrint(
      '[BarcodeFoodFlow] FoodSearch: opening FoodPage '
      'source=${catalogSource ?? 'unknown'} barcode=$_pendingBarcode '
      'name="${food.name}"',
    );

    setState(() {
      _isLoading = false;
      _isLoadingWeb = false;
      _isLoadingApi = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodPage(
          food: food,
          selectedMealType: _selectedMealType,
          barcode: _pendingBarcode,
          barcodeMarket: _pendingBarcodeMarket,
          catalogSource: catalogSource,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        _isOpeningBarcodeResult = false;
      });
    });
  }

  Future<void> _setWebViewSettings(InAppWebViewSettings settings) async {
    final controller = WebViewHelper.getInAppWebViewController();
    if (controller == null) return;
    try {
      await controller.setSettings(settings: settings);
    } catch (e) {
      print('Error updating WebView settings: $e');
    }
  }

  Future<void> _openBarcodeScanner() async {
    FocusScope.of(context).unfocus();

    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || barcode == null || barcode.isEmpty) return;

    _onBarcodeSubmitted(barcode);
  }

  String? _buildFatSecretFoodUrl(dynamic link) {
    final rawLink = link?.toString().trim();
    if (rawLink == null || rawLink.isEmpty) return null;

    if (rawLink.startsWith('http://') || rawLink.startsWith('https://')) {
      return _toMobileFatSecretUrl(rawLink);
    }

    final path = rawLink.startsWith('/') ? rawLink : '/$rawLink';
    return 'https://mobile.fatsecret.com.br$path';
  }

  String _toMobileFatSecretUrl(String url) {
    return url
        .replaceFirst(
            'https://www.fatsecret.com.br', 'https://mobile.fatsecret.com.br')
        .replaceFirst(
            'http://www.fatsecret.com.br', 'https://mobile.fatsecret.com.br')
        .replaceFirst(
            'https://foods.fatsecret.com', 'https://mobile.fatsecret.com')
        .replaceFirst(
            'http://foods.fatsecret.com', 'https://mobile.fatsecret.com')
        .replaceFirst(
            'https://www.fatsecret.com', 'https://mobile.fatsecret.com')
        .replaceFirst(
            'http://www.fatsecret.com', 'https://mobile.fatsecret.com');
  }

  Future<bool> _openFatSecretDetailIfLoaded(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (!_activeSearchIsBarcode || _isOpeningBarcodeResult || url == null) {
      return false;
    }

    try {
      final hasNutritionFacts = await controller.evaluateJavascript(
        source: 'document.querySelector(".nutrition_facts") !== null',
      );

      if (hasNutritionFacts != true) return false;

      final foodName = await controller.evaluateJavascript(
        source:
            'document.querySelector(".page-title h1")?.innerText?.trim() || ""',
      );

      _openFoodPageForFatSecretUrl(
        _toMobileFatSecretUrl(url.toString()),
        fallbackName: foodName?.toString(),
      );
      return true;
    } catch (e) {
      print('Error checking FatSecret detail page: $e');
      return false;
    }
  }

  void _openFoodPageForFatSecretUrl(
    String foodUrl, {
    String? fallbackName,
  }) {
    if (!mounted || _isOpeningBarcodeResult) return;

    _barcodeDemoExtractionTimer?.cancel();
    _isOpeningBarcodeResult = true;
    _autoOpenBarcodeResult = false;
    _barcodeCaptchaDetected = false;
    _barcodeCaptchaRetrySubmitted = false;
    _barcodeDemoTemporaryError = false;
    _barcodeDemoConsecutiveErrors = 0;
    _barcodeDemoRetryMinutes = null;

    final foodName = (fallbackName != null && fallbackName.trim().isNotEmpty)
        ? fallbackName.trim()
        : context.tr.translate('barcode');
    debugPrint(
      '[BarcodeFoodFlow] FoodSearch: opening FatSecret FoodPage '
      'barcode=$_pendingBarcode url=$foodUrl name="$foodName"',
    );

    setState(() {
      _isLoading = false;
      _isLoadingWeb = false;
      _isLoadingApi = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodPage(
          food: Food(name: foodName),
          foodUrl: foodUrl,
          selectedMealType: _selectedMealType,
          barcode: _pendingBarcode,
          barcodeMarket: _pendingBarcodeMarket,
          catalogSource: 'fatsecret',
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        _isOpeningBarcodeResult = false;
      });
    });
  }

  void _finishBarcodeDemoLoad() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isLoadingWeb = false;
    });
  }

  Future<void> _searchApi(String query) async {
    try {
      // Get device locale
      final locale = Localizations.localeOf(context);
      final languageCode = locale.languageCode; // e.g., "pt", "en", "es"
      final regionCode =
          locale.countryCode ?? languageCode.toUpperCase(); // e.g., "BR", "US"

      final uri = Uri.parse(
          '${AppConstants.DIET_API_BASE_URL}/food/search?q=${Uri.encodeComponent(query)}&region=$regionCode&language=&limit=${kIsWeb ? 20 : 3}&index=0');

      print('Searching API: $uri');
      final response = await http.get(uri);
      print('API response status: ${response.statusCode}');
      print(
          'API response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Parsed ${data.length} items from API');
        final List<Food> foods =
            data.map((item) => _convertApiResultToFood(item)).toList();

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
    final allergenList = foodData?['food_allergen'] is List
        ? (foodData!['food_allergen'] as List<dynamic>)
            .whereType<Map>()
            .map((item) =>
                FoodAllergen.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <FoodAllergen>[];
    final nutrientData = nutrientList.isNotEmpty
        ? nutrientList.first as Map<String, dynamic>?
        : null;

    final calories = nutrientData != null
        ? (double.tryParse(nutrientData['calories']?.toString() ?? '0') ?? 0.0)
        : 0.0;
    final protein = nutrientData != null
        ? (double.tryParse(nutrientData['protein']?.toString() ?? '0') ?? 0.0)
        : 0.0;
    final carbs = nutrientData != null
        ? (double.tryParse(nutrientData['carbohydrate']?.toString() ?? '0') ??
            0.0)
        : 0.0;
    final fat = nutrientData != null
        ? (double.tryParse(nutrientData['fat']?.toString() ?? '0') ?? 0.0)
        : 0.0;

    return Food(
      id: foodData?['id'],
      name: data['translation'] ?? foodData?['name'] ?? 'Unknown',
      brand: foodData?['brand'],
      photo: foodData?['photo'],
      idFatsecret: foodData?['id_fatsecret'],
      isVegetarian: foodData?['is_vegetarian']?.toString(),
      isVegan: foodData?['is_vegan']?.toString(),
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
          portions: portions
              .map((p) => Portion(
                    idFoodRegion: 0,
                    description: p['description'] ?? '',
                    proportion:
                        double.tryParse(p['proportion']?.toString() ?? '1') ??
                            1.0,
                  ))
              .toList(),
        ),
      ],
      foodAllergens: allergenList,
    );
  }

  Future<void> _extractFoodData() async {
    await _scraperHelper.extractContent(
      script: ScraperHelper.getFatSecretSearchResultsScript(),
      callback: (data) {
        if (!mounted) return;

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

            if (_activeSearchIsBarcode &&
                _autoOpenBarcodeResult &&
                results.length == 1) {
              final foodUrl = _buildFatSecretFoodUrl(results.first['link']);
              if (foodUrl != null) {
                _openFoodPageForFatSecretUrl(
                  foodUrl,
                  fallbackName: results.first['nome']?.toString(),
                );
              }
            }
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
    final showBarcodeWebView = _activeSearchIsBarcode && !kIsWeb;
    final barcodeWebViewHeight = MediaQuery.of(context).size.height * 0.5;

    final tabBar = TabBar(
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
      dividerColor: isDarkMode ? Color(0xFF48484A) : Color(0xFFD1D1D6),
      dividerHeight: 1,
      tabs: [
        Tab(text: 'Frequentes'),
        Tab(text: context.tr.translate('recent')),
        Tab(text: context.tr.translate('favorites')),
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          if (showBarcodeWebView)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: barcodeWebViewHeight,
              child: _buildFatSecretWebView(visible: true),
            )
          else
            Positioned.fill(
              child: _buildFatSecretWebView(visible: false),
            ),
          Positioned(
            top: showBarcodeWebView ? barcodeWebViewHeight : 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: backgroundColor,
              child: SafeArea(
                top: !showBarcodeWebView,
                bottom: false,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        backgroundColor: backgroundColor,
                        elevation: 0,
                        floating: true,
                        snap: true,
                        pinned: false,
                        primary: false,
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: _selectedMealType != null
                            ? DropdownButton<MealType>(
                                value: _selectedMealType,
                                underline: SizedBox.shrink(),
                                isDense: true,
                                dropdownColor: isDarkMode
                                    ? AppTheme.darkCardColor
                                    : Colors.white,
                                icon: Icon(Icons.arrow_drop_down,
                                    color: textColor, size: 24),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
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
                                            style: TextStyle(fontSize: 20)),
                                        SizedBox(width: 8),
                                        Text(option.name,
                                            style: TextStyle(fontSize: 20)),
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
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? textColor.withValues(alpha: 0.15)
                                        : textColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(80),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    keyboardType: TextInputType.text,
                                    textInputAction: TextInputAction.search,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: context.tr
                                          .translate('what_did_you_eat'),
                                      hintStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
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
                              if (!kIsWeb) ...[
                                SizedBox(width: 10),
                                _buildBarcodeScanButton(),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (!_isSearching)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarPersistentHeaderDelegate(
                            backgroundColor: backgroundColor,
                            tabBar: tabBar,
                          ),
                        ),
                    ];
                  },
                  body: _isSearching
                      ? _buildSearchResults(
                          isDarkMode, textColor, secondaryTextColor, cardColor)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildServerFrequentList(isDarkMode, textColor,
                                secondaryTextColor, cardColor),
                            _buildServerRecentList(isDarkMode, textColor,
                                secondaryTextColor, cardColor),
                            _buildServerFavoritesList(isDarkMode, textColor,
                                secondaryTextColor, cardColor),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFatSecretWebView({required bool visible}) {
    return IgnorePointer(
      ignoring: !visible,
      child: Opacity(
        opacity: visible ? 1.0 : 0.0,
        child: Container(
          color: Colors.white,
          child: InAppWebView(
            initialSettings: WebViewHelper.getOptimizedSettings(),
            onWebViewCreated: _scraperHelper.onWebViewCreated,
            onLoadStop: (controller, url) async {
              _scraperHelper.onLoadFinished(controller, url);
              // Wait a bit for the page to fully render.
              await Future.delayed(Duration(milliseconds: 500));
              if (_activeSearchIsBarcode) {
                await _fillFatSecretBarcodeDemo(controller);
                return;
              }
              final opened = await _openFatSecretDetailIfLoaded(
                controller,
                url,
              );
              if (opened) return;
              await _extractFoodData();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeScanButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: context.tr.translate('barcode_scanner_title'),
      child: Material(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(80),
        child: InkWell(
          borderRadius: BorderRadius.circular(80),
          onTap: _openBarcodeScanner,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              Icons.qr_code_scanner,
              color: colorScheme.onPrimary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDarkMode, Color textColor,
      Color secondaryTextColor, Color cardColor) {
    final bool hasApiResults = _apiResults.isNotEmpty;
    final bool hasWebResults = _webResults.isNotEmpty;
    final bool isStillLoading = _isLoading || _isLoadingApi || _isLoadingWeb;
    final barcodeTemporaryErrorMessage = _barcodeDemoRetryMinutes == null
        ? context.tr.translate('barcode_temporary_error_message')
        : context.tr
            .translate('barcode_temporary_error_message_minutes')
            .replaceAll('{minutes}', _barcodeDemoRetryMinutes.toString());

    if (_activeSearchIsBarcode && _barcodeDemoTemporaryError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: secondaryTextColor.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr.translate('barcode_temporary_error_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                barcodeTemporaryErrorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeSearchIsBarcode && _barcodeCaptchaDetected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 56,
                color: secondaryTextColor.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr.translate('barcode_captcha_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr.translate('barcode_captcha_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          ..._buildApiResultsWithAd(
            isDarkMode,
            textColor,
            secondaryTextColor,
            cardColor,
          ),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
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

  // Constrói os cards de resultado intercalando um anúncio nativo após o 5º item.
  // Só insere o ad se houver mais de 5 resultados e ads estiverem disponíveis.
  List<Widget> _buildApiResultsWithAd(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
  ) {
    const int adPosition = 5;
    final widgets = <Widget>[];
    final showAdSlot = !AdManager.adsBlocked && _apiResults.length > adPosition;

    for (var i = 0; i < _apiResults.length; i++) {
      widgets.add(_buildApiFoodCard(
        _apiResults[i],
        isDarkMode,
        textColor,
        secondaryTextColor,
        cardColor,
      ));
      if (showAdSlot && i == adPosition - 1) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: NativeAdWidget(
            adUnitId: AdManager.nativeSearchAdUnitId,
          ),
        ));
      }
    }
    return widgets;
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
        final foodUrl = _buildFatSecretFoodUrl(item['link']);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodPage(
              food: food,
              foodUrl: foodUrl,
              selectedMealType: _selectedMealType,
              catalogSource: 'fatsecret',
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
            Icon(Icons.history,
                size: 64, color: secondaryTextColor.withValues(alpha: 0.5)),
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
        return _buildFoodCard(
            food, isDarkMode, textColor, secondaryTextColor, cardColor);
      },
    );
  }

  Widget _buildServerFavoritesList(bool isDarkMode, Color textColor,
      Color secondaryTextColor, Color cardColor) {
    if (_loadingServerFavorites) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_serverFavorites.isEmpty) {
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
      itemCount: _serverFavorites.length,
      itemBuilder: (context, index) {
        final fav = _serverFavorites[index];
        final food = Food(
          name: fav.name,
          emoji: fav.emoji ?? '🍽️',
          nutrients: [
            Nutrient(
              idFood: 0,
              servingSize: fav.baseAmount,
              servingUnit: fav.baseUnit,
              calories: fav.calories.toDouble(),
              protein: fav.protein,
              carbohydrate: fav.carbs,
              fat: fav.fat,
            ),
          ],
          foodRegions: [],
        );
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
            Icon(Icons.trending_up,
                size: 64, color: secondaryTextColor.withValues(alpha: 0.5)),
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
    final historyProvider =
        Provider.of<FoodHistoryProvider>(context, listen: false);
    historyProvider.addToRecents(food);
    historyProvider.incrementFrequency(food);

    // Get meal name
    final option = DailyMealsProvider.getMealTypeOption(mealType);

    // Show success message
    UIUtils.showPrimarySnackBar(
      context,
      '${food.name} adicionado ao ${option.name}',
    );

    // Conta + tenta mostrar intersticial após N refeições (sem await — fire-and-forget)
    AdManager.notifyMealRegistered();
    AdManager.maybeShowMealDoneInterstitial();
  }

  void _showMealTypeSelector(Food food) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

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
                    color: Theme.of(context).colorScheme.primary,
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

class _TabBarPersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Color backgroundColor;
  final TabBar tabBar;

  _TabBarPersistentHeaderDelegate({
    required this.backgroundColor,
    required this.tabBar,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarPersistentHeaderDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
