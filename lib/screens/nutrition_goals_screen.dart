import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';
import 'nutrition_goals_wizard_screen.dart';

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
          'Metas Nutricionais',
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

                // Current Goals Summary with edit button
                _buildGoalsSummaryCard(provider, theme, isDarkMode, textColor),

                const SizedBox(height: 16),

                // Diet Type Card (moved here to be close to macros)
                _buildDietTypeCard(provider, theme, isDarkMode, textColor),

                const SizedBox(height: 12),

                // Edit Macronutrients Button
                _buildEditMacrosButton(provider, theme, isDarkMode, textColor),

                const SizedBox(height: 24),

                // Configuration section
                _buildCalculatedConfigSection(provider, theme, isDarkMode, textColor),

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
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suas Metas Diárias',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showManualEditDialog(context, provider, theme, isDarkMode, textColor);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.edit, color: textColor, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calories
          _buildGoalRow(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            label: 'Calorias',
            value: '${provider.caloriesGoal} kcal',
            theme: theme,
            textColor: textColor,
          ),
          const SizedBox(height: 12),

          // Protein
          _buildGoalRow(
            icon: Icons.fitness_center,
            iconColor: const Color(0xFF9575CD),
            label: 'Proteína',
            value: '${provider.proteinGoal}g',
            theme: theme,
            textColor: textColor,
          ),
          const SizedBox(height: 12),

          // Carbs
          _buildGoalRow(
            icon: Icons.grain,
            iconColor: const Color(0xFFA1887F),
            label: 'Carboidratos',
            value: '${provider.carbsGoal}g',
            theme: theme,
            textColor: textColor,
          ),
          const SizedBox(height: 12),

          // Fat
          _buildGoalRow(
            icon: Icons.water_drop,
            iconColor: const Color(0xFF90A4AE),
            label: 'Gorduras',
            value: '${provider.fatGoal}g',
            theme: theme,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required ThemeData theme,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDietTypeCard(
    NutritionGoalsProvider provider,
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
  ) {
    final cardColor = isDarkMode ? AppTheme.darkCardColor : AppTheme.cardColor;

    return _buildInfoCard(
      cardColor: cardColor,
      isDarkMode: isDarkMode,
      title: 'Tipo de Dieta',
      subtitle: provider.getDietTypeName(provider.dietType),
      details: provider.getDietTypeDescription(provider.dietType),
      icon: Icons.restaurant_menu,
      iconColor: Colors.orange,
      theme: theme,
      textColor: textColor,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NutritionGoalsWizardScreen(startStep: 3),
          ),
        );
      },
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
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editar Macronutrientes',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ajuste as porcentagens ou valores em gramas',
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
          'Configuração',
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
          title: 'Informações Pessoais',
          subtitle: '${provider.sex == "male" ? "Masculino" : "Feminino"}, ${provider.age} anos',
          details: '${provider.height.toStringAsFixed(0)} cm, ${provider.weight.toStringAsFixed(1)} kg',
          icon: Icons.person,
          iconColor: Colors.blue,
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
          title: 'Nível de Atividade',
          subtitle: provider.getActivityLevelName(provider.activityLevel),
          details: provider.getActivityLevelDescription(provider.activityLevel),
          icon: Icons.directions_run,
          iconColor: Colors.green,
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
          title: 'Objetivo',
          subtitle: provider.getFitnessGoalName(provider.fitnessGoal),
          details: _getGoalDetail(provider.fitnessGoal),
          icon: Icons.track_changes,
          iconColor: Colors.purple,
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
            label: const Text('Configurar Tudo Novamente'),
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

    showDialog(
      context: context,
      builder: (context) => _MacroEditDialog(
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
          'Editar Metas Manualmente',
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
                  labelText: 'Calorias (kcal)',
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
                  labelText: 'Proteína (g)',
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.fitness_center, color: const Color(0xFF9575CD)),
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
                  labelText: 'Carboidratos (g)',
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.grain, color: const Color(0xFFA1887F)),
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
                  labelText: 'Gorduras (g)',
                  labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.water_drop, color: const Color(0xFF90A4AE)),
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
            child: Text('Cancelar', style: TextStyle(color: textColor.withValues(alpha: 0.7))),
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
                const SnackBar(
                  content: Text('Metas atualizadas com sucesso!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  String _getGoalDetail(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return 'Déficit calórico de 500 kcal/dia';
      case FitnessGoal.maintainWeight:
        return 'Manter peso atual';
      case FitnessGoal.gainWeight:
        return 'Superávit de 300 kcal/dia';
      case FitnessGoal.gainMuscle:
        return 'Superávit de 500 kcal/dia';
    }
  }
}

