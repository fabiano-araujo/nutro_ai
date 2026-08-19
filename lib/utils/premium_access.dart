import '../services/ad_manager.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';

/// Resolve o acesso Premium usando todos os snapshots locais disponíveis.
///
/// Durante a restauração da sessão, cada serviço pode receber a atualização
/// da assinatura em momentos diferentes. Centralizar a decisão evita que uma
/// tela esconda temporariamente recursos já liberados em outra.
bool hasPremiumAccess({
  PurchaseService? purchaseService,
  AuthService? authService,
  DateTime? now,
}) {
  final subscription = authService?.currentUser?.subscription;

  return resolvePremiumAccess(
    adManagerIsPremium: AdManager.isPremium,
    purchaseIsPremium: purchaseService?.isPremium ?? false,
    purchasePlanType: purchaseService?.subscriptionType,
    purchaseExpirationDate: purchaseService?.subscriptionExpiryDate,
    userIsPremium: subscription?.isPremium ?? false,
    userPlanType: subscription?.planType,
    userExpirationDate: subscription?.expirationDate,
    remainingDays: subscription?.remainingDays,
    now: now,
  );
}

/// Núcleo puro, separado para manter a regra de acesso testável.
bool resolvePremiumAccess({
  bool adManagerIsPremium = false,
  bool purchaseIsPremium = false,
  String? purchasePlanType,
  DateTime? purchaseExpirationDate,
  bool userIsPremium = false,
  String? userPlanType,
  DateTime? userExpirationDate,
  int? remainingDays,
  DateTime? now,
}) {
  final referenceTime = now ?? DateTime.now();

  bool hasPaidPlan(String? planType) {
    final normalized = planType?.trim().toLowerCase();
    return normalized != null && normalized.isNotEmpty && normalized != 'free';
  }

  bool hasFutureExpiration(DateTime? expirationDate) {
    return expirationDate?.isAfter(referenceTime) ?? false;
  }

  return adManagerIsPremium ||
      purchaseIsPremium ||
      userIsPremium ||
      hasPaidPlan(purchasePlanType) ||
      hasPaidPlan(userPlanType) ||
      hasFutureExpiration(purchaseExpirationDate) ||
      hasFutureExpiration(userExpirationDate) ||
      (remainingDays ?? 0) > 0;
}
