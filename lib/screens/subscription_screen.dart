import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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
  static const String _heroAsset =
      'assets/images/subscription_before_after_full_hero.png';

  late final List<SubscriptionPlan> _visiblePlans;
  int _selectedPlanIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
  bool _capturedInitialPremiumState = false;
  bool _wasPremiumOnEntry = false;
  bool _handledPremiumActivation = false;
  bool _waitingForPremiumActivation = false;
  String _errorMessage = '';

  Color _pageColor(bool isDarkMode) =>
      isDarkMode ? AppTheme.darkBackgroundColor : const Color(0xFFF7FCFB);

  Color _bottomBarColor(bool isDarkMode) =>
      isDarkMode ? AppTheme.darkComponentColor : const Color(0xFFEFFBFA);

  Color _cardColor(bool isDarkMode) =>
      isDarkMode ? AppTheme.darkComponentColor : Colors.white;

  Color _selectedCardColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF122722) : const Color(0xFFEFFBFA);

  Color _softMintColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF143A35) : const Color(0xFFE8FAF6);

  Color _subtleBorderColor(bool isDarkMode) => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF0F172A).withValues(alpha: 0.06);

  Color _mutedTextColor(bool isDarkMode) =>
      isDarkMode ? AppTheme.darkMutedTextColor : const Color(0xFF667085);

  Color _accentColor(bool isDarkMode) =>
      isDarkMode ? AppTheme.primaryColorDarkMode : const Color(0xFF18B99E);

  Color _textColor(bool isDarkMode) =>
      isDarkMode ? AppTheme.darkTextColor : const Color(0xFF101828);

  @override
  void initState() {
    super.initState();
    final plans = [...SubscriptionPlan.getPlans()]..sort(_comparePlans);
    _visiblePlans = plans
        .where((plan) =>
            plan.id == PurchaseService.planoAnual ||
            plan.id == PurchaseService.planoMensal)
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visiblePlans.isEmpty && !_hasError) {
      _hasError = true;
      _errorMessage = context.tr.translate('error_loading_plans');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = _textColor(isDarkMode);
    final purchaseService = context.watch<PurchaseService>();
    final authService = context.watch<AuthService>();

    if (!_capturedInitialPremiumState) {
      _capturedInitialPremiumState = true;
      _wasPremiumOnEntry = purchaseService.isPremium;
    }
    _maybeHandlePremiumActivation(context, purchaseService);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    ));

    if (_hasError) {
      return _buildError(context, _errorMessage, isDarkMode, textColor);
    }

    final selectedPlan =
        _visiblePlans[_selectedPlanIndex.clamp(0, _visiblePlans.length - 1)];
    final selectedProduct = purchaseService.productForPlan(selectedPlan.id);
    final isBusy = _isLoading || purchaseService.isLoading;
    final shouldRetryProducts =
        authService.isAuthenticated && selectedProduct == null && !isBusy;
    final actionEnabled = authService.isAuthenticated
        ? (selectedProduct != null && !isBusy) || shouldRetryProducts
        : !isBusy;

    return Scaffold(
      backgroundColor: _pageColor(isDarkMode),
      appBar: _buildAppBar(
        context: context,
        purchaseService: purchaseService,
        authService: authService,
        isDarkMode: isDarkMode,
        textColor: textColor,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
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
              showActionLoading: isBusy,
              shouldRetryProducts: shouldRetryProducts,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required BuildContext context,
    required PurchaseService purchaseService,
    required AuthService authService,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final isBusy = _isLoading || purchaseService.isLoading;
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leadingWidth: 66,
      toolbarHeight: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
        child: _CircleIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          foregroundColor: textColor,
          backgroundColor: _cardColor(isDarkMode),
          borderColor: _subtleBorderColor(isDarkMode),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      title: Text(
        context.tr.translate('premium_plans'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge?.copyWith(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18, top: 8, bottom: 8),
          child: _CircleIconButton(
            icon: Icons.shield_outlined,
            tooltip: context.tr.translate('restore_purchases'),
            foregroundColor: _accentColor(isDarkMode),
            backgroundColor: _cardColor(isDarkMode),
            borderColor: _subtleBorderColor(isDarkMode),
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
        ),
      ],
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
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
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(context, isDarkMode, textColor),
                    const SizedBox(height: 16),
                    _buildSectionTitle(context, isDarkMode, textColor),
                    const SizedBox(height: 8),
                    _buildPlanOptions(
                      context,
                      purchaseService,
                      isDarkMode,
                      textColor,
                    ),
                    if (!authService.isAuthenticated) ...[
                      const SizedBox(height: 10),
                      _inlineHint(
                        context.tr.translate('access_account'),
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildPremiumBenefitsPreview(
                      context,
                      isDarkMode,
                      textColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumBenefitsPreview(
    BuildContext context,
    bool isDarkMode,
    Color textColor,
  ) {
    final accent = _accentColor(isDarkMode);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
        boxShadow: AppTheme.profileCardShadow(isDarkMode),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('subscription_premium_benefits_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          _PremiumBenefitChip(
            icon: Icons.block_rounded,
            label: context.tr.translate('premium_benefit_no_ads'),
            accentColor: accent,
            textColor: textColor,
            backgroundColor: _softMintColor(isDarkMode),
          ),
          const SizedBox(height: 8),
          _PremiumBenefitChip(
            icon: Icons.calendar_month_rounded,
            label: context.tr.translate('premium_benefit_daily_menu'),
            accentColor: accent,
            textColor: textColor,
            backgroundColor: _softMintColor(isDarkMode),
          ),
          const SizedBox(height: 8),
          _PremiumBenefitChip(
            icon: Icons.restaurant_menu_rounded,
            label: context.tr.translate('premium_benefit_diet'),
            accentColor: accent,
            textColor: textColor,
            backgroundColor: _softMintColor(isDarkMode),
          ),
          const SizedBox(height: 8),
          _PremiumBenefitChip(
            icon: Icons.auto_awesome_rounded,
            label: context.tr.translate('premium_benefit_shape'),
            accentColor: accent,
            textColor: textColor,
            backgroundColor: _softMintColor(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isDarkMode, Color textColor) {
    final accent = _accentColor(isDarkMode);

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: _cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
        boxShadow: AppTheme.profileCardShadow(isDarkMode),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _heroAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _HeroImageLabel(
              label: context.tr.translate('profile_shape_before'),
              accentColor: accent,
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: _HeroImageLabel(
              label: context.tr.translate('profile_shape_after'),
              accentColor: accent,
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        context.tr.translate('subscription_hero_title_prefix'),
                  ),
                  TextSpan(
                    text: context.tr
                        .translate('subscription_hero_title_highlight'),
                    style: TextStyle(color: accent),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                height: 1.02,
                letterSpacing: 0,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    bool isDarkMode,
    Color textColor,
  ) {
    return Row(
      children: [
        Icon(
          Icons.workspace_premium_rounded,
          color: textColor.withValues(alpha: 0.72),
          size: 22,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            context.tr.translate('subscription_choose_plan'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.78),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOptions(
    BuildContext context,
    PurchaseService purchaseService,
    bool isDarkMode,
    Color textColor,
  ) {
    final monthlyPlan = _visiblePlans.firstWhere(
      (plan) => plan.id == PurchaseService.planoMensal,
    );
    final annualPlan = _visiblePlans.firstWhere(
      (plan) => plan.id == PurchaseService.planoAnual,
    );
    final monthlyProduct =
        purchaseService.productForPlan(PurchaseService.planoMensal);
    final annualProduct =
        purchaseService.productForPlan(PurchaseService.planoAnual);
    final annualSavings = _annualSavingsInfo(
      monthlyProduct: monthlyProduct,
      monthlyPlan: monthlyPlan,
      annualProduct: annualProduct,
      annualPlan: annualPlan,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _visiblePlans.map((plan) {
        final index = _visiblePlans.indexWhere((item) => item.id == plan.id);
        final product = purchaseService.productForPlan(plan.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PremiumPlanCard(
            plan: plan,
            product: product,
            isSelected: index == _selectedPlanIndex,
            isDarkMode: isDarkMode,
            textColor: textColor,
            mutedTextColor: _mutedTextColor(isDarkMode),
            cardColor: _cardColor(isDarkMode),
            selectedCardColor: _selectedCardColor(isDarkMode),
            mintColor: _softMintColor(isDarkMode),
            borderColor: _subtleBorderColor(isDarkMode),
            accentColor: _accentColor(isDarkMode),
            onTap: () => setState(() => _selectedPlanIndex = index),
            productTitle: _productTitle(product, plan),
            productPrice: _productPrice(product, plan),
            monthlyPrice: _pricePerMonth(product, plan),
            monthlyLabel: context.tr.translate('per_month'),
            marketingDescription: _planMarketingDescription(context, plan),
            chargedLabel: _chargedLabel(context, product, plan),
            savingsHeadline: _savingsAmountLabel(context, annualSavings, plan),
            popularLabel: context.tr.translate('subscription_most_chosen'),
            savingsChipLabel: _savingsPercentLabel(
              context,
              annualSavings,
              plan,
            ),
            freeTrialLabel: _freeTrialLabel(context, product, plan),
            icon: _planIcon(plan),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar({
    required BuildContext context,
    required AuthService authService,
    required PurchaseService purchaseService,
    required SubscriptionPlan selectedPlan,
    required ProductDetails? selectedProduct,
    required bool actionEnabled,
    required bool showActionLoading,
    required bool shouldRetryProducts,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final accent = _accentColor(isDarkMode);

    return Container(
      decoration: BoxDecoration(
        color: _bottomBarColor(isDarkMode),
        border: Border(
          top: BorderSide(color: _subtleBorderColor(isDarkMode)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 5, 18, 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth =
                      math.min(230.0, constraints.maxWidth * 0.50);

                  return Row(
                    children: [
                      Container(
                        width: 42,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _softMintColor(isDarkMode),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          _planIcon(selectedPlan),
                          color: accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                                color: textColor.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
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
                                color: _mutedTextColor(isDarkMode),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: buttonWidth,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: actionEnabled
                              ? () {
                                  if (!authService.isAuthenticated) {
                                    _openLogin(context);
                                    return;
                                  }
                                  if (shouldRetryProducts) {
                                    _reloadStoreProducts(
                                        context, purchaseService);
                                    return;
                                  }
                                  _subscribe(context, purchaseService);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: accent,
                            foregroundColor: AppTheme.onColor(accent),
                            disabledBackgroundColor:
                                _cardColor(isDarkMode).withValues(alpha: 0.8),
                            disabledForegroundColor:
                                _mutedTextColor(isDarkMode),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: showActionLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        authService.isAuthenticated
                                            ? shouldRetryProducts
                                                ? context.tr
                                                    .translate('try_again')
                                                : context.tr
                                                    .translate('continue')
                                            : context.tr.translate('sign_in'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 22,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
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
            Icons.lock_outline_rounded,
            size: 13,
            color: textColor.withValues(alpha: 0.50),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr.translate('secure_google_play'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.58),
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
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
    final bg = backgroundColor ?? _cardColor(isDarkMode);

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
                letterSpacing: 0,
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
      backgroundColor: _pageColor(isDarkMode),
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
                      color: _cardColor(isDarkMode),
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
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _mutedTextColor(isDarkMode),
                      height: 1.45,
                      letterSpacing: 0,
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
                        backgroundColor: _accentColor(isDarkMode),
                        foregroundColor:
                            AppTheme.onColor(_accentColor(isDarkMode)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        context.tr.translate('try_again_button'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
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

  void _maybeHandlePremiumActivation(
    BuildContext context,
    PurchaseService purchaseService,
  ) {
    if (_handledPremiumActivation ||
        _wasPremiumOnEntry ||
        !_waitingForPremiumActivation ||
        !purchaseService.isPremium) {
      return;
    }

    _handledPremiumActivation = true;
    _waitingForPremiumActivation = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final hostContext = navigator.context;

      if (navigator.canPop()) {
        navigator.pop(true);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!hostContext.mounted) return;
        _showPremiumActivatedSheet(hostContext);
      });
    });
  }

  void _showPremiumActivatedSheet(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _textColor(isDarkMode);
    final accent = _accentColor(isDarkMode);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: _cardColor(isDarkMode),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _subtleBorderColor(isDarkMode)),
                  boxShadow: AppTheme.profileCardShadow(isDarkMode),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _softMintColor(isDarkMode),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: accent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr.translate('premium_activated_title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.tr
                                    .translate('premium_activated_subtitle'),
                                style: TextStyle(
                                  color: _mutedTextColor(isDarkMode),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _premiumBenefitRow(
                      context,
                      icon: Icons.restaurant_menu_rounded,
                      textKey: 'premium_benefit_diet',
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                    ),
                    _premiumBenefitRow(
                      context,
                      icon: Icons.calendar_month_rounded,
                      textKey: 'premium_benefit_daily_menu',
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                    ),
                    _premiumBenefitRow(
                      context,
                      icon: Icons.auto_awesome_rounded,
                      textKey: 'premium_benefit_shape',
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                    ),
                    _premiumBenefitRow(
                      context,
                      icon: Icons.block_rounded,
                      textKey: 'premium_benefit_no_ads',
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: accent,
                          foregroundColor: AppTheme.onColor(accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          context.tr.translate('premium_activated_cta'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _premiumBenefitRow(
    BuildContext context, {
    required IconData icon,
    required String textKey,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final accent = _accentColor(isDarkMode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _softMintColor(isDarkMode),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr.translate(textKey),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.86),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases(
      BuildContext context, PurchaseService purchaseService) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      _waitingForPremiumActivation = true;
      await purchaseService.restorePurchases();
      if (purchaseService.errorMessage != null) {
        final message = context.tr.translate('subscription_error');
        _waitingForPremiumActivation = false;
        setState(() {
          _hasError = false;
          _errorMessage = message;
        });
        _showPurchaseError(context, message);
      }
    } catch (_) {
      final message = context.tr.translate('subscription_error');
      _waitingForPremiumActivation = false;
      setState(() {
        _hasError = false;
        _errorMessage = message;
      });
      _showPurchaseError(context, message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadStoreProducts(
      BuildContext context, PurchaseService purchaseService) async {
    setState(() {
      _errorMessage = '';
    });

    await purchaseService.reloadProducts();

    if (!mounted) return;
    final storeError = purchaseService.errorMessage;
    if (storeError != null && storeError.isNotEmpty) {
      final message = context.tr.translate('subscription_error');
      setState(() {
        _hasError = false;
        _errorMessage = message;
      });
      _showPurchaseError(context, message);
    }
  }

  Future<void> _subscribe(
      BuildContext context, PurchaseService purchaseService) async {
    final selectedPlan =
        _visiblePlans[_selectedPlanIndex.clamp(0, _visiblePlans.length - 1)];
    final selectedProduct = purchaseService.productForPlan(selectedPlan.id);
    if (selectedProduct == null) {
      final message = context.tr.translate('try_again_later');
      setState(() {
        _hasError = false;
        _errorMessage = message;
      });
      _showPurchaseError(context, message);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      _waitingForPremiumActivation = true;
      await purchaseService.buySubscription(selectedProduct);
      if (purchaseService.errorMessage != null) {
        final message = context.tr.translate('subscription_error');
        _waitingForPremiumActivation = false;
        setState(() {
          _hasError = false;
          _errorMessage = message;
        });
        _showPurchaseError(context, message);
      }
    } catch (_) {
      final message = context.tr.translate('subscription_error');
      _waitingForPremiumActivation = false;
      setState(() {
        _hasError = false;
        _errorMessage = message;
      });
      _showPurchaseError(context, message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPurchaseError(BuildContext context, String message) {
    if (!mounted || message.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  String _productTitle(ProductDetails? product, SubscriptionPlan plan) {
    if (product == null) return _localizedPlanTitle(context, plan);
    final raw = product.title.trim();
    final suffix = raw.indexOf('(');
    return suffix > 0 && raw.endsWith(')')
        ? raw.substring(0, suffix).trim()
        : raw;
  }

  String _productPrice(ProductDetails? product, SubscriptionPlan plan) {
    return _recurringPricingPhase(product)?.formattedPrice ??
        product?.price ??
        plan.price;
  }

  String _pricePerMonth(ProductDetails? product, SubscriptionPlan plan) {
    final raw = _planRawPrice(product, plan);
    final symbol = _currencySymbol(product, _recurringPricingPhase(product));
    final monthly = switch (plan.id) {
      PurchaseService.planoAnual => raw / 12,
      PurchaseService.planoMensal => raw,
      PurchaseService.planoSemanal => raw * 52 / 12,
      _ => raw,
    };
    return _formatMoney(symbol, monthly);
  }

  PricingPhaseWrapper? _recurringPricingPhase(ProductDetails? product) {
    final offer = _androidOffer(product);
    if (offer == null) return null;

    for (final phase in offer.pricingPhases) {
      if (phase.recurrenceMode == RecurrenceMode.infiniteRecurring &&
          phase.priceAmountMicros > 0) {
        return phase;
      }
    }

    for (final phase in offer.pricingPhases.reversed) {
      if (phase.priceAmountMicros > 0) {
        return phase;
      }
    }

    return null;
  }

  String? _freeTrialLabel(
    BuildContext context,
    ProductDetails? product,
    SubscriptionPlan plan,
  ) {
    final phase = _freeTrialPhase(product);
    final days = _trialDaysFromBillingPeriod(phase?.billingPeriod) ??
        (plan.freeTrialDays > 0 ? plan.freeTrialDays : null);
    if (days != null && days > 0) {
      return context.tr
          .translate('subscription_free_trial_days')
          .replaceAll('{days}', days.toString());
    }

    return null;
  }

  PricingPhaseWrapper? _freeTrialPhase(ProductDetails? product) {
    final offer = _androidOffer(product);
    if (offer == null) return null;

    for (final phase in offer.pricingPhases) {
      if (phase.priceAmountMicros == 0 &&
          phase.recurrenceMode != RecurrenceMode.infiniteRecurring) {
        return phase;
      }
    }

    return null;
  }

  int? _trialDaysFromBillingPeriod(String? billingPeriod) {
    if (billingPeriod == null || billingPeriod.isEmpty) return null;

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

  SubscriptionOfferDetailsWrapper? _androidOffer(ProductDetails? product) {
    if (product is! GooglePlayProductDetails) return null;

    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null ||
        offers == null ||
        index < 0 ||
        index >= offers.length) {
      return null;
    }

    return offers[index];
  }

  double _planRawPrice(ProductDetails? product, SubscriptionPlan plan) {
    final recurringPhase = _recurringPricingPhase(product);
    if (recurringPhase != null && recurringPhase.priceAmountMicros > 0) {
      return recurringPhase.priceAmountMicros / 1000000;
    }
    return product?.rawPrice ?? _fallbackRawPrice(plan);
  }

  _AnnualSavingsInfo? _annualSavingsInfo({
    required ProductDetails? monthlyProduct,
    required SubscriptionPlan monthlyPlan,
    required ProductDetails? annualProduct,
    required SubscriptionPlan annualPlan,
  }) {
    final monthlyPrice = _planRawPrice(monthlyProduct, monthlyPlan);
    final annualPrice = _planRawPrice(annualProduct, annualPlan);
    final yearlyMonthlyPrice = monthlyPrice * 12;
    final savings = yearlyMonthlyPrice - annualPrice;

    if (monthlyPrice <= 0 || annualPrice <= 0 || savings <= 0) {
      return null;
    }

    return _AnnualSavingsInfo(
      amount: savings,
      percentage: (savings / yearlyMonthlyPrice * 100).round(),
      currencySymbol: _currencySymbol(
        annualProduct ?? monthlyProduct,
        _recurringPricingPhase(annualProduct) ??
            _recurringPricingPhase(monthlyProduct),
      ),
    );
  }

  String _currencySymbol(
    ProductDetails? product, [
    PricingPhaseWrapper? recurringPhase,
  ]) {
    final recurringSymbol =
        _currencySymbolFromFormattedPrice(recurringPhase?.formattedPrice);
    if (recurringSymbol != null) return recurringSymbol;

    final symbol = product?.currencySymbol.trim();
    if (symbol == null ||
        symbol.isEmpty ||
        symbol.toLowerCase().contains('grátis') ||
        symbol.toLowerCase().contains('free')) {
      return 'R\$';
    }
    return symbol;
  }

  String? _currencySymbolFromFormattedPrice(String? formattedPrice) {
    final price = formattedPrice?.trim();
    if (price == null || price.isEmpty || !RegExp(r'\d').hasMatch(price)) {
      return null;
    }

    final leading = RegExp(r'^\s*([^\d\s]+)').firstMatch(price)?.group(1);
    if (leading != null && leading.trim().isNotEmpty) {
      return leading.trim();
    }

    final trailing = RegExp(r'([^\d\s]+)\s*$').firstMatch(price)?.group(1);
    if (trailing != null && trailing.trim().isNotEmpty) {
      return trailing.trim();
    }

    return null;
  }

  String _formatMoney(String symbol, double value) {
    final normalizedSymbol = symbol.trim().isEmpty ? 'R\$' : symbol.trim();
    final decimalValue = value.toStringAsFixed(2);
    final formattedValue = normalizedSymbol.contains('R\$')
        ? decimalValue.replaceAll('.', ',')
        : decimalValue;
    return '$normalizedSymbol $formattedValue';
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

  String _planMarketingDescription(
    BuildContext context,
    SubscriptionPlan plan,
  ) {
    return switch (plan.id) {
      PurchaseService.planoAnual =>
        context.tr.translate('subscription_annual_card_description'),
      PurchaseService.planoMensal =>
        context.tr.translate('subscription_monthly_card_description'),
      _ => context.tr.translate('subscription_weekly_card_description'),
    };
  }

  String _localizedPlanTitle(
    BuildContext context,
    SubscriptionPlan plan,
  ) {
    return switch (plan.id) {
      PurchaseService.planoAnual =>
        context.tr.translate('subscription_annual_plan_title'),
      PurchaseService.planoMensal =>
        context.tr.translate('subscription_monthly_plan_title'),
      _ => context.tr.translate('subscription_weekly_plan_title'),
    };
  }

  String _chargedLabel(
    BuildContext context,
    ProductDetails? product,
    SubscriptionPlan plan,
  ) {
    if (plan.id != PurchaseService.planoAnual) return '';
    return context.tr
        .translate('subscription_charged_annually')
        .replaceAll('{price}', _productPrice(product, plan));
  }

  String _savingsPercentLabel(
    BuildContext context,
    _AnnualSavingsInfo? savings,
    SubscriptionPlan plan,
  ) {
    if (plan.id != PurchaseService.planoAnual ||
        savings == null ||
        savings.percentage <= 0) {
      return '';
    }
    return context.tr
        .translate('subscription_economize_percentage')
        .replaceAll('{percentage}', savings.percentage.toString());
  }

  String _savingsAmountLabel(
    BuildContext context,
    _AnnualSavingsInfo? savings,
    SubscriptionPlan plan,
  ) {
    if (plan.id != PurchaseService.planoAnual || savings == null) return '';
    return context.tr
        .translate('subscription_annual_savings_amount')
        .replaceAll(
          '{amount}',
          _formatMoney(savings.currencySymbol, savings.amount),
        );
  }

  IconData _planIcon(SubscriptionPlan plan) {
    return switch (plan.id) {
      PurchaseService.planoAnual => Icons.diamond_outlined,
      PurchaseService.planoMensal => Icons.star_outline_rounded,
      _ => plan.icon,
    };
  }
}

class _HeroImageLabel extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _HeroImageLabel({
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: accentColor.withValues(alpha: 0.64)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AnnualSavingsInfo {
  final double amount;
  final int percentage;
  final String currencySymbol;

  const _AnnualSavingsInfo({
    required this.amount,
    required this.percentage,
    required this.currencySymbol,
  });
}

class _PremiumBenefitChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final Color textColor;
  final Color backgroundColor;

  const _PremiumBenefitChip({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 17,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.82),
              fontSize: 11.6,
              fontWeight: FontWeight.w800,
              height: 1.12,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final ProductDetails? product;
  final bool isSelected;
  final bool isDarkMode;
  final Color textColor;
  final Color mutedTextColor;
  final Color cardColor;
  final Color selectedCardColor;
  final Color mintColor;
  final Color borderColor;
  final Color accentColor;
  final VoidCallback onTap;
  final String productTitle;
  final String productPrice;
  final String monthlyPrice;
  final String monthlyLabel;
  final String marketingDescription;
  final String chargedLabel;
  final String savingsHeadline;
  final String popularLabel;
  final String savingsChipLabel;
  final String? freeTrialLabel;
  final IconData icon;

  const _PremiumPlanCard({
    required this.plan,
    required this.product,
    required this.isSelected,
    required this.isDarkMode,
    required this.textColor,
    required this.mutedTextColor,
    required this.cardColor,
    required this.selectedCardColor,
    required this.mintColor,
    required this.borderColor,
    required this.accentColor,
    required this.onTap,
    required this.productTitle,
    required this.productPrice,
    required this.monthlyPrice,
    required this.monthlyLabel,
    required this.marketingDescription,
    required this.chargedLabel,
    required this.savingsHeadline,
    required this.popularLabel,
    required this.savingsChipLabel,
    required this.freeTrialLabel,
    required this.icon,
  });

  bool get _isAnnual => plan.id == PurchaseService.planoAnual;

  @override
  Widget build(BuildContext context) {
    if (_isAnnual) {
      return _buildAnnualCard(context);
    }
    return _buildMonthlyCard(context);
  }

  Widget _buildAnnualCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
          decoration: BoxDecoration(
            color: isSelected ? selectedCardColor : cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? accentColor : borderColor,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: AppTheme.profileCardShadow(isDarkMode),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (freeTrialLabel != null) ...[
                    _TopBadge(
                      label: freeTrialLabel!,
                      icon: Icons.timer_rounded,
                      accentColor: accentColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _TopBadge(
                    label: popularLabel,
                    icon: Icons.local_fire_department_rounded,
                    accentColor: const Color(0xFF22C55E),
                  ),
                  const Spacer(),
                  _SelectionIndicator(
                    isSelected: isSelected,
                    accentColor: accentColor,
                    borderColor: borderColor,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlanIconBox(
                    icon: icon,
                    accentColor: accentColor,
                    backgroundColor: mintColor,
                    size: 46,
                    radius: 18,
                    iconSize: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          marketingDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w600,
                            height: 1.18,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _PriceLine(
                          price: monthlyPrice,
                          period: monthlyLabel,
                          accentColor: accentColor,
                          textColor: textColor,
                          selected: true,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          chargedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mutedTextColor.withValues(alpha: 0.9),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        if (savingsHeadline.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SmallSavingsChip(
                              label: savingsHeadline,
                              accentColor: accentColor,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
          decoration: BoxDecoration(
            color: isSelected ? selectedCardColor : cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? accentColor : borderColor,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: AppTheme.profileCardShadow(isDarkMode),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanIconBox(
                icon: icon,
                accentColor: isSelected ? accentColor : mutedTextColor,
                backgroundColor:
                    isSelected ? mintColor : mintColor.withValues(alpha: 0.42),
                size: 46,
                radius: 18,
                iconSize: 25,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (freeTrialLabel != null) ...[
                                _TopBadge(
                                  label: freeTrialLabel!,
                                  icon: Icons.timer_rounded,
                                  accentColor: accentColor,
                                ),
                                const SizedBox(height: 5),
                              ],
                              Text(
                                productTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SelectionIndicator(
                          isSelected: isSelected,
                          accentColor: accentColor,
                          borderColor: borderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      marketingDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                        height: 1.22,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _PriceLine(
                      price: monthlyPrice,
                      period: monthlyLabel,
                      accentColor: accentColor,
                      textColor: textColor,
                      selected: isSelected,
                    ),
                    if (savingsChipLabel.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _SmallSavingsChip(
                        label: savingsChipLabel,
                        accentColor: accentColor,
                        isDarkMode: isDarkMode,
                      ),
                    ],
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: onPressed == null
                  ? foregroundColor.withValues(alpha: 0.38)
                  : foregroundColor,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanIconBox extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final double size;
  final double radius;
  final double iconSize;

  const _PlanIconBox({
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.size,
    required this.radius,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        color: accentColor,
        size: iconSize,
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;

  const _TopBadge({
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  final Color accentColor;
  final Color borderColor;

  const _SelectionIndicator({
    required this.isSelected,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isSelected ? accentColor : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isSelected ? accentColor : borderColor,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 18,
            )
          : null,
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String price;
  final String period;
  final Color accentColor;
  final Color textColor;
  final bool selected;

  const _PriceLine({
    required this.price,
    required this.period,
    required this.accentColor,
    required this.textColor,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          price,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? accentColor : textColor,
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        Text(
          period,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.66),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SmallSavingsChip extends StatelessWidget {
  final String label;
  final Color accentColor;
  final bool isDarkMode;

  const _SmallSavingsChip({
    required this.label,
    required this.accentColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDarkMode
            ? accentColor.withValues(alpha: 0.16)
            : accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accentColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