// Dialog widget for editing macronutrients
class _MacroEditDialog extends StatefulWidget {
  final NutritionGoalsProvider provider;
  final ThemeData theme;
  final bool isDarkMode;
  final Color textColor;
  final Color cardColor;

  const _MacroEditDialog({
    required this.provider,
    required this.theme,
    required this.isDarkMode,
    required this.textColor,
    required this.cardColor,
  });

  @override
  State<_MacroEditDialog> createState() => _MacroEditDialogState();
}

class _MacroEditDialogState extends State<_MacroEditDialog> {
  int _selectedMode = 0; // 0 = Percentage, 1 = Grams, 2 = Grams/kg

  // Percentage mode
  late double _carbsPercentage;
  late double _proteinPercentage;
  late double _fatPercentage;

  // Grams mode
  late double _carbsGrams;
  late double _proteinGrams;
  late double _fatGrams;

  // Grams per kg mode
  late double _carbsPerKg;
  late double _proteinPerKg;
  late double _fatPerKg;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Initialize percentages
    _carbsPercentage = widget.provider.carbsPercentage.toDouble();
    _proteinPercentage = widget.provider.proteinPercentage.toDouble();
    _fatPercentage = widget.provider.fatPercentage.toDouble();

    // Initialize grams
    _carbsGrams = widget.provider.carbsGoal.toDouble();
    _proteinGrams = widget.provider.proteinGoal.toDouble();
    _fatGrams = widget.provider.fatGoal.toDouble();

