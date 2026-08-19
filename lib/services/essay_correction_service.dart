import 'dart:convert';
import 'dart:math';
import '../models/essay_model.dart';
import '../models/essay_correction_model.dart';
import '../services/ai_service.dart';
import 'package:uuid/uuid.dart';

/// Serviço para correção automática de redações usando IA
class EssayCorrectionService {
  final AIService _aiService = AIService();
  final Uuid _uuid = const Uuid();

  /// Corrige uma redação completa usando IA
  Future<EssayCorrection> correctEssay(
    Essay essay, {
    String languageCode = 'pt_BR',
    String quality = 'bom',
    String userId = '',
  }) async {
    try {
      print('🔍 Iniciando correção da redação: ${essay.title}');
      
      // Gerar prompt específico para correção de redação
      final correctionPrompt = _buildCorrectionPrompt(essay);
      
      // Obter análise da IA
      final aiResponse = await _getAIAnalysis(
        correctionPrompt,
        languageCode: languageCode,
        quality: quality,
        userId: userId,
      );
      
      // Processar resposta da IA e gerar correção estruturada
      final correction = await _processAIResponse(essay, aiResponse);
      
      print('✅ Correção concluída para redação: ${essay.title}');
      return correction;
      
    } catch (e) {
      print('❌ Erro na correção da redação: $e');
      // Retornar correção básica em caso de erro
      return _generateFallbackCorrection(essay);
    }
  }

  /// Gera sugestões específicas para melhoria da redação
  Future<List<EssaySuggestion>> generateSuggestions(
    Essay essay, {
    String languageCode = 'pt_BR',
    String quality = 'mediano',
    String userId = '',
  }) async {
    try {
      print('💡 Gerando sugestões para redação: ${essay.title}');
      
      final suggestionsPrompt = _buildSuggestionsPrompt(essay);
      
      final aiResponse = await _getAIAnalysis(
        suggestionsPrompt,
        languageCode: languageCode,
        quality: quality,
        userId: userId,
      );
      
      final suggestions = _processSuggestionsResponse(aiResponse);
      
      print('✅ ${suggestions.length} sugestões geradas');
      return suggestions;
      
    } catch (e) {
      print('❌ Erro ao gerar sugestões: $e');
      return _generateFallbackSuggestions(essay);
    }
  }

  /// Compara redação com modelo de referência
  Future<Map<String, dynamic>> compareWithModel(
    Essay essay,
    String essayType, {
    String languageCode = 'pt_BR',
    String userId = '',
  }) async {
    try {
      final comparisonPrompt = _buildComparisonPrompt(essay, essayType);
      
      final aiResponse = await _getAIAnalysis(
        comparisonPrompt,
        languageCode: languageCode,
        quality: 'bom',
        userId: userId,
      );
      
      return _processComparisonResponse(aiResponse);
      
    } catch (e) {
      print('❌ Erro na comparação com modelo: $e');
      return {'similarity': 0.7, 'differences': [], 'recommendations': []};
    }
  }

  /// Constrói prompt específico para correção de redação
  String _buildCorrectionPrompt(Essay essay) {
    return '''
Você é um professor especialista em correção de redações ${essay.type}. 
Analise a redação abaixo e forneça uma correção detalhada seguindo os critérios específicos.

REDAÇÃO PARA ANÁLISE:
Título: ${essay.title}
Tipo: ${essay.type}
Texto: ${essay.text}

INSTRUÇÕES DE CORREÇÃO:
1. Avalie cada competência específica do ${essay.type}
2. Atribua pontuação de 0 a 200 para cada competência
3. Identifique pontos fortes e fracos específicos
4. Forneça comentários construtivos e detalhados
5. Sugira melhorias práticas e específicas

${_getEvaluationCriteria(essay.type)}

FORMATO DE RESPOSTA ESPERADO:
{
  "totalScore": [pontuação total],
  "competencyScores": {
    "Competência 1": [pontuação],
    "Competência 2": [pontuação],
    "Competência 3": [pontuação],
    "Competência 4": [pontuação],
    "Competência 5": [pontuação]
  },
  "feedback": [
    {
      "competency": "Competência 1",
      "score": [pontuação],
      "summary": "[resumo da avaliação]",
      "comments": [
        {
          "aspect": "[aspecto específico]",
          "comment": "[comentário detalhado]",
          "type": "positive|negative|neutral"
        }
      ],
      "tips": [
        {
          "category": "[categoria da dica]",
          "tip": "[dica específica]",
          "priority": "low|medium|high|critical"
        }
      ]
    }
  ]
}

Seja específico, construtivo e educativo em sua análise.
''';
  }

