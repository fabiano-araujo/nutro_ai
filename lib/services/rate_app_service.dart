import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/rate_app_bottom_sheet.dart';

class RateAppService {
  // Chaves para SharedPreferences
  static const String _keyLastPromptDate = 'last_rate_prompt_date';
  static const String _keyPromptCount = 'rate_prompt_count';
  static const String _keyHasRated = 'has_rated_app';
  static const String _keySessionCount = 'app_session_count';
  static const String _keyMessageCount = 'ai_tutor_message_count';

  // Limites para mostrar o diu00e1logo
  static const int _minSessionsBeforePrompt =
      5; // Mu00ednimo de sessu00f5es antes de pedir avaliau00e7u00e3o
  static const int _minDaysBetweenPrompts =
      10; // Mu00ednimo de dias entre pedidos
  static const int _maxPromptCount =
      3; // Nu00famero mu00e1ximo de vezes para pedir avaliau00e7u00e3o
  static const int _minMessagesBeforePrompt =
      10; // Mínimo de mensagens antes de pedir avaliação

  // Incrementa o contador de sessu00f5es e verifica se deve mostrar o diu00e1logo
  static Future<bool> incrementSessionAndCheckIfShouldPrompt() async {
    if (await _hasUserRated()) {
      return false; // Usuu00e1rio ju00e1 avaliou, nu00e3o mostrar novamente
    }

    final prefs = await SharedPreferences.getInstance();
    int sessionCount = prefs.getInt(_keySessionCount) ?? 0;
    sessionCount++;
    await prefs.setInt(_keySessionCount, sessionCount);

    // Verificar se ju00e1 atingiu o nu00famero mu00ednimo de sessu00f5es
    if (sessionCount < _minSessionsBeforePrompt) {
      return false;
    }

    // Verificar se ju00e1 atingiu o nu00famero mu00e1ximo de pedidos
    int promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    if (promptCount >= _maxPromptCount) {
      return false;
    }

    // Verificar se passou tempo suficiente desde o u00faltimo pedido
    String? lastPromptDateStr = prefs.getString(_keyLastPromptDate);
    if (lastPromptDateStr != null) {
      DateTime lastPromptDate = DateTime.parse(lastPromptDateStr);
      DateTime now = DateTime.now();
      int daysDifference = now.difference(lastPromptDate).inDays;

      if (daysDifference < _minDaysBetweenPrompts) {
        return false;
      }
    }

    return true;
  }

  // Marcar que o usuu00e1rio foi solicitado a avaliar
  static Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    int promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    promptCount++;

    await prefs.setInt(_keyPromptCount, promptCount);
    await prefs.setString(_keyLastPromptDate, DateTime.now().toIso8601String());
  }

  // Marcar que o usuu00e1rio avaliou o app
  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
  }

  // Verificar se o usuu00e1rio ju00e1 avaliou o app
  static Future<bool> _hasUserRated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasRated) ?? false;
  }

  // Mostrar o diu00e1logo de avaliau00e7u00e3o
  static Future<void> promptForRating(BuildContext context) async {
    if (await incrementSessionAndCheckIfShouldPrompt()) {
      await markPrompted();
      await RateAppBottomSheet.show(context);
    }
  }

  // Mostrar o diu00e1logo de avaliau00e7u00e3o apu00f3s uma au00e7u00e3o positiva (como resolver um problema)
  static Future<void> promptAfterPositiveAction(BuildContext context) async {
    if (await _hasUserRated()) {
      return; // Usuu00e1rio ju00e1 avaliou, nu00e3o mostrar novamente
    }

    final prefs = await SharedPreferences.getInstance();
    int promptCount = prefs.getInt(_keyPromptCount) ?? 0;

    // Limitar o nu00famero de vezes que pedimos, mesmo apu00f3s au00e7u00f5es positivas
    if (promptCount >= _maxPromptCount) {
      return;
    }

    // Verificar se passou pelo menos 1 dia desde o u00faltimo pedido
    String? lastPromptDateStr = prefs.getString(_keyLastPromptDate);
    if (lastPromptDateStr != null) {
      DateTime lastPromptDate = DateTime.parse(lastPromptDateStr);
      DateTime now = DateTime.now();
      int hoursDifference = now.difference(lastPromptDate).inHours;

      if (hoursDifference < 24) {
        // Pelo menos 1 dia entre pedidos apu00f3s au00e7u00f5es positivas
        return;
      }
    }

    await markPrompted();
    await RateAppBottomSheet.show(context);
  }

  // Incrementa o contador de mensagens e verifica se deve mostrar o diálogo
  static Future<bool> incrementMessageAndCheckIfShouldPrompt() async {
    if (await _hasUserRated()) {
      return false; // Usuário já avaliou, não mostrar novamente
    }

    final prefs = await SharedPreferences.getInstance();
    int messageCount = prefs.getInt(_keyMessageCount) ?? 0;
    messageCount++;
    await prefs.setInt(_keyMessageCount, messageCount);

    // Verificar se já atingiu o número mínimo de mensagens
    if (messageCount < _minMessagesBeforePrompt) {
      return false;
    }

    // Verificar se já atingiu o número máximo de pedidos
    int promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    if (promptCount >= _maxPromptCount) {
      return false;
    }

    // Verificar se passou tempo suficiente desde o último pedido
    String? lastPromptDateStr = prefs.getString(_keyLastPromptDate);
    if (lastPromptDateStr != null) {
      DateTime lastPromptDate = DateTime.parse(lastPromptDateStr);
      DateTime now = DateTime.now();
      int daysDifference = now.difference(lastPromptDate).inDays;

      if (daysDifference < _minDaysBetweenPrompts) {
        return false;
      }
    }

    return true;
  }

  // Resetar contador de mensagens após mostrar o rate_app
  static Future<void> resetMessageCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMessageCount, 0);
  }

  // Mostrar o diálogo de avaliação baseado em mensagens
  static Future<void> promptForRatingByMessage(BuildContext context) async {
    if (await incrementMessageAndCheckIfShouldPrompt()) {
      await markPrompted();
      await resetMessageCount();
      await RateAppBottomSheet.show(context);
    }
  }
}
