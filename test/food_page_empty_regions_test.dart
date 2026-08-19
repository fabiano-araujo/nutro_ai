import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/models/Nutrient.dart';
import 'package:nutro_ai/models/food_model.dart';
import 'package:nutro_ai/models/user_model.dart';
import 'package:nutro_ai/providers/food_history_provider.dart';
import 'package:nutro_ai/screens/food_page.dart';
import 'package:nutro_ai/services/auth_service.dart';

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
          routes: {
            '/subscription': (_) => const Scaffold(
                  body: Text('Tela de assinatura'),
                ),
          },
          home: FoodPage(food: food),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('pao'), findsWidgets);
    expect(find.text('Fibra'), findsOneWidget);
    expect(find.text('Premium'), findsNWidgets(2));
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.workspace_premium_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Tela de assinatura'), findsOneWidget);
  });

  testWidgets('FoodPage shows fiber values for a paid plan snapshot',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final food = Food(
      name: 'feijão',
      emoji: '🫘',
      nutrients: [
        Nutrient(
          idFood: 0,
          servingSize: 100,
          servingUnit: 'g',
          calories: 120,
          protein: 8,
          carbohydrate: 20,
          fat: 1,
          dietaryFiber: 6.4,
        ),
      ],
      foodRegions: const [],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FoodHistoryProvider()),
          ChangeNotifierProvider<AuthService>.value(
            value: _PaidPlanSnapshotAuthService(),
          ),
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
          home: FoodPage(food: food),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('6.4g'), findsOneWidget);
    expect(find.text('Fibra Alimentar'), findsOneWidget);
    expect(find.text('6 g'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PaidPlanSnapshotAuthService extends AuthService {
  final User _paidUser = User(
    id: 1,
    name: 'Premium',
    email: 'premium@example.com',
    username: 'premium',
    subscription: Subscription(
      isPremium: false,
      planType: 'annual',
    ),
  );

  @override
  User? get currentUser => _paidUser;
}
