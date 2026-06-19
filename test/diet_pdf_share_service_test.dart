import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/diet_plan_model.dart';
import 'package:nutro_ai/services/diet_pdf_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildDietPlanPdfBytes generates a valid PDF file', () async {
    final plan = DietPlan(
      date: '2026-06-04',
      totalNutrition: DailyNutrition(
        calories: 620,
        protein: 35,
        carbs: 78,
        fat: 18,
      ),
      generatedForNutrition: DailyNutrition(
        calories: 2000,
        protein: 150,
        carbs: 220,
        fat: 60,
      ),
      meals: [
        PlannedMeal(
          type: 'breakfast',
          time: '08:00',
          name: 'Café da manhã',
          foods: [
            PlannedFood(
              name: 'Pão francês',
              emoji: '*',
              amount: 1,
              unit: 'un',
              calories: 150,
              protein: 5,
              carbs: 30,
              fat: 2,
            ),
            PlannedFood(
              name: 'Ovos mexidos',
              emoji: '*',
              amount: 2,
              unit: 'un',
              calories: 220,
              protein: 18,
              carbs: 2,
              fat: 15,
            ),
          ],
          mealTotals: DailyNutrition(
            calories: 370,
            protein: 23,
            carbs: 32,
            fat: 17,
          ),
        ),
      ],
    );

    final bytes = await DietPdfShareService.buildDietPlanPdfBytes(
      dietPlan: plan,
      title: 'Plano alimentar diário',
      periodLabel: '04/06/2026',
      objective: 'Manter peso',
      dietStyle: 'Equilibrada',
      targetNutrition: plan.generatedForNutrition!,
      labels: const DietPdfLabels(
        appName: 'Nutro AI',
        generatedBy: 'Gerado pelo Nutro AI em',
        shareText: 'Minha dieta gerada no Nutro AI.',
        planFor: 'Plano para',
        objective: 'Objetivo',
        dietStyle: 'Estilo da dieta',
        targetMacros: 'Meta nutricional',
        dailyMacros: 'Macros do dia',
        meals: 'Refeições',
        food: 'Alimento',
        calories: 'Calorias',
        protein: 'Proteínas',
        carbs: 'Carboidratos',
        fat: 'Gordura',
        portion: 'Porção',
        nutrition: 'Nutrição',
        page: 'Página',
      ),
      generatedAt: DateTime(2026, 6, 4),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
