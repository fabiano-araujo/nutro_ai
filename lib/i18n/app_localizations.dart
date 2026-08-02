import 'package:flutter/material.dart';
import 'app_localizations_delegate.dart';
import 'translations/pt_br_translations.dart';
import 'translations/en_us_translations.dart';
import 'translations/es_es_translations.dart';
import 'translations/fr_fr_translations.dart';
import 'translations/de_de_translations.dart';
import 'translations/it_it_translations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Static member to provide the delegate
  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();

  // Map dos diferentes idiomas suportados
  static final Map<String, Map<String, String>> _localizedValues = {
    'pt_BR': ptBRTranslations,
    'en_US': enUSTranslations,
    'es_ES': esESTranslations,
    'fr_FR': frFRTranslations,
    'de_DE': deDETranslations,
    'it_IT': itITTranslations,
  };

  // Lista de idiomas suportados
  static final List<Locale> supportedLocales = [
    Locale('pt', 'BR'),
    Locale('en', 'US'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
    Locale('de', 'DE'),
    Locale('it', 'IT'),
  ];

  String get currentLanguage => locale.toString();

  // Método para obter a tradução
  String translate(String key) {
    String localeString = locale.toString();

    // Verificar se o idioma é suportado
    if (!_localizedValues.containsKey(localeString)) {
      localeString = 'pt_BR'; // Fallback para português
    }

    // Verificar se a chave de tradução existe
    if (!_localizedValues[localeString]!.containsKey(key)) {
      // Se não existir no idioma atual, procurar no fallback
      if (_localizedValues['pt_BR']!.containsKey(key)) {
        return _localizedValues['pt_BR']![key]!;
      }
      return key; // Retornar a chave se não houver tradução
    }

    return _localizedValues[localeString]![key]!;
  }

  // Nomes dos idiomas para exibição
  static Map<String, String> languageNames = {
    'pt_BR': 'Português (Brasil)',
    'en_US': 'English (US)',
    'es_ES': 'Español',
    'fr_FR': 'Français',
    'de_DE': 'Deutsch',
    'it_IT': 'Italiano',
  };

  // Método para obter os idiomas disponíveis
  static List<Map<String, String>> getAvailableLanguages() {
    return supportedLocales.map((locale) {
      return {
        'code': locale.toString(),
        'name': languageNames[locale.toString()]!
      };
    }).toList();
  }
}
