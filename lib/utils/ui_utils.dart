import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../i18n/app_localizations.dart';

// Classe utilitária para funções relacionadas à UI
class UIUtils {
  // Exibir diálogo de erro genérico
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('error_title')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('ok')),
          ),
        ],
      ),
    );
  }

  // Exibir diálogo específico para problemas de permissão
  static void showPermissionDialog(BuildContext context,
      {bool permanentlyDenied = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).translate('permission_required_title'),
        ),
        content: Text(
          permanentlyDenied
              ? AppLocalizations.of(context).translate(
                  'microphone_permission_permanently_denied_message',
                )
              : AppLocalizations.of(context).translate(
                  'microphone_permission_voice_recognition_message',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (permanentlyDenied) {
                openAppSettings(); // Função do package permission_handler
              } else {
                Permission.microphone.request();
              }
            },
            child: Text(
              AppLocalizations.of(context).translate(
                permanentlyDenied ? 'open_settings' : 'allow',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mostrar um toast (SnackBar) simples
  static void showSimpleToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2), // Aumentei um pouco a duração
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Mostrar o feedback de sucesso padrão usado nos fluxos principais do app
  static void showPrimarySnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
