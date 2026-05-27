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

String resolveFoodEmoji(String name, {String? preferred}) {
  if (preferred != null &&
      preferred.trim().isNotEmpty &&
      preferred.trim() != '🍽️') {
    return preferred.trim();
  }

  final normalized = _normalizeFoodName(name);
  const emojiMatchers = <MapEntry<List<String>, String>>[
    MapEntry([
      'ovo',
      'ovos',
      'omelete',
      'mexido',
      'clara',
      'egg',
      'eggs',
      'omelet',
    ], '🍳'),
    MapEntry([
      'peito de frango',
      'frango',
      'sobrecoxa',
      'coxa',
      'galinha',
      'chicken',
    ], '🍗'),
    MapEntry([
      'carne moida',
      'carne',
      'bife',
      'alcatra',
      'patinho',
      'picanha',
      'file mignon',
      'maminha',
      'acém',
      'acem',
      'beef',
      'steak',
    ], '🥩'),
    MapEntry(['cordeiro', 'costela', 'ribs', 'lamb'], '🍖'),
    MapEntry(['hamburguer', 'hamburger', 'burger'], '🍔'),
    MapEntry([
      'hot dog',
      'cachorro quente',
      'salsicha',
      'sausage',
    ], '🌭'),
    MapEntry(['bacon', 'presunto', 'panceta', 'pork belly'], '🥓'),
    MapEntry(['porco', 'lombo', 'pernil', 'pork'], '🥩'),
    MapEntry(['peito de peru', 'peru', 'turkey'], '🍗'),
    MapEntry([
      'salmao',
      'salmão',
      'atum',
      'tilapia',
      'sardinha',
      'bacalhau',
      'truta',
      'pescada',
      'peixe',
      'fish',
      'salmon',
      'tuna',
    ], '🐟'),
    MapEntry([
      'camarao',
      'camarão',
      'lula',
      'polvo',
      'marisco',
      'shrimp',
      'seafood',
    ], '🍤'),
    MapEntry(['sushi', 'sashimi', 'temaki', 'poke'], '🍣'),
    MapEntry(['arroz', 'risoto', 'rice', 'risotto'], '🍚'),
    MapEntry([
      'feijao',
      'feijão',
      'lentilha',
      'grao de bico',
      'grão de bico',
      'ervilha seca',
      'beans',
      'lentils',
      'chickpea',
    ], '🫘'),
    MapEntry(['ervilha', 'edamame', 'pea', 'peas'], '🫛'),
    MapEntry(['quinoa', 'cevada', 'trigo', 'farro', 'barley'], '🌾'),
    MapEntry([
      'aveia',
      'granola',
      'cereal',
      'mingau',
      'oats',
      'oatmeal',
    ], '🥣'),
    MapEntry([
      'macarrao',
      'macarrão',
      'espaguete',
      'lasanha',
      'nhoque',
      'ravioli',
      'massa',
      'pasta',
      'spaghetti',
    ], '🍝'),
    MapEntry(['lamen', 'ramen', 'noodle', 'yakisoba'], '🍜'),
    MapEntry(['pizza'], '🍕'),
    MapEntry([
      'pao',
      'pão',
      'torrada',
      'croissant',
      'bagel',
      'sanduiche',
      'sanduíche',
      'toast',
      'bread',
      'sandwich',
    ], '🥖'),
    MapEntry([
      'tapioca',
      'crepioca',
      'wrap',
      'tortilla',
      'pita',
      'flatbread',
    ], '🫓'),
    MapEntry(['panqueca', 'pancake'], '🥞'),
    MapEntry(['waffle'], '🧇'),
    MapEntry([
      'queijo',
      'mussarela',
      'muçarela',
      'parmesao',
      'parmesão',
      'ricota',
      'cottage',
      'requeijao',
      'requeijão',
      'cheese',
    ], '🧀'),
    MapEntry(['manteiga', 'butter', 'ghee'], '🧈'),
    MapEntry(['leite', 'milk'], '🥛'),
    MapEntry(['iogurte', 'coalhada', 'kefir', 'yogurt', 'yoghurt'], '🥣'),
    MapEntry(['whey', 'shake', 'smoothie', 'vitamina', 'protein shake'], '🥤'),
    MapEntry([
      'cafe com leite',
      'café com leite',
      'cafe',
      'café',
      'capuccino',
      'espresso',
      'coffee'
    ], '☕'),
    MapEntry(['cha', 'chá', 'tea'], '🫖'),
    MapEntry([
      'suco de laranja',
      'suco de uva',
      'suco de limao',
      'suco de limão',
      'suco de maca',
      'suco de maçã',
      'suco',
      'juice',
    ], '🧃'),
    MapEntry(['agua de coco', 'água de coco', 'coconut water'], '🥥'),
    MapEntry(['agua', 'água', 'water'], '💧'),
    MapEntry(['refrigerante', 'soda'], '🥤'),
    MapEntry(['vinho', 'wine'], '🍷'),
    MapEntry(['cerveja', 'beer'], '🍺'),
    MapEntry(['banana'], '🍌'),
    MapEntry(['maca', 'maçã', 'apple'], '🍎'),
    MapEntry(['pera', 'pear'], '🍐'),
    MapEntry(['laranja', 'tangerina', 'mexerica', 'orange'], '🍊'),
    MapEntry(['limao', 'limão', 'lemon', 'lime'], '🍋'),
    MapEntry(['uva', 'grape'], '🍇'),
    MapEntry(['morango', 'strawberry'], '🍓'),
    MapEntry(['mirtilo', 'blueberry', 'blueberries'], '🫐'),
    MapEntry(['cereja', 'cherry'], '🍒'),
    MapEntry(['pessego', 'pêssego', 'peach'], '🍑'),
    MapEntry(['melancia', 'watermelon'], '🍉'),
    MapEntry(['abacaxi', 'pineapple'], '🍍'),
    MapEntry(['mamao', 'mamão', 'manga', 'papaya', 'mango'], '🥭'),
    MapEntry(['abacate', 'avocado'], '🥑'),
    MapEntry(['kiwi'], '🥝'),
    MapEntry(['coco', 'coconut'], '🥥'),
    MapEntry(['acai', 'açaí'], '🫐'),
    MapEntry(['salada de frutas', 'fruit salad'], '🍓'),
    MapEntry(['tomate', 'tomato'], '🍅'),
    MapEntry(['brocolis', 'brócolis', 'broccoli'], '🥦'),
    MapEntry(['alface', 'lettuce'], '🥬'),
    MapEntry(['couve', 'espinafre', 'rucula', 'rúcula', 'spinach'], '🥬'),
    MapEntry(['pepino', 'cucumber'], '🥒'),
    MapEntry(['cenoura', 'carrot'], '🥕'),
    MapEntry(['milho', 'cuscuz', 'corn'], '🌽'),
    MapEntry(['batata doce', 'sweet potato'], '🍠'),
    MapEntry(
        ['batata', 'mandioca', 'aipim', 'inhame', 'potato', 'cassava'], '🥔'),
    MapEntry(['pimentao', 'pimentão', 'bell pepper'], '🫑'),
    MapEntry(['cebola', 'onion'], '🧅'),
    MapEntry(['alho', 'garlic'], '🧄'),
    MapEntry(['cogumelo', 'mushroom'], '🍄'),
    MapEntry(['berinjela', 'eggplant'], '🍆'),
    MapEntry(['abobrinha', 'zucchini'], '🥒'),
    MapEntry(['pimenta', 'pepper', 'chili'], '🌶️'),
    MapEntry(['salada', 'salad', 'legumes', 'vegetais', 'vegetables'], '🥗'),
    MapEntry([
      'sopa de legumes',
      'sopa de frango',
      'canja',
      'sopa',
      'caldo',
      'ensopado',
      'soup',
      'stew',
    ], '🍲'),
    MapEntry(['curry', 'strogonoff', 'stroganoff'], '🍛'),
    MapEntry(['tofu', 'tempeh', 'soja', 'soy'], '🫘'),
    MapEntry(['homus', 'hummus', 'falafel'], '🧆'),
    MapEntry(['azeite', 'azeitona', 'oliva', 'olive oil', 'olive'], '🫒'),
    MapEntry([
      'castanha',
      'castanhas',
      'amendoim',
      'noz',
      'nozes',
      'amendoas',
      'amêndoas',
      'nuts',
      'peanut',
      'almond',
    ], '🥜'),
    MapEntry(['pasta de amendoim', 'peanut butter'], '🥜'),
    MapEntry(['mel', 'honey'], '🍯'),
    MapEntry([
      'bolo de cenoura',
      'bolo de chocolate',
      'bolo',
      'torta',
      'cupcake',
      'cake',
      'pie',
    ], '🍰'),
    MapEntry(['biscoito', 'bolacha', 'cookie'], '🍪'),
    MapEntry(['chocolate', 'cacau', 'brigadeiro', 'cocoa'], '🍫'),
    MapEntry(['sorvete', 'gelato', 'ice cream'], '🍨'),
    MapEntry(['pudim', 'flan', 'pudding'], '🍮'),
    MapEntry(['doce', 'bala', 'candy'], '🍬'),
  ];

  String? bestEmoji;
  var bestScore = -1;

  for (final entry in emojiMatchers) {
    for (final term in entry.key) {
      final score = _foodTermScore(normalized, term);
      if (score > bestScore) {
        bestScore = score;
        bestEmoji = entry.value;
      }
    }
  }

  return bestEmoji ?? '🍽️';
}
