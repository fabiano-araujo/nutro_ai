import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/activity_tracking_provider.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/screens/activity_selection_screen.dart';
import 'package:nutro_ai/services/tracking_app_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('searches and saves an activity for the selected diary date',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = ActivityTrackingProvider(
      launcher: _NoPermissionTrackingLauncher(),
    );
    final selectedDate = DateTime(2026, 7, 15);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(create: (_) => NutritionGoalsProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ActivitySelectionScreen(selectedDate: selectedDate),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atividade'), findsOneWidget);
    expect(find.text('Todas atividades'), findsOneWidget);
    expect(find.text('Abdominais'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Procurar uma atividade'),
      'corrida',
    );
    await tester.pumpAndSettle();

    expect(find.text('Corrida'), findsOneWidget);
    expect(find.text('Abdominais'), findsNothing);

    await tester.tap(find.text('Corrida'));
    await tester.pumpAndSettle();

    expect(find.text('Duração'), findsOneWidget);
    expect(find.text('Calorias gastas'), findsOneWidget);

    await tester.tap(find.text('Registrar atividade'));
    await tester.pumpAndSettle();

    final entries = provider.manualActivitiesForDate(selectedDate);
    expect(entries, hasLength(1));
    expect(entries.single.activityId, 'running');
    expect(entries.single.durationMinutes, 30);
    expect(entries.single.caloriesBurned, greaterThan(0));
  });
}

class _NoPermissionTrackingLauncher extends TrackingAppLauncher {
  @override
  Future<HealthConnectStatus> getHealthConnectStatus() async {
    return const HealthConnectStatus(
      sdkStatus: 'available',
      isAvailable: true,
      hasAllPermissions: false,
      hasAnyPermission: false,
      grantedPermissions: [],
      missingPermissions: [],
    );
  }
}
