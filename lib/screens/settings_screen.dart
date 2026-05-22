import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../theme/app_theme.dart';

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
  String _appVersion = '--';

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);

  Color _inputFillColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;

  Color _subtleBorderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white12 : Colors.black12;

  Color _mutedTextColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final languageController =
          Provider.of<LanguageController>(context, listen: false);
      final packageInfo = await PackageInfo.fromPlatform();
      String currentLanguage =
          languageController.localeToString(languageController.currentLocale);

      if (!mounted) return;

      setState(() {
        _selectedLanguage = currentLanguage.isNotEmpty ? currentLanguage : 'en';
        _themeMode = themeProvider.themeMode;
        _appVersion = packageInfo.buildNumber.isNotEmpty
            ? '${packageInfo.version} (${packageInfo.buildNumber})'
            : packageInfo.version;
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

    final languageController =
        Provider.of<LanguageController>(context, listen: false);
    await languageController
        .setLocale(languageController.localeFromString(_selectedLanguage));
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
    String shareMessage = context.tr
        .translate('share_app_message')
        .replaceAll('{url}', playStoreUrl);
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
    final nutritionProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
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
    final nutritionProvider =
        Provider.of<NutritionGoalsProvider>(context, listen: false);
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
              trailing:
                  currentGender == 'male' ? const Icon(Icons.check) : null,
              onTap: () {
                nutritionProvider.updatePersonalInfo(sex: 'male');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.female),
              title: Text(context.tr.translate('female')),
              trailing:
                  currentGender == 'female' ? const Icon(Icons.check) : null,
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
      cmController =
          TextEditingController(text: provider.height.toStringAsFixed(0));
    } else {
      final heightData = provider.heightInFeet();
      feetController =
          TextEditingController(text: heightData['feet'].toString());
      inchesController =
          TextEditingController(text: heightData['inches'].toString());
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
                heightInCm =
                    double.tryParse(cmController.text) ?? provider.height;
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
        kgController =
            TextEditingController(text: provider.weight.toStringAsFixed(1));
        break;
      case WeightUnit.lbs:
        lbsController = TextEditingController(
            text: provider.weightInLbs().toStringAsFixed(1));
        break;
      case WeightUnit.stLbs:
        final weightData = provider.weightInStLbs();
        stoneController =
            TextEditingController(text: weightData['stone'].toString());
        poundsController =
            TextEditingController(text: weightData['pounds'].toString());
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.tr.translate('weight_kg'),
                  border: const OutlineInputBorder(),
                ),
              )
            : provider.weightUnit == WeightUnit.lbs
                ? TextField(
                    controller: lbsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  weightInKg =
                      double.tryParse(kgController.text) ?? provider.weight;
                  break;
                case WeightUnit.lbs:
                  final lbs = double.tryParse(lbsController.text) ??
                      provider.weightInLbs();
                  weightInKg = NutritionGoalsProvider.weightToKg(lbs);
                  break;
                case WeightUnit.stLbs:
                  final stone = int.tryParse(stoneController.text) ?? 0;
                  final pounds = int.tryParse(poundsController.text) ?? 0;
                  weightInKg =
                      NutritionGoalsProvider.weightStLbsToKg(stone, pounds);
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
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
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

  void _showEditActivityLevelDialog(
      ThemeData theme, NutritionGoalsProvider provider) {
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
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
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

  void _showEditDietTypeDialog(
      ThemeData theme, NutritionGoalsProvider provider) {
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
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final nutritionProvider = Provider.of<NutritionGoalsProvider>(context);
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildMinimalHeader(textColor),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                      children: [
                        _buildSectionCard(
                          theme: theme,
                          colorScheme: colorScheme,
                          title: context.tr.translate('account'),
                          children: [
                            _buildAccountRow(
                              context.tr.translate('name'),
                              authService.isAuthenticated
                                  ? authService.currentUser?.name ??
                                      context.tr.translate('user')
                                  : context.tr.translate('not_logged_in'),
                              Icons.person_outline,
                              theme,
                              onTap: authService.isAuthenticated
                                  ? () => _showEditNameDialog(
                                      authService.currentUser?.name ?? '')
                                  : null,
                            ),
                            _buildAccountRow(
                              context.tr.translate('age'),
                              '${nutritionProvider.age}${context.tr.translate('years_suffix')}',
                              Icons.cake_outlined,
                              theme,
                              onTap: () =>
                                  _showEditAgeDialog(nutritionProvider.age),
                            ),
                            _buildAccountRow(
                              context.tr.translate('gender'),
                              nutritionProvider.sex == 'male'
                                  ? context.tr.translate('male')
                                  : context.tr.translate('female'),
                              Icons.wc_outlined,
                              theme,
                              onTap: () =>
                                  _showEditGenderDialog(nutritionProvider.sex),
                            ),
                            _buildAccountRow(
                              context.tr.translate('height'),
                              nutritionProvider.getFormattedHeight(),
                              Icons.height,
                              theme,
                              onTap: () =>
                                  _showEditHeightDialog(nutritionProvider),
                            ),
                            _buildAccountRow(
                              context.tr.translate('weight'),
                              nutritionProvider.getFormattedWeight(),
                              Icons.monitor_weight_outlined,
                              theme,
                              onTap: () =>
                                  _showEditWeightDialog(nutritionProvider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _buildSectionCard(
                          theme: theme,
                          colorScheme: colorScheme,
                          title: context.tr.translate('diet'),
                          children: [
                            _buildAccountRow(
                              context.tr.translate('goal'),
                              nutritionProvider.getFitnessGoalName(
                                  nutritionProvider.fitnessGoal, context),
                              Icons.track_changes,
                              theme,
                              onTap: () =>
                                  _showEditGoalDialog(theme, nutritionProvider),
                            ),
                            _buildAccountRow(
                              context.tr.translate('activity_level'),
                              nutritionProvider.getActivityLevelName(
                                  nutritionProvider.activityLevel, context),
                              Icons.directions_run,
                              theme,
                              onTap: () => _showEditActivityLevelDialog(
                                  theme, nutritionProvider),
                            ),
                            _buildAccountRow(
                              context.tr.translate('diet'),
                              nutritionProvider.getDietTypeName(
                                  nutritionProvider.dietType, context),
                              Icons.restaurant_menu,
                              theme,
                              onTap: () => _showEditDietTypeDialog(
                                  theme, nutritionProvider),
                            ),
                            _buildFormulaRow(theme),
                            if (nutritionProvider.formula ==
                                CalculationFormula.katchMcArdle)
                              _buildAccountRow(
                                context.tr.translate('body_fat_percentage'),
                                nutritionProvider.bodyFat != null
                                    ? '${nutritionProvider.bodyFat!.toStringAsFixed(1)}%'
                                    : context.tr.translate('not_informed'),
                                Icons.fitness_center,
                                theme,
                                onTap: () => _showBodyFatDialog(
                                    theme, nutritionProvider),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _buildSectionCard(
                          theme: theme,
                          colorScheme: colorScheme,
                          title: context.tr.translate('preferences'),
                          children: [
                            _buildThemeRow(theme, colorScheme),
                            _buildLanguageRow(theme),
                            _buildNotificationRow(theme, colorScheme),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _buildSectionCard(
                          theme: theme,
                          colorScheme: colorScheme,
                          title: context.tr.translate('about'),
                          children: [
                            _buildNavigationRow(
                              context.tr.translate('app_version'),
                              _appVersion,
                              Icons.info_outline,
                              theme,
                              onTap: null,
                            ),
                            _buildNavigationRow(
                              context.tr.translate('privacy_policy'),
                              '',
                              Icons.privacy_tip_outlined,
                              theme,
                              onTap: () {},
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalHeader(Color textColor) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              tooltip: context.tr.translate('back'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Text(
            context.tr.translate('settings_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.88),
            ),
          ),
        ),
        ..._buildSectionChildren(children, colorScheme),
      ],
    );
  }

  List<Widget> _buildSectionChildren(
      List<Widget> children, ColorScheme colorScheme) {
    final items = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(const SizedBox(height: 10));
      }
    }

    return items;
  }

  Widget _buildThemeRow(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final themeOptions = {
      ThemeMode.light: context.tr.translate('light_theme'),
      ThemeMode.dark: context.tr.translate('dark_theme'),
      ThemeMode.system: context.tr.translate('system_theme'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _inputFillColor(isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLeadingIcon(Icons.palette_outlined, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr.translate('theme'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: themeOptions.entries.map((entry) {
              final isSelected = entry.key == _themeMode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _themeMode = entry.key;
                      });
                      _saveSettings();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? textColor : _surfaceColor(isDarkMode),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected
                              ? textColor
                              : _subtleBorderColor(isDarkMode),
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppTheme.onColor(textColor)
                              : textColor.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(IconData icon, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: Icon(
        icon,
        size: 18,
        color: textColor,
      ),
    );
  }

  Widget _buildLanguageRow(ThemeData theme) {
    return _buildAccountRow(
      context.tr.translate('language'),
      _getCurrentLanguageName(),
      Icons.translate_rounded,
      theme,
      onTap: () {
        _showLanguageDialog(theme, AppLocalizations.getAvailableLanguages());
      },
      isAction: true,
    );
  }

  String _getCurrentLanguageName() {
    return AppLocalizations.getAvailableLanguages().firstWhere(
      (lang) => lang['code'] == _selectedLanguage,
      orElse: () => {'name': 'English', 'code': 'en'},
    )['name']!;
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
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
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
                    content:
                        Text(context.tr.translate('body_fat_validation_error')),
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _mealReminders = !_mealReminders);
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: _inputFillColor(isDarkMode),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _subtleBorderColor(isDarkMode)),
          ),
          child: Row(
            children: [
              _buildLeadingIcon(Icons.notifications_outlined, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr.translate('meal_reminders'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _mealReminders,
                  onChanged: (value) {
                    setState(() => _mealReminders = value);
                  },
                  activeThumbColor: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(
      ThemeData theme, List<Map<String, String>> availableLanguages) {
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
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
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
    return _buildAccountRow(
      label,
      trailing,
      icon,
      theme,
      onTap: onTap,
    );
  }

  Widget _buildAccountRow(
    String label,
    String value,
    IconData icon,
    ThemeData theme, {
    VoidCallback? onTap,
    bool isAction = false,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final mutedColor = _mutedTextColor(isDarkMode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _inputFillColor(isDarkMode),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _subtleBorderColor(isDarkMode)),
          ),
          child: Row(
            children: [
              _buildLeadingIcon(icon, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: isAction ? textColor : mutedColor,
                      fontWeight: isAction ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: mutedColor.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
