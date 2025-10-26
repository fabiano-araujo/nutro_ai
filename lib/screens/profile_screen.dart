import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../services/auth_service.dart';
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

  // Personal Information
  double _height = 180.0;
  double _weight = 75.0;
  String _sex = 'Male';
  int _age = 30;
  String _activityLevel = 'Moderate';
  String _goal = 'Lose Weight';

  // Macro Targets
  bool _autoCalculateMacros = true;
  double _carbsPercentage = 40.0;
  double _proteinPercentage = 30.0;
  double _fatPercentage = 30.0;

  // Calories chart data
  String _selectedPeriod = '7 dias';
  final double _calorieGoal = 2000.0;
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

        // Personal Information
        _buildPersonalInformationSection(theme, colorScheme),
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
    // Calculate daily calories based on user data
    final dailyCalories = _calculateDailyCalories();

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
                radius: 50,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: user.photo != null ? NetworkImage(user.photo!) : null,
                child: user.photo == null
                    ? Icon(
                        Icons.person_outline,
                        size: 50,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              // Nome à direita
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getBMIColor().withValues(alpha: 0.12),
                            _getBMIColor().withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getBMIColor().withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _getBMIColor().withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite,
                              size: 11,
                              color: _getBMIColor(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'IMC ${_calculateBMI().toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _getBMIColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: _getBMIColor().withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getBMICategory(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _getBMIColor().withValues(alpha: 0.8),
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
                            _getGoalIcon(),
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
                        _getGoalText(),
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

  IconData _getGoalIcon() {
    switch (_goal) {
      case 'Lose Weight':
        return Icons.trending_down;
      case 'Gain Weight':
        return Icons.trending_up;
      case 'Maintain Weight':
        return Icons.trending_flat;
      default:
        return Icons.flag;
    }
  }

  String _getGoalText() {
    switch (_goal) {
      case 'Lose Weight':
        return 'Perder Peso';
      case 'Gain Weight':
        return 'Ganhar Peso';
      case 'Maintain Weight':
        return 'Manter Peso';
      default:
        return _goal;
    }
  }

  double _calculateDailyCalories() {
    // Fórmula de Harris-Benedict
    double bmr;
    if (_sex == 'Male') {
      bmr = 88.362 + (13.397 * _weight) + (4.799 * _height) - (5.677 * _age);
    } else {
      bmr = 447.593 + (9.247 * _weight) + (3.098 * _height) - (4.330 * _age);
    }

    // Multiplicador de atividade
    double activityMultiplier;
    switch (_activityLevel) {
      case 'Sedentary':
        activityMultiplier = 1.2;
        break;
      case 'Lightly Active':
        activityMultiplier = 1.375;
        break;
      case 'Moderately Active':
        activityMultiplier = 1.55;
        break;
      case 'Very Active':
        activityMultiplier = 1.725;
        break;
      case 'Extremely Active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.2;
    }

    double tdee = bmr * activityMultiplier;

    // Ajuste baseado no objetivo
    switch (_goal) {
      case 'Lose Weight':
        return tdee - 500; // Déficit de 500 calorias
      case 'Gain Weight':
        return tdee + 500; // Superávit de 500 calorias
      case 'Maintain Weight':
      default:
        return tdee;
    }
  }

  double _calculateBMI() {
    // IMC = peso (kg) / altura (m)²
    final heightInMeters = _height / 100;
    return _weight / (heightInMeters * heightInMeters);
  }

  String _getBMICategory() {
    final bmi = _calculateBMI();
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

  Color _getBMIColor() {
    final bmi = _calculateBMI();
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

  Widget _buildPersonalInformationSection(ThemeData theme, ColorScheme colorScheme) {
    return _buildSectionCard(
      theme: theme,
      colorScheme: colorScheme,
      title: 'Personal Information',
      children: [
        _buildNumberInputRow('Height', _height, 'cm', (value) {
          setState(() => _height = value);
        }),
        _buildNumberInputRow('Weight', _weight, 'kg', (value) {
          setState(() => _weight = value);
        }),
        _buildToggleRow('Sex', _sex, ['Male', 'Female'], (value) {
          setState(() => _sex = value);
        }),
        _buildNumberInputRow('Age', _age.toDouble(), 'years', (value) {
          setState(() => _age = value.toInt());
        }),
        _buildDropdownRow('Activity Level', _activityLevel, theme),
        _buildDropdownRow('Goal', _goal, theme),
      ],
    );
  }

  Widget _buildMacroTargetsSection(ThemeData theme, ColorScheme colorScheme) {
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
                'Daily Macro Targets',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _autoCalculateMacros,
                onChanged: (value) {
                  setState(() => _autoCalculateMacros = value);
                },
                activeThumbColor: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically calculated based on your goals, or set manually.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroColumn('${_carbsPercentage.toInt()}%', 'Carbs', theme),
              _buildMacroColumn('${_proteinPercentage.toInt()}%', 'Protein', theme),
              _buildMacroColumn('${_fatPercentage.toInt()}%', 'Fat', theme),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _carbsPercentage / 100,
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

  Widget _buildSectionCard({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String title,
    required List<Widget> children,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNumberInputRow(
    String label,
    double value,
    String unit,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: TextEditingController(text: value.toStringAsFixed(0)),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (text) {
                    final newValue = double.tryParse(text);
                    if (newValue != null) onChanged(newValue);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(unit, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String label,
    String selectedValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: options.map((option) {
                final isSelected = option == selectedValue;
                return GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      option,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Row(
            children: [
              Text(value, style: theme.textTheme.bodyLarge),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow(String label, String trailing, ThemeData theme) {
    return InkWell(
      onTap: () {
        // Handle navigation
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyLarge),
            Icon(
              trailing.isEmpty ? Icons.chevron_right : Icons.chevron_right,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ],
        ),
      ),
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
                  horizontalInterval: 500,
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
                      interval: 500,
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
                minY: 1000,
                maxY: 2500,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, _calorieGoal),
                      FlSpot((daysCount - 1).toDouble(), _calorieGoal),
                    ],
                    isCurved: false,
                    color: colorScheme.primary.withValues(alpha: 0.5),
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
              _buildLegendItem('Objetivo', colorScheme.primary.withValues(alpha: 0.5), theme, true),
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
