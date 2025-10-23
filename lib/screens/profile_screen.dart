import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/event_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../i18n/app_localizations_extension.dart';
import '../services/ad_manager.dart';
import '../providers/credit_provider.dart';
import '../screens/history_screen.dart'; // HistoryWidget está aqui
import '../widgets/reward_ad_dialog.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildAuthenticatedContent() {
    final authService = Provider.of<AuthService>(context);
    final purchaseService = Provider.of<PurchaseService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool isPremium =
        purchaseService.isPremium || (user?.subscription.isPremium ?? false);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.black.withOpacity(0.03),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar e nome
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.secondary,
                                ],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.white,
                              backgroundImage: user.photo != null
                                  ? NetworkImage(user.photo!)
                                  : null,
                              child: user.photo == null
                                  ? Icon(
                                      Icons.person,
                                      size: 44,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPremium
                              ? colorScheme.primary.withOpacity(0.2)
                              : colorScheme.onSurfaceVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isPremium
                              ? context.tr.translate('premium')
                              : context.tr.translate('free'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isPremium
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Informações da assinatura premium (se tiver)
                      if (isPremium &&
                          purchaseService.subscriptionType.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "${context.tr.translate('plan')} ${purchaseService.subscriptionType} - ${_getFormattedExpiryDate(purchaseService.subscriptionExpiryDate)}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Botão para assinar premium (se não for premium)
                  if (!isPremium)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/subscription');
                          },
                          icon: const Icon(Icons.star),
                          label:
                              Text(context.tr.translate('subscribe_premium')),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: colorScheme.primary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Botão de gerenciar assinatura (se for premium)
                  if (isPremium)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/subscription');
                          },
                          icon: const Icon(Icons.settings),
                          label:
                              Text(context.tr.translate('manage_subscription')),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            backgroundColor:
                                colorScheme.primary.withOpacity(0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ];
      },
      body: const HistoryWidget(),
    );
  }

  String _getFormattedExpiryDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    return difference > 0
        ? context.tr
            .translate('expires_in_days')
            .replaceAll('{days}', difference.toString())
        : context.tr.translate('expires_today');
  }

  Widget _buildUnauthenticatedContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 100,
              color: colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr.translate('login_to_access_profile'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr.translate('login_description'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToLogin,
                icon: const Icon(Icons.login),
                label: Text(context.tr.translate('sign_in')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.translate('profile')),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
          if (authService.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.card_giftcard),
              tooltip: context.tr.translate('watch_ad_for_credits'),
              onPressed: () {
                _showRewardAdDialog();
              },
            ),
          if (authService.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
        ],
      ),
      body: authService.isAuthenticated
          ? _buildAuthenticatedContent()
          : _buildUnauthenticatedContent(),
    );
  }

  // Método para mostrar um diálogo explicativo sobre o anúncio premiado
  void _showRewardAdDialog() {
    // Na versão web, apenas mostre mensagem
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('feature_not_available_web')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    RewardAdDialog.show(context);
  }

  // Método para mostrar o anúncio premiado
  Future<void> _showRewardedAd(BuildContext context) async {
    // Na versão web, este método não será executado diretamente
    // O RewardAdDialog já verifica por kIsWeb internamente
    RewardAdDialog.showRewardedAd(context);
  }
}
