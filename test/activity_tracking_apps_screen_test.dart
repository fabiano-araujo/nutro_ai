import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/activity_tracking_provider.dart';
import 'package:nutro_ai/screens/activity_tracking_apps_screen.dart';
import 'package:nutro_ai/services/tracking_app_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('has every tracking label in all supported languages', () {
    const keys = [
      'automatic_tracking_apps_title',
      'tracking_health_connect_name',
      'tracking_open_health_connect',
      'tracking_refresh',
      'tracking_no_activity_data',
      'tracking_permission_active_calories',
      'tracking_permission_steps',
      'tracking_permission_exercises',
      'popular_tracking_apps',
      'tracking_sources_intro',
      'tracking_desc_huawei_health',
      'tracking_desc_fitbit_health_connect',
      'tracking_desc_garmin_health_connect',
      'tracking_desc_polar_health_connect',
      'tracking_source_data_detected',
      'tracking_action_open',
      'tracking_action_install',
      'tracking_installed',
      'tracking_store',
      'tracking_app_opened',
      'tracking_app_store_opened',
      'tracking_app_open_error',
    ];

    for (final locale in AppLocalizations.supportedLocales) {
      final localizations = AppLocalizations(locale);
      for (final key in keys) {
        expect(
          localizations.translate(key),
          isNot(key),
          reason: '$key is missing for $locale',
        );
      }
    }
  });

  testWidgets(
      'shows real Health Connect data and source apps without '
      'requesting permissions again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final launcher = _ScreenFakeTrackingLauncher();
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('Rastreamento automático'), findsOneWidget);
    expect(find.text('Health Connect'), findsOneWidget);
    expect(find.text('Calorias gastas'), findsOneWidget);
    expect(find.text('415 kcal'), findsOneWidget);
    expect(find.text('1.990'), findsOneWidget);
    expect(find.text('Samsung Health'), findsNothing);
    expect(find.text('Strava'), findsNothing);
    expect(find.text('Medidas corporais'), findsNothing);
    expect(launcher.readCount, 1);
    expect(launcher.permissionRequestCount, 0);

    final scrollable = find.byType(Scrollable).first;
    for (final appName in [
      'Huawei Saúde',
      'Fitbit',
      'Garmin Connect',
      'Polar Flow',
    ]) {
      await tester.scrollUntilVisible(
        find.text(appName),
        260,
        scrollable: scrollable,
      );
      expect(find.text(appName), findsOneWidget);
      if (appName == 'Fitbit') {
        expect(find.text('Dados detectados hoje'), findsOneWidget);
      }
    }

    await tester.scrollUntilVisible(
      find.text('Sincronizar agora'),
      -300,
      scrollable: scrollable,
    );

    await tester.tap(find.text('Sincronizar agora'));
    await tester.pumpAndSettle();

    expect(launcher.readCount, 2);
    expect(launcher.permissionRequestCount, 0);
  });

  testWidgets('opens an installed activity source from its card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launcher = _ScreenFakeTrackingLauncher();
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Fitbit'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Fitbit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fitbit'));
    await tester.pumpAndSettle();

    expect(launcher.openedPackages, contains('com.fitbit.FitbitMobile'));
  });

  testWidgets('does not show zero metrics before Health Connect is connected',
      (tester) async {
    final launcher = _ScreenFakeTrackingLauncher(
      status: const HealthConnectStatus(
        sdkStatus: 'available',
        isAvailable: true,
        hasAllPermissions: false,
        hasAnyPermission: false,
        grantedPermissions: [],
        missingPermissions: [
          'android.permission.health.READ_TOTAL_CALORIES_BURNED',
          'android.permission.health.READ_STEPS',
          'android.permission.health.READ_EXERCISE',
        ],
      ),
    );
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('Configurar Health Connect'), findsOneWidget);
    expect(find.text('Sincronizado hoje'), findsNothing);
    expect(find.text('0 kcal'), findsNothing);
    expect(launcher.readCount, 0);
  });

  testWidgets('stays scrollable without overflow on a small screen and 2x text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = ActivityTrackingProvider(
      launcher: _ScreenFakeTrackingLauncher(),
    );

    await tester.pumpWidget(_testApp(provider, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(
  ActivityTrackingProvider provider, {
  double textScale = 1,
}) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const ActivityTrackingAppsScreen(),
    ),
  );
}

class _ScreenFakeTrackingLauncher extends TrackingAppLauncher {
  _ScreenFakeTrackingLauncher({HealthConnectStatus? status})
      : status = status ??
            const HealthConnectStatus(
              sdkStatus: 'available',
              isAvailable: true,
              hasAllPermissions: true,
              hasAnyPermission: true,
              grantedPermissions: [
                'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
                'android.permission.health.READ_TOTAL_CALORIES_BURNED',
                'android.permission.health.READ_STEPS',
                'android.permission.health.READ_EXERCISE',
              ],
              missingPermissions: [],
            );

  HealthConnectStatus status;
  int readCount = 0;
  int permissionRequestCount = 0;
  final List<String> openedPackages = [];

  static const _installedPackages = {
    'com.huawei.health',
    'com.fitbit.FitbitMobile',
    'com.garmin.android.apps.connectmobile',
    'fi.polar.polarflow',
  };

  @override
  Future<bool> isAppInstalled(String packageName) async {
    return _installedPackages.contains(packageName);
  }

  @override
  Future<TrackingAppLaunchResult> openAppOrStore(String packageName) async {
    openedPackages.add(packageName);
    return TrackingAppLaunchResult.openedApp;
  }

  @override
  Future<HealthConnectStatus> getHealthConnectStatus() async => status;

  @override
  Future<HealthConnectStatus> requestHealthPermissions() async {
    permissionRequestCount++;
    return status;
  }

  @override
  Future<ActivityTrackingSummary> readHealthSummary(DateTime date) async {
    readCount++;
    final start = DateTime(date.year, date.month, date.day);
    return ActivityTrackingSummary(
      status: 'ok',
      sdkStatus: 'available',
      hasAllPermissions: true,
      hasAnyPermission: true,
      missingPermissions: const [],
      start: start,
      end: DateTime(date.year, date.month, date.day + 1),
      syncedAt: DateTime(2026, 7, 15, 20, 46),
      activeCalories: 415.4,
      totalCalories: 1980.2,
      steps: 1990,
      exerciseCount: 1,
      exerciseMinutes: 35,
      dataOrigins: const ['com.fitbit.FitbitMobile'],
    );
  }
}
