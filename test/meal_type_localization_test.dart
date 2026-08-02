import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/meal_type_localization.dart';

void main() {
  testWidgets('localizedMealTime follows locale and 12-hour preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: false),
          child: Builder(
            builder: (context) => Text(localizedMealTime(context, '20:05')),
          ),
        ),
      ),
    );

    expect(find.text('8:05 PM'), findsOneWidget);
  });

  testWidgets('localizedMealTime follows the 24-hour device preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: Builder(
            builder: (context) => Text(localizedMealTime(context, '20:05')),
          ),
        ),
      ),
    );

    expect(find.text('20:05'), findsOneWidget);
  });

  testWidgets('localizedMealTime preserves invalid values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(localizedMealTime(context, 'evening')),
        ),
      ),
    );

    expect(find.text('evening'), findsOneWidget);
  });
}
