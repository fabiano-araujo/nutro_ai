import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/providers/activity_tracking_provider.dart';
import 'package:nutro_ai/services/tracking_app_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ActivityTrackingProvider', () {
    test('does not read health data before any permission is granted',
        () async {
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(hasAnyPermission: false),
        summary: _summary(),
      );
      final provider = ActivityTrackingProvider(launcher: launcher);

      await provider.loadForDate(DateTime(2026, 7, 15));

      expect(provider.hasLoadedStatus, isTrue);
      expect(provider.hasAnyPermission, isFalse);
      expect(provider.summary, isNull);
      expect(launcher.readCount, 0);
    });

    test('uses a short cache and force bypasses it', () async {
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(),
        summary: _summary(steps: 1990),
      );
      final provider = ActivityTrackingProvider(launcher: launcher);
      final date = DateTime(2026, 7, 15);

      await provider.loadForDate(date);
      await provider.loadForDate(date);

      expect(launcher.readCount, 1);

      await provider.loadForDate(date, force: true);

      expect(launcher.readCount, 2);
    });

    test('shares an in-flight forced read for the same date', () async {
      final readStarted = Completer<void>();
      final releaseRead = Completer<void>();
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(),
        summary: _summary(),
        readHandler: (date) async {
          readStarted.complete();
          await releaseRead.future;
          return _summary(date: date);
        },
      );
      final provider = ActivityTrackingProvider(launcher: launcher);
      final date = DateTime(2026, 7, 15);

      final firstLoad = provider.loadForDate(date, force: true);
      await readStarted.future;
      final secondLoad = provider.loadForDate(date, force: true);
      await Future<void>.delayed(Duration.zero);

      expect(launcher.readCount, 1);

      releaseRead.complete();
      await Future.wait([firstLoad, secondLoad]);

      expect(launcher.readCount, 1);
    });

    test('serializes different dates and keeps the latest request', () async {
      final firstReadStarted = Completer<void>();
      final releaseFirstRead = Completer<void>();
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(),
        summary: _summary(),
        readHandler: (date) async {
          if (date.day == 14) {
            firstReadStarted.complete();
            await releaseFirstRead.future;
          }
          return _summary(date: date, steps: date.day);
        },
      );
      final provider = ActivityTrackingProvider(launcher: launcher);

      final olderLoad = provider.loadForDate(
        DateTime(2026, 7, 14),
        force: true,
      );
      await firstReadStarted.future;
      final latestLoad = provider.loadForDate(
        DateTime(2026, 7, 15),
        force: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(launcher.readCount, 1);

      releaseFirstRead.complete();
      await Future.wait([olderLoad, latestLoad]);

      expect(launcher.readCount, 2);
      expect(provider.summary?.start, DateTime(2026, 7, 15));
      expect(provider.steps, 15);
    });

    test('does not expose calories without active-calorie permission',
        () async {
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(
          grantedPermissions: const [
            'android.permission.health.READ_STEPS',
            'android.permission.health.READ_EXERCISE',
          ],
        ),
        summary: _summary(
          activeCalories: null,
          steps: 1990,
        ),
      );
      final provider = ActivityTrackingProvider(launcher: launcher);

      await provider.loadForDate(DateTime(2026, 7, 15));

      expect(provider.canReadCalories, isFalse);
      expect(provider.hasCaloriesData, isFalse);
      expect(provider.caloriesBurned, 0);
      expect(provider.steps, 1990);
    });

    test('uses active calories when available', () async {
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(),
        summary: _summary(activeCalories: 215.6),
      );
      final provider = ActivityTrackingProvider(launcher: launcher);

      await provider.loadForDate(DateTime(2026, 7, 15));

      expect(provider.hasCaloriesData, isTrue);
      expect(provider.caloriesBurned, 216);
    });

    test('permission request loads data only after access is granted',
        () async {
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(hasAnyPermission: false),
        requestStatus: _healthStatus(),
        summary: _summary(steps: 800),
      );
      final provider = ActivityTrackingProvider(launcher: launcher);

      final status = await provider.requestPermissionsAndLoad(
        DateTime(2026, 7, 15),
      );

      expect(status.hasAllPermissions, isTrue);
      expect(launcher.permissionRequestCount, 1);
      expect(launcher.readCount, 1);
      expect(provider.steps, 800);
    });

    test('persists manual activity and combines it with the selected day',
        () async {
      final date = DateTime(2026, 7, 15);
      final launcher = _FakeTrackingAppLauncher(
        status: _healthStatus(hasAnyPermission: false),
        summary: _summary(),
      );
      final provider = ActivityTrackingProvider(launcher: launcher);

      await provider.loadForDate(date);
      await provider.addManualActivity(
        activityId: 'running',
        activityName: 'Corrida',
        date: date,
        durationMinutes: 35,
        caloriesBurned: 320,
      );

      expect(provider.totalCaloriesBurned, 320);
      expect(provider.totalExerciseMinutes, 35);
      expect(provider.hasCombinedActivityData, isTrue);

      final restored = ActivityTrackingProvider(launcher: launcher);
      await restored.loadForDate(date);

      expect(restored.manualActivitiesForDate(date), hasLength(1));
      expect(restored.totalCaloriesBurned, 320);
      expect(restored.recentManualActivities.single.activityId, 'running');
    });

    test('creates and removes custom activity definitions', () async {
      final provider = ActivityTrackingProvider(
        launcher: _FakeTrackingAppLauncher(
          status: _healthStatus(hasAnyPermission: false),
          summary: _summary(),
        ),
      );

      final activity = await provider.addCustomActivity(
        name: 'Treino funcional',
        met: 7,
      );

      expect(provider.customActivities.single.name, 'Treino funcional');

      await provider.removeCustomActivity(activity.id);

      expect(provider.customActivities, isEmpty);
    });
  });
}

