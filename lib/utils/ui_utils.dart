import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// Classe utilitária para funções relacionadas à UI
class UIUtils {
  // Exibir diálogo de erro genérico
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
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
        title: Text('Permissão necessária'),
        content: Text(
          permanentlyDenied
              ? 'A permissão do microfone foi negada permanentemente. Por favor, abra as configurações do aplicativo para habilitar o microfone.'
              : 'Para usar o reconhecimento de voz, você precisa permitir o acesso ao microfone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
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
            child: Text(permanentlyDenied ? 'Abrir Configurações' : 'Permitir'),
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
        duration: Duration(seconds: 2), // Aumentei um pouco a duração
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
