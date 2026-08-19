import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/theme/macro_theme.dart';
import 'package:nutro_ai/widgets/mini_nutrition_card.dart';
import 'package:nutro_ai/widgets/nutrition_card.dart';

void main() {
  testWidgets('nutrition card fits edit-goal state on narrow screens',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        routes: {
          '/subscription': (_) => const Scaffold(
                body: Text('Tela de assinatura'),
              ),
        },
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: NutritionCard(
                hasConfiguredGoals: false,
                onEditGoals: () {},
                onMinimize: () {},
                caloriesConsumed: 310,
                caloriesGoal: 2000,
                proteinConsumed: 13,
                proteinGoal: 100,
                carbsConsumed: 42,
                carbsGoal: 250,
                fatsConsumed: 10,
                fatsGoal: 67,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Fibra'), findsOneWidget);
    expect(find.byIcon(MacroTheme.fiberIcon), findsNothing);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('0g'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();

    expect(find.text('Tela de assinatura'), findsOneWidget);
  });

  testWidgets('premium fiber cards fit narrow screens without a fake goal',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(
                width: 360,
                child: NutritionCard(
                  caloriesConsumed: 310,
                  caloriesGoal: 2000,
                  proteinConsumed: 13,
                  proteinGoal: 100,
                  carbsConsumed: 42,
                  carbsGoal: 250,
                  fatsConsumed: 10,
                  fatsGoal: 67,
                  fiberConsumed: 18,
                  showFiber: true,
                ),
              ),
              const SizedBox(
                width: 360,
                child: MiniNutritionCard(
                  caloriesConsumed: 310,
                  caloriesGoal: 2000,
                  proteinConsumed: 13,
                  proteinGoal: 100,
                  carbsConsumed: 42,
                  carbsGoal: 250,
                  fatsConsumed: 10,
                  fatsGoal: 67,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Fibra'), findsOneWidget);
    expect(find.text('18g'), findsOneWidget);
    expect(find.textContaining('/18g'), findsNothing);
    expect(find.byIcon(MacroTheme.fiberIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
