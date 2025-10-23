import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../i18n/app_localizations.dart';
import '../i18n/language_controller.dart';
import '../i18n/app_localizations_extension.dart';
import '../widgets/rate_app_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  // Adicionar parâmetro initialTab para permitir abrir a tela em uma aba específica
  final int? initialTab;

  const SettingsScreen({Key? key, this.initialTab}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  String _selectedLanguage = ''; // Será preenchido ao carregar as configurações
  ThemeMode _themeMode = ThemeMode.light; // Default to light theme
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Inicializar o controlador de tabs com o índice inicial fornecido
    _tabController = TabController(
      length: 3, // Número de abas
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );

    // Pequeno atraso para garantir que o Provider esteja disponível
    Future.microtask(() => _loadSettings());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      // Obter o tema diretamente do ThemeProvider
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      // Obter o idioma do LanguageController
      final languageController =
          Provider.of<LanguageController>(context, listen: false);
      String currentLanguage =
          languageController.localeToString(languageController.currentLocale);

      setState(() {
        _selectedLanguage = currentLanguage;
        _themeMode = themeProvider.themeMode;
      });

      print(
          'Tema carregado na tela de configurações: ${_themeModeToString(_themeMode)}');
    } catch (e) {
      print('Erro ao carregar configurações: $e');
    }
  }

  ThemeMode _getThemeMode(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
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
      default:
        return 'dark';
    }
  }

  Future<void> _saveSettings() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Atualizar app theme primeiro
    themeProvider.setThemeMode(_themeMode);

    // Salvar a configuração
    await _storageService.saveSettings({
      'theme': _themeModeToString(_themeMode),
    });

    // Update app language
    final languageController =
        Provider.of<LanguageController>(context, listen: false);
    await languageController
        .setLocale(languageController.localeFromString(_selectedLanguage));

    print('Tema salvo nas configurações: ${_themeModeToString(_themeMode)}');
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
    // Usar a string traduzida substituindo {url} pela URL da Play Store
    String shareMessage = context.tr
        .translate('share_app_message')
        .replaceAll('{url}', playStoreUrl);
    await Share.share(shareMessage);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? AppTheme.darkBackgroundColor : Colors.white,
        title: Text(context.tr.translate('settings_title'),
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
        elevation: 0,
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme setting
            _buildSectionHeader(context.tr.translate('theme'), isDarkMode),
            _buildThemeSelector(isDarkMode, context),

            SizedBox(height: 24),

            // Language setting
            _buildSectionHeader(context.tr.translate('language'), isDarkMode),
            _buildLanguageSelector(isDarkMode),

            SizedBox(height: 24),

            // About section
            _buildSectionHeader(context.tr.translate('about'), isDarkMode),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.purple.withOpacity(0.2)
                      : Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.purple,
                ),
              ),
              title: Text(
                context.tr.translate('app_version'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '1.0.0',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.indigo.withOpacity(0.2)
                      : Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.indigo,
                ),
              ),
              title: Text(
                context.tr.translate('privacy_policy'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
              onTap: () {
                // Open privacy policy
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.teal.withOpacity(0.2)
                      : Colors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_outline,
                  color: Colors.teal,
                ),
              ),
              title: Text(
                context.tr.translate('rate_app'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
              onTap: () {
                // Abrir o bottom sheet de avaliação
                RateAppBottomSheet.show(context);
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            ),
            // Botão de compartilhar o app
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.green.withOpacity(0.2)
                      : Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.share,
                  color: Colors.green,
                ),
              ),
              title: Text(
                context.tr.translate('share_app'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
              onTap: () async {
                // Compartilhar o link da Play Store
                await _shareApp();
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            ),
            SizedBox(height: 32),
            // Botão de sair da conta
            if (authService.isAuthenticated)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await authService.logout();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(context.tr.translate('sign_out')),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(bool isDarkMode, BuildContext context) {
    return Card(
      elevation: 0,
      color: isDarkMode ? AppTheme.darkCardColor : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: DropdownButtonFormField<ThemeMode>(
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
          ),
          value: _themeMode,
          dropdownColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onChanged: (ThemeMode? newValue) {
            if (newValue != null) {
              setState(() {
                _themeMode = newValue;
              });
              _saveSettings();
            }
          },
          items: [
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Row(
                children: [
                  Icon(
                    Icons.dark_mode,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    context.tr.translate('dark_theme'),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Row(
                children: [
                  Icon(
                    Icons.light_mode,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    context.tr.translate('light_theme'),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Row(
                children: [
                  Icon(
                    Icons.settings_brightness,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    context.tr.translate('system_theme'),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(bool isDarkMode) {
    List<Map<String, String>> availableLanguages =
        AppLocalizations.getAvailableLanguages();

    return Card(
      elevation: 0,
      color: isDarkMode ? AppTheme.darkCardColor : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
          ),
          value: _selectedLanguage,
          dropdownColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLanguage = newValue;
              });
              _saveSettings();
            }
          },
          items:
              availableLanguages.map<DropdownMenuItem<String>>((languageInfo) {
            return DropdownMenuItem<String>(
              value: languageInfo['code'],
              child: Row(
                children: [
                  Icon(
                    Icons.translate,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    languageInfo['code']!.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    languageInfo['name']!,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
