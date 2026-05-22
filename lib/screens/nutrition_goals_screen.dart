import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../theme/macro_theme.dart';
import '../widgets/macro_edit_bottom_sheet.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'diet_type_selection_screen.dart';
import '../i18n/app_localizations.dart';
import '../utils/ui_utils.dart';

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
                  _buildHeader(isDarkMode, textColor),
                  const SizedBox(height: 8),
                  _buildSyncStatusBanner(
                      provider, theme, isDarkMode, textColor),
                  if (provider.hasPendingServerSync ||
                      provider.isSyncingWithServer)
                    const SizedBox(height: 14),
                  _buildGoalsHeroCard(provider, theme, isDarkMode, textColor),
                  const SizedBox(height: 14),
                  _buildMacroGrid(provider, theme, isDarkMode, textColor),
                  const SizedBox(height: 24),
                  _buildConfigurationSection(
                    context,
                    provider,
                    theme,
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

  Widget _buildHeader(bool isDarkMode, Color textColor) {
    const sideWidth = 56.0;

    return SizedBox(
      height: 76,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
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
                const SizedBox(height: 5),
                Text(
                  AppLocalizations.of(context).translate('your_daily_goals'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _mutedTextColor(isDarkMode),
                    height: 1.15,
                  ),
                ),
              ],
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
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final summaryText =
        '${provider.sex == "male" ? AppLocalizations.of(context).translate('male') : AppLocalizations.of(context).translate('female')}, '
        '${provider.age} ${AppLocalizations.of(context).translate('years_old')}'
        '  •  ${provider.getFormattedHeight()}'
        '  •  ${provider.getFormattedWeight()}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _secondarySurfaceColor(isDarkMode),
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderColor(isDarkMode)),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: accentColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
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
                              fontSize: 32,
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
                    const SizedBox(height: 6),
                    Text(
                      summaryText,
                      style: TextStyle(
                        color: _mutedTextColor(isDarkMode),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showManualEditDialog(
                  context,
                  provider,
                  theme,
                  isDarkMode,
                  textColor,
                ),
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
          const SizedBox(height: 16),
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
              ),
              _buildMetaChip(
                icon: Icons.restaurant_menu,
                label: provider.getDietTypeName(provider.dietType, context),
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
              _buildMetaChip(
                icon: Icons.directions_run,
                label: provider.getActivityLevelName(
                  provider.activityLevel,
                  context,
                ),
                isDarkMode: isDarkMode,
                textColor: textColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionChip(
                icon: Icons.tune,
                label: AppLocalizations.of(context)
                    .translate('edit_macronutrients'),
                isDarkMode: isDarkMode,
                textColor: textColor,
                onTap: () => _showEditMacrosDialog(context, provider),
              ),
              _buildActionChip(
                icon: Icons.auto_awesome,
                label: AppLocalizations.of(context)
                    .translate('configure_everything_again'),
                isDarkMode: isDarkMode,
                textColor: textColor,
                isPrimary: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NutritionGoalsWizardScreen(),
                    ),
                  );
                },
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
  }) {
    return Container(
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
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    required Color textColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final accentColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? accentColor : _secondarySurfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _borderColor(isDarkMode)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? AppTheme.onColor(accentColor) : textColor,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? AppTheme.onColor(accentColor) : textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroGrid(
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 700 ? 4 : 2;
        final childAspectRatio = crossAxisCount == 4 ? 1.32 : 1.44;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMacroCard(
              icon: MacroTheme.caloriesIcon,
              label: AppLocalizations.of(context).translate('calories'),
              value: '${provider.caloriesGoal}',
              unit: 'kcal',
              accentColor: MacroTheme.caloriesColor,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
            _buildMacroCard(
              icon: MacroTheme.proteinIcon,
              label: AppLocalizations.of(context).translate('protein_full'),
              value: '${provider.proteinGoal}',
              unit: 'g',
              accentColor: MacroTheme.proteinColor,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
            _buildMacroCard(
              icon: MacroTheme.carbsIcon,
              label: AppLocalizations.of(context).translate('carbohydrates'),
              value: '${provider.carbsGoal}',
              unit: 'g',
              accentColor: MacroTheme.carbsColor,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
            _buildMacroCard(
              icon: MacroTheme.fatIcon,
              label: AppLocalizations.of(context).translate('fats'),
              value: '${provider.fatGoal}',
              unit: 'g',
              accentColor: MacroTheme.fatColor,
              isDarkMode: isDarkMode,
              textColor: textColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMacroCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color accentColor,
    required bool isDarkMode,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardSurfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDarkMode ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 21,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        color: _mutedTextColor(isDarkMode),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _mutedTextColor(isDarkMode),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection(
    BuildContext context,
    NutritionGoalsProvider provider,
    ThemeData theme,
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
          onTap: () {
            _showDietTypeDialog(provider, theme, isDarkMode, textColor);
          },
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

  void _showDietTypeDialog(
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DietTypeSelectionScreen(),
      ),
    );
  }

  void _showEditMacrosDialog(
    BuildContext context,
    NutritionGoalsProvider provider,
  ) {
    showMacroEditBottomSheet(
      context: context,
      provider: provider,
    );
  }

  void _showManualEditDialog(
    BuildContext screenContext,
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final cardColor = _cardSurfaceColor(isDarkMode);
    final caloriesController =
        TextEditingController(text: provider.caloriesGoal.toString());
    final proteinController =
        TextEditingController(text: provider.proteinGoal.toString());
    final carbsController =
        TextEditingController(text: provider.carbsGoal.toString());
    final fatController =
        TextEditingController(text: provider.fatGoal.toString());

    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: textColor.withValues(alpha: isDarkMode ? 0.08 : 0.06),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          AppLocalizations.of(screenContext).translate('edit_goals_manually'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildManualGoalField(
                controller: caloriesController,
                label: AppLocalizations.of(screenContext)
                    .translate('calories_kcal'),
                icon: Icons.local_fire_department,
                iconColor: const Color(0xFFFF8A65),
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 12),
              _buildManualGoalField(
                controller: proteinController,
                label:
                    AppLocalizations.of(screenContext).translate('protein_g'),
                icon: MacroTheme.proteinIcon,
                iconColor: MacroTheme.proteinColor,
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 12),
              _buildManualGoalField(
                controller: carbsController,
                label: AppLocalizations.of(screenContext)
                    .translate('carbohydrates_g'),
                icon: MacroTheme.carbsIcon,
                iconColor: MacroTheme.carbsColor,
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 12),
              _buildManualGoalField(
                controller: fatController,
                label: AppLocalizations.of(screenContext).translate('fats_g'),
                icon: MacroTheme.fatIcon,
                iconColor: MacroTheme.fatColor,
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              AppLocalizations.of(screenContext).translate('cancel'),
              style: TextStyle(color: textColor.withValues(alpha: 0.72)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final calories = int.tryParse(caloriesController.text) ??
                  provider.caloriesGoal;
              final protein =
                  int.tryParse(proteinController.text) ?? provider.proteinGoal;
              final carbs =
                  int.tryParse(carbsController.text) ?? provider.carbsGoal;
              final fat = int.tryParse(fatController.text) ?? provider.fatGoal;

              provider.updateManualGoals(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
              );

              Navigator.pop(dialogContext);
              UIUtils.showPrimarySnackBar(
                screenContext,
                AppLocalizations.of(screenContext)
                    .translate('goals_updated_successfully'),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppTheme.primaryColorDarkMode
                  : AppTheme.primaryColor,
              foregroundColor: AppTheme.onPrimaryFor(isDarkMode),
            ),
            child: Text(AppLocalizations.of(screenContext).translate('save')),
          ),
        ],
      ),
    );
  }

  Widget _buildManualGoalField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: iconColor),
        fillColor: _secondarySurfaceColor(isDarkMode),
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDarkMode
                ? AppTheme.primaryColorDarkMode
                : AppTheme.primaryColor,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
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
