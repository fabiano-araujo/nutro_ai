import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/i18n/language_controller.dart';
import 'package:nutro_ai/main.dart' show ThemeProvider;
import 'package:nutro_ai/providers/diet_plan_provider.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/screens/settings_screen.dart';
import 'package:nutro_ai/services/auth_service.dart';
import 'package:nutro_ai/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Nutro AI',
      packageName: 'br.com.snapdark.apps.studyai',
      version: '1.0.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<DietPlanProvider> pumpSettings(WidgetTester tester) async {
    final dietProvider = DietPlanProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(ThemeMode.light, (_) async {}),
          ),
          ChangeNotifierProvider(create: (_) => LanguageController()),
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => NutritionGoalsProvider()),
          ChangeNotifierProvider.value(value: dietProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('pt', 'BR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return dietProvider;
  }

  Future<void> openDietModelDialog(WidgetTester tester) async {
    final modelRow = find.text('Modelo de IA da dieta');
    await tester.scrollUntilVisible(modelRow, 240);
    await tester.ensureVisible(modelRow);
    await tester.pumpAndSettle();

    await tester.tap(modelRow);
    await tester.pumpAndSettle();
  }

  testWidgets('selecting diet AI model closes dialog and updates provider',
      (tester) async {
    final dietProvider = await pumpSettings(tester);
    await openDietModelDialog(tester);

    await tester.tap(find.text('DeepSeek V4 Flash'));
    await tester.pumpAndSettle();

    expect(
      dietProvider.dietGenerationModel,
      'deepseek/deepseek-v4-flash',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving custom diet AI model closes dialog and updates provider',
      (tester) async {
    final dietProvider = await pumpSettings(tester);
    await openDietModelDialog(tester);

    await tester.enterText(
      find.byType(TextField),
      'google/gemini-3.5-flash',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(
      dietProvider.dietGenerationModel,
      'google/gemini-3.5-flash',
    );
    expect(tester.takeException(), isNull);
  });
}
