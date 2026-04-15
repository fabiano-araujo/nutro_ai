import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_service.dart';

class PurchaseService with ChangeNotifier {
  static const String keyPremiumStatus = 'premium_status';
  static const String keySubscriptionType = 'subscription_type';
  static const String keySubscriptionExpiryDate = 'subscription_expiry_date';

  static const String planoSemanal = 'plano_semanal';
  static const String planoMensal = 'plano_mensal';
  static const String planoAnual = 'plano_anual';

  static const List<String> _productIds = <String>[
    planoSemanal,
    planoMensal,
    planoAnual,
  ];

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = <ProductDetails>[];
  bool _isLoading = true;
  bool _isPremium = false;
  String _subscriptionType = 'free';
  DateTime? _subscriptionExpiryDate;
  String? _errorMessage;
  AuthService? _authService;
  int? _lastSyncedUserId;
  String? _lastSyncedToken;
  bool _isSyncingServerStatus = false;

  bool get isLoading => _isLoading;
  bool get isPremium => _isPremium;
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
      unawaited(
        _applySubscriptionStatus(
          isPremium: false,
          planType: 'free',
          expirationDate: null,
          remainingDays: null,
        ),
      );
      return;
    }

    final authSubscription = currentUser!.subscription;
    final userChanged =
        previousUserId != currentUserId || _lastSyncedUserId != currentUserId;
    final shouldApplySnapshot =
        authSubscription.isPremium || !_isPremium || userChanged;

    if (shouldApplySnapshot) {
      unawaited(
        _applySubscriptionStatus(
          isPremium: authSubscription.isPremium,
          planType: authSubscription.planType,
          expirationDate: authSubscription.expirationDate,
          remainingDays: authSubscription.remainingDays,
        ),
      );
    }

    final shouldRefreshFromServer = userChanged ||
        previousToken != currentToken ||
        _lastSyncedToken != currentToken;

    if (shouldRefreshFromServer) {
      _lastSyncedUserId = currentUserId;
      _lastSyncedToken = currentToken;
      unawaited(refreshSubscriptionStatusFromServer());
    }
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
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds.toSet());

      if (response.error != null) {
        _errorMessage = 'Erro ao carregar produtos: ${response.error!.message}';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _products = response.productDetails;
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

  Future<void> buySubscription(ProductDetails productDetails) async {
    _errorMessage = null;

    if (!_hasAuthenticatedUser()) {
      _errorMessage = 'Entre na sua conta antes de assinar o Premium.';
      notifyListeners();
      return;
    }

    try {
      final PurchaseParam purchaseParam = Platform.isAndroid
          ? GooglePlayPurchaseParam(productDetails: productDetails)
          : PurchaseParam(productDetails: productDetails);

      final launched = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!launched) {
        _errorMessage =
            'Não foi possível abrir o Google Play para concluir a assinatura.';
      }
    } catch (e) {
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

  Future<void> refreshSubscriptionStatusFromServer() async {
    final authService = _authService;
    final currentUser = authService?.currentUser;
    final token = authService?.token;

    if (_isSyncingServerStatus ||
        authService == null ||
        currentUser == null ||
        token == null) {
      return;
    }

    _isSyncingServerStatus = true;

    try {
      final data = await ApiService.getSubscriptionConfig(
        token: token,
        userId: currentUser.id,
      );

      await _applyServerSubscriptionData(data);
    } catch (e) {
      debugPrint('Erro ao sincronizar assinatura com o servidor: $e');
    } finally {
      _isSyncingServerStatus = false;
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        _errorMessage =
            'Erro na compra: ${purchaseDetails.error?.message ?? 'Desconhecido'}';
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        await _verifyPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _errorMessage = 'Compra cancelada pelo usuário.';
      }

      if (purchaseDetails.pendingCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchaseDetails);
        } catch (e) {
          debugPrint('Erro ao completar compra: $e');
        }
      }
    }

    notifyListeners();
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    final authService = _authService;
    final currentUser = authService?.currentUser;
    final token = authService?.token;

    if (authService == null || currentUser == null || token == null) {
      _errorMessage = 'Entre na sua conta antes de assinar o Premium.';
      return;
    }

    if (!Platform.isAndroid) {
      _errorMessage =
          'A assinatura premium pela loja está disponível apenas no Android neste momento.';
      return;
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
      } else {
        _errorMessage = null;
      }
    } catch (e) {
      debugPrint('Erro ao validar compra no servidor: $e');
      _errorMessage = _humanizeException(e);
    }
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
    _isPremium = isPremium;
    _subscriptionType = isPremium ? planType : 'free';
    _subscriptionExpiryDate = isPremium ? expirationDate : null;

    await _saveSubscriptionStatus(
      _isPremium,
      _subscriptionType,
      _subscriptionExpiryDate,
    );

    final authService = _authService;
    if (authService != null && authService.isAuthenticated) {
      await authService.updateSubscriptionStatus(
        isPremium: _isPremium,
        planType: _subscriptionType,
        expirationDate: _subscriptionExpiryDate,
        remainingDays: remainingDays,
      );
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  bool _hasAuthenticatedUser() {
    final authService = _authService;
    return authService != null &&
        authService.isAuthenticated &&
        authService.currentUser != null &&
        authService.token != null;
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
    _subscription?.cancel();
    super.dispose();
  }
}
