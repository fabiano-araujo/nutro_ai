import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutro_ai/i18n/app_localizations_extension.dart';
import 'package:nutro_ai/models/subscription_plan.dart';
import 'package:nutro_ai/services/purchase_service.dart';
import 'package:provider/provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final List<SubscriptionPlan> _plans = SubscriptionPlan.getPlans();
  int _selectedPlanIndex = 1;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  late List<String> _commonBenefits;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _commonBenefits = [
      'Dieta personalizada com IA',
      'Cardapio diario ajustado ao seu objetivo',
      'Registro de refeicoes, calorias e macros',
      'Resumo nutricional com progresso semanal',
      'Acompanhamento de metas e evolucao de peso',
    ];

    if (_plans.isEmpty && !_hasError) {
      _hasError = true;
      _errorMessage = context.tr.translate('error_loading_plans');
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = context.watch<PurchaseService>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_hasError) {
      return _buildErrorScreen(
        context,
        isDarkMode,
        _errorMessage.isNotEmpty
            ? _errorMessage
            : (purchaseService.errorMessage ??
                context.tr.translate('error_loading_plans')),
      );
    }

    final hasRealProducts = purchaseService.products.isNotEmpty;
    final selectedPlanIndex =
        _selectedPlanIndex >= _plans.length ? 0 : _selectedPlanIndex;
    final selectedPlan = _plans[selectedPlanIndex];
    final selectedProduct = _findProduct(
      purchaseService.products,
      selectedPlan.id,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _PaywallBackground(isDarkMode: isDarkMode),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _buildTopBar(context, purchaseService, isDarkMode),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 220),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeroCard(
                              context,
                              isDarkMode,
                              selectedPlan,
                              selectedProduct,
                            ),
                            const SizedBox(height: 22),
                            ...List.generate(_plans.length, (index) {
                              final plan = _plans[index];
                              final product = _findProduct(
                                purchaseService.products,
                                plan.id,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _PlanOptionCard(
                                  plan: plan,
                                  productDetails: product,
                                  isDarkMode: isDarkMode,
                                  isSelected: index == selectedPlanIndex,
                                  onTap: () {
                                    setState(() {
                                      _selectedPlanIndex = index;
                                    });
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            _buildIncludedCard(
                              context,
                              isDarkMode,
                              _commonBenefits,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _buildBottomActionBar(
                    context,
                    purchaseService,
                    isDarkMode,
                    selectedPlan,
                    selectedProduct,
                    hasRealProducts,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PurchaseService purchaseService,
    bool isDarkMode,
  ) {
    return Row(
      children: [
        _CircleIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
          isDarkMode: isDarkMode,
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: purchaseService.isLoading || _isLoading
              ? null
              : () => _restorePurchases(context, purchaseService),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(context.tr.translate('restore_purchases')),
          style: TextButton.styleFrom(
            foregroundColor:
                isDarkMode ? const Color(0xFFFFD8A8) : const Color(0xFF9F4B00),
            backgroundColor: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.58),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFFFE0C2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    bool isDarkMode,
    SubscriptionPlan selectedPlan,
    ProductDetails? selectedProduct,
  ) {
    final title = _productTitle(selectedProduct, selectedPlan);
    final description = _productDescription(selectedProduct, selectedPlan);
    final price = _productPrice(selectedProduct, selectedPlan);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? const [
                  Color(0xFF3A2618),
                  Color(0xFF251A14),
                  Color(0xFF181311),
                ]
              : const [
                  Color(0xFFFFE3B5),
                  Color(0xFFFFB975),
                  Color(0xFFFF8A65),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : const Color(0xFFCF5D23))
                .withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.22),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              _PillTag(
                label: context.tr.translate('premium'),
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
                icon: Icons.workspace_premium_rounded,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            context.tr.translate('premium_plans'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr.translate('unlock_potential'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonBenefits.take(3).map((benefit) {
              return _PillTag(
                label: benefit,
                backgroundColor:
                    Colors.white.withValues(alpha: isDarkMode ? 0.07 : 0.18),
                foregroundColor: Colors.white,
                icon: Icons.check_circle_rounded,
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDarkMode ? 0.06 : 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        price,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
                if (selectedPlan.savePercentage > 0)
                  _PillTag(
                    label: context.tr.translate('save_percentage').replaceAll(
                          '{percentage}',
                          selectedPlan.savePercentage.toString(),
                        ),
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedCard(
    BuildContext context,
    bool isDarkMode,
    List<String> benefits,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isDarkMode
                ? const Color(0xFF1A1714).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.82),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFFFDFC3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr.translate('whats_included'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF3B2A1F),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              ...benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE1C3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFFAF4F00),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          benefit,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : const Color(0xFF5E4A3D),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    PurchaseService purchaseService,
    bool isDarkMode,
    SubscriptionPlan selectedPlan,
    ProductDetails? selectedProduct,
    bool hasRealProducts,
  ) {
    final buttonEnabled =
        !_isLoading && !purchaseService.isLoading && selectedProduct != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: isDarkMode
                ? const Color(0xFF14110F).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.88),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
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
                        Text(
                          _productTitle(selectedProduct, selectedPlan),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF2F2117),
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _productPrice(selectedProduct, selectedPlan),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: isDarkMode
                                        ? const Color(0xFFFFD49E)
                                        : const Color(0xFF9F4B00),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedPlan.isMostPopular)
                    _PillTag(
                      label: context.tr.translate('popular'),
                      backgroundColor: isDarkMode
                          ? const Color(0xFF6C3A16)
                          : const Color(0xFFFFE5C7),
                      foregroundColor: isDarkMode
                          ? const Color(0xFFFFD8A8)
                          : const Color(0xFFAF4F00),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _GradientButton(
                onTap: buttonEnabled
                    ? () => _subscribe(context, purchaseService)
                    : null,
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
                        context.tr.translate('subscribe_now'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                      ),
              ),
              if (!hasRealProducts) ...[
                const SizedBox(height: 10),
                Text(
                  purchaseService.errorMessage ??
                      context.tr.translate('error_loading_plans'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.72)
                            : const Color(0xFF8B6E5A),
                      ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                context.tr.translate('subscription_terms'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.62)
                          : const Color(0xFF8B6E5A),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(
    BuildContext context,
    bool isDarkMode,
    String message,
  ) {
    return _buildStateScaffold(
      context: context,
      isDarkMode: isDarkMode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF5C241C)
                  : const Color(0xFFFFE1DB),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: isDarkMode
                  ? const Color(0xFFFFB4A2)
                  : const Color(0xFFB53A1B),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            context.tr.translate('oops'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDarkMode ? Colors.white : const Color(0xFF2F2117),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.72)
                      : const Color(0xFF6E5A4D),
                ),
          ),
          const SizedBox(height: 24),
          _GradientButton(
            onTap: () {
              setState(() {
                _hasError = false;
                _errorMessage = '';
              });
            },
            child: Text(
              context.tr.translate('try_again_button'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(context.tr.translate('back')),
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.76)
                  : const Color(0xFF6E5A4D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateScaffold({
    required BuildContext context,
    required bool isDarkMode,
    required Widget child,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _PaywallBackground(isDarkMode: isDarkMode),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          color: isDarkMode
                              ? const Color(0xFF171412).withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.86),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ProductDetails? _findProduct(List<ProductDetails> products, String planId) {
    for (final product in products) {
      if (product.id == planId) {
        return product;
      }
    }
    return null;
  }

  Future<void> _restorePurchases(
    BuildContext context,
    PurchaseService purchaseService,
  ) async {
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _subscribe(
    BuildContext context,
    PurchaseService purchaseService,
  ) async {
    final availablePlans = _plans
        .where(
            (plan) => _findProduct(purchaseService.products, plan.id) != null)
        .toList();

    if (availablePlans.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = context.tr.translate('error_loading_plans');
      });
      return;
    }

    final selectedPlan = availablePlans[
        _selectedPlanIndex >= availablePlans.length ? 0 : _selectedPlanIndex];
    final selectedProduct = _findProduct(
      purchaseService.products,
      selectedPlan.id,
    );

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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

String _productTitle(ProductDetails? productDetails, SubscriptionPlan plan) {
  if (productDetails == null) {
    return plan.title;
  }

  final rawTitle = productDetails.title.trim();
  final suffixStart = rawTitle.indexOf('(');

  if (suffixStart > 0 && rawTitle.endsWith(')')) {
    return rawTitle.substring(0, suffixStart).trim();
  }

  return rawTitle;
}

String _productDescription(
  ProductDetails? productDetails,
  SubscriptionPlan plan,
) {
  if (productDetails == null) {
    return plan.description;
  }

  final description = productDetails.description.trim();
  return description.isEmpty ? plan.description : description;
}

String _productPrice(ProductDetails? productDetails, SubscriptionPlan plan) {
  return productDetails?.price ?? plan.price;
}

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({
    required this.plan,
    required this.productDetails,
    required this.isDarkMode,
    required this.isSelected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final ProductDetails? productDetails;
  final bool isDarkMode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final features =
        isSelected ? plan.features : plan.features.take(2).toList();
    final title = _productTitle(productDetails, plan);
    final description = _productDescription(productDetails, plan);
    final price = _productPrice(productDetails, plan);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isDarkMode
                ? const Color(0xFF191613).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.84),
            border: Border.all(
              color: isSelected
                  ? plan.color
                  : (isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFFFE0C2)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? plan.color : Colors.black)
                    .withValues(alpha: isSelected ? 0.18 : 0.05),
                blurRadius: isSelected ? 26 : 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: plan.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(plan.icon, color: plan.color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF2F2117),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            if (plan.isMostPopular)
                              _PillTag(
                                label: context.tr.translate('popular'),
                                backgroundColor:
                                    plan.color.withValues(alpha: 0.16),
                                foregroundColor: plan.color,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.68)
                                      : const Color(0xFF776153),
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isSelected
                          ? Container(
                              key: const ValueKey('selected-badge'),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: plan.color,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('empty-badge'),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF2F2117),
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      plan.period.toLowerCase(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : const Color(0xFF776153),
                          ),
                    ),
                  ),
                ],
              ),
              if (plan.savePercentage > 0) ...[
                const SizedBox(height: 10),
                _PillTag(
                  label: context.tr.translate('save_percentage').replaceAll(
                        '{percentage}',
                        plan.savePercentage.toString(),
                      ),
                  backgroundColor: plan.color.withValues(alpha: 0.12),
                  foregroundColor: plan.color,
                  icon: Icons.local_offer_rounded,
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: features.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: plan.color,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                feature,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.82)
                                          : const Color(0xFF5E4A3D),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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

class _PaywallBackground extends StatelessWidget {
  const _PaywallBackground({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? const [
                  Color(0xFF120F0D),
                  Color(0xFF1A1512),
                  Color(0xFF221A15),
                ]
              : const [
                  Color(0xFFFFF7EC),
                  Color(0xFFFFECD7),
                  Color(0xFFFFD8BF),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _BlurBlob(
              size: 220,
              color: isDarkMode
                  ? const Color(0xFFFF8A65).withValues(alpha: 0.16)
                  : const Color(0xFFFFA726).withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            top: 130,
            right: -50,
            child: _BlurBlob(
              size: 200,
              color: isDarkMode
                  ? const Color(0xFFFFCC80).withValues(alpha: 0.12)
                  : const Color(0xFFFF7043).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: -70,
            left: 20,
            child: _BlurBlob(
              size: 240,
              color: isDarkMode
                  ? const Color(0xFF66BB6A).withValues(alpha: 0.1)
                  : const Color(0xFFA5D6A7).withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: enabled
            ? const LinearGradient(
                colors: [
                  Color(0xFFFF8A65),
                  Color(0xFFFF7043),
                  Color(0xFFF4511E),
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.grey.shade400,
                  Colors.grey.shade500,
                ],
              ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFFF56A34).withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 58,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  const _PillTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.isDarkMode,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: isDarkMode ? Colors.white : const Color(0xFF2F2117),
          ),
        ),
      ),
    );
  }
}
