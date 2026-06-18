import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class ProfileShapeGenerationBackgroundTask {
  static const String statusQueued = 'queued';
  static const String statusRunning = 'running';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';
  static const String statusCancelled = 'cancelled';

  final String taskId;
  final String status;
  final String userId;
  final String imageBase64;
  final String languageCode;
  final Map<String, dynamic>? responseData;
  final String? error;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const ProfileShapeGenerationBackgroundTask({
    required this.taskId,
    required this.status,
    required this.userId,
    required this.imageBase64,
    required this.languageCode,
    required this.startedAt,
    required this.updatedAt,
    this.responseData,
    this.error,
    this.completedAt,
  });

  bool get isTerminal =>
      status == statusCompleted ||
      status == statusFailed ||
      status == statusCancelled;

  ProfileShapeGenerationBackgroundTask copyWith({
    String? status,
    Map<String, dynamic>? responseData,
    String? error,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return ProfileShapeGenerationBackgroundTask(
      taskId: taskId,
      status: status ?? this.status,
      userId: userId,
      imageBase64: imageBase64,
      languageCode: languageCode,
      responseData: responseData ?? this.responseData,
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
      'userId': userId,
      'imageBase64': imageBase64,
      'languageCode': languageCode,
      if (responseData != null) 'responseData': responseData,
      if (error != null) 'error': error,
      'startedAt': startedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }

  static ProfileShapeGenerationBackgroundTask? tryFromJson(
    Map<String, dynamic> json,
  ) {
    try {
      final taskId = (json['taskId'] ?? json['jobId'] ?? '').toString().trim();
      final userId = json['userId']?.toString().trim() ?? '';
      final imageBase64 = json['imageBase64']?.toString() ?? '';
      if (taskId.isEmpty || userId.isEmpty || imageBase64.isEmpty) {
        return null;
      }

      final responseData = json['responseData'] is Map
          ? Map<String, dynamic>.from(json['responseData'] as Map)
          : null;

      return ProfileShapeGenerationBackgroundTask(
        taskId: taskId,
        status: json['status']?.toString() ?? statusQueued,
        userId: userId,
        imageBase64: imageBase64,
        languageCode: json['languageCode']?.toString() ?? 'pt-BR',
        responseData: responseData,
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

class ProfileShapeGenerationBackgroundService {
  static const String activeTaskKey = 'active_profile_shape_generation_job';
  static const String _startMethod = 'startProfileShapeGeneration';
  static const String _stopMethod = 'stopProfileShapeGeneration';
  static const String _completedMethod = 'profileShapeGenerationCompleted';
  static const String _failedMethod = 'profileShapeGenerationFailed';
  static const int completionNotificationId = 9062;

  static Future<ProfileShapeGenerationBackgroundTask> startGeneration({
    required String userId,
    required String imageBase64,
    required String languageCode,
  }) async {
    await DietGenerationBackgroundService.initialize();

    final now = DateTime.now();
    final task = ProfileShapeGenerationBackgroundTask(
      taskId: 'shape_${now.microsecondsSinceEpoch}',
      status: ProfileShapeGenerationBackgroundTask.statusQueued,
      userId: userId,
      imageBase64: imageBase64,
      languageCode: languageCode,
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

    await DietGenerationBackgroundService.initialize();
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    service.invoke(_startMethod, task.toJson());
  }

  static Future<ProfileShapeGenerationBackgroundTask?> readActiveTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(activeTaskKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return ProfileShapeGenerationBackgroundTask.tryFromJson(decoded);
    }
    if (decoded is Map) {
      return ProfileShapeGenerationBackgroundTask.tryFromJson(
        Map<String, dynamic>.from(decoded),
      );
    }
    return null;
  }

  static Future<void> saveActiveTask(
    ProfileShapeGenerationBackgroundTask task,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeTaskKey, jsonEncode(task.toJson()));
  }

  static Future<void> clearActiveTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeTaskKey);
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

  http.Client? activeDietClient;
  http.Client? activeProfileShapeClient;
  var dietCancelled = false;
  var profileShapeCancelled = false;
  var dietRunning = false;
  var profileShapeRunning = false;

  Future<void> stopServiceIfIdle() async {
    if (!dietRunning && !profileShapeRunning) {
      await service.stopSelf();
    }
  }

  Future<void> startDietTask(Map<String, dynamic>? data) async {
    if (dietRunning) return;

    final task = data == null
        ? await DietGenerationBackgroundService.readActiveTask()
        : DietGenerationBackgroundTask.tryFromJson(data);
    if (task == null || task.isTerminal) {
      return;
    }

    dietRunning = true;
    dietCancelled = false;
    activeDietClient = http.Client();

    try {
      await _runDietGenerationTask(
        service: service,
        notifications: notifications,
        client: activeDietClient!,
        task: task,
        isCancelled: () => dietCancelled,
      );
    } finally {
      activeDietClient?.close();
      activeDietClient = null;
      dietRunning = false;
      await stopServiceIfIdle();
    }
  }

  Future<void> startProfileShapeTask(Map<String, dynamic>? data) async {
    if (profileShapeRunning) return;

    final task = data == null
        ? await ProfileShapeGenerationBackgroundService.readActiveTask()
        : ProfileShapeGenerationBackgroundTask.tryFromJson(data);
    if (task == null || task.isTerminal) {
      return;
    }

    profileShapeRunning = true;
    profileShapeCancelled = false;
    activeProfileShapeClient = http.Client();

    try {
      await _runProfileShapeGenerationTask(
        service: service,
        notifications: notifications,
        client: activeProfileShapeClient!,
        task: task,
        isCancelled: () => profileShapeCancelled,
      );
    } finally {
      activeProfileShapeClient?.close();
      activeProfileShapeClient = null;
      profileShapeRunning = false;
      await stopServiceIfIdle();
    }
  }

  service.on('startDietGeneration').listen((data) {
    unawaited(startDietTask(data));
  });
  service.on('stopDietGeneration').listen((_) {
    unawaited(() async {
      dietCancelled = true;
      activeDietClient?.close();
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
      await stopServiceIfIdle();
    }());
  });
  service.on('startProfileShapeGeneration').listen((data) {
    unawaited(startProfileShapeTask(data));
  });
  service.on('stopProfileShapeGeneration').listen((_) {
    unawaited(() async {
      profileShapeCancelled = true;
      activeProfileShapeClient?.close();
      final currentTask =
          await ProfileShapeGenerationBackgroundService.readActiveTask();
      if (currentTask != null && !currentTask.isTerminal) {
        await ProfileShapeGenerationBackgroundService.saveActiveTask(
          currentTask.copyWith(
            status: ProfileShapeGenerationBackgroundTask.statusCancelled,
            error: 'Geração de shape cancelada',
            completedAt: DateTime.now(),
          ),
        );
      }
      await stopServiceIfIdle();
    }());
  });

  unawaited(startDietTask(null));
  unawaited(startProfileShapeTask(null));
  unawaited(
      Future<void>.delayed(const Duration(seconds: 1), stopServiceIfIdle));
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

Future<void> _runProfileShapeGenerationTask({
  required ServiceInstance service,
  required FlutterLocalNotificationsPlugin notifications,
  required http.Client client,
  required ProfileShapeGenerationBackgroundTask task,
  required bool Function() isCancelled,
}) async {
  final runningTask = task.copyWith(
    status: ProfileShapeGenerationBackgroundTask.statusRunning,
    updatedAt: DateTime.now(),
  );
  await ProfileShapeGenerationBackgroundService.saveActiveTask(runningTask);

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'Nutro AI',
      content: 'Gerando seu shape em segundo plano...',
    );
  }

  try {
    final responseData = await _requestProfileShapeGeneration(
      client: client,
      task: runningTask,
      isCancelled: isCancelled,
    );
    final completedTask = runningTask.copyWith(
      status: ProfileShapeGenerationBackgroundTask.statusCompleted,
      responseData: responseData,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ProfileShapeGenerationBackgroundService.saveActiveTask(completedTask);

    await _showDietGenerationNotification(
      notifications: notifications,
      id: ProfileShapeGenerationBackgroundService.completionNotificationId,
      title: 'Seu shape ficou pronto',
      body: 'Toque para ver sua prévia gerada.',
      payload: {
        'type': 'profile_shape_generation_completed',
        'screen': '/profile-shape',
        'taskId': completedTask.taskId,
      },
    );
    service.invoke(
      'profileShapeGenerationCompleted',
      completedTask.toJson(),
    );
  } catch (e) {
    final failedTask = runningTask.copyWith(
      status: isCancelled()
          ? ProfileShapeGenerationBackgroundTask.statusCancelled
          : ProfileShapeGenerationBackgroundTask.statusFailed,
      error: e.toString(),
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ProfileShapeGenerationBackgroundService.saveActiveTask(failedTask);

    if (!isCancelled()) {
      await _showDietGenerationNotification(
        notifications: notifications,
        id: ProfileShapeGenerationBackgroundService.completionNotificationId,
        title: 'Nao foi possivel gerar seu shape',
        body: 'Abra o app para tentar novamente.',
        payload: {
          'type': 'profile_shape_generation_failed',
          'screen': '/profile-shape',
          'taskId': failedTask.taskId,
        },
      );
      service.invoke('profileShapeGenerationFailed', failedTask.toJson());
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

Future<Map<String, dynamic>> _requestProfileShapeGeneration({
  required http.Client client,
  required ProfileShapeGenerationBackgroundTask task,
  required bool Function() isCancelled,
}) async {
  if (isCancelled()) {
    throw Exception('Geração de shape cancelada');
  }

  const secureStorage = FlutterSecureStorage();
  final token = await secureStorage.read(key: 'auth_token');
  if (token == null || token.isEmpty) {
    throw Exception('Sessão expirada. Faça login novamente.');
  }

  final headers = <String, String>{
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  headers.addAll(await AppIntegrityService.appCheckHeaders());

  final response = await client
      .post(
        Uri.parse('${AppConstants.DIET_API_BASE_URL}/ai/profile-shape-preview'),
        headers: headers,
        body: jsonEncode({
          'imageBase64': task.imageBase64,
          'language': task.languageCode,
        }),
      )
      .timeout(const Duration(minutes: 5));

  if (isCancelled()) {
    throw Exception('Geração de shape cancelada');
  }

  final decoded = response.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body) as Map<String, dynamic>;
  final data = decoded['data'];

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      decoded['success'] != true ||
      data is! Map) {
    throw Exception(
      decoded['message'] ??
          decoded['error'] ??
          'Falha ao gerar prévia no shape',
    );
  }

  return Map<String, dynamic>.from(data);
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
  int id = DietGenerationBackgroundService.completionNotificationId,
  required String title,
  required String body,
  required Map<String, dynamic> payload,
}) async {
  await notifications.show(
    id: id,
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
