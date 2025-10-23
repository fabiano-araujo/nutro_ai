import '../models/essay_model.dart';
import '../models/essay_progress_model.dart';

class AnalyticsService {
  // Em produção, esses métodos enviariam dados para um serviço de análise como Firebase Analytics

  // Registra uma interação de chat
  static void logChatInteraction(String userQuery, String aiResponse) {
    // Simula o registro de uma interação de chat
    print('Analítica: Interação de chat registrada');
    print('Query: $userQuery');
    print('Tamanho da resposta: ${aiResponse.length} caracteres');
  }

  // Registra feedback do usuário
  static void logFeedback(String aiResponse, bool isPositive) {
    // Simula o registro de feedback
    print(
        'Analítica: Feedback ${isPositive ? "positivo" : "negativo"} registrado');
    print('Tamanho da resposta avaliada: ${aiResponse.length} caracteres');
  }

  // Registra abertura de tela
  static void logScreenView(String screenName) {
    // Simula o registro de visualização de tela
    print('Analítica: Visualização da tela "$screenName" registrada');
  }

  // Registra uma ação do usuário
  static void logUserAction(
      String actionName, Map<String, dynamic> parameters) {
    // Simula o registro de ação do usuário
    print(
        'Analítica: Ação "$actionName" registrada com parâmetros: $parameters');
  }

  // === ANALYTICS ESPECÍFICOS PARA REDAÇÕES ===

  // Registra criação de nova redação
  static void logEssayCreated(Essay essay) {
    logUserAction('essay_created', {
      'essay_id': essay.id,
      'essay_type': essay.type,
      'word_count': essay.wordCount,
      'character_count': essay.characterCount,
      'theme_id': essay.themeId,
    });
  }

  // Registra submissão de redação para correção
  static void logEssaySubmitted(Essay essay) {
    logUserAction('essay_submitted', {
      'essay_id': essay.id,
      'essay_type': essay.type,
      'word_count': essay.wordCount,
      'time_to_submit': DateTime.now().difference(essay.date).inMinutes,
    });
  }

  // Registra correção de redação
  static void logEssayCorrected(Essay essay) {
    logUserAction('essay_corrected', {
      'essay_id': essay.id,
      'essay_type': essay.type,
      'total_score': essay.score,
      'competency_scores': essay.competenceScores,
      'word_count': essay.wordCount,
    });
  }

  // Registra visualização de feedback
  static void logFeedbackViewed(String essayId, String feedbackType) {
    logUserAction('feedback_viewed', {
      'essay_id': essayId,
      'feedback_type': feedbackType,
    });
  }

  // Registra progresso do usuário
  static void logProgressUpdate(ProgressPoint progressPoint) {
    logUserAction('progress_updated', {
      'essay_id': progressPoint.essayId,
      'essay_type': progressPoint.essayType,
      'total_score': progressPoint.totalScore,
      'competency_scores': progressPoint.competencyScores,
      'date': progressPoint.date.toIso8601String(),
    });
  }

  // Registra conquista desbloqueada
  static void logAchievementUnlocked(Achievement achievement) {
    logUserAction('achievement_unlocked', {
      'achievement_id': achievement.id,
      'achievement_name': achievement.name,
      'achievement_type': achievement.type.toString(),
      'unlocked_at': achievement.unlockedAt.toIso8601String(),
    });
  }

  // Registra visualização de relatório de progresso
  static void logProgressReportViewed(String period, int totalEssays) {
    logUserAction('progress_report_viewed', {
      'period': period,
      'total_essays': totalEssays,
    });
  }

  // Registra comparação com outros usuários
  static void logPeerComparisonViewed(double userScore, double peerAverage) {
    logUserAction('peer_comparison_viewed', {
      'user_average_score': userScore,
      'peer_average_score': peerAverage,
      'performance_difference': userScore - peerAverage,
    });
  }

  // Registra tempo gasto escrevendo
  static void logWritingTime(String essayId, int timeInMinutes) {
    logUserAction('writing_time_tracked', {
      'essay_id': essayId,
      'time_minutes': timeInMinutes,
    });
  }

  // Registra uso de sugestões de melhoria
  static void logSuggestionApplied(String essayId, String suggestionType) {
    logUserAction('suggestion_applied', {
      'essay_id': essayId,
      'suggestion_type': suggestionType,
    });
  }

