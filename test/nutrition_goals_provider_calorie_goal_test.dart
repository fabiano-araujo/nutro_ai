import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/screens/calorie_goal_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NutritionGoalsProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = NutritionGoalsProvider();
    await provider.ensureLoaded();
    provider.updatePersonalInfo(
      sex: 'male',
      age: 30,
      weight: 70,
      height: 170,
    );
    provider.updateActivityAndGoals(
      activityLevel: ActivityLevel.moderatelyActive,
      fitnessGoal: FitnessGoal.maintainWeight,
    );
  });

  test('infers a fitness goal from the maintenance calorie difference', () {
    expect(provider.maintenanceCalories, 2507);

    int targetAt(double difference) =>
        (provider.maintenanceCalories * (1 + difference)).round();

    expect(
      provider.inferFitnessGoalForCalories(targetAt(-0.20)),
      FitnessGoal.loseWeight,
    );
    expect(
      provider.inferFitnessGoalForCalories(targetAt(-0.10)),
      FitnessGoal.loseWeightSlowly,
    );
    expect(
      provider.inferFitnessGoalForCalories(targetAt(0)),
      FitnessGoal.maintainWeight,
    );
    expect(
      provider.inferFitnessGoalForCalories(targetAt(0.10)),
      FitnessGoal.gainWeightSlowly,
    );
    expect(
      provider.inferFitnessGoalForCalories(targetAt(0.20)),
      FitnessGoal.gainWeight,
    );
  });

  test('manual calorie target updates the objective and rescales macros', () {
    const target = 3000;
    final inferredGoal = provider.inferFitnessGoalForCalories(target);

    provider.updateManualCalorieGoal(
      calories: target,
      fitnessGoal: inferredGoal,
    );

    expect(provider.useCalculatedGoals, isFalse);
    expect(provider.caloriesGoal, target);
    expect(provider.fitnessGoal, FitnessGoal.gainWeight);
    expect(provider.carbsGoal, 375);
    expect(provider.proteinGoal, 150);
    expect(provider.fatGoal, 100);
  });

  testWidgets('calorie editor previews and confirms the inferred objective',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalorieGoalEditScreen(provider: provider),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3000');
    await tester.pump();

    expect(find.text('Ganhar peso rapidamente'), findsOneWidget);

    await tester.tap(find.text('Confirmar meta e objetivo'));
    await tester.pumpAndSettle();

    expect(provider.caloriesGoal, 3000);
    expect(provider.fitnessGoal, FitnessGoal.gainWeight);
    expect(find.text('open'), findsOneWidget);
  });
}
