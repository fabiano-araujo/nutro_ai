import 'dart:convert';
import 'dart:math';
import '../models/essay_template_model.dart';
import 'package:uuid/uuid.dart';

/// Serviço para gerenciar templates e temas de redação
class EssayTemplateService {
  final Uuid _uuid = const Uuid();
  
  // Cache local de templates e temas
  List<EssayTemplate> _templates = [];
  List<EssayTheme> _themes = [];
  
  /// Inicializa o serviço com dados padrão
  void initialize() {
    _loadDefaultTemplates();
    _loadDefaultThemes();
  }

  /// Obtém todos os templates disponíveis
  List<EssayTemplate> getTemplates() {
    if (_templates.isEmpty) {
      _loadDefaultTemplates();
    }
    return _templates.where((template) => template.isActive).toList();
  }

  /// Obtém templates por tipo
  List<EssayTemplate> getTemplatesByType(String type) {
    return getTemplates()
        .where((template) => template.type.toLowerCase() == type.toLowerCase())
        .toList();
  }

  /// Obtém um template específico por ID
  EssayTemplate? getTemplateById(String id) {
    try {
      return _templates.firstWhere((template) => template.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtém todos os temas disponíveis
  List<EssayTheme> getThemes() {
    if (_themes.isEmpty) {
      _loadDefaultThemes();
    }
    return _themes;
  }

  /// Obtém temas em alta (trending)
  List<EssayTheme> getTrendingThemes() {
    return getThemes()
        .where((theme) => theme.isTrending)
        .toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
  }

  /// Obtém temas por categoria
  List<EssayTheme> getThemesByCategory(String category) {
    return getThemes()
        .where((theme) => theme.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Obtém um tema aleatório
  EssayTheme getRandomTheme({String? category}) {
    List<EssayTheme> availableThemes;
    
    if (category != null) {
      availableThemes = getThemesByCategory(category);
    } else {
      availableThemes = getThemes();
    }
    
    if (availableThemes.isEmpty) {
      return _createFallbackTheme();
    }
    
    final random = Random();
    return availableThemes[random.nextInt(availableThemes.length)];
  }

  /// Obtém um tema específico por ID
  EssayTheme? getThemeById(String id) {
    try {
      return _themes.firstWhere((theme) => theme.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtém referências de um tema
  List<Reference> getThemeReferences(String themeId) {
    final theme = getThemeById(themeId);
    return theme?.references ?? [];
  }

  /// Incrementa o contador de uso de um tema
  void incrementThemeUsage(String themeId) {
    final themeIndex = _themes.indexWhere((theme) => theme.id == themeId);
    if (themeIndex != -1) {
      // Em uma implementação real, isso seria persistido
      print('Incrementando uso do tema: $themeId');
    }
  }

  /// Busca temas por palavra-chave
  List<EssayTheme> searchThemes(String query) {
    final lowercaseQuery = query.toLowerCase();
    
    return getThemes().where((theme) {
      return theme.title.toLowerCase().contains(lowercaseQuery) ||
             theme.description.toLowerCase().contains(lowercaseQuery) ||
             theme.keywords.any((keyword) => 
                 keyword.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  /// Obtém sugestões de temas baseadas no histórico do usuário
  List<EssayTheme> getSuggestedThemes(List<String> userCategories) {
    if (userCategories.isEmpty) {
      return getTrendingThemes().take(5).toList();
    }
    
    final suggestions = <EssayTheme>[];
    
    // Adicionar temas das categorias preferidas do usuário
    for (final category in userCategories) {
      final categoryThemes = getThemesByCategory(category);
      suggestions.addAll(categoryThemes.take(2));
    }
    
    // Adicionar alguns temas trending
    final trending = getTrendingThemes();
    for (final theme in trending) {
      if (!suggestions.contains(theme) && suggestions.length < 8) {
        suggestions.add(theme);
      }
    }
    
    return suggestions;
  }

  /// Carrega templates padrão
  void _loadDefaultTemplates() {
    _templates = [
      // Template ENEM
      EssayTemplate(
        id: 'enem_dissertativo',
        name: 'ENEM - Dissertativo-Argumentativo',
        type: 'ENEM',
        description: 'Modelo oficial de redação do ENEM com foco em dissertação-argumentativa',
        structure: '''
1. INTRODUÇÃO (1 parágrafo - 4 a 5 linhas)
   • Contextualização do tema
   • Apresentação da tese (seu posicionamento)

2. DESENVOLVIMENTO (2 parágrafos - 6 a 8 linhas cada)
   • 1º parágrafo: Primeiro argumento + fundamentação + exemplo
   • 2º parágrafo: Segundo argumento + fundamentação + exemplo

3. CONCLUSÃO (1 parágrafo - 4 a 6 linhas)
   • Retomada da tese
   • Proposta de intervenção detalhada (agente + ação + meio + finalidade + detalhamento)
''',
        guidelines: [
          'Respeitar os direitos humanos em toda a argumentação',
          'Usar a norma culta da língua portuguesa',
          'Manter coerência e coesão textual',
          'Apresentar repertório sociocultural produtivo',
          'Elaborar proposta de intervenção completa e detalhada',
          'Não copiar trechos dos textos motivadores',
          'Manter impessoalidade (evitar 1ª pessoa)',
        ],
        evaluationCriteria: {
          'Competência 1 - Norma Culta': 200,
          'Competência 2 - Compreensão do Tema': 200,
          'Competência 3 - Argumentação': 200,
          'Competência 4 - Coesão': 200,
          'Competência 5 - Proposta de Intervenção': 200,
        },
        minWords: 150,
        maxWords: 400,
        estimatedTime: 90,
      ),
      
      // Template Vestibular
      EssayTemplate(
        id: 'vestibular_dissertativo',
        name: 'Vestibular - Dissertativo',
        type: 'Vestibular',
        description: 'Modelo para redações dissertativas de vestibulares em geral',
        structure: '''
1. INTRODUÇÃO
   • Apresentação do tema
   • Contextualização
   • Tese clara e objetiva

2. DESENVOLVIMENTO (2 ou 3 parágrafos)
   • Argumentos bem fundamentados
   • Exemplos e evidências
   • Progressão lógica das ideias

3. CONCLUSÃO
   • Síntese dos argumentos principais
   • Reafirmação da tese
   • Considerações finais ou propostas
''',
        guidelines: [
          'Manter clareza e objetividade',
          'Usar linguagem formal e adequada',
          'Apresentar argumentos consistentes e bem fundamentados',
          'Demonstrar conhecimento sobre o tema',
          'Evitar generalizações e senso comum',
          'Manter coerência entre introdução, desenvolvimento e conclusão',
        ],
        evaluationCriteria: {
          'Estrutura e Organização': 250,
          'Conteúdo e Argumentação': 250,
          'Linguagem e Estilo': 250,
          'Criatividade e Originalidade': 250,
        },
        minWords: 200,
        maxWords: 500,
        estimatedTime: 75,
      ),
      
      // Template Concurso
      EssayTemplate(
        id: 'concurso_dissertativo',
        name: 'Concurso - Dissertativo',
        type: 'Concurso',
        description: 'Modelo para redações de concursos públicos',
        structure: '''
1. INTRODUÇÃO
   • Definição ou contextualização do tema
   • Apresentação da problemática
   • Tese ou posicionamento

2. DESENVOLVIMENTO
   • Análise crítica do problema
   • Argumentos técnicos e jurídicos (quando aplicável)
   • Exemplos práticos e dados

3. CONCLUSÃO
   • Síntese da análise
   • Propostas de solução
   • Considerações finais
''',
        guidelines: [
          'Usar linguagem técnica e precisa',
          'Demonstrar conhecimento específico da área',
          'Apresentar dados e informações atualizadas',
          'Manter objetividade e imparcialidade',
          'Seguir estrutura lógica e clara',
          'Evitar opiniões pessoais sem fundamentação',
        ],
        evaluationCriteria: {
          'Conhecimento Técnico': 300,
          'Estrutura e Organização': 250,
          'Linguagem e Correção': 250,
          'Análise Crítica': 200,
        },
        minWords: 250,
        maxWords: 600,
        estimatedTime: 90,
      ),
    ];
  }

  /// Carrega temas padrão
  void _loadDefaultThemes() {
    _themes = [
      // Temas de Atualidades
      EssayTheme(
        id: _uuid.v4(),
        title: 'O impacto das redes sociais na formação da opinião pública',
        description: 'Analise como as redes sociais influenciam a formação de opiniões e o debate público na sociedade contemporânea.',
        category: ThemeCategory.tecnologia,
        keywords: ['redes sociais', 'opinião pública', 'democracia', 'fake news', 'polarização'],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'O dilema das redes sociais',
            type: 'documentário',
            summary: 'Documentário que explora os impactos das redes sociais na sociedade',
            author: 'Netflix',
          ),
        ],
        difficulty: 'Médio',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isTrending: true,
        usageCount: 150,
      ),
      
      EssayTheme(
        id: _uuid.v4(),
        title: 'Desafios da educação digital no Brasil',
        description: 'Discuta os principais desafios para implementação e democratização da educação digital no país.',
        category: ThemeCategory.educacao,
        keywords: ['educação digital', 'tecnologia', 'inclusão digital', 'ensino remoto'],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'Educação na era digital',
            type: 'artigo',
            summary: 'Análise sobre os desafios da educação digital no Brasil',
            author: 'MEC',
          ),
        ],
        difficulty: 'Médio',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        isTrending: true,
        usageCount: 120,
      ),
      
      // Temas de Meio Ambiente
      EssayTheme(
        id: _uuid.v4(),
        title: 'Sustentabilidade urbana e qualidade de vida',
        description: 'Analise a relação entre práticas sustentáveis nas cidades e a melhoria da qualidade de vida dos cidadãos.',
        category: ThemeCategory.meioAmbiente,
        keywords: ['sustentabilidade', 'cidades', 'qualidade de vida', 'meio ambiente urbano'],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'Cidades sustentáveis',
            type: 'relatório',
            summary: 'Relatório sobre práticas sustentáveis em centros urbanos',
            author: 'ONU Habitat',
          ),
        ],
        difficulty: 'Médio',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        isTrending: false,
        usageCount: 80,
      ),
      
      // Temas de Sociedade
      EssayTheme(
        id: _uuid.v4(),
        title: 'A importância da empatia na construção de uma sociedade mais justa',
        description: 'Discuta como o desenvolvimento da empatia pode contribuir para reduzir desigualdades e promover justiça social.',
        category: ThemeCategory.sociedade,
        keywords: ['empatia', 'justiça social', 'desigualdade', 'solidariedade'],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'A era da empatia',
            type: 'livro',
            summary: 'Obra sobre a importância da empatia na sociedade moderna',
            author: 'Jeremy Rifkin',
          ),
        ],
        difficulty: 'Fácil',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        isTrending: true,
        usageCount: 200,
      ),
      
      // Temas de Saúde
      EssayTheme(
        id: _uuid.v4(),
        title: 'Saúde mental dos jovens na era digital',
        description: 'Analise os impactos da tecnologia e das redes sociais na saúde mental dos jovens brasileiros.',
        category: ThemeCategory.saude,
        keywords: ['saúde mental', 'jovens', 'tecnologia', 'ansiedade', 'depressão'],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'Saúde mental na adolescência',
            type: 'estudo',
            summary: 'Pesquisa sobre saúde mental de adolescentes no Brasil',
            author: 'UNICEF Brasil',
          ),
        ],
        difficulty: 'Médio',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        isTrending: true,
        usageCount: 95,
      ),
    ];
  }

  /// Cria um tema de fallback quando não há temas disponíveis
  EssayTheme _createFallbackTheme() {
    return EssayTheme(
      id: _uuid.v4(),
      title: 'A importância da educação na transformação social',
      description: 'Discuta como a educação pode ser um instrumento de transformação e desenvolvimento social.',
      category: ThemeCategory.educacao,
      keywords: ['educação', 'transformação social', 'desenvolvimento'],
      references: [],
      difficulty: 'Médio',
      createdAt: DateTime.now(),
      isTrending: false,
      usageCount: 0,
    );
  }

  /// Obtém estatísticas dos templates
  Map<String, dynamic> getTemplateStats() {
    final stats = <String, dynamic>{};
    
    for (final template in _templates) {
      stats[template.type] = (stats[template.type] ?? 0) + 1;
    }
    
    return {
      'totalTemplates': _templates.length,
      'activeTemplates': _templates.where((t) => t.isActive).length,
      'byType': stats,
    };
  }

  /// Obtém estatísticas dos temas
  Map<String, dynamic> getThemeStats() {
    final stats = <String, dynamic>{};
    
    for (final theme in _themes) {
      stats[theme.category] = (stats[theme.category] ?? 0) + 1;
    }
    
    return {
      'totalThemes': _themes.length,
      'trendingThemes': _themes.where((t) => t.isTrending).length,
      'byCategory': stats,
      'totalUsage': _themes.fold(0, (sum, theme) => sum + theme.usageCount),
    };
  }
}