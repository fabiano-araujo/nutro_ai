import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/activity_tracking_provider.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:nutro_ai/providers/meal_types_provider.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/screens/daily_meals_screen.dart';
import 'package:nutro_ai/services/tracking_app_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'nutrition_manualCalories': 2000,
      'nutrition_useCalculated': false,
      'water_goal': 8,
    });
  });

  testWidgets(
    'shows activity calories on the right and adds them to the daily balance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final selectedDate = DateUtils.dateOnly(DateTime.now());
      final mealsProvider = DailyMealsProvider();
      final goalsProvider = NutritionGoalsProvider();
      final mealTypesProvider = MealTypesProvider();
      final activityProvider = ActivityTrackingProvider(
        launcher: _NoPermissionTrackingLauncher(),
      );

      await Future.wait([
        mealsProvider.ready,
        goalsProvider.ensureLoaded(),
        mealTypesProvider.ensureLoaded(),
        activityProvider.loadForDate(selectedDate),
      ]);
      await activityProvider.addManualActivity(
        activityId: 'running',
        activityName: 'Corrida',
        date: selectedDate,
        durationMinutes: 30,
        caloriesBurned: 320,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mealsProvider),
            ChangeNotifierProvider.value(value: goalsProvider),
            ChangeNotifierProvider.value(value: mealTypesProvider),
            ChangeNotifierProvider.value(value: activityProvider),
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
            home: const DailyMealsScreen(showBackButton: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final consumedMetric =
          find.byKey(const ValueKey('diary-calories-consumed'));
      final burnedMetric = find.byKey(const ValueKey('diary-calories-burned'));
      expect(consumedMetric, findsOneWidget);
      expect(burnedMetric, findsOneWidget);
      expect(
        find.descendant(
          of: consumedMetric,
          matching: find.text('Consumidas'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: burnedMetric, matching: find.text('Gastas')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: burnedMetric, matching: find.text('320')),
        findsOneWidget,
      );
      expect(find.text('2320'), findsOneWidget);
    },
  );
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
