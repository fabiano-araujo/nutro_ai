import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'diet_type_selection_screen.dart';
import 'nutrition_assistant_screen.dart';
import '../i18n/app_localizations.dart';

class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({Key? key}) : super(key: key);

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Consumer<NutritionGoalsProvider>(
          builder: (context, provider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(textColor),
                  const SizedBox(height: 8),
                  _buildSyncStatusBanner(
                      provider, theme, isDarkMode, textColor),
                  if (provider.hasPendingServerSync ||
                      provider.isSyncingWithServer)
                    const SizedBox(height: 14),
                  _buildGoalsHeroCard(provider, isDarkMode, textColor),
                  const SizedBox(height: 14),
                  _buildAiAdjustmentButton(isDarkMode),
                  const SizedBox(height: 14),
                  _buildMacroRow(provider, isDarkMode),
                  const SizedBox(height: 24),
                  _buildConfigurationSection(
                    context,
                    provider,
                    isDarkMode,
                    textColor,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    const sideWidth = 56.0;

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: sideWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textColor),
                tooltip: AppLocalizations.of(context).translate('back'),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate('nutrition_goals'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ).copyWith(color: textColor),
            ),
          ),
          const SizedBox(width: sideWidth),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBanner(
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    if (!provider.hasPendingServerSync && !provider.isSyncingWithServer) {
      return const SizedBox.shrink();
    }

    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final message = provider.isSyncingWithServer
        ? AppLocalizations.of(context).translate('goals_syncing')
        : AppLocalizations.of(context).translate('goals_not_synced');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Row(
        children: [
          Icon(
            provider.isSyncingWithServer
                ? Icons.sync_rounded
                : Icons.cloud_off_rounded,
            size: 18,
            color: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsHeroCard(
    NutritionGoalsProvider provider,
    bool isDarkMode,
    Color textColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
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
                    Text(
                      AppLocalizations.of(context)
                          .translate('your_daily_goals'),
                      style: TextStyle(
                        color: _mutedTextColor(isDarkMode),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${provider.caloriesGoal}',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 34,
                              height: 1.05,
                            ),
                          ),
                          TextSpan(
                            text: ' kcal',
                            style: TextStyle(
                              color: _mutedTextColor(isDarkMode),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _openPersonalInfoEditor,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _secondarySurfaceColor(isDarkMode),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderColor(isDarkMode)),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: textColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChip(
                icon: Icons.track_changes,
                label:
                    provider.getFitnessGoalName(provider.fitnessGoal, context),
                isDarkMode: isDarkMode,
                textColor: textColor,
                onTap: _openFitnessGoalEditor,
              ),
              _buildMetaChip(
                icon: Icons.restaurant_menu,
                label: provider.getDietTypeName(provider.dietType, context),
                isDarkMode: isDarkMode,
                textColor: textColor,
                onTap: _openDietTypeScreen,
              ),
              _buildMetaChip(
                icon: Icons.directions_run,
                label: provider.getActivityLevelName(
                  provider.activityLevel,
                  context,
                ),
                isDarkMode: isDarkMode,
                textColor: textColor,
                onTap: _openActivityLevelEditor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _secondarySurfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _borderColor(isDarkMode)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: textColor.withValues(alpha: 0.72),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.86),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: textColor.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAdjustmentButton(bool isDarkMode) {
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return InkWell(
      onTap: _openMacroGoalsAssistant,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppTheme.onColor(accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)
                    .translate('chat_action_continue_macros_chat'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.onColor(accentColor),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppTheme.onColor(accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(
    NutritionGoalsProvider provider,
    bool isDarkMode,
  ) {
    final dividerColor = _borderColor(isDarkMode);
    return Container(
      decoration: BoxDecoration(
        color: _cardSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildMacroCardCompact(
                  icon: MacroTheme.caloriesIcon,
                  value: '${provider.caloriesGoal}',
                  unit: 'kcal',
                  color: MacroTheme.caloriesColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              VerticalDivider(
                color: dividerColor,
                width: 1,
                thickness: 1,
                indent: 4,
                endIndent: 4,
              ),
              Expanded(
                child: _buildMacroCardCompact(
                  icon: MacroTheme.proteinIcon,
                  value: '${provider.proteinGoal}g',
                  unit: AppLocalizations.of(context).translate('protein'),
                  color: MacroTheme.proteinColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              VerticalDivider(
                color: dividerColor,
                width: 1,
                thickness: 1,
                indent: 4,
                endIndent: 4,
              ),
              Expanded(
                child: _buildMacroCardCompact(
                  icon: MacroTheme.carbsIcon,
                  value: '${provider.carbsGoal}g',
                  unit: AppLocalizations.of(context).translate('carbs'),
                  color: MacroTheme.carbsColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              VerticalDivider(
                color: dividerColor,
                width: 1,
                thickness: 1,
                indent: 4,
                endIndent: 4,
              ),
              Expanded(
                child: _buildMacroCardCompact(
                  icon: MacroTheme.fatIcon,
                  value: '${provider.fatGoal}g',
                  unit: AppLocalizations.of(context).translate('fats'),
                  color: MacroTheme.fatColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCardCompact({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isDarkMode,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 10,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _openMacroGoalsAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NutritionAssistantScreen(
          initialPrompt: AppLocalizations.of(context)
              .translate('chat_macro_edit_chat_prompt'),
        ),
      ),
    );
  }

  Widget _buildConfigurationSection(
    BuildContext context,
    NutritionGoalsProvider provider,
    bool isDarkMode,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('configuration'),
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _getGoalDetail(provider.fitnessGoal, context),
          style: TextStyle(
            color: _mutedTextColor(isDarkMode),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: AppLocalizations.of(context).translate('personal_information'),
          subtitle:
              '${provider.sex == "male" ? AppLocalizations.of(context).translate('male') : AppLocalizations.of(context).translate('female')}, ${provider.age} ${AppLocalizations.of(context).translate('years_old')}',
          details:
              '${provider.getFormattedHeight()}  •  ${provider.getFormattedWeight()}',
          icon: Icons.person,
          iconColor: const Color(0xFF4DB6AC),
          isDarkMode: isDarkMode,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const NutritionGoalsWizardScreen(startStep: 0),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: AppLocalizations.of(context).translate('activity_level_title'),
          subtitle: provider.getActivityLevelName(
            provider.activityLevel,
            context,
          ),
          details: provider.getActivityLevelDescription(
            provider.activityLevel,
            context,
          ),
          icon: Icons.directions_run,
          iconColor: const Color(0xFF26A69A),
          isDarkMode: isDarkMode,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const NutritionGoalsWizardScreen(startStep: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: AppLocalizations.of(context).translate('objective'),
          subtitle: provider.getFitnessGoalName(provider.fitnessGoal, context),
          details: _getGoalDetail(provider.fitnessGoal, context),
          icon: Icons.track_changes,
          iconColor: const Color(0xFFFF6B9D),
          isDarkMode: isDarkMode,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const NutritionGoalsWizardScreen(startStep: 2),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          title: AppLocalizations.of(context).translate('diet_type'),
          subtitle: provider.getDietTypeName(provider.dietType, context),
          details: provider.getDietTypeDescription(provider.dietType, context),
          icon: Icons.restaurant_menu,
          iconColor: const Color(0xFFFFB74D),
          isDarkMode: isDarkMode,
          textColor: textColor,
          onTap: _openDietTypeScreen,
        ),
        const SizedBox(height: 16),
        _buildResetGoalsButton(isDarkMode),
      ],
    );
  }

  Widget _buildResetGoalsButton(bool isDarkMode) {
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final foregroundColor = AppTheme.onColor(primaryColor);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NutritionGoalsWizardScreen(),
            ),
          );
        },
        icon:
            Icon(Icons.auto_awesome_rounded, size: 18, color: foregroundColor),
        label: Text(
          AppLocalizations.of(context).translate('configure_everything_again'),
          style: TextStyle(
            color: foregroundColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required String details,
    required IconData icon,
    required Color iconColor,
    required bool isDarkMode,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardSurfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderColor(isDarkMode)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _mutedTextColor(isDarkMode),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _mutedTextColor(isDarkMode),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: textColor.withValues(alpha: 0.42),
            ),
          ],
        ),
      ),
    );
  }

  void _openDietTypeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DietTypeSelectionScreen(),
      ),
    );
  }

  void _openPersonalInfoEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NutritionGoalsWizardScreen(startStep: 0),
      ),
    );
  }

  void _openActivityLevelEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NutritionGoalsWizardScreen(startStep: 1),
      ),
    );
  }

  void _openFitnessGoalEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NutritionGoalsWizardScreen(startStep: 2),
      ),
    );
  }

  Color _cardSurfaceColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  }

  Color _secondarySurfaceColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF2A2A2A) : AppTheme.surfaceColor;
  }

  Color _borderColor(bool isDarkMode) {
    return isDarkMode ? Colors.white12 : Colors.black12;
  }

  Color _mutedTextColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
  }

  String _getGoalDetail(FitnessGoal goal, BuildContext context) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return AppLocalizations.of(context).translate('decrease_calories_20');
      case FitnessGoal.loseWeightSlowly:
        return AppLocalizations.of(context).translate('decrease_calories_10');
      case FitnessGoal.maintainWeight:
        return AppLocalizations.of(context)
            .translate('maintain_current_weight');
      case FitnessGoal.gainWeightSlowly:
        return AppLocalizations.of(context).translate('increase_calories_10');
      case FitnessGoal.gainWeight:
        return AppLocalizations.of(context).translate('increase_calories_20');
    }
  }
}