  // Registra abandono de redação
  static void logEssayAbandoned(String essayId, int wordCount, int timeSpent) {
    logUserAction('essay_abandoned', {
      'essay_id': essayId,
      'word_count': wordCount,
      'time_spent_minutes': timeSpent,
    });
  }

  // Registra busca por temas
  static void logThemeSearch(String searchTerm, int resultsCount) {
    logUserAction('theme_searched', {
      'search_term': searchTerm,
      'results_count': resultsCount,
    });
  }

  // Registra seleção de tema
  static void logThemeSelected(String themeId, String themeTitle) {
    logUserAction('theme_selected', {
      'theme_id': themeId,
      'theme_title': themeTitle,
    });
  }

  // Registra exportação de redação
  static void logEssayExported(String essayId, String exportFormat) {
    logUserAction('essay_exported', {
      'essay_id': essayId,
      'export_format': exportFormat,
    });
  }

  // Registra compartilhamento de progresso
  static void logProgressShared(String shareMethod, Map<String, dynamic> progressData) {
    logUserAction('progress_shared', {
      'share_method': shareMethod,
      'total_essays': progressData['total_essays'],
      'average_score': progressData['average_score'],
    });
  }

  // Registra erro durante correção
  static void logCorrectionError(String essayId, String errorType, String errorMessage) {
    logUserAction('correction_error', {
      'essay_id': essayId,
      'error_type': errorType,
      'error_message': errorMessage,
    });
  }

  // Registra sessão de estudo
  static void logStudySession(int durationMinutes, int essaysCompleted, List<String> topicsStudied) {
    logUserAction('study_session_completed', {
      'duration_minutes': durationMinutes,
      'essays_completed': essaysCompleted,
      'topics_studied': topicsStudied,
    });
  }

  // Registra configuração de meta
  static void logGoalSet(String goalType, int targetValue, DateTime deadline) {
    logUserAction('goal_set', {
      'goal_type': goalType,
      'target_value': targetValue,
      'deadline': deadline.toIso8601String(),
    });
  }

  // Registra alcance de meta
  static void logGoalAchieved(String goalType, int targetValue, int actualValue) {
    logUserAction('goal_achieved', {
      'goal_type': goalType,
      'target_value': targetValue,
      'actual_value': actualValue,
    });
  }

  // === MÉTODOS DE ANÁLISE ===

  // Calcula métricas de engajamento
  static Map<String, dynamic> calculateEngagementMetrics(List<Essay> essays) {
    if (essays.isEmpty) return {};

    final now = DateTime.now();
    final thisWeek = essays.where((e) => 
        e.date.isAfter(now.subtract(const Duration(days: 7)))).length;
    final thisMonth = essays.where((e) => 
        e.date.isAfter(now.subtract(const Duration(days: 30)))).length;
    
    final completedEssays = essays.where((e) => e.status == 'Corrigido').length;
    final completionRate = essays.isNotEmpty ? completedEssays / essays.length : 0.0;

    final averageWordCount = essays.isNotEmpty 
        ? essays.fold(0, (sum, e) => sum + e.wordCount) / essays.length
        : 0.0;

    return {
      'essays_this_week': thisWeek,
      'essays_this_month': thisMonth,
      'completion_rate': completionRate,
      'average_word_count': averageWordCount,
      'total_essays': essays.length,
    };
  }

  // Calcula métricas de performance
  static Map<String, dynamic> calculatePerformanceMetrics(List<Essay> essays) {
    final correctedEssays = essays.where((e) => e.status == 'Corrigido').toList();
    if (correctedEssays.isEmpty) return {};

    final scores = correctedEssays.map((e) => e.score).toList();
    final averageScore = scores.fold(0, (sum, score) => sum + score) / scores.length;
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);

    // Calcular tendência (últimos 5 vs primeiros 5)
    double trend = 0.0;
    if (correctedEssays.length >= 10) {
      final first5 = correctedEssays.take(5).map((e) => e.score).toList();
      final last5 = correctedEssays.skip(correctedEssays.length - 5).map((e) => e.score).toList();
      
      final firstAvg = first5.fold(0, (sum, score) => sum + score) / first5.length;
      final lastAvg = last5.fold(0, (sum, score) => sum + score) / last5.length;
      
      trend = lastAvg - firstAvg;
    }

    return {
      'average_score': averageScore,
      'min_score': minScore,
      'max_score': maxScore,
      'score_trend': trend,
      'total_corrected': correctedEssays.length,
    };
  }
}
