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
                // Header explanation
                Text(
                  'Configure suas metas nutricionais diárias',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Escolha entre calcular automaticamente baseado em suas informações ou definir manualmente.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle: Calculated vs Manual
                _buildCalculationModeCard(provider, theme, isDarkMode, textColor),

                const SizedBox(height: 24),

                // Current Goals Summary
                _buildGoalsSummaryCard(provider, theme, isDarkMode, textColor),

                const SizedBox(height: 24),

                // Configuration section based on mode
                if (provider.useCalculatedGoals) ...[
                  _buildCalculatedConfigSection(provider, theme, isDarkMode, textColor),
                ] else ...[
                  _buildManualConfigSection(provider, theme, isDarkMode, textColor),
                ],

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalculationModeCard(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo de Cálculo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.useCalculatedGoals ? 'Calculado automaticamente' : 'Manual',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Switch(
                value: provider.useCalculatedGoals,
                onChanged: (value) {
                  provider.setUseCalculatedGoals(value);
                },
                activeTrackColor: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            provider.useCalculatedGoals
                ? 'Suas metas são calculadas com base em suas informações pessoais, nível de atividade e objetivos.'
                : 'Você está definindo suas metas manualmente. Você pode alternar para o modo calculado a qualquer momento.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
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
          Text(
            'Suas Metas Diárias',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
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

        // Activity & Goal Card
        _buildInfoCard(
          cardColor: cardColor,
          isDarkMode: isDarkMode,
          title: 'Atividade e Objetivo',
          subtitle: provider.getActivityLevelName(provider.activityLevel),
          details: provider.getFitnessGoalName(provider.fitnessGoal),
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

        // Diet Type Card
        _buildInfoCard(
          cardColor: cardColor,
          isDarkMode: isDarkMode,
          title: 'Tipo de Dieta',
          subtitle: provider.getDietTypeName(provider.dietType),
          details: '${provider.carbsPercentage}% C, ${provider.proteinPercentage}% P, ${provider.fatPercentage}% G',
          icon: Icons.restaurant_menu,
          iconColor: Colors.orange,
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
        const SizedBox(height: 12),

        // Formula Card
        _buildInfoCard(
          cardColor: cardColor,
          isDarkMode: isDarkMode,
          title: 'Fórmula de Cálculo',
          subtitle: provider.getFormulaName(provider.formula),
          details: 'Método de cálculo de calorias',
          icon: Icons.calculate,
          iconColor: Colors.purple,
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

  Widget _buildManualConfigSection(
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
          Text(
            'Configuração Manual',
            style: theme.textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Calories
          _buildInputField(
            controller: caloriesController,
            label: 'Calorias (kcal)',
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            theme: theme,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),

          // Protein
          _buildInputField(
            controller: proteinController,
            label: 'Proteína (g)',
            icon: Icons.fitness_center,
            iconColor: const Color(0xFF9575CD),
            theme: theme,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),

          // Carbs
          _buildInputField(
            controller: carbsController,
            label: 'Carboidratos (g)',
            icon: Icons.grain,
            iconColor: const Color(0xFFA1887F),
            theme: theme,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),

          // Fat
          _buildInputField(
            controller: fatController,
            label: 'Gorduras (g)',
            icon: Icons.water_drop,
            iconColor: const Color(0xFF90A4AE),
            theme: theme,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
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

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Metas salvas com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Salvar Metas'),
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
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required ThemeData theme,
    required Color textColor,
    required bool isDarkMode,
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
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
