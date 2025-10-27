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
  String _units = 'Metric';
  bool _mealReminders = true;

  // Account (Conta) data
  String _userName = 'Fabiano';
  int _age = 28;
  String _gender = 'Masculino';
  String _height = '5 ft 11 in';
  String _weight = '192,2 lb';
  String _unitsSystem = 'Imperial(lb, ft)';

  // Diet (Dieta) data
  String _objective = '';
  String _activityLevel = 'Moderadamente ativo';
  String _restrictions = 'Nenhum';
  String _dietType = 'Inteligência Artificial';
  String _healthConditions = 'Nenhum';
  bool _addExerciseCalories = true;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              _buildAccountRow('Nome', _userName, Icons.person_outline, theme, onTap: () {}),
              _buildAccountRow('Idade', _age.toString(), Icons.cake_outlined, theme, onTap: () {}),
              _buildAccountRow('Gênero', _gender, Icons.wc_outlined, theme, onTap: () {}),
              _buildAccountRow('Altura', _height, Icons.height, theme, onTap: () {}),
              _buildAccountRow('Peso', _weight, Icons.monitor_weight_outlined, theme, onTap: () {}),
              _buildAccountRow('Unidade', _unitsSystem, Icons.straighten, theme, onTap: () {}),
            ],
          ),
          const SizedBox(height: 24),

          // Diet Section (Dieta)
          _buildSectionCard(
            theme: theme,
            colorScheme: colorScheme,
            title: 'Dieta',
            children: [
              _buildAccountRow('Objetivo', _objective.isEmpty ? 'Atualizar' : _objective, Icons.track_changes, theme,
                onTap: () {}, isAction: _objective.isEmpty),
              _buildAccountRow('Nível de Atividade', _activityLevel, Icons.directions_run, theme, onTap: () {}),
              _buildAccountRow('Restrições', _restrictions, Icons.block, theme, onTap: () {}),
              _buildAccountRow('Dieta', _dietType, Icons.restaurant_menu, theme, onTap: () {}),
              _buildAccountRow('Condições de Saúde', _healthConditions, Icons.favorite_border, theme, onTap: () {}),
              _buildFormulaRow(theme),
              _buildSwitchRow('Adicionar calorias de exercício ao objetivo diário', _addExerciseCalories, theme, colorScheme, (value) {
                setState(() => _addExerciseCalories = value);
              }),
              _buildAccountRow('Detalhes Extras', '', Icons.description_outlined, theme, onTap: () {}),
              _buildAccountRow('Lembretes Inteligentes', '', Icons.notifications_none, theme, onTap: () {}),
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
                final isSelected = unit == _units;
                return GestureDetector(
                  onTap: () {
                    setState(() => _units = unit);
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

  Widget _buildSwitchRow(
    String label,
    bool value,
    ThemeData theme,
    ColorScheme colorScheme,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
