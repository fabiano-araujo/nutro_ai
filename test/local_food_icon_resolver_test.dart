import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/local_food_icon_resolver.dart';

void main() {
  test('resolveLocalFoodIconKind replaces known food icons by name', () {
    const examples = {
      'Peito de frango grelhado': LocalFoodIconKind.chickenBreast,
      'Filé de frango grelhado': LocalFoodIconKind.chickenBreast,
      'Chicken breast': LocalFoodIconKind.chickenBreast,
      'Ovo de galinha': LocalFoodIconKind.egg,
      'Óleo de soja': LocalFoodIconKind.oil,
      'Farinha de tapioca': LocalFoodIconKind.tapioca,
    };

    for (final entry in examples.entries) {
      expect(
        resolveLocalFoodIconKind(entry.key),
        entry.value,
        reason: entry.key,
      );
    }

    expect(resolveLocalFoodIconKind('Coxa de frango assada'), isNull);
    expect(resolveLocalFoodIconKind('Macarrão ao sugo'), isNull);
    expect(resolveLocalFoodIconKind('Banana'), isNull);
    expect(resolveLocalFoodIconKind('Azeite de oliva'), isNull);
    expect(resolveLocalFoodIconKind('Arroz branco cozido'), isNull);
    expect(resolveLocalFoodIconKind('Mel'), isNull);
  });
}
