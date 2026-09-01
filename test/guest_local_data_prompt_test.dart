import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/widgets/guest_local_data_prompt.dart';

void main() {
  testWidgets('guest data prompt fits a narrow phone without overflow',
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
          body: Stack(
            children: [
              const SizedBox.expand(),
              GuestLocalDataPrompt(
                kinds: GuestLocalDataKind.values,
                isResolving: false,
                isWide: false,
                onSave: () {},
                onDiscard: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Encontramos dados neste aparelho'), findsOneWidget);
    expect(find.text('O que encontramos'), findsOneWidget);
    expect(find.text('Salvar na conta'), findsOneWidget);
    expect(find.text('Descartar deste aparelho'), findsOneWidget);
    expect(find.text('Metas'), findsOneWidget);
    expect(find.text('Refeições'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
