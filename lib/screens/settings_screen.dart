import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../i18n/app_localizations.dart';
import '../i18n/language_controller.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/rate_app_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/nutrition_goals_provider.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final int? initialTab;

  const SettingsScreen({Key? key, this.initialTab}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  String _selectedLanguage = 'en';
  ThemeMode _themeMode = ThemeMode.light;
  bool _useMetric = true;
  bool _mealReminders = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final languageController = Provider.of<LanguageController>(context, listen: false);
      String currentLanguage = languageController.localeToString(languageController.currentLocale);

      setState(() {
        _selectedLanguage = currentLanguage.isNotEmpty ? currentLanguage : 'en';
        _themeMode = themeProvider.themeMode;
      });
    } catch (e) {
      print('Erro ao carregar configurações: $e');
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> _saveSettings() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setThemeMode(_themeMode);
    await _storageService.saveSettings({
      'theme': _themeModeToString(_themeMode),
    });

    final languageController = Provider.of<LanguageController>(context, listen: false);
    await languageController.setLocale(languageController.localeFromString(_selectedLanguage));
  }

  Future<void> _shareApp() async {
    String appId;
    if (kIsWeb) {
      appId = 'br.com.snapdark.apps.studyai';
    } else {
      final packageInfo = await PackageInfo.fromPlatform();
      appId = packageInfo.packageName;
    }
    final playStoreUrl = 'https://play.google.com/store/apps/details?id=$appId';
    String shareMessage = context.tr.translate('share_app_message').replaceAll('{url}', playStoreUrl);
    await Share.share(shareMessage);
  }

  // Edit dialogs
  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Nome'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Update user name on server
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showEditAgeDialog(int currentAge) {
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final controller = TextEditingController(text: currentAge.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Idade'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Idade',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newAge = int.tryParse(controller.text);
              if (newAge != null && newAge > 0 && newAge < 150) {
                nutritionProvider.updatePersonalInfo(age: newAge);
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showEditGenderDialog(String currentGender) {
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Gênero'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.male),
              title: const Text('Masculino'),
              trailing: currentGender == 'male' ? const Icon(Icons.check) : null,
              onTap: () {
                nutritionProvider.updatePersonalInfo(sex: 'male');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.female),
              title: const Text('Feminino'),
              trailing: currentGender == 'female' ? const Icon(Icons.check) : null,
              onTap: () {
                nutritionProvider.updatePersonalInfo(sex: 'female');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHeightDialog(double currentHeight, bool useMetric) {
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final controller = TextEditingController(
      text: useMetric ? currentHeight.toString() : (currentHeight / 2.54).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Altura'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: useMetric ? 'Altura (cm)' : 'Altura (pol)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newHeight = double.tryParse(controller.text);
              if (newHeight != null && newHeight > 0) {
                final heightInCm = useMetric ? newHeight : newHeight * 2.54;
                nutritionProvider.updatePersonalInfo(height: heightInCm);
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showEditWeightDialog(double currentWeight, bool useMetric) {
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context, listen: false);
    final controller = TextEditingController(
      text: useMetric ? currentWeight.toString() : (currentWeight * 2.20462).toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Peso'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: useMetric ? 'Peso (kg)' : 'Peso (lb)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newWeight = double.tryParse(controller.text);
              if (newWeight != null && newWeight > 0) {
                final weightInKg = useMetric ? newWeight : newWeight / 2.20462;
                nutritionProvider.updatePersonalInfo(weight: weightInKg);
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog(ThemeData theme, NutritionGoalsProvider provider) {
    final goals = FitnessGoal.values;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Objetivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: goals.map((goal) {
            final isSelected = goal == provider.fitnessGoal;
            return ListTile(
              leading: Icon(
                _getGoalIcon(goal),
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(provider.getFitnessGoalName(goal)),
              trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                provider.updateActivityAndGoals(fitnessGoal: goal);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getGoalIcon(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
      case FitnessGoal.loseWeightSlowly:
        return Icons.trending_down;
      case FitnessGoal.gainWeight:
      case FitnessGoal.gainWeightSlowly:
        return Icons.trending_up;
      case FitnessGoal.maintainWeight:
        return Icons.trending_flat;
    }
  }

  void _showEditActivityLevelDialog(ThemeData theme, NutritionGoalsProvider provider) {
    final levels = ActivityLevel.values;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Nível de Atividade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: levels.map((level) {
            final isSelected = level == provider.activityLevel;
            return ListTile(
              leading: Icon(
                Icons.directions_run,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(provider.getActivityLevelName(level)),
              subtitle: Text(
                provider.getActivityLevelDescription(level),
                style: theme.textTheme.bodySmall,
              ),
              trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                provider.updateActivityAndGoals(activityLevel: level);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEditDietTypeDialog(ThemeData theme, NutritionGoalsProvider provider) {
    final dietTypes = DietType.values;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Tipo de Dieta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: dietTypes.map((dietType) {
              final isSelected = dietType == provider.dietType;
              return ListTile(
                leading: Icon(
                  Icons.restaurant_menu,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                title: Text(provider.getDietTypeName(dietType)),
                subtitle: Text(
                  provider.getDietTypeDescription(dietType),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                onTap: () {
                  provider.updateDietType(dietType);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authService = Provider.of<AuthService>(context);
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr.translate('settings_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section (Conta)
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: 'Conta',
            children: [
              _buildAccountRow(
                'Nome',
                authService.isAuthenticated ? authService.currentUser?.name ?? 'Usuário' : 'Não logado',
                Icons.person_outline,
                theme,
                onTap: () {
                  if (authService.isAuthenticated) {
                    _showEditNameDialog(authService.currentUser?.name ?? '');
                  }
                },
              ),
              _buildAccountRow(
                'Idade',
                '${nutritionProvider.age} anos',
                Icons.cake_outlined,
                theme,
                onTap: () => _showEditAgeDialog(nutritionProvider.age),
              ),
              _buildAccountRow(
                'Gênero',
                nutritionProvider.sex == 'male' ? 'Masculino' : 'Feminino',
                Icons.wc_outlined,
                theme,
                onTap: () => _showEditGenderDialog(nutritionProvider.sex),
              ),
              _buildAccountRow(
                'Altura',
                _useMetric
                    ? '${nutritionProvider.height.toStringAsFixed(0)} cm'
                    : '${(nutritionProvider.height / 2.54).toStringAsFixed(0)} pol',
                Icons.height,
                theme,
                onTap: () => _showEditHeightDialog(nutritionProvider.height, _useMetric),
              ),
              _buildAccountRow(
                'Peso',
                _useMetric
                    ? '${nutritionProvider.weight.toStringAsFixed(1)} kg'
                    : '${(nutritionProvider.weight * 2.20462).toStringAsFixed(1)} lb',
                Icons.monitor_weight_outlined,
                theme,
                onTap: () => _showEditWeightDialog(nutritionProvider.weight, _useMetric),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Diet Section (Dieta)
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: 'Dieta',
            children: [
              _buildAccountRow(
                'Objetivo',
                nutritionProvider.getFitnessGoalName(nutritionProvider.fitnessGoal),
                Icons.track_changes,
                theme,
                onTap: () => _showEditGoalDialog(theme, nutritionProvider),
              ),
              _buildAccountRow(
                'Nível de Atividade',
                nutritionProvider.getActivityLevelName(nutritionProvider.activityLevel),
                Icons.directions_run,
                theme,
                onTap: () => _showEditActivityLevelDialog(theme, nutritionProvider),
              ),
              _buildAccountRow(
                'Dieta',
                nutritionProvider.getDietTypeName(nutritionProvider.dietType),
                Icons.restaurant_menu,
                theme,
                onTap: () => _showEditDietTypeDialog(theme, nutritionProvider),
              ),
              _buildFormulaRow(theme),
              // Show body fat percentage only when Katch-McArdle is selected
              if (nutritionProvider.formula == CalculationFormula.katchMcArdle)
                _buildAccountRow(
                  'Percentual de Gordura',
                  nutritionProvider.bodyFat != null
                      ? '${nutritionProvider.bodyFat!.toStringAsFixed(1)}%'
                      : 'Não informado',
                  Icons.fitness_center,
                  theme,
                  onTap: () => _showBodyFatDialog(theme, nutritionProvider),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: context.tr.translate('theme'),
            children: [
              _buildThemeRow(theme, colorScheme),
            ],
          ),
          const SizedBox(height: 24),

          // Preferences Section
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: 'Preferences',
            children: [
              _buildUnitsRow(theme, colorScheme),
              _buildLanguageRow(theme),
            ],
          ),
          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: 'Notifications',
            children: [
              _buildNotificationRow(theme, colorScheme),
            ],
          ),
          const SizedBox(height: 24),

          // About Section
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: context.tr.translate('about'),
            children: [
              _buildNavigationRow(
                context.tr.translate('app_version'),
                '1.0.0',
                Icons.info_outline,
                theme,
                onTap: null,
              ),
              _buildNavigationRow(
                context.tr.translate('privacy_policy'),
                '',
                Icons.privacy_tip_outlined,
                theme,
                onTap: () {
                  // Open privacy policy
                },
              ),
              _buildNavigationRow(
                context.tr.translate('rate_app'),
                '',
                Icons.star_outline,
                theme,
                onTap: () {
                  RateAppBottomSheet.show(context);
                },
              ),
              _buildNavigationRow(
                context.tr.translate('share_app'),
                '',
                Icons.share_outlined,
                theme,
                onTap: () async {
                  await _shareApp();
                },
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
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

  Widget _buildThemeRow(ThemeData theme, ColorScheme colorScheme) {
    final themeOptions = {
      ThemeMode.light: context.tr.translate('light_theme'),
      ThemeMode.dark: context.tr.translate('dark_theme'),
      ThemeMode.system: context.tr.translate('system_theme'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.tr.translate('theme'),
            style: theme.textTheme.bodyLarge,
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: themeOptions.entries.map((entry) {
                final isSelected = entry.key == _themeMode;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _themeMode = entry.key;
                    });
                    _saveSettings();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getThemeShortName(entry.key),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  String _getThemeShortName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Auto';
    }
  }

  Widget _buildUnitsRow(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Units', style: theme.textTheme.bodyLarge),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['Metric', 'Imperial'].map((unit) {
                final isSelected = (unit == 'Metric' && _useMetric) || (unit == 'Imperial' && !_useMetric);
                return GestureDetector(
                  onTap: () {
                    setState(() => _useMetric = unit == 'Metric');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      unit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildLanguageRow(ThemeData theme) {
    List<Map<String, String>> availableLanguages = AppLocalizations.getAvailableLanguages();

    // Find current language name
    String currentLanguageName = availableLanguages
        .firstWhere(
          (lang) => lang['code'] == _selectedLanguage,
          orElse: () => {'name': 'English', 'code': 'en'},
        )['name']!;

    return InkWell(
      onTap: () {
        _showLanguageDialog(theme, availableLanguages);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr.translate('language'),
              style: theme.textTheme.bodyLarge,
            ),
            Row(
              children: [
                Text(
                  currentLanguageName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulaRow(ThemeData theme) {
    return Consumer<NutritionGoalsProvider>(
      builder: (context, provider, child) {
        return _buildAccountRow(
          'Fórmula de Cálculo',
          provider.getFormulaName(provider.formula),
          Icons.calculate,
          theme,
          onTap: () => _showFormulaDialog(theme, provider),
        );
      },
    );
  }

  void _showFormulaDialog(ThemeData theme, NutritionGoalsProvider provider) {
    final formulas = CalculationFormula.values;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fórmula de Cálculo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: formulas.map((formula) {
            final isSelected = formula == provider.formula;
            return ListTile(
              leading: Icon(
                Icons.calculate,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(provider.getFormulaName(formula)),
              subtitle: Text(
                _getFormulaDescription(formula),
                style: theme.textTheme.bodySmall,
              ),
              trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                provider.updateActivityAndGoals(formula: formula);
                Navigator.pop(context);

                // If Katch-McArdle is selected, show body fat input dialog
                if (formula == CalculationFormula.katchMcArdle) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _showBodyFatDialog(theme, provider);
                  });
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getFormulaDescription(CalculationFormula formula) {
    switch (formula) {
      case CalculationFormula.mifflinStJeor:
        return 'Mais precisa para a maioria das pessoas';
      case CalculationFormula.harrisBenedict:
        return 'Fórmula tradicional e bem estabelecida';
      case CalculationFormula.katchMcArdle:
        return 'Requer percentual de gordura corporal';
    }
  }

  void _showBodyFatDialog(ThemeData theme, NutritionGoalsProvider provider) {
    final controller = TextEditingController(
      text: provider.bodyFat?.toStringAsFixed(1) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Percentual de Gordura Corporal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A fórmula Katch-McArdle requer o percentual de gordura corporal para um cálculo mais preciso.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Percentual de Gordura (%)',
                hintText: 'Ex: 20',
                border: const OutlineInputBorder(),
                suffixText: '%',
                helperText: 'Entre 5% e 50%',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final bodyFat = double.tryParse(controller.text);
              if (bodyFat != null && bodyFat >= 5 && bodyFat <= 50) {
                provider.updatePersonalInfo(bodyFat: bodyFat);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, insira um valor entre 5 e 50'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRow(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meal Reminders',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Get notified for your meals.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _mealReminders,
            onChanged: (value) {
              setState(() => _mealReminders = value);
            },
            activeThumbColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(ThemeData theme, List<Map<String, String>> availableLanguages) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.translate('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableLanguages.map((lang) {
            final isSelected = lang['code'] == _selectedLanguage;
            return ListTile(
              leading: Icon(
                Icons.translate,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(lang['name']!),
              trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                setState(() {
                  _selectedLanguage = lang['code']!;
                });
                _saveSettings();
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavigationRow(
    String label,
    String trailing,
    IconData icon,
    ThemeData theme, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (trailing.isNotEmpty)
              Text(
                trailing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            if (trailing.isEmpty)
              Icon(
                Icons.chevron_right,
                color: theme.textTheme.bodyLarge?.color,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(
    String label,
    String value,
    IconData icon,
    ThemeData theme, {
    required VoidCallback onTap,
    bool isAction = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isAction
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  fontWeight: isAction ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
