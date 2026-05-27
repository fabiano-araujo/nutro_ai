import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/providers/diet_plan_provider.dart';

void main() {
  test('OpenRouter model validation accepts dotted Qwen model IDs', () {
    expect(
      DietPlanProvider.isValidOpenRouterModelId('qwen/qwen3.7-max'),
      isTrue,
    );
  });
}
