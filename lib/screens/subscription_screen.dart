import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutro_ai/i18n/app_localizations_extension.dart';
import 'package:nutro_ai/models/subscription_plan.dart';
import 'package:nutro_ai/screens/login_screen.dart';
import 'package:nutro_ai/services/auth_service.dart';
import 'package:nutro_ai/services/purchase_service.dart';
import 'package:nutro_ai/theme/app_theme.dart';
import 'package:provider/provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final List<SubscriptionPlan> _plans;
  int _selectedPlanIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);

  Color _inputFillColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;

  Color _subtleBorderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white12 : Colors.black12;

  Color _mutedTextColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

  @override
  void initState() {
    super.initState();
    _plans = [...SubscriptionPlan.getPlans()]..sort(_comparePlans);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_plans.isEmpty && !_hasError) {
      _hasError = true;
      _errorMessage = context.tr.translate('error_loading_plans');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final purchaseService = context.watch<PurchaseService>();
    final authService = context.watch<AuthService>();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    ));

    if (_hasError) {
      return _buildError(context, _errorMessage, isDarkMode, textColor);
    }

    final selectedPlan = _plans[_selectedPlanIndex.clamp(0, _plans.length - 1)];
    final selectedProduct =
        _findProduct(purchaseService.products, selectedPlan.id);
    final isBusy = _isLoading || purchaseService.isLoading;
    final actionEnabled = authService.isAuthenticated
        ? selectedProduct != null && !isBusy
        : !isBusy;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalHeader(
              context: context,
              purchaseService: purchaseService,
              authService: authService,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
            Expanded(
              child: _buildScrollableContent(
                context: context,
                purchaseService: purchaseService,
                authService: authService,
                selectedPlan: selectedPlan,
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            ),
            _buildBottomBar(
              context: context,
              authService: authService,
              purchaseService: purchaseService,
              selectedPlan: selectedPlan,
              selectedProduct: selectedProduct,
              actionEnabled: actionEnabled,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalHeader({
    required BuildContext context,
    required PurchaseService purchaseService,
    required AuthService authService,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final isBusy = _isLoading || purchaseService.isLoading;

    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close, color: textColor),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: Text(
                  context.tr.translate('premium_plans'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.restore_rounded, color: textColor),
              tooltip: context.tr.translate('restore_purchases'),
              onPressed: isBusy
                  ? null
                  : () {
                      if (!authService.isAuthenticated) {
                        _openLogin(context);
                        return;
                      }
                      _restorePurchases(context, purchaseService);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableContent({
    required BuildContext context,
    required PurchaseService purchaseService,
    required AuthService authService,
    required SubscriptionPlan selectedPlan,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(context, isDarkMode, textColor),
                    const SizedBox(height: 26),
                    _buildPlanOptions(
                      context,
                      purchaseService,
                      isDarkMode,
                      textColor,
                    ),
                    const SizedBox(height: 14),
                    if (!authService.isAuthenticated)
                      _inlineHint(
                        context.tr.translate('access_account'),
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                      ),
                    if (purchaseService.errorMessage != null &&
                        purchaseService.errorMessage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _inlineHint(
                          purchaseService.errorMessage!,
                          icon: Icons.info_outline_rounded,
                          foregroundColor: const Color(0xFF8A4C00),
                          backgroundColor: const Color(0xFFFFF1DE),
                          isDarkMode: isDarkMode,
                          textColor: textColor,
                        ),
                      ),
                    const SizedBox(height: 18),
                    _buildBenefitsSection(context, selectedPlan, isDarkMode),
                    const SizedBox(height: 18),
                    _buildTerms(context, isDarkMode),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, bool isDarkMode, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _surfaceColor(isDarkMode),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _subtleBorderColor(isDarkMode)),
          ),
          child: Icon(
            Icons.workspace_premium_outlined,
            color: textColor.withValues(alpha: 0.82),
            size: 26,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Nutro AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getSoftTextColor(isDarkMode),
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildCompactChip(
              context.tr.translate('premium'),
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildHeadline(context, isDarkMode),
        const SizedBox(height: 10),
        Text(
          context.tr.translate('unlock_potential'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: _mutedTextColor(isDarkMode).withValues(alpha: 0.86),
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline(BuildContext context, bool isDarkMode) {
    final parts =
        context.tr.translate('subscription_headline').split('{highlight}');
    final accent = Theme.of(context).colorScheme.primary;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: '4.2x',
            style: TextStyle(color: accent, fontWeight: FontWeight.w700),
          ),
          if (parts.length > 1) TextSpan(text: parts.last),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppTheme.getSoftTextColor(isDarkMode),
        height: 1.25,
      ),
    );
  }

  Widget _buildPlanOptions(
    BuildContext context,
    PurchaseService purchaseService,
    bool isDarkMode,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr.translate('premium_plans'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 10),
        ..._plans.map((plan) {
          final index = _plans.indexWhere((item) => item.id == plan.id);
          final product = _findProduct(purchaseService.products, plan.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlanOption(
              plan: plan,
              product: product,
              isSelected: index == _selectedPlanIndex,
              isDarkMode: isDarkMode,
              textColor: textColor,
              surfaceColor: _inputFillColor(isDarkMode),
              selectedSurfaceColor: _surfaceColor(isDarkMode),
              borderColor: _subtleBorderColor(isDarkMode),
              onTap: () => setState(() => _selectedPlanIndex = index),
              productTitle: _productTitle(product, plan),
              productPrice: _productPrice(product, plan),
              productDescription: _productDescription(product, plan),
              monthlyPrice: _pricePerMonth(product, plan),
              monthlyLabel: context.tr.translate('per_month'),
              savingsLabel: plan.savePercentage > 0
                  ? context.tr.translate('save_percentage').replaceAll(
                        '{percentage}',
                        plan.savePercentage.toString(),
                      )
                  : null,
              popularLabel:
                  plan.isMostPopular ? context.tr.translate('popular') : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBenefitsSection(
    BuildContext context,
    SubscriptionPlan selectedPlan,
    bool isDarkMode,
  ) {
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final muted = _mutedTextColor(isDarkMode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _inputFillColor(isDarkMode),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr.translate('whats_included'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          ...selectedPlan.features.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _surfaceColor(isDarkMode),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: textColor.withValues(alpha: 0.76),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        fontSize: 14,
                        color: muted.withValues(alpha: 0.94),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerms(BuildContext context, bool isDarkMode) {
    return Text(
      context.tr.translate('subscription_terms'),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _mutedTextColor(isDarkMode).withValues(alpha: 0.76),
        fontSize: 12,
        height: 1.45,
      ),
    );
  }

  Widget _buildBottomBar({
    required BuildContext context,
    required AuthService authService,
    required PurchaseService purchaseService,
    required SubscriptionPlan selectedPlan,
    required ProductDetails? selectedProduct,
    required bool actionEnabled,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkBackgroundColor
            : AppTheme.backgroundColor,
        border: Border(
          top: BorderSide(color: _subtleBorderColor(isDarkMode)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _productTitle(selectedProduct, selectedPlan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          authService.isAuthenticated
                              ? '${_pricePerMonth(selectedProduct, selectedPlan)} ${context.tr.translate('per_month')}'
                              : context.tr.translate('access_account'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: _mutedTextColor(isDarkMode)
                                .withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: actionEnabled
                      ? () {
                          if (!authService.isAuthenticated) {
                            _openLogin(context);
                            return;
                          }
                          _subscribe(context, purchaseService);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: textColor,
                    foregroundColor: isDarkMode
                        ? AppTheme.darkBackgroundColor
                        : Colors.white,
                    disabledBackgroundColor: _surfaceColor(isDarkMode),
                    disabledForegroundColor:
                        _mutedTextColor(isDarkMode).withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode
                                  ? AppTheme.darkBackgroundColor
                                  : Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          authService.isAuthenticated
                              ? context.tr.translate('continue')
                              : context.tr.translate('sign_in'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 9),
              _buildSecureLine(context, isDarkMode, textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecureLine(
      BuildContext context, bool isDarkMode, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.verified_user_outlined,
            size: 15,
            color: textColor.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr.translate('secure_google_play'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.62),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactChip(
    String text, {
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor.withValues(alpha: 0.78),
        ),
      ),
    );
  }

  Widget _inlineHint(
    String text, {
    IconData icon = Icons.lock_outline_rounded,
    Color? foregroundColor,
    Color? backgroundColor,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final fg = foregroundColor ?? textColor.withValues(alpha: 0.76);
    final bg = backgroundColor ?? _surfaceColor(isDarkMode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: backgroundColor == null
              ? _subtleBorderColor(isDarkMode)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    String message,
    bool isDarkMode,
    Color textColor,
  ) {
    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _surfaceColor(isDarkMode),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: _subtleBorderColor(isDarkMode)),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 26,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr.translate('oops'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getSoftTextColor(isDarkMode),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _mutedTextColor(isDarkMode).withValues(alpha: 0.9),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        _hasError = false;
                        _errorMessage = '';
                      }),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: textColor,
                        foregroundColor: isDarkMode
                            ? AppTheme.darkBackgroundColor
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        context.tr.translate('try_again_button'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restorePurchases(
      BuildContext context, PurchaseService purchaseService) async {
    setState(() => _isLoading = true);
    try {
      await purchaseService.restorePurchases();
      if (purchaseService.errorMessage != null) {
        setState(() {
          _hasError = true;
          _errorMessage = purchaseService.errorMessage!;
        });
      }
    } catch (_) {
      setState(() {
        _hasError = true;
        _errorMessage = context.tr.translate('subscription_error');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribe(
      BuildContext context, PurchaseService purchaseService) async {
    final selectedPlan = _plans[_selectedPlanIndex.clamp(0, _plans.length - 1)];
    final selectedProduct =
        _findProduct(purchaseService.products, selectedPlan.id);
    if (selectedProduct == null) {
      setState(() {
        _hasError = true;
        _errorMessage = context.tr.translate('try_again_later');
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await purchaseService.buySubscription(selectedProduct);
      if (purchaseService.errorMessage != null) {
        setState(() {
          _hasError = true;
          _errorMessage = purchaseService.errorMessage!;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '${context.tr.translate('subscription_error')}: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) => const LoginScreen(popOnSuccess: true)),
    );
  }

  int _comparePlans(SubscriptionPlan a, SubscriptionPlan b) {
    const order = <String, int>{
      PurchaseService.planoAnual: 0,
      PurchaseService.planoMensal: 1,
      PurchaseService.planoSemanal: 2,
    };
    return (order[a.id] ?? 99).compareTo(order[b.id] ?? 99);
  }

  ProductDetails? _findProduct(List<ProductDetails> products, String planId) {
    final matches = products.where((product) => product.id == planId).toList();
    if (matches.isEmpty) return null;
    final nonZero = matches.where((product) => product.rawPrice > 0).toList();
    final candidates = nonZero.isNotEmpty ? nonZero : matches;
    candidates.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return candidates.first;
  }

  String _productTitle(ProductDetails? product, SubscriptionPlan plan) {
    if (product == null) return plan.title;
    final raw = product.title.trim();
    final suffix = raw.indexOf('(');
    return suffix > 0 && raw.endsWith(')')
        ? raw.substring(0, suffix).trim()
        : raw;
  }

  String _productDescription(ProductDetails? product, SubscriptionPlan plan) {
    if (product == null) return plan.description;
    final description = product.description.trim();
    return description.isEmpty ? plan.description : description;
  }

  String _productPrice(ProductDetails? product, SubscriptionPlan plan) {
    return product?.price ?? plan.price;
  }

  String _pricePerMonth(ProductDetails? product, SubscriptionPlan plan) {
    final raw = product?.rawPrice ?? _fallbackRawPrice(plan);
    final symbol = product?.currencySymbol ?? 'R\$';
    if (plan.id == PurchaseService.planoAnual) {
      return '$symbol 19,90';
    }
    final monthly = switch (plan.id) {
      PurchaseService.planoAnual => raw / 12,
      PurchaseService.planoMensal => raw,
      PurchaseService.planoSemanal => raw * 52 / 12,
      _ => raw,
    };
    final value = monthly.toStringAsFixed(2);
    return '$symbol ${symbol == 'R\$' ? value.replaceAll('.', ',') : value}';
  }

  double _fallbackRawPrice(SubscriptionPlan plan) {
    switch (plan.id) {
      case PurchaseService.planoSemanal:
        return 9.90;
      case PurchaseService.planoMensal:
        return 29.90;
      case PurchaseService.planoAnual:
        return 238.80;
      default:
        return 0;
    }
  }
}

class _PlanOption extends StatelessWidget {
  final SubscriptionPlan plan;
  final ProductDetails? product;
  final bool isSelected;
  final bool isDarkMode;
  final Color textColor;
  final Color surfaceColor;
  final Color selectedSurfaceColor;
  final Color borderColor;
  final VoidCallback onTap;
  final String productTitle;
  final String productPrice;
  final String productDescription;
  final String monthlyPrice;
  final String monthlyLabel;
  final String? savingsLabel;
  final String? popularLabel;

  const _PlanOption({
    required this.plan,
    required this.product,
    required this.isSelected,
    required this.isDarkMode,
    required this.textColor,
    required this.surfaceColor,
    required this.selectedSurfaceColor,
    required this.borderColor,
    required this.onTap,
    required this.productTitle,
    required this.productPrice,
    required this.productDescription,
    required this.monthlyPrice,
    required this.monthlyLabel,
    required this.savingsLabel,
    required this.popularLabel,
  });

  @override
  Widget build(BuildContext context) {
    final muted =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? selectedSurfaceColor : surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? accent : borderColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  plan.icon,
                  color: textColor.withValues(alpha: 0.78),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected ? accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isSelected ? accent : borderColor,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: ThemeData.estimateBrightnessForColor(
                                              accent) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      productDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: muted.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          productPrice,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor.withValues(alpha: 0.88),
                          ),
                        ),
                        Text(
                          '$monthlyPrice $monthlyLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: muted.withValues(alpha: 0.86),
                          ),
                        ),
                        if (popularLabel != null)
                          _SmallPlanChip(
                            label: popularLabel!,
                            textColor: textColor,
                            borderColor: borderColor,
                            isDarkMode: isDarkMode,
                          ),
                        if (savingsLabel != null)
                          _SmallPlanChip(
                            label: savingsLabel!,
                            textColor: textColor,
                            borderColor: borderColor,
                            isDarkMode: isDarkMode,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallPlanChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color borderColor;
  final bool isDarkMode;

  const _SmallPlanChip({
    required this.label,
    required this.textColor,
    required this.borderColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
