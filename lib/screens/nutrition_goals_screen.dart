import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/macro_edit_bottom_sheet.dart';
import '../widgets/macro_card_gradient.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'diet_type_selection_screen.dart';
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
    final textColor = isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).translate('nutrition_goals'),
          style: AppTheme.headingLarge.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
      ),
      body: Consumer<NutritionGoalsProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Goals Summary Card - Specific for this screen
                _buildGoalsSummaryCard(provider, theme, isDarkMode, textColor),

                const SizedBox(height: 16),

                // Macros in row - 4 cards fora do card principal
                Row(
                  children: [
                    Expanded(
                      child: MacroCardGradient(
                        icon: '🔥',
                        label: AppLocalizations.of(context).translate('calories'),
                        value: '${provider.caloriesGoal}',
                        unit: 'kcal',
                        startColor: const Color(0xFFFF6B9D),
                        endColor: const Color(0xFFFFA06B),
                        isDarkMode: isDarkMode,
                        isCompact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MacroCardGradient(
                        icon: '💪',
                        label: AppLocalizations.of(context).translate('protein_full'),
                        value: '${provider.proteinGoal}',
                        unit: 'g',
                        startColor: const Color(0xFF9575CD),
                        endColor: const Color(0xFFBA68C8),
                        isDarkMode: isDarkMode,
                        isCompact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MacroCardGradient(
                        icon: '🌾',
                        label: AppLocalizations.of(context).translate('carbohydrates'),
                        value: '${provider.carbsGoal}',
                        unit: 'g',
                        startColor: const Color(0xFFFFB74D),
                        endColor: const Color(0xFFFF9800),
                        isDarkMode: isDarkMode,
                        isCompact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MacroCardGradient(
                        icon: '🥑',
                        label: AppLocalizations.of(context).translate('fats'),
                        value: '${provider.fatGoal}',
                        unit: 'g',
                        startColor: const Color(0xFF4DB6AC),
                        endColor: const Color(0xFF26A69A),
                        isDarkMode: isDarkMode,
                        isCompact: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Diet Type Card
                _buildDietTypeCard(context, provider, theme, isDarkMode, textColor),

                const SizedBox(height: 12),

                // Edit Macronutrients Button
                _buildEditMacrosButton(provider, theme, isDarkMode, textColor),

                const SizedBox(height: 24),

                // Configuration section
                _buildCalculatedConfigSection(context, provider, theme, isDarkMode, textColor),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalsSummaryCard(
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLocalizations.of(context).translate('your_daily_goals'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () => _showManualEditDialog(context, provider, theme, isDarkMode, textColor),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.edit,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDietTypeCard(
    BuildContext context,
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return _buildInfoCard(
      cardColor: cardColor,
      isDarkMode: isDarkMode,
      title: AppLocalizations.of(context).translate('diet_type'),
      subtitle: provider.getDietTypeName(provider.dietType, context),
      details: provider.getDietTypeDescription(provider.dietType, context),
      icon: Icons.restaurant_menu,
      iconColor: const Color(0xFFFFB74D), // Cor de Carboidratos
      theme: theme,
      textColor: textColor,
      onTap: () {
        _showDietTypeDialog(provider, theme, isDarkMode, textColor);
      },
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

  Widget _buildEditMacrosButton(
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return InkWell(
      onTap: () => _showEditMacrosDialog(context, provider, theme, isDarkMode, textColor),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9575CD).withValues(alpha: 0.15), // Cor de Proteínas
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune, color: Color(0xFF9575CD), size: 24), // Cor de Proteínas
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('edit_macronutrients'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).translate('adjust_percentages_or_grams'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: textColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatedConfigSection(
    BuildContext context,
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('configuration'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Personal Info Card
        _buildInfoCard(
          cardColor: cardColor,
          isDarkMode: isDarkMode,
          title: AppLocalizations.of(context).translate('personal_information'),
          subtitle: '${provider.sex == "male" ? AppLocalizations.of(context).translate('male') : AppLocalizations.of(context).translate('female')}, ${provider.age} ${AppLocalizations.of(context).translate('years_old')}',
          details: '${provider.getFormattedHeight()}, ${provider.getFormattedWeight()}',
          icon: Icons.person,
          iconColor: const Color(0xFF4DB6AC), // Cor de Gorduras
          theme: theme,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NutritionGoalsWizardScreen(startStep: 0),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Activity Level Card
        _buildInfoCard(
          cardColor: cardColor,
          isDarkMode: isDarkMode,
          title: AppLocalizations.of(context).translate('activity_level_title'),
          subtitle: provider.getActivityLevelName(provider.activityLevel, context),
          details: provider.getActivityLevelDescription(provider.activityLevel, context),
          icon: Icons.directions_run,
          iconColor: const Color(0xFF26A69A), // Cor de Gorduras (tom mais escuro)
          theme: theme,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NutritionGoalsWizardScreen(startStep: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Fitness Goal Card
        _buildInfoCard(
          cardColor: cardColor,
          isDarkMode: isDarkMode,
          title: AppLocalizations.of(context).translate('objective'),
          subtitle: provider.getFitnessGoalName(provider.fitnessGoal, context),
          details: _getGoalDetail(provider.fitnessGoal, context),
          icon: Icons.track_changes,
          iconColor: const Color(0xFFFF6B9D), // Cor de Calorias
          theme: theme,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NutritionGoalsWizardScreen(startStep: 2),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Complete wizard button
        SizedBox(
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
            icon: const Icon(Icons.auto_awesome),
            label: Text(AppLocalizations.of(context).translate('configure_everything_again')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required Color cardColor,
    required bool isDarkMode,
    required String title,
    required String subtitle,
    required String details,
    required IconData icon,
    required Color iconColor,
    required ThemeData theme,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: textColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMacrosDialog(
    BuildContext context,
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MacroEditBottomSheet(
        provider: provider,
        theme: theme,
        isDarkMode: isDarkMode,
        textColor: textColor,
        cardColor: cardColor,
      ),
    );
  }

  void _showManualEditDialog(
    BuildContext context,
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;
    final caloriesController = TextEditingController(text: provider.caloriesGoal.toString());
    final proteinController = TextEditingController(text: provider.proteinGoal.toString());
    final carbsController = TextEditingController(text: provider.carbsGoal.toString());
    final fatController = TextEditingController(text: provider.fatGoal.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          AppLocalizations.of(context).translate('edit_goals_manually'),
          style: TextStyle(color: textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('calories_kcal'),
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.local_fire_department, color: Colors.orange),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: proteinController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('protein_g'),
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.restaurant_menu, color: const Color(0xFF9575CD)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('carbohydrates_g'),
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.bakery_dining, color: const Color(0xFFA1887F)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fatController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('fats_g'),
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.opacity, color: const Color(0xFF90A4AE)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel'), style: TextStyle(color: textColor.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              final calories = int.tryParse(caloriesController.text) ?? provider.caloriesGoal;
              final protein = int.tryParse(proteinController.text) ?? provider.proteinGoal;
              final carbs = int.tryParse(carbsController.text) ?? provider.carbsGoal;
              final fat = int.tryParse(fatController.text) ?? provider.fatGoal;

              provider.updateManualGoals(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
              );

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).translate('goals_updated_successfully')),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context).translate('save')),
          ),
        ],
      ),
    );
  }

  String _getGoalDetail(FitnessGoal goal, BuildContext context) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return AppLocalizations.of(context).translate('decrease_calories_20');
      case FitnessGoal.loseWeightSlowly:
        return AppLocalizations.of(context).translate('decrease_calories_10');
      case FitnessGoal.maintainWeight:
        return AppLocalizations.of(context).translate('maintain_current_weight');
      case FitnessGoal.gainWeightSlowly:
        return AppLocalizations.of(context).translate('increase_calories_10');
      case FitnessGoal.gainWeight:
        return AppLocalizations.of(context).translate('increase_calories_20');
    }
  }
}
