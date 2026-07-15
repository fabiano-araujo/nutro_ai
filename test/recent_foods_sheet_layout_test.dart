import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/services/favorite_food_service.dart';
import 'package:nutro_ai/widgets/recent_foods_sheet.dart';

void main() {
  testWidgets('quick add cards stay readable on a narrow screen',
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
          body: RecentFoodsSheet(
            serviceOverride: _FakeFavoriteFoodService(),
            onFoodSelected: (_) {},
            onMealSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adicionar rápido'), findsOneWidget);
    expect(find.text('leite desnatado'), findsOneWidget);
    expect(find.text('90 kcal'), findsOneWidget);
    expect(find.text('8 g'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 760);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Refeições'));
    await tester.pumpAndSettle();

    expect(find.text('Café da Manhã'), findsOneWidget);
    expect(find.text('520 kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeFavoriteFoodService extends FavoriteFoodService {
  _FakeFavoriteFoodService() : super(token: 'test-token');

  @override
  Future<List<FavoriteFood>> getRecents({int limit = 30}) async => [
        FavoriteFood(
          id: 1,
          name: 'leite desnatado',
          emoji: '🥛',
          calories: 90,
          protein: 8,
          carbs: 12,
          fat: 0.5,
          baseAmount: 1,
          baseUnit: 'copo',
        ),
        FavoriteFood(
          id: 2,
          name: 'pão francês',
          emoji: '🥖',
          calories: 130,
          protein: 4,
          carbs: 25,
          fat: 1,
          baseAmount: 1,
          baseUnit: 'unidade',
          usageCount: 2,
        ),
      ];

  @override
  Future<List<FavoriteFood>> getFavorites() async => [];

  @override
  Future<List<RepeatableMeal>> getRepeatableMeals({int limit = 20}) async => [
        RepeatableMeal(
          id: 3,
          type: 'breakfast',
          calories: 520,
          protein: 37,
          carbs: 44,
          fat: 21.5,
          date: DateTime(2026, 7, 13),
          foods: [
            RepeatableMealFood(
              name: 'ovo',
              amount: 4,
              unit: 'unidades',
              calories: 280,
            ),
            RepeatableMealFood(
              name: 'pão francês',
              amount: 1,
              unit: 'unidade',
              calories: 130,
            ),
          ],
        ),
      ];
}
