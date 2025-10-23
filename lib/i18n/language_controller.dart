import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';
import 'dart:ui' as ui;

class LanguageController extends ChangeNotifier {
  static const String LANGUAGE_CODE = 'languageCode';
  static const String COUNTRY_CODE = 'countryCode';

  Locale _currentLocale = Locale('pt', 'BR'); // Padrão é Português do Brasil

  Locale get currentLocale => _currentLocale;

  LanguageController() {
    _loadSavedLanguage();
  }

  // Obter o idioma do dispositivo
  Locale getDeviceLocale() {
    final locale = ui.window.locale;
    String languageCode = locale.languageCode;
    String countryCode = locale.countryCode ?? '';

    // Verifica se o idioma do dispositivo é suportado
    for (var supportedLocale in AppLocalizations.supportedLocales) {
      if (supportedLocale.languageCode == languageCode) {
        // Se o país for correspondente, retorna exatamente
        if (supportedLocale.countryCode == countryCode) {
          return supportedLocale;
        }
        // Se tiver o mesmo idioma, mas país diferente, usa o país que temos
        return supportedLocale;
      }
    }

    // Se não for suportado, retorna o padrão (PT-BR)
    return Locale('pt', 'BR');
  }

  // Carregar o idioma salvo nas preferências
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    // Verifica se já existe um idioma salvo
    if (prefs.containsKey(LANGUAGE_CODE)) {
      String languageCode = prefs.getString(LANGUAGE_CODE) ?? 'pt';
      String countryCode = prefs.getString(COUNTRY_CODE) ?? 'BR';
      _currentLocale = Locale(languageCode, countryCode);
    } else {
      // Se não existe idioma salvo, usa o do dispositivo
      _currentLocale = getDeviceLocale();

      // Salva esse idioma nas preferências
      await prefs.setString(LANGUAGE_CODE, _currentLocale.languageCode);
      await prefs.setString(COUNTRY_CODE, _currentLocale.countryCode!);
    }

    notifyListeners();
  }

  // Definir o idioma do aplicativo
  Future<void> setLocale(Locale locale) async {
    if (!isLocaleSupported(locale)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LANGUAGE_CODE, locale.languageCode);
    await prefs.setString(COUNTRY_CODE, locale.countryCode!);

    _currentLocale = locale;
    notifyListeners();
  }

  // Verificar se o idioma é suportado
  bool isLocaleSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .where((supportedLocale) =>
            supportedLocale.languageCode == locale.languageCode &&
            supportedLocale.countryCode == locale.countryCode)
        .isNotEmpty;
  }

  // Converter código de idioma para Locale
  Locale localeFromString(String localeString) {
    List<String> parts = localeString.split('_');
    return Locale(parts[0], parts[1]);
  }

  // Converter Locale para string
  String localeToString(Locale locale) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
}
