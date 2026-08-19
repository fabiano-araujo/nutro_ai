import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';
import 'package:nutro_ai/providers/diet_plan_provider.dart';
import 'package:nutro_ai/providers/profile_shape_preview_provider.dart';
import 'package:nutro_ai/widgets/global_generation_floating_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ActiveDietPlanProvider extends DietPlanProvider {
  @override
  bool get hasActiveDietGenerationJob => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('generation card starts at the right edge and snaps to an edge',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final dietProvider = _ActiveDietPlanProvider();
    final shapeProvider = ProfileShapePreviewProvider();
    addTearDown(dietProvider.dispose);
    addTearDown(shapeProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DietPlanProvider>.value(value: dietProvider),
          ChangeNotifierProvider<ProfileShapePreviewProvider>.value(
            value: shapeProvider,
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
          home: GlobalGenerationFloatingOverlay(
            onOpenDietGeneration: () {},
            onOpenProfileShapeGeneration: () {},
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pump();

    final dragTarget = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanUpdate != null,
    );
    expect(dragTarget, findsOneWidget);
    expect(tester.getRect(dragTarget).right, closeTo(392, 0.1));

    await tester.drag(dragTarget, const Offset(-140, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(dragTarget).left, closeTo(8, 0.1));

    await tester.drag(dragTarget, const Offset(140, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(dragTarget).right, closeTo(392, 0.1));
  });
}
