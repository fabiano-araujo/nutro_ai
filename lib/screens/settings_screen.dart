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
        title: Text(context.tr.translate('edit_name')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.tr.translate('name'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              // TODO: Update user name on server
              Navigator.pop(context);
            },
            child: Text(context.tr.translate('save')),
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
        title: Text(context.tr.translate('edit_age')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.tr.translate('age'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              final newAge = int.tryParse(controller.text);
              if (newAge != null && newAge > 0 && newAge < 150) {
                nutritionProvider.updatePersonalInfo(age: newAge);
                Navigator.pop(context);
              }
            },
            child: Text(context.tr.translate('save')),
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
        title: Text(context.tr.translate('edit_gender')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.male),
              title: Text(context.tr.translate('male')),
              trailing: currentGender == 'male' ? const Icon(Icons.check) : null,
              onTap: () {
                nutritionProvider.updatePersonalInfo(sex: 'male');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.female),
              title: Text(context.tr.translate('female')),
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

  void _showEditHeightDialog(NutritionGoalsProvider provider) {
    late final TextEditingController feetController;
    late final TextEditingController inchesController;
    late final TextEditingController cmController;

    if (provider.heightUnit == HeightUnit.cm) {
      cmController = TextEditingController(text: provider.height.toStringAsFixed(0));
    } else {
      final heightData = provider.heightInFeet();
      feetController = TextEditingController(text: heightData['feet'].toString());
      inchesController = TextEditingController(text: heightData['inches'].toString());
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr.translate('edit_height')),
            TextButton(
              onPressed: () {
                provider.toggleHeightUnit();
                Navigator.pop(context);
                _showEditHeightDialog(provider);
              },
              child: Text(
                provider.heightUnit == HeightUnit.cm ? 'cm' : 'ft',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
        content: provider.heightUnit == HeightUnit.cm
            ? TextField(
                controller: cmController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr.translate('height_cm'),
                  border: const OutlineInputBorder(),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: feetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr.translate('feet'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: inchesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr.translate('inches'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              double heightInCm;
              if (provider.heightUnit == HeightUnit.cm) {
                heightInCm = double.tryParse(cmController.text) ?? provider.height;
              } else {
                final feet = int.tryParse(feetController.text) ?? 0;
                final inches = int.tryParse(inchesController.text) ?? 0;
                heightInCm = NutritionGoalsProvider.heightToCm(feet, inches);
              }

              if (heightInCm >= 50 && heightInCm <= 300) {
                provider.updatePersonalInfo(height: heightInCm);
                Navigator.pop(context);
              }
            },
            child: Text(context.tr.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showEditWeightDialog(NutritionGoalsProvider provider) {
    late final TextEditingController kgController;
    late final TextEditingController lbsController;
    late final TextEditingController stoneController;
    late final TextEditingController poundsController;

    switch (provider.weightUnit) {
      case WeightUnit.kg:
        kgController = TextEditingController(text: provider.weight.toStringAsFixed(1));
        break;
      case WeightUnit.lbs:
        lbsController = TextEditingController(text: provider.weightInLbs().toStringAsFixed(1));
        break;
      case WeightUnit.stLbs:
        final weightData = provider.weightInStLbs();
        stoneController = TextEditingController(text: weightData['stone'].toString());
        poundsController = TextEditingController(text: weightData['pounds'].toString());
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr.translate('edit_weight')),
            TextButton(
              onPressed: () {
                provider.toggleWeightUnit();
                Navigator.pop(context);
                _showEditWeightDialog(provider);
              },
              child: Text(
                provider.weightUnit == WeightUnit.kg
                    ? 'kg'
                    : provider.weightUnit == WeightUnit.lbs
                        ? 'lbs'
                        : 'st',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
        content: provider.weightUnit == WeightUnit.kg
            ? TextField(
                controller: kgController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.tr.translate('weight_kg'),
                  border: const OutlineInputBorder(),
                ),
              )
            : provider.weightUnit == WeightUnit.lbs
                ? TextField(
                    controller: lbsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr.translate('weight_lbs'),
                      border: const OutlineInputBorder(),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stoneController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.tr.translate('stone'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: poundsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.tr.translate('pounds'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              double weightInKg;
              switch (provider.weightUnit) {
                case WeightUnit.kg:
                  weightInKg = double.tryParse(kgController.text) ?? provider.weight;
                  break;
                case WeightUnit.lbs:
                  final lbs = double.tryParse(lbsController.text) ?? provider.weightInLbs();
                  weightInKg = NutritionGoalsProvider.weightToKg(lbs);
                  break;
                case WeightUnit.stLbs:
                  final stone = int.tryParse(stoneController.text) ?? 0;
                  final pounds = int.tryParse(poundsController.text) ?? 0;
                  weightInKg = NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
                  break;
              }

              if (weightInKg >= 20 && weightInKg <= 300) {
                provider.updatePersonalInfo(weight: weightInKg);
                Navigator.pop(context);
              }
            },
            child: Text(context.tr.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog(ThemeData theme, NutritionGoalsProvider provider) {
    final goals = FitnessGoal.values;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr.translate('edit_goal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: goals.map((goal) {
            final isSelected = goal == provider.fitnessGoal;
            return ListTile(
              leading: Icon(
                _getGoalIcon(goal),
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(provider.getFitnessGoalName(goal, dialogContext)),
              trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                provider.updateActivityAndGoals(fitnessGoal: goal);
                Navigator.pop(dialogContext);
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
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr.translate('edit_activity_level')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: levels.map((level) {
            final isSelected = level == provider.activityLevel;
            return ListTile(
              leading: Icon(
                Icons.directions_run,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(provider.getActivityLevelName(level, dialogContext)),
              subtitle: Text(
                provider.getActivityLevelDescription(level, dialogContext),
                style: theme.textTheme.bodySmall,
              ),
              trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                provider.updateActivityAndGoals(activityLevel: level);
                Navigator.pop(dialogContext);
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
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr.translate('edit_diet_type')),
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
                title: Text(provider.getDietTypeName(dietType, dialogContext)),
                subtitle: Text(
                  provider.getDietTypeDescription(dietType, dialogContext),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                onTap: () {
                  provider.updateDietType(dietType);
                  Navigator.pop(dialogContext);
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
            title: context.tr.translate('account'),
            children: [
              _buildAccountRow(
                context.tr.translate('name'),
                authService.isAuthenticated ? authService.currentUser?.name ?? context.tr.translate('user') : context.tr.translate('not_logged_in'),
                Icons.person_outline,
                theme,
                onTap: () {
                  if (authService.isAuthenticated) {
                    _showEditNameDialog(authService.currentUser?.name ?? '');
                  }
                },
              ),
              _buildAccountRow(
                context.tr.translate('age'),
                '${nutritionProvider.age}${context.tr.translate('years_suffix')}',
                Icons.cake_outlined,
                theme,
                onTap: () => _showEditAgeDialog(nutritionProvider.age),
              ),
              _buildAccountRow(
                context.tr.translate('gender'),
                nutritionProvider.sex == 'male' ? context.tr.translate('male') : context.tr.translate('female'),
                Icons.wc_outlined,
                theme,
                onTap: () => _showEditGenderDialog(nutritionProvider.sex),
              ),
              _buildAccountRow(
                context.tr.translate('height'),
                nutritionProvider.getFormattedHeight(),
                Icons.height,
                theme,
                onTap: () => _showEditHeightDialog(nutritionProvider),
              ),
              _buildAccountRow(
                context.tr.translate('weight'),
                nutritionProvider.getFormattedWeight(),
                Icons.monitor_weight_outlined,
                theme,
                onTap: () => _showEditWeightDialog(nutritionProvider),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Diet Section (Dieta)
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: context.tr.translate('diet'),
            children: [
              _buildAccountRow(
                context.tr.translate('goal'),
                nutritionProvider.getFitnessGoalName(nutritionProvider.fitnessGoal, context),
                Icons.track_changes,
                theme,
                onTap: () => _showEditGoalDialog(theme, nutritionProvider),
              ),
              _buildAccountRow(
                context.tr.translate('activity_level'),
                nutritionProvider.getActivityLevelName(nutritionProvider.activityLevel, context),
                Icons.directions_run,
                theme,
                onTap: () => _showEditActivityLevelDialog(theme, nutritionProvider),
              ),
              _buildAccountRow(
                context.tr.translate('diet'),
                nutritionProvider.getDietTypeName(nutritionProvider.dietType, context),
                Icons.restaurant_menu,
                theme,
                onTap: () => _showEditDietTypeDialog(theme, nutritionProvider),
              ),
              _buildFormulaRow(theme),
              // Show body fat percentage only when Katch-McArdle is selected
              if (nutritionProvider.formula == CalculationFormula.katchMcArdle)
                _buildAccountRow(
                  context.tr.translate('body_fat_percentage'),
                  nutritionProvider.bodyFat != null
                      ? '${nutritionProvider.bodyFat!.toStringAsFixed(1)}%'
                      : context.tr.translate('not_informed'),
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
            title: context.tr.translate('preferences'),
            children: [
              _buildLanguageRow(theme),
            ],
          ),
          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: context.tr.translate('notifications'),
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
          context.tr.translate('calculation_formula'),
          provider.getFormulaName(provider.formula, context),
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
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr.translate('calculation_formula')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: formulas.map((formula) {
            final isSelected = formula == provider.formula;
            return ListTile(
              leading: Icon(
                Icons.calculate,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(provider.getFormulaName(formula, dialogContext)),
              subtitle: Text(
                _getFormulaDescription(formula),
                style: theme.textTheme.bodySmall,
              ),
              trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                provider.updateActivityAndGoals(formula: formula);
                Navigator.pop(dialogContext);

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
        return context.tr.translate('formula_mifflin_description');
      case CalculationFormula.harrisBenedict:
        return context.tr.translate('formula_harris_description');
      case CalculationFormula.katchMcArdle:
        return context.tr.translate('formula_katch_description');
    }
  }

  void _showBodyFatDialog(ThemeData theme, NutritionGoalsProvider provider) {
    final controller = TextEditingController(
      text: provider.bodyFat?.toStringAsFixed(1) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.translate('body_fat_percentage_full')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr.translate('katch_mcardle_description'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr.translate('body_fat_percentage_label'),
                hintText: context.tr.translate('body_fat_example'),
                border: const OutlineInputBorder(),
                suffixText: '%',
                helperText: context.tr.translate('body_fat_range'),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              final bodyFat = double.tryParse(controller.text);
              if (bodyFat != null && bodyFat >= 5 && bodyFat <= 50) {
                provider.updatePersonalInfo(bodyFat: bodyFat);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr.translate('body_fat_validation_error')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(context.tr.translate('save')),
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
                  context.tr.translate('meal_reminders'),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr.translate('meal_reminders_description'),
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
