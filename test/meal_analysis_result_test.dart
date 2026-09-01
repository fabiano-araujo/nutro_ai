import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/ai_service.dart';

void main() {
  test('MealAnalysisResult.fromJson aceita o contrato do servidor', () {
    final result = MealAnalysisResult.fromJson({
      'summary': 'Refeição equilibrada.',
      'quality': 'great',
      'highlights': ['Boa proteína', 'Fibra presente'],
      'improvements': ['Reduzir o ultraprocessado'],
      'next_step': 'Troque o suco por água no jantar.',
    });

    expect(result.summary, 'Refeição equilibrada.');
    expect(result.quality, 'great');
    expect(result.highlights, ['Boa proteína', 'Fibra presente']);
    expect(result.improvements, ['Reduzir o ultraprocessado']);
    expect(result.nextStep, 'Troque o suco por água no jantar.');
  });

  test('MealAnalysisResult.fromJson aceita aliases antigos do JSON', () {
    final result = MealAnalysisResult.fromJson({
      'summary': 'Dá para melhorar.',
      'quality': 'needs-improvement',
      'positive_points': ['Tem proteína'],
      'can_improve': ['Falta vegetais'],
      'nextStep': 'Inclua uma salada.',
    });

    expect(result.quality, 'needs_improvement');
    expect(result.highlights, ['Tem proteína']);
    expect(result.improvements, ['Falta vegetais']);
    expect(result.nextStep, 'Inclua uma salada.');
  });
}
