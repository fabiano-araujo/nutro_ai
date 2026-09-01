import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/widgets/food_input_speed_dial.dart';

void main() {
  Widget wrapDial({
    required ValueChanged<FoodInputAction> onSelected,
    bool showCamera = true,
    bool showBarcode = true,
    bool isBusy = false,
  }) {
    return MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        floatingActionButton: FoodInputSpeedDial(
          onSelected: onSelected,
          showCamera: showCamera,
          showBarcode: showBarcode,
          isBusy: isBusy,
        ),
      ),
    );
  }

  testWidgets('FAB menu revela as formas de adicionar e destaca o codigo de barras',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FoodInputAction? selected;

    await tester.pumpWidget(
      wrapDial(onSelected: (action) => selected = action),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adicionar'), findsOneWidget);
    expect(find.text('Ler código de barras'), findsNothing);

    await tester.tap(find.byKey(const Key('food_input_speed_dial')));
    await tester.pumpAndSettle();

    expect(find.text('Falar alimentos'), findsOneWidget);
    expect(find.text('Tirar uma foto'), findsOneWidget);
    expect(find.text('Biblioteca de fotos'), findsOneWidget);
    expect(find.text('Ler código de barras'), findsOneWidget);
    expect(
      find.text('Leia o código de um produto embalado'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ler código de barras'));
    await tester.pumpAndSettle();

    expect(selected, FoodInputAction.barcode);
    expect(find.text('Adicionar'), findsOneWidget);
    expect(find.text('Ler código de barras'), findsNothing);
  });

  testWidgets('menu aberto em tela baixa nao estoura o layout', (tester) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapDial(onSelected: (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food_input_speed_dial')));
    await tester.pumpAndSettle();

    expect(find.text('Ler código de barras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
