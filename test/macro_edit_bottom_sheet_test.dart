import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/nutrition_goals_provider.dart';
import 'package:nutro_ai/theme/app_theme.dart';
import 'package:nutro_ai/widgets/macro_edit_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macro editor keeps all input modes clear on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final provider = NutritionGoalsProvider();
    await provider.ensureLoaded();

    await tester.pumpWidget(_MacroEditorTestApp(provider: provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('macro-daily-summary')), findsOneWidget);
    expect(find.byKey(const Key('macro-carbs-grams')), findsOneWidget);
    expect(find.byKey(const Key('macro-save')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('macro-mode-percentage')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('macro-carbs-percentage')), findsOneWidget);
    expect(find.byKey(const Key('macro-percentage-total')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('macro-mode-grams-per-kg')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('macro-carbs-per-kg')), findsOneWidget);
    expect(find.byKey(const Key('macro-protein-per-kg')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('macro-mode-grams')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('macro-carbs-grams')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty manual values disable saving and update the preview',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final provider = NutritionGoalsProvider();
    await provider.ensureLoaded();

    await tester.pumpWidget(_MacroEditorTestApp(provider: provider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('macro-carbs-grams')),
      '',
    );
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('macro-save')),
    );
    expect(saveButton.onPressed, isNull);
    expect(find.text('1003 kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MacroEditorTestApp extends StatelessWidget {
  const _MacroEditorTestApp({required this.provider});

  final NutritionGoalsProvider provider;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('pt', 'BR'),
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: MacroEditBottomSheet(
              provider: provider,
              theme: theme,
              isDarkMode: false,
              textColor: AppTheme.textPrimaryColor,
              cardColor: AppTheme.cardColor,
            ),
          );
        },
      ),
    );
  }
}
