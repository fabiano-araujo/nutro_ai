import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../util/app_constants.dart';
import 'app_integrity_service.dart';

class DietGenerationBackgroundTask {
  static const String statusQueued = 'queued';
  static const String statusRunning = 'running';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';
  static const String statusCancelled = 'cancelled';

  final String taskId;
  final String status;
  final String prompt;
  final String date;
  final String dateKey;
  final String userId;
  final String languageCode;
  final String modelId;
  final Map<String, dynamic> targetNutrition;
  final List<Map<String, dynamic>> mealTypes;
  final String? responseText;
  final String? error;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const DietGenerationBackgroundTask({
    required this.taskId,
    required this.status,
    required this.prompt,
    required this.date,
    required this.dateKey,
    required this.userId,
    required this.languageCode,
    required this.modelId,
    required this.targetNutrition,
    required this.mealTypes,
    required this.startedAt,
    required this.updatedAt,
    this.responseText,
    this.error,
    this.completedAt,
  });

  String get jobId => taskId;

  bool get isTerminal =>
      status == statusCompleted ||
      status == statusFailed ||
      status == statusCancelled;

  DietGenerationBackgroundTask copyWith({
    String? status,
    String? responseText,
    String? error,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return DietGenerationBackgroundTask(
      taskId: taskId,
      status: status ?? this.status,
      prompt: prompt,
      date: date,
      dateKey: dateKey,
      userId: userId,
      languageCode: languageCode,
      modelId: modelId,
      targetNutrition: targetNutrition,
      mealTypes: mealTypes,
      responseText: responseText ?? this.responseText,
      error: error ?? this.error,
      startedAt: startedAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'status': status,
      'prompt': prompt,
      'date': date,
      'dateKey': dateKey,
      'userId': userId,
      'languageCode': languageCode,
      'modelId': modelId,
      'targetNutrition': targetNutrition,
      'mealTypes': mealTypes,
      if (responseText != null) 'responseText': responseText,
      if (error != null) 'error': error,
      'startedAt': startedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }

  static DietGenerationBackgroundTask? tryFromJson(
    Map<String, dynamic> json,
  ) {
    try {
      final taskId = (json['taskId'] ?? json['jobId'] ?? '').toString().trim();
      final prompt = json['prompt']?.toString() ?? '';
      final date = json['date']?.toString() ?? '';
      final dateKey = json['dateKey']?.toString() ?? '';
      final userId = json['userId']?.toString() ?? '';
      if (taskId.isEmpty ||
          prompt.isEmpty ||
          date.isEmpty ||
          dateKey.isEmpty ||
          userId.isEmpty) {
        return null;
      }

      final targetNutrition = json['targetNutrition'] is Map
          ? Map<String, dynamic>.from(json['targetNutrition'] as Map)
          : <String, dynamic>{};
      final rawMealTypes = json['mealTypes'];
      final mealTypes = rawMealTypes is List
          ? rawMealTypes
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      return DietGenerationBackgroundTask(
        taskId: taskId,
        status: json['status']?.toString() ?? statusQueued,
        prompt: prompt,
        date: date,
        dateKey: dateKey,
        userId: userId,
        languageCode: json['languageCode']?.toString() ?? 'pt_BR',
        modelId: json['modelId']?.toString() ?? 'google/gemini-3-flash-preview',
        targetNutrition: targetNutrition,
        mealTypes: mealTypes,
        responseText: json['responseText']?.toString(),
        error: json['error']?.toString(),
        startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
        completedAt: DateTime.tryParse(
          json['completedAt']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

class DietGenerationBackgroundService {
  static const String activeTaskKey = 'active_diet_generation_job';
  static const String _startMethod = 'startDietGeneration';
  static const String _stopMethod = 'stopDietGeneration';
  static const String _completedMethod = 'dietGenerationCompleted';
  static const String _failedMethod = 'dietGenerationFailed';
  static const String notificationChannelId = 'nutro_ai_diet_generation';
  static const String notificationChannelName = 'Geracao de dieta';
  static const String notificationChannelDescription =
      'Servico em primeiro plano para gerar dietas longas.';
  static const int foregroundNotificationId = 9051;
  static const int completionNotificationId = 9052;

  static bool _configured = false;

  static Future<void> initialize() async {
    if (kIsWeb || _configured) return;

    await _createNotificationChannel();

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: dietGenerationBackgroundServiceOnStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Nutro AI',
        initialNotificationContent: 'Preparando geracao de dieta...',
        foregroundServiceNotificationId: foregroundNotificationId,
        foregroundServiceTypes: const [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: dietGenerationBackgroundServiceOnStart,
        onBackground: dietGenerationBackgroundServiceOnIosBackground,
      ),
    );
    _configured = true;
  }

  static Future<DietGenerationBackgroundTask> startGeneration({
    required String prompt,
    required String date,
    required String dateKey,
    required String userId,
    required String languageCode,
    required String modelId,
    required Map<String, dynamic> targetNutrition,
    required List<Map<String, dynamic>> mealTypes,
  }) async {
    await initialize();

    final now = DateTime.now();
    final task = DietGenerationBackgroundTask(
      taskId: 'diet_${now.microsecondsSinceEpoch}',
      status: DietGenerationBackgroundTask.statusQueued,
      prompt: prompt,
      date: date,
      dateKey: dateKey,
      userId: userId,
      languageCode: languageCode,
      modelId: modelId,
      targetNutrition: targetNutrition,
      mealTypes: mealTypes,
      startedAt: now,
      updatedAt: now,
    );

    await saveActiveTask(task);

    if (!kIsWeb) {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
      service.invoke(_startMethod, task.toJson());
    }

    return task;
  }

  static Stream<Map<String, dynamic>?> onCompleted() {
    return FlutterBackgroundService().on(_completedMethod);
  }

  static Stream<Map<String, dynamic>?> onFailed() {
    return FlutterBackgroundService().on(_failedMethod);
  }

  static Future<void> stopActiveGeneration() async {
    if (!kIsWeb) {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke(_stopMethod);
      }
    }
    await clearActiveTask();
  }

  static Future<void> resumeActiveGeneration() async {
    if (kIsWeb) return;

    final task = await readActiveTask();
    if (task == null || task.isTerminal) return;

    await initialize();
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    service.invoke(_startMethod, task.toJson());
  }

  static Future<DietGenerationBackgroundTask?> readActiveTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(activeTaskKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return DietGenerationBackgroundTask.tryFromJson(decoded);
    }
    if (decoded is Map) {
      return DietGenerationBackgroundTask.tryFromJson(
        Map<String, dynamic>.from(decoded),
      );
    }
    return null;
  }

  static Future<void> saveActiveTask(DietGenerationBackgroundTask task) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeTaskKey, jsonEncode(task.toJson()));
  }

  static Future<void> clearActiveTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeTaskKey);
  }

