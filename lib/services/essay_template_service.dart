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
    return getThemes().where((theme) => theme.isTrending).toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
  }

  /// Obtém temas por categoria
  List<EssayTheme> getThemesByCategory(String category) {
    return getThemes()
        .where(
            (theme) => theme.category.toLowerCase() == category.toLowerCase())
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
          theme.keywords
              .any((keyword) => keyword.toLowerCase().contains(lowercaseQuery));
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
        name: 'i18n:essay_template_enem_name',
        type: 'ENEM',
        description: 'i18n:essay_template_enem_description',
        structure: 'i18n:essay_template_enem_structure',
        guidelines: [
          'i18n:essay_guideline_respect_human_rights',
          'i18n:essay_guideline_standard_language',
          'i18n:essay_guideline_coherence_cohesion',
          'i18n:essay_guideline_sociocultural_repertoire',
          'i18n:essay_guideline_complete_intervention',
          'i18n:essay_guideline_do_not_copy_sources',
          'i18n:essay_guideline_impersonal_tone',
        ],
        evaluationCriteria: {
          'i18n:essay_criterion_enem_language': 200,
          'i18n:essay_criterion_enem_theme': 200,
          'i18n:essay_criterion_enem_argumentation': 200,
          'i18n:essay_criterion_enem_cohesion': 200,
          'i18n:essay_criterion_enem_intervention': 200,
        },
        minWords: 150,
        maxWords: 400,
        estimatedTime: 90,
      ),

      // Template Vestibular
      EssayTemplate(
        id: 'vestibular_dissertativo',
        name: 'i18n:essay_template_vestibular_name',
        type: 'Vestibular',
        description: 'i18n:essay_template_vestibular_description',
        structure: 'i18n:essay_template_vestibular_structure',
        guidelines: [
          'i18n:essay_guideline_clarity_objectivity',
          'i18n:essay_guideline_formal_language',
          'i18n:essay_guideline_consistent_arguments',
          'i18n:essay_guideline_theme_knowledge',
          'i18n:essay_guideline_avoid_generalizations',
          'i18n:essay_guideline_section_consistency',
        ],
        evaluationCriteria: {
          'i18n:essay_criterion_structure_organization': 250,
          'i18n:essay_criterion_content_argumentation': 250,
          'i18n:essay_criterion_language_style': 250,
          'i18n:essay_criterion_creativity_originality': 250,
        },
        minWords: 200,
        maxWords: 500,
        estimatedTime: 75,
      ),

      // Template Concurso
      EssayTemplate(
        id: 'concurso_dissertativo',
        name: 'i18n:essay_template_public_exam_name',
        type: 'Concurso',
        description: 'i18n:essay_template_public_exam_description',
        structure: 'i18n:essay_template_public_exam_structure',
        guidelines: [
          'i18n:essay_guideline_technical_language',
          'i18n:essay_guideline_area_knowledge',
          'i18n:essay_guideline_current_data',
          'i18n:essay_guideline_objective_impartial',
          'i18n:essay_guideline_logical_structure',
          'i18n:essay_guideline_avoid_unsupported_opinions',
        ],
        evaluationCriteria: {
          'i18n:essay_criterion_technical_knowledge': 300,
          'i18n:essay_criterion_structure_organization': 250,
          'i18n:essay_criterion_language_accuracy': 250,
          'i18n:essay_criterion_critical_analysis': 200,
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
        title: 'i18n:essay_theme_social_media_title',
        description: 'i18n:essay_theme_social_media_description',
        category: ThemeCategory.tecnologia,
        keywords: [
          'i18n:essay_keyword_social_media',
          'i18n:essay_keyword_public_opinion',
          'i18n:essay_keyword_democracy',
          'i18n:essay_keyword_fake_news',
          'i18n:essay_keyword_polarization',
        ],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'i18n:essay_reference_social_dilemma_title',
            type: 'i18n:essay_reference_type_documentary',
            summary: 'i18n:essay_reference_social_dilemma_summary',
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
        title: 'i18n:essay_theme_digital_education_title',
        description: 'i18n:essay_theme_digital_education_description',
        category: ThemeCategory.educacao,
        keywords: [
          'i18n:essay_keyword_digital_education',
          'i18n:essay_keyword_technology',
          'i18n:essay_keyword_digital_inclusion',
          'i18n:essay_keyword_remote_learning',
        ],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'i18n:essay_reference_digital_education_title',
            type: 'i18n:essay_reference_type_article',
            summary: 'i18n:essay_reference_digital_education_summary',
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
        title: 'i18n:essay_theme_urban_sustainability_title',
        description: 'i18n:essay_theme_urban_sustainability_description',
        category: ThemeCategory.meioAmbiente,
        keywords: [
          'i18n:essay_keyword_sustainability',
          'i18n:essay_keyword_cities',
          'i18n:essay_keyword_quality_of_life',
          'i18n:essay_keyword_urban_environment',
        ],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'i18n:essay_reference_sustainable_cities_title',
            type: 'i18n:essay_reference_type_report',
            summary: 'i18n:essay_reference_sustainable_cities_summary',
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
        title: 'i18n:essay_theme_empathy_title',
        description: 'i18n:essay_theme_empathy_description',
        category: ThemeCategory.sociedade,
        keywords: [
          'i18n:essay_keyword_empathy',
          'i18n:essay_keyword_social_justice',
          'i18n:essay_keyword_inequality',
          'i18n:essay_keyword_solidarity',
        ],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'i18n:essay_reference_empathy_age_title',
            type: 'i18n:essay_reference_type_book',
            summary: 'i18n:essay_reference_empathy_age_summary',
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
        title: 'i18n:essay_theme_youth_mental_health_title',
        description: 'i18n:essay_theme_youth_mental_health_description',
        category: ThemeCategory.saude,
        keywords: [
          'i18n:essay_keyword_mental_health',
          'i18n:essay_keyword_youth',
          'i18n:essay_keyword_technology',
          'i18n:essay_keyword_anxiety',
          'i18n:essay_keyword_depression',
        ],
        references: [
          Reference(
            id: _uuid.v4(),
            title: 'i18n:essay_reference_adolescent_mental_health_title',
            type: 'i18n:essay_reference_type_study',
            summary: 'i18n:essay_reference_adolescent_mental_health_summary',
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
      title: 'i18n:essay_theme_education_transformation_title',
      description: 'i18n:essay_theme_education_transformation_description',
      category: ThemeCategory.educacao,
      keywords: [
        'i18n:essay_keyword_education',
        'i18n:essay_keyword_social_transformation',
        'i18n:essay_keyword_development',
      ],
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
