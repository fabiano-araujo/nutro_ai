import 'package:flutter/foundation.dart';

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

  ActivityTrackingSummary? get summary => _summary;
  HealthConnectStatus? get healthStatus => _healthStatus;
  bool get isLoading => _isLoading;
  bool get isRequestingPermissions => _isRequestingPermissions;
  String? get errorMessage => _errorMessage;

  int get activeCalories => _summary?.activeCaloriesRounded ?? 0;
  int get totalCalories => _summary?.totalCaloriesRounded ?? 0;
  int get steps => _summary?.steps ?? 0;
  int get exerciseMinutes => _summary?.exerciseMinutes ?? 0;
  int get exerciseCount => _summary?.exerciseCount ?? 0;
  double? get weightKg => _summary?.weightKg;
  double? get bodyFatPercentage => _summary?.bodyFatPercentage;
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

  Future<void> refreshStatus() async {
    _healthStatus = await _launcher.getHealthConnectStatus();
    _errorMessage = _healthStatus?.errorMessage;
    notifyListeners();
  }

  Future<void> loadForDate(DateTime date, {bool force = false}) async {
    final dateKey = _dateKey(date);
    if (!force && _loadedDateKey == dateKey && _summary != null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _healthStatus = await _launcher.getHealthConnectStatus();
      _summary = await _launcher.readHealthSummary(date);
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
    _isRequestingPermissions = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _healthStatus = await _launcher.requestHealthPermissions();
      if (_healthStatus?.isAvailable ?? false) {
        _summary = await _launcher.readHealthSummary(date);
        _loadedDateKey = _dateKey(date);
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

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
