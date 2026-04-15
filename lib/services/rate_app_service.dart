import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/rate_app_bottom_sheet.dart';

class RateAppService {
  // Chaves para SharedPreferences
  static const String _keyLastPromptDate = 'last_rate_prompt_date';
  static const String _keyPromptCount = 'rate_prompt_count';
  static const String _keySessionCount = 'app_session_count';
  static const String _keyMessageCount = 'ai_tutor_message_count';
  static const String _keyLastInAppReviewRequestDate =
      'last_in_app_review_request_date';

  // Limites para mostrar o diálogo
  static const int _minSessionsBeforePrompt = 5;
  static const int _minDaysBetweenPrompts = 10;
  static const int _maxPromptCount = 3;
  static const int _minMessagesBeforePrompt = 10;
  static const Duration _inAppReviewCooldown = Duration(days: 30);

  static final InAppReview _inAppReview = InAppReview.instance;

  // Incrementa o contador de sessões e verifica se deve mostrar o diálogo
  static Future<bool> incrementSessionAndCheckIfShouldPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    int sessionCount = prefs.getInt(_keySessionCount) ?? 0;
    sessionCount++;
    await prefs.setInt(_keySessionCount, sessionCount);

    if (sessionCount < _minSessionsBeforePrompt) {
      return false;
    }

    final promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    if (promptCount >= _maxPromptCount) {
      return false;
    }

    final lastPromptDateStr = prefs.getString(_keyLastPromptDate);
    if (lastPromptDateStr != null) {
      final lastPromptDate = DateTime.tryParse(lastPromptDateStr);
      if (lastPromptDate != null) {
        final daysDifference = DateTime.now().difference(lastPromptDate).inDays;
        if (daysDifference < _minDaysBetweenPrompts) {
          return false;
        }
      }
    }

    return true;
  }

  // Marcar que o usuário foi solicitado a avaliar
  static Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    int promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    promptCount++;

    await prefs.setInt(_keyPromptCount, promptCount);
    await prefs.setString(_keyLastPromptDate, DateTime.now().toIso8601String());
  }

  static Future<void> _markInAppReviewRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyLastInAppReviewRequestDate,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> _shouldOpenStoreListingDirectly() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRequestDateStr = prefs.getString(_keyLastInAppReviewRequestDate);

    if (lastRequestDateStr == null) {
      return false;
    }

    final lastRequestDate = DateTime.tryParse(lastRequestDateStr);
    if (lastRequestDate == null) {
      return false;
    }

    return DateTime.now().difference(lastRequestDate) < _inAppReviewCooldown;
  }

  static Future<void> launchReviewFlow() async {
    try {
      if (await _shouldOpenStoreListingDirectly()) {
        await _openStoreListing();
        return;
      }

      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await _markInAppReviewRequested();
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('RateAppService.launchReviewFlow error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _openStoreListing();
  }

  static Future<void> _openStoreListing() async {
    try {
      await _inAppReview.openStoreListing();
    } catch (e, stackTrace) {
      debugPrint('RateAppService._openStoreListing error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Mostrar o diálogo de avaliação
  static Future<void> promptForRating(BuildContext context) async {
    if (!context.mounted) {
      return;
    }

    if (await incrementSessionAndCheckIfShouldPrompt() && context.mounted) {
      await markPrompted();
      await RateAppBottomSheet.show(context);
    }
  }

  // Mostrar o diálogo de avaliação após uma ação positiva
  static Future<void> promptAfterPositiveAction(BuildContext context) async {
    if (!context.mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final promptCount = prefs.getInt(_keyPromptCount) ?? 0;

    if (promptCount >= _maxPromptCount) {
      return;
    }

    final lastPromptDateStr = prefs.getString(_keyLastPromptDate);
    if (lastPromptDateStr != null) {
      final lastPromptDate = DateTime.tryParse(lastPromptDateStr);
      if (lastPromptDate != null) {
        final hoursDifference =
            DateTime.now().difference(lastPromptDate).inHours;
        if (hoursDifference < 24) {
          return;
        }
      }
    }

    if (!context.mounted) {
      return;
    }

    await markPrompted();
    await RateAppBottomSheet.show(context);
  }

  // Incrementa o contador de mensagens e verifica se deve mostrar o diálogo
  static Future<bool> incrementMessageAndCheckIfShouldPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    int messageCount = prefs.getInt(_keyMessageCount) ?? 0;
    messageCount++;
    await prefs.setInt(_keyMessageCount, messageCount);

    if (messageCount < _minMessagesBeforePrompt) {
      return false;
    }

    final promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    if (promptCount >= _maxPromptCount) {
      return false;
    }

    final lastPromptDateStr = prefs.getString(_keyLastPromptDate);
    if (lastPromptDateStr != null) {
      final lastPromptDate = DateTime.tryParse(lastPromptDateStr);
      if (lastPromptDate != null) {
        final daysDifference = DateTime.now().difference(lastPromptDate).inDays;
        if (daysDifference < _minDaysBetweenPrompts) {
          return false;
        }
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
    if (!context.mounted) {
      return;
    }

    if (await incrementMessageAndCheckIfShouldPrompt() && context.mounted) {
      await markPrompted();
      await resetMessageCount();
      await RateAppBottomSheet.show(context);
    }
  }
}
