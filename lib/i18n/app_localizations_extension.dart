import 'package:flutter/material.dart';
import 'app_localizations.dart';

extension AppLocalizationsExtension on BuildContext {
  /// Retorna a instância das localizações do aplicativo
  AppLocalizations get tr => AppLocalizations.of(this);
}
