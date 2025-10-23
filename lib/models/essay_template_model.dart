/// Modelo para templates de redação
class EssayTemplate {
  final String id;
  final String name;
  final String type; // ENEM, Vestibular, Concurso, Livre
  final String description;
  final String structure; // Estrutura sugerida
  final List<String> guidelines; // Diretrizes específicas
  final Map<String, int> evaluationCriteria; // Critérios de avaliação
  final int minWords;
  final int maxWords;
  final int estimatedTime; // em minutos
  final bool isActive;

  EssayTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.structure,
    required this.guidelines,
    required this.evaluationCriteria,
    this.minWords = 0,
    this.maxWords = 0,
    this.estimatedTime = 60,
    this.isActive = true,
  });

  factory EssayTemplate.fromJson(Map<String, dynamic> json) {
    return EssayTemplate(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      structure: json['structure'],
      guidelines: List<String>.from(json['guidelines']),
      evaluationCriteria: Map<String, int>.from(json['evaluationCriteria']),
      minWords: json['minWords'] ?? 0,
      maxWords: json['maxWords'] ?? 0,
      estimatedTime: json['estimatedTime'] ?? 60,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'structure': structure,
      'guidelines': guidelines,
      'evaluationCriteria': evaluationCriteria,
      'minWords': minWords,
      'maxWords': maxWords,
      'estimatedTime': estimatedTime,
      'isActive': isActive,
    };
  }
}

/// Modelo para temas de redação
class EssayTheme {
  final String id;
  final String title;
  final String description;
  final String category; // Atualidades, Meio Ambiente, etc.
  final List<String> keywords;
  final List<Reference> references;
  final String difficulty; // Fácil, Médio, Difícil
  final DateTime createdAt;
  final bool isTrending;
  final int usageCount;

  EssayTheme({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.keywords,
    required this.references,
    this.difficulty = 'Médio',
    required this.createdAt,
    this.isTrending = false,
    this.usageCount = 0,
  });

  factory EssayTheme.fromJson(Map<String, dynamic> json) {
    return EssayTheme(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      keywords: List<String>.from(json['keywords']),
      references: (json['references'] as List)
          .map((item) => Reference.fromJson(item))
          .toList(),
      difficulty: json['difficulty'] ?? 'Médio',
      createdAt: DateTime.parse(json['createdAt']),
      isTrending: json['isTrending'] ?? false,
      usageCount: json['usageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'keywords': keywords,
      'references': references.map((item) => item.toJson()).toList(),
      'difficulty': difficulty,
      'createdAt': createdAt.toIso8601String(),
      'isTrending': isTrending,
      'usageCount': usageCount,
    };
  }
}

/// Modelo para referências de apoio
class Reference {
  final String id;
  final String title;
  final String type; // artigo, livro, vídeo, estatística
  final String? url;
  final String? author;
  final String summary;
  final DateTime? publishedAt;

  Reference({
    required this.id,
    required this.title,
    required this.type,
    this.url,
    this.author,
    required this.summary,
    this.publishedAt,
  });

  factory Reference.fromJson(Map<String, dynamic> json) {
    return Reference(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      url: json['url'],
      author: json['author'],
      summary: json['summary'],
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'url': url,
      'author': author,
      'summary': summary,
      'publishedAt': publishedAt?.toIso8601String(),
    };
  }
}

/// Categorias predefinidas de temas
class ThemeCategory {
  static const String atualidades = 'Atualidades';
  static const String meioAmbiente = 'Meio Ambiente';
  static const String tecnologia = 'Tecnologia';
  static const String sociedade = 'Sociedade';
  static const String educacao = 'Educação';
  static const String saude = 'Saúde';
  static const String politica = 'Política';
  static const String economia = 'Economia';
  static const String cultura = 'Cultura';
  static const String direitos = 'Direitos Humanos';

  static List<String> get all => [
    atualidades,
    meioAmbiente,
    tecnologia,
    sociedade,
    educacao,
    saude,
    politica,
    economia,
    cultura,
    direitos,
  ];
}

/// Templates predefinidos
class PredefinedTemplates {
  static EssayTemplate get enem => EssayTemplate(
    id: 'enem_template',
    name: 'ENEM - Dissertativo-Argumentativo',
    type: 'ENEM',
    description: 'Modelo de redação dissertativo-argumentativo do ENEM',
    structure: '''
1. Introdução (1 parágrafo)
   - Contextualização do tema
   - Apresentação da tese

2. Desenvolvimento (2 parágrafos)
   - Primeiro argumento com fundamentação
   - Segundo argumento com fundamentação

3. Conclusão (1 parágrafo)
   - Retomada da tese
   - Proposta de intervenção detalhada
''',
    guidelines: [
      'Respeitar os direitos humanos',
      'Usar norma culta da língua portuguesa',
      'Apresentar proposta de intervenção detalhada',
      'Manter coerência e coesão textual',
      'Demonstrar conhecimento dos mecanismos linguísticos',
    ],
    evaluationCriteria: {
      'Competência 1': 200, // Domínio da norma culta
      'Competência 2': 200, // Compreensão do tema
      'Competência 3': 200, // Argumentação e coesão
      'Competência 4': 200, // Mecanismos linguísticos
      'Competência 5': 200, // Proposta de intervenção
    },
    minWords: 150,
    maxWords: 400,
    estimatedTime: 90,
  );

  static EssayTemplate get vestibular => EssayTemplate(
    id: 'vestibular_template',
    name: 'Vestibular - Dissertativo',
    type: 'Vestibular',
    description: 'Modelo de redação dissertativa para vestibulares',
    structure: '''
1. Introdução
   - Apresentação do tema
   - Posicionamento claro

2. Desenvolvimento
   - Argumentos bem fundamentados
   - Exemplos e evidências

3. Conclusão
   - Síntese dos argumentos
   - Considerações finais
''',
    guidelines: [
      'Manter clareza e objetividade',
      'Usar linguagem formal',
      'Apresentar argumentos consistentes',
      'Demonstrar conhecimento sobre o tema',
    ],
    evaluationCriteria: {
      'Estrutura': 250,
      'Conteúdo': 250,
      'Linguagem': 250,
      'Criatividade': 250,
    },
    minWords: 200,
    maxWords: 500,
    estimatedTime: 75,
  );

  static List<EssayTemplate> get all => [enem, vestibular];
}