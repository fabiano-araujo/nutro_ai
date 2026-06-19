import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/activity_tracking_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/essay_provider.dart';
import '../providers/food_history_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/free_chat_provider.dart';
import '../providers/meal_types_provider.dart';
import '../services/daily_chat_sync_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'nutrition_goals_screen.dart';
import 'activity_tracking_apps_screen.dart';
import 'profile_shape_preview_screen.dart';
import 'settings_screen.dart';
import '../i18n/app_localizations_extension.dart';

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
  static const double _listItemTitleFontSize = 14;
  static const double _listItemSubtitleFontSize = 12;
  static const List<Shadow> _bannerTextShadow = [
    Shadow(
      color: Color(0x40000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  static const List<Shadow> _bannerImageTextShadow = [
    Shadow(
      color: Color(0x99000000),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
    Shadow(
      color: Color(0x66000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActivityTrackingProvider>().loadForDate(DateTime.now());
    });
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(popOnSuccess: true),
      ),
    );
  }

  void _openShapePreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileShapePreviewScreen(
          onOpenSocialHub: widget.onOpenSocialHub,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _openActivityTrackingApps() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ActivityTrackingAppsScreen(),
      ),
    );
  }

  Future<void> _connectActivityTracking(
    ActivityTrackingProvider provider,
  ) async {
    final status = await provider.requestPermissionsAndLoad(DateTime.now());
    if (!mounted) return;

    String message;
    if (status.hasAllPermissions) {
      message = context.tr.translate('tracking_permission_granted');
    } else if (status.hasAnyPermission) {
      message = context.tr.translate('tracking_permission_partial');
    } else if (status.needsProviderUpdate || !status.isAvailable) {
      message = context.tr.translate('tracking_health_update_required');
      await provider.openHealthConnect();
    } else {
      message = context.tr.translate('tracking_permission_denied');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
            color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: isAuthenticated
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: IconButton(
                    icon: Icon(
                      Icons.settings_rounded,
                      color:
                          isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                    ),
                    onPressed: _openSettings,
                    tooltip: context.tr.translate('settings_title'),
                  ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Profile Header (includes subscription + BMI chips)
        _buildProfileHeader(user, theme, colorScheme, isDarkMode),
        const SizedBox(height: 14),

        // Goals section — show CTA when not configured, otherwise show goal cards
        Consumer<NutritionGoalsProvider>(
          builder: (context, nutritionProvider, child) {
            if (!nutritionProvider.hasConfiguredGoals) {
              return _buildCompleteGoalsCard(theme, colorScheme, isDarkMode);
            }
            return _buildGoalCard(theme, colorScheme, isDarkMode);
          },
        ),
        const SizedBox(height: 16),

        _buildDailyProgressCard(theme, colorScheme, isDarkMode),
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
            Semantics(
              button: true,
              label: context.tr.translate('profile_shape_preview_title'),
              child: GestureDetector(
                onTap: _openShapePreview,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isDarkMode ? AppTheme.darkCardColor : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDarkMode ? 0.34 : 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          width: 96,
                          height: 96,
                          color: colorScheme.primary,
                          child: _buildProfileAvatar(user, colorScheme),
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? AppTheme.darkCardColor : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode
                              ? AppTheme.darkBackgroundColor
                              : AppTheme.backgroundColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              user.name,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 8),
            _buildSubscriptionChip(user, theme, colorScheme, isDarkMode),
            if (nutritionProvider.hasConfiguredGoals) ...[
              const SizedBox(height: 8),
              _buildBmiChip(bmi, bmiCategory, theme, colorScheme, isDarkMode),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDefaultAvatarIcon() {
    return Icon(
      Icons.link_rounded,
      size: 50,
      color: Colors.white,
    );
  }

  Widget _buildProfileAvatar(User user, ColorScheme colorScheme) {
    final photoUrl = user.photo?.trim();
    if (photoUrl == null || photoUrl.isEmpty) {
      return _buildDefaultAvatarIcon();
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildDefaultAvatarIcon(),
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
            ? context.tr.translate('profile_plan_premium')
            : context.tr.translate('profile_plan_free');

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).pushNamed('/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDarkMode ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 13,
                    color: accentColor,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
      ColorScheme colorScheme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.26 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(text: 'IMC ${bmi.toStringAsFixed(1)}'),
            TextSpan(
              text: '  ·  ',
              style: TextStyle(color: colorScheme.primary),
            ),
            TextSpan(
              text: bmiCategory,
              style: TextStyle(color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionProvider, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary
                    .withValues(alpha: isDarkMode ? 0.18 : 0.11),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 2.22,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/profile_goal_banner.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGoalBannerItem(
                        icon: _getGoalIcon(nutritionProvider.fitnessGoal),
                        label: context.tr.translate('profile_goal'),
                        value: _getGoalText(
                            nutritionProvider.fitnessGoal, context),
                        theme: theme,
                        colorScheme: colorScheme,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NutritionGoalsWizardScreen(
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
                      height: 104,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    Expanded(
                      child: _buildGoalBannerItem(
                        icon: Icons.local_fire_department_rounded,
                        label: context.tr.translate('profile_daily_target'),
                        value: '${nutritionProvider.caloriesGoal} kcal',
                        theme: theme,
                        colorScheme: colorScheme,
                        textShadows: _bannerImageTextShadow,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NutritionGoalsScreen(),
                            ),
                          );
                        },
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

  Widget _buildGoalBannerItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    List<Shadow> textShadows = _bannerTextShadow,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 25,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: textShadows,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.05,
                shadows: textShadows,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteGoalsCard(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                colorScheme.primary.withValues(alpha: isDarkMode ? 0.18 : 0.11),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 2.22,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/profile_goal_banner.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
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
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.flag_rounded,
                          size: 25,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        context.tr.translate('profile_complete_goals_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          shadows: _bannerTextShadow,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr
                            .translate('profile_complete_goals_description'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.25,
                          shadows: _bannerTextShadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyProgressCard(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final mutedTextColor =
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;

    return Consumer2<DailyMealsProvider, ActivityTrackingProvider>(
      builder: (context, mealsProvider, trackingProvider, child) {
        final today = DateTime.now();
        final waterConsumed = mealsProvider.getWaterGlassesForDate(today);
        final waterGoal =
            mealsProvider.waterGoal <= 0 ? 1 : mealsProvider.waterGoal;
        final waterProgress =
            (waterConsumed / waterGoal).clamp(0.0, 1.0).toDouble();
        final activityDetail =
            '${trackingProvider.steps} ${context.tr.translate('tracking_steps_short')} / '
            '${trackingProvider.exerciseMinutes} ${context.tr.translate('tracking_minutes_short')}';

        return Container(
          decoration: AppTheme.profileCardDecoration(isDarkMode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildWaterProgressPanel(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      consumed: waterConsumed,
                      goal: waterGoal,
                      progress: waterProgress,
                      onAdd: () => mealsProvider.addWaterForDate(today),
                      onRemove: waterConsumed > 0
                          ? () => mealsProvider.removeWaterForDate(today)
                          : null,
                    ),
                  ),
                  _buildDailyProgressDivider(colorScheme),
                  Expanded(
                    child: _buildActivityProgressPanel(
                      theme: theme,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      mutedTextColor: mutedTextColor,
                      trackingProvider: trackingProvider,
                      detail: activityDetail,
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

  Widget _buildDailyProgressDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: colorScheme.outlineVariant.withValues(alpha: 0.18),
    );
  }

  Widget _buildWaterProgressPanel({
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
    required Color mutedTextColor,
    required int consumed,
    required int goal,
    required double progress,
    required VoidCallback onAdd,
    required VoidCallback? onRemove,
  }) {
    const waterColor = Color(0xFF4FC3F7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressIcon(
            icon: Icons.water_drop_rounded,
            color: waterColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.translate('water'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$consumed/$goal ${context.tr.translate('water_glasses')}',
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    height: 5,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 5,
                      color: waterColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallActionButton(
                tooltip: context.tr.translate('remove'),
                icon: Icons.remove_rounded,
                color: mutedTextColor,
                isDarkMode: isDarkMode,
                onPressed: onRemove,
              ),
              const SizedBox(width: 8),
              _buildSmallActionButton(
                tooltip: context.tr.translate('add'),
                icon: Icons.add_rounded,
                color: waterColor,
                isDarkMode: isDarkMode,
                onPressed: onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityProgressPanel({
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
    required Color mutedTextColor,
    required ActivityTrackingProvider trackingProvider,
    required String detail,
  }) {
    const activityColor = Color(0xFFEAB308);
    final actionColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressIcon(
            icon: Icons.emoji_events_rounded,
            color: activityColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr.translate('tracking_activities_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${trackingProvider.activeCalories} ${context.tr.translate('tracking_metric_calories')}',
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallActionButton(
                tooltip: trackingProvider.hasAnyPermission
                    ? context.tr.translate('tracking_refresh')
                    : context.tr.translate('tracking_action_connect'),
                color: actionColor,
                isDarkMode: isDarkMode,
                onPressed: trackingProvider.isRequestingPermissions
                    ? null
                    : () => _connectActivityTracking(trackingProvider),
                child: trackingProvider.isRequestingPermissions
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: actionColor,
                        ),
                      )
                    : Icon(
                        trackingProvider.hasAnyPermission
                            ? Icons.refresh_rounded
                            : Icons.link_rounded,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 8),
              _buildSmallActionButton(
                tooltip: context.tr.translate('tracking_add_activity'),
                icon: Icons.apps_rounded,
                color: mutedTextColor,
                isDarkMode: isDarkMode,
                onPressed: _openActivityTrackingApps,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIcon({
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.2 : 0.13),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _buildSmallActionButton({
    required String tooltip,
    required Color color,
    required bool isDarkMode,
    VoidCallback? onPressed,
    IconData? icon,
    Widget? child,
  }) {
    final effectiveChild = child ?? Icon(icon, size: 18);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tight(const Size(34, 34)),
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: isDarkMode ? 0.14 : 0.1),
            disabledBackgroundColor: color.withValues(alpha: 0.06),
            foregroundColor: color,
            disabledForegroundColor: color.withValues(alpha: 0.35),
            shape: const CircleBorder(),
          ),
          onPressed: onPressed,
          icon: effectiveChild,
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
      ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    return Container(
      decoration: AppTheme.profileCardDecoration(isDarkMode),
      child: Column(
        children: [
          const SizedBox(height: 6),
          _buildSettingsItem(
            icon: Icons.restaurant_menu_rounded,
            title: context.tr.translate('nutrition_goals'),
            subtitle: context.tr.translate('profile_nutrition_goals_subtitle'),
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
            subtitle: context.tr.translate('profile_tracking_apps_subtitle'),
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
            subtitle: context.tr.translate('profile_edit_profile_subtitle'),
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
            icon: Icons.auto_awesome_rounded,
            title: context.tr.translate('profile_shape_preview_title'),
            subtitle: context.tr.translate('profile_shape_preview_subtitle'),
            theme: theme,
            colorScheme: colorScheme,
            onTap: _openShapePreview,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final adaptiveColor = isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: effectiveIconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: adaptiveColor,
                        fontWeight: FontWeight.w700,
                        fontSize: _listItemTitleFontSize,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode
                            ? AppTheme.darkMutedTextColor
                            : AppTheme.textSecondaryColor,
                        fontSize: _listItemSubtitleFontSize,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 26,
                color: isDarkMode
                    ? AppTheme.darkMutedTextColor
                    : AppTheme.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 28),
      child: Divider(
        height: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.18),
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
