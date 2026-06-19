enum LocalFoodIconKind {
  avocado,
  banana,
  beans,
  bread,
  broccoli,
  chickenBreast,
  egg,
  honey,
  oil,
  peanut,
  rice,
  sweetPotato,
  tapioca,
  tomato,
}

String _normalizeFoodName(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };

  var normalized = value.toLowerCase();
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });

  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _foodTermScore(String normalizedName, String term) {
  final normalizedTerm = _normalizeFoodName(term);
  if (normalizedTerm.isEmpty) return -1;

  final hasMatch = RegExp(
    '(^| )${RegExp.escape(normalizedTerm)}( |s(?= |\$)|es(?= |\$)|\$)',
  ).hasMatch(normalizedName);

  return hasMatch ? normalizedTerm.length : -1;
}

LocalFoodIconKind? resolveLocalFoodIconKind(String name) {
  final normalized = _normalizeFoodName(name);
  if (normalized.isEmpty) return null;

  const matchers = <MapEntry<LocalFoodIconKind, List<String>>>[
    MapEntry(LocalFoodIconKind.egg, [
      'ovo',
      'ovos',
      'ovo de galinha',
      'omelete',
      'mexido',
      'clara',
      'egg',
      'eggs',
      'omelet',
    ]),
    MapEntry(LocalFoodIconKind.chickenBreast, [
      'peito de frango',
      'file de frango',
      'filé de frango',
      'chicken breast',
    ]),
    MapEntry(LocalFoodIconKind.tapioca, [
      'farinha de tapioca',
      'tapioca',
      'crepioca',
      'wrap',
      'tortilla',
      'flatbread',
    ]),
    MapEntry(LocalFoodIconKind.oil, [
      'oleo de soja',
      'óleo de soja',
      'oleo vegetal',
      'óleo vegetal',
      'oleo de canola',
      'óleo de canola',
      'oleo de girassol',
      'óleo de girassol',
      'oleo de coco',
      'óleo de coco',
      'soybean oil',
      'vegetable oil',
      'canola oil',
      'sunflower oil',
      'coconut oil',
    ]),
  ];

  LocalFoodIconKind? bestKind;
  var bestScore = -1;

  for (final entry in matchers) {
    for (final term in entry.value) {
      final score = _foodTermScore(normalized, term);
      if (score > bestScore) {
        bestScore = score;
        bestKind = entry.key;
      }
    }
  }

  return bestKind;
}
