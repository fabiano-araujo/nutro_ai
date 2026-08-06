import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_manager.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class PurchaseService with ChangeNotifier {
  static const String keyPremiumStatus = 'premium_status';
  static const String keySubscriptionType = 'subscription_type';
  static const String keySubscriptionExpiryDate = 'subscription_expiry_date';

  static const String planoSemanal = 'plano_semanal';
  static const String planoMensal = 'plano_mensal';
  static const String planoAnual = 'plano_anual';

  static const List<String> _productIds = <String>[
    planoMensal,
    planoAnual,
  ];

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = <ProductDetails>[];
  bool _isLoading = true;
  bool _isPurchaseInProgress = false;
  bool _isPremium = false;
  String _subscriptionType = 'free';
  DateTime? _subscriptionExpiryDate;
  String? _errorMessage;
  AuthService? _authService;
  int? _lastSyncedUserId;
  String? _lastSyncedToken;
  Future<void>? _subscriptionStatusSyncFuture;
  bool _subscriptionStatusSynchronized = false;
  Timer? _purchaseLaunchWatchdog;

  bool get isLoading => _isLoading || _isPurchaseInProgress;
  bool get isPurchaseInProgress => _isPurchaseInProgress;
  bool get isPremium => _isPremium;
  bool get isSubscriptionStatusSynchronized => _subscriptionStatusSynchronized;
  List<ProductDetails> get products => _products;
  String get subscriptionType => _subscriptionType;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  String? get errorMessage => _errorMessage;

  PurchaseService() {
    _loadSavedPurchaseStatus();
    _initializeStore();
  }

  void bindAuthService(AuthService authService) {
    final previousUserId = _authService?.currentUser?.id;
    final previousToken = _authService?.token;
    _authService = authService;

    final currentUser = authService.currentUser;
    final currentUserId = currentUser?.id;
    final currentToken = authService.token;

    if (!authService.isAuthenticated ||
        currentUserId == null ||
        currentToken == null) {
      _lastSyncedUserId = null;
      _lastSyncedToken = null;
      _subscriptionStatusSynchronized = true;
      _applyUnauthenticatedSnapshot();
      return;
    }

    final authSubscription = currentUser!.subscription;
    final userChanged =
        previousUserId != currentUserId || _lastSyncedUserId != currentUserId;
    final shouldApplySnapshot =
        (userChanged || authSubscription.isPremium || !_isPremium) &&
            !_matchesSubscriptionSnapshot(authSubscription);

    if (shouldApplySnapshot) {
      _applyAuthenticatedSnapshot(authSubscription);
    }

    final shouldRefreshFromServer = userChanged ||
        previousToken != currentToken ||
        _lastSyncedToken != currentToken;

    if (shouldRefreshFromServer) {
      _lastSyncedUserId = currentUserId;
      _lastSyncedToken = currentToken;
      _subscriptionStatusSynchronized = false;
      unawaited(refreshSubscriptionStatusFromServer());
    }
  }

  void _applyUnauthenticatedSnapshot() {
    final statusChanged = _isPremium ||
        _subscriptionType != 'free' ||
        _subscriptionExpiryDate != null;
    _isPremium = false;
    _subscriptionType = 'free';
    _subscriptionExpiryDate = null;

    if (!statusChanged) return;

    AdManager.setPremiumStatus(false);
    unawaited(_saveSubscriptionStatus(false, 'free', null));
    notifyListeners();
  }

  void _applyAuthenticatedSnapshot(Subscription subscription) {
    final isPremium = subscription.isPremium;
    final planType = isPremium ? subscription.planType : 'free';
    final expirationDate = isPremium ? subscription.expirationDate : null;
    final statusChanged = _isPremium != isPremium ||
        _subscriptionType != planType ||
        !_sameDate(_subscriptionExpiryDate, expirationDate);

    _isPremium = isPremium;
    _subscriptionType = planType;
    _subscriptionExpiryDate = expirationDate;

    if (!statusChanged) return;

    AdManager.setPremiumStatus(isPremium);
    unawaited(_saveSubscriptionStatus(isPremium, planType, expirationDate));
    notifyListeners();
  }

  Future<void> _loadSavedPurchaseStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIsPremium = prefs.getBool(keyPremiumStatus) ?? false;
      final savedPlanType = prefs.getString(keySubscriptionType) ?? 'free';
      final expiryDateMillis = prefs.getInt(keySubscriptionExpiryDate);

      DateTime? savedExpirationDate;
      if (expiryDateMillis != null) {
        savedExpirationDate =
            DateTime.fromMillisecondsSinceEpoch(expiryDateMillis);
      }

      // Depois que uma sessão já foi vinculada, o status salvo pode ser de
      // outra conta ou estar desatualizado. Nesse caso, deixe o snapshot da
      // sessão e a sincronização com o servidor definirem o estado atual.
      if (_authService?.isAuthenticated == true) {
        notifyListeners();
        return;
      }

      if (savedExpirationDate != null &&
          savedExpirationDate.isBefore(DateTime.now())) {
        await _applySubscriptionStatus(
          isPremium: false,
          planType: 'free',
          expirationDate: null,
          remainingDays: null,
          shouldNotify: false,
        );
      } else {
        _isPremium = savedIsPremium;
        _subscriptionType = savedIsPremium ? savedPlanType : 'free';
        _subscriptionExpiryDate = savedExpirationDate;
        AdManager.setPremiumStatus(_isPremium);
      }
    } catch (e) {
      debugPrint('Erro ao carregar status da assinatura: $e');
      _errorMessage = 'Erro ao verificar seu status de assinatura.';
    }

    notifyListeners();
  }

  Future<void> _saveSubscriptionStatus(
    bool isPremium,
    String planType,
    DateTime? expiryDate,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyPremiumStatus, isPremium);
      await prefs.setString(keySubscriptionType, planType);

      if (expiryDate != null) {
        await prefs.setInt(
          keySubscriptionExpiryDate,
          expiryDate.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(keySubscriptionExpiryDate);
      }
    } catch (e) {
      debugPrint('Erro ao salvar status da assinatura: $e');
    }
  }

  Future<void> _initializeStore() async {
    _errorMessage = null;

    try {
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        _isLoading = false;
        _errorMessage =
            'A loja de aplicativos não está disponível neste momento.';
        notifyListeners();
        return;
      }

      _subscription = _inAppPurchase.purchaseStream.listen(
        _listenToPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (Object error) {
          debugPrint('Erro no stream de compras: $error');
          _errorMessage = 'Ocorreu um erro ao monitorar suas compras.';
          notifyListeners();
        },
      );

      await _loadProducts();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Não foi possível inicializar a loja de compras.';
      debugPrint('Erro ao inicializar loja: $e');
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(_productIds.toSet())
          .timeout(const Duration(seconds: 20));

      if (response.error != null) {
        _errorMessage = 'Erro ao carregar produtos: ${response.error!.message}';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _products = response.productDetails;
      debugPrint(
        'Produtos Google Play carregados: '
        '${_products.map((product) => product.id).join(', ')}',
      );
      _debugLogProductDetails(_products);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          'Produtos Google Play nao encontrados: '
          '${response.notFoundIDs.join(', ')}',
        );
      }
      if (_products.isEmpty) {
        _errorMessage =
            'Não foi possível encontrar os planos de assinatura na loja.';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erro ao carregar produtos da loja.';
      _isLoading = false;
      debugPrint('Exceção ao carregar produtos: $e');
      notifyListeners();
    }
  }

  Future<void> reloadProducts() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        _isLoading = false;
        _errorMessage =
            'A loja de aplicativos não está disponível neste momento.';
        notifyListeners();
        return;
      }

      await _loadProducts();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Não foi possível recarregar os planos da loja.';
      debugPrint('Erro ao recarregar produtos: $e');
      notifyListeners();
    }
  }

  Future<void> buySubscription(ProductDetails productDetails) async {
    _errorMessage = null;

    if (!_hasAuthenticatedUser()) {
      _errorMessage = 'Entre na sua conta antes de assinar o Premium.';
      notifyListeners();
      return;
    }

    final authService = _authService!;
    final currentUser = authService.currentUser!;

    if (Platform.isAndroid && !_isAndroidSubscriptionProduct(productDetails)) {
      _errorMessage =
          'Este plano não está configurado como assinatura na Google Play.';
      notifyListeners();
      return;
    }

    _isPurchaseInProgress = true;
    _startPurchaseLaunchWatchdog(productDetails.id);
    notifyListeners();

    try {
      final androidProduct =
          productDetails is GooglePlayProductDetails ? productDetails : null;
      final androidOffer =
          androidProduct == null ? null : _subscriptionOfferFor(androidProduct);
      final androidOfferToken = androidOffer?.offerIdToken;

      debugPrint(
        'Abrindo compra Google Play: productId=${productDetails.id}, '
        'price=${productDetails.price}, '
        'basePlanId=${androidOffer?.basePlanId}, '
        'offerId=${androidOffer?.offerId}, '
        'offerToken=$androidOfferToken, '
        'phases=${androidOffer == null ? null : _debugPricingPhases(androidOffer.pricingPhases)}',
      );

      final PurchaseParam purchaseParam = Platform.isAndroid
          ? GooglePlayPurchaseParam(
              productDetails: productDetails,
              applicationUserName: currentUser.id.toString(),
              offerToken: androidOfferToken,
            )
          : PurchaseParam(
              productDetails: productDetails,
              applicationUserName: currentUser.id.toString(),
            );

      final launched = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!launched) {
        _errorMessage =
            'Não foi possível abrir o Google Play para concluir a assinatura.';
        _isPurchaseInProgress = false;
        _purchaseLaunchWatchdog?.cancel();
      }
    } catch (e) {
      _isPurchaseInProgress = false;
      _purchaseLaunchWatchdog?.cancel();
      _errorMessage = 'Erro ao iniciar a compra. Tente novamente mais tarde.';
      debugPrint('Erro ao comprar assinatura: $e');
    }

    notifyListeners();
  }

  Future<void> restorePurchases() async {
    _errorMessage = null;

    if (!_hasAuthenticatedUser()) {
      _errorMessage = 'Entre na sua conta antes de restaurar a assinatura.';
      notifyListeners();
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
      await refreshSubscriptionStatusFromServer();
    } catch (e) {
      _errorMessage = 'Erro ao restaurar compras. Tente novamente mais tarde.';
      debugPrint('Erro ao restaurar compras: $e');
      notifyListeners();
    }
  }

  Future<void> refreshSubscriptionStatusFromServer() {
    final inFlight = _subscriptionStatusSyncFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final authService = _authService;
    final currentUser = authService?.currentUser;
    final token = authService?.token;

    if (authService == null || currentUser == null || token == null) {
      _subscriptionStatusSynchronized = true;
      return Future<void>.value();
    }

    final future = _refreshSubscriptionStatusFromServer(
      currentUser: currentUser,
      token: token,
    );
    late final Future<void> completedFuture;
    completedFuture = future.whenComplete(() {
      if (identical(_subscriptionStatusSyncFuture, completedFuture)) {
        _subscriptionStatusSyncFuture = null;
      }
    });
    _subscriptionStatusSyncFuture = completedFuture;
    return completedFuture;
  }

  Future<void> _refreshSubscriptionStatusFromServer({
    required User currentUser,
    required String token,
  }) async {
    try {
      final data = await ApiService.getSubscriptionConfig(
        token: token,
        userId: currentUser.id,
      );

      await _applyServerSubscriptionData(data);
    } catch (e) {
      debugPrint('Erro ao sincronizar assinatura com o servidor: $e');
    } finally {
      _subscriptionStatusSynchronized = true;
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    if (purchaseDetailsList.isNotEmpty) {
      _purchaseLaunchWatchdog?.cancel();
    }

    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint(
        'Atualizacao de compra Google Play: '
        'productId=${purchaseDetails.productID}, '
        'status=${purchaseDetails.status}, '
        'pendingComplete=${purchaseDetails.pendingCompletePurchase}',
      );

      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isPurchaseInProgress = true;
        _errorMessage = null;
        continue;
      }

      _isPurchaseInProgress = false;
      var shouldCompletePurchase = false;

      if (purchaseDetails.status == PurchaseStatus.error) {
        _errorMessage =
            'Erro na compra: ${purchaseDetails.error?.message ?? 'Desconhecido'}';
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        shouldCompletePurchase = await _verifyPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _errorMessage = 'Compra cancelada pelo usuário.';
      }

      if (purchaseDetails.pendingCompletePurchase && shouldCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchaseDetails);
        } catch (e) {
          debugPrint('Erro ao completar compra: $e');
        }
      }
    }

    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    final authService = _authService;
    final currentUser = authService?.currentUser;
    final token = authService?.token;

    if (authService == null || currentUser == null || token == null) {
      _errorMessage = 'Entre na sua conta antes de assinar o Premium.';
      return false;
    }

    if (!Platform.isAndroid) {
      _errorMessage =
          'A assinatura premium pela loja está disponível apenas no Android neste momento.';
      return false;
    }

    try {
      final data = await ApiService.confirmGooglePlaySubscription(
        token: token,
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
        productId: purchaseDetails.productID,
      );

      await _applyServerSubscriptionData(data);

      if (data['isPremium'] != true) {
        _errorMessage =
            'A compra foi validada, mas a assinatura ainda não está ativa.';
        return false;
      } else {
        _errorMessage = null;
        return true;
      }
    } catch (e) {
      debugPrint('Erro ao validar compra no servidor: $e');
      _errorMessage = _humanizeException(e);
      return false;
    }
  }

  ProductDetails? productForPlan(String planId) {
    final matches = _products.where((product) => product.id == planId).toList();
    if (matches.isEmpty) return null;

    if (Platform.isAndroid) {
      final androidSubscriptions = matches
          .whereType<GooglePlayProductDetails>()
          .where(_isAndroidSubscriptionProduct)
          .toList()
        ..sort(_compareAndroidSubscriptionProducts);

      if (androidSubscriptions.isNotEmpty) {
        return androidSubscriptions.first;
      }
    }

    final nonZero = matches.where((product) => product.rawPrice > 0).toList();
    final candidates = nonZero.isNotEmpty ? nonZero : matches;
    candidates.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return candidates.first;
  }

  Future<void> _applyServerSubscriptionData(Map<String, dynamic> data) async {
    final isPremium = data['isPremium'] == true;
    final planType = (data['planType'] as String?) ?? 'free';
    final expirationDate = _parseExpirationDate(data['expirationDate']);
    final remainingDays = _parseRemainingDays(data['remainingDays']);

    await _applySubscriptionStatus(
      isPremium: isPremium,
      planType: planType,
      expirationDate: expirationDate,
      remainingDays: remainingDays,
    );
  }

  Future<void> _applySubscriptionStatus({
    required bool isPremium,
    required String planType,
    required DateTime? expirationDate,
    required int? remainingDays,
    bool shouldNotify = true,
  }) async {
    final nextIsPremium = isPremium;
    final nextSubscriptionType = isPremium ? planType : 'free';
    final nextSubscriptionExpiryDate = isPremium ? expirationDate : null;
    final statusChanged = _isPremium != nextIsPremium ||
        _subscriptionType != nextSubscriptionType ||
        !_sameDate(_subscriptionExpiryDate, nextSubscriptionExpiryDate);

    _isPremium = nextIsPremium;
    _subscriptionType = nextSubscriptionType;
    _subscriptionExpiryDate = nextSubscriptionExpiryDate;

    if (statusChanged) {
      AdManager.setPremiumStatus(_isPremium);
    }

    await _saveSubscriptionStatus(
      _isPremium,
      _subscriptionType,
      _subscriptionExpiryDate,
    );

    final authService = _authService;
    final shouldUpdateAuth = authService != null &&
        authService.isAuthenticated &&
        !_authSubscriptionMatches(
          authService,
          isPremium: _isPremium,
          planType: _subscriptionType,
          expirationDate: _subscriptionExpiryDate,
          remainingDays: remainingDays,
        );

    if (shouldUpdateAuth) {
      await authService.updateSubscriptionStatus(
        isPremium: _isPremium,
        planType: _subscriptionType,
        expirationDate: _subscriptionExpiryDate,
        remainingDays: remainingDays,
      );
    }

    if (shouldNotify && (statusChanged || shouldUpdateAuth)) {
      notifyListeners();
    }
  }

  bool _matchesSubscriptionSnapshot(Subscription subscription) {
    final snapshotIsPremium = subscription.isPremium;
    final snapshotPlanType = snapshotIsPremium ? subscription.planType : 'free';
    final snapshotExpirationDate =
        snapshotIsPremium ? subscription.expirationDate : null;

    return _isPremium == snapshotIsPremium &&
        _subscriptionType == snapshotPlanType &&
        _sameDate(_subscriptionExpiryDate, snapshotExpirationDate);
  }

  bool _authSubscriptionMatches(
    AuthService authService, {
    required bool isPremium,
    required String planType,
    required DateTime? expirationDate,
    required int? remainingDays,
  }) {
    final subscription = authService.currentUser?.subscription;
    if (subscription == null) return false;

    final normalizedPlanType = isPremium ? planType : 'free';
    final normalizedExpirationDate = isPremium ? expirationDate : null;

    return subscription.isPremium == isPremium &&
        subscription.planType == normalizedPlanType &&
        _sameDate(subscription.expirationDate, normalizedExpirationDate) &&
        subscription.remainingDays == remainingDays;
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
  }

  bool _hasAuthenticatedUser() {
    final authService = _authService;
    return authService != null &&
        authService.isAuthenticated &&
        authService.currentUser != null &&
        authService.token != null;
  }

  bool _isAndroidSubscriptionProduct(ProductDetails productDetails) {
    if (productDetails is! GooglePlayProductDetails) return false;
    final offer = _subscriptionOfferFor(productDetails);
    return offer != null && offer.offerIdToken.isNotEmpty;
  }

  SubscriptionOfferDetailsWrapper? _subscriptionOfferFor(
    GooglePlayProductDetails productDetails,
  ) {
    final index = productDetails.subscriptionIndex;
    final offers = productDetails.productDetails.subscriptionOfferDetails;

    if (index == null ||
        offers == null ||
        index < 0 ||
        index >= offers.length) {
      return null;
    }

    return offers[index];
  }

  int _compareAndroidSubscriptionProducts(
    GooglePlayProductDetails a,
    GooglePlayProductDetails b,
  ) {
    final aScore = _androidSubscriptionProductScore(a);
    final bScore = _androidSubscriptionProductScore(b);
    if (aScore != bScore) return aScore.compareTo(bScore);
    return a.rawPrice.compareTo(b.rawPrice);
  }

  int _androidSubscriptionProductScore(GooglePlayProductDetails product) {
    final offer = _subscriptionOfferFor(product);
    if (offer == null) return 100;

    var score = 0;
    final trialDays = _freeTrialDays(offer);
    final hasFreeTrial = trialDays != null;
    if (hasFreeTrial) {
      score -= 30 + trialDays.clamp(0, 365).toInt();
    }
    if (offer.offerId != null && offer.offerId!.isNotEmpty) score += 10;
    if (product.rawPrice <= 0 && !hasFreeTrial) score += 20;

    final hasRecurringPrice = offer.pricingPhases.any(
      (phase) =>
          phase.recurrenceMode == RecurrenceMode.infiniteRecurring &&
          phase.priceAmountMicros > 0,
    );
    if (!hasRecurringPrice) score += 5;

    return score;
  }

  int? _freeTrialDays(SubscriptionOfferDetailsWrapper offer) {
    for (final phase in offer.pricingPhases) {
      if (phase.priceAmountMicros == 0 &&
          phase.recurrenceMode != RecurrenceMode.infiniteRecurring) {
        return _trialDaysFromBillingPeriod(phase.billingPeriod) ?? 0;
      }
    }

    return null;
  }

  void _debugLogProductDetails(List<ProductDetails> products) {
    for (final product in products) {
      if (product is! GooglePlayProductDetails) continue;

      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers == null || offers.isEmpty) {
        debugPrint(
          'Google Play produto sem ofertas: productId=${product.id}, '
          'price=${product.price}',
        );
        continue;
      }

      for (var index = 0; index < offers.length; index++) {
        final offer = offers[index];
        debugPrint(
          'Google Play oferta: productId=${product.id}, '
          'subscriptionIndex=${product.subscriptionIndex}, '
          'offerIndex=$index, '
          'basePlanId=${offer.basePlanId}, '
          'offerId=${offer.offerId}, '
          'trialDays=${_freeTrialDays(offer)}, '
          'hasToken=${offer.offerIdToken.isNotEmpty}, '
          'phases=${_debugPricingPhases(offer.pricingPhases)}',
        );
      }
    }
  }

  String _debugPricingPhases(List<PricingPhaseWrapper> phases) {
    return phases
        .map(
          (phase) => '${phase.billingPeriod}/${phase.formattedPrice}/'
              '${phase.priceAmountMicros}/${phase.recurrenceMode}/'
              'cycles=${phase.billingCycleCount}',
        )
        .join(' | ');
  }

  int? _trialDaysFromBillingPeriod(String billingPeriod) {
    final dayMatch = RegExp(r'^P(\d+)D$').firstMatch(billingPeriod);
    if (dayMatch != null) {
      return int.tryParse(dayMatch.group(1)!);
    }

    final weekMatch = RegExp(r'^P(\d+)W$').firstMatch(billingPeriod);
    if (weekMatch != null) {
      final weeks = int.tryParse(weekMatch.group(1)!);
      return weeks == null ? null : weeks * 7;
    }

    return null;
  }

  void _startPurchaseLaunchWatchdog(String productId) {
    _purchaseLaunchWatchdog?.cancel();
    _purchaseLaunchWatchdog = Timer(const Duration(seconds: 45), () {
      if (!_isPurchaseInProgress) return;

      _isPurchaseInProgress = false;
      _errorMessage =
          'O Google Play não retornou a tela de compra. Instale o app pela faixa de teste interno da Play Store e tente novamente.';
      debugPrint(
        'Timeout aguardando retorno da compra Google Play para $productId.',
      );
      notifyListeners();
    });
  }

  DateTime? _parseExpirationDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  int? _parseRemainingDays(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  String _humanizeException(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Erro ao confirmar a assinatura. Tente novamente.';
    }
    return message;
  }

  @override
  void dispose() {
    _purchaseLaunchWatchdog?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
