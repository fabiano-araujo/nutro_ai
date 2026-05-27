import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_preferences.dart';

Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const String _preferencesKey = 'notification_preferences';

  factory NotificationService() => _instance;

  NotificationService._internal();

  String? get fcmToken => null;
  bool get isInitialized => false;

  Future<void> initialize() async {}

  void setAuthToken(String? token) {}

  Future<bool> registerTokenWithBackend(String authToken) async => false;

  Future<void> unregisterTokenFromBackend(String authToken) async {}

  Future<String?> getToken() async => null;

  Future<NotificationPreferences> getPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawPreferences = prefs.getString(_preferencesKey);
      if (rawPreferences == null) {
        return NotificationPreferences.defaults;
      }

      return NotificationPreferences.fromJson(
        jsonDecode(rawPreferences) as Map<String, dynamic>,
      );
    } catch (_) {
      return NotificationPreferences.defaults;
    }
  }

  Future<NotificationPreferences> setPreference(
    NotificationPreferenceType type,
    bool enabled,
  ) async {
    final preferences = (await getPreferences()).copyWithType(type, enabled);
    await _savePreferences(preferences);
    return preferences;
  }

  Future<NotificationPreferences> setReminderTime(
    NotificationPreferenceType type,
    String reminderTime,
  ) async {
    final preferences =
        (await getPreferences()).copyWithReminderTime(type, reminderTime);
    await _savePreferences(preferences);
    return preferences;
  }

  Future<NotificationPreferences> setWeightReminderSettings({
    required String reminderTime,
    required List<int> weekdays,
  }) async {
    final preferences = (await getPreferences()).copyWithWeightReminderSettings(
      reminderTime: reminderTime,
      weekdays: weekdays,
    );
    await _savePreferences(preferences);
    return preferences;
  }

  Future<bool> requestNotificationPermissions() async => false;

  Future<void> syncScheduledNotifications() async {}

  Future<void> cancelAllLocalNotifications() async {}

  Future<void> _savePreferences(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, jsonEncode(preferences.toJson()));
  }
}
