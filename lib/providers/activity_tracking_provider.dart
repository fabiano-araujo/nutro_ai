import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/manual_activity.dart';
import '../services/tracking_app_launcher.dart';

class ActivityTrackingProvider extends ChangeNotifier {
  final TrackingAppLauncher _launcher;

  ActivityTrackingProvider({TrackingAppLauncher? launcher})
      : _launcher = launcher ?? TrackingAppLauncher();

  ActivityTrackingSummary? _summary;
  HealthConnectStatus? _healthStatus;
  bool _isLoading = false;
  bool _isRequestingPermissions = false;
  String? _errorMessage;
  String? _loadedDateKey;
  DateTime? _lastLoadedAt;
  final List<ManualActivityEntry> _manualActivities = [];
  final List<CustomActivityDefinition> _customActivities = [];
  bool _manualDataLoaded = false;

  static const _cacheDuration = Duration(minutes: 5);
  static const _manualActivitiesKey = 'manual_activity_entries';
  static const _customActivitiesKey = 'custom_activity_definitions';

  ActivityTrackingSummary? get summary => _summary;
  HealthConnectStatus? get healthStatus => _healthStatus;
  bool get hasLoadedStatus => _healthStatus != null;
  bool get isLoading => _isLoading;
  bool get isRequestingPermissions => _isRequestingPermissions;
  String? get errorMessage => _errorMessage;

  int get caloriesBurned => (_summary?.activeCalories ?? 0).round();
  int get steps => _summary?.steps ?? 0;
  int get exerciseMinutes => _summary?.exerciseMinutes ?? 0;
  int get exerciseCount => _summary?.exerciseCount ?? 0;
  bool get hasActivityData => _summary?.hasActivityData ?? false;
  bool get hasAllPermissions =>
      _healthStatus?.hasAllPermissions ?? _summary?.hasAllPermissions ?? false;
  bool get hasAnyPermission =>
      _healthStatus?.hasAnyPermission ?? _summary?.hasAnyPermission ?? false;
  bool get isHealthConnectAvailable =>
      _healthStatus?.isAvailable ?? !(_summary?.isUnavailable ?? false);
  bool get needsProviderUpdate =>
      _healthStatus?.needsProviderUpdate ??
      _summary?.needsProviderUpdate ??
      false;
  bool get isHealthConnectUnsupported =>
      _healthStatus?.isUnsupported ?? _summary?.isUnsupported ?? false;
  bool get canReadCalories =>
      _hasGrantedPermission('READ_ACTIVE_CALORIES_BURNED') ||
      _hasGrantedPermission('READ_TOTAL_CALORIES_BURNED');
  bool get canReadSteps => _hasGrantedPermission('READ_STEPS');
  bool get canReadExercise => _hasGrantedPermission('READ_EXERCISE');
  bool get hasCaloriesData => _summary?.activeCalories != null;
  List<ManualActivityEntry> get manualActivities =>
      List.unmodifiable(_manualActivities);
  List<CustomActivityDefinition> get customActivities =>
      List.unmodifiable(_customActivities);
  int get manualCaloriesBurned => _manualActivitiesForLoadedDate.fold(
        0,
        (total, activity) => total + activity.caloriesBurned,
      );
  int get manualExerciseMinutes => _manualActivitiesForLoadedDate.fold(
        0,
        (total, activity) => total + activity.durationMinutes,
      );
  int get manualExerciseCount => _manualActivitiesForLoadedDate.length;
  int get totalCaloriesBurned => caloriesBurned + manualCaloriesBurned;
  int get totalExerciseMinutes => exerciseMinutes + manualExerciseMinutes;
  int get totalExerciseCount => exerciseCount + manualExerciseCount;
  bool get hasCombinedActivityData =>
      hasActivityData || _manualActivitiesForLoadedDate.isNotEmpty;

  List<ManualActivityEntry> get recentManualActivities {
    final sorted = [..._manualActivities]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final seen = <String>{};
    return sorted
        .where((activity) => seen.add(activity.activityId))
        .take(20)
        .toList(growable: false);
  }

  Future<void> refreshStatus() async {
    _healthStatus = await _launcher.getHealthConnectStatus();
    _errorMessage = _healthStatus?.errorMessage;
    notifyListeners();
  }

