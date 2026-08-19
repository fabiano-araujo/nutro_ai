import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StreakWidgetPinResult {
  requested,
  alreadyAdded,
  unsupported,
  failed,
}

bool shouldOfferStreakWidgetIntro({
  required int? previousMealAdditionVersion,
  required int mealAdditionVersion,
  required DateTime? lastMealAdditionDate,
  required DateTime now,
  required int localRegistrationStreak,
}) {
  if (previousMealAdditionVersion == null ||
      previousMealAdditionVersion == mealAdditionVersion ||
      lastMealAdditionDate == null ||
      localRegistrationStreak != 1) {
    return false;
  }

  return lastMealAdditionDate.year == now.year &&
      lastMealAdditionDate.month == now.month &&
      lastMealAdditionDate.day == now.day;
}

@immutable
class StreakWidgetSnapshot {
  final int calories;
  final int calorieGoal;
  final int streak;
  final DateTime date;

  const StreakWidgetSnapshot({
    required this.calories,
    required this.calorieGoal,
    required this.streak,
    required this.date,
  });

  Map<String, Object> toPlatformMap() => <String, Object>{
        'calories': calories.clamp(0, 999999),
        'calorieGoal': calorieGoal.clamp(1, 999999),
        'streak': streak.clamp(0, 999999),
        'date': _dateKey(date),
      };

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

/// Ponte leve com o AppWidget nativo do Android.
///
/// O widget não depende de um plugin externo: os dados são gravados pelo
/// MethodChannel e o AppWidgetProvider os lê mesmo quando o Flutter não está
/// em execução.
class StreakWidgetService {
  StreakWidgetService._();

  static const MethodChannel _channel = MethodChannel(
    'br.com.snapdark.apps.nutro_ia/streak_widget',
  );
  static final StreamController<void> _openRequests =
      StreamController<void>.broadcast();
  static bool _initialized = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Stream<void> get openStreakRequests => _openRequests.stream;

  static void initialize() {
    if (_initialized || !_isAndroid) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openStreak') {
        _openRequests.add(null);
      }
    });
  }

  static Future<bool> consumeInitialOpenRequest() async {
    if (!_isAndroid) return false;
    initialize();
    try {
      return await _channel.invokeMethod<bool>('consumeOpenStreak') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> update(StreakWidgetSnapshot snapshot) async {
    if (!_isAndroid) return;
    initialize();
    try {
      await _channel.invokeMethod<void>(
        'updateWidget',
        snapshot.toPlatformMap(),
      );
    } catch (error) {
      debugPrint('[StreakWidgetService] Falha ao atualizar widget: $error');
    }
  }

  static Future<bool> isSupported() async {
    if (!_isAndroid) return false;
    initialize();
    try {
      return await _channel.invokeMethod<bool>('isPinSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAdded() async {
    if (!_isAndroid) return false;
    initialize();
    try {
      return await _channel.invokeMethod<bool>('isWidgetAdded') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<StreakWidgetPinResult> requestPin() async {
    if (!_isAndroid) return StreakWidgetPinResult.unsupported;
    initialize();
    try {
      final result = await _channel.invokeMethod<String>('requestPin');
      return switch (result) {
        'requested' => StreakWidgetPinResult.requested,
        'already_added' => StreakWidgetPinResult.alreadyAdded,
        'unsupported' => StreakWidgetPinResult.unsupported,
        _ => StreakWidgetPinResult.failed,
      };
    } catch (error) {
      debugPrint('[StreakWidgetService] Falha ao solicitar widget: $error');
      return StreakWidgetPinResult.failed;
    }
  }
}

class StreakWidgetIntroStore {
  StreakWidgetIntroStore._();

  static const String _keyPrefix = 'streak_widget_intro_seen_v1';

  static Future<bool> wasSeen(String scope) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('$_keyPrefix:$scope') ?? false;
  }

  static Future<void> markSeen(String scope) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_keyPrefix:$scope', true);
  }
}
