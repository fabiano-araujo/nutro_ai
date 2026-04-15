import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutro_ai/i18n/app_localizations_extension.dart';
import 'package:nutro_ai/models/subscription_plan.dart';
import 'package:nutro_ai/screens/login_screen.dart';
import 'package:nutro_ai/services/auth_service.dart';
import 'package:nutro_ai/services/purchase_service.dart';
import 'package:provider/provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final List<SubscriptionPlan> _plans;
  late final List<String> _comparisonBenefits;
  int _selectedPlanIndex = 0;
  bool _showAllPlans = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _plans = [...SubscriptionPlan.getPlans()]..sort(_comparePlans);
    _comparisonBenefits = _plans
        .firstWhere((p) => p.id == PurchaseService.planoAnual,
            orElse: () => _plans.first)
        .features;
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
    final purchaseService = context.watch<PurchaseService>();
    final authService = context.watch<AuthService>();

    if (_hasError) {
      return _buildError(
          context, purchaseService.errorMessage ?? _errorMessage);
    }

    final selectedPlan = _plans[_selectedPlanIndex.clamp(0, _plans.length - 1)];
    final selectedProduct =
        _findProduct(purchaseService.products, selectedPlan.id);
    final actionEnabled = authService.isAuthenticated
        ? selectedProduct != null && !_isLoading && !purchaseService.isLoading
        : !_isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6EF),
      body: Stack(
        children: [
          _buildBackdrop(),
          _buildScrollableContent(context, authService, purchaseService,
              selectedPlan, selectedProduct),
          _buildBottomBar(
            context,
            authService,
            purchaseService,
            selectedPlan,
            selectedProduct,
            actionEnabled,
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    return Column(
      children: [
        Expanded(
          flex: 9,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF96DF31),
                  Color(0xFF2FA96F),
                  Color(0xFF19876F),
                ],
              ),
            ),
          ),
        ),
        Expanded(flex: 11, child: Container(color: const Color(0xFFF6F6EF))),
      ],
    );
  }

  Widget _buildScrollableContent(
    BuildContext context,
    AuthService authService,
    PurchaseService purchaseService,
    SubscriptionPlan selectedPlan,
    ProductDetails? selectedProduct,
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 190),
        child: Column(
          children: [
            Row(
              children: [
                _topCircleButton(
                    Icons.close_rounded, () => Navigator.of(context).pop()),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isLoading || purchaseService.isLoading
                      ? null
                      : () {
                          if (!authService.isAuthenticated) {
                            _openLogin(context);
                            return;
                          }
                          _restorePurchases(context, purchaseService);
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.tr.translate('restore_purchases')),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D6D32),
                    backgroundColor: Colors.white.withValues(alpha: 0.86),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 8,
                    left: 20,
                    child: Icon(Icons.auto_awesome_rounded,
                        color: Colors.white.withValues(alpha: 0.42), size: 22),
                  ),
                  Positioned(
                    top: 34,
                    right: 28,
                    child: Icon(Icons.auto_awesome_rounded,
                        color: const Color(0xFFE3FF90).withValues(alpha: 0.72),
                        size: 18),
                  ),
                  Positioned(
                    left: 50,
                    bottom: 30,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                  Container(
                    width: 184,
                    height: 184,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(52),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/images/logo_foreground.png',
                        fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Nutro AI',
                            style: GoogleFonts.dmSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF171717))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7FD548),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.tr.translate('premium'),
                            style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildHeadline(context),
                    const SizedBox(height: 14),
                    Text(
                      context.tr.translate('unlock_potential'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF637062),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFeaturedCard(context, selectedPlan, selectedProduct),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showAllPlans = !_showAllPlans),
                      icon: Icon(_showAllPlans
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded),
                      label: Text(context.tr.translate(
                        _showAllPlans ? 'hide_other_plans' : 'show_more_plans',
                      )),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF98A08E),
                        textStyle: GoogleFonts.dmSans(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_showAllPlans)
                      ..._plans.where((p) => p.id != selectedPlan.id).map(
                            (plan) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => setState(
                                  () => _selectedPlanIndex = _plans
                                      .indexWhere((item) => item.id == plan.id),
                                ),
                                borderRadius: BorderRadius.circular(24),
                                child: Ink(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F8F1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: const Color(0xFFE1E7DB)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: plan.color
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child:
                                            Icon(plan.icon, color: plan.color),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(plan.title,
                                                style: GoogleFonts.dmSans(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: const Color(
                                                        0xFF1A1A1A))),
                                            const SizedBox(height: 4),
                                            Text(
                                              _findProduct(
                                                          purchaseService
                                                              .products,
                                                          plan.id)
                                                      ?.price ??
                                                  plan.price,
                                              style: GoogleFonts.dmSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF859183)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: Color(0xFF9BA598)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                    if (!authService.isAuthenticated)
                      _inlineHint(context.tr.translate('access_account')),
                    if (purchaseService.errorMessage != null &&
                        purchaseService.errorMessage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _inlineHint(
                          purchaseService.errorMessage!,
                          fg: const Color(0xFF8A4C00),
                          bg: const Color(0xFFFFF1DE),
                          icon: Icons.info_outline_rounded,
                        ),
                      ),
                    const SizedBox(height: 22),
                    _buildBenefitsTable(context),
                    const SizedBox(height: 20),
                    Text(
                      context.tr.translate('subscription_terms'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF95A08F),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AuthService authService,
    PurchaseService purchaseService,
    SubscriptionPlan selectedPlan,
    ProductDetails? selectedProduct,
    bool actionEnabled,
  ) {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_productTitle(selectedProduct, selectedPlan),
                            style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF171717))),
                        const SizedBox(height: 4),
                        Text(
                          authService.isAuthenticated
                              ? _productPrice(selectedProduct, selectedPlan)
                              : context.tr.translate('access_account'),
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF839082)),
                        ),
                      ],
                    ),
                  ),
                  if (selectedPlan.savePercentage > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F7DA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${selectedPlan.savePercentage}% OFF',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2E8B2A)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 58,
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
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFB9C0B6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          authService.isAuthenticated
                              ? context.tr.translate('continue')
                              : context.tr.translate('sign_in'),
                          style: GoogleFonts.dmSans(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 16, color: Color(0xFF97A391)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.tr.translate('secure_google_play'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF97A391)),
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

  Widget _buildBenefitsTable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF4),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(context.tr.translate('whats_included'),
                    style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1B1B1B))),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  context.tr.translate('free_plan'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFADB4A7)),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  context.tr.translate('premium'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5AB84E)),
                ),
              ),
            ],
          ),
          ..._comparisonBenefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      benefit,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5B6557),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 72,
                    child: Center(
                        child: Icon(Icons.remove_rounded,
                            color: Color(0xFFC8CEC4), size: 20)),
                  ),
                  SizedBox(
                    width: 72,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE7F8DE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Color(0xFF4BAF47), size: 18),
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

  Widget _buildHeadline(BuildContext context) {
    final parts =
        context.tr.translate('subscription_headline').split('{highlight}');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.first),
          const TextSpan(
              text: '4.2x', style: TextStyle(color: Color(0xFF98D532))),
          if (parts.length > 1) TextSpan(text: parts.last),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.archivoBlack(
        height: 1.02,
        fontSize: 34,
        color: const Color(0xFF161616),
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    SubscriptionPlan selectedPlan,
    ProductDetails? selectedProduct,
  ) {
    final savings = selectedPlan.savePercentage > 0
        ? context.tr.translate('save_percentage').replaceAll(
              '{percentage}',
              selectedPlan.savePercentage.toString(),
            )
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFF7FFF1), Color(0xFFEDF7EE)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF58B957), width: 2.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (selectedPlan.id == PurchaseService.planoAnual)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58C04D),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr.translate('popular'),
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              const Spacer(),
              if (savings != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F7DA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    savings,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2E8B2A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_productTitle(selectedProduct, selectedPlan),
                        style: GoogleFonts.dmSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF171717))),
                    const SizedBox(height: 6),
                    Text(_productPrice(selectedProduct, selectedPlan),
                        style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF80907B))),
                    const SizedBox(height: 2),
                    Text(_productDescription(selectedProduct, selectedPlan),
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9AA08F))),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _pricePerMonth(selectedProduct, selectedPlan),
                    style: GoogleFonts.archivoBlack(
                        fontSize: 30,
                        height: 0.96,
                        color: const Color(0xFF171717)),
                  ),
                  const SizedBox(height: 4),
                  Text('por mês',
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF92A08C))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6EF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(32)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 54, color: Color(0xFFEA6A3B)),
                const SizedBox(height: 18),
                Text(context.tr.translate('oops'),
                    style: GoogleFonts.dmSans(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: const Color(0xFF687066),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() {
                      _hasError = false;
                      _errorMessage = '';
                    }),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF171717),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        context.tr.translate('try_again_button'),
                        style: GoogleFonts.dmSans(
                            fontSize: 16, fontWeight: FontWeight.w900),
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
  }

  Widget _topCircleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: const Color(0xFF2B6E36))),
      ),
    );
  }

  Widget _inlineHint(
    String text, {
    IconData icon = Icons.lock_outline_rounded,
    Color fg = const Color(0xFF5C6A5E),
    Color bg = const Color(0xFFF1F5ED),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
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
    final monthly = switch (plan.id) {
      PurchaseService.planoAnual => raw / 12,
      PurchaseService.planoMensal => raw,
      PurchaseService.planoSemanal => raw * 52 / 12,
      _ => raw,
    };
    return '$symbol ${monthly.toStringAsFixed(2)}';
  }

  double _fallbackRawPrice(SubscriptionPlan plan) {
    switch (plan.id) {
      case PurchaseService.planoSemanal:
        return 9.90;
      case PurchaseService.planoMensal:
        return 29.90;
      case PurchaseService.planoAnual:
        return 154.99;
      default:
        return 0;
    }
  }
}
