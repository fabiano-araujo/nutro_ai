import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/essay_provider.dart';
import '../providers/food_history_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/free_chat_provider.dart';
import '../providers/meal_types_provider.dart';
import '../services/daily_chat_sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'nutrition_goals_screen.dart';
import 'activity_tracking_apps_screen.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/header_streak_badge.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenSocialHub;

  const ProfileScreen({
    Key? key,
    this.onOpenDrawer,
    this.onOpenSocialHub,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(popOnSuccess: true),
      ),
    );
  }

  _LogoutCleanupDependencies _captureLogoutCleanupDependencies() {
    return _LogoutCleanupDependencies(
      storageService: StorageService(),
      creditProvider: context.read<CreditProvider>(),
      essayProvider: context.read<EssayProvider>(),
      dailyMealsProvider: context.read<DailyMealsProvider>(),
      foodHistoryProvider: context.read<FoodHistoryProvider>(),
      dietPlanProvider: context.read<DietPlanProvider>(),
      freeChatProvider: context.read<FreeChatProvider>(),
      nutritionGoalsProvider: context.read<NutritionGoalsProvider>(),
      mealTypesProvider: context.read<MealTypesProvider>(),
      dailyChatSyncService: DailyChatSyncService.instance,
    );
  }

  bool _hasPendingLogoutSync(_LogoutCleanupDependencies deps) {
    return deps.nutritionGoalsProvider.hasPendingServerSync ||
        deps.freeChatProvider.hasPendingServerSync ||
        deps.foodHistoryProvider.hasPendingServerSync ||
        deps.mealTypesProvider.hasPendingServerSync ||
        deps.dietPlanProvider.hasPendingPreferencesSync ||
        deps.dailyChatSyncService.hasPending;
  }

  Future<bool> _syncPendingBeforeLogout(
    _LogoutCleanupDependencies deps,
  ) async {
    try {
      await Future.wait([
        deps.nutritionGoalsProvider.syncPendingIfNeeded(),
        deps.freeChatProvider.syncPendingIfNeeded(),
        deps.foodHistoryProvider.syncPendingIfNeeded(),
        deps.mealTypesProvider.syncPendingIfNeeded(),
        deps.dietPlanProvider.syncPendingPreferencesIfNeeded(),
        deps.dailyChatSyncService.syncPendingIfNeeded(),
      ]);
    } catch (e) {
      print('[🔄 AUTH_DATA] ❌ ERRO ao sincronizar antes do logout: $e');
    }

    return !_hasPendingLogoutSync(deps);
  }

  Future<bool> _confirmPendingLogout(ColorScheme colorScheme) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.translate('logout_pending_sync_title')),
        content: Text(context.tr.translate('logout_pending_sync_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(context.tr.translate('logout_sync_and_leave')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _performLogout(
    AuthService authService,
    _LogoutCleanupDependencies cleanupDependencies,
  ) async {
    if (!mounted) return;
    setState(() {
      _isLoggingOut = true;
    });

    await Future.wait([
      authService.logout(),
      _clearAllUserData(cleanupDependencies),
    ]);
  }

  /// Limpa todos os dados do usuário de todos os providers e storage
  Future<void> _clearAllUserData(_LogoutCleanupDependencies deps) async {
    print(
        '[🔄 AUTH_DATA] ========== INICIANDO LOGOUT - LIMPEZA DE DADOS ==========');

    try {
      // Limpar dados do StorageService (histórico, favoritos, conversas, etc.)
      print('[🔄 AUTH_DATA] 1/7 Limpando StorageService...');
      await deps.storageService.clearAllUserData();
      print('[🔄 AUTH_DATA] 1/7 ✅ StorageService limpo');

      // Limpar CreditProvider
      print('[🔄 AUTH_DATA] 2/7 Limpando CreditProvider...');
      await deps.creditProvider.clearUserData();
      print('[🔄 AUTH_DATA] 2/7 ✅ CreditProvider limpo');

      // Limpar EssayProvider
      print('[🔄 AUTH_DATA] 3/7 Limpando EssayProvider...');
      deps.essayProvider.clearUserData();
      print('[🔄 AUTH_DATA] 3/7 ✅ EssayProvider limpo');

      // Limpar DailyMealsProvider (todas as refeições e dados de água)
      print('[🔄 AUTH_DATA] 4/7 Limpando DailyMealsProvider...');
      deps.dailyMealsProvider.clearAuth();
      await deps.dailyMealsProvider.clearAllData();
      print('[🔄 AUTH_DATA] 4/7 ✅ DailyMealsProvider limpo');

      // Limpar FoodHistoryProvider
      print('[🔄 AUTH_DATA] 5/7 Limpando FoodHistoryProvider...');
      await deps.foodHistoryProvider.clearAll(markPendingSync: false);
      print('[🔄 AUTH_DATA] 5/7 ✅ FoodHistoryProvider limpo');

      // Limpar DietPlanProvider (dietas personalizadas)
      print('[🔄 AUTH_DATA] 6/7 Limpando DietPlanProvider...');
      await deps.dietPlanProvider.clearAll();
      print('[🔄 AUTH_DATA] 6/7 ✅ DietPlanProvider limpo');

      // Limpar FreeChatProvider (conversas livres do AI Tutor)
      print('[🔄 AUTH_DATA] 7/7 Limpando FreeChatProvider...');
      await deps.freeChatProvider.clearAll();
      print('[🔄 AUTH_DATA] 7/7 ✅ FreeChatProvider limpo');

      // Limpar MealTypesProvider (configuração de refeições)
      print('[🔄 AUTH_DATA] EXTRA: Limpando MealTypesProvider...');
      await deps.mealTypesProvider.clearAllData();
      print('[🔄 AUTH_DATA] EXTRA: ✅ MealTypesProvider limpo');

      // Limpar NutritionGoalsProvider (metas nutricionais)
      print('[🔄 AUTH_DATA] EXTRA: Limpando NutritionGoalsProvider...');
      await deps.nutritionGoalsProvider.clearAllData();
      print('[🔄 AUTH_DATA] EXTRA: ✅ NutritionGoalsProvider limpo');

      print(
          '[🔄 AUTH_DATA] ========== LOGOUT CONCLUÍDO - TODOS OS DADOS LIMPOS ==========');
    } catch (e) {
      print('[🔄 AUTH_DATA] ❌ ERRO durante limpeza de dados: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isAuthenticated = authService.isAuthenticated && !_isLoggingOut;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        automaticallyImplyLeading: false,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: Icon(
                  Icons.menu,
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                ),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
              )
            : null,
        title: Text(
          context.tr.translate('profile'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: isAuthenticated
            ? [
                const HeaderStreakBadge(
                  margin: EdgeInsets.only(right: 4),
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color:
                        isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  tooltip: context.tr.translate('settings'),
                ),
              ]
            : null,
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: isAuthenticated
          ? _buildAuthenticatedContent()
          : _buildUnauthenticatedContent(),
    );
  }

  Widget _buildAuthenticatedContent() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Profile Header (includes subscription + BMI chips)
        _buildProfileHeader(user, theme, colorScheme, isDarkMode),
        const SizedBox(height: 16),

        // Goals section — show CTA when not configured, otherwise show goal cards
        Consumer<NutritionGoalsProvider>(
          builder: (context, nutritionProvider, child) {
            if (!nutritionProvider.hasConfiguredGoals) {
              return _buildCompleteGoalsCard(theme, colorScheme, isDarkMode);
            }
            return Column(
              children: [
                _buildGoalCard(theme, colorScheme, isDarkMode),
                const SizedBox(height: 12),
                _buildMacroGoalsCard(theme, colorScheme, isDarkMode),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Settings Section
        _buildSettingsSection(theme, colorScheme, isDarkMode),
        const SizedBox(height: 16),

        // Logout
        _buildLogoutButton(authService, theme, colorScheme),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildProfileHeader(
      User user, ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionProvider, child) {
        final bmi =
            _calculateBMI(nutritionProvider.weight, nutritionProvider.height);
        final bmiCategory = _getBMICategory(bmi, context);

        return Column(
          children: [
            // Avatar
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: user.photo != null
                    ? CachedNetworkImage(
                        imageUrl: user.photo!,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 96,
                          height: 96,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 96,
                          height: 96,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        width: 96,
                        height: 96,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Name + subscription chip side by side
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    user.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSubscriptionChip(user, theme, colorScheme, isDarkMode),
              ],
            ),

            // BMI chip (only when goals are configured)
            if (nutritionProvider.hasConfiguredGoals) ...[
              const SizedBox(height: 10),
              _buildBmiChip(bmi, bmiCategory, theme, colorScheme),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionChip(
      User user, ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    return Consumer<PurchaseService>(
      builder: (context, purchaseService, child) {
        final isPremium =
            purchaseService.isPremium || user.subscription.isPremium;
        final accentColor =
            isPremium ? const Color(0xFF22C55E) : colorScheme.primary;
        final label = isPremium
            ? context.tr.translate('premium')
            : context.tr.translate('free');
        final icon = isPremium
            ? Icons.workspace_premium_rounded
            : Icons.lock_open_rounded;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).pushNamed('/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      accentColor.withValues(alpha: isDarkMode ? 0.45 : 0.32),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBmiChip(double bmi, String bmiCategory, ThemeData theme,
      ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'IMC ${bmi.toStringAsFixed(1)} · $bmiCategory',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGoalCard(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionProvider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              // Goal
              Expanded(
                child: _buildGoalItem(
                  icon: _getGoalIcon(nutritionProvider.fitnessGoal),
                  label: context.tr.translate('profile_goal'),
                  value: _getGoalText(nutritionProvider.fitnessGoal, context),
                  theme: theme,
                  colorScheme: colorScheme,
                  iconColor: const Color(0xFF42A5F5),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsWizardScreen(
                          startStep: 2,
                          fromProfile: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              // Daily Calories
              Expanded(
                child: _buildGoalItem(
                  icon: MacroTheme.caloriesIcon,
                  label: context.tr.translate('profile_daily_target'),
                  value: '${nutritionProvider.caloriesGoal} kcal',
                  theme: theme,
                  colorScheme: colorScheme,
                  iconColor: MacroTheme.caloriesColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final adaptiveTextColor =
        isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: adaptiveTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: adaptiveTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroGoalsCard(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionProvider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildGoalItem(
                  icon: MacroTheme.proteinIcon,
                  label: context.tr.translate('protein'),
                  value: '${nutritionProvider.proteinGoal} g',
                  theme: theme,
                  colorScheme: colorScheme,
                  iconColor: MacroTheme.proteinColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsScreen(),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildGoalItem(
                  icon: MacroTheme.carbsIcon,
                  label: context.tr.translate('carbs'),
                  value: '${nutritionProvider.carbsGoal} g',
                  theme: theme,
                  colorScheme: colorScheme,
                  iconColor: MacroTheme.carbsColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsScreen(),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildGoalItem(
                  icon: MacroTheme.fatIcon,
                  label: context.tr.translate('fats'),
                  value: '${nutritionProvider.fatGoal} g',
                  theme: theme,
                  colorScheme: colorScheme,
                  iconColor: MacroTheme.fatColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompleteGoalsCard(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NutritionGoalsWizardScreen(
                  startStep: 0,
                  fromProfile: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.flag_rounded,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        context.tr.translate('profile_complete_goals_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr.translate('profile_complete_goals_description'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr.translate('configure_goals'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          _buildSettingsItem(
            icon: Icons.restaurant_menu_rounded,
            title: context.tr.translate('nutrition_goals'),
            theme: theme,
            colorScheme: colorScheme,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NutritionGoalsScreen(),
                ),
              );
            },
          ),
          _buildDivider(colorScheme),
          _buildSettingsItem(
            icon: Icons.sync_rounded,
            title: context.tr.translate('automatic_tracking_apps_title'),
            theme: theme,
            colorScheme: colorScheme,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ActivityTrackingAppsScreen(),
                ),
              );
            },
          ),
          _buildDivider(colorScheme),
          _buildSettingsItem(
            icon: Icons.person_outline_rounded,
            title: context.tr.translate('edit_profile'),
            theme: theme,
            colorScheme: colorScheme,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NutritionGoalsWizardScreen(
                    startStep: 0,
                    fromProfile: true,
                  ),
                ),
              );
            },
          ),
          _buildDivider(colorScheme),
          _buildSettingsItem(
            icon: Icons.bar_chart_rounded,
            title: context.tr.translate('statistics'),
            theme: theme,
            colorScheme: colorScheme,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StatisticsScreen(),
                ),
              );
            },
          ),
          _buildDivider(colorScheme),
          _buildSettingsItem(
            icon: Icons.settings_outlined,
            title: context.tr.translate('settings_title'),
            theme: theme,
            colorScheme: colorScheme,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final adaptiveColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final effectiveIconColor = iconColor ?? adaptiveColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: effectiveIconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: adaptiveColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 68, right: 20),
      child: Divider(
        height: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.25),
      ),
    );
  }

  Widget _buildLogoutButton(
      AuthService authService, ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (_isLoggingOut) return;

            final cleanupDependencies = _captureLogoutCleanupDependencies();
            if (_hasPendingLogoutSync(cleanupDependencies)) {
              final shouldSyncAndLogout =
                  await _confirmPendingLogout(colorScheme);
              if (!shouldSyncAndLogout || !mounted) return;

              setState(() {
                _isLoggingOut = true;
              });

              final synced =
                  await _syncPendingBeforeLogout(cleanupDependencies);
              if (!mounted) return;

              if (!synced) {
                setState(() {
                  _isLoggingOut = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr.translate('logout_pending_sync_failed'),
                    ),
                    backgroundColor: colorScheme.error,
                  ),
                );
                return;
              }
            }

            await _performLogout(authService, cleanupDependencies);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.tr.translate('logout'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
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

  Widget _buildUnauthenticatedContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              context.tr.translate('login_to_access_profile'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr.translate('login_description'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.tr.translate('sign_in'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
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

  // Helper methods
  double _calculateBMI(double weight, double height) {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  String _getBMICategory(double bmi, BuildContext context) {
    if (bmi < 18.5) {
      return context.tr.translate('bmi_underweight');
    } else if (bmi < 25) {
      return context.tr.translate('bmi_normal_weight');
    } else if (bmi < 30) {
      return context.tr.translate('bmi_overweight');
    } else {
      return context.tr.translate('bmi_obesity');
    }
  }

  IconData _getGoalIcon(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
      case FitnessGoal.loseWeightSlowly:
        return Icons.trending_down_rounded;
      case FitnessGoal.gainWeight:
      case FitnessGoal.gainWeightSlowly:
        return Icons.trending_up_rounded;
      case FitnessGoal.maintainWeight:
        return Icons.balance_rounded;
    }
  }

  String _getGoalText(FitnessGoal goal, BuildContext context) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return context.tr.translate('goal_lose_weight');
      case FitnessGoal.loseWeightSlowly:
        return context.tr.translate('goal_lose_weight_slowly');
      case FitnessGoal.gainWeight:
        return context.tr.translate('goal_gain_weight');
      case FitnessGoal.gainWeightSlowly:
        return context.tr.translate('goal_gain_weight_slowly');
      case FitnessGoal.maintainWeight:
        return context.tr.translate('goal_maintain_weight');
    }
  }
}

class _LogoutCleanupDependencies {
  final StorageService storageService;
  final CreditProvider creditProvider;
  final EssayProvider essayProvider;
  final DailyMealsProvider dailyMealsProvider;
  final FoodHistoryProvider foodHistoryProvider;
  final DietPlanProvider dietPlanProvider;
  final FreeChatProvider freeChatProvider;
  final NutritionGoalsProvider nutritionGoalsProvider;
  final MealTypesProvider mealTypesProvider;
  final DailyChatSyncService dailyChatSyncService;

  const _LogoutCleanupDependencies({
    required this.storageService,
    required this.creditProvider,
    required this.essayProvider,
    required this.dailyMealsProvider,
    required this.foodHistoryProvider,
    required this.dietPlanProvider,
    required this.freeChatProvider,
    required this.nutritionGoalsProvider,
    required this.mealTypesProvider,
    required this.dailyChatSyncService,
  });
}
