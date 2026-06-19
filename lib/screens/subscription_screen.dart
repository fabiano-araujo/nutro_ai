import 'dart:math' as math;

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
  static const String _heroAsset =
      'assets/images/subscription_transformation_hero.png';

  late final List<SubscriptionPlan> _visiblePlans;
  int _selectedPlanIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
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
    final selectedProduct =
        _findProduct(purchaseService.products, selectedPlan.id);
    final isBusy = _isLoading || purchaseService.isLoading;
    final actionEnabled = authService.isAuthenticated
        ? selectedProduct != null && !isBusy
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
      leadingWidth: 78,
      toolbarHeight: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
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
          padding: const EdgeInsets.only(right: 24, top: 8, bottom: 8),
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
          padding: const EdgeInsets.fromLTRB(26, 4, 26, 14),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(context, isDarkMode, textColor),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, isDarkMode, textColor),
                    const SizedBox(height: 14),
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
                    if (purchaseService.errorMessage != null &&
                        purchaseService.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _inlineHint(
                        purchaseService.errorMessage!,
                        icon: Icons.info_outline_rounded,
                        foregroundColor: const Color(0xFF8A4C00),
                        backgroundColor: const Color(0xFFFFF1DE),
                        isDarkMode: isDarkMode,
                        textColor: textColor,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildGuaranteeTile(context, isDarkMode, textColor),
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
    final accent = _accentColor(isDarkMode);

    return Container(
      height: 252,
      decoration: BoxDecoration(
        color: _cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
        boxShadow: AppTheme.profileCardShadow(isDarkMode),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 5, 0, 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: context.tr
                              .translate('subscription_hero_title_prefix'),
                        ),
                        TextSpan(
                          text: context.tr
                              .translate('subscription_hero_title_highlight'),
                          style: TextStyle(color: accent),
                        ),
                      ],
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr.translate('subscription_hero_subtitle'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _mutedTextColor(isDarkMode),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.42,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  _buildResultChip(context, isDarkMode, textColor),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 7,
            child: _TransformationHeroImage(
              assetPath: _heroAsset,
              accentColor: accent,
              backgroundColor: _softMintColor(isDarkMode),
              borderColor: _subtleBorderColor(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultChip(
    BuildContext context,
    bool isDarkMode,
    Color textColor,
  ) {
    final accent = _accentColor(isDarkMode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: _cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
        boxShadow: AppTheme.profileCardShadow(isDarkMode),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _softMintColor(isDarkMode),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: accent,
              size: 23,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: context.tr.translate('subscription_result_prefix'),
                  ),
                  TextSpan(
                    text: context.tr.translate('subscription_result_time'),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _mutedTextColor(isDarkMode),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0,
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr.translate('subscription_choose_plan'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.78),
              fontSize: 17,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _visiblePlans.map((plan) {
        final index = _visiblePlans.indexWhere((item) => item.id == plan.id);
        final product = _findProduct(purchaseService.products, plan.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
            savingsHeadline: _savingsAmountLabel(context, plan.savePercentage),
            savingsSubline:
                context.tr.translate('subscription_annual_savings_compare'),
            popularLabel: context.tr.translate('subscription_most_chosen'),
            savingsChipLabel:
                _savingsPercentLabel(context, plan.savePercentage),
            icon: _planIcon(plan),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGuaranteeTile(
    BuildContext context,
    bool isDarkMode,
    Color textColor,
  ) {
    final accent = _accentColor(isDarkMode);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
      decoration: BoxDecoration(
        color: _cardColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
        boxShadow: AppTheme.profileCardShadow(isDarkMode),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: accent,
            size: 31,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr.translate('subscription_guarantee_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.88),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr.translate('subscription_guarantee_subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _mutedTextColor(isDarkMode),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _mutedTextColor(isDarkMode),
            size: 25,
          ),
        ],
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
    final accent = _accentColor(isDarkMode);

    return Container(
      decoration: BoxDecoration(
        color: _bottomBarColor(isDarkMode),
        border: Border(
          top: BorderSide(color: _subtleBorderColor(isDarkMode)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth =
                      math.min(210.0, constraints.maxWidth * 0.46);

                  return Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _softMintColor(isDarkMode),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _planIcon(selectedPlan),
                          color: accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                fontSize: 15,
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
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: buttonWidth,
                        height: 60,
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
                            backgroundColor: accent,
                            foregroundColor: AppTheme.onColor(accent),
                            disabledBackgroundColor:
                                _cardColor(isDarkMode).withValues(alpha: 0.8),
                            disabledForegroundColor:
                                _mutedTextColor(isDarkMode),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _isLoading
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
                                            ? context.tr.translate('continue')
                                            : context.tr.translate('sign_in'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 25,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
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
            size: 15,
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
              fontSize: 12,
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
    final selectedPlan =
        _visiblePlans[_selectedPlanIndex.clamp(0, _visiblePlans.length - 1)];
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

  String _planMarketingDescription(
    BuildContext context,
    SubscriptionPlan plan,
  ) {
    return switch (plan.id) {
      PurchaseService.planoAnual =>
        context.tr.translate('subscription_annual_card_description'),
      PurchaseService.planoMensal =>
        context.tr.translate('subscription_monthly_card_description'),
      _ => plan.description,
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

  String _savingsPercentLabel(BuildContext context, int percentage) {
    if (percentage <= 0) return '';
    return context.tr
        .translate('subscription_economize_percentage')
        .replaceAll('{percentage}', percentage.toString());
  }

  String _savingsAmountLabel(BuildContext context, int percentage) {
    if (percentage <= 0) return '';
    return context.tr.translate('subscription_annual_savings_amount');
  }

  IconData _planIcon(SubscriptionPlan plan) {
    return switch (plan.id) {
      PurchaseService.planoAnual => Icons.diamond_outlined,
      PurchaseService.planoMensal => Icons.star_outline_rounded,
      _ => plan.icon,
    };
  }
}

class _TransformationHeroImage extends StatelessWidget {
  final String assetPath;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;

  const _TransformationHeroImage({
    required this.assetPath,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Center(
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.94),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.75),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
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
  final String savingsSubline;
  final String popularLabel;
  final String savingsChipLabel;
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
    required this.savingsSubline,
    required this.popularLabel,
    required this.savingsChipLabel,
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                  _TopBadge(
                    label: popularLabel,
                    icon: Icons.local_fire_department_rounded,
                    accentColor: accentColor,
                  ),
                  const Spacer(),
                  _SelectionIndicator(
                    isSelected: isSelected,
                    accentColor: accentColor,
                    borderColor: borderColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlanIconBox(
                    icon: icon,
                    accentColor: accentColor,
                    backgroundColor: mintColor,
                    size: 72,
                    radius: 28,
                    iconSize: 36,
                  ),
                  const SizedBox(width: 16),
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
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          marketingDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PriceLine(
                          price: monthlyPrice,
                          period: monthlyLabel,
                          accentColor: accentColor,
                          textColor: textColor,
                          selected: true,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          chargedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mutedTextColor.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SavingsBadge(
                    label: savingsChipLabel,
                    accentColor: accentColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: mintColor.withValues(alpha: isDarkMode ? 0.45 : 0.78),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      color: accentColor,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$savingsHeadline\n',
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : const Color(0xFF176B5F),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(text: savingsSubline),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.18,
                          letterSpacing: 0,
                        ),
                      ),
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

  Widget _buildMonthlyCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                size: 70,
                radius: 28,
                iconSize: 34,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            productTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SelectionIndicator(
                          isSelected: isSelected,
                          accentColor: accentColor,
                          borderColor: borderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      marketingDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PriceLine(
                      price: monthlyPrice,
                      period: monthlyLabel,
                      accentColor: accentColor,
                      textColor: textColor,
                      selected: isSelected,
                    ),
                    if (savingsChipLabel.isNotEmpty) ...[
                      const SizedBox(height: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
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
      width: 32,
      height: 32,
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
              size: 21,
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
            fontSize: 22,
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
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SavingsBadge extends StatelessWidget {
  final String label;
  final Color accentColor;
  final bool isDarkMode;

  const _SavingsBadge({
    required this.label,
    required this.accentColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final parts = label.split(' ');
    final prefix = parts.isNotEmpty ? parts.first : label;
    final percentage = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return Container(
      width: 96,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDarkMode
            ? accentColor.withValues(alpha: 0.14)
            : const Color(0xFFE1F7F1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prefix,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          if (percentage.isNotEmpty)
            Text(
              percentage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentColor,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 0.98,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
