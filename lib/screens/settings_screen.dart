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
import '../providers/diet_plan_provider.dart';
import '../models/notification_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int? initialTab;

  const SettingsScreen({Key? key, this.initialTab}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const double _listItemTitleFontSize = 14;
  static const double _listItemSubtitleFontSize = 12;

  final StorageService _storageService = StorageService();
  String _selectedLanguage = 'en';
  ThemeMode _themeMode = ThemeMode.light;
  NotificationPreferences _notificationPreferences =
      NotificationPreferences.defaults;
  String _appVersion = '--';

  Color _primaryTextColor(bool isDarkMode) =>
      isDarkMode ? Colors.white : AppTheme.textPrimaryColor;

  Color _mutedTextColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;

  Color _controlFillColor(bool isDarkMode) =>
      isDarkMode ? AppTheme.darkComponentColor : AppTheme.backgroundColor;

  Color _controlBorderColor(ColorScheme colorScheme) =>
      colorScheme.outlineVariant.withValues(alpha: 0.18);

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
      final notificationPreferences =
          await NotificationService().getPreferences();
      String currentLanguage =
          languageController.localeToString(languageController.currentLocale);

      if (!mounted) return;

      setState(() {
        _selectedLanguage = currentLanguage.isNotEmpty ? currentLanguage : 'en';
        _themeMode = themeProvider.themeMode;
        _appVersion = packageInfo.buildNumber.isNotEmpty
            ? '${packageInfo.version} (${packageInfo.buildNumber})'
            : packageInfo.version;
        _notificationPreferences = notificationPreferences;
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
    final dietTypes = selectableDietTypes;
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
    final dietProvider = Provider.of<DietPlanProvider>(context);
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textColor = _primaryTextColor(isDarkMode);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          tooltip: context.tr.translate('back'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr.translate('settings_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                    onTap: () => _showEditAgeDialog(nutritionProvider.age),
                  ),
                  _buildAccountRow(
                    context.tr.translate('gender'),
                    nutritionProvider.sex == 'male'
                        ? context.tr.translate('male')
                        : context.tr.translate('female'),
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
                    onTap: () => _showEditGoalDialog(theme, nutritionProvider),
                  ),
                  _buildAccountRow(
                    context.tr.translate('activity_level'),
                    nutritionProvider.getActivityLevelName(
                        nutritionProvider.activityLevel, context),
                    Icons.directions_run,
                    theme,
                    onTap: () =>
                        _showEditActivityLevelDialog(theme, nutritionProvider),
                  ),
                  _buildAccountRow(
                    context.tr.translate('diet'),
                    nutritionProvider.getDietTypeName(
                        nutritionProvider.dietType, context),
                    Icons.restaurant_menu,
                    theme,
                    onTap: () =>
                        _showEditDietTypeDialog(theme, nutritionProvider),
                  ),
                  _buildDietAiModelRow(theme, dietProvider),
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
                      onTap: () => _showBodyFatDialog(theme, nutritionProvider),
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
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String title,
    required List<Widget> children,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _primaryTextColor(isDarkMode).withValues(alpha: 0.88),
            ),
          ),
        ),
        Container(
          decoration: AppTheme.profileCardDecoration(isDarkMode),
          child: Column(
            children: [
              const SizedBox(height: 6),
              ..._buildSectionChildren(children, colorScheme),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSectionChildren(
      List<Widget> children, ColorScheme colorScheme) {
    final items = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(_buildDivider(colorScheme));
      }
    }

    return items;
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 28),
      child: Divider(
        height: 1,
        color: _controlBorderColor(colorScheme),
      ),
    );
  }

  Widget _buildThemeRow(ThemeData theme, ColorScheme colorScheme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = _primaryTextColor(isDarkMode);
    final mutedColor = _mutedTextColor(isDarkMode);
    final themeOptions = {
      ThemeMode.light: context.tr.translate('light_theme'),
      ThemeMode.dark: context.tr.translate('dark_theme'),
      ThemeMode.system: context.tr.translate('system_theme'),
    };
    final currentTheme = themeOptions[_themeMode] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLeadingIcon(Icons.palette_outlined, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr.translate('theme'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: _listItemTitleFontSize,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentTheme,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: _listItemSubtitleFontSize,
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
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
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      constraints: const BoxConstraints(minHeight: 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : _controlFillColor(isDarkMode),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : _controlBorderColor(colorScheme),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? AppTheme.onColor(colorScheme.primary)
                                : textColor.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w600,
                          ),
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
    final iconColor = theme.colorScheme.primary;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 23,
        color: iconColor,
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

  Widget _buildDietAiModelRow(
    ThemeData theme,
    DietPlanProvider dietProvider,
  ) {
    return _buildAccountRow(
      context.tr.translate('diet_ai_model'),
      dietProvider.getDietGenerationModelName(),
      Icons.psychology_alt_outlined,
      theme,
      onTap: () => _showDietAiModelDialog(dietProvider),
    );
  }

  Future<void> _showDietAiModelDialog(
    DietPlanProvider dietProvider,
  ) async {
    final currentModel = dietProvider.dietGenerationModel;

    final selectedModel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _DietAiModelDialog(
        currentModel: currentModel,
        dietProvider: dietProvider,
      ),
    );

    if (!mounted || selectedModel == null) {
      return;
    }

    await dietProvider.updateDietGenerationModel(selectedModel);
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

  Widget _buildNotificationRow(ThemeData theme, ColorScheme _) {
    return _buildAccountRow(
      context.tr.translate('notifications'),
      _notificationSummary(),
      Icons.notifications_outlined,
      theme,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationSettingsScreen(),
          ),
        );

        if (!mounted) return;
        final preferences = await NotificationService().getPreferences();
        if (mounted) {
          setState(() => _notificationPreferences = preferences);
        }
      },
    );
  }

  String _notificationSummary() {
    final enabledCount = _notificationPreferences.enabledCount;
    if (enabledCount == 0) {
      return context.tr.translate('notifications_all_disabled');
    }

    return context.tr
        .translate('notifications_enabled_count')
        .replaceAll('{count}', enabledCount.toString());
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
    final textColor = _primaryTextColor(isDarkMode);
    final mutedColor = _mutedTextColor(isDarkMode);
    final valueColor = isAction ? theme.colorScheme.primary : mutedColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: value.isNotEmpty ? 9 : 12,
          ),
          child: Row(
            children: [
              _buildLeadingIcon(icon, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: _listItemTitleFontSize,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.18,
                      ),
                    ),
                    if (value.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: _listItemSubtitleFontSize,
                          color: valueColor,
                          fontWeight:
                              isAction ? FontWeight.w600 : FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: mutedColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DietAiModelDialog extends StatefulWidget {
  const _DietAiModelDialog({
    required this.currentModel,
    required this.dietProvider,
  });

  final String currentModel;
  final DietPlanProvider dietProvider;

  @override
  State<_DietAiModelDialog> createState() => _DietAiModelDialogState();
}

class _DietAiModelDialogState extends State<_DietAiModelDialog> {
  late final TextEditingController _customModelController;
  String? _customModelError;

  @override
  void initState() {
    super.initState();
    _customModelController = TextEditingController(
      text: widget.dietProvider.isPredefinedDietGenerationModel(
        widget.currentModel,
      )
          ? ''
          : widget.currentModel,
    );
  }

  @override
  void dispose() {
    _customModelController.dispose();
    super.dispose();
  }

  void _selectModel(String modelId) {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, modelId);
  }

  void _saveCustomModel(AppLocalizations l10n) {
    final modelId = _customModelController.text.trim();
    if (!DietPlanProvider.isValidOpenRouterModelId(modelId)) {
      setState(() {
        _customModelError = l10n.translate('invalid_openrouter_model_id');
      });
      return;
    }

    _selectModel(modelId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.tr;

    return AlertDialog(
      title: Text(l10n.translate('diet_ai_model')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...DietPlanProvider.dietGenerationModelOptions.map((option) {
              final modelId = option['id']!;
              final isSelected = modelId == widget.currentModel;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.auto_awesome,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                title: Text(option['name']!),
                subtitle: Text(
                  widget.dietProvider.getDietGenerationModelDescription(
                    modelId,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () => _selectModel(modelId),
              );
            }),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.translate('custom_openrouter_model'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.translate('openrouter_model_id_helper'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customModelController,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.translate('custom_openrouter_model'),
                hintText: l10n.translate('openrouter_model_id_hint'),
                errorText: _customModelError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_customModelError != null) {
                  setState(() => _customModelError = null);
                }
              },
              onSubmitted: (_) => _saveCustomModel(l10n),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.translate('cancel')),
        ),
        FilledButton(
          onPressed: () => _saveCustomModel(l10n),
          child: Text(l10n.translate('save')),
        ),
      ],
    );
  }
}
