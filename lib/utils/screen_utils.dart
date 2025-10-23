import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Classe utilitária para funções relacionadas à tela e gerenciamento de recursos do sistema
class ScreenUtils {
  /// Controla se a tela deve permanecer ligada
  static void keepScreenOn(bool keepOn, {bool printLogs = true}) {
    if (kIsWeb) return; // Não aplicável na web

    if (keepOn) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        return Future.value();
      });
      // Manter a tela ligada
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ));

      // Reduz impressão de logs para não sobrecarregar
      if (printLogs) {
        if (!kIsWeb && Platform.isAndroid) {
          // No Android, logs excessivos diminuem o desempenho
          print('🔆 Tela mantida ligada para gravação');
        } else {
          print('🔆 Mantendo tela ligada para reconhecimento de voz');
        }
      }
    } else {
      // Restaurar comportamento normal
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ));

      // Reduz impressão de logs
      if (printLogs) {
        if (!kIsWeb && Platform.isAndroid) {
          print('🔅 Comportamento de tela restaurado');
        } else {
          print('🔅 Restaurando comportamento normal da tela');
        }
      }
    }

    // Para dispositivos Android, recomendamos limpar o cache quando não estiver mais usando o microfone
    if (!keepOn && !kIsWeb && Platform.isAndroid) {
      // Liberar recursos em segundo plano
      Future.delayed(const Duration(milliseconds: 200), () {
        // Limpar memória desnecessária
        optimizeAndroidMemory();
      });
    }
  }

  /// Otimiza o uso de memória no Android
  static void optimizeAndroidMemory() {
    if (!kIsWeb && Platform.isAndroid) {
      // Executar coleta de lixo manual e liberar recursos não utilizados
      // Isso ajuda a melhorar o desempenho em dispositivos Android com recursos limitados
      try {
        // Reduzir o tamanho do cache para minimizar uso de memória
        ImageCache().clear();
        ImageCache().maximumSize =
            10; // Diminuir o tamanho do cache de imagens temporariamente

        // Redefinir depois de alguns segundos
        Future.delayed(const Duration(seconds: 5), () {
          ImageCache().maximumSize = 1000; // Voltar ao valor padrão
        });
      } catch (e) {
        // Ignorar erros de otimização, não são críticos
      }
    }
  }
}