class _FakeTrackingAppLauncher extends TrackingAppLauncher {
  _FakeTrackingAppLauncher({
    required this.status,
    required this.summary,
    HealthConnectStatus? requestStatus,
    this.readHandler,
  }) : requestStatus = requestStatus ?? status;

  HealthConnectStatus status;
  HealthConnectStatus requestStatus;
  ActivityTrackingSummary summary;
  final Future<ActivityTrackingSummary> Function(DateTime date)? readHandler;
  int readCount = 0;
  int permissionRequestCount = 0;

  @override
  Future<HealthConnectStatus> getHealthConnectStatus() async => status;

  @override
  Future<HealthConnectStatus> requestHealthPermissions() async {
    permissionRequestCount++;
    status = requestStatus;
    return requestStatus;
  }

  @override
  Future<ActivityTrackingSummary> readHealthSummary(DateTime date) async {
    readCount++;
    final handler = readHandler;
    if (handler != null) return handler(date);
    return summary;
  }
}

HealthConnectStatus _healthStatus({
  bool hasAnyPermission = true,
  List<String>? grantedPermissions,
}) {
  final granted = grantedPermissions ??
      (hasAnyPermission
          ? const [
              'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
              'android.permission.health.READ_STEPS',
              'android.permission.health.READ_EXERCISE',
            ]
          : const <String>[]);

  return HealthConnectStatus(
    sdkStatus: 'available',
    isAvailable: true,
    hasAllPermissions: hasAnyPermission && granted.length == 3,
    hasAnyPermission: hasAnyPermission,
    grantedPermissions: granted,
    missingPermissions: const [],
  );
}

ActivityTrackingSummary _summary({
  DateTime? date,
  double? activeCalories = 120,
  int? steps = 1000,
}) {
  final start = date ?? DateTime(2026, 7, 15);
  return ActivityTrackingSummary(
    status: 'ok',
    sdkStatus: 'available',
    hasAllPermissions: true,
    hasAnyPermission: true,
    missingPermissions: const [],
    start: start,
    end: DateTime(start.year, start.month, start.day + 1),
    syncedAt: DateTime(2026, 7, 15, 20, 46),
    activeCalories: activeCalories,
    steps: steps,
    exerciseMinutes: 0,
    dataOrigins: const ['com.sec.android.app.shealth'],
  );
}
