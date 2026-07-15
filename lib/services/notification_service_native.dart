import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../i18n/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../screens/main_navigation.dart';
import '../screens/social_hub_screen.dart';
import '../util/app_constants.dart';
import 'behavioral_reminder_planner.dart';

/// Handler de mensagens em background - deve ser top-level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[NotificationService] Background message: ${message.messageId}');
  print('[NotificationService] Title: ${message.notification?.title}');
  print('[NotificationService] Body: ${message.notification?.body}');
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.titleKey,
    required this.bodyKey,
    required this.payloadType,
    this.weekday,
  });

  final int id;
  final int hour;
  final int minute;
  final String titleKey;
  final String bodyKey;
  final String payloadType;
  final int? weekday;
}

/// Service para gerenciar notificacoes push e lembretes locais.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _preferencesKey = 'notification_preferences';
  static const String _androidChannelId = 'nutro_ai_reminders';
  static const String _androidChannelName = 'Nutro AI lembretes';
  static const String _androidChannelDescription =
      'Lembretes inteligentes de refeicao, sequencia, peso e dicas.';
  static const String _androidPushChannelId = 'social';
  static const String _androidPushChannelName = 'Nutro AI';
  static const String _androidPushChannelDescription =
      'Notificacoes de social, dieta e atualizacoes do app.';

  static final List<int> _recurringNotificationIds = <int>[
    // IDs legados de lembretes diarios de refeicao. Eles precisam ser
    // cancelados na migracao para o novo plano one-shot.
    for (var index = 0; index < 100; index++) 1000 + index,
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      200 + weekday,
    301,
  ];
  static final List<int> _behavioralNotificationIds = <int>[
    for (var day = 0; day < BehavioralReminderPlanner.defaultHorizonDays; day++)
      for (var slot = 0; slot < BehavioralReminderPlanner.maxMealSlots; slot++)
        BehavioralReminderPlanner.mealReminderBaseId + (day * 10) + slot,
    BehavioralReminderPlanner.comebackReminderId,
    BehavioralReminderPlanner.streakReminderId,
  ];

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final BehavioralReminderPlanner _behavioralPlanner =
      const BehavioralReminderPlanner();

  String? _fcmToken;
  String? _authToken;
  bool _isInitialized = false;
  bool _localNotificationsInitialized = false;
  bool _timeZoneInitialized = false;
  BehavioralReminderContext? _latestBehavioralContext;
  String? _lastBehavioralPlanFingerprint;
  Future<void> _behavioralOperationQueue = Future<void>.value();

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initializeLocalNotifications();

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print(
          '[NotificationService] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _fcmToken = await _messaging.getToken();
        print('[NotificationService] FCM Token: $_fcmToken');

        _messaging.onTokenRefresh.listen(_handleTokenRefresh);
        _setupMessageHandlers();
      } else {
        print('[NotificationService] Notifications not authorized');
      }
    } catch (e) {
      print('[NotificationService] Error initializing FCM: $e');
    }

    try {
      await syncScheduledNotifications();
    } catch (e) {
      print('[NotificationService] Error syncing local reminders: $e');
    }

    _isInitialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    await _initializeTimeZone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      Future.microtask(() => _handleLocalNotificationResponse(launchResponse));
    }

    try {
      await _ensureAndroidNotificationChannels();
    } catch (e) {
      print('[NotificationService] Error creating Android channels: $e');
    }

    _localNotificationsInitialized = true;
  }

  Future<void> _ensureAndroidNotificationChannels() async {
    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation == null) return;

    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.high,
      ),
    );
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidPushChannelId,
        _androidPushChannelName,
        description: _androidPushChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _initializeTimeZone({bool force = false}) async {
    if (_timeZoneInitialized && !force) return;

    tz_data.initializeTimeZones();

    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    } catch (e) {
      print('[NotificationService] Error resolving local timezone: $e');
      if (!_timeZoneInitialized) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    _timeZoneInitialized = true;
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('[NotificationService] Foreground message received');
    print('[NotificationService] Title: ${message.notification?.title}');
    print('[NotificationService] Body: ${message.notification?.body}');
    print('[NotificationService] Data: ${message.data}');

    _showForegroundNotification(message);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null ||
        (notification.title == null && notification.body == null)) {
      return;
    }

    await _initializeLocalNotifications();

    final id = DateTime.now().millisecondsSinceEpoch.remainder(1000000) + 10000;

    await _localNotifications.show(
      id: id,
      title: notification.title,
      body: notification.body,
      notificationDetails: await _notificationDetails(),
      payload: jsonEncode(message.data),
    );
  }

  void _handleInitialMessage(RemoteMessage? message) {
    if (message != null) {
      print('[NotificationService] Initial message: ${message.data}');
      _navigateFromNotification(message.data);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('[NotificationService] Message opened app: ${message.data}');
    _navigateFromNotification(message.data);
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromNotification(data);
    } catch (e) {
      print('[NotificationService] Error parsing local payload: $e');
    }
  }

  void _navigateFromNotification(
    Map<String, dynamic> data, {
    int attempt = 0,
  }) {
    final type = data['type'];
    final screen = data['screen'];

    print('[NotificationService] Navigate to: $screen (type: $type)');

    if (navigationController.tabChangeCallback == null && attempt < 20) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _navigateFromNotification(data, attempt: attempt + 1);
      });
      return;
    }

    if (type == 'friend_request' ||
        type == 'friend_accepted' ||
        type == 'buddy_ping') {
      navigationController.changeTab(2);
      Future.delayed(const Duration(milliseconds: 300), () {
        socialTabController.changeTab(3);
      });
    } else if (type == 'streak_risk' ||
        type == 'meal_reminder' ||
        type == 'missed_meal' ||
        type == 'comeback_reminder') {
      // O diario/assistente e o caminho mais curto para registrar a refeicao.
      navigationController.changeTab(0);
    } else if (type == 'diet_generation_completed' ||
        type == 'diet_generation_failed' ||
        screen == '/diet') {
      navigationController.changeTab(1);
    } else if (type == 'weight_reminder') {
      navigationController.changeTab(3);
    } else if (type == 'personalized_tip') {
      navigationController.changeTab(0);
    }
  }

  void _handleTokenRefresh(String newToken) async {
    print('[NotificationService] Token refreshed');
    _fcmToken = newToken;

    if (_authToken != null) {
      await registerTokenWithBackend(_authToken!);
    }
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<bool> registerTokenWithBackend(String authToken) async {
    if (_fcmToken == null) {
      print('[NotificationService] No FCM token to register');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.API_BASE_URL}/fcm/register'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': _fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );

      if (response.statusCode == 200) {
        print('[NotificationService] Token registered with backend');
        _authToken = authToken;
        return true;
      } else {
        print(
            '[NotificationService] Failed to register token: ${response.statusCode}');
        print('[NotificationService] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[NotificationService] Error registering token: $e');
      return false;
    }
  }

  Future<void> unregisterTokenFromBackend(String authToken) async {
    if (_fcmToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.API_BASE_URL}/fcm/unregister'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': _fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        print('[NotificationService] Token unregistered from backend');
      } else {
        print(
            '[NotificationService] Failed to unregister token: ${response.statusCode}');
      }
    } catch (e) {
      print('[NotificationService] Error unregistering token: $e');
    }

    _authToken = null;
  }

  Future<String?> getToken() async {
    if (_fcmToken == null) {
      _fcmToken = await _messaging.getToken();
    }
    return _fcmToken;
  }

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
    } catch (e) {
      print('[NotificationService] Error loading preferences: $e');
      return NotificationPreferences.defaults;
    }
  }

  Future<NotificationPreferences> setPreference(
    NotificationPreferenceType type,
    bool enabled,
  ) async {
    var canUseLocalNotifications = true;
    try {
      await _initializeLocalNotifications();
    } catch (e) {
      canUseLocalNotifications = false;
      print('[NotificationService] Error preparing local notifications: $e');
    }

    final currentPreferences = await getPreferences();
    if (enabled && canUseLocalNotifications) {
      var allowed = true;
      try {
        allowed = await requestNotificationPermissions();
      } catch (e) {
        print('[NotificationService] Error requesting permission: $e');
      }

      if (!allowed) {
        return currentPreferences.copyWithType(type, false);
      }
    }

    final nextPreferences = currentPreferences.copyWithType(type, enabled);
    await _savePreferences(nextPreferences);
    try {
      await syncScheduledNotifications();
    } catch (e) {
      print('[NotificationService] Error scheduling reminders: $e');
    }
    return nextPreferences;
  }

  Future<NotificationPreferences> setReminderTime(
    NotificationPreferenceType type,
    String reminderTime,
  ) async {
    final nextPreferences =
        (await getPreferences()).copyWithReminderTime(type, reminderTime);
    await _savePreferences(nextPreferences);
    try {
      await syncScheduledNotifications();
    } catch (e) {
      print('[NotificationService] Error rescheduling reminder time: $e');
    }
    return nextPreferences;
  }

  Future<NotificationPreferences> setWeightReminderSettings({
    required String reminderTime,
    required List<int> weekdays,
  }) async {
    final nextPreferences =
        (await getPreferences()).copyWithWeightReminderSettings(
      reminderTime: reminderTime,
      weekdays: weekdays,
    );
    await _savePreferences(nextPreferences);
    try {
      await syncScheduledNotifications();
    } catch (e) {
      print('[NotificationService] Error rescheduling weight reminders: $e');
    }
    return nextPreferences;
  }

  Future<bool> requestNotificationPermissions() async {
    await _initializeLocalNotifications();

    bool allowed = true;

    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      allowed =
          await androidImplementation.requestNotificationsPermission() ?? false;
    }

    final iosImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      allowed = await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final macOSImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    if (macOSImplementation != null) {
      allowed = await macOSImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return allowed;
  }

  Future<void> syncScheduledNotifications() async {
    await _initializeLocalNotifications();
    await _cancelRecurringLocalNotifications();

    final preferences = await getPreferences();
    if (!preferences.mealReminders) {
      await clearBehavioralReminders();
    }

    if (!preferences.hasAnyEnabled || !await _areNotificationsAllowed()) {
      if (preferences.mealReminders) {
        await clearBehavioralReminders();
      }
      return;
    }

    final weightTimeParts =
        _parseTimeParts(preferences.weightReminderTime) ?? const [8, 30];
    final tipTimeParts =
        _parseTimeParts(preferences.personalizedTipTime) ?? const [17, 30];

    final reminders = <_ScheduledReminder>[
      if (preferences.weightReminders)
        for (final weekday in preferences.weightReminderWeekdays)
          _ScheduledReminder(
            id: 200 + weekday,
            weekday: weekday,
            hour: weightTimeParts[0],
            minute: weightTimeParts[1],
            titleKey: 'notification_weight_title',
            bodyKey: 'notification_weight_body',
            payloadType: 'weight_reminder',
          ),
      if (preferences.personalizedTips)
        _ScheduledReminder(
          id: 301,
          hour: tipTimeParts[0],
          minute: tipTimeParts[1],
          titleKey: 'notification_tip_title',
          bodyKey: 'notification_tip_body',
          payloadType: 'personalized_tip',
        ),
    ];

    for (final reminder in reminders) {
      await _scheduleReminder(reminder);
    }

    final behavioralContext = _latestBehavioralContext;
    if (preferences.mealReminders && behavioralContext != null) {
      await syncBehavioralReminders(behavioralContext, force: true);
    }
  }

  Future<void> cancelAllLocalNotifications() async {
    await _initializeLocalNotifications();
    await _cancelRecurringLocalNotifications();
    await clearBehavioralReminders(forgetContext: true);
    await _savePreferences(NotificationPreferences.defaults);
  }

  /// Reconcilia refeicoes esquecidas, retomada e streak com o estado atual.
  /// Todos esses alertas sao one-shot: registrar/editar uma refeicao dispara
  /// um novo plano, cancelando imediatamente os avisos que deixaram de valer.
  Future<void> syncBehavioralReminders(
    BehavioralReminderContext context, {
    bool force = false,
    bool refreshTimeZone = false,
  }) {
    return _enqueueBehavioralOperation(
      () => _syncBehavioralRemindersNow(
        context,
        force: force,
        refreshTimeZone: refreshTimeZone,
      ),
    );
  }

  Future<void> _syncBehavioralRemindersNow(
    BehavioralReminderContext context, {
    required bool force,
    required bool refreshTimeZone,
  }) async {
    await _initializeLocalNotifications();
    if (refreshTimeZone) {
      await _initializeTimeZone(force: true);
    }

    final freshContext = context.copyWith(now: DateTime.now());
    _latestBehavioralContext = freshContext;
    final preferences = await getPreferences();
    if (!preferences.mealReminders || !await _areNotificationsAllowed()) {
      await _cancelBehavioralLocalNotifications();
      _lastBehavioralPlanFingerprint = null;
      return;
    }

    final plan = _behavioralPlanner.plan(freshContext);
    final fingerprint = plan.map((reminder) => reminder.fingerprint).join('\n');
    if (!force && fingerprint == _lastBehavioralPlanFingerprint) {
      return;
    }

    await _cancelBehavioralLocalNotifications();
    for (final reminder in plan) {
      await _scheduleBehavioralReminder(reminder);
    }
    _lastBehavioralPlanFingerprint = fingerprint;
    print(
      '[NotificationService] ${plan.length} behavioral reminder(s) scheduled',
    );
  }

  Future<void> clearBehavioralReminders({bool forgetContext = false}) {
    return _enqueueBehavioralOperation(
      () => _clearBehavioralRemindersNow(forgetContext: forgetContext),
    );
  }

  Future<void> _clearBehavioralRemindersNow({
    required bool forgetContext,
  }) async {
    await _initializeLocalNotifications();
    await _cancelBehavioralLocalNotifications();
    _lastBehavioralPlanFingerprint = null;
    if (forgetContext) {
      _latestBehavioralContext = null;
    }
  }

  Future<void> _enqueueBehavioralOperation(
    Future<void> Function() operation,
  ) {
    final result = _behavioralOperationQueue.then((_) => operation());
    _behavioralOperationQueue = result.catchError(
      (Object error, StackTrace stackTrace) {
        print('[NotificationService] Behavioral operation error: $error');
      },
    );
    return result;
  }

  Future<void> _scheduleReminder(_ScheduledReminder reminder) async {
    final title = await _translate(reminder.titleKey);
    final body = await _translate(reminder.bodyKey);
    final scheduledDate = reminder.weekday == null
        ? _nextDailyTime(reminder.hour, reminder.minute)
        : _nextWeeklyTime(reminder.weekday!, reminder.hour, reminder.minute);

    await _localNotifications.zonedSchedule(
      id: reminder.id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: await _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: reminder.weekday == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
      payload: jsonEncode({
        'type': reminder.payloadType,
        'screen': reminder.payloadType,
      }),
    );
  }

  Future<void> _scheduleBehavioralReminder(
    BehavioralReminder reminder,
  ) async {
    final title = _replaceArguments(
      await _translate(reminder.titleKey),
      reminder.arguments,
    );
    final body = _replaceArguments(
      await _translate(reminder.bodyKey),
      reminder.arguments,
    );
    final value = reminder.scheduledAt;
    final scheduledDate = tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _localNotifications.zonedSchedule(
      id: reminder.id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: await _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'type': reminder.payloadType,
        'screen': '/diary',
        ...reminder.payload,
      }),
    );
  }

  List<int>? _parseTimeParts(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return [hour, minute];
  }

  String _replaceArguments(String text, Map<String, String> arguments) {
    var result = text;
    for (final entry in arguments.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextWeeklyTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + dayOffset,
        hour,
        minute,
      );
      if (scheduledDate.weekday == weekday && scheduledDate.isAfter(now)) {
        return scheduledDate;
      }
    }
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 7,
      hour,
      minute,
    );
  }

  Future<NotificationDetails> _notificationDetails() async {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        icon: 'ic_notification',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<bool> _areNotificationsAllowed() async {
    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? true;
    }

    final iosImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final permissions = await iosImplementation.checkPermissions();
      return permissions?.isEnabled ?? false;
    }

    final macOSImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    if (macOSImplementation != null) {
      final permissions = await macOSImplementation.checkPermissions();
      return permissions?.isEnabled ?? false;
    }

    return true;
  }

  Future<void> _cancelRecurringLocalNotifications() async {
    for (final id in _recurringNotificationIds) {
      await _localNotifications.cancel(id: id);
    }
  }

  Future<void> _cancelBehavioralLocalNotifications() async {
    for (final id in _behavioralNotificationIds) {
      await _localNotifications.cancel(id: id);
    }
  }

  Future<void> _savePreferences(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, jsonEncode(preferences.toJson()));
  }

  Future<String> _translate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode') ?? 'pt';
    final countryCode = prefs.getString('countryCode') ?? 'BR';
    return AppLocalizations(Locale(languageCode, countryCode)).translate(key);
  }
}
