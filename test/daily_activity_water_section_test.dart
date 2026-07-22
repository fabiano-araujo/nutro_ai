import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/activity_tracking_provider.dart';
import 'package:nutro_ai/providers/daily_meals_provider.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/widgets/daily_activity_water_section.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'water_goal': 8});
  });

  testWidgets('opens the water challenge dialog and saves the selected goal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mealsProvider = DailyMealsProvider();
    await mealsProvider.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mealsProvider),
          ChangeNotifierProvider(create: (_) => ActivityTrackingProvider()),
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyActivityWaterSection(
                selectedDate: DateTime(2026, 7, 16),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Desafios'), findsOneWidget);
    expect(find.text('Acompanhe seu consumo diário'), findsOneWidget);
    expect(find.text('2,00 L'), findsOneWidget);
    expect(find.text('Recomendado'), findsOneWidget);

    final sliderRect = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(sliderRect.left + 8, sliderRect.center.dy));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Desafios'), findsNothing);
    expect(mealsProvider.waterGoal, lessThan(8));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('water_goal'), mealsProvider.waterGoal);
  });

  testWidgets('fills through the tapped glass and drains from a filled glass',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final selectedDate = DateTime(2026, 7, 16);
    final mealsProvider = DailyMealsProvider();
    await mealsProvider.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mealsProvider),
          ChangeNotifierProvider(create: (_) => ActivityTrackingProvider()),
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyActivityWaterSection(selectedDate: selectedDate),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const ValueKey('water-glass-2')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(mealsProvider.getWaterGlassesForDate(selectedDate), 3);
    expect(find.text('Meta: 2,00 L'), findsOneWidget);
    expect(find.text('0,75 L'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('water-glass-1')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(mealsProvider.getWaterGlassesForDate(selectedDate), 1);
  });

  testWidgets('applies the recommendation calculated from the saved profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'water_goal': 8,
      'nutrition_hasExplicitSex': true,
      'nutrition_hasExplicitAge': true,
      'nutrition_hasExplicitWeight': true,
      'nutrition_hasExplicitHeight': true,
      'nutrition_hasExplicitActivityLevel': true,
      'nutrition_sex': 'male',
      'nutrition_age': 35,
      'nutrition_weight': 83.0,
      'nutrition_height': 175.0,
      'nutrition_activityLevel': ActivityLevel.moderatelyActive.index,
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mealsProvider = DailyMealsProvider();
    final nutritionGoals = NutritionGoalsProvider();
    await Future.wait([mealsProvider.ready, nutritionGoals.ensureLoaded()]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mealsProvider),
          ChangeNotifierProvider.value(value: nutritionGoals),
          ChangeNotifierProvider(create: (_) => ActivityTrackingProvider()),
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyActivityWaterSection(
                selectedDate: DateTime(2026, 7, 16),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.max, 32);
    await tester.drag(find.byType(Slider), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('8,00 L'), findsOneWidget);
    expect(
      find.text('Acima do recomendado para você (3,25 L).'),
      findsOneWidget,
    );

    await tester.tap(find.text('Recomendado'));
    await tester.pump();

    expect(find.text('3,25 L'), findsOneWidget);
    expect(find.byKey(const ValueKey('water-goal-warning')), findsNothing);
    await tester.tap(find.text('Confirmar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(mealsProvider.waterGoal, 13);
  });
}
