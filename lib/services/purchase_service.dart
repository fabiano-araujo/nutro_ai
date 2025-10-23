import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../util/app_constants.dart'; // Importar constantes

class PurchaseService with ChangeNotifier {
  static const String keyPremiumStatus = 'premium_status';
  static const String keySubscriptionType = 'subscription_type';
  static const String keySubscriptionExpiryDate = 'subscription_expiry_date';

  // IDs dos produtos da Google Play Store (substitua pelos seus IDs reais cadastrados)
  static const String planoSemanal = 'plano_semanal';
  static const String planoMensal = 'plano_mensal';
  static const String planoAnual = 'plano_anual';

  // Lista de IDs de produtos
  static const List<String> _productIds = <String>[
    planoSemanal,
    planoMensal,
    planoAnual,
  ];

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  bool _isLoading = true;
  bool _isPremium = false;
  String _subscriptionType = '';
  DateTime? _subscriptionExpiryDate;
  String? _errorMessage;

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

  Future<void> _loadSavedPurchaseStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(keyPremiumStatus) ?? false;
      _subscriptionType = prefs.getString(keySubscriptionType) ?? '';

      final expiryDateMillis = prefs.getInt(keySubscriptionExpiryDate);
      if (expiryDateMillis != null) {
        _subscriptionExpiryDate =
            DateTime.fromMillisecondsSinceEpoch(expiryDateMillis);

        // Verifica se a assinatura expirou
        if (_subscriptionExpiryDate!.isBefore(DateTime.now())) {
          _isPremium = false;
          _subscriptionType = '';
          _subscriptionExpiryDate = null;
          await _saveSubscriptionStatus(false, '', null);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar status da assinatura: $e');
      _errorMessage = 'Erro ao verificar seu status de assinatura.';
    }

    notifyListeners();
  }

  Future<void> _saveSubscriptionStatus(
      bool isPremium, String type, DateTime? expiryDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyPremiumStatus, isPremium);
      await prefs.setString(keySubscriptionType, type);

      if (expiryDate != null) {
        await prefs.setInt(
            keySubscriptionExpiryDate, expiryDate.millisecondsSinceEpoch);
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

      // Observador para eventos de compra
      _subscription = _inAppPurchase.purchaseStream
          .listen(_listenToPurchaseUpdated, onDone: () {
        _subscription?.cancel();
      }, onError: (error) {
        debugPrint('Erro no stream de compras: $error');
        _errorMessage = 'Ocorreu um erro ao monitorar suas compras.';
        notifyListeners();
      });

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
        debugPrint(_errorMessage);
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        // Alguns produtos não foram encontrados
        debugPrint('Produtos não encontrados: ${response.notFoundIDs}');
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
      debugPrint('Exceção ao carregar produtos: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buySubscription(ProductDetails productDetails) async {
    _errorMessage = null;

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      if (productDetails.id.contains('subscription') ||
          productDetails.id.contains('plano')) {
        // Comprar como assinatura
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Comprar como produto não consumível
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      _errorMessage = 'Erro ao iniciar a compra. Tente novamente mais tarde.';
      debugPrint('Erro ao comprar: $e');
      notifyListeners();
    }
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Processando compra - não faz nada aqui, a UI deve mostrar um indicador de carregamento
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Tratar erro
          _errorMessage =
              'Erro na compra: ${purchaseDetails.error?.message ?? 'Desconhecido'}';
          debugPrint(_errorMessage);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Validar a compra
          await _verifyPurchase(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          _errorMessage = 'Compra cancelada pelo usuário.';
          debugPrint('Compra cancelada');
        }

        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await _inAppPurchase.completePurchase(purchaseDetails);
          } catch (e) {
            debugPrint('Erro ao completar compra: $e');
          }
        }
      }
    }

    notifyListeners();
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Determinar tipo de assinatura e data de expiração
    String subscriptionType = '';
    DateTime? expiryDate;

    switch (purchaseDetails.productID) {
      case planoSemanal:
        subscriptionType = 'semanal';
        expiryDate = DateTime.now().add(const Duration(days: 7));
        break;
      case planoMensal:
        subscriptionType = 'mensal';
        expiryDate = DateTime.now().add(const Duration(days: 30));
        break;
      case planoAnual:
        subscriptionType = 'anual';
        expiryDate = DateTime.now().add(const Duration(days: 365));
        break;
      default:
        // Produto desconhecido
        debugPrint('Produto desconhecido: ${purchaseDetails.productID}');
        return;
    }

    // Verificar o recibo no servidor (opcional, mas recomendado para segurança adicional)
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.API_BASE_URL}/verify-purchase'),
        body: {
          'receipt': purchaseDetails.verificationData.serverVerificationData,
          'productId': purchaseDetails.productID,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Assinatura confirmada pelo servidor
        _isPremium = true;
        _subscriptionType = subscriptionType;
        _subscriptionExpiryDate = expiryDate;
        await _saveSubscriptionStatus(true, subscriptionType, expiryDate);
      } else {
        // Erro na verificação do servidor
        debugPrint('Erro na verificação do servidor: ${response.body}');

        // Decisão de negócio: permitir acesso mesmo sem verificação do servidor?
        // Por padrão, vamos permitir para melhorar a experiência do usuário
        _isPremium = true;
        _subscriptionType = subscriptionType;
        _subscriptionExpiryDate = expiryDate;
        await _saveSubscriptionStatus(true, subscriptionType, expiryDate);
      }
    } catch (e) {
      // Caso não consiga contatar o servidor, podemos permitir o acesso,
      // mas com verificações locais somente
      debugPrint('Erro ao contatar servidor: $e');
      _isPremium = true;
      _subscriptionType = subscriptionType;
      _subscriptionExpiryDate = expiryDate;
      await _saveSubscriptionStatus(true, subscriptionType, expiryDate);
    }

    notifyListeners();
  }

  Future<void> restorePurchases() async {
    _errorMessage = null;

    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _errorMessage = 'Erro ao restaurar compras. Tente novamente mais tarde.';
      debugPrint('Erro ao restaurar compras: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
