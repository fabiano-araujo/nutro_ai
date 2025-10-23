import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdSettingsService {
  static const String _appOpenCountKey = 'app_open_count';
  static const String _lastAdShownTimeKey = 'last_ad_shown_time';

  // Incrementa e retorna a contagem de abertura do app
  Future<int> incrementAppOpenCount() async {
    // Se estiver na web, retorne 0
    if (kIsWeb) {
      return 0;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      int currentCount = prefs.getInt(_appOpenCountKey) ?? 0;
      currentCount++;
      await prefs.setInt(_appOpenCountKey, currentCount);
      return currentCount;
    } catch (e) {
      print('Erro ao incrementar contagem de abertura do app: $e');
      return 0;
    }
  }

  // Obtém a contagem atual de abertura do app
  Future<int> getAppOpenCount() async {
    // Se estiver na web, retorne 0
    if (kIsWeb) {
      return 0;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_appOpenCountKey) ?? 0;
    } catch (e) {
      print('Erro ao obter contagem de abertura do app: $e');
      return 0;
    }
  }

  // Verifica se deve mostrar o anúncio nativo (após 3 aberturas)
  Future<bool> shouldShowNativeAd() async {
    // Na web, nunca mostra anúncios
    if (kIsWeb) {
      return false;
    }

    final count = await getAppOpenCount();
    return count >= 3;
  }

  // Salva o timestamp da última exibição do anúncio
  Future<void> saveLastAdShownTime() async {
    // Na web, não faz nada
    if (kIsWeb) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastAdShownTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Erro ao salvar timestamp do último anúncio: $e');
    }
  }

  // Verifica se o anúncio deve ser recarregado (após 1 minuto)
  Future<bool> shouldReloadAd() async {
    // Na web, nunca recarrega anúncios
    if (kIsWeb) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      int? lastShownTime = prefs.getInt(_lastAdShownTimeKey);

      if (lastShownTime == null) {
        return true;
      }

      final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownTime);
      final now = DateTime.now();

      // Recarregar se passou mais de 1 minuto
      return now.difference(lastShown).inMinutes >= 1;
    } catch (e) {
      print('Erro ao verificar necessidade de recarregar anúncio: $e');
      return true;
    }
  }
}