  static Future<void> _createNotificationChannel() async {
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            notificationChannelId,
            notificationChannelName,
            description: notificationChannelDescription,
            importance: Importance.high,
          ),
        );
  }
}

@pragma('vm:entry-point')
Future<bool> dietGenerationBackgroundServiceOnIosBackground(
  ServiceInstance service,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void dietGenerationBackgroundServiceOnStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await AppIntegrityService.activateAppCheck();
  } catch (e) {
    debugPrint('[DietGenerationService] Firebase/AppCheck init error: $e');
  }

  final notifications = FlutterLocalNotificationsPlugin();
  await _initializeDietGenerationNotifications(notifications);

  http.Client? activeClient;
  var cancelled = false;
  var running = false;

  Future<void> startTask(Map<String, dynamic>? data) async {
    if (running) return;

    final task = data == null
        ? await DietGenerationBackgroundService.readActiveTask()
        : DietGenerationBackgroundTask.tryFromJson(data);
    if (task == null || task.isTerminal) {
      await service.stopSelf();
      return;
    }

    running = true;
    cancelled = false;
    activeClient = http.Client();

    try {
      await _runDietGenerationTask(
        service: service,
        notifications: notifications,
        client: activeClient!,
        task: task,
        isCancelled: () => cancelled,
      );
    } finally {
      activeClient?.close();
      activeClient = null;
      running = false;
      await service.stopSelf();
    }
  }

  service.on('startDietGeneration').listen((data) {
    unawaited(startTask(data));
  });
  service.on('stopDietGeneration').listen((_) {
    unawaited(() async {
      cancelled = true;
      activeClient?.close();
      final currentTask =
          await DietGenerationBackgroundService.readActiveTask();
      if (currentTask != null && !currentTask.isTerminal) {
        await DietGenerationBackgroundService.saveActiveTask(
          currentTask.copyWith(
            status: DietGenerationBackgroundTask.statusCancelled,
            error: 'Geração de dieta cancelada',
            completedAt: DateTime.now(),
          ),
        );
      }
      await service.stopSelf();
    }());
  });

  unawaited(startTask(null));
}