  Future<void> loadForDate(DateTime date, {bool force = false}) async {
    final manualWasLoaded = _manualDataLoaded;
    await _ensureManualDataLoaded();
    final dateKey = _dateKey(date);
    final cacheIsFresh = _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < _cacheDuration;
    if (!force &&
        cacheIsFresh &&
        _loadedDateKey == dateKey &&
        _summary != null) {
      if (!manualWasLoaded) notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _healthStatus = await _launcher.getHealthConnectStatus();
      if (_healthStatus?.hasAnyPermission ?? false) {
        _summary = await _launcher.readHealthSummary(date);
        _lastLoadedAt = DateTime.now();
      } else {
        _summary = null;
        _lastLoadedAt = null;
      }
      _loadedDateKey = dateKey;
      _errorMessage = _summary?.errorMessage ?? _healthStatus?.errorMessage;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<HealthConnectStatus> requestPermissionsAndLoad(DateTime date) async {
    await _ensureManualDataLoaded();
    _isRequestingPermissions = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _healthStatus = await _launcher.requestHealthPermissions();
      if (_healthStatus?.hasAnyPermission ?? false) {
        _summary = await _launcher.readHealthSummary(date);
        _loadedDateKey = _dateKey(date);
        _lastLoadedAt = DateTime.now();
      } else {
        _summary = null;
        _lastLoadedAt = null;
      }
      _errorMessage = _summary?.errorMessage ?? _healthStatus?.errorMessage;
      return _healthStatus!;
    } catch (e) {
      _errorMessage = e.toString();
      _healthStatus =
          HealthConnectStatus.unavailable(errorMessage: _errorMessage);
      return _healthStatus!;
    } finally {
      _isRequestingPermissions = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TrackingAppLaunchResult> openHealthConnect() {
    return _launcher.openHealthConnect();
  }

  Future<bool> isTrackingAppInstalled(String packageName) {
    return _launcher.isAppInstalled(packageName);
  }

  Future<TrackingAppLaunchResult> openTrackingApp(String packageName) {
    return _launcher.openAppOrStore(packageName);
  }

  Future<TrackingAppLaunchResult> openTrackingAppOfficialStore(String url) {
    return _launcher.openOfficialStore(url);
  }

  Future<void> loadManualActivities() async {
    if (_manualDataLoaded) return;
    await _ensureManualDataLoaded();
    notifyListeners();
  }

  List<ManualActivityEntry> manualActivitiesForDate(DateTime date) {
    final dateKey = _dateKey(date);
    final activities = _manualActivities
        .where((activity) => _dateKey(activity.date) == dateKey)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return activities;
  }

  Future<ManualActivityEntry> addManualActivity({
    required String activityId,
    required String activityName,
    required DateTime date,
    required int durationMinutes,
    required int caloriesBurned,
  }) async {
    await _ensureManualDataLoaded();
    final now = DateTime.now();
    final entry = ManualActivityEntry(
      id: 'manual_${now.microsecondsSinceEpoch}',
      activityId: activityId,
      activityName: activityName.trim(),
      date: DateTime(date.year, date.month, date.day),
      durationMinutes: durationMinutes.clamp(1, 1440),
      caloriesBurned: caloriesBurned.clamp(0, 100000),
      createdAt: now,
    );
    _manualActivities.add(entry);
    _loadedDateKey = _dateKey(date);
    await _saveManualActivities();
    notifyListeners();
    return entry;
  }

  Future<void> removeManualActivity(String entryId) async {
    await _ensureManualDataLoaded();
    final previousLength = _manualActivities.length;
    _manualActivities.removeWhere((activity) => activity.id == entryId);
    if (_manualActivities.length == previousLength) return;
    await _saveManualActivities();
    notifyListeners();
  }

  Future<CustomActivityDefinition> addCustomActivity({
    required String name,
    required double met,
  }) async {
    await _ensureManualDataLoaded();
    final now = DateTime.now();
    final definition = CustomActivityDefinition(
      id: 'custom_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      met: met.clamp(1, 20),
      createdAt: now,
    );
    _customActivities.add(definition);
    await _saveCustomActivities();
    notifyListeners();
    return definition;
  }

  Future<void> removeCustomActivity(String activityId) async {
    await _ensureManualDataLoaded();
    final previousLength = _customActivities.length;
    _customActivities.removeWhere((activity) => activity.id == activityId);
    if (_customActivities.length == previousLength) return;
    await _saveCustomActivities();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _summary = null;
    _healthStatus = null;
    _loadedDateKey = null;
    _lastLoadedAt = null;
    _manualActivities.clear();
    _customActivities.clear();
    _manualDataLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_manualActivitiesKey),
      prefs.remove(_customActivitiesKey),
    ]);
    notifyListeners();
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _hasGrantedPermission(String permissionName) {
    final grantedPermissions = _healthStatus?.grantedPermissions;
    if (grantedPermissions == null) return hasAllPermissions;
    return grantedPermissions.any(
      (permission) => permission.endsWith(permissionName),
    );
  }

  List<ManualActivityEntry> get _manualActivitiesForLoadedDate {
    final loadedDateKey = _loadedDateKey;
    if (loadedDateKey == null) return const [];
    return _manualActivities
        .where((activity) => _dateKey(activity.date) == loadedDateKey)
        .toList(growable: false);
  }

  Future<void> _ensureManualDataLoaded() async {
    if (_manualDataLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _manualActivities
      ..clear()
      ..addAll(
        _decodeList(prefs.getString(_manualActivitiesKey))
            .map(ManualActivityEntry.fromJson)
            .where(
                (entry) => entry.id.isNotEmpty && entry.activityId.isNotEmpty),
      );
    _customActivities
      ..clear()
      ..addAll(
        _decodeList(prefs.getString(_customActivitiesKey))
            .map(CustomActivityDefinition.fromJson)
            .where((definition) =>
                definition.id.isNotEmpty && definition.name.isNotEmpty),
      );
    _manualDataLoaded = true;
  }

  List<Map<String, dynamic>> _decodeList(String? source) {
    if (source == null || source.isEmpty) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveManualActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _manualActivitiesKey,
      jsonEncode(_manualActivities.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _saveCustomActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customActivitiesKey,
      jsonEncode(_customActivities.map((entry) => entry.toJson()).toList()),
    );
  }
}
