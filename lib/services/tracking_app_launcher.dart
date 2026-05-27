import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum TrackingAppLaunchResult {
  openedApp,
  openedStore,
  unsupported,
  failed,
}

class TrackingAppLauncher {
  static const MethodChannel _channel =
      MethodChannel('br.com.snapdark.apps.nutro_ia/tracking_apps');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isAppInstalled(String packageName) async {
    if (!_isAndroid) return false;

    try {
      final installed = await _channel.invokeMethod<bool>(
        'isAppInstalled',
        {'packageName': packageName},
      );
      return installed ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<TrackingAppLaunchResult> openAppOrStore(String packageName) async {
    if (!_isAndroid) {
      return _openPlayStoreWeb(packageName);
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'openAppOrStore',
        {'packageName': packageName},
      );
      return _parseResult(result);
    } on PlatformException {
      return _openPlayStoreWeb(packageName);
    }
  }

  Future<TrackingAppLaunchResult> openHealthConnect() async {
    if (!_isAndroid) {
      return _openPlayStoreWeb('com.google.android.apps.healthdata');
    }

    try {
      final result = await _channel.invokeMethod<String>('openHealthConnect');
      return _parseResult(result);
    } on PlatformException {
      return _openPlayStoreWeb('com.google.android.apps.healthdata');
    }
  }

  Future<HealthConnectStatus> getHealthConnectStatus() async {
    if (!_isAndroid) {
      return const HealthConnectStatus(
        sdkStatus: 'unsupported',
        isAvailable: false,
        hasAllPermissions: false,
        hasAnyPermission: false,
        grantedPermissions: [],
        missingPermissions: [],
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getHealthConnectStatus',
      );
      return HealthConnectStatus.fromMap(result ?? const {});
    } on PlatformException catch (e) {
      return HealthConnectStatus.unavailable(errorMessage: e.message);
    }
  }

  Future<HealthConnectStatus> requestHealthPermissions() async {
    if (!_isAndroid) {
      return const HealthConnectStatus(
        sdkStatus: 'unsupported',
        isAvailable: false,
        hasAllPermissions: false,
        hasAnyPermission: false,
        grantedPermissions: [],
        missingPermissions: [],
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'requestHealthPermissions',
      );
      return HealthConnectStatus.fromMap(result ?? const {});
    } on PlatformException catch (e) {
      return HealthConnectStatus.unavailable(errorMessage: e.message);
    }
  }

  Future<ActivityTrackingSummary> readHealthSummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    if (!_isAndroid) {
      return ActivityTrackingSummary.unsupported(
        start: start,
        end: end,
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readHealthSummary',
        {
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': end.millisecondsSinceEpoch,
        },
      );
      return ActivityTrackingSummary.fromMap(result ?? const {});
    } on PlatformException catch (e) {
      return ActivityTrackingSummary.error(
        start: start,
        end: end,
        errorMessage: e.message,
      );
    }
  }

  TrackingAppLaunchResult _parseResult(String? value) {
    switch (value) {
      case 'opened_app':
        return TrackingAppLaunchResult.openedApp;
      case 'opened_store':
        return TrackingAppLaunchResult.openedStore;
      case 'unsupported':
        return TrackingAppLaunchResult.unsupported;
      default:
        return TrackingAppLaunchResult.failed;
    }
  }

  Future<TrackingAppLaunchResult> _openPlayStoreWeb(String packageName) async {
    final uri = Uri.https(
      'play.google.com',
      '/store/apps/details',
      {'id': packageName},
    );
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    return launched
        ? TrackingAppLaunchResult.openedStore
        : TrackingAppLaunchResult.failed;
  }
}

class HealthConnectStatus {
  final String sdkStatus;
  final bool isAvailable;
  final bool hasAllPermissions;
  final bool hasAnyPermission;
  final List<String> grantedPermissions;
  final List<String> missingPermissions;
  final String? errorMessage;

  const HealthConnectStatus({
    required this.sdkStatus,
    required this.isAvailable,
    required this.hasAllPermissions,
    required this.hasAnyPermission,
    required this.grantedPermissions,
    required this.missingPermissions,
    this.errorMessage,
  });

  factory HealthConnectStatus.fromMap(Map<dynamic, dynamic> map) {
    return HealthConnectStatus(
      sdkStatus: map['sdkStatus']?.toString() ?? 'unknown',
      isAvailable: map['isAvailable'] == true,
      hasAllPermissions: map['hasAllPermissions'] == true,
      hasAnyPermission: map['hasAnyPermission'] == true,
      grantedPermissions: _stringList(map['grantedPermissions']),
      missingPermissions: _stringList(map['missingPermissions']),
      errorMessage: map['errorMessage']?.toString(),
    );
  }

