import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'diet_type_selection_screen.dart';
import 'free_chat_screen.dart';
import 'nutrition_assistant_screen.dart';
import '../i18n/app_localizations.dart';
import '../widgets/macro_edit_bottom_sheet.dart';

class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({Key? key}) : super(key: key);

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _CalculationDataRowData {
  const _CalculationDataRowData({
    required this.title,
    required this.value,
    required this.details,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String value;
  final String details;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
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
    final goalName = provider.getFitnessGoalName(provider.fitnessGoal, context);
    final dietName = provider.getDietTypeName(provider.dietType, context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                      AppLocalizations.of(context).translate(
                        'nutrition_goals_daily_target',
                      ),
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
                    const SizedBox(height: 4),
                    Text(
                      '$goalName • $dietName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedTextColor(isDarkMode),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: AppLocalizations.of(context)
                    .translate('edit_macronutrients'),
                child: InkWell(
                  onTap: _openMacroEditor,
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
                      Icons.tune_rounded,
                      color: textColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).translate(
              'nutrition_goals_macros_per_day',
            ),
            style: TextStyle(
              color: _mutedTextColor(isDarkMode),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildMacroSummary(provider, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildMacroSummary(
    NutritionGoalsProvider provider,
    bool isDarkMode,
  ) {
    final dividerColor = _borderColor(isDarkMode);

    return IntrinsicHeight(
      child: Row(
        children: [
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          unit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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
        builder: (context) => FreeChatScreen(
          initialPrompt: AppLocalizations.of(context)
              .translate('chat_macro_edit_chat_prompt'),
          toolType: NutritionAssistantScreen.macroGoalsToolType,
          forceNewConversation: true,
        ),
      ),
    );
  }

  void _openMacroEditor() {
    showMacroEditBottomSheet(
      context: context,
      provider: context.read<NutritionGoalsProvider>(),
    );
  }

  Widget _buildConfigurationSection(
    BuildContext context,
    NutritionGoalsProvider provider,
    bool isDarkMode,
    Color textColor,
  ) {
    final personalSummary =
        '${provider.sex == "male" ? AppLocalizations.of(context).translate('male') : AppLocalizations.of(context).translate('female')}, ${provider.age} ${AppLocalizations.of(context).translate('years_old')}';
    final personalDetails =
        '${provider.getFormattedHeight()} • ${provider.getFormattedWeight()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate(
            'nutrition_goals_calculation_data',
          ),
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).translate(
            'nutrition_goals_calculation_data_hint',
          ),
          style: TextStyle(
            color: _mutedTextColor(isDarkMode),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        _buildCalculationDataGroup(
          rows: [
            _CalculationDataRowData(
              title: AppLocalizations.of(context)
                  .translate('personal_information'),
              value: personalSummary,
              details: personalDetails,
              icon: Icons.person,
              iconColor: const Color(0xFF4DB6AC),
              onTap: _openPersonalInfoEditor,
            ),
            _CalculationDataRowData(
              title: AppLocalizations.of(context)
                  .translate('activity_level_title'),
              value: provider.getActivityLevelName(
                provider.activityLevel,
                context,
              ),
              details: provider.getActivityLevelDescription(
                provider.activityLevel,
                context,
              ),
              icon: Icons.directions_run,
              iconColor: const Color(0xFF26A69A),
              onTap: _openActivityLevelEditor,
            ),
            _CalculationDataRowData(
              title: AppLocalizations.of(context).translate('objective'),
              value: provider.getFitnessGoalName(provider.fitnessGoal, context),
              details: _getGoalDetail(provider.fitnessGoal, context),
              icon: Icons.track_changes,
              iconColor: const Color(0xFFFF6B9D),
              onTap: _openFitnessGoalEditor,
            ),
            _CalculationDataRowData(
              title: AppLocalizations.of(context).translate('diet_type'),
              value: provider.getDietTypeName(provider.dietType, context),
              details: provider.getDietTypeDescription(
                provider.dietType,
                context,
              ),
              icon: Icons.restaurant_menu,
              iconColor: const Color(0xFFFFB74D),
              onTap: _openDietTypeScreen,
            ),
          ],
          isDarkMode: isDarkMode,
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildCalculationDataGroup({
    required List<_CalculationDataRowData> rows,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _buildCalculationDataRow(
              rows[index],
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
            if (index < rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                color: _borderColor(isDarkMode),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculationDataRow(
    _CalculationDataRowData data, {
    required bool isDarkMode,
    required Color textColor,
  }) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    data.iconColor.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _mutedTextColor(isDarkMode),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.details,
                    maxLines: 1,
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
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
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
