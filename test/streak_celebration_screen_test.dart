import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/screens/streak_celebration_screen.dart';

void main() {
  testWidgets('uses singular and plural streak celebration copy',
      (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        StreakCelebrationScreen(
          key: ValueKey('singular-celebration'),
          event: StreakCelebrationEvent(
            eventId: 1,
            currentStreak: 1,
            effectiveDate: DateTime(2026, 8, 13),
            missedDates: <DateTime>[],
            freezeRecovered: false,
            freezesAvailable: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('dia seguido!'), findsOneWidget);
    expect(find.text('Amanhã você pode chegar a 2 dias seguidos!'),
        findsOneWidget);
    expect(find.bySemanticsLabel('1 dia seguido!'), findsWidgets);

    await tester.pumpWidget(
      _localizedApp(
        StreakCelebrationScreen(
          key: ValueKey('plural-celebration'),
          event: StreakCelebrationEvent(
            eventId: 2,
            currentStreak: 4,
            effectiveDate: DateTime(2026, 8, 13),
            missedDates: <DateTime>[],
            freezeRecovered: false,
            freezesAvailable: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4'), findsNWidgets(2));
    expect(find.text('dias seguidos!'), findsOneWidget);
    expect(find.text('Amanhã você pode chegar a 5 dias seguidos!'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('five-day strip distinguishes filled, protected and empty days',
      (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        StreakCelebrationScreen(
          event: StreakCelebrationEvent(
            eventId: 3,
            currentStreak: 2,
            effectiveDate: DateTime(2026, 8, 13),
            missedDates: <DateTime>[DateTime(2026, 8, 12)],
            freezeRecovered: false,
            freezesAvailable: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('streak-celebration-day--2-filled'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('streak-celebration-day--1-protected'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('streak-celebration-day-0-filled'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('streak-celebration-day-1-empty'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('streak-celebration-day-2-empty'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('freeze recovery opens a second page before completing',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(
      _localizedApp(
        StreakCelebrationScreen(
          event: StreakCelebrationEvent(
            eventId: 4,
            currentStreak: 7,
            effectiveDate: DateTime(2026, 8, 13),
            missedDates: <DateTime>[],
            freezeRecovered: true,
            freezesAvailable: 2,
          ),
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('streak-celebration-continue-button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('streak-celebration-freeze-page')),
      findsOneWidget,
    );
    expect(find.text('Você recuperou seu gelo'), findsOneWidget);
    expect(find.text('Isso ajudará caso você perca um dia.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('streak-celebration-freeze-illustration')),
      findsOneWidget,
    );
    expect(completed, isFalse);

    await tester.tap(
      find.byKey(
        const ValueKey('streak-celebration-continue-button'),
      ),
    );
    await tester.pump();

    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact dark layout fits 320x568 with animations disabled',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        StreakCelebrationScreen(
          event: StreakCelebrationEvent(
            eventId: 5,
            currentStreak: 128,
            effectiveDate: DateTime(2026, 8, 13),
            missedDates: <DateTime>[DateTime(2026, 8, 12)],
            freezeRecovered: true,
            freezesAvailable: 1,
          ),
        ),
        brightness: Brightness.dark,
        disableAnimations: true,
      ),
    );
    await tester.pump();

    expect(find.text('128'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('streak-celebration-five-day-strip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('streak-celebration-continue-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _localizedApp(
  Widget home, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
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
    theme: ThemeData(useMaterial3: true, brightness: brightness),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: home,
  );
}