  /// Constrói prompt para geração de sugestões
  String _buildSuggestionsPrompt(Essay essay) {
    return '''
Analise o texto abaixo e forneça sugestões específicas de melhoria:

TEXTO: ${essay.text}

Identifique:
1. Erros gramaticais e ortográficos
2. Problemas de coesão e coerência
3. Oportunidades de melhoria estilística
4. Sugestões de vocabulário mais adequado
5. Melhorias na estrutura argumentativa

Para cada sugestão, forneça:
- Texto original problemático
- Texto sugerido como melhoria
- Explicação clara da melhoria
- Posição no texto (aproximada)
- Prioridade da correção

Formato JSON esperado:
{
  "suggestions": [
    {
      "type": "grammar|style|structure|content|vocabulary",
      "originalText": "[texto original]",
      "suggestedText": "[texto sugerido]",
      "explanation": "[explicação da melhoria]",
      "priority": "low|medium|high|critical"
    }
  ]
}
''';
  }

  /// Constrói prompt para comparação com modelo
  String _buildComparisonPrompt(Essay essay, String essayType) {
    return '''
Compare a redação abaixo com os padrões de excelência para redações do tipo $essayType:

REDAÇÃO: ${essay.text}

Analise:
1. Estrutura comparada ao modelo ideal
2. Qualidade da argumentação
3. Uso de conectivos e coesão
4. Adequação ao gênero textual
5. Cumprimento dos requisitos específicos

Forneça:
- Percentual de similaridade com modelo ideal (0-100%)
- Principais diferenças identificadas
- Recomendações específicas para aproximar do modelo

Formato JSON:
{
  "similarity": [0-100],
  "differences": ["diferença 1", "diferença 2"],
  "recommendations": ["recomendação 1", "recomendação 2"]
}
''';
  }

  /// Obtém critérios de avaliação específicos por tipo de redação
  String _getEvaluationCriteria(String essayType) {
    switch (essayType.toUpperCase()) {
      case 'ENEM':
        return '''
CRITÉRIOS DE AVALIAÇÃO ENEM:
- Competência 1 (0-200): Domínio da modalidade escrita formal da língua portuguesa
- Competência 2 (0-200): Compreender a proposta de redação e aplicar conceitos das várias áreas de conhecimento
- Competência 3 (0-200): Selecionar, relacionar, organizar e interpretar informações, fatos, opiniões e argumentos
- Competência 4 (0-200): Demonstrar conhecimento dos mecanismos linguísticos necessários para a construção da argumentação
- Competência 5 (0-200): Elaborar proposta de intervenção para o problema abordado, respeitando os direitos humanos
''';
      case 'VESTIBULAR':
        return '''
CRITÉRIOS DE AVALIAÇÃO VESTIBULAR:
- Estrutura (0-250): Organização lógica e coerente do texto
- Conteúdo (0-250): Qualidade e relevância das ideias apresentadas
- Linguagem (0-250): Correção gramatical e adequação vocabular
- Criatividade (0-250): Originalidade e criatividade na abordagem
''';
      default:
        return '''
CRITÉRIOS GERAIS DE AVALIAÇÃO:
- Estrutura e organização textual
- Qualidade do conteúdo e argumentação
- Correção linguística e estilística
- Adequação ao gênero e proposta
- Coerência e coesão textual
''';
    }
  }

  /// Chama o serviço de IA para análise
  Future<String> _getAIAnalysis(
    String prompt, {
    required String languageCode,
    required String quality,
    required String userId,
  }) async {
    // Usar o método de stream do AIService e coletar toda a resposta
    final buffer = StringBuffer();
    
    await for (final chunk in _aiService.getAnswerStream(
      prompt,
      subject: 'Correção de Redação',
      languageCode: languageCode,
      quality: quality,
      userId: userId,
    )) {
      buffer.write(chunk);
    }
    
    return buffer.toString();
  }

  /// Processa resposta da IA para correção
  Future<EssayCorrection> _processAIResponse(Essay essay, String aiResponse) async {
    try {
      // Tentar extrair JSON da resposta
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(aiResponse);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final data = jsonDecode(jsonString);
        
        return EssayCorrection(
          id: _uuid.v4(),
          essayId: essay.id,
          totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
          competencyScores: Map<String, int>.from(data['competencyScores'] ?? {}),
          feedback: _processFeedbackData(data['feedback'] ?? []),
          suggestions: [], // Será preenchido separadamente
          correctedAt: DateTime.now(),
          correctionVersion: '1.0',
        );
      }
    } catch (e) {
      print('❌ Erro ao processar resposta JSON da IA: $e');
    }
    
