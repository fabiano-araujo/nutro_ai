import 'dart:async';

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
    expect(find.text('Health Connect ativo'), findsOneWidget);
    expect(
      find.text(
        'Sincronize com o Health Connect para acompanhar calorias gastas, passos e exercícios no seu dia.',
      ),
      findsNothing,
    );
    expect(
      find.text('1.990 passos e 35 min de exercícios sincronizados hoje.'),
      findsNothing,
    );
    expect(
      find.text(
        'Instale o app do fabricante e ative o Health Connect nele. O Nutro AI detecta automaticamente os dados compartilhados.',
      ),
      findsNothing,
    );

    final caloriesCard = find.byKey(const ValueKey('tracking-metric-calories'));
    final stepsCard = find.byKey(const ValueKey('tracking-metric-steps'));
    final exerciseCard =
        find.byKey(const ValueKey('tracking-metric-exercises'));
    expect(caloriesCard, findsOneWidget);
    expect(stepsCard, findsOneWidget);
    expect(exerciseCard, findsOneWidget);
    expect(tester.getSize(caloriesCard), tester.getSize(stepsCard));
    expect(tester.getSize(stepsCard), tester.getSize(exerciseCard));
    expect(tester.getSize(caloriesCard).height, 112);
    expect(find.text('Samsung Health'), findsNothing);
    expect(find.text('Strava'), findsNothing);
    expect(find.text('Medidas corporais'), findsNothing);
    expect(launcher.readCount, 1);
    expect(launcher.permissionRequestCount, 0);

    final scrollable = find.byType(Scrollable).first;
    for (final appName in [
      'Google Health (Fitbit)',
      'Garmin Connect',
      'Polar Flow',
    ]) {
      await tester.scrollUntilVisible(
        find.text(appName),
        260,
        scrollable: scrollable,
      );
      expect(find.text(appName), findsOneWidget);
      if (appName == 'Google Health (Fitbit)') {
        expect(find.text('Dados detectados hoje'), findsOneWidget);
      }
    }
    expect(find.text('Huawei Saúde'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Atualizar'),
      -300,
      scrollable: scrollable,
    );

    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(launcher.readCount, 2);
    expect(launcher.permissionRequestCount, 0);
  });

  testWidgets('syncs automatically when the app resumes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launcher = _ScreenFakeTrackingLauncher();
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();
    expect(launcher.readCount, 1);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pumpAndSettle();

    expect(launcher.readCount, 2);
    expect(launcher.permissionRequestCount, 0);
  });

  testWidgets('opens every installed activity source from its card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launcher = _ScreenFakeTrackingLauncher();
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    const apps = {
      'Google Health (Fitbit)': 'com.fitbit.FitbitMobile',
      'Garmin Connect': 'com.garmin.android.apps.connectmobile',
      'Polar Flow': 'fi.polar.polarflow',
    };

    for (final entry in apps.entries) {
      await tester.scrollUntilVisible(
        find.text(entry.key),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
    }

    expect(launcher.openedPackages, apps.values.toList());
  });

  testWidgets('opens the official store when a source app is not installed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launcher = _ScreenFakeTrackingLauncher(
      installedPackages: const {},
      launchResult: TrackingAppLaunchResult.openedStore,
    );
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Google Health (Fitbit)'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Google Health (Fitbit)'));
    await tester.pumpAndSettle();

    expect(launcher.openedPackages, ['com.fitbit.FitbitMobile']);
    expect(
      find.text(
        'Abrindo a loja oficial para instalar Google Health (Fitbit).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not open a source after Health Connect access is denied',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const deniedStatus = HealthConnectStatus(
      sdkStatus: 'available',
      isAvailable: true,
      hasAllPermissions: false,
      hasAnyPermission: false,
      grantedPermissions: [],
      missingPermissions: [
        'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
      ],
    );
    final launcher = _ScreenFakeTrackingLauncher(status: deniedStatus);
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Google Health (Fitbit)'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Google Health (Fitbit)'));
    await tester.pumpAndSettle();

    expect(launcher.permissionRequestCount, 1);
    expect(launcher.openAttemptCount, 0);
    expect(launcher.openedPackages, isEmpty);
    expect(find.text('Ative o acesso ao Health Connect'), findsWidgets);
  });

  testWidgets('serializes taps while Health Connect permission is pending',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const deniedStatus = HealthConnectStatus(
      sdkStatus: 'available',
      isAvailable: true,
      hasAllPermissions: false,
      hasAnyPermission: false,
      grantedPermissions: [],
      missingPermissions: [
        'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
      ],
    );
    const grantedStatus = HealthConnectStatus(
      sdkStatus: 'available',
      isAvailable: true,
      hasAllPermissions: true,
      hasAnyPermission: true,
      grantedPermissions: [
        'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
        'android.permission.health.READ_STEPS',
        'android.permission.health.READ_EXERCISE',
      ],
      missingPermissions: [],
    );
    final permissionCompleter = Completer<HealthConnectStatus>();
    final launcher = _ScreenFakeTrackingLauncher(
      status: deniedStatus,
      permissionCompleter: permissionCompleter,
    );
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    final card = find.text('Google Health (Fitbit)');
    await tester.scrollUntilVisible(
      card,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();

    expect(launcher.permissionRequestCount, 1);
    expect(launcher.openAttemptCount, 0);

    permissionCompleter.complete(grantedStatus);
    await tester.pumpAndSettle();

    expect(launcher.permissionRequestCount, 1);
    expect(launcher.openAttemptCount, 1);
    expect(launcher.openedPackages, ['com.fitbit.FitbitMobile']);
  });

  testWidgets('recovers after an exception while opening a source app',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launcher = _ScreenFakeTrackingLauncher()..throwOnOpen = true;
    final provider = ActivityTrackingProvider(launcher: launcher);

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    final card = find.text('Google Health (Fitbit)');
    await tester.scrollUntilVisible(
      card,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(launcher.openAttemptCount, 1);
    expect(
      find.text('Não foi possível abrir Google Health (Fitbit).'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    launcher.throwOnOpen = false;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(launcher.openAttemptCount, 2);
    expect(launcher.openedPackages, ['com.fitbit.FitbitMobile']);
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
          'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
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

  testWidgets('hides Garmin below Android 14', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = ActivityTrackingProvider(
      launcher: _ScreenFakeTrackingLauncher(androidSdkInt: 33),
    );

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Google Health (Fitbit)'),
      260,
      scrollable: scrollable,
    );
    expect(find.text('Google Health (Fitbit)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Polar Flow'),
      260,
      scrollable: scrollable,
    );
    expect(find.text('Polar Flow'), findsOneWidget);
    expect(find.text('Garmin Connect'), findsNothing);
  });

  testWidgets('hides all source apps when Health Connect is unsupported',
      (tester) async {
    const unsupportedStatus = HealthConnectStatus(
      sdkStatus: 'unavailable',
      isAvailable: false,
      hasAllPermissions: false,
      hasAnyPermission: false,
      grantedPermissions: [],
      missingPermissions: [],
    );
    final provider = ActivityTrackingProvider(
      launcher: _ScreenFakeTrackingLauncher(status: unsupportedStatus),
    );

    await tester.pumpWidget(_testApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('Apps e dispositivos'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Google Health (Fitbit)'), findsNothing);
    expect(find.text('Garmin Connect'), findsNothing);
    expect(find.text('Polar Flow'), findsNothing);
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
  _ScreenFakeTrackingLauncher({
    HealthConnectStatus? status,
    Set<String>? installedPackages,
    this.androidSdkInt = 35,
    this.launchResult = TrackingAppLaunchResult.openedApp,
    this.permissionCompleter,
  })  : installedPackages = installedPackages ?? _defaultInstalledPackages,
        status = status ??
            const HealthConnectStatus(
              sdkStatus: 'available',
              isAvailable: true,
              hasAllPermissions: true,
              hasAnyPermission: true,
              grantedPermissions: [
                'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
                'android.permission.health.READ_STEPS',
                'android.permission.health.READ_EXERCISE',
              ],
              missingPermissions: [],
            );

  HealthConnectStatus status;
  final Set<String> installedPackages;
  final int? androidSdkInt;
  TrackingAppLaunchResult launchResult;
  final Completer<HealthConnectStatus>? permissionCompleter;
  bool throwOnOpen = false;
  int readCount = 0;
  int permissionRequestCount = 0;
  int openAttemptCount = 0;
  final List<String> openedPackages = [];

  static const _defaultInstalledPackages = {
    'com.fitbit.FitbitMobile',
    'com.garmin.android.apps.connectmobile',
    'fi.polar.polarflow',
  };

  @override
  Future<int?> getAndroidSdkInt() async => androidSdkInt;

  @override
  Future<bool> isAppInstalled(String packageName) async {
    return installedPackages.contains(packageName);
  }

  @override
  Future<TrackingAppLaunchResult> openAppOrStore(String packageName) async {
    openAttemptCount++;
    if (throwOnOpen) throw StateError('Unable to open $packageName');
    openedPackages.add(packageName);
    return launchResult;
  }

  @override
  Future<HealthConnectStatus> getHealthConnectStatus() async => status;

  @override
  Future<HealthConnectStatus> requestHealthPermissions() async {
    permissionRequestCount++;
    final requestedStatus = permissionCompleter == null
        ? status
        : await permissionCompleter!.future;
    status = requestedStatus;
    return requestedStatus;
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
      steps: 1990,
      exerciseMinutes: 35,
      dataOrigins: const ['com.fitbit.FitbitMobile'],
    );
  }
}
