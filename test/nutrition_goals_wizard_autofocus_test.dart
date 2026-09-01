import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/screens/nutrition_goals_wizard_screen.dart';
import 'package:nutro_ai/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('avança o foco de gênero para idade, altura e peso',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = NutritionGoalsProvider();
    await provider.ensureLoaded();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          theme: AppTheme.lightTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const NutritionGoalsWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qual é a sua idade?'), findsNothing);

    await tester.tap(find.text('Masculino'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Qual é a sua idade?'), findsOneWidget);
    expect(_textFieldHasFocus(tester, 0), isTrue);

    await tester.enterText(find.byType(TextField).at(0), '20');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Qual é a sua altura?'), findsOneWidget);
    expect(_textFieldHasFocus(tester, 1), isTrue);

    await tester.enterText(find.byType(TextField).at(1), '181');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Qual é o seu peso atual?'), findsOneWidget);
    expect(_textFieldHasFocus(tester, 2), isTrue);
  });
}

bool _textFieldHasFocus(WidgetTester tester, int index) {
  final field = tester.widget<TextField>(find.byType(TextField).at(index));
  return field.focusNode?.hasFocus ?? false;
}
