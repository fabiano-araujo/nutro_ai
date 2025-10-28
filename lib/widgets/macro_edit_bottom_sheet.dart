import 'package:flutter/material.dart';
import '../providers/nutrition_goals_provider.dart';
import '../theme/app_theme.dart';

class MacroEditBottomSheet extends StatefulWidget {
  final NutritionGoalsProvider provider;
  final ThemeData theme;
  final bool isDarkMode;
  final Color textColor;
  final Color cardColor;

  const MacroEditBottomSheet({
    Key? key,
    required this.provider,
    required this.theme,
    required this.isDarkMode,
    required this.textColor,
    required this.cardColor,
  }) : super(key: key);

  @override
  State<MacroEditBottomSheet> createState() => _MacroEditBottomSheetState();
}

class _MacroEditBottomSheetState extends State<MacroEditBottomSheet> {
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

  @override
  Widget build(BuildContext context) {
    final totalPercentage = _carbsPercentage + _proteinPercentage + _fatPercentage;
    final isValid = (totalPercentage - 100).abs() < 0.1;

    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Editar Macronutrientes',
                      style: widget.theme.textTheme.titleLarge?.copyWith(
                        color: widget.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: widget.textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(
                color: widget.textColor.withValues(alpha: 0.1),
                height: 1,
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
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
                      const SizedBox(height: 24),

                      if (_selectedMode == 0) ..._buildPercentageMode(isValid, totalPercentage),
                      if (_selectedMode == 1) ..._buildGramsMode(),
                      if (_selectedMode == 2) ..._buildGramsPerKgMode(),

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
              ),

              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: widget.cardColor,
                  border: Border(
                    top: BorderSide(
                      color: widget.textColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: widget.textColor.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: widget.textColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _validateAndUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Salvar Alterações',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPercentageMode(bool isValid, double totalPercentage) {
    return [
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
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isValid
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _autoAdjust,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ajustar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
    ];
  }

  List<Widget> _buildGramsMode() {
    return [
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
      _buildCaloriesSummary(),
    ];
  }

  List<Widget> _buildGramsPerKgMode() {
    return [
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
      _buildCaloriesSummaryPerKg(),
    ];
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
