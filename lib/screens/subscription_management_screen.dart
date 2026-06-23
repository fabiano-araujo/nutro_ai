import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/app_localizations_extension.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import 'subscription_screen.dart';

class SubscriptionManagementScreen extends StatelessWidget {
  const SubscriptionManagementScreen({super.key});

  static const String _packageName = 'br.com.snapdark.apps.nutreai';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final accent =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr.translate('subscription_manage_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: context.tr.translate('subscription_refresh_status'),
            onPressed: () => context
                .read<PurchaseService>()
                .refreshSubscriptionStatusFromServer(),
          ),
        ],
      ),
      body: Consumer2<PurchaseService, AuthService>(
        builder: (context, purchaseService, authService, child) {
          final subscription = authService.currentUser?.subscription;
          final isPremium =
              purchaseService.isPremium || (subscription?.isPremium ?? false);
          final planType = _resolvePlanType(purchaseService, subscription);
          final expirationDate = purchaseService.subscriptionExpiryDate ??
              subscription?.expirationDate;
          final currentPlanName = _planName(context, planType);
          final expiryText = _formatExpirationDate(context, expirationDate);
          final remainingDays =
              _remainingDays(expirationDate, subscription?.remainingDays);
          final isAnnual = _isAnnualPlan(planType);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _StatusHeroCard(
                isPremium: isPremium,
                planName: currentPlanName,
                isDarkMode: isDarkMode,
                textColor: textColor,
                mutedColor: mutedColor,
                accent: accent,
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                label: context.tr.translate('subscription_summary_title'),
                color: mutedColor,
              ),
              const SizedBox(height: 10),
              _SummaryCard(
                planName: currentPlanName,
                expiryText: expiryText,
                remainingDays: remainingDays,
                isDarkMode: isDarkMode,
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                label: context.tr.translate('subscription_actions_title'),
                color: mutedColor,
              ),
              const SizedBox(height: 10),
              _ActionsCard(
                isAnnual: isAnnual,
                isPremium: isPremium,
                sku: _skuForPlan(planType),
                isDarkMode: isDarkMode,
                textColor: textColor,
                mutedColor: mutedColor,
                accent: accent,
              ),
              const SizedBox(height: 16),
              _BenefitsCard(
                isDarkMode: isDarkMode,
                textColor: textColor,
                mutedColor: mutedColor,
                accent: accent,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _resolvePlanType(
    PurchaseService purchaseService,
    Subscription? subscription,
  ) {
    final servicePlan = purchaseService.subscriptionType;
    if (servicePlan != 'free') return servicePlan;
    return subscription?.planType ?? 'free';
  }

  static bool _isAnnualPlan(String planType) {
    final normalized = planType.toLowerCase();
    return normalized == 'anual' || normalized == PurchaseService.planoAnual;
  }

  static String? _skuForPlan(String planType) {
    final normalized = planType.toLowerCase();
    if (normalized == 'mensal' || normalized == PurchaseService.planoMensal) {
      return PurchaseService.planoMensal;
    }
    if (_isAnnualPlan(planType)) {
      return PurchaseService.planoAnual;
    }
    return null;
  }

  static String _planName(BuildContext context, String planType) {
    final normalized = planType.toLowerCase();
    if (normalized == 'mensal' || normalized == PurchaseService.planoMensal) {
      return context.tr.translate('subscription_plan_monthly_play_store');
    }
    if (normalized == 'anual' || normalized == PurchaseService.planoAnual) {
      return context.tr.translate('subscription_plan_annual_play_store');
    }
    if (normalized == 'semanal' || normalized == PurchaseService.planoSemanal) {
      return context.tr.translate('subscription_plan_weekly_play_store');
    }
    return context.tr.translate('subscription_plan_premium_play_store');
  }

  static String _formatExpirationDate(BuildContext context, DateTime? date) {
    if (date == null) {
      return context.tr.translate('subscription_expiry_unknown');
    }

    final localDate = date.toLocal();
    return MaterialLocalizations.of(context).formatMediumDate(localDate);
  }

  static int? _remainingDays(DateTime? expirationDate, int? fallback) {
    if (expirationDate == null) return fallback;

    final now = DateTime.now();
    final localExpiry = expirationDate.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay =
        DateTime(localExpiry.year, localExpiry.month, localExpiry.day);
    final diff = expiryDay.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  static Future<void> openPlayStoreManagement(
    BuildContext context, {
    String? sku,
  }) async {
    final query = <String, String>{
      'package': _packageName,
      if (sku != null && sku.isNotEmpty) 'sku': sku,
    };
    final uri = Uri.https(
      'play.google.com',
      '/store/account/subscriptions',
      query,
    );

    final messenger = ScaffoldMessenger.of(context);
    final message = context.tr.translate('subscription_play_store_open_error');

    try {
      final opened = await launchUrl(
        uri,
        mode: kIsWeb || defaultTargetPlatform != TargetPlatform.android
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      if (!opened) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _StatusHeroCard extends StatelessWidget {
  final bool isPremium;
  final String planName;
  final bool isDarkMode;
  final Color textColor;
  final Color mutedColor;
  final Color accent;

  const _StatusHeroCard({
    required this.isPremium,
    required this.planName,
    required this.isDarkMode,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.profileCardDecoration(
        isDarkMode,
        radius: 28,
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDarkMode ? 0.22 : 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_open_rounded,
              color: accent,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium
                      ? context.tr.translate('subscription_active_title')
                      : context.tr.translate('subscription_inactive_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionTitle({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String planName;
  final String expiryText;
  final int? remainingDays;
  final bool isDarkMode;
  final Color textColor;
  final Color mutedColor;

  const _SummaryCard({
    required this.planName,
    required this.expiryText,
    required this.remainingDays,
    required this.isDarkMode,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          _SummaryRow(
            label: context.tr.translate('subscription_current_plan_label'),
            value: planName,
            icon: Icons.local_offer_rounded,
            textColor: textColor,
            mutedColor: mutedColor,
            isDarkMode: isDarkMode,
          ),
          Divider(
            height: 28,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _SummaryRow(
            label: context.tr.translate('subscription_valid_until_label'),
            value: expiryText,
            icon: Icons.event_available_rounded,
            textColor: textColor,
            mutedColor: mutedColor,
            isDarkMode: isDarkMode,
          ),
          if (remainingDays != null) ...[
            const SizedBox(height: 14),
            _RemainingDaysPill(
              remainingDays: remainingDays!,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color textColor;
  final Color mutedColor;
  final bool isDarkMode;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.textColor,
    required this.mutedColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RemainingDaysPill extends StatelessWidget {
  final int remainingDays;
  final bool isDarkMode;
  final Color textColor;

  const _RemainingDaysPill({
    required this.remainingDays,
    required this.isDarkMode,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final key = remainingDays == 1
        ? 'subscription_remaining_day'
        : 'subscription_remaining_days';
    final label = context.tr
        .translate(key)
        .replaceAll('{days}', remainingDays.toString());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final bool isAnnual;
  final bool isPremium;
  final String? sku;
  final bool isDarkMode;
  final Color textColor;
  final Color mutedColor;
  final Color accent;

  const _ActionsCard({
    required this.isAnnual,
    required this.isPremium,
    required this.sku,
    required this.isDarkMode,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr.translate('subscription_manage_description'),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.86),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  SubscriptionManagementScreen.openPlayStoreManagement(
                context,
                sku: sku,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              label: Text(
                context.tr.translate('subscription_manage_play_store_button'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: accent,
                foregroundColor: AppTheme.onColor(accent),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!isPremium)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              ),
              icon: Icon(Icons.workspace_premium_rounded,
                  color: accent, size: 19),
              label: Text(
                context.tr.translate('subscription_view_plans'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            )
          else if (!isAnnual)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              ),
              icon: Icon(Icons.trending_up_rounded, color: accent, size: 19),
              label: Text(
                context.tr.translate('subscription_switch_to_annual'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            )
          else
            Text(
              context.tr.translate('subscription_annual_active_note'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  final bool isDarkMode;
  final Color textColor;
  final Color mutedColor;
  final Color accent;

  const _BenefitsCard({
    required this.isDarkMode,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode, radius: 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr.translate('subscription_premium_benefits_title'),
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          _BenefitLine(
            icon: Icons.restaurant_menu_rounded,
            labelKey: 'premium_benefit_diet',
            accent: accent,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          _BenefitLine(
            icon: Icons.calendar_month_rounded,
            labelKey: 'premium_benefit_daily_menu',
            accent: accent,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          _BenefitLine(
            icon: Icons.auto_awesome_rounded,
            labelKey: 'premium_benefit_shape',
            accent: accent,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          _BenefitLine(
            icon: Icons.block_rounded,
            labelKey: 'premium_benefit_no_ads',
            accent: accent,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ],
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  final IconData icon;
  final String labelKey;
  final Color accent;
  final Color textColor;
  final Color mutedColor;

  const _BenefitLine({
    required this.icon,
    required this.labelKey,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr.translate(labelKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.86),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
