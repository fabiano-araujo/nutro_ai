import 'package:flutter/foundation.dart';
import '../models/essay_template_model.dart';
import '../services/essay_template_service.dart';

/// Provider para gerenciar templates e temas de redação
class EssayTemplateProvider with ChangeNotifier {
  final EssayTemplateService _templateService = EssayTemplateService();
  
  List<EssayTemplate> _templates = [];
  List<EssayTheme> _themes = [];
  EssayTemplate? _selectedTemplate;
  EssayTheme? _selectedTheme;
  String _selectedCategory = '';
  bool _isLoading = false;
  String? _error;

  // Getters
  List<EssayTemplate> get templates => _templates;
  List<EssayTheme> get themes => _themes;
  EssayTemplate? get selectedTemplate => _selectedTemplate;
  EssayTheme? get selectedTheme => _selectedTheme;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Inicializa o provider
  Future<void> initialize() async {
    _setLoading(true);
    try {
      _templateService.initialize();
      await _loadTemplates();
      await _loadThemes();
      _error = null;
    } catch (e) {
      _error = 'Erro ao carregar dados: $e';
      print('Erro na inicialização do EssayTemplateProvider: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega todos os templates
  Future<void> _loadTemplates() async {
    try {
      _templates = _templateService.getTemplates();
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar templates: $e');
      _error = 'Erro ao carregar templates';
    }
  }

  /// Carrega todos os temas
  Future<void> _loadThemes() async {
    try {
      _themes = _templateService.getThemes();
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar temas: $e');
      _error = 'Erro ao carregar temas';
    }
  }

  /// Obtém templates por tipo
  List<EssayTemplate> getTemplatesByType(String type) {
    return _templateService.getTemplatesByType(type);
  }

  /// Obtém temas por categoria
  List<EssayTheme> getThemesByCategory(String category) {
    return _templateService.getThemesByCategory(category);
  }

  /// Obtém temas em alta
  List<EssayTheme> getTrendingThemes() {
    return _templateService.getTrendingThemes();
  }

  /// Obtém temas sugeridos baseados no histórico do usuário
  List<EssayTheme> getSuggestedThemes(List<String> userCategories) {
    return _templateService.getSuggestedThemes(userCategories);
  }

  /// Busca temas por palavra-chave
  List<EssayTheme> searchThemes(String query) {
    if (query.trim().isEmpty) {
      return _themes;
    }
    return _templateService.searchThemes(query);
  }

  /// Seleciona um template
  void selectTemplate(EssayTemplate? template) {
    _selectedTemplate = template;
    notifyListeners();
  }

  /// Seleciona um tema
  void selectTheme(EssayTheme? theme) {
    _selectedTheme = theme;
    if (theme != null) {
      _templateService.incrementThemeUsage(theme.id);
    }
    notifyListeners();
  }

  /// Define a categoria selecionada
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Obtém um tema aleatório
  EssayTheme getRandomTheme({String? category}) {
    return _templateService.getRandomTheme(category: category);
  }

  /// Obtém template por ID
  EssayTemplate? getTemplateById(String id) {
    return _templateService.getTemplateById(id);
  }

  /// Obtém tema por ID
  EssayTheme? getThemeById(String id) {
    return _templateService.getThemeById(id);
  }

  /// Obtém referências de um tema
  List<Reference> getThemeReferences(String themeId) {
    return _templateService.getThemeReferences(themeId);
  }

  /// Obtém todas as categorias disponíveis
  List<String> getAvailableCategories() {
    return ThemeCategory.all;
  }

  /// Obtém estatísticas dos templates
  Map<String, dynamic> getTemplateStats() {
    return _templateService.getTemplateStats();
  }

  /// Obtém estatísticas dos temas
  Map<String, dynamic> getThemeStats() {
    return _templateService.getThemeStats();
  }

  /// Limpa seleções
  void clearSelections() {
    _selectedTemplate = null;
    _selectedTheme = null;
    _selectedCategory = '';
    notifyListeners();
  }

  /// Recarrega dados
  Future<void> refresh() async {
    await initialize();
  }

  /// Define estado de loading
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Obtém temas filtrados por dificuldade
  List<EssayTheme> getThemesByDifficulty(String difficulty) {
    return _themes
        .where((theme) => theme.difficulty.toLowerCase() == difficulty.toLowerCase())
        .toList();
  }

  /// Obtém temas mais usados
  List<EssayTheme> getMostUsedThemes({int limit = 10}) {
    final sortedThemes = List<EssayTheme>.from(_themes);
    sortedThemes.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sortedThemes.take(limit).toList();
  }

  /// Obtém temas recentes
  List<EssayTheme> getRecentThemes({int limit = 10}) {
    final sortedThemes = List<EssayTheme>.from(_themes);
    sortedThemes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedThemes.take(limit).toList();
  }

  /// Verifica se um template é adequado para um nível específico
  bool isTemplateAppropriate(EssayTemplate template, String userLevel) {
    // Lógica para determinar se o template é apropriado
    // baseado no nível do usuário (iniciante, intermediário, avançado)
    switch (userLevel.toLowerCase()) {
      case 'iniciante':
        return template.type == 'Livre' || template.minWords <= 200;
      case 'intermediário':
        return template.type != 'Concurso';
      case 'avançado':
        return true;
      default:
        return true;
    }
  }

  /// Obtém recomendações personalizadas
  Map<String, List<dynamic>> getPersonalizedRecommendations({
    String userLevel = 'intermediário',
    List<String> preferredCategories = const [],
    List<String> recentTypes = const [],
  }) {
    // Templates recomendados
    final recommendedTemplates = _templates
        .where((template) => isTemplateAppropriate(template, userLevel))
        .toList();

    // Temas recomendados baseados nas categorias preferidas
    List<EssayTheme> recommendedThemes;
    if (preferredCategories.isNotEmpty) {
      recommendedThemes = [];
      for (final category in preferredCategories) {
        recommendedThemes.addAll(getThemesByCategory(category).take(3));
      }
    } else {
      recommendedThemes = getTrendingThemes().take(5).toList();
    }

    return {
      'templates': recommendedTemplates,
      'themes': recommendedThemes,
      'trendingThemes': getTrendingThemes().take(3).toList(),
      'recentThemes': getRecentThemes().take(3).toList(),
    };
  }
}