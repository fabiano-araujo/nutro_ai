import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/local_food_icon_resolver.dart';

void main() {
  test('resolveLocalFoodIconKind only replaces chicken breast by name', () {
    const examples = {
      'Peito de frango grelhado': LocalFoodIconKind.chickenBreast,
      'Filé de frango grelhado': LocalFoodIconKind.chickenBreast,
      'Chicken breast': LocalFoodIconKind.chickenBreast,
    };

    for (final entry in examples.entries) {
      expect(
        resolveLocalFoodIconKind(entry.key),
        entry.value,
        reason: entry.key,
      );
    }

    expect(resolveLocalFoodIconKind('Arroz branco cozido'), isNull);
    expect(resolveLocalFoodIconKind('Coxa de frango assada'), isNull);
  });
}