    // Initialize grams per kg (calculate from current grams)
    final weight = widget.provider.weight;
    _carbsPerKg = weight > 0 ? _carbsGrams / weight : 3.0;
    _proteinPerKg = weight > 0 ? _proteinGrams / weight : 2.0;
    _fatPerKg = weight > 0 ? _fatGrams / weight : 1.0;
  }

  void _validateAndUpdate() {
    if (_selectedMode == 0) {
      _validatePercentages();
    } else if (_selectedMode == 1) {
      _validateGrams();
    } else {
      _validateGramsPerKg();
    }
  }

  void _validatePercentages() {
    final total = _carbsPercentage + _proteinPercentage + _fatPercentage;

    if ((total - 100).abs() > 0.1) {
      setState(() {
        _errorMessage = 'A soma das porcentagens deve ser 100% (atual: ${total.toStringAsFixed(0)}%)';
      });
      return;
    }

    // Update provider
    widget.provider.updateMacroPercentages(
      carbs: _carbsPercentage.round(),
      protein: _proteinPercentage.round(),
      fat: _fatPercentage.round(),
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Macronutrientes atualizados com sucesso!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _validateGrams() {
    final totalCalories = widget.provider.caloriesGoal;

    // Calculate calories from grams
    double carbsCalories = _carbsGrams * 4;
    double proteinCalories = _proteinGrams * 4;
    double fatCalories = _fatGrams * 9;
    double totalFromMacros = carbsCalories + proteinCalories + fatCalories;

    // Allow 1% tolerance (stricter validation)
    final difference = (totalFromMacros - totalCalories).abs();
    final tolerance = totalCalories * 0.01;

    if (difference > tolerance) {
      setState(() {
        _errorMessage = 'Total de calorias dos macros (${totalFromMacros.toStringAsFixed(0)}) deve ser igual à meta (${totalCalories} kcal). Use o botão "Ajustar" abaixo.';
      });
      return;
    }

    // Auto-adjust if there's a small difference (within tolerance)
    if (totalFromMacros != totalCalories && totalFromMacros > 0) {
      final factor = totalCalories / totalFromMacros;
      carbsCalories = _carbsGrams * 4 * factor;
      proteinCalories = _proteinGrams * 4 * factor;
      fatCalories = _fatGrams * 9 * factor;
      totalFromMacros = carbsCalories + proteinCalories + fatCalories;
    }

    // Calculate percentages from adjusted calories
    final carbsPercentage = ((carbsCalories / totalCalories) * 100).round();
    final proteinPercentage = ((proteinCalories / totalCalories) * 100).round();
    final fatPercentage = 100 - carbsPercentage - proteinPercentage;

    // Update provider
    widget.provider.updateMacroPercentages(
      carbs: carbsPercentage,
      protein: proteinPercentage,
      fat: fatPercentage,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Macronutrientes atualizados com sucesso!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _autoAdjust() {
    if (_selectedMode != 0) return;

    final total = _carbsPercentage + _proteinPercentage + _fatPercentage;

    if (total == 0) return;

    // Normalize to 100%
    setState(() {
      _carbsPercentage = (_carbsPercentage / total * 100);
      _proteinPercentage = (_proteinPercentage / total * 100);
      _fatPercentage = (_fatPercentage / total * 100);
      _errorMessage = null;
    });
  }

  void _autoAdjustGrams() {
    if (_selectedMode != 1) return;

    final targetCalories = widget.provider.caloriesGoal;

    // Calculate current total calories
    final carbsCalories = _carbsGrams * 4;
    final proteinCalories = _proteinGrams * 4;
    final fatCalories = _fatGrams * 9;
    final totalCalories = carbsCalories + proteinCalories + fatCalories;

    if (totalCalories == 0) return;

    // Calculate proportional adjustment factor
    final factor = targetCalories / totalCalories;

    // Adjust all macros proportionally
    setState(() {
      _carbsGrams = (_carbsGrams * factor);
      _proteinGrams = (_proteinGrams * factor);
      _fatGrams = (_fatGrams * factor);
      _errorMessage = null;
    });
  }

  void _autoAdjustGramsPerKg() {
    if (_selectedMode != 2) return;

    final targetCalories = widget.provider.caloriesGoal;
    final weight = widget.provider.weight;

    // Calculate current total calories
    final carbsGrams = _carbsPerKg * weight;
    final proteinGrams = _proteinPerKg * weight;
    final fatGrams = _fatPerKg * weight;

    final carbsCalories = carbsGrams * 4;
    final proteinCalories = proteinGrams * 4;
    final fatCalories = fatGrams * 9;
    final totalCalories = carbsCalories + proteinCalories + fatCalories;

    if (totalCalories == 0) return;

    // Calculate proportional adjustment factor
    final factor = targetCalories / totalCalories;

    // Adjust all macros proportionally
    setState(() {
      _carbsPerKg = (_carbsPerKg * factor);
      _proteinPerKg = (_proteinPerKg * factor);
      _fatPerKg = (_fatPerKg * factor);
      _errorMessage = null;
    });
  }

  void _validateGramsPerKg() {
    final totalCalories = widget.provider.caloriesGoal;
    final weight = widget.provider.weight;

    // Calculate grams from grams per kg
    final carbsGrams = _carbsPerKg * weight;
    final proteinGrams = _proteinPerKg * weight;
    final fatGrams = _fatPerKg * weight;

    // Calculate calories from grams
    double carbsCalories = carbsGrams * 4;
    double proteinCalories = proteinGrams * 4;
    double fatCalories = fatGrams * 9;
    double totalFromMacros = carbsCalories + proteinCalories + fatCalories;

    // Allow 1% tolerance (stricter validation)
    final difference = (totalFromMacros - totalCalories).abs();
    final tolerance = totalCalories * 0.01;

    if (difference > tolerance) {
      setState(() {
        _errorMessage = 'Total de calorias dos macros (${totalFromMacros.toStringAsFixed(0)}) deve ser igual à meta (${totalCalories} kcal). Use o botão "Ajustar" abaixo.';
      });
      return;
    }

    // Auto-adjust if there's a small difference (within tolerance)
    if (totalFromMacros != totalCalories && totalFromMacros > 0) {
      final factor = totalCalories / totalFromMacros;
      carbsCalories = carbsGrams * 4 * factor;
      proteinCalories = proteinGrams * 4 * factor;
      fatCalories = fatGrams * 9 * factor;
      totalFromMacros = carbsCalories + proteinCalories + fatCalories;
    }

    // Calculate percentages from adjusted calories
    final carbsPercentage = ((carbsCalories / totalCalories) * 100).round();
    final proteinPercentage = ((proteinCalories / totalCalories) * 100).round();
    final fatPercentage = 100 - carbsPercentage - proteinPercentage;

    // Update provider
    widget.provider.updateMacroPercentages(
      carbs: carbsPercentage,
      protein: proteinPercentage,
      fat: fatPercentage,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Macronutrientes atualizados com sucesso!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPercentage = _carbsPercentage + _proteinPercentage + _fatPercentage;
    final isValid = (totalPercentage - 100).abs() < 0.1;

    return AlertDialog(
      backgroundColor: widget.cardColor,
      title: Text(
        'Editar Macronutrientes',
        style: TextStyle(color: widget.textColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle between 3 modes
            Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.grey[800]
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      label: '%',
                      isSelected: _selectedMode == 0,
                      onTap: () => setState(() => _selectedMode = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'g',
                      isSelected: _selectedMode == 1,
                      onTap: () => setState(() => _selectedMode = 1),
                    ),
                  ),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'g/kg',
                      isSelected: _selectedMode == 2,
                      onTap: () => setState(() => _selectedMode = 2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_selectedMode == 0) ...[
              // Percentage mode
              Text(
                'Meta de calorias: ${widget.provider.caloriesGoal} kcal',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              _buildPercentageSlider(
                label: 'Carboidratos',
                value: _carbsPercentage,
                color: const Color(0xFFA1887F),
                icon: Icons.grain,
                onChanged: (value) {
                  setState(() {
                    _carbsPercentage = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildPercentageSlider(
                label: 'Proteína',
                value: _proteinPercentage,
                color: const Color(0xFF9575CD),
                icon: Icons.fitness_center,
                onChanged: (value) {
                  setState(() {
                    _proteinPercentage = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildPercentageSlider(
                label: 'Gorduras',
                value: _fatPercentage,
                color: const Color(0xFF90A4AE),
                icon: Icons.water_drop,
                onChanged: (value) {
                  setState(() {
                    _fatPercentage = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Total display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isValid
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isValid ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: widget.theme.textTheme.bodyLarge?.copyWith(
                        color: widget.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${totalPercentage.toStringAsFixed(0)}%',
                          style: widget.theme.textTheme.bodyLarge?.copyWith(
                            color: isValid ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isValid) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _autoAdjust,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Ajustar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_selectedMode == 1) ...[
              // Grams mode
              Text(
                'Meta de calorias: ${widget.provider.caloriesGoal} kcal',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              _buildGramsInput(
                label: 'Carboidratos',
                value: _carbsGrams,
                color: const Color(0xFFA1887F),
                icon: Icons.grain,
                caloriesPerGram: 4,
                onChanged: (value) {
                  setState(() {
                    _carbsGrams = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildGramsInput(
                label: 'Proteína',
                value: _proteinGrams,
                color: const Color(0xFF9575CD),
                icon: Icons.fitness_center,
                caloriesPerGram: 4,
                onChanged: (value) {
                  setState(() {
                    _proteinGrams = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildGramsInput(
                label: 'Gorduras',
                value: _fatGrams,
                color: const Color(0xFF90A4AE),
                icon: Icons.water_drop,
                caloriesPerGram: 9,
                onChanged: (value) {
                  setState(() {
                    _fatGrams = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Total calories from macros
              _buildCaloriesSummary(),
            ] else ...[
              // Grams per kg mode
              Text(
                'Peso corporal: ${widget.provider.weight.toStringAsFixed(1)} kg',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Meta de calorias: ${widget.provider.caloriesGoal} kcal',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              _buildGramsPerKgInput(
                label: 'Carboidratos',
                value: _carbsPerKg,
                color: const Color(0xFFA1887F),
                icon: Icons.grain,
                caloriesPerGram: 4,
                weight: widget.provider.weight,
                onChanged: (value) {
                  setState(() {
                    _carbsPerKg = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildGramsPerKgInput(
                label: 'Proteína',
                value: _proteinPerKg,
                color: const Color(0xFF9575CD),
                icon: Icons.fitness_center,
                caloriesPerGram: 4,
                weight: widget.provider.weight,
                onChanged: (value) {
                  setState(() {
                    _proteinPerKg = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildGramsPerKgInput(
                label: 'Gorduras',
                value: _fatPerKg,
                color: const Color(0xFF90A4AE),
                icon: Icons.water_drop,
                caloriesPerGram: 9,
                weight: widget.provider.weight,
                onChanged: (value) {
                  setState(() {
                    _fatPerKg = value;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Total calories from macros
              _buildCaloriesSummaryPerKg(),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: widget.textColor.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _validateAndUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : widget.textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPercentageSlider({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    final calories = (widget.provider.caloriesGoal * (value / 100)).round();
    final grams = label == 'Gorduras'
        ? (calories / 9).round()
        : (calories / 4).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(0)}% (${grams}g)',
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildGramsInput({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    required int caloriesPerGram,
    required ValueChanged<double> onChanged,
  }) {
    final calories = (value * caloriesPerGram).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: widget.textColor),
                decoration: InputDecoration(
                  suffixText: 'g',
                  hintText: value.toStringAsFixed(0),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.textColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (text) {
                  final parsed = double.tryParse(text);
                  if (parsed != null) {
                    onChanged(parsed);
                  }
                },
                controller: TextEditingController(
                  text: value.toStringAsFixed(0),
                )..selection = TextSelection.collapsed(
                  offset: value.toStringAsFixed(0).length,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${calories} kcal',
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaloriesSummary() {
    final carbsCalories = _carbsGrams * 4;
    final proteinCalories = _proteinGrams * 4;
    final fatCalories = _fatGrams * 9;
    final totalCalories = carbsCalories + proteinCalories + fatCalories;
    final targetCalories = widget.provider.caloriesGoal;
    final difference = (totalCalories - targetCalories).abs();
    final isClose = difference <= targetCalories * 0.01;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClose
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isClose ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total dos macros:',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor,
                ),
              ),
              Text(
                '${totalCalories.toStringAsFixed(0)} kcal',
                style: widget.theme.textTheme.bodyLarge?.copyWith(
                  color: isClose ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meta:',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '$targetCalories kcal',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          if (!isClose) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diferença: ${difference.toStringAsFixed(0)} kcal',
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: _autoAdjustGrams,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Ajustar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGramsPerKgInput({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    required int caloriesPerGram,
    required double weight,
    required ValueChanged<double> onChanged,
  }) {
    final totalGrams = value * weight;
    final calories = (totalGrams * caloriesPerGram).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: widget.textColor),
                decoration: InputDecoration(
                  suffixText: 'g/kg',
                  hintText: value.toStringAsFixed(1),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.textColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (text) {
                  final parsed = double.tryParse(text);
                  if (parsed != null) {
                    onChanged(parsed);
                  }
                },
                controller: TextEditingController(
                  text: value.toStringAsFixed(1),
                )..selection = TextSelection.collapsed(
                  offset: value.toStringAsFixed(1).length,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${totalGrams.toStringAsFixed(0)}g',
                      style: widget.theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$calories kcal',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.textColor.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaloriesSummaryPerKg() {
    final weight = widget.provider.weight;
    final carbsGrams = _carbsPerKg * weight;
    final proteinGrams = _proteinPerKg * weight;
    final fatGrams = _fatPerKg * weight;

    final carbsCalories = carbsGrams * 4;
    final proteinCalories = proteinGrams * 4;
    final fatCalories = fatGrams * 9;
    final totalCalories = carbsCalories + proteinCalories + fatCalories;
    final targetCalories = widget.provider.caloriesGoal;
    final difference = (totalCalories - targetCalories).abs();
    final isClose = difference <= targetCalories * 0.01;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClose
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isClose ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total dos macros:',
                style: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: widget.textColor,
                ),
              ),
              Text(
                '${totalCalories.toStringAsFixed(0)} kcal',
                style: widget.theme.textTheme.bodyLarge?.copyWith(
                  color: isClose ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meta:',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '$targetCalories kcal',
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  color: widget.textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          if (!isClose) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diferença: ${difference.toStringAsFixed(0)} kcal',
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: _autoAdjustGramsPerKg,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Ajustar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