    // Fallback: gerar correção baseada na análise textual
    return _generateCorrectionFromText(essay, aiResponse);
  }

  /// Processa dados de feedback da resposta da IA
  List<DetailedFeedback> _processFeedbackData(List<dynamic> feedbackData) {
    return feedbackData.map((item) {
      return DetailedFeedback(
        competency: item['competency'] ?? 'Geral',
        score: (item['score'] as num?)?.toInt() ?? 0,
        summary: item['summary'] ?? 'Análise não disponível',
        comments: _processCommentsData(item['comments'] ?? []),
        tips: _processTipsData(item['tips'] ?? []),
      );
    }).toList();
  }

  /// Processa comentários específicos
  List<SpecificComment> _processCommentsData(List<dynamic> commentsData) {
    return commentsData.map((item) {
      return SpecificComment(
        text: item['comment'] ?? item['text'] ?? '',
        type: _parseCommentType(item['type']),
        startPosition: (item['startPosition'] as num?)?.toInt(),
        endPosition: (item['endPosition'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// Processa dicas de melhoria
  List<ImprovementTip> _processTipsData(List<dynamic> tipsData) {
    return tipsData.map((item) {
      return ImprovementTip(
        title: item['title'] ?? item['category'] ?? 'Geral',
        description: item['description'] ?? item['tip'] ?? '',
        category: item['category'] ?? 'Geral',
        priority: _parseTipPriority(item['priority']),
      );
    }).toList();
  }

  /// Processa resposta de sugestões
  List<EssaySuggestion> _processSuggestionsResponse(String aiResponse) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(aiResponse);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        final data = jsonDecode(jsonString);
        final suggestions = data['suggestions'] as List<dynamic>;
        
        return suggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          return EssaySuggestion(
            type: _parseSuggestionType(item['type']),
            originalText: item['originalText'] ?? '',
            suggestedText: item['suggestedText'] ?? '',
            explanation: item['explanation'] ?? '',
            startPosition: index * 10, // Posição aproximada
            endPosition: (index * 10) +
                ((item['originalText'] as String?)?.length ?? 10),
            priority: _parseSuggestionPriority(item['priority']),
          );
        }).toList();
      }
    } catch (e) {
      print('❌ Erro ao processar sugestões: $e');
    }
    
    return _generateFallbackSuggestions(null);
  }

  /// Processa resposta de comparação
  Map<String, dynamic> _processComparisonResponse(String aiResponse) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(aiResponse);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0)!;
        return jsonDecode(jsonString);
      }
    } catch (e) {
      print('❌ Erro ao processar comparação: $e');
    }
    
    return {
      'similarity': 75,
      'differences': ['Estrutura pode ser aprimorada', 'Argumentação precisa de mais fundamentação'],
      'recommendations': ['Melhorar conectivos', 'Adicionar mais exemplos']
    };
  }

  /// Gera correção a partir de análise textual (fallback)
  EssayCorrection _generateCorrectionFromText(Essay essay, String analysis) {
    // Análise básica do texto para gerar pontuação
    final wordCount = essay.wordCount;
    final hasGoodStructure = _analyzeStructure(essay.text);
    final hasGoodArguments = _analyzeArguments(essay.text);
    
    // Calcular pontuações baseadas em análise simples
    final scores = _calculateBasicScores(essay, hasGoodStructure, hasGoodArguments);
    
    return EssayCorrection(
      id: _uuid.v4(),
      essayId: essay.id,
      totalScore: scores.values.reduce((a, b) => a + b),
      competencyScores: scores,
      feedback: _generateBasicFeedback(scores, analysis),
      suggestions: [],
      correctedAt: DateTime.now(),
      correctionVersion: '1.0',
    );
  }

  /// Gera correção de fallback em caso de erro
  EssayCorrection _generateFallbackCorrection(Essay essay) {
    final basicScores = {
      'Competência 1': 140,
      'Competência 2': 150,
      'Competência 3': 130,
      'Competência 4': 140,
      'Competência 5': 120,
    };
    
    return EssayCorrection(
      id: _uuid.v4(),
      essayId: essay.id,
      totalScore: 680,
      competencyScores: basicScores,
      feedback: _generateBasicFeedback(basicScores, 'Análise básica da redação.'),
      suggestions: _generateFallbackSuggestions(essay),
      correctedAt: DateTime.now(),
      correctionVersion: '1.0',
    );
  }

  /// Gera sugestões de fallback
  List<EssaySuggestion> _generateFallbackSuggestions(Essay? essay) {
    return [
      EssaySuggestion(
        type: 'structure',
        originalText: 'Estrutura geral',
        suggestedText: 'Melhore a organização dos parágrafos',
        explanation: 'Uma boa estrutura facilita a compreensão do texto',
        startPosition: 0,
        endPosition: 10,
        priority: SuggestionPriority.medium,
      ),
      EssaySuggestion(
        type: 'content',
        originalText: 'Argumentação',
        suggestedText: 'Adicione mais exemplos e fundamentação',
        explanation: 'Argumentos bem fundamentados tornam o texto mais convincente',
        startPosition: 50,
        endPosition: 60,
        priority: SuggestionPriority.high,
      ),
    ];
  }

  /// Métodos auxiliares para análise básica
  bool _analyzeStructure(String text) {
    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).length;
    return paragraphs >= 3 && paragraphs <= 5;
  }

  bool _analyzeArguments(String text) {
    final argumentWords = ['porque', 'pois', 'visto que', 'uma vez que', 'portanto', 'assim'];
    return argumentWords.any((word) => text.toLowerCase().contains(word));
  }

  Map<String, int> _calculateBasicScores(Essay essay, bool hasGoodStructure, bool hasGoodArguments) {
    final baseScore = 120;
    final structureBonus = hasGoodStructure ? 30 : 0;
    final argumentBonus = hasGoodArguments ? 20 : 0;
    final lengthBonus = essay.wordCount > 150 ? 10 : 0;
    
    return {
      'Competência 1': baseScore + structureBonus + 10,
      'Competência 2': baseScore + argumentBonus + 15,
      'Competência 3': baseScore + argumentBonus + structureBonus,
      'Competência 4': baseScore + lengthBonus + 20,
      'Competência 5': baseScore + 5,
    };
  }

  List<DetailedFeedback> _generateBasicFeedback(Map<String, int> scores, String analysis) {
    return scores.entries.map((entry) {
      return DetailedFeedback(
        competency: entry.key,
        score: entry.value,
        summary: 'Análise da ${entry.key}: ${_getScoreDescription(entry.value)}',
        comments: [
          SpecificComment(
            text: analysis.length > 100
                ? '${analysis.substring(0, 100)}...'
                : analysis,
            type: 'neutral',
          ),
        ],
        tips: [
          ImprovementTip(
            title: 'Sugestão',
            description: _getTipForScore(entry.value),
            category: 'Geral',
            priority: 3,
          ),
        ],
      );
    }).toList();
  }

  String _getScoreDescription(int score) {
    if (score >= 180) return 'Excelente desempenho';
    if (score >= 160) return 'Bom desempenho';
    if (score >= 140) return 'Desempenho satisfatório';
    if (score >= 120) return 'Desempenho regular';
    return 'Precisa melhorar';
  }

  String _getTipForScore(int score) {
    if (score >= 160) return 'Continue mantendo este nível de qualidade!';
    if (score >= 140) return 'Você está no caminho certo, continue praticando.';
    if (score >= 120) return 'Foque em melhorar a estrutura e argumentação.';
    return 'Pratique mais e busque exemplos de redações modelo.';
  }

  /// Métodos de parsing para enums
  String _parseCommentType(String? type) {
    switch (type?.toLowerCase()) {
      case 'positive': return 'positive';
      case 'negative': return 'negative';
      default: return 'neutral';
    }
  }

  int _parseTipPriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'critical': return 1;
      case 'high': return 2;
      case 'low': return 5;
      default: return 3;
    }
  }

  String _parseSuggestionType(String? type) {
    switch (type?.toLowerCase()) {
      case 'grammar': return 'grammar';
      case 'style': return 'style';
      case 'structure': return 'structure';
      case 'content': return 'content';
      case 'vocabulary': return 'vocabulary';
      default: return 'style';
    }
  }

  SuggestionPriority _parseSuggestionPriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low': return SuggestionPriority.low;
      case 'high': return SuggestionPriority.high;
      case 'critical': return SuggestionPriority.critical;
      default: return SuggestionPriority.medium;
    }
  }
}