  factory HealthConnectStatus.unavailable({String? errorMessage}) {
    return HealthConnectStatus(
      sdkStatus: 'unavailable',
      isAvailable: false,
      hasAllPermissions: false,
      hasAnyPermission: false,
      grantedPermissions: const [],
      missingPermissions: const [],
      errorMessage: errorMessage,
    );
  }

  bool get needsProviderUpdate => sdkStatus == 'provider_update_required';
  bool get isUnsupported => sdkStatus == 'unsupported';

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const [];
  }
}

class ActivityTrackingSummary {
  final String status;
  final String sdkStatus;
  final bool hasAllPermissions;
  final bool hasAnyPermission;
  final List<String> missingPermissions;
  final DateTime start;
  final DateTime end;
  final DateTime syncedAt;
  final double? activeCalories;
  final double? totalCalories;
  final int? steps;
  final int exerciseCount;
  final int exerciseMinutes;
  final double? weightKg;
  final double? bodyFatPercentage;
  final List<String> dataOrigins;
  final String? errorMessage;

  const ActivityTrackingSummary({
    required this.status,
    required this.sdkStatus,
    required this.hasAllPermissions,
    required this.hasAnyPermission,
    required this.missingPermissions,
    required this.start,
    required this.end,
    required this.syncedAt,
    required this.activeCalories,
    required this.totalCalories,
    required this.steps,
    required this.exerciseCount,
    required this.exerciseMinutes,
    required this.weightKg,
    required this.bodyFatPercentage,
    required this.dataOrigins,
    this.errorMessage,
  });

  factory ActivityTrackingSummary.fromMap(Map<dynamic, dynamic> map) {
    final now = DateTime.now();
    final startMillis = _intValue(map['startMillis']);
    final endMillis = _intValue(map['endMillis']);
    final syncedAtMillis = _intValue(map['syncedAtMillis']);

    return ActivityTrackingSummary(
      status: map['status']?.toString() ?? 'unknown',
      sdkStatus: map['sdkStatus']?.toString() ?? 'unknown',
      hasAllPermissions: map['hasAllPermissions'] == true,
      hasAnyPermission: map['hasAnyPermission'] == true,
      missingPermissions: HealthConnectStatus._stringList(
        map['missingPermissions'],
      ),
      start: startMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(startMillis)
          : DateTime(now.year, now.month, now.day),
      end: endMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(endMillis)
          : DateTime(now.year, now.month, now.day).add(
              const Duration(days: 1),
            ),
      syncedAt: syncedAtMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(syncedAtMillis)
          : now,
      activeCalories: _doubleValue(map['activeCalories']),
      totalCalories: _doubleValue(map['totalCalories']),
      steps: _intValue(map['steps']),
      exerciseCount: _intValue(map['exerciseCount']) ?? 0,
      exerciseMinutes: _intValue(map['exerciseMinutes']) ?? 0,
      weightKg: _doubleValue(map['weightKg']),
      bodyFatPercentage: _doubleValue(map['bodyFatPercentage']),
      dataOrigins: HealthConnectStatus._stringList(map['dataOrigins']),
      errorMessage: map['errorMessage']?.toString(),
    );
  }

  factory ActivityTrackingSummary.unsupported({
    required DateTime start,
    required DateTime end,
  }) {
    return ActivityTrackingSummary(
      status: 'unsupported',
      sdkStatus: 'unsupported',
      hasAllPermissions: false,
      hasAnyPermission: false,
      missingPermissions: const [],
      start: start,
      end: end,
      syncedAt: DateTime.now(),
      activeCalories: null,
      totalCalories: null,
      steps: null,
      exerciseCount: 0,
      exerciseMinutes: 0,
      weightKg: null,
      bodyFatPercentage: null,
      dataOrigins: const [],
    );
  }

  factory ActivityTrackingSummary.error({
    required DateTime start,
    required DateTime end,
    String? errorMessage,
  }) {
    return ActivityTrackingSummary(
      status: 'error',
      sdkStatus: 'unknown',
      hasAllPermissions: false,
      hasAnyPermission: false,
      missingPermissions: const [],
      start: start,
      end: end,
      syncedAt: DateTime.now(),
      activeCalories: null,
      totalCalories: null,
      steps: null,
      exerciseCount: 0,
      exerciseMinutes: 0,
      weightKg: null,
      bodyFatPercentage: null,
      dataOrigins: const [],
      errorMessage: errorMessage,
    );
  }

  int get activeCaloriesRounded => (activeCalories ?? 0).round();
  int get totalCaloriesRounded => (totalCalories ?? 0).round();
  bool get hasActivityData =>
      activeCaloriesRounded > 0 ||
      totalCaloriesRounded > 0 ||
      (steps ?? 0) > 0 ||
      exerciseMinutes > 0 ||
      exerciseCount > 0;
  bool get needsProviderUpdate => sdkStatus == 'provider_update_required';
  bool get isUnavailable =>
      sdkStatus == 'unavailable' ||
      sdkStatus == 'unsupported' ||
      needsProviderUpdate;

  static double? _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
