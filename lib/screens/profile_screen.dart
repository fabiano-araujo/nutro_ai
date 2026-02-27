import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/essay_provider.dart';
import '../providers/food_history_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/free_chat_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'nutrition_goals_screen.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/streak_display.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const ProfileScreen({Key? key, this.onOpenDrawer}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  /// Limpa todos os dados do usuário de todos os providers e storage
  Future<void> _clearAllUserData() async {
    print('[ProfileScreen] Iniciando limpeza de dados do usuário...');

    try {
      // Limpar dados do StorageService (histórico, favoritos, conversas, etc.)
      final storageService = StorageService();
      await storageService.clearAllUserData();

      // Limpar CreditProvider
      final creditProvider = Provider.of<CreditProvider>(context, listen: false);
      await creditProvider.clearUserData();

      // Limpar EssayProvider
      final essayProvider = Provider.of<EssayProvider>(context, listen: false);
      essayProvider.clearUserData();

      // Limpar DailyMealsProvider
      final dailyMealsProvider = Provider.of<DailyMealsProvider>(context, listen: false);
      dailyMealsProvider.clearAuth();
      dailyMealsProvider.clearAllMeals();

      // Limpar FoodHistoryProvider
      final foodHistoryProvider = Provider.of<FoodHistoryProvider>(context, listen: false);
      await foodHistoryProvider.clearAll();

      // Limpar DietPlanProvider (dietas personalizadas)
      final dietPlanProvider = Provider.of<DietPlanProvider>(context, listen: false);
      await dietPlanProvider.clearAll();

      // Limpar FreeChatProvider (conversas livres do AI Tutor)
      final freeChatProvider = Provider.of<FreeChatProvider>(context, listen: false);
      await freeChatProvider.clearAll();

      print('[ProfileScreen] Todos os dados do usuário foram limpos com sucesso');
    } catch (e) {
      print('[ProfileScreen] Erro ao limpar dados do usuário: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
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
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: authService.isAuthenticated
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Profile Header
        _buildProfileHeader(user, theme, colorScheme, isDarkMode),
        const SizedBox(height: 24),

        // Streak Card
        const StreakDetailCard(),
        const SizedBox(height: 24),

        // Goal Card
        _buildGoalCard(theme, colorScheme, isDarkMode),
        const SizedBox(height: 24),

        // Quick Stats
        _buildQuickStats(theme, colorScheme, isDarkMode),
        const SizedBox(height: 32),

        // Settings Section
        _buildSettingsSection(theme, colorScheme, isDarkMode),
        const SizedBox(height: 32),

        // Logout
        _buildLogoutButton(authService, theme, colorScheme),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildProfileHeader(user, ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    return Consumer<NutritionGoalsProvider>(
      builder: (context, nutritionProvider, child) {
        final bmi = _calculateBMI(nutritionProvider.weight, nutritionProvider.height);
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

            // Name
            Text(
              user.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // BMI Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ),
          ],
        );
      },
    );
  }

  Widget _buildGoalCard(ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
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
                  icon: Icons.local_fire_department_rounded,
                  label: context.tr.translate('profile_daily_target'),
                  value: '${nutritionProvider.caloriesGoal} kcal',
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
  }) {
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
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;

    return Consumer<DailyMealsProvider>(
      builder: (context, mealsProvider, child) {
        final streak = mealsProvider.getCurrentStreak();
        final avgCalories = mealsProvider.getAverageCalories(7);

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.local_fire_department_rounded,
                value: streak.toString(),
                label: context.tr.translate('profile_streak'),
                theme: theme,
                colorScheme: colorScheme,
                cardColor: cardColor,
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.show_chart_rounded,
                value: avgCalories > 0 ? '${avgCalories.toStringAsFixed(0)}' : '-',
                label: context.tr.translate('profile_avg_cal'),
                theme: theme,
                colorScheme: colorScheme,
                cardColor: cardColor,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required Color cardColor,
    required bool isDarkMode,
  }) {
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
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(ThemeData theme, ColorScheme colorScheme, bool isDarkMode) {
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
            icon: Icons.settings_outlined,
            title: context.tr.translate('settings'),
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildLogoutButton(AuthService authService, ThemeData theme, ColorScheme colorScheme) {
    return TextButton(
      onPressed: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr.translate('logout')),
            content: Text(context.tr.translate('logout_confirmation')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr.translate('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  context.tr.translate('logout'),
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
        );

        if (shouldLogout == true) {
          // Limpar todos os dados do usuário antes de fazer logout
          await _clearAllUserData();
          await authService.logout();
        }
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.logout_rounded,
            size: 20,
            color: colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            context.tr.translate('logout'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
        return context.tr.translate('goal_maintain');
    }
  }
}
