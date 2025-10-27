import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/auth_service.dart';
import '../providers/nutrition_goals_provider.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import '../i18n/app_localizations_extension.dart';

// Custom painter for dashed line in legend
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const dashWidth = 3.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ScrollController _scrollController;

  // Calories chart data
  String _selectedPeriod = '7 dias';
  final List<double> _dailyCalories7 = [1800, 2100, 1900, 2200, 1850, 2050, 1950];
  final List<double> _dailyCalories30 = List.generate(30, (index) => 1800 + (index % 5) * 100);
  final List<double> _dailyCalories90 = List.generate(90, (index) => 1800 + (index % 5) * 100);

  // Macronutrients chart data
  String _selectedMacroPeriod = '7 dias';
  final List<double> _dailyProtein7 = [80, 95, 75, 100, 85, 90, 88];
  final List<double> _dailyCarbs7 = [200, 220, 190, 240, 210, 225, 215];
  final List<double> _dailyFat7 = [60, 70, 55, 75, 65, 68, 62];
  final List<double> _dailyFiber7 = [25, 30, 22, 28, 26, 29, 27];
  final List<double> _dailyProtein30 = List.generate(30, (index) => 80 + (index % 4) * 5);
  final List<double> _dailyCarbs30 = List.generate(30, (index) => 200 + (index % 5) * 10);
  final List<double> _dailyFat30 = List.generate(30, (index) => 60 + (index % 4) * 5);
  final List<double> _dailyFiber30 = List.generate(30, (index) => 25 + (index % 3) * 2);
  final List<double> _dailyProtein90 = List.generate(90, (index) => 80 + (index % 4) * 5);
  final List<double> _dailyCarbs90 = List.generate(90, (index) => 200 + (index % 5) * 10);
  final List<double> _dailyFat90 = List.generate(90, (index) => 60 + (index % 4) * 5);
  final List<double> _dailyFiber90 = List.generate(90, (index) => 25 + (index % 3) * 2);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildAuthenticatedContent() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Header
        _buildProfileHeader(user, theme, colorScheme),
        const SizedBox(height: 24),

        // Calories Chart Card
        _buildCaloriesChartCard(theme, colorScheme),
        const SizedBox(height: 24),

        // Macronutrients Chart Card
        _buildMacronutrientsChartCard(theme, colorScheme),
        const SizedBox(height: 24),

        // Daily Macro Targets
        _buildMacroTargetsSection(theme, colorScheme),
        const SizedBox(height: 32),

        // Logout Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await authService.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout),
            label: Text(context.tr.translate('sign_out')),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.red,
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildProfileHeader(user, ThemeData theme, ColorScheme colorScheme) {
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context, listen: false);
    // Calculate daily calories and BMI based on user data
    final dailyCalories = nutritionProvider.caloriesGoal.toDouble();
    final bmi = _calculateBMI(nutritionProvider.weight, nutritionProvider.height);
    final bmiColor = _getBMIColor(bmi);
    final bmiCategory = _getBMICategory(bmi);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar à esquerda
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: user.photo != null ? NetworkImage(user.photo!) : null,
                child: user.photo == null
                    ? Icon(
                        Icons.person_outline,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Nome à direita
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Ícone de editar na mesma linha
                        InkWell(
                          onTap: () {
                            // TODO: Navegar para tela de edição de perfil
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Editar perfil - Em breve!')),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            bmiColor.withValues(alpha: 0.12),
                            bmiColor.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: bmiColor.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: bmiColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite,
                              size: 11,
                              color: bmiColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'IMC ${bmi.toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: bmiColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: bmiColor.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            bmiCategory,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: bmiColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Divisor
          Divider(
            color: theme.colorScheme.surfaceContainerHighest,
            thickness: 1,
          ),
          const SizedBox(height: 16),
          // Objetivo e Calorias
          Row(
            children: [
              // Objetivo
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getGoalIcon(nutritionProvider.fitnessGoal),
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Objetivo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getGoalText(nutritionProvider.fitnessGoal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Calorias Diárias
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 20,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Meta Diária',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${dailyCalories.toStringAsFixed(0)} kcal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getGoalIcon(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return Icons.trending_down;
      case FitnessGoal.gainWeight:
      case FitnessGoal.gainMuscle:
        return Icons.trending_up;
      case FitnessGoal.maintainWeight:
        return Icons.trending_flat;
    }
  }

  String _getGoalText(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return 'Perder Peso';
      case FitnessGoal.gainWeight:
        return 'Ganhar Peso';
      case FitnessGoal.gainMuscle:
        return 'Ganhar Massa';
      case FitnessGoal.maintainWeight:
        return 'Manter Peso';
    }
  }

  double _calculateBMI(double weight, double height) {
    // IMC = peso (kg) / altura (m)²
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) {
      return 'Abaixo do peso';
    } else if (bmi < 25) {
      return 'Peso normal';
    } else if (bmi < 30) {
      return 'Sobrepeso';
    } else {
      return 'Obesidade';
    }
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) {
      return const Color(0xFF64B5F6); // Azul suave - Abaixo do peso
    } else if (bmi < 25) {
      return const Color(0xFF66BB6A); // Verde suave - Peso normal
    } else if (bmi < 30) {
      return const Color(0xFFFFB74D); // Laranja suave - Sobrepeso
    } else {
      return const Color(0xFFEF5350); // Vermelho suave - Obesidade
    }
  }

  Widget _buildMacroTargetsSection(ThemeData theme, ColorScheme colorScheme) {
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Metas Diárias de Macros',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: nutritionProvider.useCalculatedGoals,
                onChanged: (value) {
                  nutritionProvider.setUseCalculatedGoals(value);
                },
                activeThumbColor: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Calculado automaticamente com base em seus objetivos, ou definir manualmente.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroColumn('${nutritionProvider.carbsPercentage}%', 'Carboidratos', theme),
              _buildMacroColumn('${nutritionProvider.proteinPercentage}%', 'Proteínas', theme),
              _buildMacroColumn('${nutritionProvider.fatPercentage}%', 'Gorduras', theme),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: nutritionProvider.carbsPercentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroColumn(String percentage, String label, ThemeData theme) {
    return Column(
      children: [
        Text(
          percentage,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildUnauthenticatedContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 100,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr.translate('login_to_access_profile'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr.translate('login_description'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToLogin,
                icon: const Icon(Icons.login),
                label: Text(context.tr.translate('sign_in')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesChartCard(ThemeData theme, ColorScheme colorScheme) {
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final calorieGoal = nutritionProvider.caloriesGoal.toDouble();

    List<double> currentData;
    int daysCount;

    switch (_selectedPeriod) {
      case '30 dias':
        currentData = _dailyCalories30;
        daysCount = 30;
        break;
      case '90 dias':
        currentData = _dailyCalories90;
        daysCount = 90;
        break;
      default:
        currentData = _dailyCalories7;
        daysCount = 7;
    }

    // Calcular min e max dinamicamente
    final maxDataValue = currentData.reduce((a, b) => a > b ? a : b);
    final minDataValue = currentData.reduce((a, b) => a < b ? a : b);

    // Incluir a meta no cálculo do range
    final maxValue = [maxDataValue, calorieGoal].reduce((a, b) => a > b ? a : b);
    final minValue = [minDataValue, calorieGoal].reduce((a, b) => a < b ? a : b);

    // Adicionar margem de 10% acima e abaixo
    final range = maxValue - minValue;
    final chartMaxY = (maxValue + range * 0.15).ceilToDouble();
    final chartMinY = (minValue - range * 0.15).floorToDouble();

    // Calcular intervalo apropriado para as linhas de grade
    final totalRange = chartMaxY - chartMinY;
    final interval = (totalRange / 5).ceilToDouble();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calorias consumidas diariamente',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPeriodChip('7 dias', theme, colorScheme),
              const SizedBox(width: 8),
              _buildPeriodChip('30 dias', theme, colorScheme),
              const SizedBox(width: 8),
              _buildPeriodChip('90 dias', theme, colorScheme),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.surfaceContainerHighest,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: daysCount > 30 ? 15 : (daysCount > 7 ? 5 : 1),
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < daysCount) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${value.toInt() + 1}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest, width: 1),
                    left: BorderSide(color: theme.colorScheme.surfaceContainerHighest, width: 1),
                  ),
                ),
                minX: 0,
                maxX: (daysCount - 1).toDouble(),
                minY: chartMinY,
                maxY: chartMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, calorieGoal),
                      FlSpot((daysCount - 1).toDouble(), calorieGoal),
                    ],
                    isCurved: false,
                    color: Colors.orange,
                    barWidth: 2,
                    isStrokeCapRound: false,
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  LineChartBarData(
                    spots: currentData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: theme.cardColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        if (spot.barIndex == 1) {
                          return LineTooltipItem(
                            '${spot.y.toInt()} kcal',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Consumido', colorScheme.primary, theme, false),
              const SizedBox(width: 24),
              _buildLegendItem('Meta Diária', Colors.orange, theme, true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, ThemeData theme, ColorScheme colorScheme) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = period);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          period,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, ThemeData theme, bool isDashed) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed ? CustomPaint(painter: DashedLinePainter(color: color)) : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMacronutrientsChartCard(ThemeData theme, ColorScheme colorScheme) {
    List<double> proteinData, carbsData, fatData, fiberData;

    switch (_selectedMacroPeriod) {
      case '30 dias':
        proteinData = _dailyProtein30;
        carbsData = _dailyCarbs30;
        fatData = _dailyFat30;
        fiberData = _dailyFiber30;
        break;
      case '90 dias':
        proteinData = _dailyProtein90;
        carbsData = _dailyCarbs90;
        fatData = _dailyFat90;
        fiberData = _dailyFiber90;
        break;
      default:
        proteinData = _dailyProtein7;
        carbsData = _dailyCarbs7;
        fatData = _dailyFat7;
        fiberData = _dailyFiber7;
    }

    // Calculate averages
    final avgProtein = proteinData.reduce((a, b) => a + b) / proteinData.length;
    final avgCarbs = carbsData.reduce((a, b) => a + b) / carbsData.length;
    final avgFat = fatData.reduce((a, b) => a + b) / fatData.length;
    final avgFiber = fiberData.reduce((a, b) => a + b) / fiberData.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Média de macronutrientes diários',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMacroPeriodChip('7 dias', theme, colorScheme),
              const SizedBox(width: 8),
              _buildMacroPeriodChip('30 dias', theme, colorScheme),
              const SizedBox(width: 8),
              _buildMacroPeriodChip('90 dias', theme, colorScheme),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 250,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label = '';
                      switch (groupIndex) {
                        case 0:
                          label = 'Proteína';
                          break;
                        case 1:
                          label = 'Carboidrato';
                          break;
                        case 2:
                          label = 'Gordura';
                          break;
                        case 3:
                          label = 'Fibra';
                          break;
                      }
                      return BarTooltipItem(
                        '$label\n${rod.toY.toStringAsFixed(1)}g',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        String text = '';
                        Color color = Colors.black;
                        switch (value.toInt()) {
                          case 0:
                            text = 'Proteína';
                            color = const Color(0xFF9575CD); // Purple
                            break;
                          case 1:
                            text = 'Carboidrato';
                            color = const Color(0xFFA1887F); // Brown
                            break;
                          case 2:
                            text = 'Gordura';
                            color = const Color(0xFF90A4AE); // Blue-grey
                            break;
                          case 3:
                            text = 'Fibra';
                            color = Colors.green;
                            break;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            text,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}g',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.surfaceContainerHighest,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest, width: 1),
                    left: BorderSide(color: theme.colorScheme.surfaceContainerHighest, width: 1),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: avgProtein,
                        color: const Color(0xFF9575CD), // Purple - matches nutrition_card.dart
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 250,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: avgCarbs,
                        color: const Color(0xFFA1887F), // Brown - matches nutrition_card.dart
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 250,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: avgFat,
                        color: const Color(0xFF90A4AE), // Blue-grey - matches nutrition_card.dart
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 250,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: avgFiber,
                        color: Colors.green,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 250,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildMacroLegendItem('Proteína: ${avgProtein.toStringAsFixed(1)}g', const Color(0xFF9575CD), theme),
              _buildMacroLegendItem('Carboidrato: ${avgCarbs.toStringAsFixed(1)}g', const Color(0xFFA1887F), theme),
              _buildMacroLegendItem('Gordura: ${avgFat.toStringAsFixed(1)}g', const Color(0xFF90A4AE), theme),
              _buildMacroLegendItem('Fibra: ${avgFiber.toStringAsFixed(1)}g', Colors.green, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPeriodChip(String period, ThemeData theme, ColorScheme colorScheme) {
    final isSelected = _selectedMacroPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMacroPeriod = period);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          period,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMacroLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile & Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          if (authService.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: authService.isAuthenticated
          ? _buildAuthenticatedContent()
          : _buildUnauthenticatedContent(),
    );
  }
}
