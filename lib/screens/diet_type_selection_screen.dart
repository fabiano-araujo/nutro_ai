import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/macro_edit_bottom_sheet.dart';

class DietTypeSelectionScreen extends StatelessWidget {
  const DietTypeSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final accentColor = theme.colorScheme.primary;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

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
          _tr(context, 'diet_type', 'Tipo de Dieta'),
          style: AppTheme.headingLarge.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
      ),
      body: Consumer<NutritionGoalsProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      Icon(Icons.restaurant_menu, color: accentColor, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _tr(context, 'choose_diet_type', 'Escolha o Tipo de Dieta'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tr(
                  context,
                  'choose_diet_type_description',
                  'Escolha o tipo de dieta que melhor se adapta aos seus objetivos',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              ...selectableDietTypes.map((dietType) {
                final isSelected = provider.dietType == dietType;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildDietTypeCard(
                    icon: _getDietIcon(dietType),
                    title: provider.getDietTypeName(dietType, context),
                    subtitle: provider.getDietTypeDescription(
                      dietType,
                      context,
                    ),
                    isSelected: isSelected,
                    theme: theme,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    onTap: () {
                      if (dietType == DietType.custom) {
                        _showMacroEditBottomSheet(context, provider);
                      } else {
                        final messenger = ScaffoldMessenger.of(context);
                        provider.updateDietType(dietType);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              _tr(
                                context,
                                'changes_saved_successfully',
                                'Mudanças salvas com sucesso!',
                              ),
                            ),
                            backgroundColor: accentColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  void _showMacroEditBottomSheet(
    BuildContext context,
    NutritionGoalsProvider provider,
  ) {
    showMacroEditBottomSheet(
      context: context,
      provider: provider,
    );
  }

  String _tr(BuildContext context, String key, String fallback) {
    final translated = context.tr.translate(key);
    return translated == key ? fallback : translated;
  }

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);

  Color _inputFillColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;

  Color _subtleBorderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white12 : Colors.black12;

  Widget _buildDietTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDarkMode,
    required Color textColor,
  }) {
    final accentColor = theme.colorScheme.primary;
    final selectedForeground = theme.colorScheme.onPrimary;
    final foregroundColor = isSelected ? selectedForeground : textColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : _subtleBorderColor(isDarkMode),
            width: isSelected ? 0 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedForeground.withValues(alpha: 0.16)
                    : _inputFillColor(isDarkMode),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected
                      ? selectedForeground.withValues(alpha: 0.2)
                      : _subtleBorderColor(isDarkMode),
                ),
              ),
              child: Icon(
                icon,
                size: 21,
                color: foregroundColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.64),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked_rounded,
              color: foregroundColor.withValues(alpha: isSelected ? 1 : 0.35),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDietIcon(DietType type) {
    switch (type) {
      case DietType.aiRecommended:
        return Icons.auto_awesome;
      case DietType.standard:
      case DietType.balanced:
        return Icons.restaurant_menu;
      case DietType.ketogenic:
        return Icons.eco;
      case DietType.lowCarb:
        return Icons.no_food;
      case DietType.highProtein:
        return Icons.fitness_center;
      case DietType.mediterranean:
        return Icons.waves;
      case DietType.paleo:
        return Icons.local_fire_department;
      case DietType.lowFat:
        return Icons.water_drop_outlined;
      case DietType.dash:
        return Icons.favorite_border;
      case DietType.custom:
        return Icons.tune;
    }
  }
}
