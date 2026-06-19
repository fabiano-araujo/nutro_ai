import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/providers/food_history_provider.dart';
import 'package:nutro_ai/screens/food_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FoodPage opens foods with empty region list', (tester) async {
    final food = Food(
      name: 'pao',
      emoji: '*',
      nutrients: [
        Nutrient(
          idFood: 0,
          servingSize: 100,
          servingUnit: 'g',
          calories: 90,
          protein: 3,
          carbohydrate: 18,
          fat: 1,
        ),
      ],
      foodRegions: const [],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FoodHistoryProvider(),
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FoodPage(food: food),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('pao'), findsWidgets);
  });
}