Future<void> _runDietGenerationTask({
  required ServiceInstance service,
  required FlutterLocalNotificationsPlugin notifications,
  required http.Client client,
  required DietGenerationBackgroundTask task,
  required bool Function() isCancelled,
}) async {
  final runningTask = task.copyWith(
    status: DietGenerationBackgroundTask.statusRunning,
    updatedAt: DateTime.now(),
  );
  await DietGenerationBackgroundService.saveActiveTask(runningTask);

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'Nutro AI',
      content: 'Gerando sua dieta em segundo plano...',
    );
  }

  try {
    final responseText = await _requestDietGeneration(
      client: client,
      task: runningTask,
      isCancelled: isCancelled,
    );
    final completedTask = runningTask.copyWith(
      status: DietGenerationBackgroundTask.statusCompleted,
      responseText: responseText,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await DietGenerationBackgroundService.saveActiveTask(completedTask);

    await _showDietGenerationNotification(
      notifications: notifications,
      title: 'Sua dieta ficou pronta',
      body: 'Toque para ver seu plano alimentar.',
      payload: {
        'type': 'diet_generation_completed',
        'screen': '/diet',
        'taskId': completedTask.taskId,
      },
    );
    service.invoke('dietGenerationCompleted', completedTask.toJson());
  } catch (e) {
    final failedTask = runningTask.copyWith(
      status: isCancelled()
          ? DietGenerationBackgroundTask.statusCancelled
          : DietGenerationBackgroundTask.statusFailed,
      error: e.toString(),
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await DietGenerationBackgroundService.saveActiveTask(failedTask);

    if (!isCancelled()) {
      await _showDietGenerationNotification(
        notifications: notifications,
        title: 'Nao foi possivel gerar sua dieta',
        body: 'Abra o app para tentar novamente.',
        payload: {
          'type': 'diet_generation_failed',
          'screen': '/diet',
          'taskId': failedTask.taskId,
        },
      );
      service.invoke('dietGenerationFailed', failedTask.toJson());
    }
  }
}

Future<String> _requestDietGeneration({
  required http.Client client,
  required DietGenerationBackgroundTask task,
  required bool Function() isCancelled,
}) async {
  final request = http.Request(
    'POST',
    Uri.parse('${AppConstants.API_BASE_URL}/ai/generate-text'),
  );
  request.headers.addAll({
    'Content-Type': 'application/json; charset=utf-8',
  });
  request.headers.addAll(await AppIntegrityService.appCheckHeaders());
  request.bodyBytes = utf8.encode(
    jsonEncode({
      'prompt': task.prompt,
      'temperature': 0.5,
      'model': task.modelId,
      'streaming': true,
      'userId': task.userId,
      'agentType': 'diet',
      'language': task.languageCode,
      'mealTypes': task.mealTypes
          .map((meal) => {
                'id': meal['id']?.toString() ?? '',
                'name': meal['name']?.toString() ?? '',
              })
          .where((meal) => meal['id']!.isNotEmpty && meal['name']!.isNotEmpty)
          .toList(),
    }),
  );

  final response = await client.send(request).timeout(
        const Duration(minutes: 15),
      );
  if (response.statusCode != 200) {
    final body = await response.stream.bytesToString();
    throw Exception(
      'Erro na API: ${response.statusCode}${body.isEmpty ? '' : ' - $body'}',
    );
  }

  final responseBuffer = StringBuffer();
  var lineBuffer = '';

  await for (final chunk in response.stream.transform(utf8.decoder).timeout(
        const Duration(minutes: 15),
      )) {
    if (isCancelled()) {
      throw Exception('Geração de dieta cancelada');
    }

    lineBuffer += chunk;
    while (lineBuffer.contains('\n')) {
      final newlineIndex = lineBuffer.indexOf('\n');
      final line = lineBuffer.substring(0, newlineIndex).trim();
      lineBuffer = lineBuffer.substring(newlineIndex + 1);
      if (line.isEmpty) continue;

      var jsonLine = line;
      if (jsonLine.startsWith('data: ')) {
        jsonLine = jsonLine.substring(6);
      }

      final decoded = jsonDecode(jsonLine);
      if (decoded is Map && decoded['text'] != null) {
        responseBuffer.write(decoded['text']);
      } else if (decoded is Map && decoded['error'] != null) {
        throw Exception(decoded['error'].toString());
      }
    }
  }

  final responseText = responseBuffer.toString();
  if (responseText.trim().isEmpty) {
    throw Exception('A API finalizou sem retornar a dieta');
  }
  return responseText;
}

Future<void> _initializeDietGenerationNotifications(
  FlutterLocalNotificationsPlugin notifications,
) async {
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

  await notifications.initialize(settings: initializationSettings);
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          DietGenerationBackgroundService.notificationChannelId,
          DietGenerationBackgroundService.notificationChannelName,
          description:
              DietGenerationBackgroundService.notificationChannelDescription,
          importance: Importance.high,
        ),
      );
}

Future<void> _showDietGenerationNotification({
  required FlutterLocalNotificationsPlugin notifications,
  required String title,
  required String body,
  required Map<String, dynamic> payload,
}) async {
  await notifications.show(
    id: DietGenerationBackgroundService.completionNotificationId,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        DietGenerationBackgroundService.notificationChannelId,
        DietGenerationBackgroundService.notificationChannelName,
        channelDescription:
            DietGenerationBackgroundService.notificationChannelDescription,
        icon: 'ic_notification',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
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
    ),
    payload: jsonEncode(payload),
  );
}
